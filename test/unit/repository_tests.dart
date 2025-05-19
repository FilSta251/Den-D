import 'package:flutter_test/flutter_test.dart';
import 'package:svatebni_planovac/models/task.dart';
import 'package:svatebni_planovac/repositories/tasks_repository.dart';

/// FakeTasksRepository simuluje chování TasksRepository pro účely testování.
/// V reálném testovacím prostředí by bylo vhodné využít knihovnu pro mockování, například cloud_firestore_mocks.
class FakeTasksRepository extends TasksRepository {
  List<Task> fakeTasks = [];

  // Override metody fetchTasks, aby vrátila falešná data místo skutečného volání Firestore.
  @override
  Future<List<Task>> fetchTasks() async {
    return fakeTasks;
  }

  // Metoda pro nastavení falešných úkolů, kterou využijeme při testování.
  void setFakeTasks(List<Task> tasks) {
    fakeTasks = tasks;
    // V reálném repozitáři by byla také aktualizována lokální cache a vyslán stream,
    // ale zde pracujeme přímo s metodou fetchTasks.
  }
}

void main() {
  group('FakeTasksRepository Tests', () {
    late FakeTasksRepository repository;

    setUp(() {
      repository = FakeTasksRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    test('fetchTasks returns empty list initially', () async {
      final tasks = await repository.fetchTasks();
      expect(tasks, isEmpty);
    });

    test('fetchTasks returns fake tasks after setting them', () async {
      repository.setFakeTasks([
        Task(
          id: '1',
          title: 'Task One',
          description: 'First task description',
          isCompleted: false,
          dueDate: DateTime.parse('2023-12-31T00:00:00Z'),
          priority: TaskPriority.high,
          createdAt: DateTime.parse('2023-01-01T00:00:00Z'),
          updatedAt: DateTime.parse('2023-01-01T00:00:00Z'),
        ),
        Task(
          id: '2',
          title: 'Task Two',
          description: 'Second task description',
          isCompleted: true,
          dueDate: DateTime.parse('2023-11-30T00:00:00Z'),
          priority: TaskPriority.medium,
          createdAt: DateTime.parse('2023-02-01T00:00:00Z'),
          updatedAt: DateTime.parse('2023-02-01T00:00:00Z'),
        ),
      ]);
      final tasks = await repository.fetchTasks();
      expect(tasks.length, equals(2));
      expect(tasks.first.title, equals('Task One'));
    });

    test('getFilteredTasks filters tasks by query', () async {
      repository.setFakeTasks([
        Task(
          id: '1',
          title: 'Buy Flowers',
          description: 'Need to buy wedding flowers',
          isCompleted: false,
          dueDate: DateTime.parse('2023-10-01T00:00:00Z'),
          priority: TaskPriority.low,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        Task(
          id: '2',
          title: 'Book Venue',
          description: 'Reserve the wedding venue',
          isCompleted: false,
          dueDate: DateTime.parse('2023-10-15T00:00:00Z'),
          priority: TaskPriority.high,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      final filtered = repository.getFilteredTasks(query: 'Buy');
      expect(filtered.length, equals(1));
      expect(filtered.first.title, equals('Buy Flowers'));
    });
  });
}
