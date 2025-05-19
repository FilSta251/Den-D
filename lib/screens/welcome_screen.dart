import 'dart:async';
import 'package:flutter/material.dart';

/// WelcomeScreen představuje uvítací obrazovku, která se zobrazí novým uživatelům.
/// Obsahuje animovaný vstup, logo, vítací text, popis a tlačítko pro pokračování.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Timer? _autoNavigateTimer;

  @override
  void initState() {
    super.initState();
    // Inicializace animace (fade in)
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeIn,
      ),
    );
    _animationController!.forward();

    // Pokud chcete automaticky přejít na další obrazovku po určité době, můžete odkomentovat níže:
    // _autoNavigateTimer = Timer(const Duration(seconds: 5), _navigateNext);
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _autoNavigateTimer?.cancel();
    super.dispose();
  }

  /// Naviguje na další obrazovku (například onboarding nebo domovskou obrazovku).
  void _navigateNext() {
    // Zde nastavte trasu podle vaší navigační logiky
    Navigator.pushReplacementNamed(context, '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo – ujistěte se, že máte asset "assets/images/welcome_logo.png"
                  Image.asset(
                    'assets/images/welcome_logo.png',
                    width: 200,
                    height: 200,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Vítejte v naší aplikaci!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Objevte nové funkce, spravujte své úkoly a komunikujte snadno s ostatními. '
                    'Začněte svou cestu nyní a užijte si vše, co naše aplikace nabízí.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _navigateNext,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF2575FC),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Začít',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Volitelně přidejte další tlačítka (např. pro přihlášení či registraci)
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      'Už máte účet? Přihlaste se',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

