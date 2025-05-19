/// Enum pro definici priority úkolu.
enum TaskPriority { low, medium, high }

/// Třída reprezentující úkol ve vaší aplikaci.
class Task {
  /// Unikátní identifikátor úkolu.
  final String id;

  /// Název úkolu.
  final String title;

  /// Volitelný popis úkolu.
  final String? description;

  /// Stav, zda je úkol dokončen.
  final bool isCompleted;

  /// Volitelný termín, do kdy má být úkol splněn.
  final DateTime? dueDate;

  /// Volitelná priorita úkolu.
  final TaskPriority? priority;

  /// Datum vytvoření úkolu.
  final DateTime createdAt;

  /// Datum poslední aktualizace úkolu.
  final DateTime updatedAt;

  /// Primární konstruktor. Pokud nejsou zadána data pro vytvoření či aktualizaci, použijí se výchozí hodnoty.
  Task({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.dueDate,
    this.priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Vytvoří instanci Task z JSON mapy.
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
      priority: json['priority'] != null
          ? _priorityFromString(json['priority'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Vrací instanci Task jako JSON mapu.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority != null ? _priorityToString(priority!) : null,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Umožňuje vytvoření nové instance s přepsáním vybraných hodnot.
  Task copyWith({
    String? id,
    String? title,
    String? description,
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
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      // Při úpravě aktualizujeme updatedAt na aktuální čas, pokud není předáno.
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Task(id: $id, title: $title, description: $description, '
        'isCompleted: $isCompleted, dueDate: $dueDate, priority: $priority, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Getter, který vrací hodnotu createdAt jako timestamp.
  DateTime get timestamp => createdAt;

  static TaskPriority _priorityFromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        return TaskPriority.low;
    }
  }

  static String _priorityToString(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
    }
  }
}
