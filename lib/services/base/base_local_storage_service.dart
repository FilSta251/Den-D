// lib/services/base/base_local_storage_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstraktní základní třída pro služby pracující s lokálním úložištěm.
/// 
/// Poskytuje společnou funkcionalitu pro ukládání, načítání a správu dat
/// v lokálním úložišti pomocí SharedPreferences.
/// 
/// Výhody použití:
/// - Jednotný přístup k ukládání a načítání dat
/// - Automatické debounce ukládání
/// - Správa stavu načítání
/// - Časové značky poslední synchronizace
/// - Ošetření chyb
abstract class BaseLocalStorageService<T> extends ChangeNotifier {
  /// Klíč pro ukládání dat v SharedPreferences
  final String storageKey;
  
  /// Seznam položek spravovaných touto službou
  List<T> _items = [];
  
  /// Timer pro debounce ukládání
  Timer? _saveDebounce;
  
  /// Příznak, zda probíhá načítání
  bool _isLoading = false;
  
  /// Časová značka poslední synchronizace
  DateTime _lastSyncTimestamp = DateTime(2000);
  
  /// Konstruktor vyžadující klíč pro ukládání
  BaseLocalStorageService({required this.storageKey}) {
    _initializeService();
  }
  
  /// Inicializace služby - načte data při vytvoření
  void _initializeService() {
    loadItems();
  }
  
  /// Getter pro seznam položek
  List<T> get items => List.unmodifiable(_items);
  
  /// Getter pro stav načítání
  bool get isLoading => _isLoading;
  
  /// Getter pro časovou značku poslední synchronizace
  DateTime get lastSyncTimestamp => _lastSyncTimestamp;
  
  /// Abstraktní metoda pro převod položky na JSON
  Map<String, dynamic> itemToJson(T item);
  
  /// Abstraktní metoda pro vytvoření položky z JSON
  T itemFromJson(Map<String, dynamic> json);
  
  /// Abstraktní metoda pro získání časové značky položky
  DateTime getItemTimestamp(T item);
  
  /// Načte položky z lokálního úložiště
  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("=== ${runtimeType}: NAČÍTÁM DATA Z ÚLOŽIŠTĚ ===");
      
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(storageKey);
      
      if (storedData != null && storedData.isNotEmpty) {
        final List<dynamic> jsonData = jsonDecode(storedData);
        _items = jsonData
            .map((json) => itemFromJson(json as Map<String, dynamic>))
            .toList();
      }
      
      _updateLastSyncTimestamp();
      
      debugPrint("=== ${runtimeType}: NAČTENO ${_items.length} POLOŽEK ===");
    } catch (e) {
      debugPrint("=== ${runtimeType}: CHYBA PŘI NAČÍTÁNÍ: $e ===");
      _handleLoadError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Uloží položky do lokálního úložiště
  Future<void> saveItems() async {
    try {
      debugPrint("=== ${runtimeType}: UKLÁDÁM DATA DO ÚLOŽIŠTĚ ===");
      
      final prefs = await SharedPreferences.getInstance();
      final data = _items.map((item) => itemToJson(item)).toList();
      final String jsonData = jsonEncode(data);
      
      await prefs.setString(storageKey, jsonData);
      
      _updateLastSyncTimestamp();
      
      debugPrint("=== ${runtimeType}: ULOŽENO ${_items.length} POLOŽEK ===");
    } catch (e) {
      debugPrint("=== ${runtimeType}: CHYBA PŘI UKLÁDÁNÍ: $e ===");
      _handleSaveError(e);
    }
  }
  
  /// Přidá novou položku
  void addItem(T item) {
    debugPrint("=== ${runtimeType}: PŘIDÁVÁM NOVOU POLOŽKU ===");
    _items.add(item);
    _notifyChange();
  }
  
  /// Odebere položku podle indexu
  void removeItemAt(int index) {
    if (index < 0 || index >= _items.length) {
      debugPrint("=== ${runtimeType}: NEPLATNÝ INDEX PRO ODEBRÁNÍ: $index ===");
      return;
    }
    
    debugPrint("=== ${runtimeType}: ODEBÍRÁM POLOŽKU NA INDEXU $index ===");
    _items.removeAt(index);
    _notifyChange();
  }
  
  /// Odebere položku podle podmínky
  void removeItemWhere(bool Function(T) test) {
    final removedCount = _items.length;
    _items.removeWhere(test);
    final removed = removedCount - _items.length;
    
    if (removed > 0) {
      debugPrint("=== ${runtimeType}: ODEBRÁNO $removed POLOŽEK ===");
      _notifyChange();
    }
  }
  
  /// Aktualizuje položku na daném indexu
  void updateItemAt(int index, T updatedItem) {
    if (index < 0 || index >= _items.length) {
      debugPrint("=== ${runtimeType}: NEPLATNÝ INDEX PRO AKTUALIZACI: $index ===");
      return;
    }
    
    debugPrint("=== ${runtimeType}: AKTUALIZUJI POLOŽKU NA INDEXU $index ===");
    _items[index] = updatedItem;
    _notifyChange();
  }
  
  /// Aktualizuje položku podle podmínky
  void updateItemWhere(bool Function(T) test, T Function(T) update) {
    var updated = false;
    
    for (var i = 0; i < _items.length; i++) {
      if (test(_items[i])) {
        _items[i] = update(_items[i]);
        updated = true;
      }
    }
    
    if (updated) {
      debugPrint("=== ${runtimeType}: AKTUALIZOVÁNY VYBRANÉ POLOŽKY ===");
      _notifyChange();
    }
  }
  
  /// Přeuspořádá položky
  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length || 
        newIndex < 0 || newIndex > _items.length) {
      debugPrint("=== ${runtimeType}: NEPLATNÉ INDEXY PRO PŘEUSPOŘÁDÁNÍ ===");
      return;
    }
    
    if (newIndex > oldIndex) newIndex--;
    
    debugPrint("=== ${runtimeType}: PŘEUSPOŘÁDÁVÁM Z $oldIndex NA $newIndex ===");
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _notifyChange();
  }
  
  /// Vloží položku na danou pozici
  void insertItemAt(int index, T item) {
    if (index < 0 || index > _items.length) {
      debugPrint("=== ${runtimeType}: NEPLATNÝ INDEX PRO VLOŽENÍ: $index ===");
      return;
    }
    
    debugPrint("=== ${runtimeType}: VKLÁDÁM POLOŽKU NA INDEX $index ===");
    _items.insert(index, item);
    _notifyChange();
  }
  
  /// Vymaže všechny položky
  void clearAllItems() {
    debugPrint("=== ${runtimeType}: MAŽU VŠECHNY POLOŽKY ===");
    _items.clear();
    _notifyChange();
  }
  
  /// Nastaví položky bez notifikace (pro synchronizaci)
  void setItemsWithoutNotify(List<T> items) {
    debugPrint("=== ${runtimeType}: NASTAVUJI ${items.length} POLOŽEK BEZ NOTIFIKACE ===");
    _items = List.from(items);
    saveItems(); // Uložíme bez debounce
  }
  
  /// Exportuje data do JSON
  String exportToJson() {
    debugPrint("=== ${runtimeType}: EXPORTUJI DATA DO JSON ===");
    return jsonEncode(_items.map((item) => itemToJson(item)).toList());
  }
  
  /// Importuje data z JSON
  Future<void> importFromJson(String jsonData) async {
    debugPrint("=== ${runtimeType}: IMPORTUJI DATA Z JSON ===");
    
    try {
      final List<dynamic> data = jsonDecode(jsonData);
      _items = data
          .map((json) => itemFromJson(json as Map<String, dynamic>))
          .toList();
      _notifyChange();
    } catch (e) {
      debugPrint("=== ${runtimeType}: CHYBA PŘI IMPORTU: $e ===");
      _handleImportError(e);
    }
  }
  
  /// Najde položku podle podmínky
  T? findItem(bool Function(T) test) {
    try {
      return _items.firstWhere(test);
    } catch (_) {
      return null;
    }
  }
  
  /// Najde všechny položky podle podmínky
  List<T> findItems(bool Function(T) test) {
    return _items.where(test).toList();
  }
  
  /// Vrátí počet položek
  int get itemCount => _items.length;
  
  /// Zkontroluje, zda je seznam prázdný
  bool get isEmpty => _items.isEmpty;
  
  /// Zkontroluje, zda seznam není prázdný
  bool get isNotEmpty => _items.isNotEmpty;
  
  /// Aktualizuje časovou značku poslední synchronizace
  void _updateLastSyncTimestamp() {
    if (_items.isEmpty) {
      _lastSyncTimestamp = DateTime.now();
      return;
    }
    
    _lastSyncTimestamp = _items
        .map((item) => getItemTimestamp(item))
        .reduce((a, b) => a.isAfter(b) ? a : b);
    
    debugPrint("=== ${runtimeType}: POSLEDNÍ SYNCHRONIZACE: $_lastSyncTimestamp ===");
  }
  
  /// Notifikuje posluchače a naplánuje uložení
  void _notifyChange() {
    notifyListeners();
    _debounceSave();
  }
  
  /// Debounce pro ukládání - zabrání častému ukládání
  void _debounceSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      saveItems();
    });
  }
  
  /// Ošetření chyby při načítání
  void _handleLoadError(dynamic error) {
    // Můžete přidat vlastní logiku pro ošetření chyb
    // Například zobrazení notifikace uživateli
  }
  
  /// Ošetření chyby při ukládání
  void _handleSaveError(dynamic error) {
    // Můžete přidat vlastní logiku pro ošetření chyb
  }
  
  /// Ošetření chyby při importu
  void _handleImportError(dynamic error) {
    // Můžete přidat vlastní logiku pro ošetření chyb
  }
  
  @override
  void dispose() {
    debugPrint("=== ${runtimeType}: UKONČUJI SLUŽBU ===");
    _saveDebounce?.cancel();
    super.dispose();
  }
}

/// Mixin pro služby s ID-based položkami
mixin IdBasedItemsMixin<T> on BaseLocalStorageService<T> {
  /// Abstraktní metoda pro získání ID položky
  String getItemId(T item);
  
  /// Najde položku podle ID
  T? findItemById(String id) {
    return findItem((item) => getItemId(item) == id);
  }
  
  /// Odebere položku podle ID
  void removeItemById(String id) {
    removeItemWhere((item) => getItemId(item) == id);
  }
  
  /// Aktualizuje položku podle ID
  void updateItemById(String id, T updatedItem) {
    final index = items.toList().indexWhere((item) => getItemId(item) == id);
    if (index != -1) {
      updateItemAt(index, updatedItem);
    }
  }
  
  /// Zkontroluje, zda položka s daným ID existuje
  bool hasItemWithId(String id) {
    return findItemById(id) != null;
  }
}

/// Mixin pro služby s časově řazenými položkami
mixin TimeBasedItemsMixin<T> on BaseLocalStorageService<T> {
  /// Seřadí položky podle času (nejnovější první)
  List<T> get itemsSortedByTime {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) => getItemTimestamp(b).compareTo(getItemTimestamp(a)));
    return sorted;
  }
  
  /// Najde položky v daném časovém rozmezí
  List<T> findItemsInTimeRange(DateTime start, DateTime end) {
    return findItems((item) {
      final timestamp = getItemTimestamp(item);
      return timestamp.isAfter(start) && timestamp.isBefore(end);
    });
  }
  
  /// Najde položky od daného data
  List<T> findItemsAfter(DateTime date) {
    return findItems((item) => getItemTimestamp(item).isAfter(date));
  }
  
  /// Najde položky před daným datem
  List<T> findItemsBefore(DateTime date) {
    return findItems((item) => getItemTimestamp(item).isBefore(date));
  }
}