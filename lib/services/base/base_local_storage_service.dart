/// lib/services/base/base_local_storage_service.dart
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abstraktní základní třída pro sluťby pracující s lokálním úloťiĹˇtěm.
///
/// poskytuje společnou funkcionalitu pro ukládání, náčítání a správu dat
/// v lokálním úloťiĹˇti pomocí SharedPreferences.
///
/// Výhody pouťití:
/// - Jednotný přístup k ukládání a náčítání dat
/// - AutomatickĂ© debounce ukládání
/// - Správa stavu náčítání
/// - ďŚasovĂ© znáčky poslední synchronizace
/// - OĹˇetření chyb
abstract class BaseLocalStorageService<T> extends ChangeNotifier {
  /// Klíč pro ukládání dat v SharedPreferences
  final String storageKey;

  /// Seznam poloťek spravovaných touto sluťbou
  List<T> _items = [];

  /// Timer pro debounce ukládání
  Timer? _saveDebounce;

  /// Příznak, zda probíhá náčítání
  bool _isLoading = false;

  /// ďŚasová znáčka poslední synchronizace
  DateTime _lastSyncTimestamp = DateTime(2000);

  /// Konstruktor vyťadující klíč pro ukládání
  BaseLocalStorageService({required this.storageKey}) {
    _initializeService();
  }

  /// Inicializace sluťby - náčte data při vytvoření
  void _initializeService() {
    loadItems();
  }

  /// Getter pro seznam poloťek
  List<T> get items => List.unmodifiable(_items);

  /// Getter pro stav náčítání
  bool get isLoading => _isLoading;

  /// Getter pro časovou znáčku poslední synchronizace
  DateTime get lastSyncTimestamp => _lastSyncTimestamp;

  /// Abstraktní metoda pro převod poloťky na JSON
  Map<String, dynamic> itemToJson(T item);

  /// Abstraktní metoda pro vytvoření poloťky z JSON
  T itemFromJson(Map<String, dynamic> json);

  /// Abstraktní metoda pro získání časovĂ© znáčky poloťky
  DateTime getItemTimestamp(T item);

  /// Náčte poloťky z lokálního úloťiĹˇtě
  Future<void> loadItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint("=== $runtimeType: NAďŚĂŤTĂM DATA Z ĂšLOĹ˝IĹ Tďš ===");

      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(storageKey);

      if (storedData != null && storedData.isNotEmpty) {
        final List<dynamic> jsonData = jsonDecode(storedData);
        _items = jsonData
            .map((json) => itemFromJson(json as Map<String, dynamic>))
            .toList();
      }

      _updateLastSyncTimestamp();

      debugPrint("=== $runtimeType: NAďŚTENO ${_items.length} POLOĹ˝EK ===");
    } catch (e) {
      debugPrint("=== $runtimeType: CHYBA PĹI NAďŚĂŤTĂNĂŤ: $e ===");
      _handleLoadError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Uloťí poloťky do lokálního úloťiĹˇtě
  Future<void> saveItems() async {
    try {
      debugPrint("=== $runtimeType: UKLĂDĂM DATA DO ĂšLOĹ˝IĹ Tďš ===");

      final prefs = await SharedPreferences.getInstance();
      final data = _items.map((item) => itemToJson(item)).toList();
      final String jsonData = jsonEncode(data);

      await prefs.setString(storageKey, jsonData);

      _updateLastSyncTimestamp();

      debugPrint("=== $runtimeType: ULOĹ˝ENO ${_items.length} POLOĹ˝EK ===");
    } catch (e) {
      debugPrint("=== $runtimeType: CHYBA PĹI UKLĂDĂNĂŤ: $e ===");
      _handleSaveError(e);
    }
  }

  /// Přidá novou poloťku
  void addItem(T item) {
    debugPrint("=== $runtimeType: PĹIDĂVĂM NOVOU POLOĹ˝KU ===");
    _items.add(item);
    _notifyChange();
  }

  /// Odebere poloťku podle indexu
  void removeItemAt(int index) {
    if (index < 0 || index >= _items.length) {
      debugPrint(
          "=== $runtimeType: NEPLATNĂť INDEX PRO ODEBRĂNĂŤ: $index ===");
      return;
    }

    debugPrint("=== $runtimeType: ODEBĂŤRĂM POLOĹ˝KU NA INDEXU $index ===");
    _items.removeAt(index);
    _notifyChange();
  }

  /// Odebere poloťku podle podmínky
  void removeItemWhere(bool Function(T) test) {
    final removedCount = _items.length;
    _items.removeWhere(test);
    final removed = removedCount - _items.length;

    if (removed > 0) {
      debugPrint("=== $runtimeType: ODEBRĂNO $removed POLOĹ˝EK ===");
      _notifyChange();
    }
  }

  /// Aktualizuje poloťku na danĂ©m indexu
  void updateItemAt(int index, T updatedItem) {
    if (index < 0 || index >= _items.length) {
      debugPrint(
          "=== $runtimeType: NEPLATNĂť INDEX PRO AKTUALIZACI: $index ===");
      return;
    }

    debugPrint("=== $runtimeType: AKTUALIZUJI POLOĹ˝KU NA INDEXU $index ===");
    _items[index] = updatedItem;
    _notifyChange();
  }

  /// Aktualizuje poloťku podle podmínky
  void updateItemWhere(bool Function(T) test, T Function(T) update) {
    var updated = false;

    for (var i = 0; i < _items.length; i++) {
      if (test(_items[i])) {
        _items[i] = update(_items[i]);
        updated = true;
      }
    }

    if (updated) {
      debugPrint("=== $runtimeType: AKTUALIZOVĂNY VYBRANĂ‰ POLOĹ˝KY ===");
      _notifyChange();
    }
  }

  /// Přeuspořádá poloťky
  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _items.length ||
        newIndex < 0 ||
        newIndex > _items.length) {
      debugPrint(
          "=== $runtimeType: NEPLATNĂ‰ INDEXY PRO PĹEUSPOĹĂDĂNĂŤ ===");
      return;
    }

    if (newIndex > oldIndex) newIndex--;

    debugPrint(
        "=== $runtimeType: PĹEUSPOĹĂDĂVĂM Z $oldIndex NA $newIndex ===");
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _notifyChange();
  }

  /// Vloťí poloťku na danou pozici
  void insertItemAt(int index, T item) {
    if (index < 0 || index > _items.length) {
      debugPrint("=== $runtimeType: NEPLATNĂť INDEX PRO VLOĹ˝ENĂŤ: $index ===");
      return;
    }

    debugPrint("=== $runtimeType: VKLĂDĂM POLOĹ˝KU NA INDEX $index ===");
    _items.insert(index, item);
    _notifyChange();
  }

  /// Vymaťe vĹˇechny poloťky
  void clearAllItems() {
    debugPrint("=== $runtimeType: MAĹ˝U VĹ ECHNY POLOĹ˝KY ===");
    _items.clear();
    _notifyChange();
  }

  /// Nastaví poloťky bez notifikace (pro synchronizaci)
  void setItemsWithoutNotify(List<T> items) {
    debugPrint(
        "=== $runtimeType: NASTAVUJI ${items.length} POLOĹ˝EK BEZ NOTIFIKACE ===");
    _items = List.from(items);
    saveItems(); // Uloťíme bez debounce
  }

  /// Exportuje data do JSON
  String exportToJson() {
    debugPrint("=== $runtimeType: EXPORTUJI DATA DO JSON ===");
    return jsonEncode(_items.map((item) => itemToJson(item)).toList());
  }

  /// Importuje data z JSON
  Future<void> importFromJson(String jsonData) async {
    debugPrint("=== $runtimeType: IMPORTUJI DATA Z JSON ===");

    try {
      final List<dynamic> data = jsonDecode(jsonData);
      _items = data
          .map((json) => itemFromJson(json as Map<String, dynamic>))
          .toList();
      _notifyChange();
    } catch (e) {
      debugPrint("=== $runtimeType: CHYBA PĹI IMPORTU: $e ===");
      _handleImportError(e);
    }
  }

  /// Najde poloťku podle podmínky
  T? findItem(bool Function(T) test) {
    try {
      return _items.firstWhere(test);
    } catch (_) {
      return null;
    }
  }

  /// Najde vĹˇechny poloťky podle podmínky
  List<T> findItems(bool Function(T) test) {
    return _items.where(test).toList();
  }

  /// Vrátí počet poloťek
  int get itemCount => _items.length;

  /// Zkontroluje, zda je seznam prázdný
  bool get isEmpty => _items.isEmpty;

  /// Zkontroluje, zda seznam není prázdný
  bool get isNotEmpty => _items.isNotEmpty;

  /// Aktualizuje časovou znáčku poslední synchronizace
  void _updateLastSyncTimestamp() {
    if (_items.isEmpty) {
      _lastSyncTimestamp = DateTime.now();
      return;
    }

    _lastSyncTimestamp = _items
        .map((item) => getItemTimestamp(item))
        .reduce((a, b) => a.isAfter(b) ? a : b);

    debugPrint(
        "=== $runtimeType: POSLEDNĂŤ SYNCHRONIZACE: $_lastSyncTimestamp ===");
  }

  /// Notifikuje poslucháče a naplánuje uloťení
  void _notifyChange() {
    notifyListeners();
    _debounceSave();
  }

  /// Debounce pro ukládání - zabrání častĂ©mu ukládání
  void _debounceSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      saveItems();
    });
  }

  /// OĹˇetření chyby při náčítání
  void _handleLoadError(dynamic error) {
    // Můťete přidat vlastní logiku pro oĹˇetření chyb
    // Například zobrazení notifikace uťivateli
  }

  /// OĹˇetření chyby při ukládání
  void _handleSaveError(dynamic error) {
    // Můťete přidat vlastní logiku pro oĹˇetření chyb
  }

  /// OĹˇetření chyby při importu
  void _handleImportError(dynamic error) {
    // Můťete přidat vlastní logiku pro oĹˇetření chyb
  }

  @override
  void dispose() {
    debugPrint("=== $runtimeType: UKONďŚUJI SLUĹ˝BU ===");
    _saveDebounce?.cancel();
    super.dispose();
  }
}

/// Mixin pro sluťby s ID-based poloťkami
mixin IdBasedItemsMixin<T> on BaseLocalStorageService<T> {
  /// Abstraktní metoda pro získání ID poloťky
  String getItemId(T item);

  /// Najde poloťku podle ID
  T? findItemById(String id) {
    return findItem((item) => getItemId(item) == id);
  }

  /// Odebere poloťku podle ID
  void removeItemById(String id) {
    removeItemWhere((item) => getItemId(item) == id);
  }

  /// Aktualizuje poloťku podle ID
  void updateItemById(String id, T updatedItem) {
    final index = items.toList().indexWhere((item) => getItemId(item) == id);
    if (index != -1) {
      updateItemAt(index, updatedItem);
    }
  }

  /// Zkontroluje, zda poloťka s daným ID existuje
  bool hasItemWithId(String id) {
    return findItemById(id) != null;
  }
}

/// Mixin pro sluťby s časově řazenými poloťkami
mixin TimeBasedItemsMixin<T> on BaseLocalStorageService<T> {
  /// Seřadí poloťky podle času (nejnovějĹˇí první)
  List<T> get itemsSortedByTime {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) => getItemTimestamp(b).compareTo(getItemTimestamp(a)));
    return sorted;
  }

  /// Najde poloťky v danĂ©m časovĂ©m rozmezí
  List<T> findItemsInTimeRange(DateTime start, DateTime end) {
    return findItems((item) {
      final timestamp = getItemTimestamp(item);
      return timestamp.isAfter(start) && timestamp.isBefore(end);
    });
  }

  /// Najde poloťky od danĂ©ho data
  List<T> findItemsAfter(DateTime date) {
    return findItems((item) => getItemTimestamp(item).isAfter(date));
  }

  /// Najde poloťky před daným datem
  List<T> findItemsBefore(DateTime date) {
    return findItems((item) => getItemTimestamp(item).isBefore(date));
  }
}
