// test/unit/model_tests.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task Model Tests', () {
    test('Task.fromJson vytvoří platnou instanci Task', () {
      final json = {
        'id': '1',
        'title': 'Rezervovat místo',
        'description': 'Rezervovat místo pro svatbu',
        'category': 'venue',
        'isCompleted': false,
        'dueDate': '2023-12-01T12:00:00Z',
        'priority': 'high',
        'createdAt': '2023-01-05T12:00:00Z',
        'updatedAt': '2023-01-05T12:00:00Z',
      };

      final task = Task.fromJson(json);
      expect(task.id, '1');
      expect(task.title, 'Rezervovat místo');
      expect(task.description, 'Rezervovat místo pro svatbu');
      expect(task.category, 'venue');
      expect(task.isCompleted, false);
      expect(task.dueDate, DateTime.parse('2023-12-01T12:00:00Z'));
      expect(task.priority, TaskPriority.high);
      expect(task.createdAt, DateTime.parse('2023-01-05T12:00:00Z'));
      expect(task.updatedAt, DateTime.parse('2023-01-05T12:00:00Z'));
    });

    test('Task.toJson vrátí platnou JSON mapu', () {
      final task = Task(
        id: '1',
        title: 'Rezervovat místo',
        description: 'Rezervovat místo pro svatbu',
        category: 'venue',
        isCompleted: false,
        dueDate: DateTime.parse('2023-12-01T12:00:00Z'),
        priority: TaskPriority.high,
        createdAt: DateTime.parse('2023-01-05T12:00:00Z'),
        updatedAt: DateTime.parse('2023-01-05T12:00:00Z'),
      );

      final json = task.toJson();
      expect(json['id'], '1');
      expect(json['title'], 'Rezervovat místo');
      expect(json['description'], 'Rezervovat místo pro svatbu');
      expect(json['category'], 'venue');
      expect(json['isCompleted'], false);
      expect(json['dueDate'], '2023-12-01T12:00:00.000Z');
      expect(json['priority'], 'high');
      expect(json['createdAt'], '2023-01-05T12:00:00.000Z');
      expect(json['updatedAt'], '2023-01-05T12:00:00.000Z');
    });

    test('Task.copyWith vytvoří aktualizovanou instanci', () {
      final task = Task(
        id: '1',
        title: 'Rezervovat místo',
        description: 'Rezervovat místo pro svatbu',
        category: 'venue',
        isCompleted: false,
        dueDate: DateTime.parse('2023-12-01T12:00:00Z'),
        priority: TaskPriority.high,
        createdAt: DateTime.parse('2023-01-05T12:00:00Z'),
        updatedAt: DateTime.parse('2023-01-05T12:00:00Z'),
      );

      final updatedTask = task.copyWith(
        isCompleted: true,
        title: 'Místo rezervováno',
      );

      expect(updatedTask.id, task.id);
      expect(updatedTask.title, 'Místo rezervováno');
      expect(updatedTask.isCompleted, true);
      expect(updatedTask.description, task.description);
      expect(updatedTask.category, task.category);
      expect(updatedTask.dueDate, task.dueDate);
      expect(updatedTask.priority, task.priority);
    });
  });

  group('Helper Model Tests', () {
    test('Helper.fromJson vytvoří platnou instanci Helper', () {
      final json = {
        'id': 'helper1',
        'name': 'Alice Smith',
        'role': 'Koordinátor',
        'profilePictureUrl': 'https://example.com/image.jpg',
        'contact': '+123456789'
      };

      final helper = Helper.fromJson(json);
      expect(helper.id, 'helper1');
      expect(helper.name, 'Alice Smith');
      expect(helper.role, 'Koordinátor');
      expect(helper.profilePictureUrl, 'https://example.com/image.jpg');
      expect(helper.contact, '+123456789');
    });

    test('Helper.toJson vrátí platnou JSON mapu', () {
      final helper = Helper(
        id: 'helper1',
        name: 'Alice Smith',
        role: 'Koordinátor',
        profilePictureUrl: 'https://example.com/image.jpg',
        contact: '+123456789',
      );

      final json = helper.toJson();
      expect(json['id'], 'helper1');
      expect(json['name'], 'Alice Smith');
      expect(json['role'], 'Koordinátor');
      expect(json['profilePictureUrl'], 'https://example.com/image.jpg');
      expect(json['contact'], '+123456789');
    });

    test('Helper.copyWith vytvoří aktualizovanou instanci', () {
      final helper = Helper(
        id: 'helper1',
        name: 'Alice Smith',
        role: 'Koordinátor',
        profilePictureUrl: 'https://example.com/image.jpg',
        contact: '+123456789',
      );

      final updatedHelper = helper.copyWith(
        name: 'Alice Johnson',
        contact: '+987654321',
      );

      expect(updatedHelper.id, helper.id);
      expect(updatedHelper.name, 'Alice Johnson');
      expect(updatedHelper.contact, '+987654321');
      expect(updatedHelper.role, helper.role);
      expect(updatedHelper.profilePictureUrl, helper.profilePictureUrl);
    });
  });
}

// ============================================================================
// POMOCNÉ TŘÍDY PRO TESTY
// ============================================================================

enum TaskPriority {
  low,
  medium,
  high;

  static TaskPriority fromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }

  String toJson() => name;
}

class Task {
  final String id;
  final String title;
  final String description;
  final String category;
  final bool isCompleted;
  final DateTime dueDate;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.isCompleted,
    required this.dueDate,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      dueDate: DateTime.parse(json['dueDate'] as String),
      priority:
          TaskPriority.fromString(json['priority'] as String? ?? 'medium'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'isCompleted': isCompleted,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    bool? isCompleted,
    DateTime? dueDate,
    TaskPriority? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Helper {
  final String id;
  final String name;
  final String role;
  final String? profilePictureUrl;
  final String contact;

  Helper({
    required this.id,
    required this.name,
    required this.role,
    this.profilePictureUrl,
    required this.contact,
  });

  factory Helper.fromJson(Map<String, dynamic> json) {
    return Helper(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      contact: json['contact'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'profilePictureUrl': profilePictureUrl,
      'contact': contact,
    };
  }

  Helper copyWith({
    String? id,
    String? name,
    String? role,
    String? profilePictureUrl,
    String? contact,
  }) {
    return Helper(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      contact: contact ?? this.contact,
    );
  }
}
