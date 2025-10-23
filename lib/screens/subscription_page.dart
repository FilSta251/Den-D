/// lib/screens/subscription_page.dart původní

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../providers/subscription_provider.dart';
import '../services/payment_service.dart';
import '../services/onboarding_manager.dart';
import '../router/app_router.dart';
import '../routes.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({Key? key}) : super(key: key);

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isProcessing = false;
  String _errorMessage = '';
  ProductDetails? _premiumProduct;
  bool _purchaseSuccess = false;
  String _selectedPlan = 'premium';
  String? _userId;
  @override
  void initState() {
    super.initState();

    // Získání userId
    _userId = fb.FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[SubscriptionPage] User ID: $_userId');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Kontrola zda už má uživatel premium
      _checkExistingPremium();

      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args?['showFreeOption'] == true) {
        setState(() {
          _selectedPlan = 'free';
        });
      }
    });

    _loadProducts();
  }

  Future<void> _checkExistingPremium() async {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    // Pokud už má premium, zobraz dialog a vrať ho zpět
    if (subscriptionProvider.isPremium) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700, size: 28),
              const SizedBox(width: 8),
              Text(tr('subs.already_premium.title')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                tr('subs.already_premium.message'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                tr('subs.already_premium.info'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
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

      // Po zavření dialogu přejdi zpět do aplikace
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RoutePaths.brideGroomMain,
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      final paymentService =
          Provider.of<PaymentService>(context, listen: false);
      final products = await paymentService.loadProducts();

      if (products.isNotEmpty) {
        setState(() {
          _premiumProduct = paymentService.getPremiumProduct();
        });
      }
    } catch (e) {
      debugPrint('Chyba při načítání produktů: $e');
      setState(() {
        _errorMessage = tr('subs.error.loading_products');
      });
    }
  }

  Future<void> _purchasePremium() async {
    if (_premiumProduct == null) {
      setState(() {
        _errorMessage = tr('subs.error.product_unavailable');
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    try {
      final paymentService =
          Provider.of<PaymentService>(context, listen: false);
      await paymentService.buyPremium(_premiumProduct!);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subs.error.purchase_failed')),
          backgroundColor: Colors.red,
        ),
      );
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

      // Označení onboardingu jako dokončeného
      debugPrint('[SubscriptionPage] Marking subscription as shown (FREE)');
      await OnboardingManager.markSubscriptionShown(userId: _userId);
      await OnboardingManager.markOnboardingCompleted(userId: _userId);
      debugPrint('[SubscriptionPage] Onboarding completed for user: $_userId');

      Navigator.of(context).pushNamedAndRemoveUntil(
        RoutePaths.brideGroomMain,
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = tr('subs.error.free_activation_failed');
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subs.error.free_activation_failed')),
          backgroundColor: Colors.red,
        ),
      );
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.block,
                  color: Colors.red.shade400,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('subs.downgrade.blocked_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(height: 8),
                      Text(
                        tr('subs.downgrade.how_to_cancel'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('subs.error.manage_failed')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openTerms() async {
    final Uri url = Uri.parse('https://stastnyfoto.com/podminky-pouzivani/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      AppRouter.navigateToTerms(context);
    }
  }

  Future<void> _openPrivacy() async {
    final Uri url =
        Uri.parse('https://stastnyfoto.com/zasady_ochrany_osobnich_udaju/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      AppRouter.navigateToPrivacy(context);
    }
  }

  Widget _buildSuccessState() {
    return Container(
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
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green[600],
            ),
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

  Widget _buildBenefitRow({
    required IconData icon,
    required String text,
    bool isPremium = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: isPremium ? Colors.pink : Colors.grey, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isPremium ? Colors.black87 : Colors.grey[600],
                decoration: isPremium
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
            ),
          ),
          Icon(
            isPremium ? Icons.check_circle : Icons.cancel,
            color: isPremium ? Colors.green.shade600 : Colors.red.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('subs.comparison.title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Free verze - zvýrazněné omezení
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      tr('subs.comparison.free_title'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBenefitRow(
                  icon: Icons.lock_outline,
                  text: tr('subs.free.limited_features'),
                  isPremium: false,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Premium verze - zelené zvýraznění
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.pink, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBenefitRow(
                  icon: Icons.all_inclusive,
                  text: tr('subs.premium.unlimited_functions'),
                ),
                _buildBenefitRow(
                  icon: Icons.block,
                  text: tr('subs.premium.no_ads'),
                ),
                _buildBenefitRow(
                  icon: Icons.cloud_sync,
                  text: tr('subs.premium.cloud_sync'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final hasActivePremium = subscriptionProvider.isPremium;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: hasActivePremium ? 0.5 : 1.0,
              child: _buildPlanCard(
                title: tr('subs.plan.free_title'),
                subtitle: tr('subs.plan.free_subtitle'),
                price: tr('subs.plan.free_price'),
                period: tr('subs.plan.free_period'),
                isSelected: _selectedPlan == 'free',
                onTap: hasActivePremium
                    ? () => _showActivePremiumWarning()
                    : () => setState(() => _selectedPlan = 'free'),
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade400],
                ),
                showYearlyBadge: false,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildPlanCard(
              title: tr('subs.plan.premium_title'),
              subtitle: tr('subs.plan.premium_subtitle'),
              price: _premiumProduct?.price ?? tr('subs.plan.premium_price'),
              period: tr('subs.plan.premium_period'),
              isSelected: _selectedPlan == 'premium',
              onTap: () => setState(() => _selectedPlan = 'premium'),
              gradient: LinearGradient(
                colors: [Colors.pink.shade400, Colors.pink.shade600],
              ),
              showYearlyBadge: true,
            ),
          ),
        ],
      ),
    );
  }

  void _showActivePremiumWarning() {
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final expiresAt = subscriptionProvider.subscription?.expiresAt;
    final daysLeft = subscriptionProvider.subscription?.daysLeft ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('subs.active.title'),
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('subs.active.message'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.pink, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Premium',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.pink.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (expiresAt != null) ...[
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          '${tr('subs.active.expires')}: ${DateFormat('dd.MM.yyyy').format(expiresAt)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          '${tr('subs.active.days_left')}: $daysLeft ${daysLeft == 1 ? tr('subs.active.day') : tr('subs.active.days')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              tr('subs.active.ok'),
              style: TextStyle(
                color: Colors.green.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required bool isSelected,
    required VoidCallback onTap,
    required LinearGradient gradient,
    required bool showYearlyBadge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.pink.shade300.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showYearlyBadge)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tr('subs.badge.yearly'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (showYearlyBadge)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  period,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                period,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            if (isSelected)
              const Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_selectedPlan == 'free') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[600],
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 2,
          ),
          onPressed: _isProcessing ? null : _continueWithFree,
          child: _isProcessing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  tr('subs.free.continue_button'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      );
    } else {
      return SizedBox(
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
          ),
          onPressed: _isProcessing ? null : _purchasePremium,
          child: _isProcessing
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  tr('subs.cta.unlock'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('subs.title')),
        backgroundColor: Colors.pink.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<SubscriptionProvider, PaymentService>(
        builder: (context, subscriptionProvider, paymentService, _) {
          return StreamBuilder<List<PurchaseDetails>>(
            stream: paymentService.purchaseStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final purchases = snapshot.data!;
                final successfulPurchase = purchases.any((p) =>
                    p.status == PurchaseStatus.purchased ||
                    p.status == PurchaseStatus.restored);

                if (successfulPurchase && !_purchaseSuccess) {
                  // Označení nákupu jako úspěšného a dokončení onboardingu
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    setState(() {
                      _purchaseSuccess = true;
                      _isProcessing = false;
                    });

                    // Označení onboardingu jako dokončeného
                    debugPrint(
                        '[SubscriptionPage] Marking subscription as shown (PREMIUM)');
                    await OnboardingManager.markSubscriptionShown(
                        userId: _userId);
                    await OnboardingManager.markOnboardingCompleted(
                        userId: _userId);
                    debugPrint(
                        '[SubscriptionPage] Onboarding completed for user: $_userId');
                  });
                }
              }

              if (_purchaseSuccess) {
                return _buildSuccessState();
              }

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          tr('subs.header.title'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('subs.header.subtitle'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (_premiumProduct == null && _errorMessage.isEmpty)
                          Center(
                            child: Column(
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(tr('subs.loading.products')),
                              ],
                            ),
                          )
                        else ...[
                          _buildFeatureComparison(),
                          const SizedBox(height: 24),
                          _buildPlanSelector(),
                          const SizedBox(height: 24),
                          _buildActionButton(),
                          const SizedBox(height: 16),
                          if (_selectedPlan == 'premium')
                            Text(
                              tr('subs.premium.auto_renewal'),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: _openTerms,
                                child: Text(
                                  tr('subs.links.terms'),
                                  style: TextStyle(
                                    color: Colors.pink.shade600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Container(
                                height: 20,
                                width: 1,
                                color: Colors.grey.shade400,
                              ),
                              TextButton(
                                onPressed: _openPrivacy,
                                child: Text(
                                  tr('subs.links.privacy'),
                                  style: TextStyle(
                                    color: Colors.pink.shade600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              Container(
                                height: 20,
                                width: 1,
                                color: Colors.grey.shade400,
                              ),
                              TextButton(
                                onPressed: _openManageSubscriptions,
                                child: Text(
                                  tr('subs.links.manage'),
                                  style: TextStyle(
                                    color: Colors.pink.shade600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
