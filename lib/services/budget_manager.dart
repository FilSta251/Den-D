// lib/services/budget_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/expense.dart';
import '../services/local_budget_service.dart';
import '../services/cloud_budget_service.dart';

/// Manager pro synchronizaci položek rozpočtu mezi lokálním úložištěm a cloudem.
/// 
/// DŮLEŽITÉ: Tento manager spravuje pouze jednotlivé položky výdajů (Expense),
/// nikoliv celkový rozpočet svatby, který je uložen v kolekci wedding_info a
/// je spravován prostřednictvím WeddingRepository.
class BudgetManager extends ChangeNotifier {
  final LocalBudgetService _localService;
  final CloudBudgetService _cloudService;
  final fb.FirebaseAuth _auth;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  StreamSubscription? _cloudSubscription;
  StreamSubscription? _authSubscription;
  bool _initialized = false;
  bool _localDataLoaded = false;
  Timer? _syncTimer;
  Timer? _debounceTimer;
  String? _currentUserId;
  
  bool _cloudSyncEnabled = true;
  bool get cloudSyncEnabled => _cloudSyncEnabled;
  
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
    debugPrint("=== INICIALIZACE BUDGET MANAGER ===");
    
    // DŮLEŽITÉ: Nejprve se přihlašujeme na stream událostí autentizace
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        final newUserId = user.uid;
        // Pokud se přihlásil jiný uživatel než dříve nebo jsme jen teď detekovali přihlášení
        if (_currentUserId != newUserId) {
          debugPrint("=== PŘIHLÁŠEN NOVÝ UŽIVATEL: ${user.uid} ===");
          
          // Uložíme ID aktuálního uživatele
          _currentUserId = newUserId;
          
          // Vyčistíme lokální data před načtením dat nového uživatele
          // DŮLEŽITÉ: Vypneme posluchače změn před čištěním, aby se nevyvolaly zbytečné synchronizace
          _localService.removeListener(_handleLocalChanges);
          _localService.clearAllExpenses();
          
          // Provedeme kompletní synchronizaci z cloudu
          await _forceInitialSync();
          
          // Znovu napojíme posluchače změn
          _localService.addListener(_handleLocalChanges);
        } else {
          debugPrint("=== UŽIVATEL ZŮSTÁVÁ PŘIHLÁŠEN: ${user.uid} ===");
          await _refreshFromCloud();
        }
      } else {
        debugPrint("=== UŽIVATEL ODHLÁŠEN ===");
        // Vyčistíme ID uživatele
        _currentUserId = null;
        
        // Vyčistíme lokální data při odhlášení
        // DŮLEŽITÉ: Vypneme posluchače změn před čištěním
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
      debugPrint("=== UŽIVATEL JIŽ PŘIHLÁŠEN PŘI STARTU: $_currentUserId ===");
      await _forceInitialSync();
    } else {
      debugPrint("=== UŽIVATEL NENÍ PŘIHLÁŠEN PŘI STARTU ===");
      await _loadLocalData();
    }
    
    // Pravidelná synchronizace pro udržení aktuálních dat
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      if (_auth.currentUser != null && _cloudSyncEnabled) {
        debugPrint("=== PERIODICKÁ SYNCHRONIZACE POLOŽEK ROZPOČTU ===");
        await _refreshFromCloud();
      }
    });
    
    // Registrace posluchače lokálních změn
    _localService.addListener(_handleLocalChanges);
  }
  
  /// Synchronizuje lokální data do cloudu.
  Future<void> _syncToCloud() async {
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE SYNCHRONIZOVAT POLOŽKY ROZPOČTU DO CLOUDU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      return;
    }
    
    if (_localService.expenses.isEmpty) {
      debugPrint("=== LOKÁLNÍ POLOŽKY ROZPOČTU JSOU PRÁZDNÉ, NEPROVÁDÍM SYNC DO CLOUDU ===");
      return;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      debugPrint("=== SYNCHRONIZUJI ${_localService.expenses.length} POLOŽEK ROZPOČTU DO CLOUDU ===");
      await _cloudService.syncFromLocal(_localService.expenses);
      debugPrint("=== SYNCHRONIZACE POLOŽEK ROZPOČTU DO CLOUDU DOKONČENA ===");
    } catch (e) {
      debugPrint("=== CHYBA PŘI NAHRÁVÁNÍ POLOŽEK ROZPOČTU DO CLOUDU: $e ===");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Nová metoda pro forsírovanou inicializační synchronizaci
  Future<void> _forceInitialSync() async {
    debugPrint("=== FORSÍROVANÁ INICIALIZAČNÍ SYNCHRONIZACE POLOŽEK ROZPOČTU ===");
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      // 1. Nejprve načteme data z cloudu
      final cloudExpenses = await _cloudService.fetchExpenses();
      debugPrint("=== NAČTENO ${cloudExpenses.length} POLOŽEK ROZPOČTU Z CLOUDU ===");
      
      // 2. Poté načteme lokální data
      await _loadLocalData();
      debugPrint("=== NAČTENO ${_localService.expenses.length} POLOŽEK ROZPOČTU Z LOKÁLU ===");
      
      // 3. Určíme, co použijeme:
      
      // KRITICKÁ ZMĚNA: Pokud máme data v cloudu, použijeme VŽDY cloud jako zdroj pravdy
      if (cloudExpenses.isNotEmpty) {
        debugPrint("=== POUŽÍVÁM DATA Z CLOUDU JAKO ZDROJ PRAVDY ===");
        
        // Vypneme posluchače změn, abychom předešli zbytečným notifikacím
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
      } 
      // Pokud máme lokální data, ale cloud je prázdný, nahrajeme na cloud
      else if (_localService.expenses.isNotEmpty) {
        debugPrint("=== NAHRÁVÁM LOKÁLNÍ POLOŽKY ROZPOČTU DO CLOUDU ===");
        await _cloudService.syncFromLocal(_localService.expenses);
      }
      
      // 4. Nyní zahájíme sledování změn v cloudu
      _enableCloudSync();
      
      _initialized = true;
      
    } catch (e) {
      debugPrint("=== CHYBA PŘI INICIALIZAČNÍ SYNCHRONIZACI POLOŽEK ROZPOČTU: $e ===");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Metoda pro aktualizaci dat z cloudu s jasným logem
  Future<void> _refreshFromCloud() async {
    try {
      if (_auth.currentUser == null) return;
      
      debugPrint("=== AKTUALIZUJI POLOŽKY ROZPOČTU Z CLOUDU ===");
      final cloudExpenses = await _cloudService.fetchExpenses();
      
      if (cloudExpenses.isNotEmpty) {
        debugPrint("=== NAČTENO ${cloudExpenses.length} POLOŽEK ROZPOČTU Z CLOUDU ===");
        
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("=== CHYBA PŘI AKTUALIZACI POLOŽEK ROZPOČTU Z CLOUDU: $e ===");
    }
  }
  
  Future<void> _loadLocalData() async {
    if (!_localDataLoaded) {
      debugPrint("=== NAČÍTÁM LOKÁLNÍ POLOŽKY ROZPOČTU ===");
      await _localService.loadExpenses();
      _localDataLoaded = true;
      debugPrint("=== LOKÁLNÍ POLOŽKY ROZPOČTU NAČTENY: ${_localService.expenses.length} POLOŽEK ===");
    }
  }
  
  /// Zapne synchronizaci s cloudem.
  void _enableCloudSync() {
    if (!_cloudSyncEnabled) {
      debugPrint("=== CLOUD SYNC POLOŽEK ROZPOČTU JE VYPNUTÝ V NASTAVENÍ ===");
      return;
    }
    
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE ZAPNOUT CLOUD SYNC POLOŽEK ROZPOČTU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      return;
    }
    
    debugPrint("=== ZAPÍNÁM CLOUD SYNC POLOŽEK ROZPOČTU ===");
    
    // Zaregistrujeme poslech změn z cloudu
    _cloudSubscription?.cancel();
    _cloudSubscription = _cloudService.getExpensesStream().listen((cloudExpenses) {
      debugPrint("=== STREAM: PŘIJATO ${cloudExpenses.length} POLOŽEK ROZPOČTU Z CLOUDU ===");
      
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
      debugPrint("=== CHYBA VE STREAMU CLOUDOVÝCH DAT POLOŽEK ROZPOČTU: $error ===");
    });
  }
  
  /// Vypne synchronizaci s cloudem.
  void _disableCloudSync() {
    debugPrint("=== VYPÍNÁM CLOUD SYNC POLOŽEK ROZPOČTU ===");
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
    _initialized = false;
  }
  
  /// Reaguje na změny v lokálním úložišti.
  void _handleLocalChanges() {
    if (!_cloudSyncEnabled || _auth.currentUser == null) {
      debugPrint("=== ZMĚNA V LOKÁLNÍCH DATECH POLOŽEK ROZPOČTU, ALE CLOUD SYNC NENÍ AKTIVNÍ ===");
      return;
    }
    
    // Zahájíme synchronizaci do cloudu - s krátkým zpožděním pro debounce
    debugPrint("=== ZMĚNA V LOKÁLNÍCH DATECH POLOŽEK ROZPOČTU, SYNCHRONIZUJI DO CLOUDU ===");
    
    // Zrušíme případný předchozí časovač
    _debounceTimer?.cancel();
    
    // Vytvoříme nový časovač
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _syncToCloud();
    });
  }
  
  /// Přidá nový výdaj do rozpočtu.
  void addExpense(Expense expense) {
    debugPrint("=== PŘIDÁVÁM NOVÝ VÝDAJ: ${expense.title} ===");
    _localService.addExpense(expense);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Aktualizuje existující výdaj v rozpočtu.
  void updateExpense(Expense expense) {
    debugPrint("=== AKTUALIZUJI VÝDAJ: ${expense.title} ===");
    _localService.updateExpense(expense);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Odstraní výdaj z rozpočtu.
  void removeExpense(String expenseId) {
    debugPrint("=== ODSTRAŇUJI VÝDAJ ===");
    _localService.removeExpense(expenseId);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Vyčistí všechny výdaje rozpočtu.
  void clearAllExpenses() {
    debugPrint("=== MAŽU VŠECHNY VÝDAJE ===");
    _localService.clearAllExpenses();
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Vynucené načtení výdajů z cloudu - veřejná metoda pro přímé volání z UI
  Future<void> forceRefreshFromCloud() async {
    debugPrint("=== VYNUCENÉ NAČTENÍ POLOŽEK ROZPOČTU Z CLOUDU (veřejná metoda) ===");
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE NAČÍST POLOŽKY ROZPOČTU Z CLOUDU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      await _loadLocalData();
      return;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final cloudExpenses = await _cloudService.fetchExpenses();
      debugPrint("=== NAČTENO ${cloudExpenses.length} POLOŽEK ROZPOČTU Z CLOUDU ===");
      
      if (cloudExpenses.isNotEmpty) {
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setExpensesWithoutNotify(cloudExpenses);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
      } else {
        debugPrint("=== Z CLOUDU NEBYLY NAČTENY ŽÁDNÉ POLOŽKY ROZPOČTU ===");
      }
    } catch (e) {
      debugPrint("=== CHYBA PŘI NAČÍTÁNÍ POLOŽEK ROZPOČTU Z CLOUDU: $e ===");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Vynucená synchronizace do cloudu.
  Future<void> forceSyncToCloud() async {
    debugPrint("=== VYNUCENÁ SYNCHRONIZACE POLOŽEK ROZPOČTU DO CLOUDU ===");
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE SYNCHRONIZOVAT POLOŽKY ROZPOČTU DO CLOUDU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      return;
    }
    
    await _syncToCloud();
  }
  
  /// Zapne/vypne cloudovou synchronizaci.
  set cloudSyncEnabled(bool value) {
    debugPrint("=== NASTAVUJI CLOUDOVOU SYNCHRONIZACI POLOŽEK ROZPOČTU NA: $value ===");
    _cloudSyncEnabled = value;
    if (value) {
      if (_auth.currentUser != null) {
        _enableCloudSync();
      }
    } else {
      _disableCloudSync();
    }
    notifyListeners();
  }
  
  /// Exportuje položky rozpočtu do JSON formátu.
  String exportToJson() {
    return _localService.exportToJson();
  }
  
  /// Importuje položky rozpočtu z JSON formátu.
  Future<void> importFromJson(String jsonData) async {
    await _localService.importFromJson(jsonData);
  }
  
  /// Seznam výdajů rozpočtu.
  List<Expense> get expenses => _localService.expenses;
  
  /// Indikátor načítání.
  bool get isLoading => _localService.isLoading || _isSyncing;
  
  /// Vypočítá celkovou zaplacenou částku
  double get totalPaid => expenses.fold(0.0, (sum, exp) => sum + exp.paid);
  
  /// Vypočítá celkovou očekávanou částku
  double get totalPending => expenses.fold(0.0, (sum, exp) => sum + exp.pending);
  
  /// Vypočítá celkové výdaje (zaplacené + očekávané)
  double get totalExpenses => totalPaid + totalPending;
  
  @override
  void dispose() {
    debugPrint("=== UKONČUJI BUDGET MANAGER ===");
    _authSubscription?.cancel();  // Zrušení posluchače autentizace
    _cloudSubscription?.cancel();
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _localService.removeListener(_handleLocalChanges);
    super.dispose();
  }
}