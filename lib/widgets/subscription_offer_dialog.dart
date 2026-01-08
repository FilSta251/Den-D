/// lib/widgets/subscription_offer_dialog.dart
///
/// Univerzální paywall dialog pro nabídku Premium předplatného.
/// OPRAVENO: Používá SubscriptionRepository místo přímého PaymentService
/// a naslouchá na processingStateStream pro správnou aktualizaci UI.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../services/payment_service.dart';
import '../repositories/subscription_repository.dart';
import '../router/app_router.dart';
import '../utils/constants.dart';

/// Univerzální paywall dialog pro nabídku Premium předplatného
///
/// Volá se při dosažení free limitu - umožňuje přímý nákup v dialogu
class SubscriptionOfferDialog extends StatefulWidget {
  final String? priceText;
  final String? source;

  const SubscriptionOfferDialog({super.key, this.priceText, this.source});

  static Future<bool?> show(
    BuildContext context, {
    String? priceText,
    String? source,
  }) {
    // 🔴 DOČASNĚ: Když je subscription disabled, nezobrazujeme paywall
    if (!Billing.subscriptionEnabled) {
      debugPrint('[SubscriptionOfferDialog] Subscription disabled - skipping paywall');
      return Future.value(true); // Vrátíme true jako by měl Premium
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          SubscriptionOfferDialog(priceText: priceText, source: source),
    );
  }

  @override
  State<SubscriptionOfferDialog> createState() =>
      _SubscriptionOfferDialogState();
}

class _SubscriptionOfferDialogState extends State<SubscriptionOfferDialog> {
  bool _isProcessing = false;
  bool _isVerifying = false;
  bool _purchaseSuccess = false;
  String? _errorMessage;
  ProductDetails? _premiumProduct;
  String? _userId;

  // Stream subscription pro sledování stavu nákupu
  StreamSubscription<PurchaseProcessingState>? _processingStateSubscription;

  @override
  void initState() {
    super.initState();
    _userId = fb.FirebaseAuth.instance.currentUser?.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupActiveUser();
      _setupProcessingStateListener();
      _logPaywallView();
    });

    _loadProduct();
  }

  @override
  void dispose() {
    _processingStateSubscription?.cancel();
    super.dispose();
  }

  /// Nastaví aktivního uživatele v repository
  void _setupActiveUser() {
    if (_userId != null) {
      try {
        final repository = Provider.of<SubscriptionRepository>(
          context,
          listen: false,
        );
        repository.setActiveUser(_userId);
      } catch (e) {
        debugPrint('[SubscriptionOfferDialog] Error setting active user: $e');
      }
    }
  }

  /// Nastaví listener pro sledování stavu zpracování nákupu
  void _setupProcessingStateListener() {
    try {
      final repository = Provider.of<SubscriptionRepository>(
        context,
        listen: false,
      );

      _processingStateSubscription = repository.processingStateStream.listen((
        state,
      ) {
        if (!mounted) return;

        debugPrint('[SubscriptionOfferDialog] Processing state: $state');

        switch (state) {
          case PurchaseProcessingState.verifying:
            setState(() {
              _isVerifying = true;
              _isProcessing = true;
              _errorMessage = null;
            });
            break;

          case PurchaseProcessingState.success:
            setState(() {
              _isVerifying = false;
              _isProcessing = false;
              _purchaseSuccess = true;
            });
            // Zavřít dialog s úspěchem po krátké prodlevě
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            });
            break;

          case PurchaseProcessingState.error:
            setState(() {
              _isVerifying = false;
              _isProcessing = false;
              _errorMessage = tr('subs.error.verification_failed');
            });
            break;

          case PurchaseProcessingState.idle:
            // Pokud jsme byli ve stavu processing a nyní idle (např. zrušeno)
            if (_isProcessing && !_purchaseSuccess) {
              setState(() {
                _isVerifying = false;
                _isProcessing = false;
              });
            }
            break;
        }
      });
    } catch (e) {
      debugPrint(
        '[SubscriptionOfferDialog] Error setting up processing listener: $e',
      );
    }
  }

  /// Loguje zobrazení paywallu
  void _logPaywallView() {
    try {
      final repository = Provider.of<SubscriptionRepository>(
        context,
        listen: false,
      );
      repository.logPaywallView(
        source: widget.source ?? 'limit_reached',
        screen: 'subscription_offer_dialog',
      );
    } catch (e) {
      debugPrint('[SubscriptionOfferDialog] Error logging paywall view: $e');
    }
  }

  /// Načte Premium produkt z obchodu
  Future<void> _loadProduct() async {
    try {
      final paymentService = Provider.of<PaymentService>(
        context,
        listen: false,
      );
      final products = await paymentService.loadProducts();

      if (products.isNotEmpty && mounted) {
        setState(() {
          _premiumProduct = paymentService.getPremiumProduct();
        });
      }
    } catch (e) {
      debugPrint('[SubscriptionOfferDialog] Error loading product: $e');
      if (mounted) {
        setState(() {
          _errorMessage = tr('subs.error.loading_products');
        });
      }
    }
  }

  /// Zahájí nákup Premium přes SubscriptionRepository
  Future<void> _purchasePremium() async {
    if (_premiumProduct == null) {
      setState(() {
        _errorMessage = tr('subs.error.product_unavailable');
      });
      return;
    }

    if (_userId == null) {
      setState(() {
        _errorMessage = tr('subs.error.not_logged_in');
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // OPRAVENO: Použití SubscriptionRepository místo přímého PaymentService
      final repository = Provider.of<SubscriptionRepository>(
        context,
        listen: false,
      );

      debugPrint(
        '[SubscriptionOfferDialog] Starting purchase for user: $_userId',
      );

      await repository.startPremiumPurchase(_userId!);

      // Poznámka: Výsledek nákupu přijde přes processingStateStream
      // UI se aktualizuje automaticky v _setupProcessingStateListener
    } catch (e) {
      debugPrint('[SubscriptionOfferDialog] Purchase error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = tr('subs.error.purchase_failed');
          _isProcessing = false;
        });
      }
    }
  }

  /// Zavře dialog bez nákupu
  void _continueWithFree() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.pink.shade50],
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    // Zobrazení úspěchu
    if (_purchaseSuccess) {
      return _buildSuccessContent();
    }

    // Zobrazení verifikace
    if (_isVerifying) {
      return _buildVerifyingContent();
    }

    // Hlavní obsah
    return _buildMainContent();
  }

  /// Obsah při úspěšném nákupu
  Widget _buildSuccessContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          tr('subs.success.title'),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          tr('subs.success.message'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  /// Obsah při verifikaci nákupu
  Widget _buildVerifyingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          tr('subs.verifying.title'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          tr('subs.verifying.message'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  /// Hlavní obsah dialogu
  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ikona omezení
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock, size: 48, color: Colors.red.shade600),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '3/3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nadpis
          Text(
            tr('subs.limit.title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Popis
          Text(
            tr('subs.limit.message'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Výhody Premium - pouze 2 hlavní funkce
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.pink.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.pink, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('subs.premium.benefits_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Neomezený počet položek
                _buildFeatureRow(
                  Icons.all_inclusive,
                  tr('subs.features.unlimited_items'),
                ),
                const SizedBox(height: 6),
                // Prioritní podpora
                _buildFeatureRow(
                  Icons.support_agent,
                  tr('subs.features.priority_support'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cena ročního předplatného
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.pink.shade400, Colors.pink.shade600],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.shade300.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  tr('subs.premium.yearly'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.priceText ??
                      _premiumProduct?.price ??
                      tr('subs.loading.price'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tr('subs.premium.only_yearly'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tlačítko pro nákup
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 4,
                disabledBackgroundColor: Colors.pink.shade300,
              ),
              onPressed: (_isProcessing || _premiumProduct == null)
                  ? null
                  : _purchasePremium,
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      tr('subs.cta.unlock_premium'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Tlačítko Zrušit
          TextButton(
            onPressed: _isProcessing ? null : _continueWithFree,
            child: Text(
              tr('subs.paywall.maybe_later'),
              style: TextStyle(
                color: _isProcessing
                    ? Colors.grey.shade400
                    : Colors.grey.shade700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Text(
            tr('subs.premium.auto_renewal'),
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Odkazy na podmínky a zásady
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              GestureDetector(
                onTap: _isProcessing
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        AppRouter.navigateToTerms(context);
                      },
                child: Text(
                  tr('subs.links.terms'),
                  style: TextStyle(
                    color: _isProcessing
                        ? Colors.grey.shade400
                        : Colors.pink.shade600,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(
                '•',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
              GestureDetector(
                onTap: _isProcessing
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        AppRouter.navigateToPrivacy(context);
                      },
                child: Text(
                  tr('subs.links.privacy'),
                  style: TextStyle(
                    color: _isProcessing
                        ? Colors.grey.shade400
                        : Colors.pink.shade600,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.pink.shade700),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        Icon(Icons.check_circle, size: 16, color: Colors.green.shade600),
      ],
    );
  }
}
