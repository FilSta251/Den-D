/// lib/services/payment_service.dart
///
/// PaymentService pro správu in-app nákupů.
/// AKTUALIZOVÁNO: Odstraněno automatické completePurchase - nyní řízeno z SubscriptionRepository
/// po server-side ověření.
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/constants.dart';

/// PaymentService pro správu in-app nákupů
///
/// Poskytuje jednotné rozhraní pro Google Play Billing a Apple StoreKit.
/// Obsahuje metody pro inicializaci, načtení produktů, nákup a správu předplatného.
///
/// ZMĚNA: completePurchase se nyní NEVOLÁ automaticky v _handlePurchaseUpdates.
/// Je zodpovědností SubscriptionRepository zavolat completePurchase až PO
/// úspěšném server-side ověření nákupu.
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

  /// Getter pro purchase stream - přeposílá InAppPurchase.instance.purchaseStream
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _purchaseStreamController.stream;

  /// Kontrola dostupnosti in-app nákupů
  Future<bool> isAvailable() async {
    try {
      return await _inAppPurchase.isAvailable();
    } catch (e) {
      debugPrint('Chyba při kontrole dostupnosti IAP: $e');
      return false;
    }
  }

  /// Inicializuje PaymentService
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('PaymentService již byl inicializován');
      return;
    }

    try {
      // Kontrola dostupnosti in-app nákupů
      final bool available = await isAvailable();
      if (!available) {
        throw Exception('error_iap_not_available'.tr());
      }

      // Nastavení posluchače pro nákupní aktualizace - přeposílání do vlastního streamu
      _subscription = _inAppPurchase.purchaseStream.listen(
        (List<PurchaseDetails> purchaseDetailsList) {
          _purchaseStreamController.add(purchaseDetailsList);
          _handlePurchaseUpdates(purchaseDetailsList);
        },
        onDone: () {
          debugPrint('Purchase stream ukončen');
        },
        onError: (error) {
          debugPrint('Chyba v purchase streamu: $error');
          _purchaseStreamController.addError(error);
        },
      );

      _isInitialized = true;
      debugPrint('PaymentService úspěšně inicializován');
    } catch (e) {
      debugPrint('Chyba při inicializaci PaymentService: $e');
      rethrow;
    }
  }

  /// Načte produkty z obchodu
  Future<List<ProductDetails>> loadProducts() async {
    if (!_isInitialized) {
      throw Exception('error_payment_service_not_initialized'.tr());
    }

    try {
      final Set<String> productIds = {
        Platform.isAndroid
            ? Billing.productPremiumYearlyAndroid
            : Billing.productPremiumYearlyIOS
      };

      debugPrint('Načítám produkty: $productIds');

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        throw Exception(
            '${'error_loading_products'.tr()}: ${response.error!.message}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Nenalezené produkty: ${response.notFoundIDs}');
      }

      _products = response.productDetails;

      debugPrint('Načteno ${_products.length} produktů:');
      for (final product in _products) {
        debugPrint('- ${product.id}: ${product.title} (${product.price})');
      }

      return _products;
    } catch (e) {
      debugPrint('Chyba při načítání produktů: $e');
      rethrow;
    }
  }

  /// Zahájí nákup Premium předplatného
  Future<void> buyPremium(ProductDetails productDetails) async {
    if (!_isInitialized) {
      throw Exception('error_payment_service_not_initialized'.tr());
    }

    try {
      debugPrint('Zahajuji nákup Premium: ${productDetails.id}');

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null,
      );

      // Pro předplatné používáme buyNonConsumable
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('Chyba při zahájení nákupu Premium: $e');
      rethrow;
    }
  }

  /// Dokončí nákup (acknowledge)
  ///
  /// DŮLEŽITÉ: Tuto metodu volat POUZE po úspěšném server-side ověření!
  /// Nevolat automaticky - řídí SubscriptionRepository.
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    try {
      if (purchaseDetails.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchaseDetails);
        debugPrint('Nákup ${purchaseDetails.productID} dokončen (acknowledged)');
      } else {
        debugPrint(
            'Nákup ${purchaseDetails.productID} již byl dokončen nebo nevyžaduje acknowledge');
      }
    } catch (e) {
      debugPrint('Chyba při dokončování nákupu: $e');
      rethrow;
    }
  }

  /// Otevře správu předplatného
  Future<void> openManageSubscriptions() async {
    try {
      if (Platform.isAndroid) {
        // Android: otevři Google Play Store správu předplatného
        final String packageName = Constants.packageName;

        // Správné URL pro správu předplatného na Google Play
        final Uri playStoreUri =
            Uri.parse('https://play.google.com/store/account/subscriptions');

        // Fallback - profil aplikace v Play Store
        final Uri appUri = Uri.parse(
            'https://play.google.com/store/apps/details?id=$packageName');

        bool launched = false;

        // Zkus otevřít správu předplatného
        if (await canLaunchUrl(playStoreUri)) {
          launched = await launchUrl(playStoreUri,
              mode: LaunchMode.externalApplication);
        }

        // Fallback na stránku aplikace
        if (!launched && await canLaunchUrl(appUri)) {
          launched =
              await launchUrl(appUri, mode: LaunchMode.externalApplication);
        }

        if (!launched) {
          throw Exception('error_cannot_open_manage_subscriptions'.tr());
        }
      } else if (Platform.isIOS) {
        // iOS: zobraz instrukce pro správu v Nastavení
        _showIOSSubscriptionInstructions();
      }
    } catch (e) {
      debugPrint('Chyba při otevírání správy předplatného: $e');
      rethrow;
    }
  }

  /// Zobrazí instrukce pro správu předplatného na iOS
  void _showIOSSubscriptionInstructions() {
    // Tuto metodu bude volat UI komponenta, která zobrazí dialog s instrukcemi
    // Instrukce: "Pro správu předplatného přejděte do Nastavení > [Vaše jméno] > Předplatná"
    debugPrint('Zobrazuji iOS instrukce pro správu předplatného');
  }

  /// Obnoví předchozí nákupy
  Future<void> restorePurchases() async {
    if (!_isInitialized) {
      throw Exception('PaymentService není inicializován');
    }

    try {
      debugPrint('Zahajuji obnovu nákupů...');
      await _inAppPurchase.restorePurchases();
      debugPrint('Obnova nákupů dokončena');
    } catch (e) {
      debugPrint('Chyba při obnově nákupů: $e');
      rethrow;
    }
  }

  /// Zpracování aktualizací nákupů
  ///
  /// ZMĚNA: Neporovádí automatické completePurchase!
  /// Pouze loguje stavy. CompletePurchase je zodpovědností SubscriptionRepository
  /// po úspěšném server-side ověření.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    debugPrint(
        'Zpracovávám ${purchaseDetailsList.length} nákupních aktualizací');

    for (final purchase in purchaseDetailsList) {
      debugPrint('Nákup ${purchase.productID}: ${purchase.status}'
          '${purchase.error != null ? ' - ${purchase.error}' : ''}');

      // ODSTRANĚNO: Automatické completePurchase
      // Nyní se completePurchase volá pouze z SubscriptionRepository
      // po úspěšném server-side ověření
      //
      // if (purchase.pendingCompletePurchase) {
      //   try {
      //     await completePurchase(purchase);
      //   } catch (e) {
      //     debugPrint('Chyba při automatickém dokončování nákupu: $e');
      //   }
      // }
    }
  }

  /// Získá Premium produkt z načtených produktů
  ProductDetails? getPremiumProduct() {
    final String productId = Platform.isAndroid
        ? Billing.productPremiumYearlyAndroid
        : Billing.productPremiumYearlyIOS;

    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      debugPrint('Premium produkt $productId není v cache');
      return null;
    }
  }

  /// Vrací informace o ceně Premium předplatného
  String get premiumPriceText {
    final product = getPremiumProduct();
    return product?.price ??
        '${Constants.premiumPriceYearly.toInt()} ${Constants.currencySymbol}';
  }

  /// Vrací název Premium předplatného
  String get premiumTitle {
    final product = getPremiumProduct();
    return product?.title ?? tr('subs.premium.title');
  }

  /// Vrací popis Premium předplatného
  String get premiumDescription {
    final product = getPremiumProduct();
    return product?.description ?? tr('subs.premium.description');
  }

  /// Vrací všechny načtené produkty
  List<ProductDetails> get availableProducts => List.unmodifiable(_products);

  /// Kontrola, zda je PaymentService inicializován
  bool get isInitialized => _isInitialized;

  /// Extrahuje cenu a měnu z ProductDetails
  ///
  /// [productDetails] - detaily produktu
  /// Vrací tuple (price, currency) nebo (0, 'CZK') pokud nelze extrahovat
  (double, String) extractPriceAndCurrency(ProductDetails productDetails) {
    // rawPrice je v měně produktu
    final double price = productDetails.rawPrice;
    final String currency = productDetails.currencyCode;

    debugPrint('Extracted price: $price $currency from ${productDetails.id}');

    return (price, currency);
  }

  /// Uvolní zdroje
  void dispose() {
    debugPrint('PaymentService dispose');
    _subscription.cancel();
    _purchaseStreamController.close();
    _isInitialized = false;
  }
}
