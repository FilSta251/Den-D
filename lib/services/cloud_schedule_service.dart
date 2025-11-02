/// lib/services/cloud_schedule_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../services/local_schedule_service.dart';

/// Služba pro cloudovou synchronizaci harmonogramu svatby.
///
/// Umožňuje:
/// - Ukládání harmonogramu do Firestore
/// - Načítání harmonogramu z Firestore
/// - Synchronizaci mezi zařízeními
/// - Sledování změn v reálném čase
class CloudScheduleService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  // Konstanty pro retry mechanismus
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 500;

  // Cache pro offline použití
  List<ScheduleItem>? _cachedItems;

  CloudScheduleService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  /// Vrací ID aktuálně přihlášeného uživatele, nebo null pokud není nikdo přihlášen.
  String? get _userId => _auth.currentUser?.uid;

  /// Vrací referenci na kolekci harmonogramu pro aktuálního uživatele.
  CollectionReference<Map<String, dynamic>> _getScheduleCollection() {
    if (_userId == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    return _firestore.collection('users').doc(_userId).collection('schedule');
  }

  /// Získá stream položek harmonogramu, který se aktualizuje v reálném čase.
  Stream<List<ScheduleItem>> getScheduleItemsStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getScheduleCollection()
          .orderBy('lastModified', descending: true)
          .snapshots()
          .map((snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ScheduleItem.fromJson(data);
        }).toList();

        // Aktualizujeme cache při každém novém stavu
        _cachedItems = items;

        return items;
      });
    } catch (e) {
      debugPrint('Chyba při získávání streamu položek harmonogramu: $e');
      return Stream.value(_cachedItems ?? []);
    }
  }

  /// Načte položky harmonogramu z Firestore s retry logikou.
  Future<List<ScheduleItem>> fetchScheduleItems() async {
    if (_userId == null) {
      return _cachedItems ?? [];
    }

    try {
      return await _withRetry<List<ScheduleItem>>(() async {
        final snapshot = await _getScheduleCollection()
            .orderBy('lastModified', descending: true)
            .get();

        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ScheduleItem.fromJson(data);
        }).toList();

        // Aktualizujeme cache
        _cachedItems = items;

        return items;
      });
    } catch (e) {
      debugPrint('Chyba při načítání položek harmonogramu: $e');

      // Vracíme cache v případě chyby
      return _cachedItems ?? [];
    }
  }

  /// Přidá novou položku do harmonogramu.
  Future<void> addItem(ScheduleItem item) async {
    if (_userId == null) {
      throw Exception("Uživatel není přihlášen");
    }

    await _withRetry<void>(() async {
      await _getScheduleCollection().doc(item.id).set(item.toJson());

      // Aktualizujeme cache
      if (_cachedItems != null) {
        _cachedItems!.add(item);
      }
    });
  }

  /// Aktualizuje existující položku harmonogramu.
  Future<void> updateItem(ScheduleItem item) async {
    if (_userId == null) {
      throw Exception("Uživatel není přihlášen");
    }

    await _withRetry<void>(() async {
      await _getScheduleCollection().doc(item.id).update(item.toJson());

      // Aktualizujeme cache
      if (_cachedItems != null) {
        final index = _cachedItems!.indexWhere((e) => e.id == item.id);
        if (index >= 0) {
          _cachedItems![index] = item;
        }
      }
    });
  }

  /// Odstraní položku harmonogramu.
  Future<void> removeItem(String itemId) async {
    if (_userId == null) {
      throw Exception("Uživatel není přihlášen");
    }

    await _withRetry<void>(() async {
      await _getScheduleCollection().doc(itemId).delete();

      // Aktualizujeme cache
      if (_cachedItems != null) {
        _cachedItems!.removeWhere((e) => e.id == itemId);
      }
    });
  }

  /// Vymaže všechny položky harmonogramu.
  Future<void> clearAllItems() async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      final snapshot = await _getScheduleCollection().get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Aktualizujeme cache
      _cachedItems = [];
    });
  }

  /// Získá časovou značku poslední synchronizace z Firestore
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;

      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['lastScheduleSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastScheduleSync'];
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('Chyba při získávání časové značky: $e');
      return null;
    }
  }

  /// Uloží časovou značku poslední synchronizace do Firestore
  Future<void> saveLastSyncTimestamp(DateTime timestamp) async {
    try {
      if (_userId == null) return;

      await _firestore.collection('users').doc(_userId).set({
        'lastScheduleSync': Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Chyba při ukládání časové značky: $e');
    }
  }

  /// Synchronizuje položky z lokálního úložiště do cloudu.
  Future<void> syncFromLocal(List<ScheduleItem> localItems) async {
    if (_userId == null || localItems.isEmpty) return;

    await _withRetry<void>(() async {
      // Optimalizace: zjistíme, co opravdu potřebujeme synchronizovat

      // 1. Nejprve získáme aktuální stav z Firestore
      final snapshot = await _getScheduleCollection().get();
      final cloudItemIds = snapshot.docs.map((doc) => doc.id).toSet();
      final localItemIds = localItems.map((e) => e.id).toSet();

      // 2. Určíme, které položky musíme přidat, aktualizovat nebo odstranit
      final toAdd =
          localItems.where((e) => !cloudItemIds.contains(e.id)).toList();
      final toUpdate =
          localItems.where((e) => cloudItemIds.contains(e.id)).toList();
      final toRemove =
          cloudItemIds.where((id) => !localItemIds.contains(id)).toList();

      // 3. Vytvoříme batch operace pro efektivní aktualizaci
      final batch = _firestore.batch();

      // Přidání nových položek
      for (final item in toAdd) {
        final updatedItem = item.copyWith(lastModified: DateTime.now());
        final docRef = _getScheduleCollection().doc(item.id);
        batch.set(docRef, updatedItem.toJson());
      }

      // Aktualizace existujících položek
      for (final item in toUpdate) {
        final updatedItem = item.copyWith(lastModified: DateTime.now());
        final docRef = _getScheduleCollection().doc(item.id);
        batch.update(docRef, updatedItem.toJson());
      }

      // Odstranění chybějících položek
      for (final id in toRemove) {
        final docRef = _getScheduleCollection().doc(id);
        batch.delete(docRef);
      }

      // 4. Provedeme batch operaci
      await batch.commit();

      // 5. Uložíme časovou značku synchronizace
      await saveLastSyncTimestamp(DateTime.now());

      // Aktualizujeme cache
      _cachedItems = List.from(localItems);

      debugPrint(
          "Synchronizace dokončena: přidáno ${toAdd.length}, aktualizováno ${toUpdate.length}, odstraněno ${toRemove.length} položek");
    });
  }

  /// Retry wrapper pro Firebase operace s exponenciálním backoff.
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
