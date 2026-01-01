/// lib/screens/subscription_page.dart
///
/// Sjednocená Subscription stránka pro iOS i Android.
/// Premium: Neomezené položky, bez reklam, prioritní podpora
/// Free: Max 3 položky na funkci
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../providers/subscription_provider.dart';
import '../repositories/subscription_repository.dart';
import '../services/payment_service.dart';
import '../services/onboarding_manager.dart';
import '../router/app_router.dart';
import '../routes.dart';

class SubscriptionPage extends StatefulWidget {
  final String source;

  const SubscriptionPage({
    super.key,
    this.source = 'unknown',
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isProcessing = false;
  bool _isVerifying = false;
  bool _isLoadingProducts = true;
  String _errorMessage = '';
  ProductDetails? _premiumProduct;
  bool _purchaseSuccess = false;
  String _selectedPlan = 'premium';
  String? _userId;

  StreamSubscription<PurchaseProcessingState>? _processingStateSubscription;

  @override
  void initState() {
    super.initState();
    _userId = fb.FirebaseAuth.instance.currentUser?.uid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logPaywallView();
      _checkExistingPremium();
      _setupActiveUser();
      _setupProcessingStateListener();

      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args?['showFreeOption'] == true) {
        setState(() => _selectedPlan = 'free');
      }
    });

    _loadProducts();
  }

  @override
  void dispose() {
    _processingStateSubscription?.cancel();
    super.dispose();
  }

  void _logPaywallView() {
    try {
      final repository =
          Provider.of<SubscriptionRepository>(context, listen: false);
      repository.logPaywallView(
          source: widget.source, screen: 'subscription_page');
    } catch (e) {
      debugPrint('[SubscriptionPage] Error logging paywall view: $e');
    }
  }

  void _setupActiveUser() {
    if (_userId != null) {
      try {
        final repository =
            Provider.of<SubscriptionRepository>(context, listen: false);
        repository.setActiveUser(_userId);
      } catch (e) {
        debugPrint('[SubscriptionPage] Error setting active user: $e');
      }
    }
  }

  void _setupProcessingStateListener() {
    try {
      final repository =
          Provider.of<SubscriptionRepository>(context, listen: false);

      _processingStateSubscription =
          repository.processingStateStream.listen((state) {
        if (!mounted) return;

        switch (state) {
          case PurchaseProcessingState.verifying:
            setState(() {
              _isVerifying = true;
              _isProcessing = true;
            });
            break;
          case PurchaseProcessingState.success:
            setState(() {
              _isVerifying = false;
              _isProcessing = false;
              _purchaseSuccess = true;
            });
            _handlePurchaseSuccess();
            break;
          case PurchaseProcessingState.error:
            setState(() {
              _isVerifying = false;
              _isProcessing = false;
              _errorMessage = tr('subs.error.verification_failed');
            });
            break;
          case PurchaseProcessingState.idle:
            setState(() {
              _isVerifying = false;
              _isProcessing = false;
            });
            break;
        }
      });
    } catch (e) {
      debugPrint('[SubscriptionPage] Error setting up processing listener: $e');
    }
  }

  Future<void> _handlePurchaseSuccess() async {
    await OnboardingManager.markSubscriptionShown(userId: _userId);
    await OnboardingManager.markOnboardingCompleted(userId: _userId);
  }

  Future<void> _checkExistingPremium() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    if (subscriptionProvider.isPremium) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('subs.already_premium.title'))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
              const SizedBox(height: 16),
              Text(tr('subs.already_premium.message'),
                  textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openManageSubscriptions();
              },
              child: Text(tr('subs.already_premium.manage')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  RoutePaths.brideGroomMain,
                  (route) => false,
                );
              },
              child: Text(tr('subs.already_premium.continue_app')),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RoutePaths.brideGroomMain,
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProducts = true;
      _errorMessage = '';
    });

    try {
      final paymentService =
          Provider.of<PaymentService>(context, listen: false);

      final products = await paymentService.loadProducts().timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw TimeoutException(tr('subs.error.loading_timeout')),
          );

      if (!mounted) return;

      if (products.isNotEmpty) {
        final premiumProduct = paymentService.getPremiumProduct();
        if (premiumProduct != null) {
          setState(() {
            _premiumProduct = premiumProduct;
            _isLoadingProducts = false;
          });
        } else {
          setState(() {
            _errorMessage = tr('subs.error.premium_not_found');
            _isLoadingProducts = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = tr('subs.error.no_products_found');
          _isLoadingProducts = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _errorMessage = tr('subs.error.loading_timeout');
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = tr('subs.error.loading_products');
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _purchasePremium() async {
    if (_premiumProduct == null) {
      setState(() => _errorMessage = tr('subs.error.product_unavailable'));
      return;
    }

    if (_userId == null) {
      setState(() => _errorMessage = tr('subs.error.not_logged_in'));
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      final repository =
          Provider.of<SubscriptionRepository>(context, listen: false);
      await repository.startPremiumPurchase(_userId!);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _continueWithFree() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    if (subscriptionProvider.isPremium) {
      final confirmed = await _showDowngradeWarningDialog();
      if (!confirmed) return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      await subscriptionProvider.setFreeTier();
      await OnboardingManager.markSubscriptionShown(userId: _userId);
      await OnboardingManager.markOnboardingCompleted(userId: _userId);

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RoutePaths.brideGroomMain,
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = tr('subs.error.free_activation_failed');
        _isProcessing = false;
      });
    }
  }

  Future<bool> _showDowngradeWarningDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(tr('subs.downgrade.blocked_title'))),
              ],
            ),
            content: Text(tr('subs.downgrade.blocked_message')),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    RoutePaths.brideGroomMain,
                    (route) => false,
                  );
                },
                child: Text(tr('subs.downgrade.back_to_app')),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  _openManageSubscriptions();
                },
                child: Text(tr('subs.downgrade.manage_subscription')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openManageSubscriptions() async {
    try {
      final paymentService =
          Provider.of<PaymentService>(context, listen: false);
      await paymentService.openManageSubscriptions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('subs.error.manage_failed')),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openTerms() async {
    final Uri url = Uri.parse('https://stastnyfoto.com/podminky-pouzivani/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      AppRouter.navigateToTerms(context);
    }
  }

  Future<void> _openPrivacy() async {
    final Uri url =
        Uri.parse('https://stastnyfoto.com/zasady_ochrany_osobnich_udaju/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      AppRouter.navigateToPrivacy(context);
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('subs.title')),
        backgroundColor: Colors.pink.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, _) {
          if (_purchaseSuccess) return _buildSuccessState();
          if (_isVerifying) return _buildVerifyingState();
          if (_errorMessage.isNotEmpty && !_isLoadingProducts)
            return _buildErrorState();
          if (_isLoadingProducts) return _buildLoadingState();
          return _buildMainContent();
        },
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Premium benefits box
              _buildPremiumBenefitsBox(),
              const SizedBox(height: 20),

              // Plan cards
              _buildPlanCards(),
              const SizedBox(height: 24),

              // CTA button
              _buildActionButton(),
              const SizedBox(height: 12),

              // Auto-renewal text
              Text(
                tr('subs.renewal.auto'),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Footer links
              _buildFooterLinks(),
            ],
          ),
        ),
      ),
    );
  }

  /// Premium benefits box - AKTUALIZOVANÉ BENEFITY
  Widget _buildPremiumBenefitsBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.pink.shade600, size: 22),
              const SizedBox(width: 8),
              Text(
                tr('subs.premium.title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.pink.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Neomezený počet položek
          _buildBenefitRow(
              Icons.all_inclusive, tr('subs.features.unlimited_items')),
          const SizedBox(height: 8),
          // Prioritní podpora
          _buildBenefitRow(
              Icons.support_agent, tr('subs.features.priority_support')),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
          ),
        ),
        Icon(Icons.check_circle, size: 20, color: Colors.green.shade600),
      ],
    );
  }

  /// Plan cards - Free a Premium
  Widget _buildPlanCards() {
    return Row(
      children: [
        // Free card
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPlan = 'free'),
            child: _buildPlanCard(
              title: tr('subs.free.title'),
              subtitle: tr('subs.free.subtitle'),
              price: tr('subs.free.price'),
              isSelected: _selectedPlan == 'free',
              isPremium: false,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Premium card
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPlan = 'premium'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _buildPlanCard(
                  title: tr('subs.premium.title'),
                  subtitle: tr('subs.premium.subtitle'),
                  price: _premiumProduct?.price ?? tr('subs.loading.price'),
                  priceSubtext: tr('subs.premium.per_year'),
                  isSelected: _selectedPlan == 'premium',
                  isPremium: true,
                ),
                // Badge
                Positioned(
                  top: -10,
                  right: -5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr('subs.premium.badge'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String price,
    String? priceSubtext,
    required bool isSelected,
    required bool isPremium,
  }) {
    final Color bgColor = isPremium
        ? (isSelected ? Colors.pink.shade100 : Colors.pink.shade50)
        : (isSelected ? Colors.grey.shade200 : Colors.grey.shade100);

    final Color borderColor = isSelected
        ? (isPremium ? Colors.pink.shade400 : Colors.grey.shade500)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color:
                      (isPremium ? Colors.pink : Colors.grey).withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isPremium ? Colors.pink.shade700 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Text(
            price,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isPremium ? 22 : 18,
              color: isPremium ? Colors.pink.shade700 : Colors.grey.shade800,
            ),
          ),
          if (priceSubtext != null) ...[
            const SizedBox(height: 2),
            Text(
              priceSubtext,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final bool isPremiumSelected = _selectedPlan == 'premium';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isPremiumSelected ? Colors.pink.shade600 : Colors.grey.shade600,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          elevation: 4,
        ),
        onPressed: _isProcessing
            ? null
            : (isPremiumSelected ? _purchasePremium : _continueWithFree),
        child: _isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                isPremiumSelected
                    ? tr('subs.cta.unlock')
                    : tr('subs.free.continue_button'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        GestureDetector(
          onTap: _openTerms,
          child: Text(
            tr('subs.links.terms'),
            style: TextStyle(
              color: Colors.pink.shade600,
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        GestureDetector(
          onTap: _openPrivacy,
          child: Text(
            tr('subs.links.privacy'),
            style: TextStyle(
              color: Colors.pink.shade600,
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        GestureDetector(
          onTap: _openManageSubscriptions,
          child: Text(
            tr('subs.links.manage'),
            style: TextStyle(
              color: Colors.pink.shade600,
              fontSize: 13,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // State widgets
  // ============================================================

  Widget _buildSuccessState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle, size: 80, color: Colors.green[600]),
          ),
          const SizedBox(height: 24),
          Text(
            tr('subs.success.title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            tr('subs.success.message'),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil(
                RoutePaths.brideGroomMain,
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: Text(tr('subs.success.continue')),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              tr('subs.loading.products'),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyingState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            tr('subs.verifying.title'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            tr('subs.verifying.message'),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink.shade50, Colors.white],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.red.shade700),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadProducts,
                icon: const Icon(Icons.refresh),
                label: Text(tr('subs.error.retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _continueWithFree,
                child: Text(tr('subs.error.continue_free')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
