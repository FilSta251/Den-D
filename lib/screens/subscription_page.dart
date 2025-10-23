/// lib/screens/subscription_page.dart - AKTUALIZOVANÁ VERZE S ONBOARDING

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb; // ← PŘIDÁNO

import '../models/subscription.dart';
import '../providers/subscription_provider.dart';
import '../services/payment_service.dart';
import '../services/onboarding_manager.dart'; // ← PŘIDÁNO
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
  String? _userId; // ← PŘIDÁNO

  @override
  void initState() {
    super.initState();

    // ===== PŘIDÁNO: Získání userId =====
    _userId = fb.FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[SubscriptionPage] User ID: $_userId');
    // ==================================

    WidgetsBinding.instance.addPostFrameCallback((_) {
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

      // Po úspěšném nákupu označíme onboarding jako dokončený
      // (Volá se automaticky v StreamBuilder při detekci úspěšného nákupu)
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

      // ===== PŘIDÁNO: Označení onboardingu jako dokončeného =====
      debugPrint('[SubscriptionPage] Marking subscription as shown (FREE)');
      await OnboardingManager.markSubscriptionShown(userId: _userId);
      await OnboardingManager.markOnboardingCompleted(userId: _userId);
      debugPrint('[SubscriptionPage] Onboarding completed for user: $_userId');
      // =========================================================

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
            title: Text(tr('subs.downgrade.warning_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  tr('subs.downgrade.warning_message'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('subs.downgrade.features_lost'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr('subs.downgrade.keep_premium')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(tr('subs.downgrade.confirm_downgrade')),
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

  // ===== PŘIDÁNO: Handler po úspěšném nákupu =====
  Future<void> _handlePurchaseSuccess() async {
    debugPrint(
        '[SubscriptionPage] Purchase successful, marking onboarding complete');

    try {
      await OnboardingManager.markSubscriptionShown(userId: _userId);
      await OnboardingManager.markOnboardingCompleted(userId: _userId);
      debugPrint('[SubscriptionPage] Onboarding completed for user: $_userId');

      // Počkáme chvíli a pak přejdeme na hlavní obrazovku
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RoutePaths.brideGroomMain,
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('[SubscriptionPage] Error marking onboarding complete: $e');
    }
  }
  // =============================================

  Widget _buildSuccessState() {
    // ===== PŘIDÁNO: Automatické volání po zobrazení success =====
    if (_purchaseSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePurchaseSuccess();
      });
    }
    // ===========================================================

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
              Icons.check_circle_outline,
              size: 100,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('subs.success.title'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            tr('subs.success.message'),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(), // Zobrazí loading dokud se neukončí onboarding
          const SizedBox(height: 16),
          Text(
            tr('subs.success.redirecting'),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFeatureRow(
              icon: Icons.check_circle,
              title: tr('subs.features.basic_features'),
              free: true,
              premium: true,
            ),
            _buildFeatureRow(
              icon: Icons.people_outline,
              title: tr('subs.features.unlimited_guests'),
              free: false,
              premium: true,
            ),
            _buildFeatureRow(
              icon: Icons.budget,
              title: tr('subs.features.budget_tracking'),
              free: false,
              premium: true,
            ),
            _buildFeatureRow(
              icon: Icons.table_chart_outlined,
              title: tr('subs.features.seating_chart'),
              free: false,
              premium: true,
            ),
            _buildFeatureRow(
              icon: Icons.cloud_upload_outlined,
              title: tr('subs.features.cloud_sync'),
              free: false,
              premium: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required bool free,
    required bool premium,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.pink.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Icon(
                free ? Icons.check : Icons.close,
                color: free ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Center(
              child: Icon(
                premium ? Icons.check : Icons.close,
                color: premium ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildPlanOption(
            title: tr('subs.free.title'),
            price: tr('subs.free.price'),
            description: tr('subs.free.description'),
            value: 'free',
            backgroundColor: Colors.grey.shade100,
          ),
          const Divider(height: 1),
          _buildPlanOption(
            title: tr('subs.premium.title'),
            price: _premiumProduct != null
                ? _premiumProduct!.price
                : tr('subs.loading.price'),
            description: tr('subs.premium.description'),
            value: 'premium',
            backgroundColor: Colors.pink.shade50,
            recommended: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required String title,
    required String price,
    required String description,
    required String value,
    required Color backgroundColor,
    bool recommended = false,
  }) {
    final isSelected = _selectedPlan == value;
    return InkWell(
      onTap: () => setState(() => _selectedPlan = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? backgroundColor.withOpacity(0.3) : backgroundColor,
          border: isSelected
              ? Border.all(color: Colors.pink.shade600, width: 2)
              : null,
          borderRadius: value == 'free'
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : const BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedPlan,
              onChanged: (val) => setState(() => _selectedPlan = val!),
              activeColor: Colors.pink.shade600,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            tr('subs.premium.recommended'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
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
            backgroundColor: Colors.grey.shade700,
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
                  setState(() {
                    _purchaseSuccess = true;
                    _isProcessing = false;
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
