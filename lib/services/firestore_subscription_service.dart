/// lib/services/firestore_subscription_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../utils/constants.dart';

/// Firestore služba pro správu předplatných
///
/// OPRAVENO: Nyní čte z kolekce 'subscriptions/{uid}' (kam ukládá Cloud Function)
/// místo z 'users/{uid}.subscription'
class FirestoreSubscriptionService {
  final FirebaseFirestore _firestore;

  /// Konstruktor s možností předat vlastní Firestore instanci (pro testování)
  FirestoreSubscriptionService(this._firestore);

  /// Factory konstruktor s výchozí Firestore instancí
  factory FirestoreSubscriptionService.defaultInstance() {
    return FirestoreSubscriptionService(FirebaseFirestore.instance);
  }

  /// Uloží předplatné do Firestore
  ///
  /// [uid] - ID uživatele
  /// [subscription] - předplatné k uložení
  ///
  /// OPRAVENO: Ukládá do subscriptions/{uid} (stejně jako Cloud Function)
  Future<void> saveSubscription(String uid, Subscription subscription) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdné');
      }

      debugPrint(
          '[FirestoreSubscription] Ukládám předplatné pro uživatele: $uid');

      // OPRAVENO: Ukládáme do kolekce subscriptions
      final subscriptionDocRef =
          _firestore.collection(Constants.subscriptionsCollection).doc(uid);

      // Připravíme data ve formátu kompatibilním s Cloud Function
      final data = {
        'userId': uid,
        'tier':
            subscription.tier == SubscriptionTier.premium ? 'premium' : 'free',
        'productId': subscription.productId,
        'purchaseToken': subscription.purchaseToken,
        'autoRenewing': subscription.autoRenewing,
        'expiresAt': subscription.expiresAt != null
            ? Timestamp.fromDate(subscription.expiresAt!)
            : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await subscriptionDocRef.set(data, SetOptions(merge: true));

      debugPrint('[FirestoreSubscription] Předplatné úspěšně uloženo pro $uid');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreSubscription] Chyba při ukládání předplatného: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception('Nepodařilo se uložit předplatné pro uživatele $uid: $e');
    }
  }

  /// Sleduje změny předplatného v reálném čase
  ///
  /// [uid] - ID uživatele
  /// Vrací Stream<Subscription> s aktuálním stavem předplatného
  ///
  /// OPRAVENO: Čte z kolekce subscriptions/{uid}
  Stream<Subscription> watchSubscription(String uid) {
    if (uid.isEmpty) {
      return Stream.error(ArgumentError('UID nesmí být prázdné'));
    }

    debugPrint(
        '[FirestoreSubscription] Spouštím sledování předplatného pro: $uid');

    // OPRAVENO: Čteme z kolekce subscriptions
    return _firestore
        .collection(Constants.subscriptionsCollection)
        .doc(uid)
        .snapshots()
        .asyncMap((DocumentSnapshot doc) async {
      try {
        if (!doc.exists) {
          debugPrint(
              '[FirestoreSubscription] Subscription dokument neexistuje, vytvářím výchozí free předplatné');
          final defaultSubscription = _createDefaultSubscription(uid);
          await saveSubscription(uid, defaultSubscription);
          return defaultSubscription;
        }

        final data = doc.data() as Map<String, dynamic>?;

        if (data == null) {
          debugPrint(
              '[FirestoreSubscription] Subscription data jsou null, vytvářím výchozí');
          final defaultSubscription = _createDefaultSubscription(uid);
          await saveSubscription(uid, defaultSubscription);
          return defaultSubscription;
        }

        // Parsujeme data z formátu Cloud Function
        final subscription = _parseSubscriptionFromFirestore(uid, data);

        debugPrint(
            '[FirestoreSubscription] Načteno předplatné: ${subscription.tier}, '
            'expiresAt: ${subscription.expiresAt}, '
            'isActivePremium: ${subscription.isActivePremium}');
        return subscription;
      } catch (e, stackTrace) {
        debugPrint(
            '[FirestoreSubscription] Chyba při parsování předplatného: $e');
        debugPrintStack(stackTrace: stackTrace);

        final defaultSubscription = _createDefaultSubscription(uid);

        try {
          await saveSubscription(uid, defaultSubscription);
        } catch (saveError) {
          debugPrint(
              '[FirestoreSubscription] Nepodařilo se uložit výchozí předplatné: $saveError');
        }

        return defaultSubscription;
      }
    }).handleError((error) {
      debugPrint('[FirestoreSubscription] Chyba ve stream: $error');
      return _createDefaultSubscription(uid);
    });
  }

  /// Načte předplatné uživatele jednorázově
  ///
  /// [uid] - ID uživatele
  /// Vrací Subscription nebo null pokud neexistuje
  ///
  /// OPRAVENO: Čte z kolekce subscriptions/{uid}
  Future<Subscription?> getSubscription(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdné');
      }

      debugPrint('[FirestoreSubscription] Načítám předplatné pro: $uid');

      // OPRAVENO: Čteme z kolekce subscriptions
      final subscriptionDoc = await _firestore
          .collection(Constants.subscriptionsCollection)
          .doc(uid)
          .get();

      if (!subscriptionDoc.exists) {
        debugPrint(
            '[FirestoreSubscription] Subscription dokument neexistuje pro $uid');
        return null;
      }

      final data = subscriptionDoc.data();

      if (data == null) {
        debugPrint(
            '[FirestoreSubscription] Subscription data jsou null pro $uid');
        return null;
      }

      final subscription = _parseSubscriptionFromFirestore(uid, data);

      debugPrint(
          '[FirestoreSubscription] Úspěšně načteno předplatné: ${subscription.tier}, '
          'isActivePremium: ${subscription.isActivePremium}');
      return subscription;
    } catch (e, stackTrace) {
      debugPrint('[FirestoreSubscription] Chyba při načítání předplatného: $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Parsuje Subscription z Firestore dat (formát Cloud Function)
  Subscription _parseSubscriptionFromFirestore(
      String uid, Map<String, dynamic> data) {
    // Parsování tier
    final tierString = data['tier'] as String? ?? 'free';
    final tier = tierString == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;

    // Parsování expiresAt - může být Timestamp nebo null
    DateTime? expiresAt;
    final expiresAtValue = data['expiresAt'];
    if (expiresAtValue != null) {
      if (expiresAtValue is Timestamp) {
        expiresAt = expiresAtValue.toDate();
      } else if (expiresAtValue is String) {
        expiresAt = DateTime.tryParse(expiresAtValue);
      }
    }

    // Parsování autoRenewing - může být bool nebo null
    bool autoRenewing = false;
    final autoRenewingValue = data['autoRenewing'];
    if (autoRenewingValue != null) {
      if (autoRenewingValue is bool) {
        autoRenewing = autoRenewingValue;
      } else if (autoRenewingValue is int) {
        autoRenewing = autoRenewingValue != 0;
      }
    }

    return Subscription(
      id: uid,
      userId: data['userId'] as String? ?? uid,
      tier: tier,
      expiresAt: expiresAt,
      productId: data['productId'] as String?,
      purchaseToken: data['purchaseToken'] as String?,
      autoRenewing: autoRenewing,
    );
  }

  /// Vytvoří výchozí free předplatné pro nového uživatele
  Subscription _createDefaultSubscription(String uid) {
    return Subscription(
      id: uid,
      userId: uid,
      tier: SubscriptionTier.free,
      expiresAt: null,
      productId: null,
      purchaseToken: null,
      autoRenewing: false,
    );
  }

  /// Smaže předplatné uživatele
  ///
  /// [uid] - ID uživatele
  /// OPRAVENO: Maže z kolekce subscriptions
  Future<void> deleteSubscription(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdné');
      }

      debugPrint('[FirestoreSubscription] Mažu předplatné pro: $uid');

      await _firestore
          .collection(Constants.subscriptionsCollection)
          .doc(uid)
          .delete();

      debugPrint('[FirestoreSubscription] Předplatné smazáno pro $uid');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreSubscription] Chyba při mazání předplatného: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception('Nepodařilo se smazat předplatné pro uživatele $uid: $e');
    }
  }

  /// Aktualizuje pouze konkrétní pole předplatného
  ///
  /// [uid] - ID uživatele
  /// [updates] - mapa polí k aktualizaci
  ///
  /// OPRAVENO: Aktualizuje v kolekci subscriptions
  Future<void> updateSubscriptionFields(
      String uid, Map<String, dynamic> updates) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdné');
      }

      if (updates.isEmpty) {
        debugPrint('[FirestoreSubscription] Žádné aktualizace k provedení');
        return;
      }

      debugPrint(
          '[FirestoreSubscription] Aktualizuji pole předplatného pro $uid: ${updates.keys}');

      // Přidáme timestamp
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(Constants.subscriptionsCollection)
          .doc(uid)
          .update(updates);

      debugPrint(
          '[FirestoreSubscription] Pole předplatného aktualizována pro $uid');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreSubscription] Chyba při aktualizaci polí předplatného: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
          'Nepodařilo se aktualizovat předplatné pro uživatele $uid: $e');
    }
  }

  /// Ověří existenci subscription dokumentu a vytvoří ho pokud neexistuje
  ///
  /// [uid] - ID uživatele
  /// OPRAVENO: Kontroluje kolekci subscriptions
  Future<void> ensureUserDocumentExists(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdné');
      }

      final subscriptionDocRef =
          _firestore.collection(Constants.subscriptionsCollection).doc(uid);
      final subscriptionDoc = await subscriptionDocRef.get();

      if (!subscriptionDoc.exists) {
        debugPrint(
            '[FirestoreSubscription] Vytvářím subscription dokument pro $uid');

        final defaultSubscription = _createDefaultSubscription(uid);
        await saveSubscription(uid, defaultSubscription);

        debugPrint(
            '[FirestoreSubscription] Subscription dokument vytvořen pro $uid');
      }
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreSubscription] Chyba při zajišťování subscription dokumentu: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
          'Nepodařilo se zajistit subscription dokument pro $uid: $e');
    }
  }
}
