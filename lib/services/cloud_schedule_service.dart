// lib/services/cloud_schedule_service.dart

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
  
  CloudScheduleService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  }) : 
    _firestore = firestore ?? FirebaseFirestore.instance,
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
          .orderBy('lastModified', descending: true) // Třídíme podle času poslední úpravy
          .snapshots()
          .map((snapshot) {
        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ScheduleItem.fromJson(data);
        }).toList();
        
        debugPrint("Stream: Přijato ${items.length} položek z Firestore");
        return items;
      });
    } catch (e, stackTrace) {
      debugPrint('Error getting schedule items stream: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      // Vracíme prázdný stream v případě chyby
      return Stream.value([]);
    }
  }
  
  /// Načte položky harmonogramu z Firestore.
  Future<List<ScheduleItem>> fetchScheduleItems() async {
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
          debugPrint("=== POKUS $attempts O NAČTENÍ DAT Z FIRESTORE ===");
          
          final snapshot = await _getScheduleCollection()
              .orderBy('lastModified', descending: true)
              .get();
          
          final items = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return ScheduleItem.fromJson(data);
          }).toList();
          
          debugPrint("=== ÚSPĚŠNĚ NAČTENO ${items.length} POLOŽEK Z FIRESTORE ===");
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
      debugPrint('=== FATÁLNÍ CHYBA PŘI NAČÍTÁNÍ Z FIRESTORE: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      // Vracíme prázdný seznam v případě chyby
      return [];
    }
  }
  
  /// Přidá novou položku do harmonogramu.
  Future<void> addItem(ScheduleItem item) async {
    try {
      if (_userId == null) {
        throw Exception("=== UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      }
      
      await _getScheduleCollection().doc(item.id).set(item.toJson());
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI PŘIDÁVÁNÍ POLOŽKY: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Aktualizuje existující položku harmonogramu.
  Future<void> updateItem(ScheduleItem item) async {
    try {
      if (_userId == null) {
        throw Exception("=== UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      }
      
      await _getScheduleCollection().doc(item.id).update(item.toJson());
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI AKTUALIZACI POLOŽKY: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Odstraní položku harmonogramu.
  Future<void> removeItem(String itemId) async {
    try {
      if (_userId == null) {
        throw Exception("=== UŽIVATEL NENÍ PŘIHLÁŠEN ===");
      }
      
      await _getScheduleCollection().doc(itemId).delete();
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI ODSTRAŇOVÁNÍ POLOŽKY: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Vymaže všechny položky harmonogramu.
  Future<void> clearAllItems() async {
    try {
      if (_userId == null) return;
      
      final batch = _firestore.batch();
      final snapshot = await _getScheduleCollection().get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('=== CHYBA PŘI MAZÁNÍ VŠECH POLOŽEK: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Získá časovou značku poslední synchronizace z Firestore
  Future<DateTime?> getLastSyncTimestamp() async {
    try {
      if (_userId == null) return null;
      
      final doc = await _firestore.collection('users').doc(_userId).get();
      if (doc.exists && doc.data() != null && doc.data()!['lastScheduleSync'] != null) {
        final Timestamp timestamp = doc.data()!['lastScheduleSync'];
        return timestamp.toDate();
      }
      return null;
    } catch (e) {
      debugPrint('=== CHYBA PŘI ZÍSKÁVÁNÍ ČASOVÉ ZNAČKY: $e ===');
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
      debugPrint('=== CHYBA PŘI UKLÁDÁNÍ ČASOVÉ ZNAČKY: $e ===');
    }
  }
  
  /// Synchronizuje položky z lokálního úložiště do cloudu.
  Future<void> syncFromLocal(List<ScheduleItem> localItems) async {
    try {
      if (_userId == null || localItems.isEmpty) return;
      
      // Opakované pokusy pro lepší spolehlivost
      const maxRetries = 3;
      int attempts = 0;
      Exception? lastException;
      
      while (attempts < maxRetries) {
        try {
          attempts++;
          debugPrint("=== POKUS $attempts O SYNCHRONIZACI DAT DO FIRESTORE ===");
          
          final batch = _firestore.batch();
          
          // Nejprve vyčistíme současnou kolekci
          final snapshot = await _getScheduleCollection().get();
          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          
          // Pak přidáme všechny lokální položky
          for (final item in localItems) {
            final docRef = _getScheduleCollection().doc(item.id);
            // Aktualizujeme lastModified časovou značku
            final updatedItem = item.copyWith(lastModified: DateTime.now());
            batch.set(docRef, updatedItem.toJson());
          }
          
          await batch.commit();
          
          // Uložíme časovou značku synchronizace
          final now = DateTime.now();
          await saveLastSyncTimestamp(now);
          
          debugPrint("=== ÚSPĚŠNĚ SYNCHRONIZOVÁNO ${localItems.length} POLOŽEK DO FIRESTORE ===");
          return;
        } catch (e) {
          lastException = Exception("Pokus $attempts: $e");
          debugPrint("=== CHYBA PŘI SYNCHRONIZACI DO FIRESTORE: $e ===");
          
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
      debugPrint('=== FATÁLNÍ CHYBA PŘI SYNCHRONIZACI: $e ===');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Inteligentní sloučení položek z lokálního úložiště a cloudu.
  Future<List<ScheduleItem>> mergeLists(List<ScheduleItem> localItems, List<ScheduleItem> cloudItems) async {
    // Vytvoříme slovník pro rychlý přístup k položkám podle ID
    final Map<String, ScheduleItem> localMap = {for (var item in localItems) item.id: item};
    final Map<String, ScheduleItem> cloudMap = {for (var item in cloudItems) item.id: item};
    
    // Spojíme všechna unikátní ID
    final Set<String> allIds = {...localMap.keys, ...cloudMap.keys};
    
    // Pro každé ID vybereme novější verzi položky
    final mergedItems = <ScheduleItem>[];
    for (final id in allIds) {
      final localItem = localMap[id];
      final cloudItem = cloudMap[id];
      
      if (localItem != null && cloudItem != null) {
        // Obě položky existují, vybereme novější
        if (localItem.lastModified.isAfter(cloudItem.lastModified)) {
          debugPrint("=== POLOŽKA $id: LOKÁLNÍ JE NOVĚJŠÍ ===");
          mergedItems.add(localItem);
        } else {
          debugPrint("=== POLOŽKA $id: CLOUDOVÁ JE NOVĚJŠÍ ===");
          mergedItems.add(cloudItem);
        }
      } else if (localItem != null) {
        // Jen lokální položka
        debugPrint("=== POLOŽKA $id: POUZE LOKÁLNÍ ===");
        mergedItems.add(localItem);
      } else if (cloudItem != null) {
        // Jen cloudová položka
        debugPrint("=== POLOŽKA $id: POUZE CLOUDOVÁ ===");
        mergedItems.add(cloudItem);
      }
    }
    
    // Seřadíme podle času
    mergedItems.sort((a, b) {
      if (a.time == null && b.time == null) return 0;
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return a.time!.compareTo(b.time!);
    });
    
    debugPrint("=== SLOUČENO ${mergedItems.length} POLOŽEK ===");
    return mergedItems;
  }
}