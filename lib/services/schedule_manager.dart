// lib/services/schedule_manager.dart - KOMPLETNÍ OPRAVENÁ VERZE

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/local_schedule_service.dart';
import '../services/cloud_schedule_service.dart';

/// Manager pro synchronizaci harmonogramu mezi lokálním úložištěm a cloudem.
class ScheduleManager extends ChangeNotifier {
  final LocalScheduleService _localService;
  final CloudScheduleService _cloudService;
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
  
  ScheduleManager({
    required LocalScheduleService localService,
    required CloudScheduleService cloudService,
    required fb.FirebaseAuth auth,
  }) : 
    _localService = localService,
    _cloudService = cloudService,
    _auth = auth {
    // Okamžitá inicializace při vytvoření instance
    _init();
  }
  
  Future<void> _init() async {
    debugPrint("=== INICIALIZACE SCHEDULE MANAGER ===");
    
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
          _localService.clearAllItems();
          
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
        _localService.clearAllItems();
        
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
        debugPrint("=== PERIODICKÁ SYNCHRONIZACE ===");
        await _refreshFromCloud();
      }
    });
  }
  
  // Nová metoda pro forsírovanou inicializační synchronizaci
  Future<void> _forceInitialSync() async {
    debugPrint("=== FORSÍROVANÁ INICIALIZAČNÍ SYNCHRONIZACE ===");
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      // 1. Nejprve načteme data z cloudu
      final cloudItems = await _cloudService.fetchScheduleItems();
      debugPrint("=== NAČTENO ${cloudItems.length} POLOŽEK Z CLOUDU ===");
      
      // 2. Poté načteme lokální data
      await _loadLocalData();
      debugPrint("=== NAČTENO ${_localService.scheduleItems.length} POLOŽEK Z LOKÁLU ===");
      
      // 3. Určíme, co použijeme:
      
      // KRITICKÁ ZMĚNA: Pokud máme data v cloudu, použijeme VŽDY cloud jako zdroj pravdy
      if (cloudItems.isNotEmpty) {
        debugPrint("=== POUŽÍVÁM DATA Z CLOUDU JAKO ZDROJ PRAVDY ===");
        
        // Vypneme posluchače změn, abychom předešli zbytečným notifikacím
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setItemsWithoutNotify(cloudItems);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
      } 
      // Pokud máme lokální data, ale cloud je prázdný, nahrajeme na cloud
      else if (_localService.scheduleItems.isNotEmpty) {
        debugPrint("=== NAHRÁVÁM LOKÁLNÍ DATA DO CLOUDU ===");
        await _cloudService.syncFromLocal(_localService.scheduleItems);
      }
      
      // 4. Nyní zahájíme sledování změn v cloudu
      _enableCloudSync();
      
      _initialized = true;
      
    } catch (e) {
      debugPrint("=== CHYBA PŘI INICIALIZAČNÍ SYNCHRONIZACI: $e ===");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  // Nová metoda pro aktualizaci dat z cloudu s jasným logem
  Future<void> _refreshFromCloud() async {
    try {
      if (_auth.currentUser == null) return;
      
      debugPrint("=== AKTUALIZUJI DATA Z CLOUDU ===");
      final cloudItems = await _cloudService.fetchScheduleItems();
      
      if (cloudItems.isNotEmpty) {
        debugPrint("=== NAČTENO ${cloudItems.length} POLOŽEK Z CLOUDU ===");
        
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setItemsWithoutNotify(cloudItems);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
        
        notifyListeners();
      }
    } catch (e) {
      debugPrint("=== CHYBA PŘI AKTUALIZACI Z CLOUDU: $e ===");
    }
  }
  
  Future<void> _loadLocalData() async {
    if (!_localDataLoaded) {
      debugPrint("=== NAČÍTÁM LOKÁLNÍ DATA ===");
      await _localService.loadScheduleItems();
      _localDataLoaded = true;
      debugPrint("=== LOKÁLNÍ DATA NAČTENA: ${_localService.scheduleItems.length} POLOŽEK ===");
    }
  }
  
  /// Zapne synchronizaci s cloudem.
  void _enableCloudSync() {
    if (!_cloudSyncEnabled) {
      debugPrint("=== CLOUD SYNC JE VYPNUTÝ V NASTAVENÍ ===");
      return;
    }
    
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE ZAPNOUT CLOUD SYNC - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      return;
    }
    
    debugPrint("=== ZAPÍNÁM CLOUD SYNC ===");
    
    // Zaregistrujeme poslech změn z cloudu
    _cloudSubscription?.cancel();
    _cloudSubscription = _cloudService.getScheduleItemsStream().listen((dynamic cloudItemsObj) {
      if (cloudItemsObj is List<ScheduleItem>) {
        final cloudItems = cloudItemsObj;
        debugPrint("=== STREAM: PŘIJATO ${cloudItems.length} POLOŽEK Z CLOUDU ===");
        
        if (cloudItems.isNotEmpty) {
          // Vypneme posluchače změn
          _localService.removeListener(_handleLocalChanges);
          
          // Nahradíme lokální data daty z cloudu
          _localService.setItemsWithoutNotify(cloudItems);
          
          // Zapneme posluchače zpět
          _localService.addListener(_handleLocalChanges);
          
          notifyListeners();
        }
      } else {
        debugPrint("=== CHYBA: NEPLATNÝ TYP DAT Z CLOUDU: ${cloudItemsObj.runtimeType} ===");
      }
    }, onError: (error) {
      debugPrint("=== CHYBA VE STREAMU CLOUDOVÝCH DAT: $error ===");
    });
  }
  
  /// Vypne synchronizaci s cloudem.
  void _disableCloudSync() {
    debugPrint("=== VYPÍNÁM CLOUD SYNC ===");
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
    _initialized = false;
  }
  
  /// Reaguje na změny v lokálním úložišti.
  void _handleLocalChanges() {
    if (!_cloudSyncEnabled || _auth.currentUser == null) {
      debugPrint("=== ZMĚNA V LOKÁLNÍCH DATECH, ALE CLOUD SYNC NENÍ AKTIVNÍ ===");
      return;
    }
    
    // Zahájíme synchronizaci do cloudu - s krátkým zpožděním pro debounce
    debugPrint("=== ZMĚNA V LOKÁLNÍCH DATECH, SYNCHRONIZUJI DO CLOUDU ===");
    
    // Zrušíme případný předchozí časovač
    _debounceTimer?.cancel();
    
    // Vytvoříme nový časovač
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _syncToCloud();
    });
  }
  
  /// Synchronizuje lokální data do cloudu.
  Future<void> _syncToCloud() async {
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE SYNCHRONIZOVAT DO CLOUDU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      return;
    }
    
    if (_localService.scheduleItems.isEmpty) {
      debugPrint("=== LOKÁLNÍ DATA JSOU PRÁZDNÁ, NEPROVÁDÍM SYNC DO CLOUDU ===");
      return;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      debugPrint("=== SYNCHRONIZUJI ${_localService.scheduleItems.length} POLOŽEK DO CLOUDU ===");
      await _cloudService.syncFromLocal(_localService.scheduleItems);
      debugPrint("=== SYNCHRONIZACE DO CLOUDU DOKONČENA ===");
    } catch (e) {
      debugPrint("=== CHYBA PŘI NAHRÁVÁNÍ DO CLOUDU: $e ===");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Přidá novou položku do harmonogramu.
  void addItem(ScheduleItem item) {
    debugPrint("=== PŘIDÁVÁM NOVOU POLOŽKU: ${item.title} ===");
    _localService.addItem(item);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Aktualizuje existující položku v harmonogramu.
  void updateItem(int index, ScheduleItem item) {
    debugPrint("=== AKTUALIZUJI POLOŽKU: ${item.title} ===");
    _localService.updateItem(index, item);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Odstraní položku z harmonogramu.
  void removeItem(int index) {
    debugPrint("=== ODSTRAŇUJI POLOŽKU ===");
    _localService.removeItem(index);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Změní pořadí položek v harmonogramu.
  void reorderItems(int oldIndex, int newIndex) {
    debugPrint("=== MĚNÍM POŘADÍ POLOŽEK ===");
    _localService.reorderItems(oldIndex, newIndex);
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Vyčistí všechny položky harmonogramu.
  void clearAllItems() {
    debugPrint("=== MAŽU VŠECHNY POLOŽKY ===");
    _localService.clearAllItems();
    
    // Okamžitě synchronizujeme do cloudu
    if (_auth.currentUser != null && _cloudSyncEnabled) {
      _syncToCloud();
    }
  }
  
  /// Vynucené načtení položek z cloudu - veřejná metoda pro přímé volání z UI
  Future<void> forceRefreshFromCloud() async {
    debugPrint("=== VYNUCENÉ NAČTENÍ Z CLOUDU (veřejná metoda) ===");
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE NAČÍST DATA Z CLOUDU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      await _loadLocalData();
      return;
    }
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final cloudItems = await _cloudService.fetchScheduleItems();
      debugPrint("=== NAČTENO ${cloudItems.length} POLOŽEK Z CLOUDU ===");
      
      if (cloudItems.isNotEmpty) {
        // Vypneme posluchače změn
        _localService.removeListener(_handleLocalChanges);
        
        // Nahradíme lokální data daty z cloudu
        _localService.setItemsWithoutNotify(cloudItems);
        
        // Zapneme posluchače zpět
        _localService.addListener(_handleLocalChanges);
      } else {
        debugPrint("=== Z CLOUDU NEBYLY NAČTENY ŽÁDNÉ POLOŽKY ===");
      }
    } catch (e) {
      debugPrint("=== CHYBA PŘI NAČÍTÁNÍ Z CLOUDU: $e ===");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Vynucená synchronizace do cloudu.
  Future<void> forceSyncToCloud() async {
    debugPrint("=== VYNUCENÁ SYNCHRONIZACE DO CLOUDU ===");
    if (_auth.currentUser == null) {
      debugPrint("=== NELZE SYNCHRONIZOVAT DO CLOUDU - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      return;
    }
    
    await _syncToCloud();
  }
  
  /// Zapne/vypne cloudovou synchronizaci.
  set cloudSyncEnabled(bool value) {
    debugPrint("=== NASTAVUJI CLOUDOVOU SYNCHRONIZACI NA: $value ===");
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
  
  /// Exportuje položky harmonogramu do JSON formátu.
  String exportToJson() {
    return _localService.exportToJson();
  }
  
  /// Importuje položky harmonogramu z JSON formátu.
  Future<void> importFromJson(String jsonData) async {
    await _localService.importFromJson(jsonData);
  }
  
  /// Seznam položek harmonogramu.
  List<ScheduleItem> get scheduleItems => _localService.scheduleItems;
  
  /// Indikátor načítání.
  bool get isLoading => _localService.isLoading || _isSyncing;
  
  /// VEŘEJNÁ METODA pro kompatibilitu s main.dart
  /// Synchronizuje data - alias pro interní synchronizační metody
  Future<void> synchronizeData() async {
    debugPrint("=== VOLÁNA METODA synchronizeData() Z MAIN.DART ===");
    if (_auth.currentUser == null) {
      debugPrint("=== UŽIVATEL NENÍ PŘIHLÁŠEN, PROVÁDÍM POUZE NAČTENÍ LOKÁLNÍCH DAT ===");
      await _loadLocalData();
      return;
    }
    
    await _refreshFromCloud();
  }
  
  @override
  void dispose() {
    debugPrint("=== UKONČUJI SCHEDULE MANAGER ===");
    _authSubscription?.cancel();  // Zrušení posluchače autentizace
    _cloudSubscription?.cancel();
    _syncTimer?.cancel();
    _debounceTimer?.cancel();
    _localService.removeListener(_handleLocalChanges);
    super.dispose();
  }
}