import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// PaymentService implementuje integraci plateb pomocí in-app nákupů.
/// Tato třída je vytvořena jako singleton a poskytuje metody pro inicializaci,
/// načtení produktů, zahájení nákupu a obnovu nákupů.
class PaymentService {
  // Singleton instance
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  // Instance InAppPurchase pluginu.
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Stream subscription pro nákupní aktualizace.
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Definice produktových ID, které nabízíte (např. předplatné, jednorázové nákupy).
  final Set<String> _productIds = <String>{
    'premium_subscription', // např. předplatné pro prémiový obsah
    'coin_pack_100',        // např. balíček virtuálních měn
  };

  // Interní seznam dostupných produktů.
  List<ProductDetails> _products = [];

  /// Inicializuje PaymentService.
  ///
  /// Nejprve se ověří, zda jsou in-app nákupy dostupné. Poté se nastaví posluchač
  /// nákupních aktualizací a načtou se produktová data.
  Future<void> initialize() async {
    // Kontrola dostupnosti in-app nákupů.
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      debugPrint("In-app purchases nejsou dostupné.");
      return;
    }

    // Nastavení posluchače pro nákupní aktualizace.
    _subscription = _inAppPurchase.purchaseStream.listen(
      _listenToPurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint("Chyba při nákupních aktualizacích: $error");
      },
    );

    // Načtení produktových dat z obchodu.
    final ProductDetailsResponse response =
        await _inAppPurchase.queryProductDetails(_productIds);
    if (response.error != null) {
      debugPrint("Chyba při získávání produktů: ${response.error}");
      return;
    }
    _products = response.productDetails;
    debugPrint("Produkty načteny: ${_products.map((p) => p.title).toList()}");
  }

  /// Vrací seznam dostupných produktů.
  List<ProductDetails> get products => _products;

  /// Zahájí nákup zvoleného produktu.
  ///
  /// U produktů, jejichž ID obsahuje "subscription", je volána metoda pro nepodporovatelné (non-consumable) nákupy.
  /// U ostatních produktů se předpokládá, že jde o konzumovatelné nákupy.
  Future<void> buyProduct(ProductDetails productDetails) async {
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

    if (productDetails.id.contains('subscription')) {
      // Pro nepodporovatelné nákupy (předplatné)
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } else {
      // Pro konzumovatelné produkty
      await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    }
  }

  /// Obnoví předchozí nákupy (např. při reinstalaci aplikace).
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  /// Interní metoda pro zpracování nákupních aktualizací.
  ///
  /// Projde všechny nákupní aktualizace, ošetří stavy pending, error, purchased a restored.
  /// Pokud je nákup označen jako pendingCompletePurchase, dokončí ho.
  void _listenToPurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint("Nákup čeká: ${purchaseDetails.productID}");
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint("Chyba při nákupu: ${purchaseDetails.error}");
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // V reálné aplikaci ověřte nákup, např. odesláním na server
          debugPrint("Nákup úspěšný: ${purchaseDetails.productID}");
        }
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Uvolní zdroje, zejména zruší stream subscription.
  void dispose() {
    _subscription?.cancel();
  }
}
