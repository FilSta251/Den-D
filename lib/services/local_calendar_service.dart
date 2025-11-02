import 'dart:convert';
import 'package:flutter/material.dart';
import 'base/base_local_storage_service.dart';
import '../models/calendar_event.dart';

/// Služba pro lokální správu kalendáře využívající základní třídu
class LocalCalendarService extends BaseLocalStorageService<CalendarEvent>
    with IdBasedItemsMixin<CalendarEvent>, TimeBasedItemsMixin<CalendarEvent> {
  LocalCalendarService() : super(storageKey: 'wedding_calendar_events');

  /// Seznam událostí (pro zpětnou kompatibilitu)
  List<CalendarEvent> get events => items;

  @override
  Map<String, dynamic> itemToJson(CalendarEvent item) {
    return item.toJson();
  }

  @override
  CalendarEvent itemFromJson(Map<String, dynamic> json) {
    return CalendarEvent.fromJson(json);
  }

  @override
  DateTime getItemTimestamp(CalendarEvent item) {
    return item.updatedAt;
  }

  @override
  String getItemId(CalendarEvent item) {
    return item.id;
  }

  /// Přidá událost
  void addEvent(CalendarEvent event) {
    addItem(event);
  }

  /// Odebere událost podle ID
  void removeEvent(String id) {
    removeItemById(id);
  }

  /// Aktualizuje událost
  void updateEvent(CalendarEvent updatedEvent) {
    updateItemById(updatedEvent.id, updatedEvent);
  }

  /// Získá události pro konkrétní den
  List<CalendarEvent> getEventsForDay(DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = DateTime(day.year, day.month, day.day, 23, 59, 59);

    return findItems((event) {
      if (event.allDay) {
        return DateUtils.isSameDay(event.startTime, day);
      }
      return (event.startTime.isAfter(dayStart) ||
              event.startTime.isAtSameMomentAs(dayStart)) &&
          event.startTime.isBefore(dayEnd);
    });
  }

  /// Získá události v daném měsíci
  List<CalendarEvent> getEventsForMonth(int year, int month) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

    return findItems((event) {
      return event.startTime.isAfter(monthStart) &&
          event.startTime.isBefore(monthEnd);
    });
  }

  /// Získá události v daném časovém rozmezí
  List<CalendarEvent> getEventsInRange(DateTime start, DateTime end) {
    return findItems((event) {
      return event.startTime.isAfter(start) && event.startTime.isBefore(end);
    });
  }

  /// Získá události podle barvy
  List<CalendarEvent> getEventsByColor(int color) {
    return findItems((event) => event.color == color);
  }

  /// Získá události podle kategorie (pro zpětnou kompatibilitu)
  List<CalendarEvent> getEventsByCategory(String category) {
    return findItems((event) => event.category == category);
  }

  /// Získá události s notifikací
  List<CalendarEvent> getEventsWithNotification() {
    return findItems((event) => event.notificationEnabled);
  }

  /// Získá události s připomenutím (pro zpětnou kompatibilitu)
  List<CalendarEvent> getEventsWithReminder() {
    return findItems(
        (event) => event.reminder != null || event.notificationEnabled);
  }

  /// Získá nadcházející události
  List<CalendarEvent> getUpcomingEvents({int days = 7}) {
    final now = DateTime.now();
    final future = now.add(Duration(days: days));

    return findItems((event) {
      return event.startTime.isAfter(now) && event.startTime.isBefore(future);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// Získá probíhající události
  List<CalendarEvent> getOngoingEvents() {
    final now = DateTime.now();

    return findItems((event) {
      if (event.allDay) {
        return DateUtils.isSameDay(event.startTime, now);
      }
      return event.startTime.isBefore(now) &&
          (event.endTime == null || event.endTime!.isAfter(now));
    });
  }

  /// Získá statistiky kalendáře
  Map<String, dynamic> getCalendarStatistics() {
    final upcoming = getUpcomingEvents();
    final ongoing = getOngoingEvents();
    final withNotification = getEventsWithNotification();

    return {
      'total': itemCount,
      'upcoming': upcoming.length,
      'ongoing': ongoing.length,
      'withNotification': withNotification.length,
      'lastModified': lastSyncTimestamp,
    };
  }

  /// Získá souhrn podle barev
  Map<int, int> getColorSummary() {
    final summary = <int, int>{};

    for (final event in events) {
      summary[event.color] = (summary[event.color] ?? 0) + 1;
    }

    return summary;
  }

  /// Získá souhrn podle kategorií (zachováno pro zpětnou kompatibilitu)
  Map<String, int> getCategorySummary() {
    final summary = <String, int>{};

    for (final event in events) {
      if (event.category != null) {
        summary[event.category!] = (summary[event.category!] ?? 0) + 1;
      }
    }

    return summary;
  }

  /// Kontrola konfliktů v čase
  List<CalendarEvent> findTimeConflicts(DateTime startTime, DateTime? endTime) {
    return findItems((event) {
      if (event.allDay) return false;

      final eventEnd =
          event.endTime ?? event.startTime.add(const Duration(hours: 1));
      final checkEnd = endTime ?? startTime.add(const Duration(hours: 1));

      // Kontrola překryvu
      return (startTime.isBefore(eventEnd) &&
          checkEnd.isAfter(event.startTime));
    });
  }

  /// Vytvoří novou událost
  static CalendarEvent createEvent({
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    DateTime? endTime,
    bool allDay = false,
    int color = 0xFF2196F3,
    EventReminder? reminder,
    String? category,
    List<String> attendees = const [],
    bool notificationEnabled = false,
    int notificationMinutesBefore = 30,
  }) {
    return CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      allDay: allDay,
      color: color,
      reminder: reminder,
      category: category,
      attendees: attendees,
      notificationEnabled: notificationEnabled,
      notificationMinutesBefore: notificationMinutesBefore,
    );
  }

  /// Vytvoří připomenutí (pro zpětnou kompatibilitu)
  static EventReminder createReminder({
    required String type,
    required int value,
  }) {
    return EventReminder(
      type: type,
      value: value,
    );
  }

  /// Export událostí do iCal formátu
  String exportToICal() {
    final buffer = StringBuffer();

    // iCal header
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Svatební plánovač//CZ');
    buffer.writeln('CALSCALE:GREGORIAN');

    // Události
    for (final event in events) {
      buffer.writeln('BEGIN:VEVENT');
      buffer.writeln('UID:${event.id}@svatebni-planovac.cz');
      buffer.writeln('DTSTAMP:${_formatDateTimeForICal(event.createdAt)}');

      if (event.allDay) {
        buffer.writeln(
            'DTSTART;VALUE=DATE:${_formatDateForICal(event.startTime)}');
        if (event.endTime != null) {
          buffer.writeln(
              'DTEND;VALUE=DATE:${_formatDateForICal(event.endTime!)}');
        }
      } else {
        buffer.writeln('DTSTART:${_formatDateTimeForICal(event.startTime)}');
        if (event.endTime != null) {
          buffer.writeln('DTEND:${_formatDateTimeForICal(event.endTime!)}');
        }
      }

      buffer.writeln('SUMMARY:${_escapeICalText(event.title)}');

      if (event.description != null) {
        buffer.writeln('DESCRIPTION:${_escapeICalText(event.description!)}');
      }

      if (event.location != null) {
        buffer.writeln('LOCATION:${_escapeICalText(event.location!)}');
      }

      // Notifikace
      if (event.notificationEnabled) {
        buffer.writeln('BEGIN:VALARM');
        buffer.writeln('ACTION:DISPLAY');
        buffer.writeln('DESCRIPTION:Připomenutí: ${event.title}');
        buffer.writeln('TRIGGER:-PT${event.notificationMinutesBefore}M');
        buffer.writeln('END:VALARM');
      }

      buffer.writeln('END:VEVENT');
    }

    buffer.writeln('END:VCALENDAR');

    return buffer.toString();
  }

  /// Formátuje datum pro iCal
  String _formatDateForICal(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Formátuje datum a čas pro iCal
  String _formatDateTimeForICal(DateTime dateTime) {
    return '${dateTime.year.toString().padLeft(4, '0')}'
        '${dateTime.month.toString().padLeft(2, '0')}'
        '${dateTime.day.toString().padLeft(2, '0')}'
        'T'
        '${dateTime.hour.toString().padLeft(2, '0')}'
        '${dateTime.minute.toString().padLeft(2, '0')}'
        '${dateTime.second.toString().padLeft(2, '0')}'
        'Z';
  }

  /// Escapuje text pro iCal
  String _escapeICalText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  /// Nastaví události bez notifikace (pro synchronizaci)
  void setEventsWithoutNotify(List<CalendarEvent> events) {
    setItemsWithoutNotify(events);
  }

  /// Exportuje data událostí do JSON
  @override
  String exportToJson() {
    final data = {
      'events': items.map((event) => event.toJson()).toList(),
      'exportDate': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
    return jsonEncode(data);
  }

  /// Importuje data událostí z JSON
  @override
  Future<void> importFromJson(String jsonData) async {
    try {
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      // Import událostí
      if (data.containsKey('events')) {
        final eventsList = (data['events'] as List<dynamic>)
            .map((json) => CalendarEvent.fromJson(json as Map<String, dynamic>))
            .toList();
        setItemsWithoutNotify(eventsList);
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Chyba při importu dat kalendáře: $e");
      throw Exception('Nepodařilo se importovat data: $e');
    }
  }
}
