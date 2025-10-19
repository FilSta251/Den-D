/// lib/models/task.dart
library;

import 'package:equatable/equatable.dart';

/// Model reprezentující úkol v checklistu svatby
class Task extends Equatable {
  final String id;
  final String title;
  final String category;
  final bool isDone;
  final DateTime? dueDate;
  final String? note;
  final int priority; // 1 = vysoká, 2 = střední, 3 = nízká
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.category,
    this.isDone = false,
    this.dueDate,
    this.note,
    this.priority = 2,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Vytvoří instanci Task z JSON
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      isDone: json['isDone'] as bool? ?? false,
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'] as String)
          : null,
      note: json['note'] as String?,
      priority: json['priority'] as int? ?? 2,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Převede Task na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'isDone': isDone,
      'dueDate': dueDate?.toIso8601String(),
      'note': note,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Vytvoří kopii s upravenými hodnotami
  Task copyWith({
    String? id,
    String? title,
    String? category,
    bool? isDone,
    DateTime? dueDate,
    String? note,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        category,
        isDone,
        dueDate,
        note,
        priority,
        createdAt,
        updatedAt,
      ];

  @override
  String toString() {
    return 'Task(id: $id, title: $title, category: $category, isDone: $isDone, priority: $priority)';
  }
}

/// Model reprezentující kategorii úkolů
class TaskCategory extends Equatable {
  final String id;
  final String name;
  final String description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskCategory({
    required this.id,
    required this.name,
    required this.description,
    this.sortOrder = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Vytvoří instanci TaskCategory z JSON
  factory TaskCategory.fromJson(Map<String, dynamic> json) {
    return TaskCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Převede TaskCategory na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Vytvoří kopii s upravenými hodnotami
  TaskCategory copyWith({
    String? id,
    String? name,
    String? description,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, description, sortOrder, createdAt, updatedAt];

  @override
  String toString() =>
      'TaskCategory(id: $id, name: $name, sortOrder: $sortOrder)';
}
