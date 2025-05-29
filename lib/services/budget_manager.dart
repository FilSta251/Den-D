// lib/services/budget_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/expense.dart';
import '../services/local_budget_service.dart';
import '../services/cloud_budget_service.dart';

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
  
  BudgetManager({
    required LocalBudgetService localService,
    required CloudBudgetService cloudService,
    fb.FirebaseAuth? auth,
  }) : 
    _localService = localService,
    _cloudService = cloudService,
    _auth = auth ?? fb.FirebaseAuth.instance {
    // Okamžitá inicializace při vytvoření instance
    _init();
  }
  
  Future<void> _init() async {
    _setSyncState(SyncState.idle);
    
    // Inicializace sledování připojení k internetu
    _setupConnectivityMonitoring();
    
    // DŮLEŽITÉ: Nejprve se přihlašujeme na stream událostí autentizace
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final newUserId = user.uid;
        // Pokud se přihlásil jiný uživatel než dříve nebo jsme jen teď detekovali přihlášení
        if (_currentUserId != newUserId) {
          debugPrint("Nový uživatel přihlášen: ${user.uid}");
          
          // Uložíme ID aktuálního uživatele
          _currentUserId = newUserId;
          
          // Vyčistíme lokální data před načtením dat nového uživatele
          _localService.removeListener(_handleLocalChanges);
          _localService.clearAllExpenses();
          
          // Provedeme kompletní synchronizaci z cloudu
          await _forceInitialSync();
          
          // Znovu napojíme posluchače změn
          _localService.addListener(_handleLocalChanges);
        } else {
          await _refreshFromCloud();
        }
      } else {
        // Uživatel odhlášen
        _currentUserId = null;
        
        // Vyčistíme lokální data při odhlášení
        _localService.removeListener(_handleLocalChanges);
        _localService.clearAllExpenses();
        
        // Vypneme synchronizaci s cloudem
        _disableCloudSync();
        
        // Znovu aktivujeme lokální změny pro nepřihlášeného uživatele
        _localService.addListener(_handleLocalChanges);
      }
    });
    
    // Pokud je uživatel již přihlášen, okamžitě zahájíme synchronizaci
    if (_auth.currentUser != null) {
      _currentUserId = _auth.currentUser!.uid;
      await _forceInitialSync();
    } else {
      await _loadLocalData();
    }
    
    // Pravidelná synchronizace pro udržení aktuálních dat
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _attemptSynchronization();
    });
    
    // Registrace posluchače lokálních změn
    _localService.addListener(_handleLocalChanges);
  }
  
  // Nastavení sledování připojení k internetu
  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      final isConnected = result.isNotEmpty && result.first != ConnectivityResult.none;
      
      if (isConnected && !_isOnline) {
        // Přechod z offline do online stavu
        debugPrint("Připojení k internetu obnoveno, zahajuji synchronizaci");
        _isOnline = true;
        await _syncPendingChanges();
      } else if (!isConnected && _isOnline) {
        // Přechod z online do offline stavu
        debugPrint("Připojení k internetu ztraceno, přepínám do offline režimu");
        _isOnline = false;
        _setSyncState(SyncState.offline);
      }
      
      notifyListeners();
    });
    
    // Inicializace počátečního stavu připojení
    Connectivity().checkConnectivity().then((result) {
      _isOnline = result.isNotEmpty && result.first != ConnectivityResult.none;
      if (!_isOnline) {
        _setSyncState(SyncState.offline);
      }
    });
  }
  
  // Nastavení stavu synchronizace
  void _setSyncState(SyncState state, [String? error]) {
    _syncState = state;
    _syncError = error;
    if (state == SyncState.idle) {
      _lastSyncTime = DateTime.now();
    }
    notifyListeners();
  }
  
  // Pokus o synchronizaci - spustí se pouze pokud jsme online
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
  
  // Synchronizace lokálních změn do cloudu
  Future<void> _syncPendingChanges() async {
    if (_auth.currentUser == null || !_isOnline) {
      return;
    }
    
    if (_syncState == SyncState.syncing) {
      return; // Již probíhá synchronizace
    }
    
    if (_pendingChanges.isEmpty && _pendingSyncOperations == 0) {
      return; // Nemáme žádné změny k synchronizaci
    }
    
    _setSyncState(SyncState.syncing);
    
    try {
      // Pokud máme konkrétní akce, zpracujeme je
      if (_pendingChanges.isNotEmpty) {
        final List<Map<String, dynamic>> changesToProcess = List.from(_pendingChanges);
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
      } 
      // Nemáme konkrétní akce, ale máme změny v datech - sync celé kolekce
      else if (_pendingSyncOperations > 0) {
        await _cloudService.syncFromLocal(_localService.expenses);
        _pendingSyncOperations = 0;
      }
      
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("Chyba při synchronizaci změn: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }
  
  // Nová metoda pro forsírovanou inicializační synchronizaci
  Future<void> _forceInitialSync() async {
    if (_syncState == SyncState.syncing) return;
    
    _setSyncState(SyncState.syncing);
    
    try {
      // Načtení poslední synchronizace z cloudu
      final lastCloudSync = await _cloudService.getLastSyncTimestamp();
      
      // 1. Nejprve načteme data z cloudu
      final cloudExpenses = await _cloudService.fetchExpenses();
      
      // 2. Poté načteme lokální data
      await _loadLocalData();
      
      // 3. Určíme, co použijeme:
      if (cloudExpenses.isNotEmpty) {
        // Vypneme posluchače změn, abychom předešli zbytečným notifikacím
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
      } 
      // Pokud máme lokální data, ale cloud je prázdný, nahrajeme na cloud
      else if (_localService.expenses.isNotEmpty && _isOnline) {
        await _cloudService.syncFromLocal(_localService.expenses);
      }
      
      // 4. Nyní zahájíme sledování změn v cloudu
      _enableCloudSync();
      
      _initialized = true;
      _setSyncState(SyncState.idle);
      
    } catch (e) {
      debugPrint("Chyba při inicializační synchronizaci: $e");
      _setSyncState(SyncState.error, e.toString());
    }
  }
  
  // Metoda pro aktualizaci dat z cloudu
  Future<void> _refreshFromCloud() async {
    if (!_isOnline || _auth.currentUser == null) return;
    
    try {
      final cloudExpenses = await _cloudService.fetchExpenses();
      
      if (cloudExpenses.isNotEmpty) {
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Chyba při aktualizaci z cloudu: $e");
      // Nezobrazujeme uživateli tyto chyby, pouze logujeme
    }
  }
  
  Future<void> _loadLocalData() async {
    if (!_localDataLoaded) {
      await _localService.loadExpenses();
      _localDataLoaded = true;
    }
  }
  
  /// Zapne synchronizaci s cloudem.
  void _enableCloudSync() {
    if (!_cloudSyncEnabled || _auth.currentUser == null) {
      return;
    }
    
    // Zaregistrujeme poslech změn z cloudu
    _cloudSubscription?.cancel();
    _cloudSubscription = _cloudService.getExpensesStream().listen((cloudExpenses) {
      if (cloudExpenses.isNotEmpty) {
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
        
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("Chyba ve streamu cloudových dat: $error");
    });
  }
  
  /// Vypne synchronizaci s cloudem.
  void _disableCloudSync() {
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
    _initialized = false;
  }
  
  /// Reaguje na změny v lokálním úložišti.
  void _handleLocalChanges() {
    // Inkrementujeme počítadlo nevyřízených synchronizací
    _pendingSyncOperations++;
    
    // Zahájíme synchronizaci do cloudu s debounce
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      _attemptSynchronization();
    });
  }
  
  /// Přidá nový výdaj do rozpočtu.
  void addExpense(Expense expense) {
    _localService.addExpense(expense);
    
    // Přidáme operaci do fronty změn
    _pendingChanges.add({
      'operation': 'add',
      'expense': expense,
      'timestamp': DateTime.now(),
    });
    
    _attemptSynchronization();
  }
  
  /// Aktualizuje existující výdaj v rozpočtu.
  void updateExpense(Expense expense) {
    _localService.updateExpense(expense);
    
    // Přidáme operaci do fronty změn
    _pendingChanges.add({
      'operation': 'update',
      'expense': expense,
      'timestamp': DateTime.now(),
    });
    
    _attemptSynchronization();
  }
  
  /// Odstraní výdaj z rozpočtu.
  void removeExpense(String expenseId) {
    // Nejprve si uložíme referenci na výdaj před odstraněním
    final expense = _localService.getExpenseById(expenseId);
    if (expense == null) return;
    
    _localService.removeExpense(expenseId);
    
    // Přidáme operaci do fronty změn
    _pendingChanges.add({
      'operation': 'remove',
      'expense': expense,
      'timestamp': DateTime.now(),
    });
    
    _attemptSynchronization();
  }
  
  /// Vyčistí všechny výdaje rozpočtu.
  void clearAllExpenses() {
    // Vytvoříme kopii všech výdajů před smazáním
    final allExpenses = List<Expense>.from(_localService.expenses);
    
    _localService.clearAllExpenses();
    
    // Přidáme operace odstranění pro každý výdaj
    for (final expense in allExpenses) {
      _pendingChanges.add({
        'operation': 'remove',
        'expense': expense,
        'timestamp': DateTime.now(),
      });
    }
    
    _attemptSynchronization();
  }
  
  /// Vynucené načtení výdajů z cloudu - veřejná metoda pro přímé volání z UI
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
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
      }
      
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("Chyba při načítání z cloudu: $e");
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
      
      // Pokud nemáme žádné konkrétní změny, synchronizujeme vše
      if (_pendingChanges.isEmpty) {
        await _cloudService.syncFromLocal(_localService.expenses);
      }
      
      _setSyncState(SyncState.idle);
    } catch (e) {
      debugPrint("Chyba při synchronizaci do cloudu: $e");
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
  bool get isLoading => _localService.isLoading || _syncState == SyncState.syncing;
  
  /// Vypočítá celkovou zaplacenou částku
  double get totalPaid => expenses.fold(0.0, (sum, exp) => sum + exp.paid);
  
  /// Vypočítá celkovou očekávanou částku
  double get totalPending => expenses.fold(0.0, (sum, exp) => sum + exp.pending);
  
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