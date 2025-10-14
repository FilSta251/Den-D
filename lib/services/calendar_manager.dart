// lib/services/calendar_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/calendar_event.dart';
import '../services/local_calendar_service.dart';
import '../services/cloud_calendar_service.dart';

/// Manager pro synchronizaci kalendáře mezi lokálním úložištěm a cloudem.
/// 
/// Poskytuje kompletní správu kalendářních událostí včetně:
/// - Správy událostí podle kategorií
/// - Sledování časových konfliktů
/// - Nastavení připomenutí
/// - Offline/online synchronizace
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
  bool _initialized = false;
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
  }) : 
    _localService = localService,
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
          debugPrint("CalendarManager: Nový uživatel přihlášen: ${user.uid}");
          
          _currentUserId = newUserId;
          
          // Vyčistíme lokální data
          _localService.removeListener(_handleLocalChanges);
          _localService.clearAllItems();
          
          // Provedeme synchronizaci z cloudu
          await _forceInitialSync();
          
          // Znovu napojíme posluchače
          _localService.addListener(_handleLocalChanges);
        } else {
          await _refreshFromCloud();
        }
      } else {
        // Uživatel odhlášen
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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      final isConnected = result.isNotEmpty && result.first != ConnectivityResult.none;
      
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
    
    // Kontrola počátečního stavu
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
    if (_auth.currentUser == null || !_isOnline) {
      return;
    }
    
    if (_syncState == SyncState.syncing) {
      return;
    }
    
    if (_pendingChanges.isEmpty && _pendingSyncOperations == 0) {
      return;
    }
    
    _setSyncState(SyncState.syncing);
    
    try {
      // Zpracování konkrétních změn
      if (_pendingChanges.isNotEmpty) {
        final List<Map<String, dynamic>> changesToProcess = List.from(_pendingChanges);
        _pendingChanges.clear();
        
        for (final change in changesToProcess) {
          final String operation = change['operation'];
          final CalendarEvent event = change['data'];
          
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
      } 
      // Synchronizace celé kolekce
      else if (_pendingSyncOperations > 0) {
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
      // Načteme data z cloudu
      final cloudEvents = await _cloudService.fetchEvents();
      
      // Načteme lokální data
      await _loadLocalData();
      
      // Použijeme cloudová data, pokud existují
      if (cloudEvents.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);
        
        _localService.setEventsWithoutNotify(cloudEvents);
        
        _localService.addListener(_handleLocalChanges);
      } 
      // Pokud máme lokální data a cloud je prázdný, nahrajeme na cloud
      else if (_localService.events.isNotEmpty && _isOnline) {
        await _cloudService.syncFromLocal(_localService.events);
      }
      
      // Zahájíme sledování změn v cloudu
      _enableCloudSync();
      
      _initialized = true;
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
    if (!_cloudSyncEnabled || _auth.currentUser == null) {
      return;
    }
    
    // Stream pro události
    _eventsCloudSubscription?.cancel();
    _eventsCloudSubscription = _cloudService.getEventsStream().listen((cloudEvents) {
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
    _initialized = false;
  }
  
  void _handleLocalChanges() {
    _pendingSyncOperations++;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _attemptSynchronization();
    });
  }
  
  // === Veřejné metody pro práci s událostmi ===
  
  /// Přidá novou událost.
  void addEvent(CalendarEvent event) {
    _localService.addEvent(event);
    
    _pendingChanges.add({
      'operation': 'add',
      'data': event,
      'timestamp': DateTime.now(),
    });
    
    _attemptSynchronization();
  }
  
  /// Aktualizuje událost.
  void updateEvent(CalendarEvent event) {
    _localService.updateEvent(event);
    
    _pendingChanges.add({
      'operation': 'update',
      'data': event,
      'timestamp': DateTime.now(),
    });
    
    _attemptSynchronization();
  }
  
  /// Odstraní událost.
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
  
  /// Vyčistí všechny události.
  void clearAllData() {
    final allEvents = List<CalendarEvent>.from(_localService.events);
    
    _localService.clearAllItems();
    
    // Přidáme operace odstranění
    for (final event in allEvents) {
      _pendingChanges.add({
        'operation': 'remove',
        'data': event,
        'timestamp': DateTime.now(),
      });
    }
    
    _attemptSynchronization();
  }
  
  /// Vynucené načtení dat z cloudu.
  Future<void> forceRefreshFromCloud() async {
    if (_auth.currentUser == null || !_isOnline) {
      if (!_isOnline) {
        _setSyncState(SyncState.offline);
      }
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
  
  /// Vynucená synchronizace do cloudu.
  Future<void> forceSyncToCloud() async {
    if (_auth.currentUser == null || !_isOnline) {
      if (!_isOnline) {
        _setSyncState(SyncState.offline);
      }
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
  
  /// Zapne/vypne cloudovou synchronizaci.
  set cloudSyncEnabled(bool value) {
    _cloudSyncEnabled = value;
    if (value) {
      if (_auth.currentUser != null && _isOnline) {
        _enableCloudSync();
        _attemptSynchronization();
      }
    } else {
      _disableCloudSync();
    }
    notifyListeners();
  }
  
  /// Vymaže frontu nevyřízených změn.
  void clearPendingChanges() {
    _pendingChanges.clear();
    _pendingSyncOperations = 0;
    notifyListeners();
  }
  
  // === Gettery pro přístup k datům ===
  
  /// Seznam událostí.
  List<CalendarEvent> get events => _localService.events;
  
  /// Indikátor načítání.
  bool get isLoading => _localService.isLoading || _syncState == SyncState.syncing;
  
  /// Získá události pro konkrétní den.
  List<CalendarEvent> getEventsForDay(DateTime day) => _localService.getEventsForDay(day);
  
  /// Získá události v daném měsíci.
  List<CalendarEvent> getEventsForMonth(int year, int month) => _localService.getEventsForMonth(year, month);
  
  /// Získá události v daném časovém rozmezí.
  List<CalendarEvent> getEventsInRange(DateTime start, DateTime end) => _localService.getEventsInRange(start, end);
  
  /// Získá události podle kategorie.
  List<CalendarEvent> getEventsByCategory(String category) => _localService.getEventsByCategory(category);
  
  /// Získá události s připomenutím.
  List<CalendarEvent> getEventsWithReminder() => _localService.getEventsWithReminder();
  
  /// Získá nadcházející události.
  List<CalendarEvent> getUpcomingEvents({int days = 7}) => _localService.getUpcomingEvents(days: days);
  
  /// Získá probíhající události.
  List<CalendarEvent> getOngoingEvents() => _localService.getOngoingEvents();
  
  /// Získá statistiky kalendáře.
  Map<String, dynamic> getCalendarStatistics() => _localService.getCalendarStatistics();
  
  /// Získá souhrn podle kategorií.
  Map<String, int> getCategorySummary() => _localService.getCategorySummary();
  
  /// Kontrola konfliktů v čase.
  List<CalendarEvent> findTimeConflicts(DateTime startTime, DateTime? endTime) => 
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

/// Enum pro sledování stavu synchronizace
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}