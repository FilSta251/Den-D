/// lib/services/cloud_calendar_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import 'package:flutter/material.dart';

/// Sluťba pro cloudovou synchronizaci kalendáře.
///
/// poskytuje kompletní správu kalendářních událostí
/// s real-time synchronizací napříč zařízeními.
class CloudCalendarService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  // Konstanty pro retry mechanismus
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 500;

  // Cache pro offline pouťití
  List<CalendarEvent>? _cachedEvents;
  DateTime? _cacheTimestamp;

  // Názvy kolekcí
  static const String _eventsCollection = 'calendar_events';

  CloudCalendarService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  /// Vrací ID aktuálně přihláĹˇenĂ©ho uťivatele.
  String? get _userId => _auth.currentUser?.uid;

  /// Vrací referenci na kolekci událostí pro aktuálního uťivatele.
  CollectionReference<Map<String, dynamic>> _getEventsCollection() {
    if (_userId == null) {
      throw Exception('Uťivatel není přihláĹˇen.');
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_eventsCollection);
  }

  /// Získá stream událostí, který se aktualizuje v reálnĂ©m čase.
  Stream<List<CalendarEvent>> getEventsStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getEventsCollection()
          .orderBy('startTime')
          .snapshots()
          .map((snapshot) {
        final events = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return CalendarEvent.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedEvents = events;
        _cacheTimestamp = DateTime.now();

        return events;
      }).handleError((error) {
        debugPrint('Chyba při získávání streamu událostí: $error');
        return _cachedEvents ?? [];
      });
    } catch (e) {
      debugPrint('Chyba při vytváření streamu událostí: $e');
      return Stream.value(_cachedEvents ?? []);
    }
  }

  /// Náčte události z Firestore.
  Future<List<CalendarEvent>> fetchEvents() async {
    if (_userId == null) {
      return _cachedEvents ?? [];
    }

    try {
      return await _withRetry<List<CalendarEvent>>(() async {
        final snapshot =
            await _getEventsCollection().orderBy('startTime').get();

        final events = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return CalendarEvent.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedEvents = events;
        _cacheTimestamp = DateTime.now();

        return events;
      });
    } catch (e) {
      debugPrint('Chyba při náčítání událostí: $e');
      return _cachedEvents ?? [];
    }
  }

  /// Přidá novou událost.
  Future<void> addEvent(CalendarEvent event) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getEventsCollection().doc(event.id).set(event.toJson());

      // Aktualizujeme cache
      if (_cachedEvents != null) {
        _cachedEvents!.add(event);
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Aktualizuje existující událost.
  Future<void> updateEvent(CalendarEvent event) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getEventsCollection().doc(event.id).update(event.toJson());

      // Aktualizujeme cache
      if (_cachedEvents != null) {
        final index = _cachedEvents!.indexWhere((e) => e.id == event.id);
        if (index >= 0) {
          _cachedEvents![index] = event;
          _cacheTimestamp = DateTime.now();
        }
      }
    });
  }

  /// Odstraní událost.
  Future<void> removeEvent(String eventId) async {
    if (_userId == null) {
      throw Exception("Uťivatel není přihláĹˇen");
    }

    await _withRetry<void>(() async {
      await _getEventsCollection().doc(eventId).delete();

      // Aktualizujeme cache
      if (_cachedEvents != null) {
        _cachedEvents!.removeWhere((e) => e.id == eventId);
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Hromadná aktualizace událostí.
  Future<void> batchUpdateEvents(List<CalendarEvent> events) async {
    if (_userId == null || events.isEmpty) return;

    await _withRetry<void>(() async {
      final batch = _firestore.batch();

      for (final event in events) {
        final docRef = _getEventsCollection().doc(event.id);
        batch.update(docRef, event.toJson());
      }

      await batch.commit();

      // Aktualizujeme cache
      if (_cachedEvents != null) {
        for (final event in events) {
          final index = _cachedEvents!.indexWhere((e) => e.id == event.id);
          if (index >= 0) {
            _cachedEvents![index] = event;
          }
        }
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Vymaťe vĹˇechny události.
  Future<void> clearAllData() async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      // Získáme vĹˇechny dokumenty
      final eventsSnapshot = await _getEventsCollection().get();

      // Vytvoříme batch operaci
      final batch = _firestore.batch();

      // Přidáme smazání vĹˇech událostí
      for (final doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Provedeme batch operaci
      await batch.commit();

      // Vyčistíme cache
      _cachedEvents = [];
      _cacheTimestamp = DateTime.now();
    });
  }

  /// Synchronizuje data z lokálního úloťiĹˇtě do cloudu.
  Future<void> syncFromLocal(List<CalendarEvent> localEvents) async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      // Synchronizace událostí
      final cloudEventsSnapshot = await _getEventsCollection().get();
      final cloudEventIds =
          cloudEventsSnapshot.docs.map((doc) => doc.id).toSet();
      final localEventIds = localEvents.map((e) => e.id).toSet();

      // Batch operace pro události
      final eventsBatch = _firestore.batch();

      // Přidání/aktualizace událostí
      for (final event in localEvents) {
        final docRef = _getEventsCollection().doc(event.id);
        eventsBatch.set(docRef, event.toJson(), SetOptions(merge: true));
      }

      // Odstranění událostí, kterĂ© nejsou v lokálních datech
      final eventsToRemove =
          cloudEventIds.where((id) => !localEventIds.contains(id));
      for (final id in eventsToRemove) {
        eventsBatch.delete(_getEventsCollection().doc(id));
      }

      await eventsBatch.commit();

      // Uloťíme časovou znáčku synchronizace
      await saveLastSyncTimestamp(DateTime.now());

      // Aktualizujeme cache
      _cachedEvents = List.from(localEvents);
      _cacheTimestamp = DateTime.now();

      debugPrint("Synchronizace kalendáře dokončena");
    });
  }

  /// Získá časovou znáčku poslední synchronizace.
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;

      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['lastCalendarSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastCalendarSync'];
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('Chyba při získávání časovĂ© znáčky synchronizace: $e');
      return null;
    }
  }

  /// Uloťí časovou znáčku poslední synchronizace.
  Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    try {
      if (_userId == null) return;

      await _firestore.collection('users').doc(_userId).set({
        'lastCalendarSync': Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Chyba při ukládání časovĂ© znáčky synchronizace: $e');
    }
  }

  /// Získá statistiky kalendáře přímo z cloudu.
  Future<Map<String, dynamic>> getCalendarStatistics() async {
    if (_userId == null) {
      return {};
    }

    try {
      final events = await fetchEvents();
      final now = DateTime.now();

      final upcoming = events.where((e) => e.startTime.isAfter(now)).toList();
      final ongoing = events.where((e) {
        if (e.allDay) {
          return DateUtils.isSameDay(e.startTime, now);
        }
        return e.startTime.isBefore(now) &&
            (e.endTime == null || e.endTime!.isAfter(now));
      }).toList();

      final withReminder = events.where((e) => e.reminder != null).toList();

      return {
        'total': events.length,
        'upcoming': upcoming.length,
        'ongoing': ongoing.length,
        'withReminder': withReminder.length,
        'lastSync': _cacheTimestamp,
      };
    } catch (e) {
      debugPrint('Chyba při získávání statistik: $e');
      return {};
    }
  }

  /// Retry wrapper pro Firebase operace.
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= _maxRetries) {
          rethrow;
        }

        // Exponenciální backoff
        final delay = _baseDelayMs * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delay));

        debugPrint('Retry attempt $attempt after ${delay}ms delay');
      }
    }

    throw Exception('Operation failed after $_maxRetries attempts');
  }
}
