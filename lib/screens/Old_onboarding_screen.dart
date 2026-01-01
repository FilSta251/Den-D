import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../repositories/user_repository.dart';
import '../router/app_router.dart';

// Import hlavní obrazovky, kam se uťivatel přesměruje po dokončení onboardingu.
import 'bride_groom_main_menu.dart';

/// OnboardingScreen představuje vícestránkový onboarding flow pro aplikaci.
/// Po úspěĹˇnĂ©m dokončení onboardingu se uloťí příznak a uťivatel je přesměrován na hlavní obrazovku.
class OnboardingScreen extends StatefulWidget {
  final UserRepository userRepository; // Parametr userRepository
  const OnboardingScreen({super.key, required this.userRepository});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Seznam obsahu pro jednotlivĂ© stránky onboardingu.
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
        // Premium stránka
        _PremiumOnboardingPage(),
      ];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  /// Pokud jiť byl onboarding dokončen, automaticky přesměrujeme uťivatele na hlavní obrazovku.
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;
    if (onboardingCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BrideGroomMainMenu()),
        );
      });
    }
  }

  /// Uloťí příznak, ťe onboarding byl dokončen.
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
  }

  /// Dokončí onboarding a přesměruje uťivatele na hlavní obrazovku (Free verze).
  void _finishOnboardingFree() async {
    await _completeOnboarding();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BrideGroomMainMenu()),
    );
  }

  /// Přesměruje na SubscriptionPage pro Premium.
  void _navigateToPremium() async {
    await _completeOnboarding();
    AppRouter.navigateFromOnboarding(context);
  }

  /// Přejde na dalĹˇí stránku, nebo pokud jsme na poslední, zobrazí Premium stránku.
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Přeskočí onboarding a přesměruje uťivatele na hlavní obrazovku.
  void _skipOnboarding() {
    _finishOnboardingFree();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Indikátor aktuální stránky.
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

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('onboarding')),
          actions: [
            if (!isLastPage)
              TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  tr('skip'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
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
            _buildPageIndicator(),
            const SizedBox(height: 16),

            // Pokud nejsme na Premium stránce, zobrazíme standardní Next tláčítko
            if (!isLastPage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    tr('next'),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),

            // Na Premium stránce zobrazíme dvě CTA tláčítka
            if (isLastPage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Premium tláčítko
                    ElevatedButton(
                      onPressed: _navigateToPremium,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.pink,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        tr('onboarding.premium.unlock'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Free tláčítko
                    OutlinedButton(
                      onPressed: _finishOnboardingFree,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                      child: Text(
                        tr('onboarding.premium.continue_free'),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Právní řádek
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                          children: [
                            TextSpan(text: tr('onboarding.legal.prefix')),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => AppRouter.navigateToTerms(context),
                                child: Text(
                                  tr('onboarding.legal.terms'),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    decoration: TextDecoration.underline,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(text: tr('onboarding.legal.and')),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () =>
                                    AppRouter.navigateToPrivacy(context),
                                child: Text(
                                  tr('onboarding.legal.privacy'),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    decoration: TextDecoration.underline,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(text: tr('onboarding.legal.suffix')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Jednotlivá stránka onboardingu s obrázkem, titulkem a popisem.
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
    // Pouťití MediaQuery pro responsivitu layoutu.
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Obrázek "“ ujistěte se, ťe soubor existuje v assets a je uveden v pubspec.yaml.
          Container(
            height: size.height * 0.3,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(imageAsset),
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Premium stránka v onboardingu
class _PremiumOnboardingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium ikona
          SizedBox(
            height: size.height * 0.2,
            child: Icon(
              Icons.diamond,
              size: 120,
              color: Colors.amber,
            ),
          ),

          const SizedBox(height: 32),

          // Titulek
          Text(
            tr('onboarding.premium.title'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.pink,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Popis
          Text(
            tr('onboarding.premium.subtitle'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Výhody Premium
          Column(
            children: [
              _PremiumFeature(
                icon: Icons.all_inclusive,
                title: tr('onboarding.premium.feature1'),
              ),
              _PremiumFeature(
                icon: Icons.cloud_sync,
                title: tr('onboarding.premium.feature2'),
              ),
              _PremiumFeature(
                icon: Icons.priority_high,
                title: tr('onboarding.premium.feature3'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Cena
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.pink.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.pink.withOpacity(0.3)),
            ),
            child: Text(
              tr('onboarding.premium.price'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.pink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pro jednotlivĂ© Premium funkce
class _PremiumFeature extends StatelessWidget {
  final IconData icon;
  final String title;

  const _PremiumFeature({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
