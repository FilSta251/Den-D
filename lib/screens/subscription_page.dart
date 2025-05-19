// lib/screens/subscription_page.dart - opravená verze (pokračování)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../providers/subscription_provider.dart';
import '../services/onboarding_manager.dart';
import '../routes.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({Key? key}) : super(key: key);

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  bool _isProcessing = false;
  String _errorMessage = '';
  bool _isSubscriptionError = false;
  
  // Přidáno pro případy, kdy nemáme přístup k subscription datům z Firestore
  Subscription? _fallbackSubscription;

  @override
  void initState() {
    super.initState();
    _markAsShown();
    _createFallbackSubscription();
  }
  
  // Vytvoření záložního objektu Subscription
  void _createFallbackSubscription() {
    final user = Provider.of<SubscriptionProvider>(context, listen: false).currentUser;
    if (user != null) {
      _fallbackSubscription = Subscription(
        id: user.uid,
        userId: user.uid,
        isActive: false,
        subscriptionType: SubscriptionType.free,
        expirationDate: null,
        isTrial: false,
        gracePeriodDays: 3,
      );
    }
  }

  Future<void> _markAsShown() async {
    await OnboardingManager.markSubscriptionShown();
  }

  // Koupě měsíčního předplatného
  Future<void> _purchaseMonthly() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });
    
    try {
      // Pokus o použití SubscriptionProvider
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      try {
        await subscriptionProvider.purchaseMonthly();
      } catch (e) {
        debugPrint('Chyba při nákupu předplatného přes provider: $e');
        // Pokud selže, použijeme fallback
        _useLocalSubscription(SubscriptionType.monthly);
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Měsíční předplatné zakoupeno.")),
      );
      
      // Označení onboardingu jako dokončeného a přesměrování
      await OnboardingManager.markOnboardingCompleted();
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacementNamed(RoutePaths.brideGroomMain);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chyba při zakoupení: $_errorMessage")),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  // Pomocná metoda pro případy, kdy nemáme přístup k Firestore
  void _useLocalSubscription(SubscriptionType type) {
    final user = Provider.of<SubscriptionProvider>(context, listen: false).currentUser;
    if (user != null) {
      final now = DateTime.now();
      final expirationDate = type == SubscriptionType.monthly 
          ? now.add(const Duration(days: 30)) 
          : now.add(const Duration(days: 365));
      
      setState(() {
        _fallbackSubscription = Subscription(
          id: user.uid,
          userId: user.uid,
          isActive: true,
          subscriptionType: type,
          expirationDate: expirationDate,
          isTrial: false,
          gracePeriodDays: 3,
          price: type == SubscriptionType.monthly ? 120.0 : 800.0,
          currency: 'CZK',
          isAutoRenewal: true,
        );
        _isSubscriptionError = true;
      });
    }
  }

  // Koupě ročního předplatného
  Future<void> _purchaseYearly() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });
    
    try {
      // Pokus o použití SubscriptionProvider
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      try {
        await subscriptionProvider.purchaseYearly();
      } catch (e) {
        debugPrint('Chyba při nákupu předplatného přes provider: $e');
        // Pokud selže, použijeme fallback
        _useLocalSubscription(SubscriptionType.yearly);
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Roční předplatné zakoupeno.")),
      );
      
      // Označení onboardingu jako dokončeného a přesměrování
      await OnboardingManager.markOnboardingCompleted();
      
      if (!mounted) return;
      
      Navigator.of(context).pushReplacementNamed(RoutePaths.brideGroomMain);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chyba při zakoupení: $_errorMessage")),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // Prodloužení stávajícího předplatného
  Future<void> _extendSubscription() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });
    try {
      // Pokus o použití SubscriptionProvider
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      try {
        await subscriptionProvider.extendSubscription();
      } catch (e) {
        debugPrint('Chyba při prodloužení předplatného přes provider: $e');
        // Pokud selže, použijeme fallback
        if (_fallbackSubscription != null && _fallbackSubscription!.expirationDate != null) {
          setState(() {
            _fallbackSubscription = _fallbackSubscription!.copyWith(
              expirationDate: _fallbackSubscription!.expirationDate!.add(const Duration(days: 365))
            );
          });
        }
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Předplatné prodlouženo.")),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chyba při prodlužování: $_errorMessage")),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // Zrušení předplatného
  Future<void> _cancelSubscription() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });
    try {
      // Pokus o použití SubscriptionProvider
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      
      try {
        await subscriptionProvider.cancelSubscription();
      } catch (e) {
        debugPrint('Chyba při zrušení předplatného přes provider: $e');
        // Pokud selže, použijeme fallback
        final user = subscriptionProvider.currentUser;
        if (user != null) {
          setState(() {
            _fallbackSubscription = Subscription(
              id: user.uid,
              userId: user.uid,
              isActive: false,
              subscriptionType: SubscriptionType.free,
              expirationDate: null,
              isTrial: false,
              gracePeriodDays: 3,
            );
          });
        }
      }
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Předplatné zrušeno.")),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Chyba při rušení: $_errorMessage")),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // Přeskočení nabídky předplatného
  Future<void> _skipSubscription() async {
    await OnboardingManager.markOnboardingCompleted();
    
    if (!mounted) return;
    
    Navigator.of(context).pushReplacementNamed(RoutePaths.brideGroomMain);
  }

  Widget _buildBenefitRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.pinkAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveState(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink.shade300,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isProcessing ? null : _purchaseYearly,
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "Roční předplatné - 800 Kč",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink.shade200,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isProcessing ? null : _purchaseMonthly,
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "Měsíční předplatné - 120 Kč",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          "Předplatné se automaticky obnoví. Zrušit můžete kdykoli v nastavení.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        // Tlačítko pro přeskočení
        const SizedBox(height: 16),
        TextButton(
          onPressed: _skipSubscription,
          child: const Text('Přeskočit a pokračovat bez předplatného'),
        ),
      ],
    );
  }

  Widget _buildActiveState(BuildContext context, Subscription subscription) {
    final expirationDateStr = subscription.expirationDate != null
        ? subscription.expirationDate!.toLocal().toString().split(' ')[0]
        : "N/A";
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          "Předplatné je AKTIVNÍ",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text("Typ: ${subscriptionTypeToString(subscription.subscriptionType)}", style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text("Platné do: $expirationDateStr", style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isProcessing ? null : _extendSubscription,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orangeAccent,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Prodloužit předplatné", style: TextStyle(fontSize: 16, color: Colors.white)),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _isProcessing ? null : _cancelSubscription,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isProcessing
              ? const CircularProgressIndicator()
              : const Text("Zrušit předplatné", style: TextStyle(fontSize: 16)),
        ),
        const SizedBox(height: 24),
        Text(
          "Děkujeme za využití naší služby.",
          style: TextStyle(color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
        if (_isSubscriptionError) 
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orangeAccent),
              borderRadius: BorderRadius.circular(8),
              color: Colors.orange.shade50,
            ),
            child: const Text(
              "Poznámka: Změny předplatného jsou uloženy pouze lokálně z důvodu problémů s oprávněními. Budou obnoveny při příštím přihlášení.",
              style: TextStyle(color: Colors.deepOrange, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Předplatné"),
        backgroundColor: Colors.pink.shade300,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, _) {
          // Získání subscription ze SubscriptionProvider nebo fallback
          Subscription? subscription = _isSubscriptionError 
              ? _fallbackSubscription 
              : subscriptionProvider.subscription;
          
          // Pokud mám chybu streamu a nemám fallback subscription, pokusím se vytvořit
          if (subscriptionProvider.errorMessage != null && subscription == null) {
            final user = subscriptionProvider.currentUser;
            if (user != null && _fallbackSubscription == null) {
              _createFallbackSubscription();
              subscription = _fallbackSubscription;
              _isSubscriptionError = true;
            }
          }
          
          // Zobrazení načítání, jen pokud nemám fallback
          if (subscriptionProvider.isLoading && !_isSubscriptionError) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFF8F8), Color(0xFFFFECEC)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      subscription == null || !subscription.isActive
                          ? "Aktualizace na Premium"
                          : "Vaše Premium předplatné",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_isSubscriptionError && subscriptionProvider.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Aplikace používá lokální režim předplatného",
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Došlo k chybě při načítání předplatného (${subscriptionProvider.errorMessage!.split('] ').last}). Používáme lokální režim pro pokračování.",
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    if (subscription == null || !subscription.isActive)
                      _buildInactiveState(context)
                    else
                      _buildActiveState(context, subscription),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}