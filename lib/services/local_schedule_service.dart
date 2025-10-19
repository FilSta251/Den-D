/// lib/services/local_schedule_service.dart - REFAKTOROVANĂ VERZE
library;

import 'package:flutter/material.dart';
import 'base/base_local_storage_service.dart';

/// Model pro poloťku harmonogramu svatby.
class ScheduleItem {
  final String id;
  String title;
  DateTime? time;
  DateTime lastModified;

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
      time: json['time'] != null
          ? DateTime.tryParse(json['time'] as String)
          : null,
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
      lastModified: lastModified ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'ScheduleItem(id: $id, title: $title, time: $time, lastModified: $lastModified)';
  }
}

/// Sluťba pro správu harmonogramu svatby vyuťívající základní třídu.
class LocalScheduleService extends BaseLocalStorageService<ScheduleItem>
    with IdBasedItemsMixin<ScheduleItem>, TimeBasedItemsMixin<ScheduleItem> {
  LocalScheduleService() : super(storageKey: 'wedding_schedule_items');

  /// Seznam poloťek harmonogramu (pro zpětnou kompatibilitu)
  List<ScheduleItem> get scheduleItems => items;

  @override
  Map<String, dynamic> itemToJson(ScheduleItem item) {
    return item.toJson();
  }

  @override
  ScheduleItem itemFromJson(Map<String, dynamic> json) {
    return ScheduleItem.fromJson(json);
  }

  @override
  DateTime getItemTimestamp(ScheduleItem item) {
    return item.lastModified;
  }

  @override
  String getItemId(ScheduleItem item) {
    return item.id;
  }

  /// Náčte poloťky harmonogramu (alias pro loadItems)
  Future<void> loadScheduleItems() async {
    await loadItems();
  }

  /// Uloťí poloťky harmonogramu (alias pro saveItems)
  Future<void> saveScheduleItems() async {
    await saveItems();
  }

  /// Přidá poloťku harmonogramu s validací
  void addScheduleItem(ScheduleItem item) {
    if (item.title.trim().isEmpty) {
      debugPrint(
          "=== HARMONOGRAM: POKUS O PĹIDĂNĂŤ POLOĹ˝KY S PRĂZDNĂťM NĂZVEM ===");
      return;
    }
    addItem(item);
  }

  /// Aktualizuje poloťku harmonogramu
  void updateScheduleItem(int index, ScheduleItem updatedItem) {
    // Nastavíme aktuální časovou znáčku pro upravenou poloťku
    final newItem = updatedItem.copyWith(lastModified: DateTime.now());
    updateItemAt(index, newItem);
  }

  /// Odebere poloťku podle indexu (pro zpětnou kompatibilitu)
  void removeItem(int index) {
    removeItemAt(index);
  }

  /// Aktualizuje poloťku podle indexu (pro zpětnou kompatibilitu)
  void updateItem(int index, ScheduleItem updatedItem) {
    updateScheduleItem(index, updatedItem);
  }

  /// Seřadí poloťky podle času
  List<ScheduleItem> get itemsSortedByScheduleTime {
    final sorted = List<ScheduleItem>.from(items);
    sorted.sort((a, b) {
      // Poloťky bez času jdou na konec
      if (a.time == null && b.time == null) return 0;
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return a.time!.compareTo(b.time!);
    });
    return sorted;
  }

  /// Najde poloťky pro konkrĂ©tní den
  List<ScheduleItem> findItemsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return findItems((item) {
      if (item.time == null) return false;
      return item.time!.isAfter(startOfDay) && item.time!.isBefore(endOfDay);
    });
  }

  /// Najde poloťky bez přiřazenĂ©ho času
  List<ScheduleItem> get itemsWithoutTime {
    return findItems((item) => item.time == null);
  }

  /// Najde poloťky s přiřazeným časem
  List<ScheduleItem> get itemsWithTime {
    return findItems((item) => item.time != null);
  }

  /// Vytvoří novou poloťku harmonogramu
  static ScheduleItem createScheduleItem({
    required String title,
    DateTime? time,
  }) {
    return ScheduleItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      time: time,
    );
  }

  /// Zkontroluje konflikty v čase
  List<ScheduleItem> findTimeConflicts(DateTime time,
      {Duration tolerance = const Duration(minutes: 30)}) {
    return findItems((item) {
      if (item.time == null) return false;
      final difference = item.time!.difference(time).abs();
      return difference <= tolerance;
    });
  }

  /// Získá statistiky harmonogramu
  Map<String, dynamic> getStatistics() {
    return {
      'totalItems': itemCount,
      'itemsWithTime': itemsWithTime.length,
      'itemsWithoutTime': itemsWithoutTime.length,
      'lastModified': lastSyncTimestamp,
    };
  }
}
