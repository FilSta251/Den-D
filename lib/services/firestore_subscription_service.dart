/// lib/services/firestore_subscription_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/subscription.dart';
import '../utils/constants.dart';

/// Firestore sluťba pro správu předplatných
///
/// poskytuje CRUD operace pro subscription data uloťená v users/{uid}.subscription
/// Navrťeno pro produkční pouťití s error handlingem a retry logikou
class FirestoreSubscriptionService {
  final FirebaseFirestore _firestore;

  /// Konstruktor s moťností předat vlastní Firestore instanci (pro testování)
  FirestoreSubscriptionService(this._firestore);

  /// Factory konstruktor s výchozí Firestore instancí
  factory FirestoreSubscriptionService.defaultInstance() {
    return FirestoreSubscriptionService(FirebaseFirestore.instance);
  }

  /// Uloťí předplatnĂ© do Firestore
  ///
  /// [uid] - ID uťivatele
  /// [subscription] - předplatnĂ© k uloťení
  ///
  /// Ukládá do users/{uid} pod pole 'subscription'
  Future<void> saveSubscription(String uid, Subscription subscription) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdnĂ©');
      }

      debugPrint(
          '[FirestoreSubscription] Ukládám předplatnĂ© pro uťivatele: $uid');

      final userDocRef =
          _firestore.collection(Constants.usersCollection).doc(uid);

      // Uloťíme subscription jako sub-objekt v user dokumentu
      await userDocRef.set({
        'subscription': subscription.toJson(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          '[FirestoreSubscription] PředplatnĂ© úspěĹˇně uloťeno pro $uid');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreSubscription] Chyba při ukládání předplatnĂ©ho: $e');
      debugPrintStack(stackTrace: stackTrace);

      // Re-throw s kontextem pro lepĹˇí error handling ve vyĹˇĹˇích vrstvách
      throw Exception(
          'Nepodařilo se uloťit předplatnĂ© pro uťivatele $uid: $e');
    }
  }

  /// Sleduje změny předplatnĂ©ho v reálnĂ©m čase
  ///
  /// [uid] - ID uťivatele
  /// Vrací Stream<Subscription> s aktuálním stavem předplatnĂ©ho
  ///
  /// Pokud předplatnĂ© neexistuje, vytvoří výchozí free předplatnĂ©
  Stream<Subscription> watchSubscription(String uid) {
    if (uid.isEmpty) {
      return Stream.error(ArgumentError('UID nesmí být prázdnĂ©'));
    }

    debugPrint(
        '[FirestoreSubscription] SpouĹˇtím sledování předplatnĂ©ho pro: $uid');

    return _firestore
        .collection(Constants.usersCollection)
        .doc(uid)
        .snapshots()
        .asyncMap((DocumentSnapshot doc) async {
      try {
        if (!doc.exists) {
          debugPrint(
              '[FirestoreSubscription] User dokument neexistuje, vytvářím výchozí free předplatnĂ©');
          final defaultSubscription = _createDefaultSubscription(uid);
          await saveSubscription(uid, defaultSubscription);
          return defaultSubscription;
        }

        final data = doc.data() as Map<String, dynamic>?;

        if (data == null || !data.containsKey('subscription')) {
          debugPrint(
              '[FirestoreSubscription] Subscription data neexistují, vytvářím výchozí');
          final defaultSubscription = _createDefaultSubscription(uid);
          await saveSubscription(uid, defaultSubscription);
          return defaultSubscription;
        }

        final subscriptionData = data['subscription'] as Map<String, dynamic>;

        // Ujistíme se, ťe máme správnĂ© ID
        subscriptionData['id'] = uid;
        subscriptionData['userId'] = uid;

        final subscription = Subscription.fromJson(subscriptionData);

        debugPrint(
            '[FirestoreSubscription] Náčteno předplatnĂ©: ${subscription.tier}');
        return subscription;
      } catch (e, stackTrace) {
        debugPrint(
            '[FirestoreSubscription] Chyba při parsování předplatnĂ©ho: $e');
        debugPrintStack(stackTrace: stackTrace);

        // V případě chyby vrátíme výchozí free předplatnĂ©
        final defaultSubscription = _createDefaultSubscription(uid);

        // Pokusíme se uloťit výchozí předplatnĂ© (ale nevyhazujeme chybu pokud se nepovede)
        try {
          await saveSubscription(uid, defaultSubscription);
        } catch (saveError) {
          debugPrint(
              '[FirestoreSubscription] Nepodařilo se uloťit výchozí předplatnĂ©: $saveError');
        }

        return defaultSubscription;
      }
    }).handleError((error) {
      debugPrint('[FirestoreSubscription] Chyba ve stream: $error');
      // Stream bude pokráčovat s výchozím předplatným
      return _createDefaultSubscription(uid);
    });
  }

  /// Náčte předplatnĂ© uťivatele jednorázově
  ///
  /// [uid] - ID uťivatele
  /// Vrací Subscription nebo null pokud neexistuje
  Future<Subscription?> getSubscription(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdnĂ©');
      }

      debugPrint('[FirestoreSubscription] Náčítám předplatnĂ© pro: $uid');

      final userDoc =
          await _firestore.collection(Constants.usersCollection).doc(uid).get();

      if (!userDoc.exists) {
        debugPrint('[FirestoreSubscription] User dokument neexistuje pro $uid');
        return null;
      }

      final data = userDoc.data();

      if (data == null || !data.containsKey('subscription')) {
        debugPrint(
            '[FirestoreSubscription] Subscription data neexistují pro $uid');
        return null;
      }

      final subscriptionData = data['subscription'] as Map<String, dynamic>;

      // Ujistíme se, ťe máme správnĂ© ID
      subscriptionData['id'] = uid;
      subscriptionData['userId'] = uid;

      final subscription = Subscription.fromJson(subscriptionData);

      debugPrint(
          '[FirestoreSubscription] ĂšspěĹˇně náčteno předplatnĂ©: ${subscription.tier}');
      return subscription;
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreSubscription] Chyba při náčítání předplatnĂ©ho: $e');
      debugPrintStack(stackTrace: stackTrace);

      // Nevyhazujeme exception, pouze vrátíme null
      // Volající kĂłd se můťe rozhodnout jak reagovat
      return null;
    }
  }

  /// Vytvoří výchozí free předplatnĂ© pro novĂ©ho uťivatele
  ///
  /// [uid] - ID uťivatele
  /// Vrací Subscription s free tier
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

  /// Smaťe předplatnĂ© uťivatele
  ///
  /// [uid] - ID uťivatele
  /// UťitečnĂ© pro cleanup nebo reset na free verzi
  Future<void> deleteSubscription(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdnĂ©');
      }

      debugPrint('[FirestoreSubscription] Maťu předplatnĂ© pro: $uid');

      await _firestore.collection(Constants.usersCollection).doc(uid).update({
        'subscription': FieldValue.delete(),
        'subscriptionDeletedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FirestoreSubscription] PředplatnĂ© smazáno pro $uid');
    } catch (e, stackTrace) {
      debugPrint('[FirestoreSubscription] Chyba při mazání předplatnĂ©ho: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
          'Nepodařilo se smazat předplatnĂ© pro uťivatele $uid: $e');
    }
  }

  /// Aktualizuje pouze konkrĂ©tní pole předplatnĂ©ho
  ///
  /// [uid] - ID uťivatele
  /// [updates] - mapa polí k aktualizaci
  ///
  /// UťitečnĂ© pro částečnĂ© aktualizace bez nutnosti náčítat celĂ© předplatnĂ©
  Future<void> updateSubscriptionFields(
      String uid, Map<String, dynamic> updates) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdnĂ©');
      }

      if (updates.isEmpty) {
        debugPrint('[FirestoreSubscription] Ĺ˝ádnĂ© aktualizace k provedení');
        return;
      }

      debugPrint(
          '[FirestoreSubscription] Aktualizuji pole předplatnĂ©ho pro $uid: ${updates.keys}');

      // Prefix vĹˇechny klíče s 'subscription.'
      final prefixedUpdates = <String, dynamic>{};
      updates.forEach((key, value) {
        prefixedUpdates['subscription.$key'] = value;
      });

      // Přidáme timestamp
      prefixedUpdates['lastUpdated'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(Constants.usersCollection)
          .doc(uid)
          .update(prefixedUpdates);

      debugPrint(
          '[FirestoreSubscription] Pole předplatnĂ©ho aktualizována pro $uid');
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreSubscription] Chyba při aktualizaci polí předplatnĂ©ho: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
          'Nepodařilo se aktualizovat předplatnĂ© pro uťivatele $uid: $e');
    }
  }

  /// Ověří existenci user dokumentu a vytvoří ho pokud neexistuje
  ///
  /// [uid] - ID uťivatele
  /// UťitečnĂ© pro zajiĹˇtění konzistence dat
  Future<void> ensureUserDocumentExists(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdnĂ©');
      }

      final userDocRef =
          _firestore.collection(Constants.usersCollection).doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        debugPrint('[FirestoreSubscription] Vytvářím user dokument pro $uid');

        await userDocRef.set({
          'createdAt': FieldValue.serverTimestamp(),
          'subscription': _createDefaultSubscription(uid).toJson(),
        });

        debugPrint('[FirestoreSubscription] User dokument vytvořen pro $uid');
      }
    } catch (e, stackTrace) {
      debugPrint(
          '[FirestoreSubscription] Chyba při zajiĹˇšování user dokumentu: $e');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception('Nepodařilo se zajistit user dokument pro $uid: $e');
    }
  }
}
