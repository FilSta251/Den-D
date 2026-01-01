import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';

/// EventRepository zajiĹˇšuje náčítání, ukládání a aktualizaci událostí z Firestore.
/// Podporuje operace CRUD, lokální cachování, filtrování a řazení událostí.
class EventRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Lokální cache událostí.
  List<Event> _cachedEvents = [];

  // Stream controller pro vysílání změn událostí.
  final StreamController<List<Event>> _eventsStreamController =
      StreamController<List<Event>>.broadcast();

  /// Vrací stream událostí, který se aktualizuje při kaťdĂ© změně v kolekci 'events'.
  Stream<List<Event>> get eventsStream => _eventsStreamController.stream;

  /// Konstruktor: nastavuje real-time listener na kolekci 'events' v Firestore.
  EventRepository() {
    _firestore.collection('events').snapshots().listen((snapshot) {
      try {
        _cachedEvents = snapshot.docs.map((doc) {
          final data = doc.data();
          // Ujistíme se, ťe id dokumentu je součástí dat.
          data['id'] = doc.id;
          return Event.fromJson(data);
        }).toList();
        _eventsStreamController.add(_cachedEvents);
      } catch (e, stackTrace) {
        print('Error processing event snapshot: $e');
        print(stackTrace);
      }
    }, onError: (error) {
      print('Error listening to events collection: $error');
    });
  }

  /// Náčte a vrátí vĹˇechny události z Firestore.
  Future<List<Event>> fetchEvents() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('events').get();
      _cachedEvents = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Event.fromJson(data);
      }).toList();
      _eventsStreamController.add(_cachedEvents);
      return _cachedEvents;
    } catch (e, stackTrace) {
      print('Error fetching events: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Přidá novou událost do Firestore a aktualizuje cache.
  Future<void> addEvent(Event event) async {
    try {
      // Pouťijeme event.id, pokud je jiť definováno.
      await _firestore.collection('events').doc(event.id).set(event.toJson());
      // Cache a stream se aktualizují díky real-time listeneru.
    } catch (e, stackTrace) {
      print('Error adding event: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Aktualizuje existující událost v Firestore.
  /// Optimalizuje aktualizaci odesláním pouze změněných polí.
  Future<void> updateEvent(Event event) async {
    try {
      // Najdeme původní událost z cache pro porovnání.
      final Event original = _cachedEvents.firstWhere(
        (e) => e.id == event.id,
        orElse: () => event,
      );
      final Map<String, dynamic> originalJson = original.toJson();
      final Map<String, dynamic> updatedJson = event.toJson();

      // Porovnáme a vytvoříme mapu změněných hodnot.
      final Map<String, dynamic> changes = {};
      updatedJson.forEach((key, value) {
        if (originalJson[key] != value) {
          changes[key] = value;
        }
      });

      if (changes.isNotEmpty) {
        await _firestore.collection('events').doc(event.id).update(changes);
        // Aktualizace cache se provede díky real-time listeneru.
      }
    } catch (e, stackTrace) {
      print('Error updating event: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Smaťe událost s daným ID z Firestore.
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore.collection('events').doc(eventId).delete();
      // Cache a stream se automaticky aktualizují díky listeneru.
    } catch (e, stackTrace) {
      print('Error deleting event: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Vrací filtrovaný seznam událostí podle zadaných kritĂ©rií.
  List<Event> getFilteredEvents(
      {String? category, DateTime? fromDate, DateTime? toDate}) {
    return _cachedEvents.where((event) {
      bool matches = true;
      if (category != null && category.isNotEmpty) {
        matches = matches &&
            (event.category?.toLowerCase() == category.toLowerCase());
      }
      if (fromDate != null) {
        matches = matches &&
            (event.startTime.isAfter(fromDate) ||
                event.startTime.isAtSameMomentAs(fromDate));
      }
      if (toDate != null) {
        matches = matches &&
            (event.startTime.isBefore(toDate) ||
                event.startTime.isAtSameMomentAs(toDate));
      }
      return matches;
    }).toList();
  }

  /// Vrací řazený seznam událostí podle data (vzestupně nebo sestupně).
  List<Event> getSortedEvents({bool ascending = true}) {
    final List<Event> sorted = List.from(_cachedEvents);
    sorted.sort((a, b) => ascending
        ? a.startTime.compareTo(b.startTime)
        : b.startTime.compareTo(a.startTime));
    return sorted;
  }

  /// Zavře stream controller událostí.
  void dispose() {
    _eventsStreamController.close();
  }
}
