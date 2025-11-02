/// lib/services/checklist_manager.dart
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/local_checklist_service.dart';
import '../services/cloud_checklist_service.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_offer_dialog.dart';

/// Enum pro sledování stavu synchronizace
enum SyncState {
  idle,
  syncing,
  error,
  offline,
}

/// Manager pro synchronizaci checklistu mezi lokálním úložištěm a cloudem.
///
/// poskytuje kompletní správu úkolů svatby včetně:
/// - Správy úkolů podle kategorií
/// - Sledování dokončenosti
/// - Nastavení priorit
/// - Offline/online synchronizace
/// - Free limit kontroly
class ChecklistManager extends ChangeNotifier {
  final LocalChecklistService _localService;
  final CloudChecklistService _cloudService;
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
  StreamSubscription? _tasksCloudSubscription;
  StreamSubscription? _categoriesCloudSubscription;
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

  ChecklistManager({
    required LocalChecklistService localService,
    required CloudChecklistService cloudService,
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
          debugPrint("ChecklistManager: Nový uživatel přihlášen: ${user.uid}");

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
        debugPrint("ChecklistManager: Připojení obnoveno");
        _isOnline = true;
        await _syncPendingChanges();
      } else if (!isConnected && _isOnline) {
        debugPrint("ChecklistManager: Offline režim");
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

  /// Kontrola free limitu před přidáním checklist položky
  Future<bool> _checkFreeLimit(BuildContext context) async {
    try {
      if (!context.mounted) return false;

      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);

      final canUse = await subscriptionProvider
          .registerInteraction(InteractionType.addChecklistItem);

      if (!canUse) {
        if (!context.mounted) return false;

        final result = await SubscriptionOfferDialog.show(
          context,
          source: 'checklist_limit',
        );
        return result == true;
      }

      return true;
    } catch (e) {
      debugPrint('ChecklistManager: Chyba při kontrole free limitu: $e');
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
            case 'task':
              final Task task = change['data'];
              switch (operation) {
                case 'add':
                  await _cloudService.addTask(task);
                  break;
                case 'update':
                  await _cloudService.updateTask(task);
                  break;
                case 'remove':
                  await _cloudService.removeTask(task.id);
                  break;
                case 'toggle':
                  await _cloudService.toggleTaskDone(task.id, task.isDone);
                  break;
              }
              break;

            case 'category':
              final TaskCategory category = change['data'];
              switch (operation) {
                case 'add':
                  await _cloudService.addCategory(category);
                  break;
                case 'update':
                  await _cloudService.updateCategory(category);
                  break;
                case 'remove':
                  final defaultCategoryId =
                      change['defaultCategoryId'] as String;
                  await _cloudService.removeCategory(
                      category.id, defaultCategoryId);
                  break;
              }
              break;
          }
        }
      }
      // Synchronizace celé kolekce
      else if (_pendingSyncOperations > 0) {
        await _cloudService.syncFromLocal(
            _localService.tasks, _localService.categories);
        _pendingSyncOperations = 0;
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ChecklistManager: Chyba při synchronizaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _forceInitialSync() async {
    if (_syncState == SyncState.syncing) return;

    _setSyncState(SyncState.syncing);

    try {
      // Načteme data z cloudu
      final cloudTasks = await _cloudService.fetchTasks();
      final cloudCategories = await _cloudService.fetchCategories();

      // Načteme lokální data
      await _loadLocalData();

      // Použijeme cloudová data, pokud existují
      if (cloudTasks.isNotEmpty || cloudCategories.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setTasksAndCategoriesWithoutNotify(
            cloudTasks, cloudCategories);

        _localService.addListener(_handleLocalChanges);
      }
      // Pokud máme lokální data a cloud je prázdný, nahrajeme na cloud
      else if ((_localService.tasks.isNotEmpty ||
              _localService.categories.isNotEmpty) &&
          _isOnline) {
        await _cloudService.syncFromLocal(
            _localService.tasks, _localService.categories);
      }

      // Zahájíme sledování změn v cloudu
      _enableCloudSync();

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ChecklistManager: Chyba při inicializaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }

  Future<void> _refreshFromCloud() async {
    if (!_isOnline || _auth.currentUser == null) return;

    try {
      final cloudTasks = await _cloudService.fetchTasks();
      final cloudCategories = await _cloudService.fetchCategories();

      if (cloudTasks.isNotEmpty || cloudCategories.isNotEmpty) {
        _localService.removeListener(_handleLocalChanges);

        _localService.setTasksAndCategoriesWithoutNotify(
            cloudTasks, cloudCategories);

        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    } catch (e) {
      debugPrint("ChecklistManager: Chyba při aktualizaci z cloudu: $e");
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

    // Stream pro úkoly
    _tasksCloudSubscription?.cancel();
    _tasksCloudSubscription =
        _cloudService.getTasksStream().listen((cloudTasks) {
      if (cloudTasks.isNotEmpty) {
        final currentCategories = _localService.categories;

        _localService.removeListener(_handleLocalChanges);
        _localService.setTasksAndCategoriesWithoutNotify(
            cloudTasks, currentCategories);
        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("ChecklistManager: Chyba ve streamu úkolů: $error");
    });

    // Stream pro kategorie
    _categoriesCloudSubscription?.cancel();
    _categoriesCloudSubscription =
        _cloudService.getCategoriesStream().listen((cloudCategories) {
      if (cloudCategories.isNotEmpty) {
        final currentTasks = _localService.tasks;

        _localService.removeListener(_handleLocalChanges);
        _localService.setTasksAndCategoriesWithoutNotify(
            currentTasks, cloudCategories);
        _localService.addListener(_handleLocalChanges);

        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("ChecklistManager: Chyba ve streamu kategorií: $error");
    });
  }

  void _disableCloudSync() {
    _tasksCloudSubscription?.cancel();
    _tasksCloudSubscription = null;
    _categoriesCloudSubscription?.cancel();
    _categoriesCloudSubscription = null;
  }

  void _handleLocalChanges() {
    _pendingSyncOperations++;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _attemptSynchronization();
    });
  }

  // === Veřejné metody pro práci s úkoly (s free limit kontrolou) ===

  /// Přidá nový úkol s kontrolou free limitu.
  Future<bool> addTask(Task task, BuildContext context) async {
    // Kontrola free limitu
    final canAdd = await _checkFreeLimit(context);
    if (!canAdd) {
      return false;
    }

    _localService.addTask(task);

    _pendingChanges.add({
      'operation': 'add',
      'type': 'task',
      'data': task,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
    return true;
  }

  /// Aktualizuje úkol (bez kontroly limitu - editace existujícího úkolu).
  void updateTask(Task task) {
    _localService.updateTask(task);

    _pendingChanges.add({
      'operation': 'update',
      'type': 'task',
      'data': task,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Odstraní úkol (bez kontroly limitu - odstraňování je vždy povoleno).
  void removeTask(String taskId) {
    final task = _localService.findItemById(taskId);
    if (task == null) return;

    _localService.removeTask(taskId);

    _pendingChanges.add({
      'operation': 'remove',
      'type': 'task',
      'data': task,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Přepne stav dokončení úkolu (bez kontroly limitu - toggle je vždy povolen).
  void toggleTaskDone(String taskId) {
    _localService.toggleTaskDone(taskId);

    final task = _localService.findItemById(taskId);
    if (task != null) {
      _pendingChanges.add({
        'operation': 'toggle',
        'type': 'task',
        'data': task,
        'timestamp': DateTime.now(),
      });

      _attemptSynchronization();
    }
  }

  // === Veřejné metody pro práci s kategoriemi ===

  /// Přidá novou kategorii.
  Future<void> addCategory(TaskCategory category) async {
    await _localService.addCategory(category);

    _pendingChanges.add({
      'operation': 'add',
      'type': 'category',
      'data': category,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Aktualizuje kategorii.
  Future<void> updateCategory(TaskCategory category) async {
    await _localService.updateCategory(category);

    _pendingChanges.add({
      'operation': 'update',
      'type': 'category',
      'data': category,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Odstraní kategorii.
  Future<void> removeCategory(String categoryId) async {
    final category =
        _localService.categories.firstWhere((c) => c.id == categoryId);
    final defaultCategoryId =
        LocalChecklistService.defaultCategories.first['id'] as String;

    await _localService.removeCategory(categoryId);

    _pendingChanges.add({
      'operation': 'remove',
      'type': 'category',
      'data': category,
      'defaultCategoryId': defaultCategoryId,
      'timestamp': DateTime.now(),
    });

    _attemptSynchronization();
  }

  /// Vyčistí všechny úkoly a kategorie.
  void clearAllData() {
    final allTasks = List<Task>.from(_localService.tasks);
    final allCategories = List<TaskCategory>.from(_localService.categories);

    _localService.clearAllItems();

    // Přidáme operace odstranění
    for (final task in allTasks) {
      _pendingChanges.add({
        'operation': 'remove',
        'type': 'task',
        'data': task,
        'timestamp': DateTime.now(),
      });
    }

    for (final category in allCategories) {
      if (!LocalChecklistService.defaultCategories
          .any((c) => c['id'] == category.id)) {
        _pendingChanges.add({
          'operation': 'remove',
          'type': 'category',
          'data': category,
          'timestamp': DateTime.now(),
        });
      }
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
      final cloudTasks = await _cloudService.fetchTasks();
      final cloudCategories = await _cloudService.fetchCategories();

      _localService.removeListener(_handleLocalChanges);
      _localService.setTasksAndCategoriesWithoutNotify(
          cloudTasks, cloudCategories);
      _localService.addListener(_handleLocalChanges);

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ChecklistManager: Chyba při načítání z cloudu: $e");
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
            _localService.tasks, _localService.categories);
      }

      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("ChecklistManager: Chyba při synchronizaci do cloudu: $e");
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

  /// Seznam úkolů.
  List<Task> get tasks => _localService.tasks;

  /// Seznam kategorií.
  List<TaskCategory> get categories => _localService.categories;

  /// Indikátor načítání.
  bool get isLoading =>
      _localService.isLoading || _syncState == SyncState.syncing;

  /// Získá úkoly podle kategorie.
  List<Task> getTasksByCategory(String categoryId) =>
      _localService.getTasksByCategory(categoryId);

  /// Získá dokončené úkoly.
  List<Task> getCompletedTasks() => _localService.getCompletedTasks();

  /// Získá nedokončené úkoly.
  List<Task> getPendingTasks() => _localService.getPendingTasks();

  /// Získá úkoly podle priority.
  List<Task> getTasksByPriority(int priority) =>
      _localService.getTasksByPriority(priority);

  /// Získá úkoly s termínem.
  List<Task> getTasksWithDueDate() => _localService.getTasksWithDueDate();

  /// Získá zpožděné úkoly.
  List<Task> getOverdueTasks() => _localService.getOverdueTasks();

  /// Získá statistiky checklistu.
  Map<String, dynamic> getChecklistStatistics() =>
      _localService.getChecklistStatistics();

  /// Získá statistiky podle kategorií.
  Map<String, Map<String, dynamic>> getCategoryStatistics() =>
      _localService.getCategoryStatistics();

  /// Získá kategorii podle ID.
  TaskCategory? getCategoryById(String id) => _localService.getCategoryById(id);

  @override
  void dispose() {
    _authSubscription?.cancel();
    _tasksCloudSubscription?.cancel();
    _categoriesCloudSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _localService.removeListener(_handleLocalChanges);
    super.dispose();
  }
}
