/// lib/models/calendar_event.dart
library;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Model reprezentující událost v kalendáři svatby
class CalendarEvent extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime? endTime;
  final bool allDay;
  final int color;
  final EventReminder? reminder;
  final String? category; // Zachováno pro zpětnou kompatibilitu
  final List<String> attendees;
  final DateTime createdAt;
  final DateTime updatedAt;

  // NOVÉ VLASTNOSTI PRO NOTIFIKACE
  final bool notificationEnabled;
  final int notificationMinutesBefore; // Počet minut před událostí

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    this.endTime,
    this.allDay = false,
    this.color = 0xFF2196F3, // Výchozí modrá barva
    this.reminder,
    this.category,
    this.attendees = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
    this.notificationEnabled = false,
    this.notificationMinutesBefore = 30,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Vytvoří instanci CalendarEvent z JSON
  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      allDay: json['allDay'] as bool? ?? false,
      color: json['color'] as int? ?? 0xFF2196F3,
      reminder: json['reminder'] != null
          ? EventReminder.fromJson(json['reminder'] as Map<String, dynamic>)
          : null,
      category: json['category'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      notificationEnabled: json['notificationEnabled'] as bool? ?? false,
      notificationMinutesBefore:
          json['notificationMinutesBefore'] as int? ?? 30,
    );
  }

  /// Převede CalendarEvent na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'allDay': allDay,
      'color': color,
      'reminder': reminder?.toJson(),
      'category': category,
      'attendees': attendees,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notificationEnabled': notificationEnabled,
      'notificationMinutesBefore': notificationMinutesBefore,
    };
  }

  /// Vytvoří kopii s upravenými hodnotami
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
    int? color,
    EventReminder? reminder,
    String? category,
    List<String>? attendees,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? notificationEnabled,
    int? notificationMinutesBefore,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allDay: allDay ?? this.allDay,
      color: color ?? this.color,
      reminder: reminder ?? this.reminder,
      category: category ?? this.category,
      attendees: attendees ?? this.attendees,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
    );
  }

  /// Získá Color objekt z int hodnoty
  Color get colorObject => Color(color);

  /// Získá dobu trvání události
  Duration? get duration => endTime?.difference(startTime);

  /// Kontroluje, zda událost probíhá v daný čas
  bool isOngoingAt(DateTime dateTime) {
    if (allDay) {
      return DateUtils.isSameDay(dateTime, startTime);
    }
    return dateTime.isAfter(startTime) &&
        (endTime == null || dateTime.isBefore(endTime!));
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        location,
        startTime,
        endTime,
        allDay,
        color,
        reminder,
        category,
        attendees,
        createdAt,
        updatedAt,
        notificationEnabled,
        notificationMinutesBefore,
      ];

  @override
  String toString() {
    return 'CalendarEvent(id: $id, title: $title, startTime: $startTime, allDay: $allDay, notificationEnabled: $notificationEnabled)';
  }
}

/// Model pro připomenutí události (zachováno pro zpětnou kompatibilitu)
class EventReminder extends Equatable {
  final String type; // minutes, hours, days
  final int value;
  final bool scheduled;
  final int? notificationId;

  const EventReminder({
    required this.type,
    required this.value,
    this.scheduled = false,
    this.notificationId,
  });

  factory EventReminder.fromJson(Map<String, dynamic> json) {
    return EventReminder(
      type: json['type'] as String,
      value: json['value'] as int,
      scheduled: json['scheduled'] as bool? ?? false,
      notificationId: json['notificationId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'value': value,
      'scheduled': scheduled,
      'notificationId': notificationId,
    };
  }

  EventReminder copyWith({
    String? type,
    int? value,
    bool? scheduled,
    int? notificationId,
  }) {
    return EventReminder(
      type: type ?? this.type,
      value: value ?? this.value,
      scheduled: scheduled ?? this.scheduled,
      notificationId: notificationId ?? this.notificationId,
    );
  }

  /// Vypočítá čas připomenutí
  DateTime getReminderTime(DateTime eventTime) {
    switch (type) {
      case 'minutes':
        return eventTime.subtract(Duration(minutes: value));
      case 'hours':
        return eventTime.subtract(Duration(hours: value));
      case 'days':
        return eventTime.subtract(Duration(days: value));
      default:
        return eventTime.subtract(Duration(minutes: value));
    }
  }

  /// Získá popis připomenutí
  String getDescription() {
    switch (type) {
      case 'minutes':
        return '$value minut předem';
      case 'hours':
        return '$value hodin předem';
      case 'days':
        return '$value dní předem';
      default:
        return '$value minut předem';
    }
  }

  @override
  List<Object?> get props => [type, value, scheduled, notificationId];
}

/// Kategorie událostí (zachováno pro zpětnou kompatibilitu, ale nepoužívá se v UI)
class EventCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const EventCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  static const List<EventCategory> defaultCategories = [
    EventCategory(
      id: 'ceremony',
      name: 'event_category_ceremony',
      icon: Icons.favorite,
      color: Colors.pink,
    ),
    EventCategory(
      id: 'preparation',
      name: 'event_category_preparation',
      icon: Icons.brush,
      color: Colors.purple,
    ),
    EventCategory(
      id: 'photo',
      name: 'event_category_photo',
      icon: Icons.camera_alt,
      color: Colors.blue,
    ),
    EventCategory(
      id: 'reception',
      name: 'event_category_reception',
      icon: Icons.restaurant,
      color: Colors.orange,
    ),
    EventCategory(
      id: 'party',
      name: 'event_category_party',
      icon: Icons.music_note,
      color: Colors.green,
    ),
    EventCategory(
      id: 'meeting',
      name: 'event_category_meeting',
      icon: Icons.people,
      color: Colors.teal,
    ),
    EventCategory(
      id: 'other',
      name: 'event_category_other',
      icon: Icons.event,
      color: Colors.grey,
    ),
  ];

  static EventCategory? getCategoryById(String id) {
    try {
      return defaultCategories.firstWhere((cat) => cat.id == id);
    } catch (_) {
      return null;
    }
  }
}
