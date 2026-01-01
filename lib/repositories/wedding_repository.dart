/// wedding_repository.dart - aktualizovaná verze bez isolates
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../models/wedding_info.dart';

class WeddingRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  WeddingInfo? _cachedWeddingInfo;
  final StreamController<WeddingInfo?> _weddingStreamController =
      StreamController<WeddingInfo?>.broadcast();

  Stream<WeddingInfo?> get weddingInfoStream => _weddingStreamController.stream;

  WeddingRepository() {
    _initializeListener();
  }

  // Přidáme metodu pro získání a výpis aktuálního UID
  String? getCurrentUserId() {
    final user = _auth.currentUser;
    debugPrint('[WeddingRepository] Current user UID: ${user?.uid}');
    debugPrint('[WeddingRepository] Current user email: ${user?.email}');
    debugPrint(
        '[WeddingRepository] Current user email verified: ${user?.emailVerified}');
    return user?.uid;
  }

  void _initializeListener() {
    final fb.User? currentUser = _auth.currentUser;
    debugPrint(
        '[WeddingRepository] Initializing listener for user: ${currentUser?.uid}');

    if (currentUser != null) {
      final docRef = _firestore.collection('wedding_info').doc(currentUser.uid);
      debugPrint(
          '[WeddingRepository] Setting up listener on Firestore path: wedding_info/${currentUser.uid}');

      docRef.snapshots().listen(
        (snapshot) async {
          if (snapshot.exists && snapshot.data() != null) {
            try {
              final data = snapshot.data()!;
              debugPrint(
                  '[WeddingRepository] Received data from Firestore: $data');

              // Zpracování dat přímo v hlavním vlákně
              final info = WeddingInfo.fromJson(data);

              _cachedWeddingInfo = info;
              _weddingStreamController.add(info);
              debugPrint(
                  '[WeddingRepository] Received wedding info update: $info');
            } catch (e, stack) {
              debugPrint(
                  '[WeddingRepository] Error parsing wedding info snapshot: $e');
              debugPrintStack(label: 'StackTrace', stackTrace: stack);
              _weddingStreamController.addError(e);
            }
          } else {
            debugPrint(
                '[WeddingRepository] Wedding info document not found or empty.');
            _weddingStreamController.add(null);
          }
        },
        onError: (error, stack) {
          debugPrint(
              '[WeddingRepository] Error listening to wedding info: $error');
          debugPrintStack(label: 'StackTrace', stackTrace: stack);
          _weddingStreamController.addError(error);
        },
      );
    } else {
      debugPrint(
          '[WeddingRepository] No authenticated user found; listener not initialized.');
    }
  }

  // Implementace bez pouťití compute/isolate
  Future<WeddingInfo> fetchWeddingInfo() async {
    final fb.User? currentUser = _auth.currentUser;
    debugPrint(
        '[WeddingRepository] Fetching wedding info for user: ${currentUser?.uid}');

    if (currentUser == null) {
      debugPrint(
          '[WeddingRepository] No authenticated user found; cannot fetch wedding info.');
      throw Exception('Uťivatel není přihláĹˇen.');
    }

    final docRef = _firestore.collection('wedding_info').doc(currentUser.uid);
    debugPrint(
        '[WeddingRepository] Fetching from Firestore path: wedding_info/${currentUser.uid}');

    try {
      // Náčítání přímo v hlavním vlákně místo compute
      final snapshot = await docRef.get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final result = WeddingInfo.fromJson(data);

        _cachedWeddingInfo = result;
        _weddingStreamController.add(result);

        debugPrint(
            '[WeddingRepository] Wedding info fetched successfully: ${result.toJson()}');
        return result;
      } else {
        // Vytvoření defaultní instance
        final defaultInfo = WeddingInfo(
          userId: currentUser.uid,
          weddingDate: DateTime.now().add(const Duration(days: 180)),
          yourName: '--',
          partnerName: '--',
          weddingVenue: '--',
          budget: 0.0,
          notes: '--',
        );

        // Uloťení defaultní instance do Firestore
        await docRef.set(defaultInfo.toJson());

        _cachedWeddingInfo = defaultInfo;
        _weddingStreamController.add(defaultInfo);

        debugPrint(
            '[WeddingRepository] Created default wedding info: ${defaultInfo.toJson()}');
        return defaultInfo;
      }
    } catch (e, stack) {
      debugPrint('[WeddingRepository] Error fetching wedding info: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      rethrow;
    }
  }

  Future<void> updateWeddingInfo(WeddingInfo updatedInfo) async {
    final fb.User? currentUser = _auth.currentUser;
    debugPrint(
        '[WeddingRepository] Updating wedding info for user: ${currentUser?.uid}');
    debugPrint('[WeddingRepository] Updated info: ${updatedInfo.toJson()}');

    if (currentUser == null) {
      debugPrint(
          '[WeddingRepository] No authenticated user found; cannot update wedding info.');
      throw Exception('Uťivatel není přihláĹˇen.');
    }

    // Ujistíme se, ťe userId je správnĂ©
    if (updatedInfo.userId != currentUser.uid) {
      debugPrint(
          '[WeddingRepository] Warning: updatedInfo.userId (${updatedInfo.userId}) does not match currentUser.uid (${currentUser.uid})');
      // Opravíme userId
      updatedInfo = updatedInfo.copyWith(userId: currentUser.uid);
      debugPrint('[WeddingRepository] UserId corrected in wedding info');
    }

    final docRef = _firestore.collection('wedding_info').doc(currentUser.uid);
    debugPrint(
        '[WeddingRepository] Updating Firestore document: wedding_info/${currentUser.uid}');

    try {
      // Aktualizace přímo v hlavním vlákně místo compute
      final updatedJson = updatedInfo.toJson();

      // Provedeme kontrolu změn pokud máme cache
      Map<String, dynamic> dataToUpdate = {};
      bool isModified = false;

      if (_cachedWeddingInfo != null) {
        final cachedJson = _cachedWeddingInfo!.toJson();
        updatedJson.forEach((key, newValue) {
          if (cachedJson[key] != newValue) {
            dataToUpdate[key] = newValue;
            isModified = true;
          }
        });
      } else {
        dataToUpdate = updatedJson;
        isModified = true;
      }

      if (dataToUpdate.isNotEmpty) {
        await docRef.set(dataToUpdate, SetOptions(merge: true));
        debugPrint(
            '[WeddingRepository] Updated fields in Firestore: ${dataToUpdate.keys.join(', ')}');

        // Aktualizace lokální instance
        if (_cachedWeddingInfo != null) {
          _cachedWeddingInfo =
              _mergeInfoLocally(_cachedWeddingInfo!, dataToUpdate);
        } else {
          _cachedWeddingInfo = updatedInfo;
        }

        if (isModified) {
          _weddingStreamController.add(_cachedWeddingInfo);
        }
      } else {
        debugPrint('[WeddingRepository] No changes detected, skipping update.');
      }
    } catch (e, stack) {
      debugPrint('[WeddingRepository] Error updating wedding info: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      rethrow;
    }
  }

  // Pomocná metoda pro lokální sloučení dat
  static WeddingInfo _mergeInfoLocally(
      WeddingInfo current, Map<String, dynamic> diff) {
    return current.copyWith(
      userId: diff.containsKey('userId') ? diff['userId'] : current.userId,
      weddingDate: diff.containsKey('weddingDate')
          ? DateTime.parse(diff['weddingDate'] as String)
          : current.weddingDate,
      yourName:
          diff.containsKey('yourName') ? diff['yourName'] : current.yourName,
      partnerName: diff.containsKey('partnerName')
          ? diff['partnerName']
          : current.partnerName,
      weddingVenue: diff.containsKey('weddingVenue')
          ? diff['weddingVenue']
          : current.weddingVenue,
      budget: diff.containsKey('budget')
          ? (diff['budget'] as num).toDouble()
          : current.budget,
      notes: diff.containsKey('notes') ? diff['notes'] : current.notes,
    );
  }

  Future<void> createWeddingInfo(WeddingInfo info) async {
    final fb.User? currentUser = _auth.currentUser;
    debugPrint(
        '[WeddingRepository] Creating wedding info for user: ${currentUser?.uid}');
    debugPrint('[WeddingRepository] Info to create: ${info.toJson()}');

    if (currentUser == null) {
      debugPrint(
          '[WeddingRepository] No authenticated user found; cannot create wedding info.');
      throw Exception('Uťivatel není přihláĹˇen.');
    }

    // Ujistíme se, ťe userId je správnĂ©
    if (info.userId != currentUser.uid) {
      debugPrint(
          '[WeddingRepository] Warning: info.userId (${info.userId}) does not match currentUser.uid (${currentUser.uid})');
      // Opravíme userId
      info = info.copyWith(userId: currentUser.uid);
      debugPrint('[WeddingRepository] UserId corrected in wedding info');
    }

    final docRef = _firestore.collection('wedding_info').doc(currentUser.uid);
    debugPrint(
        '[WeddingRepository] Creating Firestore document: wedding_info/${currentUser.uid}');

    try {
      // Vytvoření přímo v hlavním vlákně místo compute
      await docRef.set(info.toJson());

      _cachedWeddingInfo = info;
      _weddingStreamController.add(info);
      debugPrint('[WeddingRepository] Wedding info created successfully');
    } catch (e, stack) {
      debugPrint('[WeddingRepository] Error creating wedding info: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      rethrow;
    }
  }

  // Testovací metoda pro ověření oprávnění
  Future<void> testFirestorePermissions() async {
    final userId = getCurrentUserId();
    debugPrint(
        '[WeddingRepository] Testing Firestore permissions for user ID: $userId');

    if (userId == null) {
      debugPrint('[WeddingRepository] No user logged in!');
      return;
    }

    try {
      // Test čtení
      debugPrint('[WeddingRepository] Testing READ permission...');
      final docRef = _firestore.collection('wedding_info').doc(userId);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        debugPrint(
            '[WeddingRepository] READ permission SUCCESS - Document exists');
        debugPrint('[WeddingRepository] Document data: ${docSnapshot.data()}');
      } else {
        debugPrint(
            '[WeddingRepository] READ permission SUCCESS - Document does not exist');
      }

      // Test zápisu
      debugPrint('[WeddingRepository] Testing WRITE permission...');
      await docRef.set({
        'test_field': 'test_value',
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
      debugPrint('[WeddingRepository] WRITE permission SUCCESS');

      // Test čtení po zápisu
      debugPrint('[WeddingRepository] Testing READ after WRITE...');
      final updatedDoc = await docRef.get();
      debugPrint('[WeddingRepository] Updated document: ${updatedDoc.data()}');

      // Test odstranění testovacího pole
      debugPrint('[WeddingRepository] Testing DELETE permission...');
      await docRef.update({'test_field': FieldValue.delete()});
      debugPrint('[WeddingRepository] DELETE permission SUCCESS');

      // Závěrečný test čtení
      final finalDoc = await docRef.get();
      debugPrint(
          '[WeddingRepository] Final document state: ${finalDoc.data()}');
      debugPrint('[WeddingRepository] All Firebase permission tests PASSED');
    } catch (e, stack) {
      debugPrint('[WeddingRepository] Permission test error: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      throw Exception('Firebase permission test failed: $e');
    }
  }

  void dispose() {
    _weddingStreamController.close();
  }
}
