/// lib/repositories/subscription_repository.dart
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/subscription.dart';
import '../services/payment_service.dart';
import '../services/firestore_subscription_service.dart';
import '../utils/constants.dart';

/// Repository pro správu předplatných
///
/// Propojuje PaymentService (IAP) s FirestoreSubscriptionService (databáze)
/// poskytuje jednotné rozhraní pro práci s předplatnými včetně nákupů
class SubscriptionRepository {
  final PaymentService _paymentService;
  final FirestoreSubscriptionService _firestoreService;

  // Stream pro sledování stavu předplatnč‚©ho
  final StreamController<Subscription?> _subscriptionController =
      StreamController<Subscription?>.broadcast();

  // Cache pro aktuální předplatnč‚©
  Subscription? _currentSubscription;

  // Subscription pro poslouchání nákupů
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  SubscriptionRepository({
    PaymentService? paymentService,
    FirestoreSubscriptionService? firestoreService,
  })  : _paymentService = paymentService ?? PaymentService(),
        _firestoreService =
            firestoreService ?? FirestoreSubscriptionService.defaultInstance() {
    _initializeRepository();
  }

  /// Inicializuje repository a nastaví listenery
  Future<void> _initializeRepository() async {
    try {
      // Inicializace payment service
      await _paymentService.initialize();

      // Nastavení poslucháče pro nákupy
      _purchaseSubscription = _paymentService.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          debugPrint(
              '[SubscriptionRepository] Chyba v purchase stream: $error');
        },
      );

      debugPrint(
          '[SubscriptionRepository] Repository úspěč¹Ë‡ně inicializován');
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při inicializaci: $e');
      rethrow;
    }
  }

  /// Sleduje předplatnč‚© konkrč‚©tního uťivatele
  ///
  /// [uid] - ID uťivatele
  /// Vrací Stream<Subscription?> s aktuálním stavem předplatnč‚©ho
  Stream<Subscription?> watch(String uid) {
    if (uid.isEmpty) {
      return Stream.error(ArgumentError('error_uid_empty'.tr()));
    }

    debugPrint(
        '[SubscriptionRepository] Spouč¹Ë‡tím sledování předplatnč‚©ho pro: $uid');

    // Přeposíláme stream z Firestore service
    return _firestoreService.watchSubscription(uid).map((subscription) {
      _currentSubscription = subscription;
      _subscriptionController.add(subscription);
      return subscription;
    }).handleError((error) {
      debugPrint('[SubscriptionRepository] Chyba ve watch stream: $error');
      _subscriptionController.addError(error);
      return null;
    });
  }

  /// Zpracuje úspěč¹Ë‡ný nákup a aktivuje Premium předplatnč‚©
  ///
  /// [uid] - ID uťivatele
  /// [purchaseDetails] - detaily nákupu z IAP
  ///
  /// Uloťí productId, purchaseToken, autoRenewing a přepne na premium
  Future<void> handlePurchase(
      String uid, PurchaseDetails purchaseDetails) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('error_uid_empty'.tr());
      }

      debugPrint(
          '[SubscriptionRepository] Zpracovávám nákup pro $uid: ${purchaseDetails.productID}');

      // Ověříme, ťe se jedná o podporovaný produkt
      final String expectedProductId = Platform.isAndroid
          ? Billing.productPremiumYearlyAndroid
          : Billing.productPremiumYearlyIOS;

      if (purchaseDetails.productID != expectedProductId) {
        throw Exception(
            '${'error_unsupported_product'.tr()}: ${purchaseDetails.productID}');
      }

      // Vytvoříme Premium předplatnč‚©
      final premiumSubscription = Subscription(
        id: uid,
        userId: uid,
        tier: SubscriptionTier.premium,
        expiresAt: DateTime.now()
            .add(const Duration(days: 365)), // Roční předplatnč‚©
        productId: purchaseDetails.productID,
        purchaseToken: purchaseDetails.purchaseID,
        autoRenewing:
            true, // Google Play/App Store automaticky obnovují předplatnč‚©
      );

      // Uloťíme do Firestore
      await _firestoreService.saveSubscription(uid, premiumSubscription);

      // Dokončíme nákup v payment service
      await _paymentService.completePurchase(purchaseDetails);

      debugPrint(
          '[SubscriptionRepository] Premium předplatnč‚© aktivováno pro $uid');

      // TODO: Budoucí server-side validace
      // V produkční aplikaci by zde měla být validace nákupu na serveru:
      // 1. Odeslat purchaseToken na vlastní server
      // 2. Server ověří token přes Google Play Billing API / App Store API
      // 3. Teprve po ověření aktivovat předplatnč‚©
      // 4. Zajistit, ťe token nebyl jiť pouťit (ochrana proti duplikátním aktivacím)
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při zpracování nákupu: $e');
      rethrow;
    }
  }

  /// Downgraduje uťivatele na Free verzi
  ///
  /// [uid] - ID uťivatele
  /// Uloťí free tier do databáze
  Future<void> downgradeToFree(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdnč‚©');
      }

      debugPrint('[SubscriptionRepository] Downgrade na Free pro: $uid');

      // Vytvoříme Free předplatnč‚©
      final freeSubscription = Subscription(
        id: uid,
        userId: uid,
        tier: SubscriptionTier.free,
        expiresAt: null,
        productId: null,
        purchaseToken: null,
        autoRenewing: false,
      );

      // Uloťíme do Firestore
      await _firestoreService.saveSubscription(uid, freeSubscription);

      debugPrint('[SubscriptionRepository] Uťivatel $uid downgrádován na Free');
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při downgrade: $e');
      rethrow;
    }
  }

  /// Zpracování aktualizací z purchase stream
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      debugPrint(
          '[SubscriptionRepository] Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Automatickč‚© zpracování nákupu pro aktuálního uťivatele
          // V reálnč‚© aplikaci by UID měl být předán jinak (např. přes user context)
          break;

        case PurchaseStatus.error:
          debugPrint(
              '[SubscriptionRepository] Chyba nákupu: ${purchase.error}');
          break;

        case PurchaseStatus.pending:
          debugPrint(
              '[SubscriptionRepository] Nákup čeká na zpracování: ${purchase.productID}');
          break;

        case PurchaseStatus.canceled:
          debugPrint(
              '[SubscriptionRepository] Nákup zruč¹Ë‡en: ${purchase.productID}');
          break;
      }
    }
  }

  /// Náčte aktuální předplatnč‚© uťivatele
  ///
  /// [uid] - ID uťivatele
  /// Vrací Subscription nebo null
  Future<Subscription?> getCurrentSubscription(String uid) async {
    try {
      return await _firestoreService.getSubscription(uid);
    } catch (e) {
      debugPrint(
          '[SubscriptionRepository] Chyba při náčítání předplatnč‚©ho: $e');
      return null;
    }
  }

  /// Zahájí nákup Premium předplatnč‚©ho
  ///
  /// [uid] - ID uťivatele (pro budoucí pouťití)
  /// Zahájí IAP flow pro roční předplatnč‚©
  Future<void> startPremiumPurchase(String uid) async {
    try {
      debugPrint('[SubscriptionRepository] Zahajuji nákup Premium pro: $uid');

      // Náčteme dostupnč‚© produkty
      final products = await _paymentService.loadProducts();

      if (products.isEmpty) {
        throw Exception(tr('subs.error.no_products'));
      }

      // Najdeme Premium produkt
      final premiumProduct = _paymentService.getPremiumProduct();

      if (premiumProduct == null) {
        throw Exception(tr('subs.error.premium_not_available'));
      }

      // Zahájíme nákup
      await _paymentService.buyPremium(premiumProduct);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při zahájení nákupu: $e');
      rethrow;
    }
  }

  /// Obnoví předchozí nákupy
  ///
  /// [uid] - ID uťivatele (pro budoucí pouťití)
  Future<void> restorePurchases(String uid) async {
    try {
      debugPrint('[SubscriptionRepository] Obnovuji nákupy pro: $uid');

      await _paymentService.restorePurchases();
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při obnově nákupů: $e');
      rethrow;
    }
  }

  /// Náčte dostupnč‚© produkty z obchodu
  Future<List<ProductDetails>> getAvailableProducts() async {
    try {
      return await _paymentService.loadProducts();
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při náčítání produktů: $e');
      rethrow;
    }
  }

  /// Otevře správu předplatnč‚©ho v obchodu
  Future<void> openManageSubscriptions() async {
    try {
      await _paymentService.openManageSubscriptions();
    } catch (e) {
      debugPrint(
          '[SubscriptionRepository] Chyba při otevírání správy předplatnč‚©ho: $e');
      rethrow;
    }
  }

  /// Kontrola dostupnosti IAP
  Future<bool> isPaymentAvailable() async {
    return await _paymentService.isAvailable();
  }

  /// Getter pro aktuální cache
  Subscription? get currentSubscription => _currentSubscription;

  /// Stream pro sledování změn předplatnč‚©ho
  Stream<Subscription?> get subscriptionStream =>
      _subscriptionController.stream;

  /// Uvolní zdroje
  void dispose() {
    _purchaseSubscription?.cancel();
    _subscriptionController.close();
    _paymentService.dispose();
  }
}

// TODO: Server-side validace nákupů
//
// Pro produkční aplikaci je kritickč‚© implementovat server-side validace:
//
// 1. GOOGLE PLAY BILLING API VALIDACE:
//    - Endpoint: https://developers.google.com/android-publisher/api-ref/rest/v3/purchases/subscriptions/get
//    - Potřebnč‚©: Service Account klíče, Package name, Subscription ID, Purchase token
//    - Ověří: platnost tokenu, stav předplatnč‚©ho, expiraci
//
// 2. APP STORE SERVER API VALIDACE (pro iOS):
//    - Endpoint: https://developer.apple.com/documentation/appstoreserverapi
//    - Potřebnč‚©: App Store Connect API klíče, Bundle ID, Transaction ID
//    - Ověří: platnost transakce, stav předplatnč‚©ho
//
// 3. IMPLEMENTAčŁšNč‚Ť KROKY:
//    a) Vytvořit Cloud Function pro validaci
//    b) handlePurchase() volá Cloud Function místo přímč‚©ho uloťení
//    c) Cloud Function ověří token a teprve pak aktivuje předplatnč‚©
//    d) Ochrana proti replay útokům (uloťení pouťitých tokenů)
//    e) Pravidelná synchronizace s obchody (webhook nebo cron job)
//
// 4. BEZPEčŁšNOSTNč‚Ť OPATč¹Â˜ENč‚Ť:
//    - Nikdy nevěřit pouze klientskč‚© validaci
//    - Logovat vč¹Ë‡echny pokusy o aktivaci
//    - Implementovat rate limiting
//    - Monitorovat podezřelč‚© aktivity
