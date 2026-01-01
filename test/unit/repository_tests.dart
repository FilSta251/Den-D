// test/unit/repository_tests.dart
// JEDNODUCHÁ VERZE - test repozitáře bez složitých závislostí

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TasksRepository Tests', () {
    late FakeTasksRepository repository;

    setUp(() {
      repository = FakeTasksRepository();
    });

    test('fetchTasks vrátí prázdný seznam na začátku', () async {
      final tasks = await repository.fetchTasks();
      expect(tasks, isEmpty);
    });

    test('fetchTasks vrátí úkoly po jejich přidání', () async {
      // Arrange
      repository.addTask(SimpleTask(
        id: '1',
        title: 'Objednat květiny',
        isCompleted: false,
      ));

      repository.addTask(SimpleTask(
        id: '2',
        title: 'Rezervovat místo',
        isCompleted: false,
      ));

      // Act
      final tasks = await repository.fetchTasks();

      // Assert
      expect(tasks.length, equals(2));
      expect(tasks[0].title, equals('Objednat květiny'));
      expect(tasks[1].title, equals('Rezervovat místo'));
    });

    test('updateTask změní existující úkol', () async {
      // Arrange
      repository.addTask(SimpleTask(
        id: '1',
        title: 'Původní název',
        isCompleted: false,
      ));

      // Act
      await repository.updateTask(
          '1',
          SimpleTask(
            id: '1',
            title: 'Nový název',
            isCompleted: true,
          ));

      // Assert
      final tasks = await repository.fetchTasks();
      expect(tasks[0].title, equals('Nový název'));
      expect(tasks[0].isCompleted, isTrue);
    });

    test('deleteTask odstraní úkol', () async {
      // Arrange
      repository
          .addTask(SimpleTask(id: '1', title: 'Task 1', isCompleted: false));
      repository
          .addTask(SimpleTask(id: '2', title: 'Task 2', isCompleted: false));

      // Act
      await repository.deleteTask('1');

      // Assert
      final tasks = await repository.fetchTasks();
      expect(tasks.length, equals(1));
      expect(tasks[0].id, equals('2'));
    });

    test('getTaskById vrátí správný úkol', () async {
      // Arrange
      repository
          .addTask(SimpleTask(id: '1', title: 'Task 1', isCompleted: false));
      repository
          .addTask(SimpleTask(id: '2', title: 'Task 2', isCompleted: false));

      // Act
      final task = await repository.getTaskById('2');

      // Assert
      expect(task, isNotNull);
      expect(task?.title, equals('Task 2'));
    });

    test('getCompletedTasks vrátí pouze dokončené úkoly', () async {
      // Arrange
      repository
          .addTask(SimpleTask(id: '1', title: 'Hotovo', isCompleted: true));
      repository.addTask(
          SimpleTask(id: '2', title: 'Nedokončeno', isCompleted: false));
      repository.addTask(
          SimpleTask(id: '3', title: 'Taky hotovo', isCompleted: true));

      // Act
      final completed = await repository.getCompletedTasks();

      // Assert
      expect(completed.length, equals(2));
      expect(completed.every((task) => task.isCompleted), isTrue);
    });

    test('getPendingTasks vrátí pouze nedokončené úkoly', () async {
      // Arrange
      repository
          .addTask(SimpleTask(id: '1', title: 'Hotovo', isCompleted: true));
      repository.addTask(
          SimpleTask(id: '2', title: 'Nedokončeno', isCompleted: false));
      repository.addTask(
          SimpleTask(id: '3', title: 'Taky nedokončeno', isCompleted: false));

      // Act
      final pending = await repository.getPendingTasks();

      // Assert
      expect(pending.length, equals(2));
      expect(pending.every((task) => !task.isCompleted), isTrue);
    });
  });
}

// ============================================================================
// POMOCNÉ TŘÍDY PRO TESTY
// ============================================================================

/// Jednoduchý model úkolu pro testování
class SimpleTask {
  final String id;
  final String title;
  final bool isCompleted;

  SimpleTask({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  SimpleTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
  }) {
    return SimpleTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Falešný repozitář pro testování
class FakeTasksRepository {
  final List<SimpleTask> _tasks = [];

  /// Načte všechny úkoly
  Future<List<SimpleTask>> fetchTasks() async {
    return List.from(_tasks);
  }

  /// Přidá nový úkol
  void addTask(SimpleTask task) {
    _tasks.add(task);
  }

  /// Aktualizuje existující úkol
  Future<void> updateTask(String id, SimpleTask updatedTask) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      _tasks[index] = updatedTask;
    }
  }

  /// Odstraní úkol
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
  }

  /// Najde úkol podle ID
  Future<SimpleTask?> getTaskById(String id) async {
    try {
      return _tasks.firstWhere((task) => task.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Vrátí pouze dokončené úkoly
  Future<List<SimpleTask>> getCompletedTasks() async {
    return _tasks.where((task) => task.isCompleted).toList();
  }

  /// Vrátí pouze nedokončené úkoly
  Future<List<SimpleTask>> getPendingTasks() async {
    return _tasks.where((task) => !task.isCompleted).toList();
  }

  /// Vyčistí všechny úkoly (pro tearDown)
  void clear() {
    _tasks.clear();
  }
}
