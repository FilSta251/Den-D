/// lib/screens/splash_screen.dart - OPRAVENÁ VERZE
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/onboarding_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuthAndNavigate();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _animationController!.forward();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Kontrola přihlášeného uživatele
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Uživatel je přihlášen - zkontrolovat stav onboardingu
      final onboardingCompleted =
          await OnboardingManager.isOnboardingCompleted();

      if (onboardingCompleted) {
        Navigator.of(context).pushReplacementNamed('/brideGroomMain');
      } else {
        // Zkontrolovat kde v onboardingu je
        final chatbotCompleted = await OnboardingManager.isChatbotCompleted();
        final subscriptionShown = await OnboardingManager.isSubscriptionShown();

        if (subscriptionShown) {
          Navigator.of(context).pushReplacementNamed('/brideGroomMain');
        } else if (chatbotCompleted) {
          Navigator.of(context).pushReplacementNamed('/subscription');
        } else {
          Navigator.of(context).pushReplacementNamed('/chatbot');
        }
      }
    } else {
      // Uživatel není přihlášen - jít na auth
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedBuilder(
        animation: _animationController!,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _fadeAnimation!,
                  child: ScaleTransition(
                    scale: _scaleAnimation!,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                      height: 200,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.pink.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 100,
                            color: Colors.pink,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FadeTransition(
                  opacity: _fadeAnimation!,
                  child: Text(
                    tr('app_name'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 60),
                const CircularProgressIndicator(),
              ],
            ),
          );
        },
      ),
    );
  }
}
