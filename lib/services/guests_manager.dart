/// lib/services/guests_manager.dart
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../models/guest.dart';
import '../models/table_arrangement.dart';
import '../services/local_guests_service.dart';
import '../services/cloud_guests_service.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';

/// Enum pro sledování stavu synchronizace
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

/// Manager pro synchronizaci hostů a stolů mezi lokálním úložištěm a cloudem.
///
/// poskytuje kompletní správu hostů svatby včetně:
/// - Správy seznamu hostů
/// - Rozmístění u stolů
/// - Sledování účasti
/// - Offline/online synchronizace
/// - Free limit kontroly
class GuestsManager extends ChangeNotifier {
  final LocalGuestsService _localService;
  final CloudGuestsService _cloudService;
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
  StreamSubscription? _guestsCloudSubscription;
  StreamSubscription? _tablesCloudSubscription;
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

  GuestsManager({
    required LocalGuestsService localService,
    required CloudGuestsService cloudService,
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
          debugPrint("GuestsManager: Nový uživatel přihlášen: ${user.uid}");

          _currentUserId = newUserId;

          // Vyčistíme lokální data
          _localService.removeListener(_handleLocalChanges);
          _localService.clearAllItems();

          // Provedeme synchronizaci z cloudu
          await _forceInitialSync();

          // Znovu napojíme poslucháče
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

    // Registrace poslucháče lokálních změn
    _localService.addListener(_handleLocalChanges);
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      final isConnected =
          result.isNotEmpty && result.first != ConnectivityResult.none;

      if (isConnected && !_isOnline) {
        debugPrint("GuestsManager: Připojení obnoveno");
        _isOnline = true;
        await _syncPendingChanges();
      } else if (!isConnected && _isOnline) {
        debugPrint("GuestsManager: Offline režim");
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

  /// Kontrola free limitu před přidáním hosta
  Future<bool> _checkFreeLimit(BuildContext context) async {
    try {
      if (!context.mounted) return false;

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);

      final canUse = await subscriptionProvider
          .registerInteraction(InteractionType.addGuest);

      if (!canUse) {
        if (!context.mounted) return false;

        final result = await SubscriptionOfferDialog.show(
          context,
          source: 'guests_limit',
        );
        return result == true;
      }

      return true;
    } catch (e) {
      debugPrint('GuestsManager: Chyba při kontrole free limitu: $e');
      // V případě chyby povolíme akci
      return true;
    }
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
        final List<Map<String, dynamic>> changesToProcess =
            List.from(_pendingChanges);
        _pendingChanges.clear();

        for (final change in changesToProcess) {
          final String operation = change['operation'];
          final String type = change['type'];

          switch (type) {
            case 'guest':
              final Guest guest = change['data'];
              switch (operation) {
                case 'add':
                  await _cloudService.addGuest(guest);
                  break;
                case 'update':
                  await _cloudService.updateGuest(guest);
                  break;
                case 'remove':
                  await _cloudService.removeGuest(guest.id);
                  break;
              }
              break;

            case 'table':
              final TableArrangement table = change['data'];
              switch (operation) {
                case 'add':
                  await _cloudService.addTable(table);
                  break;
                case 'update':
                  await _cloudService.updateTable(table);
                  break;
                case 'remove':
                  await _cloudService.removeTable(table.id);
                  break;
              }
              break;
          }
        }
      }
      // Synchronizace celé kolekce
      else if (_pendingSyncOperations > 0) {
        await _cloudService.syncFromLocal(
            _localService.guests, _localService.tables);
        _pendingSyncOperations = 0;
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("GuestsManager: Chyba při synchronizaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _forceInitialSync() async {
    if (_syncState == SyncState.syncing) return;

    _setSyncState(SyncState.syncing);

    try {
      // Načteme data z cloudu
      final cloudGuests = await _cloudService.fetchGuests();
      final cloudTables = await _cloudService.fetchTables();

      // Načteme lokální data
      await _loadLocalData();

      // Použijeme cloudová data, pokud existují
      if (cloudGuests.isNotEmpty || cloudTables.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setGuestsAndTablesWithoutNotify(cloudGuests, cloudTables);

        _localService.addListener(_handleLocalChanges);
      }
      // Pokud máme lokální data a cloud je prázdný, nahrajeme na cloud
      else if ((_localService.guests.isNotEmpty ||
              _localService.tables.isNotEmpty) &&
          _isOnline) {
        await _cloudService.syncFromLocal(
            _localService.guests, _localService.tables);
      }

      // Zahájíme sledování změn v cloudu
      _enableCloudSync();

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("GuestsManager: Chyba při inicializaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _refreshFromCloud() async {
    if (!_isOnline || _auth.currentUser == null) return;

    try {
      final cloudGuests = await _cloudService.fetchGuests();
      final cloudTables = await _cloudService.fetchTables();

      if (cloudGuests.isNotEmpty || cloudTables.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setGuestsAndTablesWithoutNotify(cloudGuests, cloudTables);

        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    } catch (e) {
      debugPrint("GuestsManager: Chyba při aktualizaci z cloudu: $e");
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

    // Stream pro hosty
    _guestsCloudSubscription?.cancel();
    _guestsCloudSubscription =
        _cloudService.getGuestsStream().listen((cloudGuests) {
      if (cloudGuests.isNotEmpty) {
        final currentTables = _localService.tables;

        _localService.removeListener(_handleLocalChanges);
        _localService.setGuestsAndTablesWithoutNotify(
            cloudGuests, currentTables);
        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("GuestsManager: Chyba ve streamu hostů: $error");
    });

    // Stream pro stoly
    _tablesCloudSubscription?.cancel();
    _tablesCloudSubscription =
        _cloudService.getTablesStream().listen((cloudTables) {
      if (cloudTables.isNotEmpty) {
        final currentGuests = _localService.guests;

        _localService.removeListener(_handleLocalChanges);
        _localService.setGuestsAndTablesWithoutNotify(
            currentGuests, cloudTables);
        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("GuestsManager: Chyba ve streamu stolů: $error");
    });
  }

  void _disableCloudSync() {
    _guestsCloudSubscription?.cancel();
    _guestsCloudSubscription = null;
    _tablesCloudSubscription?.cancel();
    _tablesCloudSubscription = null;
  }

  void _handleLocalChanges() {
    _pendingSyncOperations++;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _attemptSynchronization();
    });
  }

  // === Veřejné metody pro práci s hosty (s free limit kontrolou) ===

  /// Přidá nového hosta s kontrolou free limitu.
  Future<bool> addGuest(Guest guest, BuildContext context) async {
    // Kontrola free limitu
    final canAdd = await _checkFreeLimit(context);
    if (!canAdd) {
      return false;
    }

    _localService.addGuest(guest);

    _pendingChanges.add({
      'operation': 'add',
      'type': 'guest',
      'data': guest,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
    return true;
  }

  /// Aktualizuje hosta (bez kontroly limitu - editace existujícího hosta).
  void updateGuest(Guest guest) {
    _localService.updateGuest(guest);

    _pendingChanges.add({
      'operation': 'update',
      'type': 'guest',
      'data': guest,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Odstraní hosta (bez kontroly limitu - odstraňování je vždy povoleno).
  void removeGuest(String guestId) {
    final guest = _localService.findItemById(guestId);
    if (guest == null) return;

    _localService.removeGuest(guestId);

    _pendingChanges.add({
      'operation': 'remove',
      'type': 'guest',
      'data': guest,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  // === Veřejné metody pro práci se stoly ===

  /// Přidá nový stůl.
  Future<void> addTable(TableArrangement table) async {
    await _localService.addTable(table);

    _pendingChanges.add({
      'operation': 'add',
      'type': 'table',
      'data': table,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Aktualizuje stůl.
  Future<void> updateTable(TableArrangement table) async {
    await _localService.updateTable(table);

    _pendingChanges.add({
      'operation': 'update',
      'type': 'table',
      'data': table,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Odstraní stůl.
  Future<void> removeTable(String tableId) async {
    final table = _localService.tables.firstWhere((t) => t.id == tableId);

    await _localService.removeTable(tableId);

    _pendingChanges.add({
      'operation': 'remove',
      'type': 'table',
      'data': table,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Vyčistí všechny hosty a stoly.
  void clearAllData() {
    final allGuests = List<Guest>.from(_localService.guests);
    final allTables = List<TableArrangement>.from(_localService.tables);

    _localService.clearAllItems();

    // Přidáme operace odstranění
    for (final guest in allGuests) {
      _pendingChanges.add({
        'operation': 'remove',
        'type': 'guest',
        'data': guest,
        'timestamp': DateTime.now(),
      });
    }

    for (final table in allTables) {
      _pendingChanges.add({
        'operation': 'remove',
        'type': 'table',
        'data': table,
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
      final cloudGuests = await _cloudService.fetchGuests();
      final cloudTables = await _cloudService.fetchTables();

      _localService.removeListener(_handleLocalChanges);
      _localService.setGuestsAndTablesWithoutNotify(cloudGuests, cloudTables);
      _localService.addListener(_handleLocalChanges);

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("GuestsManager: Chyba při načítání z cloudu: $e");
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
        await _cloudService.syncFromLocal(
            _localService.guests, _localService.tables);
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("GuestsManager: Chyba při synchronizaci do cloudu: $e");
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

  /// Seznam hostů.
  List<Guest> get guests => _localService.guests;

  /// Seznam stolů.
  List<TableArrangement> get tables => _localService.tables;

  /// Indikátor načítání.
  bool get isLoading =>
      _localService.isLoading || _syncState == SyncState.syncing;

  /// Získá hosty podle skupiny.
  List<Guest> getGuestsByGroup(String group) =>
      _localService.getGuestsByGroup(group);

  /// Získá hosty podle stolu.
  List<Guest> getGuestsByTable(String tableName) =>
      _localService.getGuestsByTable(tableName);

  /// Získá hosty podle účasti.
  List<Guest> getGuestsByAttendance(String attendance) =>
      _localService.getGuestsByAttendance(attendance);

  /// Získá hosty podle pohlaví.
  List<Guest> getGuestsByGender(String gender) =>
      _localService.getGuestsByGender(gender);

  /// Získá statistiky hostů.
  Map<String, dynamic> getGuestStatistics() =>
      _localService.getGuestStatistics();

  /// Získá souhrn podle skupin.
  Map<String, int> getGroupSummary() => _localService.getGroupSummary();

  /// Získá využití stolů.
  Map<String, Map<String, dynamic>> getTableUtilization() =>
      _localService.getTableUtilization();

  @override
  void dispose() {
    _authSubscription?.cancel();
    _guestsCloudSubscription?.cancel();
    _tablesCloudSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _localService.removeListener(_handleLocalChanges);
    super.dispose();
  }
}
