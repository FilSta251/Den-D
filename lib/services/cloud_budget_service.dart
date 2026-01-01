/// lib/services/cloud_budget_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../models/expense.dart';

/// Služba pro cloudovou synchronizaci rozpočtu svatby.
class CloudBudgetService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  // Konstanty pro retry mechanismus
  static const int _maxRetries = 3;
  static const int _baseDelayMs = 500;

  // Cache pro offline použití
  List<Expense>? _cachedExpenses;

  CloudBudgetService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance;

  /// Vrací ID aktuálně přihlášeného uživatele, nebo null pokud není nikdo přihlášen.
  String? get _userId => _auth.currentUser?.uid;

  /// Vrací referenci na kolekci rozpočtu pro aktuálního uživatele.
  CollectionReference<Map<String, dynamic>> _getExpensesCollection() {
    if (_userId == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    return _firestore.collection('users').doc(_userId).collection('budget');
  }

  /// Získá stream položek rozpočtu, který se aktualizuje v reálném čase.
  Stream<List<Expense>> getExpensesStream() {
    try {
      if (_userId == null) {
        return Stream.value([]);
      }

      return _getExpensesCollection()
          .orderBy('date', descending: true)
          .snapshots()
          .map((snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          return Expense.fromJson(data);
        }).toList();

        // Aktualizujeme cache při každém novém stavu
        _cachedExpenses = items;

        return items;
      });
    } catch (e) {
      debugPrint('Chyba při získávání streamu položek rozpočtu: $e');
      return Stream.value(_cachedExpenses ?? []);
    }
  }

  /// Načte položky rozpočtu z Firestore s retry logikou.
  Future<List<Expense>> fetchExpenses() async {
    if (_userId == null) {
      return _cachedExpenses ?? [];
    }

    try {
      return await _withRetry<List<Expense>>(() async {
        final snapshot = await _getExpensesCollection()
            .orderBy('date', descending: true)
            .get();

        final items = snapshot.docs.map((doc) {
          return Expense.fromJson(doc.data());
        }).toList();

        // Aktualizujeme cache
        _cachedExpenses = items;

        return items;
      });
    } catch (e) {
      debugPrint('Chyba při načítání položek rozpočtu: $e');

      // Vracíme cache v případě chyby
      return _cachedExpenses ?? [];
    }
  }

  /// Přidá novou položku do rozpočtu.
  Future<void> addExpense(Expense expense) async {
    if (_userId == null) {
      throw Exception("Uživatel není přihlášen");
    }

    await _withRetry<void>(() async {
      await _getExpensesCollection().doc(expense.id).set(expense.toJson());

      // Aktualizujeme cache
      if (_cachedExpenses != null) {
        _cachedExpenses!.add(expense);
      }
    });
  }

  /// Aktualizuje existující položku rozpočtu.
  Future<void> updateExpense(Expense expense) async {
    if (_userId == null) {
      throw Exception("Uživatel není přihlášen");
    }

    await _withRetry<void>(() async {
      await _getExpensesCollection().doc(expense.id).update(expense.toJson());

      // Aktualizujeme cache
      if (_cachedExpenses != null) {
        final index = _cachedExpenses!.indexWhere((e) => e.id == expense.id);
        if (index >= 0) {
          _cachedExpenses![index] = expense;
        }
      }
    });
  }

  /// Odstraní položku rozpočtu.
  Future<void> removeExpense(String expenseId) async {
    if (_userId == null) {
      throw Exception("Uživatel není přihlášen");
    }

    await _withRetry<void>(() async {
      await _getExpensesCollection().doc(expenseId).delete();

      // Aktualizujeme cache
      if (_cachedExpenses != null) {
        _cachedExpenses!.removeWhere((e) => e.id == expenseId);
      }
    });
  }

  /// Vymaže všechny položky rozpočtu.
  Future<void> clearAllExpenses() async {
    if (_userId == null) return;

    await _withRetry<void>(() async {
      final snapshot = await _getExpensesCollection().get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Aktualizujeme cache
      _cachedExpenses = [];
    });
  }

  /// Získá časovou značku poslední synchronizace z Firestore
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;

      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists &&
          doc.data() != null &&
          doc.data()!['lastBudgetSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastBudgetSync'];
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
        'lastBudgetSync': Timestamp.fromDate(timestamp),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Chyba při ukládání časové značky: $e');
    }
  }

  /// Synchronizuje položky z lokálního úložiště do cloudu.
  Future<void> syncFromLocal(List<Expense> localExpenses) async {
    if (_userId == null || localExpenses.isEmpty) return;

    await _withRetry<void>(() async {
      // Optimalizace: zjistíme, co opravdu potřebujeme synchronizovat

      // 1. Nejprve získáme aktuální stav z Firestore
      final snapshot = await _getExpensesCollection().get();
      final cloudExpenseIds = snapshot.docs.map((doc) => doc.id).toSet();
      final localExpenseIds = localExpenses.map((e) => e.id).toSet();

      // 2. Určíme, které položky musíme přidat, aktualizovat nebo odstranit
      final toAdd =
          localExpenses.where((e) => !cloudExpenseIds.contains(e.id)).toList();
      final toUpdate =
          localExpenses.where((e) => cloudExpenseIds.contains(e.id)).toList();
      final toRemove =
          cloudExpenseIds.where((id) => !localExpenseIds.contains(id)).toList();

      // 3. Vytvoříme batch operace pro efektivní aktualizaci
      final batch = _firestore.batch();

      // Přidání nových položek
      for (final expense in toAdd) {
        final docRef = _getExpensesCollection().doc(expense.id);
        batch.set(docRef, expense.toJson());
      }

      // Aktualizace existujících položek
      for (final expense in toUpdate) {
        final docRef = _getExpensesCollection().doc(expense.id);
        batch.update(docRef, expense.toJson());
      }

      // Odstranění chybějících položek
      for (final id in toRemove) {
        final docRef = _getExpensesCollection().doc(id);
        batch.delete(docRef);
      }

      // 4. Provedeme batch operaci
      await batch.commit();

      // 5. Uložíme časovou značku synchronizace
      await saveLastSyncTimestamp(DateTime.now());

      // Aktualizujeme cache
      _cachedExpenses = List.from(localExpenses);

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
