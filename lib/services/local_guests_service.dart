/// lib/services/local_guests_service.dart - OPRAVENĂ VERZE
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base/base_local_storage_service.dart';
import '../models/guest.dart';
import '../models/table_arrangement.dart';

/// Sluťba pro lokální správu hostů vyuťívající základní třídu
class LocalGuestsService extends BaseLocalStorageService<Guest>
    with IdBasedItemsMixin<Guest>, TimeBasedItemsMixin<Guest> {
  // Stoly jsou ukládány separátně
  List<TableArrangement> _tables = [];
  List<TableArrangement> get tables => List.unmodifiable(_tables);

  LocalGuestsService() : super(storageKey: 'wedding_guests');

  /// Seznam hostů (pro zpětnou kompatibilitu)
  List<Guest> get guests => items;

  @override
  Map<String, dynamic> itemToJson(Guest item) {
    return item.toJson();
  }

  @override
  Guest itemFromJson(Map<String, dynamic> json) {
    return Guest.fromJson(json);
  }

  @override
  DateTime getItemTimestamp(Guest item) {
    return item.updatedAt;
  }

  @override
  String getItemId(Guest item) {
    return item.id;
  }

  /// Náčte hosty a stoly
  @override
  Future<void> loadItems() async {
    await super.loadItems();
    await _loadTables();
  }

  /// Náčte stoly ze separátního klíče
  Future<void> _loadTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? tablesData = prefs.getString('wedding_tables');

      if (tablesData != null && tablesData.isNotEmpty) {
        final List<dynamic> jsonData = jsonDecode(tablesData);
        _tables = jsonData
            .map((json) =>
                TableArrangement.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        // Výchozí stůl "Nepřiřazen" pokud neexistují ťádnĂ© stoly
        _tables = [
          TableArrangement(
            id: 'unassigned',
            name: 'Nepřiřazen',
            maxCapacity: 0,
          ),
        ];
      }
    } catch (e) {
      debugPrint("Chyba při náčítání stolů: $e");
      _tables = [
        TableArrangement(
          id: 'unassigned',
          name: 'Nepřiřazen',
          maxCapacity: 0,
        ),
      ];
    }

    notifyListeners();
  }

  /// Uloťí stoly
  Future<void> _saveTables() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _tables.map((table) => table.toJson()).toList();
      await prefs.setString('wedding_tables', jsonEncode(data));
    } catch (e) {
      debugPrint("Chyba při ukládání stolů: $e");
    }
  }

  /// Přidá hosta
  void addGuest(Guest guest) {
    addItem(guest);
  }

  /// Odebere hosta podle ID
  void removeGuest(String id) {
    removeItemById(id);
  }

  /// Aktualizuje hosta
  void updateGuest(Guest updatedGuest) {
    updateItemById(updatedGuest.id, updatedGuest);
  }

  /// Přidá stůl
  Future<void> addTable(TableArrangement table) async {
    // Kontrola, zda uť neexistuje stůl se stejným jmĂ©nem
    if (_tables.any((t) => t.name == table.name)) {
      throw Exception('Stůl s názvem ${table.name} jiť existuje');
    }

    _tables.add(table);
    await _saveTables();
    notifyListeners();
  }

  /// Odebere stůl
  Future<void> removeTable(String tableId) async {
    // Nelze odstranit výchozí stůl "Nepřiřazen"
    if (tableId == 'unassigned') {
      throw Exception('Nelze odstranit výchozí stůl');
    }

    // Najdeme stůl
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);
    if (tableIndex == -1) return;

    final tableName = _tables[tableIndex].name;

    // Přesuneme vĹˇechny hosty z tohoto stolu na "Nepřiřazen"
    final guestsToUpdate =
        items.where((guest) => guest.table == tableName).toList();
    for (final guest in guestsToUpdate) {
      updateGuest(guest.copyWith(table: 'Nepřiřazen'));
    }

    // Odstraníme stůl
    _tables.removeAt(tableIndex);
    await _saveTables();
    notifyListeners();
  }

  /// Aktualizuje stůl
  Future<void> updateTable(TableArrangement updatedTable) async {
    final index = _tables.indexWhere((table) => table.id == updatedTable.id);
    if (index == -1) {
      throw Exception('Stůl nebyl nalezen');
    }

    final oldName = _tables[index].name;
    _tables[index] = updatedTable;

    // Pokud se změnil název stolu, aktualizujeme hosty
    if (oldName != updatedTable.name) {
      final guestsToUpdate =
          items.where((guest) => guest.table == oldName).toList();
      for (final guest in guestsToUpdate) {
        updateGuest(guest.copyWith(table: updatedTable.name));
      }
    }

    await _saveTables();
    notifyListeners();
  }

  /// Získá stůl podle ID
  TableArrangement? getTableById(String id) {
    try {
      return _tables.firstWhere((table) => table.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Získá stůl podle názvu
  TableArrangement? getTableByName(String name) {
    try {
      return _tables.firstWhere((table) => table.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Získá hosty podle skupiny
  List<Guest> getGuestsByGroup(String group) {
    return findItems((guest) => guest.group == group);
  }

  /// Získá hosty podle stolu
  List<Guest> getGuestsByTable(String tableName) {
    return findItems((guest) => guest.table == tableName);
  }

  /// Získá hosty podle účasti
  List<Guest> getGuestsByAttendance(String attendance) {
    return findItems((guest) => guest.attendance == attendance);
  }

  /// Získá hosty podle pohlaví
  List<Guest> getGuestsByGender(String gender) {
    return findItems((guest) => guest.gender == gender);
  }

  /// Získá statistiky hostů
  Map<String, dynamic> getGuestStatistics() {
    return {
      'total': itemCount,
      'male': getGuestsByGender('Muť').length,
      'female': getGuestsByGender('Ĺ˝ena').length,
      'other': getGuestsByGender('JinĂ©').length,
      'confirmed': getGuestsByAttendance('Potvrzená').length,
      'declined': getGuestsByAttendance('Neutvrzená').length,
      'pending': getGuestsByAttendance('Neodpovězeno').length,
      'tables': _tables.length,
      'lastModified': lastSyncTimestamp,
    };
  }

  /// Získá souhrn podle skupin
  Map<String, int> getGroupSummary() {
    final summary = <String, int>{};
    for (final guest in guests) {
      summary[guest.group] = (summary[guest.group] ?? 0) + 1;
    }
    return summary;
  }

  /// Získá vyuťití stolů
  Map<String, Map<String, dynamic>> getTableUtilization() {
    final utilization = <String, Map<String, dynamic>>{};

    for (final table in _tables) {
      final guestsAtTable = getGuestsByTable(table.name);
      utilization[table.name] = {
        'current': guestsAtTable.length,
        'max': table.maxCapacity,
        'available': table.maxCapacity > 0
            ? table.maxCapacity - guestsAtTable.length
            : null,
        'percentage': table.maxCapacity > 0
            ? (guestsAtTable.length / table.maxCapacity * 100).round()
            : 0,
        'isFull':
            table.maxCapacity > 0 && guestsAtTable.length >= table.maxCapacity,
      };
    }

    return utilization;
  }

  /// Kontrola, zda je moťnĂ© přiřadit hosta ke stolu
  bool canAssignGuestToTable(String tableName) {
    final table = getTableByName(tableName);
    if (table == null) return false;

    // Stůl "Nepřiřazen" nemá omezení
    if (table.id == 'unassigned' || table.maxCapacity == 0) return true;

    final currentGuests = getGuestsByTable(tableName).length;
    return currentGuests < table.maxCapacity;
  }

  /// Vytvoří novĂ©ho hosta
  static Guest createGuest({
    required String name,
    required String group,
    String? contact,
    String gender = 'Muť',
    String table = 'Nepřiřazen',
    String attendance = 'Neodpovězeno',
  }) {
    return Guest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      group: group,
      contact: contact,
      gender: gender,
      table: table,
      attendance: attendance,
    );
  }

  /// Vytvoří nový stůl
  static TableArrangement createTable({
    required String name,
    required int maxCapacity,
  }) {
    return TableArrangement(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      maxCapacity: maxCapacity,
    );
  }

  /// Vymaťe vĹˇechna data
  @override
  void clearAllItems() {
    super.clearAllItems();
    _tables = [
      TableArrangement(
        id: 'unassigned',
        name: 'Nepřiřazen',
        maxCapacity: 0,
      ),
    ];
    _saveTables();
  }

  /// Nastaví hosty a stoly bez notifikace (pro synchronizaci)
  void setGuestsAndTablesWithoutNotify(
      List<Guest> guests, List<TableArrangement> tables) {
    setItemsWithoutNotify(guests);

    // Zajistíme, ťe vťdy existuje výchozí stůl
    if (!tables.any((t) => t.id == 'unassigned')) {
      _tables = [
        TableArrangement(
          id: 'unassigned',
          name: 'Nepřiřazen',
          maxCapacity: 0,
        ),
        ...tables,
      ];
    } else {
      _tables = List.from(tables);
    }

    _saveTables();
  }

  /// Exportuje data hostů a stolů do JSON
  @override
  String exportToJson() {
    final data = {
      'guests': items.map((guest) => guest.toJson()).toList(),
      'tables': _tables.map((table) => table.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Importuje data hostů a stolů z JSON
  @override
  Future<void> importFromJson(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Import hostů
      if (data.containsKey('guests')) {
        final guestsList = (data['guests'] as List<dynamic>)
            .map((json) => Guest.fromJson(json as Map<String, dynamic>))
            .toList();
        setItemsWithoutNotify(guestsList);
      }

      // Import stolů
      if (data.containsKey('tables')) {
        final tablesList = (data['tables'] as List<dynamic>)
            .map((json) =>
                TableArrangement.fromJson(json as Map<String, dynamic>))
            .toList();

        // Zajistíme výchozí stůl
        if (!tablesList.any((t) => t.id == 'unassigned')) {
          _tables = [
            TableArrangement(
              id: 'unassigned',
              name: 'Nepřiřazen',
              maxCapacity: 0,
            ),
            ...tablesList,
          ];
        } else {
          _tables = tablesList;
        }

        await _saveTables();
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Chyba při importu dat hostů: $e");
      throw Exception('Nepodařilo se importovat data: $e');
    }
  }
}
