import 'package:flutter_test/flutter_test.dart';
import 'package:svatebni_planovac/models/task.dart';
import 'package:svatebni_planovac/models/helper.dart';

void main() {
  group('Task Model Tests', () {
    test('Task.fromJson creates a valid Task instance', () {
      final json = {
        'id': '1',
        'title': 'Book Venue',
        'description': 'Book the wedding venue',
        'isCompleted': false,
        'dueDate': '2023-12-01T12:00:00Z',
        'priority': 'high',
        'createdAt': '2023-01-05T12:00:00Z',
        'updatedAt': '2023-01-05T12:00:00Z',
      };

      final task = Task.fromJson(json);
      expect(task.id, '1');
      expect(task.title, 'Book Venue');
      expect(task.description, 'Book the wedding venue');
      expect(task.isCompleted, false);
      expect(task.dueDate, DateTime.parse('2023-12-01T12:00:00Z'));
      expect(task.priority, TaskPriority.high);
      expect(task.createdAt, DateTime.parse('2023-01-05T12:00:00Z'));
      expect(task.updatedAt, DateTime.parse('2023-01-05T12:00:00Z'));
    });

    test('Task.toJson returns a valid JSON map', () {
      final task = Task(
        id: '1',
        title: 'Book Venue',
        description: 'Book the wedding venue',
        isCompleted: false,
        dueDate: DateTime.parse('2023-12-01T12:00:00Z'),
        priority: TaskPriority.high,
        createdAt: DateTime.parse('2023-01-05T12:00:00Z'),
        updatedAt: DateTime.parse('2023-01-05T12:00:00Z'),
      );

      final json = task.toJson();
      expect(json['id'], '1');
      expect(json['title'], 'Book Venue');
      expect(json['description'], 'Book the wedding venue');
      expect(json['isCompleted'], false);
      expect(json['dueDate'], '2023-12-01T12:00:00.000Z');
      expect(json['priority'], 'high');
      expect(json['createdAt'], '2023-01-05T12:00:00.000Z');
      expect(json['updatedAt'], '2023-01-05T12:00:00.000Z');
    });

    test('Task.copyWith creates an updated instance', () {
      final task = Task(
        id: '1',
        title: 'Book Venue',
        description: 'Book the wedding venue',
        isCompleted: false,
        dueDate: DateTime.parse('2023-12-01T12:00:00Z'),
        priority: TaskPriority.high,
        createdAt: DateTime.parse('2023-01-05T12:00:00Z'),
        updatedAt: DateTime.parse('2023-01-05T12:00:00Z'),
      );

      final updatedTask = task.copyWith(isCompleted: true, title: 'Book Venue Updated');
      expect(updatedTask.id, task.id);
      expect(updatedTask.title, 'Book Venue Updated');
      expect(updatedTask.isCompleted, true);
      expect(updatedTask.description, task.description);
      expect(updatedTask.dueDate, task.dueDate);
      expect(updatedTask.priority, task.priority);
    });
  });

  group('Helper Model Tests', () {
    test('Helper.fromJson creates a valid Helper instance', () {
      final json = {
        'id': 'helper1',
        'name': 'Alice Smith',
        'role': 'Coordinator',
        'profilePictureUrl': 'https://example.com/image.jpg',
        'contact': '+123456789'
      };

      final helper = Helper.fromJson(json);
      expect(helper.id, 'helper1');
      expect(helper.name, 'Alice Smith');
      expect(helper.role, 'Coordinator');
      expect(helper.profilePictureUrl, 'https://example.com/image.jpg');
      expect(helper.contact, '+123456789');
    });

    test('Helper.toJson returns a valid JSON map', () {
      final helper = Helper(
        id: 'helper1',
        name: 'Alice Smith',
        role: 'Coordinator',
        profilePictureUrl: 'https://example.com/image.jpg',
        contact: '+123456789',
      );

      final json = helper.toJson();
      expect(json['id'], 'helper1');
      expect(json['name'], 'Alice Smith');
      expect(json['role'], 'Coordinator');
      expect(json['profilePictureUrl'], 'https://example.com/image.jpg');
      expect(json['contact'], '+123456789');
    });

    test('Helper.copyWith creates an updated instance', () {
      final helper = Helper(
        id: 'helper1',
        name: 'Alice Smith',
        role: 'Coordinator',
        profilePictureUrl: 'https://example.com/image.jpg',
        contact: '+123456789',
      );

      final updatedHelper = helper.copyWith(name: 'Alice Johnson', contact: '+987654321');
      expect(updatedHelper.id, helper.id);
      expect(updatedHelper.name, 'Alice Johnson');
      expect(updatedHelper.contact, '+987654321');
      expect(updatedHelper.role, helper.role);
      expect(updatedHelper.profilePictureUrl, helper.profilePictureUrl);
    });
  });
}
