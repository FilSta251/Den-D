// lib/services/calendar_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/calendar_event.dart';
import '../services/local_calendar_service.dart';
import '../services/cloud_calendar_service.dart';

/// Enum pro sledování stavu synchronizace
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

/// Manager pro synchronizaci kalendáře mezi lokálním úložištěm a cloudem.
class CalendarManager extends ChangeNotifier {
  final LocalCalendarService _localService;
  final CloudCalendarService _cloudService;
  final fb.FirebaseAuth _auth;

  // Synchronizační stav
  SyncState _syncState = SyncState.idle;
  SyncState get syncState => _syncState;
  String? _syncError;
  String? get syncError => _syncError;
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Sledování připojení k internetu
  bool _isOnline = true;
  bool get isOnline => _isOnline;
  StreamSubscription? _connectivitySubscription;

  // Interní stav
  StreamSubscription? _eventsCloudSubscription;
  StreamSubscription? _authSubscription;
  bool _localDataLoaded = false;
  Timer? _syncTimer;
  Timer? _debounceTimer;
  String? _currentUserId;
  int _pendingSyncOperations = 0;

  // Nastavení
  bool _cloudSyncEnabled = true;
  bool get cloudSyncEnabled => _cloudSyncEnabled;

  // Stav změn
  final List<Map<String, dynamic>> _pendingChanges = [];
  bool get hasPendingChanges => _pendingChanges.isNotEmpty;
  int get pendingChangesCount => _pendingChanges.length;

  CalendarManager({
    required LocalCalendarService localService,
    required CloudCalendarService cloudService,
    fb.FirebaseAuth? auth,
  })  : _localService = localService,
        _cloudService = cloudService,
        _auth = auth ?? fb.FirebaseAuth.instance {
    _init();
  }

  Future<void> _init() async {
    _setSyncState(SyncState.idle);

    // Inicializace sledování připojení
    _setupConnectivityMonitoring();

    // Sledování změn autentizace
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final newUserId = user.uid;
        if (_currentUserId != newUserId) {
          debugPrint("CalendarManager: Nový uživatel přihlášen: $newUserId");
          _currentUserId = newUserId;
          _localService.removeListener(_handleLocalChanges);
          _localService.clearAllItems();
          await _forceInitialSync();
          _localService.addListener(_handleLocalChanges);
        } else {
          await _refreshFromCloud();
        }
      } else {
        _currentUserId = null;
        _localService.removeListener(_handleLocalChanges);
        _localService.clearAllItems();
        _disableCloudSync();
        _localService.addListener(_handleLocalChanges);
      }
    });

    // Inicializace dat
    if (_auth.currentUser != null) {
      _currentUserId = _auth.currentUser!.uid;
      await _forceInitialSync();
    } else {
      await _loadLocalData();
    }

    // Pravidelná synchronizace
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _attemptSynchronization();
    });

    // Registrace posluchače lokálních změn
    _localService.addListener(_handleLocalChanges);
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      final isConnected =
          result.isNotEmpty && result.first != ConnectivityResult.none;

      if (isConnected && !_isOnline) {
        debugPrint("CalendarManager: Připojení obnoveno");
        _isOnline = true;
        await _syncPendingChanges();
      } else if (!isConnected && _isOnline) {
        debugPrint("CalendarManager: Offline režim");
        _isOnline = false;
        _setSyncState(SyncState.offline);
      }

      notifyListeners();
    });

    Connectivity().checkConnectivity().then((result) {
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
      if (!_isOnline) {
        _setSyncState(SyncState.offline);
      }
    });
  }

  void _setSyncState(SyncState state, [String? error]) {
    _syncState = state;
    _syncError = error;
    if (state == SyncState.idle) {
      _lastSyncTime = DateTime.now();
    }
    notifyListeners();
  }

  Future<void> _attemptSynchronization() async {
    if (!_isOnline || !_cloudSyncEnabled || _auth.currentUser == null) {
      return;
    }

    if (_pendingChanges.isNotEmpty || _pendingSyncOperations > 0) {
      await _syncPendingChanges();
    } else {
      await _refreshFromCloud();
    }
  }

  Future<void> _syncPendingChanges() async {
    if (_auth.currentUser == null || !_isOnline) return;
    if (_syncState == SyncState.syncing) return;
    if (_pendingChanges.isEmpty && _pendingSyncOperations == 0) return;

    _setSyncState(SyncState.syncing);

    try {
      if (_pendingChanges.isNotEmpty) {
        final changesToProcess =
            List<Map<String, dynamic>>.from(_pendingChanges);
        _pendingChanges.clear();

        for (final change in changesToProcess) {
          final operation = change['operation'] as String;
          final event = change['data'] as CalendarEvent;
          switch (operation) {
            case 'add':
              await _cloudService.addEvent(event);
              break;
            case 'update':
              await _cloudService.updateEvent(event);
              break;
            case 'remove':
              await _cloudService.removeEvent(event.id);
              break;
          }
        }
      } else if (_pendingSyncOperations > 0) {
        await _cloudService.syncFromLocal(_localService.events);
        _pendingSyncOperations = 0;
      }
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("CalendarManager: Chyba při synchronizaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _forceInitialSync() async {
    if (_syncState == SyncState.syncing) return;
    _setSyncState(SyncState.syncing);
    try {
      final cloudEvents = await _cloudService.fetchEvents();
      await _loadLocalData();
      if (cloudEvents.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);
        _localService.setEventsWithoutNotify(cloudEvents);
        _localService.addListener(_handleLocalChanges);
      } else if (_localService.events.isNotEmpty && _isOnline) {
        await _cloudService.syncFromLocal(_localService.events);
      }
      _enableCloudSync();
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("CalendarManager: Chyba při inicializaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _refreshFromCloud() async {
    if (!_isOnline || _auth.currentUser == null) return;
    try {
      final cloudEvents = await _cloudService.fetchEvents();
      if (cloudEvents.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);
        _localService.setEventsWithoutNotify(cloudEvents);
        _localService.addListener(_handleLocalChanges);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("CalendarManager: Chyba při aktualizaci z cloudu: $e");
    }
  }

  Future<void> _loadLocalData() async {
    if (!_localDataLoaded) {
      await _localService.loadItems();
      _localDataLoaded = true;
    }
  }

  void _enableCloudSync() {
    if (!_cloudSyncEnabled || _auth.currentUser == null) return;
    _eventsCloudSubscription?.cancel();
    _eventsCloudSubscription =
        _cloudService.getEventsStream().listen((cloudEvents) {
      if (cloudEvents.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);
        _localService.setEventsWithoutNotify(cloudEvents);
        _localService.addListener(_handleLocalChanges);
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("CalendarManager: Chyba ve streamu událostí: $error");
    });
  }

  void _disableCloudSync() {
    _eventsCloudSubscription?.cancel();
    _eventsCloudSubscription = null;
  }

  void _handleLocalChanges() {
    _pendingSyncOperations++;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _attemptSynchronization();
    });
  }

  // === Veřejné metody pro práci s událostmi ===

  void addEvent(CalendarEvent event) {
    _localService.addEvent(event);
    _pendingChanges.add({
      'operation': 'add',
      'data': event,
      'timestamp': DateTime.now(),
    });
    _attemptSynchronization();
  }

  void updateEvent(CalendarEvent event) {
    _localService.updateEvent(event);
    _pendingChanges.add({
      'operation': 'update',
      'data': event,
      'timestamp': DateTime.now(),
    });
    _attemptSynchronization();
  }

  void removeEvent(String eventId) {
    final event = _localService.findItemById(eventId);
    if (event == null) return;
    _localService.removeEvent(eventId);
    _pendingChanges.add({
      'operation': 'remove',
      'data': event,
      'timestamp': DateTime.now(),
    });
    _attemptSynchronization();
  }

  /// Export událostí do formátu iCal (.ics) dle RFC5545
  String exportToICal() {
    final buffer = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//SvatebniPlanovac//EN')
      ..writeln('CALSCALE:GREGORIAN');

    for (final event in _localService.events) {
      final dtStartUtc = event.startTime.toUtc();
      final dtEndUtc = (event.endTime ?? event.startTime).toUtc();
      buffer
        ..writeln('BEGIN:VEVENT')
        ..writeln('UID:${event.id}@svatebniplanovac')
        ..writeln('DTSTAMP:${_formatDate(DateTime.now().toUtc())}')
        ..writeln('DTSTART:${_formatDate(dtStartUtc)}')
        ..writeln('DTEND:${_formatDate(dtEndUtc)}')
        ..writeln('SUMMARY:${event.title}')
        ..writeln('DESCRIPTION:${event.description ?? ''}')
        ..writeln('LOCATION:${event.location ?? ''}')
        ..writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }

  void clearAllData() {
    final allEvents = List<CalendarEvent>.from(_localService.events);
    _localService.clearAllItems();
    for (final event in allEvents) {
      _pendingChanges.add({
        'operation': 'remove',
        'data': event,
        'timestamp': DateTime.now(),
      });
    }
    _attemptSynchronization();
  }

  Future<void> forceRefreshFromCloud() async {
    if (_auth.currentUser == null || !_isOnline) {
      if (!_isOnline) _setSyncState(SyncState.offline);
      return;
    }
    _setSyncState(SyncState.syncing);
    try {
      final cloudEvents = await _cloudService.fetchEvents();
      _localService.removeListener(_handleLocalChanges);
      _localService.setEventsWithoutNotify(cloudEvents);
      _localService.addListener(_handleLocalChanges);
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("CalendarManager: Chyba při načítání z cloudu: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> forceSyncToCloud() async {
    if (_auth.currentUser == null || !_isOnline) {
      if (!_isOnline) _setSyncState(SyncState.offline);
      return;
    }
    _setSyncState(SyncState.syncing);
    try {
      await _syncPendingChanges();
      if (_pendingChanges.isEmpty) {
        await _cloudService.syncFromLocal(_localService.events);
      }
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("CalendarManager: Chyba při synchronizaci do cloudu: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  set cloudSyncEnabled(bool value) {
    _cloudSyncEnabled = value;
    if (value && _auth.currentUser != null && _isOnline) {
      _enableCloudSync();
      _attemptSynchronization();
    } else if (!value) {
      _disableCloudSync();
    }
    notifyListeners();
  }

  void clearPendingChanges() {
    _pendingChanges.clear();
    _pendingSyncOperations = 0;
    notifyListeners();
  }

  // === Gettery pro přístup k datům ===
  List<CalendarEvent> get events => _localService.events;
  bool get isLoading =>
      _localService.isLoading || _syncState == SyncState.syncing;
  List<CalendarEvent> getEventsForDay(DateTime day) =>
      _localService.getEventsForDay(day);
  List<CalendarEvent> getEventsForMonth(int year, int month) =>
      _localService.getEventsForMonth(year, month);
  List<CalendarEvent> getEventsInRange(DateTime start, DateTime end) =>
      _localService.getEventsInRange(start, end);
  List<CalendarEvent> getEventsByCategory(String category) =>
      _localService.getEventsByCategory(category);
  List<CalendarEvent> getEventsWithReminder() =>
      _localService.getEventsWithReminder();
  List<CalendarEvent> getUpcomingEvents({int days = 7}) =>
      _localService.getUpcomingEvents(days: days);
  List<CalendarEvent> getOngoingEvents() => _localService.getOngoingEvents();
  Map<String, dynamic> getCalendarStatistics() =>
      _localService.getCalendarStatistics();
  Map<String, int> getCategorySummary() => _localService.getCategorySummary();
  List<CalendarEvent> findTimeConflicts(
          DateTime startTime, DateTime? endTime) =>
      _localService.findTimeConflicts(startTime, endTime);

  @override
  void dispose() {
    _authSubscription?.cancel();
    _eventsCloudSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _localService.removeListener(_handleLocalChanges);
    super.dispose();
  }
}
