/// lib/services/cloud_checklist_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../models/task.dart';

/// Sluťba pro cloudovou synchronizaci checklistu svatby.
///
/// poskytuje kompletní správu úkolů a kategorií
/// s real-time synchronizací napříč zařízeními.
class CloudChecklistService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  // Konstanty pro retry mechanismus
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 500;

  // Cache pro offline pouťití
  List<Task>? _cachedTasks;
  List<TaskCategory>? _cachedCategories;
  DateTime? _cacheTimestamp;

  // Názvy kolekcí
  static const String _tasksCollection = 'checklist_tasks';
  static const String _categoriesCollection = 'checklist_categories';

  CloudChecklistService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  /// Vrací ID aktuálně přihláĹˇenĂ©ho uťivatele.
  String? get _userId => _auth.currentUser?.uid;

  /// Vrací referenci na kolekci úkolů pro aktuálního uťivatele.
  CollectionReference<Map<String, dynamic>> _getTasksCollection() {
    if (_userId == null) {
      throw Exception('Uťivatel není přihláĹˇen.');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_tasksCollection);
  }

  /// Vrací referenci na kolekci kategorií pro aktuálního uťivatele.
  CollectionReference<Map<String, dynamic>> _getCategoriesCollection() {
    if (_userId == null) {
      throw Exception('Uťivatel není přihláĹˇen.');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_categoriesCollection);
  }

  /// Získá stream úkolů, který se aktualizuje v reálnĂ©m čase.
  Stream<List<Task>> getTasksStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getTasksCollection()
          .orderBy('category')
          .orderBy('priority')
          .orderBy('createdAt')
          .snapshots()
          .map((snapshot) {
        final tasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Task.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedTasks = tasks;
        _cacheTimestamp = DateTime.now();

        return tasks;
      }).handleError((error) {
        debugPrint('Chyba při získávání streamu úkolů: $error');
        return _cachedTasks ?? [];
      });
    } catch (e) {
      debugPrint('Chyba při vytváření streamu úkolů: $e');
      return Stream.value(_cachedTasks ?? []);
    }
  }

  /// Získá stream kategorií, který se aktualizuje v reálnĂ©m čase.
  Stream<List<TaskCategory>> getCategoriesStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getCategoriesCollection()
          .orderBy('sortOrder')
          .snapshots()
          .map((snapshot) {
        final categories = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TaskCategory.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedCategories = categories;

        return categories;
      }).handleError((error) {
        debugPrint('Chyba při získávání streamu kategorií: $error');
        return _cachedCategories ?? [];
      });
    } catch (e) {
      debugPrint('Chyba při vytváření streamu kategorií: $e');
      return Stream.value(_cachedCategories ?? []);
    }
  }

  /// Náčte úkoly z Firestore.
  Future<List<Task>> fetchTasks() async {
    if (_userId == null) {
      return _cachedTasks ?? [];
    }

    try {
      return await _withRetry<List<Task>>(() async {
        final snapshot = await _getTasksCollection()
            .orderBy('category')
            .orderBy('priority')
            .orderBy('createdAt')
            .get();

        final tasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Task.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedTasks = tasks;
        _cacheTimestamp = DateTime.now();

        return tasks;
      });
    } catch (e) {
      debugPrint('Chyba při náčítání úkolů: $e');
      return _cachedTasks ?? [];
    }
  }

  /// Náčte kategorie z Firestore.
  Future<List<TaskCategory>> fetchCategories() async {
    if (_userId == null) {
      return _cachedCategories ?? [];
    }

    try {
      return await _withRetry<List<TaskCategory>>(() async {
        final snapshot =
            await _getCategoriesCollection().orderBy('sortOrder').get();

        final categories = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TaskCategory.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedCategories = categories;

        return categories;
      });
    } catch (e) {
      debugPrint('Chyba při náčítání kategorií: $e');
      return _cachedCategories ?? [];
    }
  }

  /// Přidá nový úkol.
  Future<void> addTask(Task task) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getTasksCollection().doc(task.id).set(task.toJson());

      // Aktualizujeme cache
      if (_cachedTasks != null) {
        _cachedTasks!.add(task);
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Aktualizuje existující úkol.
  Future<void> updateTask(Task task) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getTasksCollection().doc(task.id).update(task.toJson());

      // Aktualizujeme cache
      if (_cachedTasks != null) {
        final index = _cachedTasks!.indexWhere((t) => t.id == task.id);
        if (index >= 0) {
          _cachedTasks![index] = task;
          _cacheTimestamp = DateTime.now();
        }
      }
    });
  }

  /// Odstraní úkol.
  Future<void> removeTask(String taskId) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getTasksCollection().doc(taskId).delete();

      // Aktualizujeme cache
      if (_cachedTasks != null) {
        _cachedTasks!.removeWhere((t) => t.id == taskId);
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Přidá novou kategorii.
  Future<void> addCategory(TaskCategory category) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getCategoriesCollection().doc(category.id).set(category.toJson());

      // Aktualizujeme cache
      if (_cachedCategories != null) {
        _cachedCategories!.add(category);
        _cachedCategories!.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
    });
  }

  /// Aktualizuje existující kategorii.
  Future<void> updateCategory(TaskCategory category) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getCategoriesCollection()
          .doc(category.id)
          .update(category.toJson());

      // Aktualizujeme cache
      if (_cachedCategories != null) {
        final index = _cachedCategories!.indexWhere((c) => c.id == category.id);
        if (index >= 0) {
          _cachedCategories![index] = category;
          _cachedCategories!.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        }
      }
    });
  }

  /// Odstraní kategorii a přesune úkoly do výchozí kategorie.
  Future<void> removeCategory(
      String categoryId, String defaultCategoryId) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      // Najdeme vĹˇechny úkoly v tĂ©to kategorii
      final tasksInCategory = await _getTasksCollection()
          .where('category', isEqualTo: categoryId)
          .get();

      // Batch operace pro efektivnost
      final batch = _firestore.batch();

      // Přesuneme úkoly do výchozí kategorie
      for (final taskDoc in tasksInCategory.docs) {
        batch.update(taskDoc.reference, {
          'category': defaultCategoryId,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Smaťeme kategorii
      batch.delete(_getCategoriesCollection().doc(categoryId));

      // Provedeme batch operaci
      await batch.commit();

      // Aktualizujeme cache
      if (_cachedCategories != null) {
        _cachedCategories!.removeWhere((c) => c.id == categoryId);
      }
      if (_cachedTasks != null) {
        for (var i = 0; i < _cachedTasks!.length; i++) {
          if (_cachedTasks![i].category == categoryId) {
            _cachedTasks![i] =
                _cachedTasks![i].copyWith(category: defaultCategoryId);
          }
        }
      }
    });
  }

  /// Hromadná aktualizace úkolů (např. při změně kategorie).
  Future<void> batchUpdateTasks(List<Task> tasks) async {
    if (_userId == null || tasks.isEmpty) return;

    await _withRetry<void>(() async {
      final batch = _firestore.batch();

      for (final task in tasks) {
        final docRef = _getTasksCollection().doc(task.id);
        batch.update(docRef, task.toJson());
      }

      await batch.commit();

      // Aktualizujeme cache
      if (_cachedTasks != null) {
        for (final task in tasks) {
          final index = _cachedTasks!.indexWhere((t) => t.id == task.id);
          if (index >= 0) {
            _cachedTasks![index] = task;
          }
        }
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Oznáčí úkol jako dokončený/nedokončený.
  Future<void> toggleTaskDone(String taskId, bool isDone) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getTasksCollection().doc(taskId).update({
        'isDone': isDone,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Aktualizujeme cache
      if (_cachedTasks != null) {
        final index = _cachedTasks!.indexWhere((t) => t.id == taskId);
        if (index >= 0) {
          _cachedTasks![index] = _cachedTasks![index].copyWith(isDone: isDone);
          _cacheTimestamp = DateTime.now();
        }
      }
    });
  }

  /// Vymaťe vĹˇechny úkoly a kategorie.
  Future<void> clearAllData() async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      // Získáme vĹˇechny dokumenty
      final tasksSnapshot = await _getTasksCollection().get();
      final categoriesSnapshot = await _getCategoriesCollection().get();

      // Vytvoříme batch operaci
      final batch = _firestore.batch();

      // Přidáme smazání vĹˇech úkolů
      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Přidáme smazání vĹˇech kategorií
      for (final doc in categoriesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Provedeme batch operaci
      await batch.commit();

      // Vyčistíme cache
      _cachedTasks = [];
      _cachedCategories = [];
      _cacheTimestamp = DateTime.now();
    });
  }

  /// Synchronizuje data z lokálního úloťiĹˇtě do cloudu.
  Future<void> syncFromLocal(
      List<Task> localTasks, List<TaskCategory> localCategories) async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      // 1. Synchronizace kategorií
      final cloudCategoriesSnapshot = await _getCategoriesCollection().get();
      final cloudCategoryIds =
          cloudCategoriesSnapshot.docs.map((doc) => doc.id).toSet();
      final localCategoryIds = localCategories.map((c) => c.id).toSet();

      // Batch operace pro kategorie
      final categoriesBatch = _firestore.batch();

      // Přidání/aktualizace kategorií
      for (final category in localCategories) {
        final docRef = _getCategoriesCollection().doc(category.id);
        categoriesBatch.set(docRef, category.toJson(), SetOptions(merge: true));
      }

      // Odstranění kategorií, kterĂ© nejsou v lokálních datech
      final categoriesToRemove =
          cloudCategoryIds.where((id) => !localCategoryIds.contains(id));
      for (final id in categoriesToRemove) {
        categoriesBatch.delete(_getCategoriesCollection().doc(id));
      }

      await categoriesBatch.commit();

      // 2. Synchronizace úkolů
      final cloudTasksSnapshot = await _getTasksCollection().get();
      final cloudTaskIds = cloudTasksSnapshot.docs.map((doc) => doc.id).toSet();
      final localTaskIds = localTasks.map((t) => t.id).toSet();

      // Batch operace pro úkoly
      final tasksBatch = _firestore.batch();

      // Přidání/aktualizace úkolů
      for (final task in localTasks) {
        final docRef = _getTasksCollection().doc(task.id);
        tasksBatch.set(docRef, task.toJson(), SetOptions(merge: true));
      }

      // Odstranění úkolů, kterĂ© nejsou v lokálních datech
      final tasksToRemove =
          cloudTaskIds.where((id) => !localTaskIds.contains(id));
      for (final id in tasksToRemove) {
        tasksBatch.delete(_getTasksCollection().doc(id));
      }

      await tasksBatch.commit();

      // 3. Uloťíme časovou znáčku synchronizace
      await saveLastSyncTimestamp(DateTime.now());

      // Aktualizujeme cache
      _cachedTasks = List.from(localTasks);
      _cachedCategories = List.from(localCategories);
      _cacheTimestamp = DateTime.now();

      debugPrint("Synchronizace checklistu dokončena");
    });
  }

  /// Získá časovou znáčku poslední synchronizace.
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;

      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['lastChecklistSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastChecklistSync'];
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('Chyba při získávání časovĂ© znáčky synchronizace: $e');
      return null;
    }
  }

  /// Uloťí časovou znáčku poslední synchronizace.
  Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    try {
      if (_userId == null) return;

      await _firestore.collection('users').doc(_userId).set({
        'lastChecklistSync': Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Chyba při ukládání časovĂ© znáčky synchronizace: $e');
    }
  }

  /// Získá statistiky checklistu přímo z cloudu.
  Future<Map<String, dynamic>> getChecklistStatistics() async {
    if (_userId == null) {
      return {};
    }

    try {
      final tasks = await fetchTasks();
      final categories = await fetchCategories();

      final completed = tasks.where((t) => t.isDone).length;
      final total = tasks.length;
      final overdue = tasks
          .where((t) =>
              t.dueDate != null &&
              t.dueDate!.isBefore(DateTime.now()) &&
              !t.isDone)
          .length;

      return {
        'total': total,
        'completed': completed,
        'pending': total - completed,
        'percentage': total > 0 ? (completed / total * 100).round() : 0,
        'overdue': overdue,
        'highPriority': tasks.where((t) => t.priority == 1).length,
        'categories': categories.length,
        'lastSync': _cacheTimestamp,
      };
    } catch (e) {
      debugPrint('Chyba při získávání statistik: $e');
      return {};
    }
  }

  /// Retry wrapper pro Firebase operace.
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= _maxRetries) {
          rethrow;
        }

        // Exponenciální backoff
        final delay = _baseDelayMs * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delay));

        debugPrint('Retry attempt $attempt after ${delay}ms delay');
      }
    }

    throw Exception('Operation failed after $_maxRetries attempts');
  }
}
