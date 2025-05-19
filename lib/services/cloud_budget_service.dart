// lib/services/cloud_budget_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../models/expense.dart';

/// Služba pro cloudovou synchronizaci rozpočtu svatby.
class CloudBudgetService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  
  CloudBudgetService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  }) : 
    _firestore = firestore ?? FirebaseFirestore.instance,
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
          .orderBy('date', descending: true) // Třídíme podle data sestupně
          .snapshots()
          .map((snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          return Expense.fromJson(data);
        }).toList();
        
        debugPrint("Stream: Přijato ${items.length} položek rozpočtu z Firestore");
        return items;
      });
    } catch (e, stackTrace) {
      debugPrint('Error getting expenses stream: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      // Vracíme prázdný stream v případě chyby
      return Stream.value([]);
    }
  }
  
  /// Načte položky rozpočtu z Firestore.
  Future<List<Expense>> fetchExpenses() async {
    try {
      if (_userId == null) {
        debugPrint("=== NELZE NAČÍST DATA Z FIRESTORE - UŽIVATEL NENÍ PŘIHLÁŠEN ===");
        return [];
      }
      
      // Opakované pokusy pro lepší spolehlivost
      const maxRetries = 3;
      int attempts = 0;
      Exception? lastException;
      
      while (attempts < maxRetries) {
        try {
          attempts++;
          debugPrint("=== POKUS $attempts O NAČTENÍ ROZPOČTU Z FIRESTORE ===");
          
          final snapshot = await _getExpensesCollection()
              .orderBy('date', descending: true)
              .get();
          
          final items = snapshot.docs.map((doc) {
            return Expense.fromJson(doc.data());
          }).toList();
          
          debugPrint("=== ÚSPĚŠNĚ NAČTENO ${items.length} POLOŽEK ROZPOČTU Z FIRESTORE ===");
          return items;
        } catch (e) {
          lastException = Exception("Pokus $attempts: $e");
          debugPrint("=== CHYBA PŘI NAČÍTÁNÍ Z FIRESTORE: $e ===");
          
          // Počkáme před dalším pokusem (exponenciální backoff)
          if (attempts < maxRetries) {
            final delay = Duration(milliseconds: 500 * (1 << attempts));
            debugPrint("=== ČEKÁM ${delay.inMilliseconds}ms PŘED DALŠÍM POKUSEM ===");
            await Future.delayed(delay);
          }
        }
      }
      
      // Pokud jsme sem došli, všechny pokusy selhaly
      throw lastException ?? Exception("Nepodařilo se načíst data po $maxRetries pokusech");
    } catch (e, stackTrace) {
      debugPrint('=== FATÁLNÍ CHYBA PŘI NAČÍTÁNÍ ROZPOČTU Z FIRESTORE: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      // Vracíme prázdný seznam v případě chyby
      return [];
    }
  }
  
  /// Přidá novou položku do rozpočtu.
  Future<void> addExpense(Expense expense) async {
    try {
      if (_userId == null) {
        throw Exception("=== UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      }
      
      await _getExpensesCollection().doc(expense.id).set(expense.toJson());
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI PŘIDÁVÁNÍ POLOŽKY ROZPOČTU: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Aktualizuje existující položku rozpočtu.
  Future<void> updateExpense(Expense expense) async {
    try {
      if (_userId == null) {
        throw Exception("=== UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      }
      
      await _getExpensesCollection().doc(expense.id).update(expense.toJson());
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI AKTUALIZACI POLOŽKY ROZPOČTU: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Odstraní položku rozpočtu.
  Future<void> removeExpense(String expenseId) async {
    try {
      if (_userId == null) {
        throw Exception("=== UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      }
      
      await _getExpensesCollection().doc(expenseId).delete();
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI ODSTRAŇOVÁNÍ POLOŽKY ROZPOČTU: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Vymaže všechny položky rozpočtu.
  Future<void> clearAllExpenses() async {
    try {
      if (_userId == null) return;
      
      final batch = _firestore.batch();
      final snapshot = await _getExpensesCollection().get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI MAZÁNÍ VŠECH POLOŽEK ROZPOČTU: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Získá časovou značku poslední synchronizace z Firestore
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;
      
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data() != null && doc.data()!['lastBudgetSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastBudgetSync'];
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('=== CHYBA PŘI ZÍSKÁVÁNÍ ČASOVÉ ZNAČKY ROZPOČTU: $e ===');
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
      debugPrint('=== CHYBA PŘI UKLÁDÁNÍ ČASOVÉ ZNAČKY ROZPOČTU: $e ===');
    }
  }
  
  /// Synchronizuje položky z lokálního úložiště do cloudu.
  Future<void> syncFromLocal(List<Expense> localExpenses) async {
    try {
      if (_userId == null || localExpenses.isEmpty) return;
      
      // Opakované pokusy pro lepší spolehlivost
      const maxRetries = 3;
      int attempts = 0;
      Exception? lastException;
      
      while (attempts < maxRetries) {
        try {
          attempts++;
          debugPrint("=== POKUS $attempts O SYNCHRONIZACI ROZPOČTU DO FIRESTORE ===");
          
          final batch = _firestore.batch();
          
          // Nejprve vyčistíme současnou kolekci
          final snapshot = await _getExpensesCollection().get();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          
          // Pak přidáme všechny lokální položky
          for (final expense in localExpenses) {
            final docRef = _getExpensesCollection().doc(expense.id);
            batch.set(docRef, expense.toJson());
          }
          
          await batch.commit();
          
          // Uložíme časovou značku synchronizace
          final now = DateTime.now();
          await saveLastSyncTimestamp(now);
          
          debugPrint("=== ÚSPĚŠNĚ SYNCHRONIZOVÁNO ${localExpenses.length} POLOŽEK ROZPOČTU DO FIRESTORE ===");
          return;
        } catch (e) {
          lastException = Exception("Pokus $attempts: $e");
          debugPrint("=== CHYBA PŘI SYNCHRONIZACI ROZPOČTU DO FIRESTORE: $e ===");
          
          // Počkáme před dalším pokusem (exponenciální backoff)
          if (attempts < maxRetries) {
            final delay = Duration(milliseconds: 500 * (1 << attempts));
            debugPrint("=== ČEKÁM ${delay.inMilliseconds}ms PŘED DALŠÍM POKUSEM ===");
            await Future.delayed(delay);
          }
        }
      }
      
      // Pokud jsme sem došli, všechny pokusy selhaly
      throw lastException ?? Exception("Nepodařilo se synchronizovat data po $maxRetries pokusech");
    } catch (e, stackTrace) {
      debugPrint('=== FATÁLNÍ CHYBA PŘI SYNCHRONIZACI ROZPOČTU: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
}