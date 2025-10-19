/// lib/services/payment_service.dart - pouze roční předplatnĂ© za 200 Kč
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// PaymentService pro správu in-app nákupů
///
/// poskytuje jednotné rozhraní pro Google Play Billing a Apple StoreKit.
/// Obsahuje metody pro inicializaci, náčtení produktů, nákup a obnovu.
class PaymentService {
  // Singleton instance
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Instance InAppPurchase pluginu
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Stream pro poslouchání nákupních aktualizací
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Controller pro vlastní purchase stream
  final StreamController<List<PurchaseDetails>> _purchaseStreamController =
      StreamController<List<PurchaseDetails>>.broadcast();

  // Seznam dostupných produktů
  List<ProductDetails> _products = [];

  // Příznak inicializace
  bool _isInitialized = false;

  // ID produktu pro roční předplatnĂ© - upravte podle vaĹˇeho nastavení v obchodech
  static const String yearlySubscriptionId = 'yearly_premium_200czk';

  // Getter pro purchase stream
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseStreamController.stream;

  /// Inicializuje PaymentService
  ///
  /// Ověří dostupnost in-app nákupů a nastaví poslucháče aktualizací.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PaymentService jiť byl inicializován');
      return;
    }

    try {
      // Kontrola dostupnosti in-app nákupů
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        throw Exception('In-app nákupy nejsou dostupnĂ© na tomto zařízení');
      }

      // Nastavení poslucháče pro nákupní aktualizace
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          debugPrint('Purchase stream ukončen');
        },
        onError: (error) {
          debugPrint('Chyba v purchase streamu: $error');
          FirebaseCrashlytics.instance.recordError(error, null);
          _purchaseStreamController.addError(error);
        },
      );

      _isInitialized = true;
      debugPrint('PaymentService úspěĹˇně inicializován');
    } catch (e, st) {
      debugPrint('Chyba při inicializaci PaymentService: $e');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }

  /// Náčte informace o ročním předplatnĂ©m z obchodu
  ///
  /// Vrací [ProductDetails] s cenou a popiskem
  Future<ProductDetails?> getYearlySubscription() async {
    if (!_isInitialized) {
      throw Exception(
          'PaymentService není inicializován - zavolej initialize() nejdříve');
    }

    try {
      debugPrint('Náčítám roční předplatnĂ©: $yearlySubscriptionId');

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails({yearlySubscriptionId});

      if (response.error != null) {
        throw Exception(
            'Chyba při náčítání produktu: ${response.error!.message}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Produkt nenalezen: $yearlySubscriptionId');
        FirebaseCrashlytics.instance
            .log('Produkt nenalezen: $yearlySubscriptionId');
        return null;
      }

      _products = response.productDetails;

      if (_products.isNotEmpty) {
        final product = _products.first;
        debugPrint(
            'Náčten produkt: ${product.id} - ${product.title} (${product.price})');
        return product;
      }

      return null;
    } catch (e, st) {
      debugPrint('Chyba při náčítání ročního předplatnĂ©ho: $e');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }

  /// Zahájí nákup ročního předplatnĂ©ho
  ///
  /// Automaticky náčte produkt a zahájí nákup
  Future<void> purchaseYearlySubscription() async {
    if (!_isInitialized) {
      throw Exception('PaymentService není inicializován');
    }

    try {
      debugPrint('Zahajuji nákup ročního předplatnĂ©ho...');

      // Náčteme aktuální informace o produktu
      final ProductDetails? productDetails = await getYearlySubscription();

      if (productDetails == null) {
        throw Exception('Roční předplatnĂ© není dostupnĂ© v obchodě');
      }

      // Zahájíme nákup
      await buyProduct(productDetails);
    } catch (e, st) {
      debugPrint('Chyba při nákupu ročního předplatnĂ©ho: $e');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }

  /// Zahájí nákup produktu
  ///
  /// [productDetails] - detail produktu k nákupu
  /// Pro předplatnĂ© pouťívá buyNonConsumable
  Future<void> buyProduct(ProductDetails productDetails) async {
    if (!_isInitialized) {
      throw Exception('PaymentService není inicializován');
    }

    try {
      debugPrint('Zahajuji nákup produktu: ${productDetails.id}');

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null, // Můťeme přidat user ID pro tracking
      );

      // Pro roční předplatnĂ© pouťíváme nonConsumable
      debugPrint('Nákup ročního předplatnĂ©ho (non-consumable)');
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e, st) {
      debugPrint('Chyba při zahájení nákupu: $e');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }

  /// Obnoví předchozí nákupy
  ///
  /// UťitečnĂ© při reinstalaci aplikace nebo přepnutí zařízení.
  /// Funguje pouze pro non-consumable produkty a předplatnĂ©.
  Future<void> restorePurchases() async {
    if (!_isInitialized) {
      throw Exception('PaymentService není inicializován');
    }

    try {
      debugPrint('Zahajuji obnovu nákupů...');
      await _inAppPurchase.restorePurchases();
      debugPrint('Obnova nákupů dokončena');
    } catch (e, st) {
      debugPrint('Chyba při obnově nákupů: $e');
      FirebaseCrashlytics.instance.recordError(e, st);
      rethrow;
    }
  }

  /// Zpracování aktualizací nákupů
  ///
  /// Interní metoda pro zpracování vĹˇech stavů nákupů.
  /// Přeposílá události do vlastního streamu pro SubscriptionRepository.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    debugPrint(
        'Zpracovávám ${purchaseDetailsList.length} nákupních aktualizací');

    // Přeposlat do vlastního streamu
    _purchaseStreamController.add(purchaseDetailsList);

    // Logování pro debug
    for (final purchase in purchaseDetailsList) {
      debugPrint('Nákup ${purchase.productID}: ${purchase.status}'
          '${purchase.error != null ? ' - ${purchase.error}' : ''}');

      // AutomatickĂ© dokončení nákupu pokud je to potřeba
      if (purchase.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchase);
          debugPrint('Nákup ${purchase.productID} automaticky dokončen');
        } catch (e) {
          debugPrint('Chyba při dokončování nákupu: $e');
          FirebaseCrashlytics.instance.recordError(e, null);
        }
      }

      // Analýzy pro Firebase
      try {
        _logPurchaseEvent(purchase);
      } catch (e) {
        debugPrint('Chyba při logování purchase eventu: $e');
      }
    }
  }

  /// Logování purchase eventů pro analytiku
  void _logPurchaseEvent(PurchaseDetails purchase) {
    final Map<String, dynamic> parameters = {
      'product_id': purchase.productID,
      'status': purchase.status.toString(),
      'transaction_date': purchase.transactionDate ?? '',
      'purchase_id': purchase.purchaseID ?? '',
    };

    if (purchase.error != null) {
      parameters['error_code'] = purchase.error!.code;
      parameters['error_message'] = purchase.error!.message;
    }

    FirebaseCrashlytics.instance
        .log('Purchase event: ${purchase.productID} - ${purchase.status}');
  }

  /// Získání ročního předplatnĂ©ho z cache
  ProductDetails? getYearlySubscriptionFromCache() {
    try {
      return _products
          .firstWhere((product) => product.id == yearlySubscriptionId);
    } catch (e) {
      debugPrint('Roční předplatnĂ© $yearlySubscriptionId není v cache');
      return null;
    }
  }

  /// Vrací vĹˇechny náčtenĂ© produkty (v naĹˇem případě jen roční předplatnĂ©)
  List<ProductDetails> get availableProducts => List.unmodifiable(_products);

  /// Kontrola, zda je PaymentService inicializován
  bool get isInitialized => _isInitialized;

  /// Kontrola dostupnosti in-app nákupů
  Future<bool> isAvailable() async {
    try {
      return await _inAppPurchase.isAvailable();
    } catch (e) {
      debugPrint('Chyba při kontrole dostupnosti: $e');
      return false;
    }
  }

  /// Vrací informace o ceně ročního předplatnĂ©ho pro zobrazení
  String get yearlyPriceText {
    final product = getYearlySubscriptionFromCache();
    return product?.price ?? '200 Kč';
  }

  /// Vrací název ročního předplatnĂ©ho
  String get yearlyTitle {
    final product = getYearlySubscriptionFromCache();
    return product?.title ?? tr('rocni_predplatne');
  }

  /// Vrací popis ročního předplatnĂ©ho
  String get yearlyDescription {
    final product = getYearlySubscriptionFromCache();
    return product?.description ?? tr('rocni_predplatne_popis');
  }

  /// Uvolní zdroje
  void dispose() {
    debugPrint('PaymentService dispose');
    _subscription.cancel();
    _purchaseStreamController.close();
    _isInitialized = false;
  }

  /// Dočasná funkce pro překlady - nahraďŹte svým systĂ©mem lokalizace
  String tr(String key) {
    const Map<String, String> translations = {
      'rocni_predplatne': 'Roční předplatnĂ©',
      'rocni_predplatne_popis':
          'Získejte přístup ke vĹˇem funkcím aplikace na celý rok za 200 Kč',
    };
    return translations[key] ?? key;
  }
}
