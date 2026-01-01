// lib/services/budget_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../models/expense.dart';
import '../services/local_budget_service.dart';
import '../services/cloud_budget_service.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';

/// Enum pro sledování stavu synchronizace
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

/// Manager pro synchronizaci položek rozpočtu mezi lokálním úložištěm a cloudem.
///
/// DŮLEŽITÉ: Tento manager spravuje pouze jednotlivé položky výdajů (Expense),
/// nikoliv celkový rozpočet svatby, který je uložen v kolekci wedding_info a
/// je spravován prostřednictvím WeddingRepository.
class BudgetManager extends ChangeNotifier {
  final LocalBudgetService _localService;
  final CloudBudgetService _cloudService;
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

  BudgetManager({
    required LocalBudgetService localService,
    required CloudBudgetService cloudService,
    fb.FirebaseAuth? auth,
  })  : _localService = localService,
        _cloudService = cloudService,
        _auth = auth ?? fb.FirebaseAuth.instance {
    _init();
  }

  Future<void> _init() async {
    _setSyncState(SyncState.idle);

    _setupConnectivityMonitoring();

    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final newUserId = user.uid;
        if (_currentUserId != newUserId) {
          debugPrint("BudgetManager: Nový uživatel přihlášen: ${user.uid}");

          _currentUserId = newUserId;

          _localService.removeListener(_handleLocalChanges);
          _localService.clearAllExpenses();

          await _forceInitialSync();

          _localService.addListener(_handleLocalChanges);
        } else {
          await _refreshFromCloud();
        }
      } else {
        _currentUserId = null;

        _localService.removeListener(_handleLocalChanges);
        _localService.clearAllExpenses();

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
        debugPrint("BudgetManager: Připojení obnoveno");
        _isOnline = true;
        await _syncPendingChanges();
      } else if (!isConnected && _isOnline) {
        debugPrint("BudgetManager: Offline režim");
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

  /// Kontrola free limitu před přidáním výdaje
  Future<bool> _checkFreeLimit(BuildContext context) async {
    try {
      if (!context.mounted) return false;

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);

      final canUse = await subscriptionProvider
          .registerInteraction(InteractionType.addExpense);

      if (!canUse) {
        if (!context.mounted) return false;

        final result = await SubscriptionOfferDialog.show(
          context,
          source: 'budget_limit',
        );
        return result == true;
      }

      return true;
    } catch (e) {
      debugPrint('BudgetManager: Chyba při kontrole free limitu: $e');
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
          final Expense expense = change['expense'];

          switch (operation) {
            case 'add':
              await _cloudService.addExpense(expense);
              break;
            case 'update':
              await _cloudService.updateExpense(expense);
              break;
            case 'remove':
              await _cloudService.removeExpense(expense.id);
              break;
          }
        }
      } else if (_pendingSyncOperations > 0) {
        await _cloudService.syncFromLocal(_localService.expenses);
        _pendingSyncOperations = 0;
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("BudgetManager: Chyba při synchronizaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _forceInitialSync() async {
    if (_syncState == SyncState.syncing) return;

    _setSyncState(SyncState.syncing);

    try {
      final cloudExpenses = await _cloudService.fetchExpenses();

      await _loadLocalData();

      if (cloudExpenses.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setExpensesWithoutNotify(cloudExpenses);

        _localService.addListener(_handleLocalChanges);
      } else if (_localService.expenses.isNotEmpty && _isOnline) {
        await _cloudService.syncFromLocal(_localService.expenses);
      }

      _enableCloudSync();

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("BudgetManager: Chyba při inicializaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _refreshFromCloud() async {
    if (!_isOnline || _auth.currentUser == null) return;

    try {
      final cloudExpenses = await _cloudService.fetchExpenses();

      if (cloudExpenses.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setExpensesWithoutNotify(cloudExpenses);

        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    } catch (e) {
      debugPrint("BudgetManager: Chyba při aktualizaci z cloudu: $e");
    }
  }

  Future<void> _loadLocalData() async {
    if (!_localDataLoaded) {
      await _localService.loadExpenses();
      _localDataLoaded = true;
    }
  }

  void _enableCloudSync() {
    if (!_cloudSyncEnabled || _auth.currentUser == null) {
      return;
    }

    _cloudSubscription?.cancel();
    _cloudSubscription =
        _cloudService.getExpensesStream().listen((cloudExpenses) {
      if (cloudExpenses.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setExpensesWithoutNotify(cloudExpenses);

        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("BudgetManager: Chyba ve streamu cloudových dat: $error");
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

  /// Přidá nový výdaj do rozpočtu s kontrolou free limitu.
  Future<bool> addExpense(Expense expense, BuildContext context) async {
    // Kontrola free limitu
    final canAdd = await _checkFreeLimit(context);
    if (!canAdd) {
      return false;
    }

    _localService.addExpense(expense);

    _pendingChanges.add({
      'operation': 'add',
      'expense': expense,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
    return true;
  }

  /// Aktualizuje existující výdaj v rozpočtu (bez kontroly limitu).
  void updateExpense(Expense expense) {
    _localService.updateExpense(expense);

    _pendingChanges.add({
      'operation': 'update',
      'expense': expense,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Odstraní výdaj z rozpočtu (bez kontroly limitu).
  void removeExpense(String expenseId) {
    final expense = _localService.getExpenseById(expenseId);

    _localService.removeExpense(expenseId);

    _pendingChanges.add({
      'operation': 'remove',
      'expense': expense,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Vyčistí všechny výdaje rozpočtu.
  void clearAllExpenses() {
    final allExpenses = List<Expense>.from(_localService.expenses);

    _localService.clearAllExpenses();

    for (final expense in allExpenses) {
      _pendingChanges.add({
        'operation': 'remove',
        'expense': expense,
        'timestamp': DateTime.now(),
      });
    }

    _attemptSynchronization();
  }

  /// Vynucené načtení výdajů z cloudu.
  Future<void> forceRefreshFromCloud() async {
    if (_auth.currentUser == null || !_isOnline) {
      if (!_isOnline) {
        _setSyncState(SyncState.offline);
      }
      return;
    }

    _setSyncState(SyncState.syncing);

    try {
      final cloudExpenses = await _cloudService.fetchExpenses();

      if (cloudExpenses.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setExpensesWithoutNotify(cloudExpenses);

        _localService.addListener(_handleLocalChanges);
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("BudgetManager: Chyba při načítání z cloudu: $e");
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
        await _cloudService.syncFromLocal(_localService.expenses);
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("BudgetManager: Chyba při synchronizaci do cloudu: $e");
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

  /// Exportuje položky rozpočtu do JSON formátu.
  String exportToJson() {
    return _localService.exportToJson();
  }

  /// Importuje položky rozpočtu z JSON formátu.
  Future<void> importFromJson(String jsonData) async {
    await _localService.importFromJson(jsonData);
    _pendingSyncOperations++;
    _attemptSynchronization();
  }

  /// Seznam výdajů rozpočtu.
  List<Expense> get expenses => _localService.expenses;

  /// Indikátor načítání.
  bool get isLoading =>
      _localService.isLoading || _syncState == SyncState.syncing;

  /// Vypočítá celkovou zaplacenou částku
  double get totalPaid => expenses.fold(0.0, (sum, exp) => sum + exp.paid);

  /// Vypočítá celkovou očekávanou částku
  double get totalPending =>
      expenses.fold(0.0, (sum, exp) => sum + exp.pending);

  /// Vypočítá celkové výdaje (zaplacené + očekávané)
  double get totalExpenses => totalPaid + totalPending;

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
