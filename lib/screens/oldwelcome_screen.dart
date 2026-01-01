import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/onboarding_manager.dart';

/// WelcomeScreen představuje uvítací obrazovku s onboarding slidy.
/// Obsahuje 3 slidy představující funkce aplikace a finální stránku s navigáčními tláčítky.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;

  // Seznam stránek onboardingu
  List<Widget> get _pages => [
        _OnboardingPage(
          imageAsset: 'assets/images/onboarding1.png',
          title: tr('onboarding_title_1'),
          description: tr('onboarding_desc_1'),
        ),
        _OnboardingPage(
          imageAsset: 'assets/images/onboarding2.png',
          title: tr('onboarding_title_2'),
          description: tr('onboarding_desc_2'),
        ),
        _OnboardingPage(
          imageAsset: 'assets/images/onboarding3.png',
          title: tr('onboarding_title_3'),
          description: tr('onboarding_desc_3'),
        ),
        _FinalWelcomePage(),
      ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkOnboardingStatus();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeIn,
      ),
    );
    _animationController!.forward();
  }

  /// Kontrola stavu onboardingu - pokud uť uťivatel proĹˇel některými částmi,
  /// přesměrujeme ho na správnĂ© místo
  Future<void> _checkOnboardingStatus() async {
    try {
      // Kontrola, zda uť je uťivatel přihláĹˇený a dokončil některĂ© části
      final chatbotCompleted = await OnboardingManager.isChatbotCompleted();
      final subscriptionShown = await OnboardingManager.isSubscriptionShown();
      final onboardingCompleted =
          await OnboardingManager.isOnboardingCompleted();

      // Pokud uť je vĹˇe dokončeno, přejít na hlavní aplikaci
      if (onboardingCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/brideGroomMain');
        });
        return;
      }

      // Pokud uť viděl subscription, přejít na hlavní aplikaci
      if (subscriptionShown) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/brideGroomMain');
        });
        return;
      }

      // Pokud dokončil chatbot, přejít na subscription
      if (chatbotCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/subscription');
        });
        return;
      }

      // Jinak zůstat na welcome screen
    } catch (e) {
      debugPrint('Chyba při kontrole onboarding statusu: $e');
      // V případě chyby zůstaneme na welcome screen
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// Přejde na dalĹˇí stránku
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Přeskočí welcome slides a jde rovnou na registraci
  void _skipToAuth() {
    Navigator.pushReplacementNamed(context, '/auth');
  }

  /// Naviguje na registraci/přihláĹˇení po dokončení welcome
  void _navigateToAuth() {
    Navigator.pushReplacementNamed(context, '/auth');
  }

  /// Naviguje na přihláĹˇení pro existující uťivatele
  void _navigateToLogin() {
    Navigator.pushNamed(context, '/login');
  }

  /// Indikátor aktuální stránky
  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.pink : Colors.grey,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation!,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // AppBar s Skip tláčítkem
                if (!isLastPage)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48), // Spacing pro vycentrování
                        Text(
                          tr('welcome_title'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: _skipToAuth,
                          child: Text(
                            tr('skip'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Obsah stránek
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    itemBuilder: (context, index) => _pages[index],
                  ),
                ),

                // Indikátor stránek
                if (!isLastPage) _buildPageIndicator(),

                const SizedBox(height: 16),

                // Navigáční tláčítka
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: isLastPage
                      ? _buildFinalPageButtons()
                      : _buildNavigationButton(),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return ElevatedButton(
      onPressed: _nextPage,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF2575FC),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        tr('next'),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFinalPageButtons() {
    return Column(
      children: [
        // Hlavní tláčítko - Záčít
        ElevatedButton(
          onPressed: _navigateToAuth,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF2575FC),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            tr('start'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Odkaz pro existující uťivatele
        TextButton(
          onPressed: _navigateToLogin,
          child: Text(
            tr('already_have_account_login'),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// Jednotlivá stránka onboardingu s obrázkem, titulkem a popisem
class _OnboardingPage extends StatelessWidget {
  final String imageAsset;
  final String title;
  final String description;

  const _OnboardingPage({
    super.key,
    required this.imageAsset,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Obrázek s fallback
          Container(
            height: size.height * 0.3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              imageAsset,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: size.height * 0.3,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.image,
                    size: 80,
                    color: Colors.white54,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Finální stránka s welcome zprávou a tláčítky
class _FinalWelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo aplikace
          SizedBox(
            height: size.height * 0.25,
            child: Image.asset(
              'assets/images/welcome_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 80,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          Text(
            tr('welcome_title'),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          Text(
            tr('welcome_description'),
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Dodatečný popis pro motivaci
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tr('welcome_motivation_text'),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
