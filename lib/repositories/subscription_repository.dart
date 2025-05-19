// lib/repositories/subscription_repository.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../models/subscription.dart';
import '../utils/compute_helpers.dart'; // Import vašeho nového souboru

// Parametry pro isolate
class _FetchSubscriptionParams {
  final String userId;
  final FirebaseFirestore firestore;
  
  _FetchSubscriptionParams({
    required this.userId,
    required this.firestore
  });
}

// Parametry pro isolate
class _PurchaseYearlyParams {
  final String userId;
  final bool withTrial;
  final int trialDays;
  final FirebaseFirestore firestore;
  
  _PurchaseYearlyParams({
    required this.userId,
    required this.withTrial,
    required this.trialDays,
    required this.firestore
  });
}

// Parametry pro isolate
class _PurchaseMonthlyParams {
  final String userId;
  final FirebaseFirestore firestore;
  
  _PurchaseMonthlyParams({
    required this.userId,
    required this.firestore
  });
}

// Parametry pro isolate
class _ExtendYearlyParams {
  final String userId;
  final DateTime oldExpiration;
  final int extraDays;
  final FirebaseFirestore firestore;
  
  _ExtendYearlyParams({
    required this.userId,
    required this.oldExpiration,
    required this.extraDays,
    required this.firestore
  });
}

// Parametry pro isolate
class _CancelSubscriptionParams {
  final String userId;
  final FirebaseFirestore firestore;
  
  _CancelSubscriptionParams({
    required this.userId,
    required this.firestore
  });
}

class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;

  Subscription? _cachedSubscription;
  final StreamController<Subscription?> _subscriptionStreamController =
      StreamController<Subscription?>.broadcast();

  /// Stream, který vysílá aktuální Subscription (nebo null).
  Stream<Subscription?> get subscriptionStream =>
      _subscriptionStreamController.stream;

  SubscriptionRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? fb.FirebaseAuth.instance {
    _initializeListener();
  }

  /// Inicializace real-time listeneru na dokument subscriptions/{uid}.
  void _initializeListener() {
    final user = _auth.currentUser;
    if (user == null) {
      _subscriptionStreamController.add(null);
      return;
    }
    final docRef = _firestore.collection('subscriptions').doc(user.uid);
    docRef.snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists || snapshot.data() == null) {
          _subscriptionStreamController.add(null);
          return;
        }
        
        try {
          final data = snapshot.data()!;
          data['id'] = snapshot.id;
          
          // Použití compute pro přesun parsování mimo hlavní vlákno
          final subscription = await computeOrDirect(_parseSubscriptionData, data);
          
          _cachedSubscription = subscription;
          _subscriptionStreamController.add(subscription);

          FirebaseAnalytics.instance.logEvent(
            name: 'subscription_update',
            parameters: {
              'userId': subscription.userId,
              'type': subscriptionTypeToString(subscription.subscriptionType),
              'isActive': subscription.isActive ? 1 : 0,
            },
          );
        } catch (e, st) {
          debugPrint('Error parsing subscription snapshot: $e');
          debugPrintStack(stackTrace: st);
          _subscriptionStreamController.addError(e);

          FirebaseCrashlytics.instance.log('Subscription parse error');
          FirebaseCrashlytics.instance.recordError(e, st);
        }
      },
      onError: (error) {
        debugPrint('Error listening subscription: $error');
        _subscriptionStreamController.addError(error);
        FirebaseCrashlytics.instance.log('Subscription listen error: $error');
      },
    );
  }
  
  // Statická metoda pro compute
  static Subscription _parseSubscriptionData(Map<String, dynamic> data) {
    return Subscription.fromJson(data);
  }

  /// Jednorázové načtení subscription z Firestore.
  Future<Subscription> fetchSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    
    try {
      // Přesuneme náročnou operaci do compute
      final result = await computeOrDirect(
        _fetchSubscriptionIsolate,
        _FetchSubscriptionParams(
          userId: user.uid,
          firestore: _firestore
        )
      );
      
      _cachedSubscription = result;
      _subscriptionStreamController.add(result);
      return result;
    } catch (e, st) {
      debugPrint('Error fetching subscription: $e');
      debugPrintStack(stackTrace: st);
      FirebaseCrashlytics.instance.log('fetchSubscription error');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }
  
  // Statická metoda pro compute
  static Future<Subscription> _fetchSubscriptionIsolate(_FetchSubscriptionParams params) async {
    final docRef = params.firestore.collection('subscriptions').doc(params.userId);
    final snap = await docRef.get();
    
    if (snap.exists && snap.data() != null) {
      final data = snap.data()!;
      data['id'] = snap.id;
      return Subscription.fromJson(data);
    } else {
      final defaultSub = Subscription(
        id: params.userId,
        userId: params.userId,
        isActive: false,
        subscriptionType: SubscriptionType.free,
        expirationDate: null,
        isTrial: false,
        gracePeriodDays: 3,
      );
      
      await docRef.set(defaultSub.toJson());
      return defaultSub;
    }
  }

  /// Koupě ročního předplatného s volitelným trial (např. 7 dní).
  Future<void> purchaseYearlySubscription({
    bool withTrial = false,
    int trialDays = 7,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    
    try {
      // Přesuneme náročnou operaci do compute
      await computeOrDirect(
        _purchaseYearlySubscriptionIsolate,
        _PurchaseYearlyParams(
          userId: user.uid,
          withTrial: withTrial,
          trialDays: trialDays,
          firestore: _firestore
        )
      );
      
      FirebaseAnalytics.instance.logEvent(
        name: 'purchase_yearly',
        parameters: {
          'trial': withTrial ? 1 : 0,
          'trialDays': trialDays,
          'price': 800.0,
          'currency': 'CZK',
        },
      );
    } catch (e, st) {
      debugPrint('Error purchasing yearly subscription: $e');
      debugPrintStack(stackTrace: st);
      FirebaseCrashlytics.instance.log('purchase_yearly error');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }
  
  // Statická metoda pro compute
  static Future<void> _purchaseYearlySubscriptionIsolate(_PurchaseYearlyParams params) async {
    final docRef = params.firestore.collection('subscriptions').doc(params.userId);
    final now = DateTime.now();
    // Opraveno: použití params.trialDays.toDouble() aby nedošlo k chybě typu
    final int totalDays = 365 + (params.withTrial ? params.trialDays : 0);
    final expiration = now.add(Duration(days: totalDays));
    
    final updatedData = {
      'id': params.userId,
      'userId': params.userId,
      'isActive': true,
      'subscriptionType': subscriptionTypeToString(SubscriptionType.yearly),
      'isTrial': params.withTrial ? 1 : 0, // převedeno na číslo
      'expirationDate': expiration.toIso8601String(),
      'gracePeriodDays': 3,
      'lastRenewalDate': now.toIso8601String(),
      'price': 800.0,
      'currency': 'CZK',
      'isAutoRenewal': true,
    };
    
    await docRef.set(updatedData, SetOptions(merge: true));
  }

  /// Koupě měsíčního předplatného.
  Future<void> purchaseMonthlySubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    
    try {
      // Přesuneme náročnou operaci do compute
      await computeOrDirect(
        _purchaseMonthlySubscriptionIsolate,
        _PurchaseMonthlyParams(
          userId: user.uid,
          firestore: _firestore
        )
      );
      
      FirebaseAnalytics.instance.logEvent(
        name: 'purchase_monthly',
        parameters: {
          'price': 120.0,
          'currency': 'CZK',
        },
      );
    } catch (e, st) {
      debugPrint('Error purchasing monthly subscription: $e');
      debugPrintStack(stackTrace: st);
      FirebaseCrashlytics.instance.log('purchase_monthly error');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }
  
  // Statická metoda pro compute
  static Future<void> _purchaseMonthlySubscriptionIsolate(_PurchaseMonthlyParams params) async {
    final docRef = params.firestore.collection('subscriptions').doc(params.userId);
    final now = DateTime.now();
    final expiration = now.add(const Duration(days: 30));
    
    final updatedData = {
      'id': params.userId,
      'userId': params.userId,
      'isActive': true,
      'subscriptionType': subscriptionTypeToString(SubscriptionType.monthly),
      'isTrial': 0,
      'expirationDate': expiration.toIso8601String(),
      'gracePeriodDays': 3,
      'lastRenewalDate': now.toIso8601String(),
      'price': 120.0,
      'currency': 'CZK',
      'isAutoRenewal': true,
    };
    
    await docRef.set(updatedData, SetOptions(merge: true));
  }

  /// Prodloužení ročního předplatného o extra dny (default 365).
  Future<void> extendYearlySubscription({int extraDays = 365}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    
    try {
      if (_cachedSubscription == null) {
        throw Exception('Subscription nenalezeno v cache, zavolej fetchSubscription() nejdřív.');
      }
      
      // Přesuneme náročnou operaci do compute
      final oldExpiration = _cachedSubscription!.expirationDate ?? DateTime.now();
      
      await computeOrDirect(
        _extendYearlySubscriptionIsolate,
        _ExtendYearlyParams(
          userId: user.uid,
          oldExpiration: oldExpiration,
          extraDays: extraDays,
          firestore: _firestore
        )
      );
      
      FirebaseAnalytics.instance.logEvent(
        name: 'extend_yearly_subscription',
        parameters: {
          'oldExpiration': oldExpiration.toIso8601String(),
          'newExpiration': oldExpiration.add(Duration(days: extraDays)).toIso8601String(),
        },
      );
    } catch (e, st) {
      debugPrint('Error extending yearly subscription: $e');
      debugPrintStack(stackTrace: st);
      FirebaseCrashlytics.instance.log('extend_yearly_subscription error');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }
  
  // Statická metoda pro compute
  static Future<void> _extendYearlySubscriptionIsolate(_ExtendYearlyParams params) async {
    final docRef = params.firestore.collection('subscriptions').doc(params.userId);
    final newExpiration = params.oldExpiration.add(Duration(days: params.extraDays));
    
    await docRef.update({
      'expirationDate': newExpiration.toIso8601String(),
      'lastRenewalDate': DateTime.now().toIso8601String(),
    });
  }

  /// Zrušení předplatného – nastaví subscription na free.
  Future<void> cancelSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    
    try {
      // Přesuneme náročnou operaci do compute
      await computeOrDirect(
        _cancelSubscriptionIsolate,
        _CancelSubscriptionParams(
          userId: user.uid,
          firestore: _firestore
        )
      );
      
      FirebaseAnalytics.instance.logEvent(
        name: 'cancel_subscription',
        parameters: {'userId': user.uid},
      );
    } catch (e, st) {
      debugPrint('Error cancelling subscription: $e');
      debugPrintStack(stackTrace: st);
      FirebaseCrashlytics.instance.log('cancel_subscription error');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }
  
  // Statická metoda pro compute
  static Future<void> _cancelSubscriptionIsolate(_CancelSubscriptionParams params) async {
    final docRef = params.firestore.collection('subscriptions').doc(params.userId);
    
    await docRef.update({
      'isActive': false,
      'subscriptionType': subscriptionTypeToString(SubscriptionType.free),
      'expirationDate': null,
      'isTrial': 0,
    });
  }

  Subscription? get cached => _cachedSubscription;

  void dispose() {
    _subscriptionStreamController.close();
  }
}