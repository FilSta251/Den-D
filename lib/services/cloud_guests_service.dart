/// lib/services/cloud_guests_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/guest.dart';
import '../models/table_arrangement.dart';

/// Služba pro cloudovou synchronizaci hostů a stolů svatby.
///
/// poskytuje kompletní správu hostů a jejich rozmístění u stolů
/// s real-time synchronizací napříč zařízeními.
class CloudGuestsService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  // Konstanty pro retry mechanismus
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 500;

  // Cache pro offline použití
  List<Guest>? _cachedGuests;
  List<TableArrangement>? _cachedTables;
  DateTime? _cacheTimestamp;

  // Názvy kolekcí
  static const String _guestsCollection = 'guests';
  static const String _tablesCollection = 'tables';

  CloudGuestsService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  /// Vrací ID aktuálně přihlášeného uživatele.
  String? get _userId => _auth.currentUser?.uid;

  /// Vrací referenci na kolekci hostů pro aktuálního uživatele.
  CollectionReference<Map<String, dynamic>> _getGuestsCollection() {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_guestsCollection);
  }

  /// Vrací referenci na kolekci stolů pro aktuálního uživatele.
  CollectionReference<Map<String, dynamic>> _getTablesCollection() {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection(_tablesCollection);
  }

  /// Získá stream hostů, který se aktualizuje v reálném čase.
  Stream<List<Guest>> getGuestsStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getGuestsCollection()
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        final guests = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Guest.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedGuests = guests;
        _cacheTimestamp = DateTime.now();

        return guests;
      }).handleError((error) {
        debugPrint('Chyba při získávání streamu hostů: $error');
        return _cachedGuests ?? [];
      });
    } catch (e) {
      debugPrint('Chyba při vytváření streamu hostů: $e');
      return Stream.value(_cachedGuests ?? []);
    }
  }

  /// Získá stream stolů, který se aktualizuje v reálném čase.
  Stream<List<TableArrangement>> getTablesStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getTablesCollection().orderBy('name').snapshots().map((snapshot) {
        final tables = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TableArrangement.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedTables = tables;

        return tables;
      }).handleError((error) {
        debugPrint('Chyba při získávání streamu stolů: $error');
        return _cachedTables ?? [];
      });
    } catch (e) {
      debugPrint('Chyba při vytváření streamu stolů: $e');
      return Stream.value(_cachedTables ?? []);
    }
  }

  /// Načte hosty z Firestore.
  Future<List<Guest>> fetchGuests() async {
    if (_userId == null) {
      return _cachedGuests ?? [];
    }

    try {
      return await _withRetry<List<Guest>>(() async {
        final snapshot = await _getGuestsCollection()
            .orderBy('updatedAt', descending: true)
            .get();

        final guests = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Guest.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedGuests = guests;
        _cacheTimestamp = DateTime.now();

        return guests;
      });
    } catch (e) {
      debugPrint('Chyba při načítání hostů: $e');
      return _cachedGuests ?? [];
    }
  }

  /// Načte stoly z Firestore.
  Future<List<TableArrangement>> fetchTables() async {
    if (_userId == null) {
      return _cachedTables ?? [];
    }

    try {
      return await _withRetry<List<TableArrangement>>(() async {
        final snapshot = await _getTablesCollection().orderBy('name').get();

        final tables = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return TableArrangement.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedTables = tables;

        return tables;
      });
    } catch (e) {
      debugPrint('Chyba při načítání stolů: $e');
      return _cachedTables ?? [];
    }
  }

  /// Přidá nového hosta.
  Future<void> addGuest(Guest guest) async {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    await _withRetry<void>(() async {
      await _getGuestsCollection().doc(guest.id).set(guest.toJson());

      // Aktualizujeme cache
      if (_cachedGuests != null) {
        _cachedGuests!.add(guest);
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Aktualizuje existujícího hosta.
  Future<void> updateGuest(Guest guest) async {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    await _withRetry<void>(() async {
      await _getGuestsCollection().doc(guest.id).update(guest.toJson());

      // Aktualizujeme cache
      if (_cachedGuests != null) {
        final index = _cachedGuests!.indexWhere((g) => g.id == guest.id);
        if (index >= 0) {
          _cachedGuests![index] = guest;
          _cacheTimestamp = DateTime.now();
        }
      }
    });
  }

  /// Odstraní hosta.
  Future<void> removeGuest(String guestId) async {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    await _withRetry<void>(() async {
      await _getGuestsCollection().doc(guestId).delete();

      // Aktualizujeme cache
      if (_cachedGuests != null) {
        _cachedGuests!.removeWhere((g) => g.id == guestId);
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Přidá nový stůl.
  Future<void> addTable(TableArrangement table) async {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    await _withRetry<void>(() async {
      await _getTablesCollection().doc(table.id).set(table.toJson());

      // Aktualizujeme cache
      if (_cachedTables != null) {
        _cachedTables!.add(table);
      }
    });
  }

  /// Aktualizuje existující stůl.
  Future<void> updateTable(TableArrangement table) async {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    await _withRetry<void>(() async {
      await _getTablesCollection().doc(table.id).update(table.toJson());

      // Aktualizujeme cache
      if (_cachedTables != null) {
        final index = _cachedTables!.indexWhere((t) => t.id == table.id);
        if (index >= 0) {
          _cachedTables![index] = table;
        }
      }
    });
  }

  /// Odstraní stůl a přesune hosty na "Nepřiřazen".
  Future<void> removeTable(String tableId) async {
    if (_userId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    await _withRetry<void>(() async {
      // Získáme název stolu před smazáním
      final tableDoc = await _getTablesCollection().doc(tableId).get();
      if (!tableDoc.exists) return;

      final tableName = tableDoc.data()!['name'] as String;

      // Najdeme všechny hosty u tohoto stolu
      final guestsAtTable = await _getGuestsCollection()
          .where('table', isEqualTo: tableName)
          .get();

      // Batch operace pro efektivnost
      final batch = _firestore.batch();

      // Přesuneme hosty na "Nepřiřazen" (konstantu!)
      for (final guestDoc in guestsAtTable.docs) {
        batch.update(guestDoc.reference, {
          'table': GuestConstants.unassignedTable,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Smažeme stůl
      batch.delete(_getTablesCollection().doc(tableId));

      // Provedeme batch operaci
      await batch.commit();

      // Aktualizujeme cache
      if (_cachedTables != null) {
        _cachedTables!.removeWhere((t) => t.id == tableId);
      }
      if (_cachedGuests != null) {
        for (var i = 0; i < _cachedGuests!.length; i++) {
          if (_cachedGuests![i].table == tableName) {
            _cachedGuests![i] = _cachedGuests![i]
                .copyWith(table: GuestConstants.unassignedTable);
          }
        }
      }
    });
  }

  /// Hromadná aktualizace hostů (např. při změně stolu).
  Future<void> batchUpdateGuests(List<Guest> guests) async {
    if (_userId == null || guests.isEmpty) return;

    await _withRetry<void>(() async {
      final batch = _firestore.batch();

      for (final guest in guests) {
        final docRef = _getGuestsCollection().doc(guest.id);
        batch.update(docRef, guest.toJson());
      }

      await batch.commit();

      // Aktualizujeme cache
      if (_cachedGuests != null) {
        for (final guest in guests) {
          final index = _cachedGuests!.indexWhere((g) => g.id == guest.id);
          if (index >= 0) {
            _cachedGuests![index] = guest;
          }
        }
        _cacheTimestamp = DateTime.now();
      }
    });
  }

  /// Vymaže všechny hosty a stoly.
  Future<void> clearAllData() async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      // Získáme všechny dokumenty
      final guestsSnapshot = await _getGuestsCollection().get();
      final tablesSnapshot = await _getTablesCollection().get();

      // Vytvoříme batch operaci
      final batch = _firestore.batch();

      // Přidáme smazání všech hostů
      for (final doc in guestsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Přidáme smazání všech stolů
      for (final doc in tablesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Provedeme batch operaci
      await batch.commit();

      // Vyčistíme cache
      _cachedGuests = [];
      _cachedTables = [];
      _cacheTimestamp = DateTime.now();
    });
  }

  /// Synchronizuje data z lokálního úložiště do cloudu.
  Future<void> syncFromLocal(
      List<Guest> localGuests, List<TableArrangement> localTables) async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      // 1. Synchronizace stolů
      final cloudTablesSnapshot = await _getTablesCollection().get();
      final cloudTableIds =
          cloudTablesSnapshot.docs.map((doc) => doc.id).toSet();
      final localTableIds = localTables.map((t) => t.id).toSet();

      // Batch operace pro stoly
      final tablesBatch = _firestore.batch();

      // Přidání/aktualizace stolů
      for (final table in localTables) {
        final docRef = _getTablesCollection().doc(table.id);
        tablesBatch.set(docRef, table.toJson(), SetOptions(merge: true));
      }

      // Odstranění stolů, které nejsou v lokálních datech
      final tablesToRemove =
          cloudTableIds.where((id) => !localTableIds.contains(id));
      for (final id in tablesToRemove) {
        tablesBatch.delete(_getTablesCollection().doc(id));
      }

      await tablesBatch.commit();

      // 2. Synchronizace hostů
      final cloudGuestsSnapshot = await _getGuestsCollection().get();
      final cloudGuestIds =
          cloudGuestsSnapshot.docs.map((doc) => doc.id).toSet();
      final localGuestIds = localGuests.map((g) => g.id).toSet();

      // Batch operace pro hosty
      final guestsBatch = _firestore.batch();

      // Přidání/aktualizace hostů
      for (final guest in localGuests) {
        final docRef = _getGuestsCollection().doc(guest.id);
        guestsBatch.set(docRef, guest.toJson(), SetOptions(merge: true));
      }

      // Odstranění hostů, kteří nejsou v lokálních datech
      final guestsToRemove =
          cloudGuestIds.where((id) => !localGuestIds.contains(id));
      for (final id in guestsToRemove) {
        guestsBatch.delete(_getGuestsCollection().doc(id));
      }

      await guestsBatch.commit();

      // 3. Uložíme časovou značku synchronizace
      await saveLastSyncTimestamp(DateTime.now());

      // Aktualizujeme cache
      _cachedGuests = List.from(localGuests);
      _cachedTables = List.from(localTables);
      _cacheTimestamp = DateTime.now();

      debugPrint("Synchronizace hostů dokončena");
    });
  }

  /// Získá časovou značku poslední synchronizace.
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;

      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['lastGuestsSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastGuestsSync'];
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('Chyba při získávání časové značky synchronizace: $e');
      return null;
    }
  }

  /// Uloží časovou značku poslední synchronizace.
  Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    try {
      if (_userId == null) return;

      await _firestore.collection('users').doc(_userId).set({
        'lastGuestsSync': Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Chyba při ukládání časové značky synchronizace: $e');
    }
  }

  /// Získá statistiky hostů přímo z cloudu.
  Future<Map<String, dynamic>> getGuestStatistics() async {
    if (_userId == null) {
      return {};
    }

    try {
      final guests = await fetchGuests();
      final tables = await fetchTables();

      return {
        'total': guests.length,
        'male':
            guests.where((g) => g.gender == GuestConstants.genderMale).length,
        'female':
            guests.where((g) => g.gender == GuestConstants.genderFemale).length,
        'other':
            guests.where((g) => g.gender == GuestConstants.genderOther).length,
        'confirmed': guests
            .where((g) => g.attendance == GuestConstants.attendanceConfirmed)
            .length,
        'declined': guests
            .where((g) => g.attendance == GuestConstants.attendanceDeclined)
            .length,
        'pending': guests
            .where((g) => g.attendance == GuestConstants.attendancePending)
            .length,
        'tables': tables.length,
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

    throw Exception('error_operation_failed_max_retries'.tr());
  }
}
