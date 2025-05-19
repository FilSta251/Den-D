import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/user_repository.dart';


// Import hlavní obrazovky, kam se uživatel přesměruje po dokončení onboardingu.
import 'bride_groom_main_menu.dart';

/// OnboardingScreen představuje vícestránkový onboarding flow pro aplikaci.
/// Po úspěšném dokončení onboardingu se uloží příznak a uživatel je přesměrován na hlavní obrazovku.
class OnboardingScreen extends StatefulWidget {
  final UserRepository userRepository; // Parametr userRepository
  const OnboardingScreen({Key? key, required this.userRepository}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Seznam obsahu pro jednotlivé stránky onboardingu.
  final List<Widget> _pages = const [
    _OnboardingPage(
      imageAsset: 'assets/images/onboarding1.png',
      title: 'Vítejte ve Wedding Planner',
      description: 'Plánujte svou svatbu jednoduše a efektivně.',
    ),
    _OnboardingPage(
      imageAsset: 'assets/images/onboarding2.png',
      title: 'Organizace úkolů',
      description: 'Spravujte své úkoly a sledujte termíny snadno.',
    ),
    _OnboardingPage(
      imageAsset: 'assets/images/onboarding3.png',
      title: 'Sdílejte radost',
      description: 'Komunikujte s hosty a pomocníky přímo v aplikaci.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  /// Pokud již byl onboarding dokončen, automaticky přesměrujeme uživatele na hlavní obrazovku.
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

  /// Uloží příznak, že onboarding byl dokončen.
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingCompleted', true);
  }

  /// Dokončí onboarding a přesměruje uživatele na hlavní obrazovku.
  void _finishOnboarding() async {
    await _completeOnboarding();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BrideGroomMainMenu()),
    );
  }

  /// Přejde na další stránku, nebo pokud jsme na poslední, dokončí onboarding.
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  /// Přeskočí onboarding a přesměruje uživatele na hlavní obrazovku.
  void _skipOnboarding() {
    _finishOnboarding();
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
    // Pokud by bylo potřeba využít userRepository, můžete jej získat přes widget.userRepository.
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Onboarding'),
          actions: [
            TextButton(
              onPressed: _skipOnboarding,
              child: const Text(
                'Přeskočit',
                style: TextStyle(color: Colors.white),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  _currentPage == _pages.length - 1 ? 'Začít' : 'Další',
                  style: const TextStyle(fontSize: 18),
                ),
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
    Key? key,
    required this.imageAsset,
    required this.title,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Použití MediaQuery pro responsivitu layoutu.
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Obrázek – ujistěte se, že soubor existuje v assets a je uveden v pubspec.yaml.
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
