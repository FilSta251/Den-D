// lib/services/local_schedule_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model pro položku harmonogramu svatby.
/// Umožňuje zadat pouze název a čas (datum není zadáváno, protože se jedná o jeden den).
class ScheduleItem {
  final String id;
  String title;
  DateTime? time; // Pouze čas (datum je pevně daný)
  DateTime lastModified; // Časová značka poslední úpravy

  ScheduleItem({
    required this.id,
    required this.title,
    this.time,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      title: json['title'] as String,
      time: json['time'] != null ? DateTime.tryParse(json['time'] as String) : null,
      lastModified: json['lastModified'] != null 
          ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'time': time?.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  ScheduleItem copyWith({
    String? id,
    String? title,
    DateTime? time,
    DateTime? lastModified,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      lastModified: lastModified ?? DateTime.now(), // Vždy aktualizujeme časovou značku
    );
  }

  @override
  String toString() {
    return 'ScheduleItem(id: $id, title: $title, time: $time, lastModified: $lastModified)';
  }
}

/// Služba pro správu harmonogramu svatby – pro jeden den.
/// Obsahuje metody pro načítání, ukládání, přidávání, mazání, přeuspořádání, export a import položek.
class LocalScheduleService extends ChangeNotifier {
  final String _storageKey = 'wedding_schedule_items';
  List<ScheduleItem> _scheduleItems = [];
  Timer? _saveDebounce;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<ScheduleItem> get scheduleItems => _scheduleItems;
  
  // Časová značka poslední aktualizace seznamu
  DateTime _lastSyncTimestamp = DateTime(2000); // Výchozí hodnota v minulosti
  DateTime get lastSyncTimestamp => _lastSyncTimestamp;

  LocalScheduleService() {
    loadScheduleItems();
  }

  Future<void> loadScheduleItems() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("=== LOKÁLNÍ SLUŽBA: NAČÍTÁM HARMONOGRAM Z ÚLOŽIŠTĚ ===");
      
      // Místo použití compute, načteme data přímo
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(_storageKey);
      if (storedData != null) {
        List<dynamic> jsonData = jsonDecode(storedData);
        _scheduleItems = jsonData.map((e) => ScheduleItem.fromJson(e)).toList();
      }
      
      // Aktualizace časové značky podle nejnovější položky
      _updateLastSyncTimestamp();
      
      debugPrint("=== LOKÁLNÍ SLUŽBA: NAČTENO ${_scheduleItems.length} POLOŽEK HARMONOGRAMU Z LOKÁLNÍHO ÚLOŽIŠTĚ ===");
    } catch (e) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: CHYBA PŘI NAČÍTÁNÍ: $e ===");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Aktualizuje časovou značku poslední synchronizace
  void _updateLastSyncTimestamp() {
    if (_scheduleItems.isNotEmpty) {
      _lastSyncTimestamp = _scheduleItems
          .map((item) => item.lastModified)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    debugPrint("=== LOKÁLNÍ SLUŽBA: POSLEDNÍ SYNCHRONIZACE HARMONOGRAMU: $_lastSyncTimestamp ===");
  }

  Future<void> saveScheduleItems() async {
    try {
      debugPrint("=== LOKÁLNÍ SLUŽBA: UKLÁDÁM HARMONOGRAM DO ÚLOŽIŠTĚ ===");
      
      // Místo compute, uložíme data přímo
      final prefs = await SharedPreferences.getInstance();
      final data = _scheduleItems.map((item) => item.toJson()).toList();
      final String jsonData = jsonEncode(data);
      
      try {
        await prefs.setString(_storageKey, jsonData);
      } catch (e) {
        debugPrint("Error saving schedule items: $e");
      }
      
      // Aktualizace časové značky
      _updateLastSyncTimestamp();
      
      debugPrint("=== LOKÁLNÍ SLUŽBA: HARMONOGRAM ULOŽEN, ${_scheduleItems.length} POLOŽEK ===");
    } catch (e) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: CHYBA PŘI UKLÁDÁNÍ: $e ===");
    }
  }

  void addItem(ScheduleItem item) {
    if (item.title.trim().isEmpty) return;
    
    debugPrint("=== LOKÁLNÍ SLUŽBA: PŘIDÁVÁM POLOŽKU: ${item.title} ===");
    _scheduleItems.add(item);
    _notifyChange();
  }

  void removeItem(int index) {
    if (index < 0 || index >= _scheduleItems.length) return;
    
    debugPrint("=== LOKÁLNÍ SLUŽBA: ODSTRAŇUJI POLOŽKU NA INDEXU $index ===");
    _scheduleItems.removeAt(index);
    _notifyChange();
  }

  void updateItem(int index, ScheduleItem updatedItem) {
    if (index < 0 || index >= _scheduleItems.length) return;
    
    debugPrint("=== LOKÁLNÍ SLUŽBA: AKTUALIZUJI POLOŽKU: ${updatedItem.title} ===");
    // Nastavíme aktuální časovou značku pro upravenou položku
    final newItem = updatedItem.copyWith(lastModified: DateTime.now());
    _scheduleItems[index] = newItem;
    _notifyChange();
  }

  void reorderItems(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    
    debugPrint("=== LOKÁLNÍ SLUŽBA: MĚNÍM POŘADÍ POLOŽEK Z $oldIndex NA $newIndex ===");
    final item = _scheduleItems.removeAt(oldIndex);
    _scheduleItems.insert(newIndex, item);
    _notifyChange();
  }

  /// Nová metoda – vloží položku na danou pozici (pro undo akci).
  void insertItemAt(int index, ScheduleItem item) {
    debugPrint("=== LOKÁLNÍ SLUŽBA: VKLÁDÁM POLOŽKU NA INDEX $index ===");
    _scheduleItems.insert(index, item);
    _notifyChange();
  }

  void clearAllItems() {
    debugPrint("=== LOKÁLNÍ SLUŽBA: MAŽU VŠECHNY POLOŽKY ===");
    _scheduleItems.clear();
    _notifyChange();
  }

  /// Aktualizuje seznam položek bez notifikace posluchačů (pro interní použití)
  void setItemsWithoutNotify(List<ScheduleItem> items) {
    debugPrint("=== LOKÁLNÍ SLUŽBA: NASTAVUJI ${items.length} POLOŽEK BEZ NOTIFIKACE ===");
    _scheduleItems = items;
    saveScheduleItems();
  }

  String exportToJson() {
    debugPrint("=== LOKÁLNÍ SLUŽBA: EXPORTUJI HARMONOGRAM DO JSON ===");
    return jsonEncode(_scheduleItems.map((item) => item.toJson()).toList());
  }

  Future<void> importFromJson(String jsonData) async {
    debugPrint("=== LOKÁLNÍ SLUŽBA: IMPORTUJI HARMONOGRAM Z JSON ===");
    try {
      // Místo compute, parsujeme JSON přímo
      List<dynamic> data = jsonDecode(jsonData);
      _scheduleItems = data.map((e) => ScheduleItem.fromJson(e)).toList();
      _notifyChange();
    } catch (e) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: CHYBA PŘI IMPORTU: $e ===");
    }
  }

  void _notifyChange() {
    notifyListeners();
    _debounceSave();
  }

  void _debounceSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      saveScheduleItems();
    });
  }

  @override
  void dispose() {
    debugPrint("=== LOKÁLNÍ SLUŽBA: UKONČUJI SLUŽBU ===");
    _saveDebounce?.cancel();
    super.dispose();
  }
}