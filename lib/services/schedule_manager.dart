// lib/services/schedule_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../services/local_schedule_service.dart';
import '../services/cloud_schedule_service.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';

/// Enum pro sledování stavu synchronizace
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

/// Manager pro synchronizaci harmonogramu mezi lokálním úložištěm a cloudem.
class ScheduleManager extends ChangeNotifier {
  final LocalScheduleService _localService;
  final CloudScheduleService _cloudService;
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
  StreamSubscription? _cloudSubscription;
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

  ScheduleManager({
    required LocalScheduleService localService,
    required CloudScheduleService cloudService,
    required fb.FirebaseAuth auth,
  })  : _localService = localService,
        _cloudService = cloudService,
        _auth = auth {
    _init();
  }

  Future<void> _init() async {
    _setSyncState(SyncState.idle);

    _setupConnectivityMonitoring();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final newUserId = user.uid;
        if (_currentUserId != newUserId) {
          debugPrint("ScheduleManager: Nový uživatel přihlášen: ${user.uid}");

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

    if (_auth.currentUser != null) {
      _currentUserId = _auth.currentUser!.uid;
      await _forceInitialSync();
    } else {
      await _loadLocalData();
    }

    _syncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _attemptSynchronization();
    });

    _localService.addListener(_handleLocalChanges);
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      final isConnected =
          result.isNotEmpty && result.first != ConnectivityResult.none;

      if (isConnected && !_isOnline) {
        debugPrint("ScheduleManager: Připojení obnoveno");
        _isOnline = true;
        await _syncPendingChanges();
      } else if (!isConnected && _isOnline) {
        debugPrint("ScheduleManager: Offline režim");
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

  /// Kontrola free limitu před přidáním schedule položky
  Future<bool> _checkFreeLimit(BuildContext context) async {
    try {
      if (!context.mounted) return false;

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);

      final canUse = await subscriptionProvider
          .registerInteraction(InteractionType.addScheduleItem);

      if (!canUse) {
        if (!context.mounted) return false;

        final result = await SubscriptionOfferDialog.show(
          context,
          source: 'schedule_limit',
        );
        return result == true;
      }

      return true;
    } catch (e) {
      debugPrint('ScheduleManager: Chyba při kontrole free limitu: $e');
      return true;
    }
  }

  Future<void> _attemptSynchronization() async {
    if (!_isOnline || !_cloudSyncEnabled || _auth.currentUser == null) {
      return;
    }

    if (_pendingChanges.isNotEmpty) {
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
      if (_pendingChanges.isNotEmpty) {
        final List<Map<String, dynamic>> changesToProcess =
            List.from(_pendingChanges);
        _pendingChanges.clear();

        for (final change in changesToProcess) {
          final String operation = change['operation'];
          final ScheduleItem item = change['item'];

          switch (operation) {
            case 'add':
              await _cloudService.addItem(item);
              break;
            case 'update':
              await _cloudService.updateItem(item);
              break;
            case 'remove':
              await _cloudService.removeItem(item.id);
              break;
          }
        }
      } else if (_pendingSyncOperations > 0) {
        await _cloudService.syncFromLocal(_localService.scheduleItems);
        _pendingSyncOperations = 0;
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ScheduleManager: Chyba při synchronizaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _forceInitialSync() async {
    if (_syncState == SyncState.syncing) return;

    _setSyncState(SyncState.syncing);

    try {
      final cloudItems = await _cloudService.fetchScheduleItems();

      await _loadLocalData();

      if (cloudItems.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setItemsWithoutNotify(cloudItems);

        _localService.addListener(_handleLocalChanges);
      } else if (_localService.scheduleItems.isNotEmpty && _isOnline) {
        await _cloudService.syncFromLocal(_localService.scheduleItems);
      }

      _enableCloudSync();

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ScheduleManager: Chyba při inicializaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _refreshFromCloud() async {
    if (!_isOnline || _auth.currentUser == null) return;

    try {
      final cloudItems = await _cloudService.fetchScheduleItems();

      if (cloudItems.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setItemsWithoutNotify(cloudItems);

        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    } catch (e) {
      debugPrint("ScheduleManager: Chyba při aktualizaci z cloudu: $e");
    }
  }

  Future<void> _loadLocalData() async {
    if (!_localDataLoaded) {
      await _localService.loadScheduleItems();
      _localDataLoaded = true;
    }
  }

  void _enableCloudSync() {
    if (!_cloudSyncEnabled || _auth.currentUser == null) {
      return;
    }

    _cloudSubscription?.cancel();
    _cloudSubscription =
        _cloudService.getScheduleItemsStream().listen((cloudItems) {
      if (cloudItems.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setItemsWithoutNotify(cloudItems);

        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("ScheduleManager: Chyba ve streamu cloudových dat: $error");
    });
  }

  void _disableCloudSync() {
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
  }

  void _handleLocalChanges() {
    _pendingSyncOperations++;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _attemptSynchronization();
    });
  }

  // === Veřejné metody s free limit kontrolou ===

  /// Přidá novou položku do harmonogramu s kontrolou free limitu.
  Future<bool> addItem(ScheduleItem item, BuildContext context) async {
    // Kontrola free limitu
    final canAdd = await _checkFreeLimit(context);
    if (!canAdd) {
      return false;
    }

    _localService.addItem(item);

    _pendingChanges.add({
      'operation': 'add',
      'item': item,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
    return true;
  }

  /// Aktualizuje existující položku v harmonogramu (bez kontroly limitu).
  void updateItem(int index, ScheduleItem item) {
    _localService.updateItem(index, item);

    _pendingChanges.add({
      'operation': 'update',
      'item': item,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Odstraní položku z harmonogramu (bez kontroly limitu).
  void removeItem(int index) {
    final item = _localService.scheduleItems[index];

    _localService.removeItem(index);

    _pendingChanges.add({
      'operation': 'remove',
      'item': item,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Změní pořadí položek v harmonogramu.
  void reorderItems(int oldIndex, int newIndex) {
    _localService.reorderItems(oldIndex, newIndex);

    _pendingSyncOperations++;
    _attemptSynchronization();
  }

  /// Vyčistí všechny položky harmonogramu.
  void clearAllItems() {
    final allItems = List<ScheduleItem>.from(_localService.scheduleItems);

    _localService.clearAllItems();

    for (final item in allItems) {
      _pendingChanges.add({
        'operation': 'remove',
        'item': item,
        'timestamp': DateTime.now(),
      });
    }

    _attemptSynchronization();
  }

  /// Vynucené načtení položek z cloudu.
  Future<void> forceRefreshFromCloud() async {
    if (_auth.currentUser == null || !_isOnline) {
      if (!_isOnline) {
        _setSyncState(SyncState.offline);
      }
      return;
    }

    _setSyncState(SyncState.syncing);

    try {
      final cloudItems = await _cloudService.fetchScheduleItems();

      if (cloudItems.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setItemsWithoutNotify(cloudItems);

        _localService.addListener(_handleLocalChanges);
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ScheduleManager: Chyba při načítání z cloudu: $e");
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
        await _cloudService.syncFromLocal(_localService.scheduleItems);
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ScheduleManager: Chyba při synchronizaci do cloudu: $e");
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

  /// Vymaže frontu nevyřízených změn
  void clearPendingChanges() {
    _pendingChanges.clear();
    _pendingSyncOperations = 0;
    notifyListeners();
  }

  /// Vrací stav připojení k internetu jako text
  String get connectivityStatus {
    if (_isOnline) {
      return "Online";
    } else {
      return "Offline";
    }
  }

  /// Exportuje položky harmonogramu do JSON formátu.
  String exportToJson() {
    return _localService.exportToJson();
  }

  /// Importuje položky harmonogramu z JSON formátu.
  Future<void> importFromJson(String jsonData) async {
    await _localService.importFromJson(jsonData);
    _pendingSyncOperations++;
    _attemptSynchronization();
  }

  /// Seznam položek harmonogramu.
  List<ScheduleItem> get scheduleItems => _localService.scheduleItems;

  /// Indikátor načítání.
  bool get isLoading =>
      _localService.isLoading || _syncState == SyncState.syncing;

  /// Synchronizuje data - alias pro interní synchronizační metody
  Future<void> synchronizeData() async {
    if (_auth.currentUser == null) {
      await _loadLocalData();
      return;
    }

    _attemptSynchronization();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _cloudSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _localService.removeListener(_handleLocalChanges);
    super.dispose();
  }
}
