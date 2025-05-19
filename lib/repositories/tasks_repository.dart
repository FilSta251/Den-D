import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';

/// TasksRepository zajišťuje správu dat úkolů z Firestore.
/// Poskytuje CRUD operace, real-time synchronizaci, lokální cachování
/// a metody pro filtrování dat.
class TasksRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _tasksCollection;

  // Lokální cache seznamu úkolů.
  List<Task> _cachedTasks = [];

  // Stream controller pro vysílání aktuálního seznamu úkolů.
  final StreamController<List<Task>> _tasksStreamController =
      StreamController<List<Task>>.broadcast();

  // Firestore subscription pro real-time aktualizace.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// Stream, který vysílá aktuální seznam úkolů v reálném čase.
  Stream<List<Task>> get tasksStream => _tasksStreamController.stream;

  /// Konstruktor třídy TasksRepository.
  TasksRepository() {
    _tasksCollection = _firestore.collection('tasks');
    _initializeListener();
  }

  /// Nastaví real-time posluchače změn v kolekci 'tasks' na Firestore.
  void _initializeListener() {
    _subscription = _tasksCollection.snapshots().listen(
      (snapshot) {
        try {
          _cachedTasks = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Zajištění, že máme dokumentové ID.
            return Task.fromJson(data);
          }).toList();
          _tasksStreamController.add(_cachedTasks);
        } catch (error, stackTrace) {
          debugPrint('Error processing tasks snapshot: $error');
          debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
          _tasksStreamController.addError(error);
        }
      },
      onError: (error) {
        debugPrint('Error listening to tasks collection: $error');
        _tasksStreamController.addError(error);
      },
    );
  }

  /// Načte seznam úkolů z Firestore s retry mechanismem.
  Future<List<Task>> fetchTasks() async {
    const int maxAttempts = 3;
    int attempts = 0;
    while (attempts < maxAttempts) {
      try {
        QuerySnapshot<Map<String, dynamic>> snapshot = await _tasksCollection.get();
        _cachedTasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Task.fromJson(data);
        }).toList();
        _tasksStreamController.add(_cachedTasks);
        return _cachedTasks;
      } catch (error, stackTrace) {
        attempts++;
        debugPrint('Error fetching tasks (attempt $attempts): $error');
        debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
        if (attempts >= maxAttempts) {
          throw Exception('Chyba při načítání úkolů po $attempts pokusech: $error\n$stackTrace');
        }
        await Future.delayed(Duration(seconds: 2 * attempts));
      }
    }
    throw Exception('Nepodařilo se načíst úkoly.');
  }

  /// Přidá nový úkol do Firestore.
  Future<void> addTask(Task task) async {
    try {
      if (task.id.isNotEmpty) {
        await _tasksCollection.doc(task.id).set(task.toJson());
      } else {
        await _tasksCollection.add(task.toJson());
      }
    } catch (error, stackTrace) {
      debugPrint('Error adding task: $error');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Aktualizuje existující úkol.
  Future<void> updateTask(Task task) async {
    try {
      final DocumentReference<Map<String, dynamic>> docRef = _tasksCollection.doc(task.id);
      await docRef.update(task.toJson());
    } catch (error, stackTrace) {
      debugPrint('Error updating task: $error');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Aktualizuje stav dokončení úkolu.
  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    try {
      await _tasksCollection.doc(taskId).update({
        'isCompleted': isCompleted,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (error, stackTrace) {
      debugPrint('Error updating task completion: $error');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Smaže úkol podle jeho ID.
  Future<void> deleteTask(String taskId) async {
    try {
      await _tasksCollection.doc(taskId).delete();
    } catch (error, stackTrace) {
      debugPrint('Error deleting task: $error');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Vrací filtrovaný seznam úkolů dle zadaných kritérií.
  List<Task> getFilteredTasks({String? query, bool? isCompleted}) {
    List<Task> filtered = List.from(_cachedTasks);
    if (query != null && query.trim().isNotEmpty) {
      filtered = filtered.where((task) =>
          task.title.toLowerCase().contains(query.trim().toLowerCase())).toList();
    }
    if (isCompleted != null) {
      filtered = filtered.where((task) => task.isCompleted == isCompleted).toList();
    }
    return filtered;
  }

  /// Uvolní zdroje – zruší Firestore subscription a zavře stream controller.
  void dispose() {
    _subscription?.cancel();
    _tasksStreamController.close();
  }
}
