import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'chatbot_screen.dart';
import '../services/onboarding_manager.dart'; // Přidaný import
import '../router/app_router.dart'; // Přidaný import

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
  const AppIntroductionScreen({Key? key}) : super(key: key);

  @override
  _AppIntroductionScreenState createState() => _AppIntroductionScreenState();
}

class _AppIntroductionScreenState extends State<AppIntroductionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Definuj stránky s texty načtenými přes tr() – klíče musí být definovány v jazykových souborech.
  late final List<IntroductionPage> _pages = [
    IntroductionPage(
      title: tr('intro_title_1'),
      description: tr('intro_desc_1'),
      imageAsset: 'assets/images/feature_tasks.png',
    ),
    IntroductionPage(
      title: tr('intro_title_2'),
      description: tr('intro_desc_2'),
      imageAsset: 'assets/images/feature_expenses.png',
    ),
    IntroductionPage(
      title: tr('intro_title_3'),
      description: tr('intro_desc_3'),
      imageAsset: 'assets/images/feature_events.png',
    ),
    IntroductionPage(
      title: tr('intro_title_4'),
      description: tr('intro_desc_4'),
      imageAsset: 'assets/images/feature_chat.png',
    ),
  ];

  // Přidaná metoda pro dokončení úvodních obrazovek
  Future<void> _finishOnboarding() async {
    // Označíme intro jako dokončené
    await OnboardingManager.markIntroCompleted();
    // Přejdeme na chatbota
    Navigator.pushReplacementNamed(context, AppRoutes.chatbot);
  }

  // Přidaná metoda pro přeskočení úvodních obrazovek
  Future<void> _skipOnboarding() async {
    // Označíme intro jako dokončené
    await OnboardingManager.markIntroCompleted();
    // Přejdeme na chatbota
    Navigator.pushReplacementNamed(context, AppRoutes.chatbot);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('welcome_message')),
        actions: [
          // Přidané tlačítko pro přeskočení
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
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(page.imageAsset, height: 200),
                      const SizedBox(height: 24),
                      Text(
                        page.title,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        page.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildPageIndicator(),
          const SizedBox(height: 16),
          _currentPage == _pages.length - 1
              ? ElevatedButton(
                  onPressed: _finishOnboarding,
                  child: Text(tr('continue')),
                )
              : ElevatedButton(
                  onPressed: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeIn,
                    );
                  },
                  child: Text(tr('next')),
                ),
          const SizedBox(height: 16),
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
            color: _currentPage == index ? Colors.pink : Colors.grey,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
