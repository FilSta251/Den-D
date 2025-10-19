/// lib/models/event.dart
library;

/// Třída reprezentující událost v aplikaci.
///
/// Obsahuje klíčovĂ© atributy jako unikátní identifikátor, titulek, popis,
/// datum a čas záčátku a (volitelně) konce události, lokaci, kategorii
/// a časová razítka vytvoření a aktualizace. Tato třída takĂ© poskytuje metody
/// pro serializaci, kopírování a přepis operátorů pro správnĂ© porovnávání instancí.
class Event {
  /// Unikátní identifikátor události.
  final String id;

  /// Titulek události.
  final String title;

  /// Volitelný popis události.
  final String? description;

  /// Datum a čas záčátku události.
  final DateTime startTime;

  /// Volitelný datum a čas konce události.
  final DateTime? endTime;

  /// Volitelná lokace nebo místo konání.
  final String? location;

  /// Volitelná kategorie nebo typ události.
  final String? category;

  /// Datum a čas vytvoření události.
  final DateTime createdAt;

  /// Datum a čas poslední aktualizace události.
  final DateTime updatedAt;

  /// Primární konstruktor.
  ///
  /// Pokud je zadán [endTime], musí být [startTime] před [endTime].
  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.endTime,
    this.location,
    this.category,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    if (endTime != null && !startTime.isBefore(endTime!)) {
      throw ArgumentError('startTime must be before endTime');
    }
  }

  /// Vytvoří instanci [Event] z JSON mapy.
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      location: json['location'] as String?,
      category: json['category'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Vrací instanci [Event] jako JSON mapu.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'location': location,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// UmoťĹuje vytvoření novĂ© instance [Event] s moťností přepsání některých hodnot.
  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final newStartTime = startTime ?? this.startTime;
    final newEndTime = endTime ?? this.endTime;
    if (newEndTime != null && !newStartTime.isBefore(newEndTime)) {
      throw ArgumentError('startTime must be before endTime');
    }
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: newStartTime,
      endTime: newEndTime,
      location: location ?? this.location,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Přepis operátoru rovnosti pro správnĂ© porovnání instancí.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.location == location &&
        other.category == category &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  /// Přepis hashCode pro správnĂ© porovnání instancí.
  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        (description?.hashCode ?? 0) ^
        startTime.hashCode ^
        (endTime?.hashCode ?? 0) ^
        (location?.hashCode ?? 0) ^
        (category?.hashCode ?? 0) ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  /// Vrací textovou reprezentaci instance (uťitečnĂ© při ladění).
  @override
  String toString() {
    return 'Event(id: $id, title: $title, description: $description, startTime: $startTime, '
        'endTime: $endTime, location: $location, category: $category, '
        'createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
