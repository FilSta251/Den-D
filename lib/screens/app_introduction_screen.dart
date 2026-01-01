/// lib/screens/app_introduction_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'chatbot_screen.dart';
import '../services/onboarding_manager.dart';

class IntroductionPage {
  final String title;
  final String description;
  final String imageAsset;

  IntroductionPage({
    required this.title,
    required this.description,
    required this.imageAsset,
  });
}

class AppIntroductionScreen extends StatefulWidget {
  const AppIntroductionScreen({super.key});

  @override
  _AppIntroductionScreenState createState() => _AppIntroductionScreenState();
}

class _AppIntroductionScreenState extends State<AppIntroductionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;
  bool _isInitialized = false;
  String? _userId;

  late final List<IntroductionPage> _pages = [
    IntroductionPage(
      title: tr('onboarding_title_1'),
      description: tr('onboarding_desc_1'),
      imageAsset: 'assets/images/onboarding1.png',
    ),
    IntroductionPage(
      title: tr('onboarding_title_2'),
      description: tr('onboarding_desc_2'),
      imageAsset: 'assets/images/onboarding2.png',
    ),
    IntroductionPage(
      title: tr('onboarding_title_3'),
      description: tr('onboarding_desc_3'),
      imageAsset: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeOnboarding();
  }

  /// Inicializace - získání userId a migrace dat
  Future<void> _initializeOnboarding() async {
    if (_isInitialized) return;

    try {
      // Získání aktuálního userId
      final currentUser = fb.FirebaseAuth.instance.currentUser;
      _userId = currentUser?.uid;

      if (_userId != null) {
        debugPrint('[AppIntroScreen] User ID: $_userId');

        // Migrace existujících lokálních dat do Firestore
        await OnboardingManager.migrateToFirestore(_userId!);

        // Synchronizace s Firestore
        await OnboardingManager.syncWithFirestore(_userId!);
      } else {
        debugPrint('[AppIntroScreen] Uživatel není přihlášen');
      }

      // Kontrola onboarding statusu
      await _checkOnboardingStatus();
    } catch (e) {
      debugPrint('[AppIntroScreen] Chyba při inicializaci: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _checkOnboardingStatus() async {
    if (_isInitialized) return;

    try {
      final bool introCompleted = await OnboardingManager.isIntroCompleted(
        userId: _userId,
      );
      final bool chatbotCompleted = await OnboardingManager.isChatbotCompleted(
        userId: _userId,
      );
      final bool subscriptionShown =
          await OnboardingManager.isSubscriptionShown(
        userId: _userId,
      );
      final bool onboardingCompleted =
          await OnboardingManager.isOnboardingCompleted(
        userId: _userId,
      );

      if (!mounted) return;

      debugPrint('[AppIntroScreen] Status - '
          'intro: $introCompleted, '
          'chatbot: $chatbotCompleted, '
          'subscription: $subscriptionShown, '
          'completed: $onboardingCompleted');

      if (onboardingCompleted) {
        _navigateToMainApp();
        return;
      }

      if (subscriptionShown) {
        _navigateToMainApp();
        return;
      }

      if (chatbotCompleted) {
        _navigateToSubscription();
        return;
      }

      if (introCompleted) {
        _navigateToChatbot();
        return;
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('[AppIntroScreen] Chyba při kontrole onboarding statusu: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _navigateToMainApp() {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });
    Navigator.pushReplacementNamed(context, '/brideGroomMain');
  }

  void _navigateToSubscription() {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });
    Navigator.pushReplacementNamed(context, '/subscription');
  }

  void _navigateToChatbot() {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ChatBotScreen()),
      (route) => false,
    );
  }

  Future<void> _finishOnboarding() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });

    try {
      // Označení intro jako dokončeného s userId
      await OnboardingManager.markIntroCompleted(userId: _userId);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatBotScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[AppIntroScreen] Chyba při dokončování onboardingu: $e');
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  Future<void> _skipOnboarding() async {
    if (_isNavigating) return;
    setState(() {
      _isNavigating = true;
    });

    try {
      // Označení intro jako dokončeného s userId
      await OnboardingManager.markIntroCompleted(userId: _userId);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const ChatBotScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[AppIntroScreen] Chyba při přeskakování onboardingu: $e');
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Flexible(
                    child: Text(
                      tr('welcome_message'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  TextButton(
                    onPressed: _isNavigating ? null : _skipOnboarding,
                    child: Text(
                      tr('skip'),
                      style: TextStyle(
                        color: _isNavigating ? Colors.grey : Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  if (!_isNavigating) {
                    setState(() {
                      _currentPage = index;
                    });
                  }
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(_pages[index]);
                },
              ),
            ),
            _buildPageIndicator(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _isNavigating
                    ? null
                    : isLastPage
                        ? _finishOnboarding
                        : () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                            );
                          },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  backgroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isNavigating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      )
                    : Text(
                        isLastPage ? tr('continue') : tr('next'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(IntroductionPage page) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: size.height * 0.3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                page.imageAsset,
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
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
