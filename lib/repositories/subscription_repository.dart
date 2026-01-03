/// lib/repositories/subscription_repository.dart
///
/// Repository pro správu předplatných s server-side ověřením.
/// AKTUALIZOVÁNO: Implementováno setActiveUser, server-side validace,
/// správné analytics tracking a deduplikace.
/// OPRAVENO: iOS nyní získává skutečnou cenu z ProductDetails
/// OPRAVA v1.3.4: Graceful handling když IAP není dostupný - aplikace nepadá
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/subscription.dart';
import '../services/payment_service.dart';
import '../services/firestore_subscription_service.dart';
import '../services/purchase_verification_service.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';

/// Stav zpracování nákupu
enum PurchaseProcessingState { idle, verifying, success, error }

/// Repository pro správu předplatných
///
/// Propojuje PaymentService (IAP) s FirestoreSubscriptionService (databáze)
/// a PurchaseVerificationService (server-side validace).
///
/// NOVÉ FUNKCE:
/// - setActiveUser(uid) - nastaví aktivního uživatele pro zpracování nákupů
/// - Server-side validace před acknowledge
/// - Analytics tracking (pouze pro nové nákupy, ne restored)
/// - Deduplikace purchase logů
///
/// OPRAVA v1.3.4:
/// - Graceful handling když IAP není dostupný
/// - Aplikace funguje i bez možnosti nákupu
class SubscriptionRepository {
  final PaymentService _paymentService;
  final FirestoreSubscriptionService _firestoreService;
  final PurchaseVerificationService _verificationService;
  final AnalyticsService _analyticsService;

  // Stream pro sledování stavu předplatného
  final StreamController<Subscription?> _subscriptionController =
      StreamController<Subscription?>.broadcast();

  // Stream pro sledování stavu zpracování nákupu
  final StreamController<PurchaseProcessingState> _processingStateController =
      StreamController<PurchaseProcessingState>.broadcast();

  // Cache pro aktuální předplatné
  Subscription? _currentSubscription;

  // Aktuální aktivní uživatel
  String? _activeUserId;

  // Subscription pro poslouchání nákupů
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // Set pro sledování zpracovaných nákupů v této session
  final Set<String> _processedPurchaseIds = {};

  // Cache pro poslední načtený produkt (pro iOS analytics)
  ProductDetails? _lastLoadedProduct;

  // Příznak dostupnosti IAP - NOVÉ
  bool _isIAPAvailable = false;

  SubscriptionRepository({
    PaymentService? paymentService,
    FirestoreSubscriptionService? firestoreService,
    PurchaseVerificationService? verificationService,
    AnalyticsService? analyticsService,
  })  : _paymentService = paymentService ?? PaymentService(),
        _firestoreService =
            firestoreService ?? FirestoreSubscriptionService.defaultInstance(),
        _verificationService =
            verificationService ?? PurchaseVerificationService(),
        _analyticsService = analyticsService ?? AnalyticsService() {
    _initializeRepository();
  }

  /// Inicializuje repository a nastaví listenery
  ///
  /// OPRAVA v1.3.4: Nikdy nehodí výjimku - aplikace funguje i bez IAP
  Future<void> _initializeRepository() async {
    try {
      // Inicializace payment service - OPRAVA: nyní vrací bool místo throwing
      _isIAPAvailable = await _paymentService.initialize();

      if (!_isIAPAvailable) {
        debugPrint(
          '[SubscriptionRepository] ⚠️ IAP není dostupný - repository funguje v omezeném režimu',
        );
        // Pokračujeme dál - aplikace funguje, jen bez možnosti nákupu
      }

      // Inicializace analytics service
      await _analyticsService.initialize();

      // Nastavení posluchače pro nákupy - POUZE pokud je IAP dostupný
      if (_isIAPAvailable) {
        _purchaseSubscription = _paymentService.purchaseStream.listen(
          _handlePurchaseUpdates,
          onError: (error) {
            debugPrint(
              '[SubscriptionRepository] Chyba v purchase stream: $error',
            );
          },
        );
      }

      debugPrint(
        '[SubscriptionRepository] Repository inicializován (IAP available: $_isIAPAvailable)',
      );
    } catch (e) {
      // OPRAVA: Nikdy neděláme rethrow - aplikace musí fungovat
      debugPrint('[SubscriptionRepository] ⚠️ Chyba při inicializaci: $e');
      debugPrint(
          '[SubscriptionRepository] Repository funguje v omezeném režimu');
      _isIAPAvailable = false;
      // ODSTRANĚNO: rethrow - to způsobovalo crash
    }
  }

  /// Getter pro dostupnost IAP - NOVÉ
  /// Vrací true pokud je možné provádět nákupy
  bool get isIAPAvailable => _isIAPAvailable;

  /// Nastaví aktivního uživatele pro zpracování nákupů
  ///
  /// DŮLEŽITÉ: Volat při přihlášení uživatele (např. z SubscriptionProvider.bindUser)
  /// [uid] - ID přihlášeného uživatele
  void setActiveUser(String? uid) {
    _activeUserId = uid;
    debugPrint('[SubscriptionRepository] Active user set: $uid');

    // Nastavení user ID pro analytics
    _analyticsService.setUserId(uid);
  }

  /// Getter pro aktivního uživatele
  String? get activeUserId => _activeUserId;

  /// Stream pro sledování stavu zpracování nákupu
  Stream<PurchaseProcessingState> get processingStateStream =>
      _processingStateController.stream;

  /// Sleduje předplatné konkrétního uživatele
  ///
  /// [uid] - ID uživatele
  /// Vrací Stream s aktuálním stavem předplatného
  Stream<Subscription?> watch(String uid) {
    if (uid.isEmpty) {
      return Stream.error(ArgumentError('error_uid_empty'.tr()));
    }

    debugPrint(
      '[SubscriptionRepository] Spouštím sledování předplatného pro: $uid',
    );

    // Přeposíláme stream z Firestore service
    return _firestoreService.watchSubscription(uid).map((subscription) {
      _currentSubscription = subscription;
      _subscriptionController.add(subscription);

      // Aktualizace analytics user property
      _analyticsService.setSubscriptionTier(
        subscription?.tier.name ?? 'free',
      );

      return subscription;
    }).handleError((error) {
      debugPrint('[SubscriptionRepository] Chyba ve watch stream: $error');
      _subscriptionController.addError(error);
      return null;
    });
  }

  /// Zpracování aktualizací z purchase stream
  ///
  /// HLAVNÍ LOGIKA:
  /// - PurchaseStatus.purchased - verify na serveru, analytics, completePurchase
  /// - PurchaseStatus.restored - pouze verify (BEZ analytics), completePurchase
  /// - PurchaseStatus.error - log error
  /// - PurchaseStatus.canceled - log canceled
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      debugPrint(
        '[SubscriptionRepository] Purchase update: ${purchase.productID} - ${purchase.status}',
      );

      // Deduplikace - přeskočit již zpracované nákupy v této session
      // ALE: Pokud subscription je stále FREE, zpracovat znovu!
      final purchaseKey = '${purchase.productID}_${purchase.purchaseID}';
      if (_processedPurchaseIds.contains(purchaseKey) &&
          purchase.status != PurchaseStatus.pending) {
        // OPRAVA: Zkontrolovat zda je uživatel už Premium
        // Pokud ne, zpracovat nákup znovu
        final shouldReprocess = await _shouldReprocessPurchase();
        if (!shouldReprocess) {
          debugPrint(
            '[SubscriptionRepository] Skipping already processed purchase: $purchaseKey',
          );
          continue;
        }
        debugPrint(
          '[SubscriptionRepository] Re-processing purchase (subscription still free): $purchaseKey',
        );
      }

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          await _handlePurchased(purchase, isRestore: false);
          _processedPurchaseIds.add(purchaseKey);
          break;

        case PurchaseStatus.restored:
          await _handlePurchased(purchase, isRestore: true);
          _processedPurchaseIds.add(purchaseKey);
          break;

        case PurchaseStatus.error:
          _handleError(purchase);
          break;

        case PurchaseStatus.pending:
          debugPrint(
            '[SubscriptionRepository] Nákup čeká na zpracování: ${purchase.productID}',
          );
          break;

        case PurchaseStatus.canceled:
          _handleCanceled(purchase);
          break;
      }
    }
  }

  /// Kontroluje zda by se měl nákup znovu zpracovat
  /// Vrací true pokud uživatel NENÍ Premium (tzn. předchozí zpracování selhalo)
  Future<bool> _shouldReprocessPurchase() async {
    if (_activeUserId == null || _activeUserId!.isEmpty) {
      return false;
    }

    try {
      final currentSub = await _firestoreService.getSubscription(
        _activeUserId!,
      );
      final isPremium = currentSub?.isActivePremium ?? false;

      if (!isPremium) {
        debugPrint(
          '[SubscriptionRepository] User is not Premium, will reprocess purchase',
        );
      }

      return !isPremium;
    } catch (e) {
      debugPrint('[SubscriptionRepository] Error checking subscription: $e');
      return true; // V případě chyby raději zpracovat znovu
    }
  }

  /// Zpracování úspěšného nákupu nebo restore
  ///
  /// [purchase] - detaily nákupu
  /// [isRestore] - true pokud je to restore (nelogovat jako konverzi)
  Future<void> _handlePurchased(
    PurchaseDetails purchase, {
    required bool isRestore,
  }) async {
    final uid = _activeUserId;

    if (uid == null || uid.isEmpty) {
      debugPrint(
        '[SubscriptionRepository] CHYBA: Žádný aktivní uživatel pro zpracování nákupu',
      );
      // Nelze zpracovat bez uid - nákup zůstane pending
      return;
    }

    debugPrint(
      '[SubscriptionRepository] Zpracovávám ${isRestore ? 'RESTORE' : 'NÁKUP'}: '
      'uid=$uid, productId=${purchase.productID}, platform=${Platform.isIOS ? 'iOS' : 'Android'}',
    );

    _processingStateController.add(PurchaseProcessingState.verifying);

    try {
      // Rozlišení podle platformy
      if (Platform.isAndroid) {
        await _handleAndroidPurchase(uid, purchase, isRestore);
      } else if (Platform.isIOS) {
        await _handleIOSPurchase(uid, purchase, isRestore);
      } else {
        throw Exception('Nepodporovaná platforma');
      }

      // 3. COMPLETE PURCHASE (acknowledge) - až po úspěšné validaci
      if (purchase.pendingCompletePurchase) {
        debugPrint(
          '[SubscriptionRepository] Completing purchase (acknowledge)...',
        );
        await _paymentService.completePurchase(purchase);
      }

      _processingStateController.add(PurchaseProcessingState.success);

      debugPrint(
        '[SubscriptionRepository] ${isRestore ? 'Restore' : 'Nákup'} úspěšně zpracován',
      );
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při zpracování nákupu: $e');

      _processingStateController.add(PurchaseProcessingState.error);

      // Log error do analytics
      await _analyticsService.logPurchaseError(
        productId: purchase.productID,
        error: e.toString(),
      );

      // Poznámka: completePurchase se NEVOLÁ při chybě validace
      // Nákup zůstane pending a může být zpracován znovu
    }
  }

  /// Zpracování Android nákupu - server-side validace přes Google Play API
  Future<void> _handleAndroidPurchase(
    String uid,
    PurchaseDetails purchase,
    bool isRestore,
  ) async {
    // Extrakce purchase token (Android specific)
    String? purchaseToken;
    if (purchase is GooglePlayPurchaseDetails) {
      purchaseToken = purchase.billingClientPurchase.purchaseToken;
    } else {
      purchaseToken = purchase.purchaseID;
    }

    if (purchaseToken == null || purchaseToken.isEmpty) {
      throw Exception('Chybí purchase token');
    }

    // 1. SERVER-SIDE VALIDACE
    debugPrint(
      '[SubscriptionRepository] Volám server-side validaci (Android)...',
    );

    final verificationResult =
        await _verificationService.verifyPlaySubscription(
      uid: uid,
      productId: purchase.productID,
      purchaseToken: purchaseToken,
    );

    debugPrint(
      '[SubscriptionRepository] Výsledek validace: $verificationResult',
    );

    if (!verificationResult.valid) {
      throw Exception(
        verificationResult.error ?? 'Nákup nebyl ověřen serverem',
      );
    }

    // 2. ANALYTICS - pouze pro NOVÉ nákupy, NE pro restored
    if (!isRestore && !verificationResult.alreadyProcessed) {
      final orderId = verificationResult.orderId ?? '';
      final price = verificationResult.price ?? 0;
      final currency = verificationResult.currency ?? 'CZK';

      if (orderId.isNotEmpty) {
        final logged = await _analyticsService.logPurchase(
          orderId: orderId,
          productId: purchase.productID,
          price: price,
          currency: currency,
        );

        debugPrint(
          '[SubscriptionRepository] Analytics purchase logged: $logged',
        );
      }
    } else if (isRestore) {
      await _analyticsService.logRestorePurchase(productId: purchase.productID);
    }
  }

  /// Zpracování iOS nákupu - App Store validuje automaticky
  /// Pro iOS aktivujeme Premium přímo, protože App Store už ověřil platbu
  /// OPRAVENO: Získává skutečnou cenu z ProductDetails
  Future<void> _handleIOSPurchase(
    String uid,
    PurchaseDetails purchase,
    bool isRestore,
  ) async {
    debugPrint('[SubscriptionRepository] Zpracovávám iOS nákup...');

    // App Store už ověřil platbu, můžeme přímo aktivovat Premium
    // Pro vyšší bezpečnost by se měla implementovat server-side validace
    // s App Store receipt verification, ale pro MVP je toto dostačující

    // Výpočet expirace (1 rok od teď pro roční předplatné)
    final expiresAt = DateTime.now().add(const Duration(days: 365));

    // Vytvoření Premium předplatného
    final premiumSubscription = Subscription(
      id: uid,
      userId: uid,
      tier: SubscriptionTier.premium,
      expiresAt: expiresAt,
      productId: purchase.productID,
      purchaseToken: purchase.purchaseID,
      autoRenewing: true, // iOS předplatné se automaticky obnovuje
    );

    // Uložení do Firestore
    debugPrint(
      '[SubscriptionRepository] Ukládám Premium do Firestore (iOS)...',
    );
    await _firestoreService.saveSubscription(uid, premiumSubscription);

    // Analytics
    if (!isRestore) {
      // OPRAVENO: Získáme skutečnou cenu z ProductDetails
      double price = Constants.premiumPriceYearly; // Fallback hodnota
      String currency = Constants.currency; // Fallback 'CZK'

      // Zkusíme získat skutečnou cenu z cache nebo z PaymentService
      final product = _lastLoadedProduct ?? _paymentService.getPremiumProduct();

      if (product != null) {
        final (extractedPrice, extractedCurrency) =
            _paymentService.extractPriceAndCurrency(product);
        price = extractedPrice;
        currency = extractedCurrency;
        debugPrint(
          '[SubscriptionRepository] iOS: Skutečná cena z ProductDetails: $price $currency',
        );
      } else {
        debugPrint(
          '[SubscriptionRepository] iOS: Používám fallback cenu: $price $currency',
        );
      }

      // Pro nový nákup logovat purchase
      await _analyticsService.logPurchase(
        orderId: purchase.purchaseID ??
            'ios_${DateTime.now().millisecondsSinceEpoch}',
        productId: purchase.productID,
        price: price,
        currency: currency,
      );
    } else {
      // Pro restore pouze logovat
      await _analyticsService.logRestorePurchase(productId: purchase.productID);
    }

    // Aktualizace analytics user property
    await _analyticsService.setSubscriptionTier('premium');

    debugPrint('[SubscriptionRepository] iOS Premium aktivován úspěšně');
  }

  /// Zpracování chyby nákupu
  void _handleError(PurchaseDetails purchase) {
    final errorMessage = purchase.error?.message ?? 'Neznámá chyba';
    debugPrint(
      '[SubscriptionRepository] Chyba nákupu: ${purchase.productID} - $errorMessage',
    );

    _processingStateController.add(PurchaseProcessingState.error);

    // Log error do analytics
    _analyticsService.logPurchaseError(
      productId: purchase.productID,
      error: errorMessage,
    );
  }

  /// Zpracování zrušeného nákupu
  void _handleCanceled(PurchaseDetails purchase) {
    debugPrint('[SubscriptionRepository] Nákup zrušen: ${purchase.productID}');

    _processingStateController.add(PurchaseProcessingState.idle);

    // Log canceled do analytics
    _analyticsService.logPurchaseCanceled(productId: purchase.productID);
  }

  /// Zpracuje úspěšný nákup a aktivuje Premium předplatné (legacy metoda)
  ///
  /// DEPRECATED: Použijte automatické zpracování přes _handlePurchaseUpdates
  /// Tato metoda je zachována pro zpětnou kompatibilitu.
  Future<void> handlePurchase(
    String uid,
    PurchaseDetails purchaseDetails,
  ) async {
    debugPrint(
      '[SubscriptionRepository] LEGACY handlePurchase called - using new flow',
    );

    // Nastavíme aktivního uživatele a necháme zpracovat automaticky
    setActiveUser(uid);

    // Manuální zpracování pro zpětnou kompatibilitu
    await _handlePurchased(purchaseDetails, isRestore: false);
  }

  /// Downgraduje uživatele na Free verzi
  ///
  /// [uid] - ID uživatele
  /// Uloží free tier do databáze
  Future<void> downgradeToFree(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('UID nesmí být prázdné');
      }

      debugPrint('[SubscriptionRepository] Downgrade na Free pro: $uid');

      // Vytvoříme Free předplatné
      final freeSubscription = Subscription(
        id: uid,
        userId: uid,
        tier: SubscriptionTier.free,
        expiresAt: null,
        productId: null,
        purchaseToken: null,
        autoRenewing: false,
      );

      // Uložíme do Firestore
      await _firestoreService.saveSubscription(uid, freeSubscription);

      // Aktualizace analytics
      await _analyticsService.setSubscriptionTier('free');

      debugPrint('[SubscriptionRepository] Uživatel $uid downgrádován na Free');
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při downgrade: $e');
      rethrow;
    }
  }

  /// Načte aktuální předplatné uživatele
  ///
  /// [uid] - ID uživatele
  /// Vrací Subscription nebo null
  Future<Subscription?> getCurrentSubscription(String uid) async {
    try {
      return await _firestoreService.getSubscription(uid);
    } catch (e) {
      debugPrint(
        '[SubscriptionRepository] Chyba při načítání předplatného: $e',
      );
      return null;
    }
  }

  /// Zahájí nákup Premium předplatného
  ///
  /// [uid] - ID uživatele
  /// Zahájí IAP flow pro roční předplatné a loguje begin_checkout
  ///
  /// OPRAVA v1.3.4: Kontroluje dostupnost IAP před zahájením nákupu
  Future<void> startPremiumPurchase(String uid) async {
    // OPRAVA: Kontrola dostupnosti IAP
    if (!_isIAPAvailable) {
      debugPrint(
          '[SubscriptionRepository] ⚠️ IAP není dostupný - nelze zahájit nákup');
      throw IAPNotAvailableException('error_iap_not_available'.tr());
    }

    try {
      debugPrint('[SubscriptionRepository] Zahajuji nákup Premium pro: $uid');

      // Nastavení aktivního uživatele
      setActiveUser(uid);

      // Načteme dostupné produkty
      final products = await _paymentService.loadProducts();

      if (products.isEmpty) {
        throw Exception(tr('subs.error.no_products'));
      }

      // Najdeme Premium produkt
      final premiumProduct = _paymentService.getPremiumProduct();

      if (premiumProduct == null) {
        throw Exception(tr('subs.error.premium_not_available'));
      }

      // OPRAVENO: Uložíme produkt do cache pro pozdější použití v analytics
      _lastLoadedProduct = premiumProduct;

      // Získáme cenu pro begin_checkout
      final (price, currency) =
          _paymentService.extractPriceAndCurrency(premiumProduct);

      // Log begin_checkout do analytics s cenou
      await _analyticsService.logBeginCheckout(
        plan: 'premium_yearly',
        productId: premiumProduct.id,
        price: price,
        currency: currency,
      );

      // Zahájíme nákup
      await _paymentService.buyPremium(premiumProduct);
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při zahájení nákupu: $e');
      rethrow;
    }
  }

  /// Obnoví předchozí nákupy
  ///
  /// [uid] - ID uživatele
  ///
  /// OPRAVA v1.3.4: Kontroluje dostupnost IAP
  Future<void> restorePurchases(String uid) async {
    // OPRAVA: Kontrola dostupnosti IAP
    if (!_isIAPAvailable) {
      debugPrint(
          '[SubscriptionRepository] ⚠️ IAP není dostupný - nelze obnovit nákupy');
      throw IAPNotAvailableException('error_iap_not_available'.tr());
    }

    try {
      debugPrint('[SubscriptionRepository] Obnovuji nákupy pro: $uid');

      // Nastavení aktivního uživatele
      setActiveUser(uid);

      await _paymentService.restorePurchases();
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při obnově nákupů: $e');
      rethrow;
    }
  }

  /// Načte dostupné produkty z obchodu
  ///
  /// OPRAVA v1.3.4: Kontroluje dostupnost IAP
  Future<List<ProductDetails>> getAvailableProducts() async {
    // OPRAVA: Kontrola dostupnosti IAP
    if (!_isIAPAvailable) {
      debugPrint(
          '[SubscriptionRepository] ⚠️ IAP není dostupný - nelze načíst produkty');
      return []; // Vrátíme prázdný seznam místo výjimky
    }

    try {
      final products = await _paymentService.loadProducts();

      // Uložíme Premium produkt do cache
      if (products.isNotEmpty) {
        _lastLoadedProduct = _paymentService.getPremiumProduct();
      }

      return products;
    } catch (e) {
      debugPrint('[SubscriptionRepository] Chyba při načítání produktů: $e');
      rethrow;
    }
  }

  /// Otevře správu předplatného v obchodu
  Future<void> openManageSubscriptions() async {
    try {
      await _paymentService.openManageSubscriptions();
    } catch (e) {
      debugPrint(
        '[SubscriptionRepository] Chyba při otevírání správy předplatného: $e',
      );
      rethrow;
    }
  }

  /// Kontrola dostupnosti IAP
  ///
  /// OPRAVA v1.3.4: Používá cached hodnotu místo async volání
  Future<bool> isPaymentAvailable() async {
    return _isIAPAvailable;
  }

  /// Getter pro aktuální cache
  Subscription? get currentSubscription => _currentSubscription;

  /// Stream pro sledování změn předplatného
  Stream<Subscription?> get subscriptionStream =>
      _subscriptionController.stream;

  /// Log paywall view - volat při zobrazení subscription stránky/dialogu
  Future<void> logPaywallView({
    required String source,
    required String screen,
  }) async {
    await _analyticsService.logPaywallView(source: source, screen: screen);
  }

  /// Uvolní zdroje
  void dispose() {
    _purchaseSubscription?.cancel();
    _subscriptionController.close();
    _processingStateController.close();
    _paymentService.dispose();
  }
}
