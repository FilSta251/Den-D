/// lib/services/local_checklist_service.dart
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'base/base_local_storage_service.dart';
import '../models/task.dart';

/// Sluťba pro lokální správu checklistu vyuťívající základní třídu
class LocalChecklistService extends BaseLocalStorageService<Task>
    with IdBasedItemsMixin<Task>, TimeBasedItemsMixin<Task> {
  // Kategorie jsou ukládány separátně
  List<TaskCategory> _categories = [];
  List<TaskCategory> get categories => List.unmodifiable(_categories);

  // Výchozí kategorie - ukládáme klíče pro překlad
  static const List<Map<String, dynamic>> defaultCategories = [
    {
      'id': '12-6-months',
      'nameKey': 'category_12_6_months',
      'descriptionKey': 'category_12_6_months_desc',
      'sortOrder': 1,
    },
    {
      'id': '6-3-months',
      'nameKey': 'category_6_3_months',
      'descriptionKey': 'category_6_3_months_desc',
      'sortOrder': 2,
    },
    {
      'id': '3-1-months',
      'nameKey': 'category_3_1_months',
      'descriptionKey': 'category_3_1_months_desc',
      'sortOrder': 3,
    },
    {
      'id': 'week-before',
      'nameKey': 'category_week_before',
      'descriptionKey': 'category_week_before_desc',
      'sortOrder': 4,
    },
    {
      'id': 'wedding-day',
      'nameKey': 'category_wedding_day',
      'descriptionKey': 'category_wedding_day_desc',
      'sortOrder': 5,
    },
  ];

  // Výchozí úkoly pro kaťdou kategorii - ukládáme klíče pro překlad
  static const Map<String, List<String>> defaultTasks = {
    '12-6-months': [
      'task_reserve_venue',
      'task_choose_photographer',
      'task_set_budget',
      'task_create_guest_list',
      'task_choose_theme',
      'task_reserve_band',
      'task_consider_coordinator',
    ],
    '6-3-months': [
      'task_send_invitations',
      'task_book_catering',
      'task_choose_dress_suit',
      'task_order_cake',
      'task_reserve_flowers',
      'task_plan_schedule',
      'task_arrange_accommodation',
    ],
    '3-1-months': [
      'task_confirm_guests',
      'task_choose_rings',
      'task_arrange_seating',
      'task_arrange_transport',
      'task_try_dress_suit',
      'task_prepare_program',
      'task_finish_decoration',
    ],
    'week-before': [
      'task_confirm_vendors',
      'task_prepare_timeline',
      'task_pack_honeymoon',
      'task_rehearse_ceremony',
      'task_prepare_emergency_kit',
      'task_check_weather',
      'task_finish_payments',
    ],
    'wedding-day': [
      'task_check_preparations',
      'task_welcome_guests',
      'task_thank_vendors',
      'task_enjoy_day',
    ],
  };

  LocalChecklistService() : super(storageKey: 'wedding_checklist_tasks');

  /// Seznam úkolů (pro zpětnou kompatibilitu)
  List<Task> get tasks => items;

  @override
  Map<String, dynamic> itemToJson(Task item) {
    return item.toJson();
  }

  @override
  Task itemFromJson(Map<String, dynamic> json) {
    return Task.fromJson(json);
  }

  @override
  DateTime getItemTimestamp(Task item) {
    return item.updatedAt;
  }

  @override
  String getItemId(Task item) {
    return item.id;
  }

  /// Náčte úkoly a kategorie
  @override
  Future<void> loadItems() async {
    await super.loadItems();
    await _loadCategories();

    // Pokud nejsou ťádnĂ© úkoly, vytvoříme výchozí
    if (items.isEmpty) {
      await _createDefaultTasks();
    }
  }

  /// Náčte kategorie ze separátního klíče
  Future<void> _loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? categoriesData =
          prefs.getString('wedding_checklist_categories');

      if (categoriesData != null && categoriesData.isNotEmpty) {
        final List<dynamic> jsonData = jsonDecode(categoriesData);
        _categories = jsonData
            .map((json) => TaskCategory.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        // Vytvoříme výchozí kategorie s překladovými klíči
        _categories = defaultCategories
            .map((data) => TaskCategory(
                  id: data['id'] as String,
                  name: data['nameKey']
                      as String, // Ukládáme klíč, ne přeloťený text
                  description: data['descriptionKey']
                      as String, // Ukládáme klíč, ne přeloťený text
                  sortOrder: data['sortOrder'] as int,
                ))
            .toList();
        await _saveCategories();
      }

      // Seřadíme kategorie podle sortOrder
      _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    } catch (e) {
      debugPrint("Chyba při náčítání kategorií: $e");
      // Vytvoříme výchozí kategorie
      _categories = defaultCategories
          .map((data) => TaskCategory(
                id: data['id'] as String,
                name: data['nameKey'] as String,
                description: data['descriptionKey'] as String,
                sortOrder: data['sortOrder'] as int,
              ))
          .toList();
    }

    notifyListeners();
  }

  /// Uloťí kategorie
  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _categories.map((category) => category.toJson()).toList();
      await prefs.setString('wedding_checklist_categories', jsonEncode(data));
    } catch (e) {
      debugPrint("Chyba při ukládání kategorií: $e");
    }
  }

  /// Vytvoří výchozí úkoly
  Future<void> _createDefaultTasks() async {
    final List<Task> defaultTasksList = [];

    for (final category in _categories) {
      final tasksForCategory = defaultTasks[category.id] ?? [];
      for (int i = 0; i < tasksForCategory.length; i++) {
        defaultTasksList.add(Task(
          id: '${category.id}_${i}_${DateTime.now().millisecondsSinceEpoch}',
          title: tasksForCategory[i], // Ukládáme klíč pro překlad
          category: category.id,
          priority: 2,
        ));
      }
    }

    setItemsWithoutNotify(defaultTasksList);
    await saveItems();
    notifyListeners();
  }

  /// Přidá úkol
  void addTask(Task task) {
    addItem(task);
  }

  /// Odebere úkol podle ID
  void removeTask(String id) {
    removeItemById(id);
  }

  /// Aktualizuje úkol
  void updateTask(Task updatedTask) {
    updateItemById(updatedTask.id, updatedTask);
  }

  /// Oznáčí úkol jako hotový/nehotový
  void toggleTaskDone(String taskId) {
    final task = findItemById(taskId);
    if (task != null) {
      updateTask(task.copyWith(isDone: !task.isDone));
    }
  }

  /// Přidá kategorii
  Future<void> addCategory(TaskCategory category) async {
    // Kontrola duplicit
    if (_categories.any((c) => c.name == category.name)) {
      throw Exception(tr('category_already_exists', args: [category.name]));
    }

    _categories.add(category);
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _saveCategories();
    notifyListeners();
  }

  /// Odebere kategorii
  Future<void> removeCategory(String categoryId) async {
    // Nelze odstranit výchozí kategorie
    if (defaultCategories.any((c) => c['id'] == categoryId)) {
      throw Exception(tr('cannot_delete_default_category'));
    }

    // Přesuneme vĹˇechny úkoly z tĂ©to kategorie do první výchozí kategorie
    final tasksToUpdate =
        items.where((task) => task.category == categoryId).toList();
    for (final task in tasksToUpdate) {
      updateTask(
          task.copyWith(category: defaultCategories.first['id'] as String));
    }

    _categories.removeWhere((c) => c.id == categoryId);
    await _saveCategories();
    notifyListeners();
  }

  /// Aktualizuje kategorii
  Future<void> updateCategory(TaskCategory updatedCategory) async {
    final index = _categories.indexWhere((c) => c.id == updatedCategory.id);
    if (index == -1) {
      throw Exception(tr('category_not_found'));
    }

    _categories[index] = updatedCategory;
    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _saveCategories();
    notifyListeners();
  }

  /// Získá kategorii podle ID
  TaskCategory? getCategoryById(String id) {
    try {
      return _categories.firstWhere((category) => category.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Získá úkoly podle kategorie
  List<Task> getTasksByCategory(String categoryId) {
    return findItems((task) => task.category == categoryId);
  }

  /// Získá dokončenĂ© úkoly
  List<Task> getCompletedTasks() {
    return findItems((task) => task.isDone);
  }

  /// Získá nedokončenĂ© úkoly
  List<Task> getPendingTasks() {
    return findItems((task) => !task.isDone);
  }

  /// Získá úkoly podle priority
  List<Task> getTasksByPriority(int priority) {
    return findItems((task) => task.priority == priority);
  }

  /// Získá úkoly s termínem
  List<Task> getTasksWithDueDate() {
    return findItems((task) => task.dueDate != null);
  }

  /// Získá zpoťděnĂ© úkoly
  List<Task> getOverdueTasks() {
    final now = DateTime.now();
    return findItems((task) =>
        task.dueDate != null && task.dueDate!.isBefore(now) && !task.isDone);
  }

  /// Získá statistiky checklistu
  Map<String, dynamic> getChecklistStatistics() {
    final completed = getCompletedTasks().length;
    final total = itemCount;
    final percentage = total > 0 ? (completed / total * 100).round() : 0;

    return {
      'total': total,
      'completed': completed,
      'pending': total - completed,
      'percentage': percentage,
      'overdue': getOverdueTasks().length,
      'highPriority': getTasksByPriority(1).length,
      'categories': _categories.length,
      'lastModified': lastSyncTimestamp,
    };
  }

  /// Získá statistiky podle kategorií
  Map<String, Map<String, dynamic>> getCategoryStatistics() {
    final stats = <String, Map<String, dynamic>>{};

    for (final category in _categories) {
      final categoryTasks = getTasksByCategory(category.id);
      final completed = categoryTasks.where((t) => t.isDone).length;
      final total = categoryTasks.length;

      stats[category.id] = {
        'name': category.name,
        'total': total,
        'completed': completed,
        'pending': total - completed,
        'percentage': total > 0 ? (completed / total * 100).round() : 0,
      };
    }

    return stats;
  }

  /// Vytvoří nový úkol
  static Task createTask({
    required String title,
    required String category,
    String? note,
    DateTime? dueDate,
    int priority = 2,
  }) {
    return Task(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      category: category,
      note: note,
      dueDate: dueDate,
      priority: priority,
    );
  }

  /// Vytvoří novou kategorii
  static TaskCategory createCategory({
    required String name,
    required String description,
    int sortOrder = 999,
  }) {
    return TaskCategory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      sortOrder: sortOrder,
    );
  }

  /// Vymaťe vĹˇechna data
  @override
  void clearAllItems() {
    super.clearAllItems();

    // Obnovíme výchozí kategorie s překladovými klíči
    _categories = defaultCategories
        .map((data) => TaskCategory(
              id: data['id'] as String,
              name: data['nameKey'] as String,
              description: data['descriptionKey'] as String,
              sortOrder: data['sortOrder'] as int,
            ))
        .toList();

    _saveCategories();

    // Vytvoříme výchozí úkoly
    _createDefaultTasks();
  }

  /// Nastaví úkoly a kategorie bez notifikace (pro synchronizaci)
  void setTasksAndCategoriesWithoutNotify(
      List<Task> tasks, List<TaskCategory> categories) {
    setItemsWithoutNotify(tasks);

    // Zajistíme, ťe výchozí kategorie zůstanou
    final defaultCategoryIds =
        defaultCategories.map((c) => c['id'] as String).toSet();
    final customCategories =
        categories.where((c) => !defaultCategoryIds.contains(c.id)).toList();

    _categories = [
      ...defaultCategories.map((data) => TaskCategory(
            id: data['id'] as String,
            name: data['nameKey'] as String,
            description: data['descriptionKey'] as String,
            sortOrder: data['sortOrder'] as int,
          )),
      ...customCategories,
    ];

    _categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _saveCategories();
  }

  /// Exportuje data úkolů a kategorií do JSON
  @override
  String exportToJson() {
    final data = {
      'tasks': items.map((task) => task.toJson()).toList(),
      'categories': _categories.map((category) => category.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Importuje data úkolů a kategorií z JSON
  @override
  Future<void> importFromJson(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Import úkolů
      if (data.containsKey('tasks')) {
        final tasksList = (data['tasks'] as List<dynamic>)
            .map((json) => Task.fromJson(json as Map<String, dynamic>))
            .toList();
        setItemsWithoutNotify(tasksList);
      }

      // Import kategorií
      if (data.containsKey('categories')) {
        final categoriesList = (data['categories'] as List<dynamic>)
            .map((json) => TaskCategory.fromJson(json as Map<String, dynamic>))
            .toList();

        // Sloučíme s výchozími kategoriemi
        setTasksAndCategoriesWithoutNotify(items, categoriesList);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Chyba při importu dat checklistu: $e");
      throw Exception(tr('import_error', args: [e.toString()]));
    }
  }
}
