// lib/screens/splash_screen.dart - OPRAVENÁ VERZE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routes.dart';
import '../services/onboarding_manager.dart';
import '../services/notification_service.dart';
import '../di/service_locator.dart' as di;

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<double>? _scaleAnimation;
  
  bool _isLoading = true;
  String _statusMessage = 'Inicializace aplikace...';
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }
  
  // Nastavení animací pro splash screen
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
  
  // Inicializace aplikace
  Future<void> _initializeApp() async {
    try {
      // Zobrazení statusu inicializace
      _updateStatus('Kontrola uživatelského účtu...');
      
      // Kontrola přihlášení
      final user = FirebaseAuth.instance.currentUser;
      
      // Kontrola zda jsou dostupné služby
      await _checkServices();
      
      // Prodleva pro zobrazení splash screenu
      await Future.delayed(const Duration(seconds: 2));
      
      if (user != null) {
        // Uživatel je přihlášen
        _updateStatus('Přihlášený uživatel nalezen, přesměrování...');
        
        // Kontrola, zda uživatel dokončil onboarding
        final onboardingCompleted = await OnboardingManager.isOnboardingCompleted();
        
        // Směrovat podle stavu onboardingu
        if (onboardingCompleted) {
          // Přejít na hlavní menu
          _navigateTo(RoutePaths.brideGroomMain);
        } else {
          // Kontrola, kam poslat uživatele v onboardingu
          await _checkOnboardingProgress();
        }
      } else {
        // Uživatel není přihlášen
        _updateStatus('Přihlášení vyžadováno...');
        _navigateTo(RoutePaths.welcome);
      }
    } catch (e) {
      _updateStatus('Chyba při inicializaci: $e');
      debugPrint('Chyba při inicializaci aplikace: $e');
      
      // Počkat 3 sekundy a pak přesměrovat na auth obrazovku
      await Future.delayed(const Duration(seconds: 3));
      _navigateTo(RoutePaths.welcome);
    }
  }
  
  // Kontrola dostupnosti služeb
  Future<void> _checkServices() async {
    _updateStatus('Kontrola služeb aplikace...');
    
    try {
      // Inicializace služeb je již provedena v main.dart
      // Zde pouze kontrolujeme, zda jsou služby dostupné
      
      // Kontrola notifikací bez volání neexistující metody
      final notificationService = di.locator<NotificationService>();
      // Zde necháme prázdnou kontrolu, protože checkPermissions neexistuje
      
      _updateStatus('Služby inicializovány.');
    } catch (e) {
      debugPrint('Varování: Některé služby nemusí být dostupné: $e');
      // Pokračujeme dál i při chybě
    }
  }
  
  // Kontrola stavu onboardingu a přesměrování
  Future<void> _checkOnboardingProgress() async {
    _updateStatus('Kontrola procesu nastavení...');
    
    final introCompleted = await OnboardingManager.isIntroCompleted();
    final chatbotCompleted = await OnboardingManager.isChatbotCompleted();
    final subscriptionShown = await OnboardingManager.isSubscriptionShown();
    
    if (subscriptionShown) {
      // Pokud viděl nabídku předplatného, směřovat na hlavní menu
      _navigateTo(RoutePaths.brideGroomMain);
      await OnboardingManager.markOnboardingCompleted();
    } else if (chatbotCompleted) {
      // Pokud dokončil chatbota, směřovat na předplatné
      _navigateTo(RoutePaths.subscription);
    } else if (introCompleted) {
      // Pokud dokončil intro, směřovat na chatbota
      _navigateTo(RoutePaths.chatbot);
    } else {
      // Jinak začít od začátku
      _navigateTo(RoutePaths.introduction);
    }
  }
  
  // Aktualizace stavu načítání
  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }
  
  // Navigace na další obrazovku
  void _navigateTo(String routeName) {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      
      // Použít animaci pro přechod
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.of(context).pushReplacementNamed(routeName);
      });
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
      backgroundColor: Theme.of(context).colorScheme.background,
      body: AnimatedBuilder(
        animation: _animationController!,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo aplikace s animací
                FadeTransition(
                  opacity: _fadeAnimation!,
                  child: ScaleTransition(
                    scale: _scaleAnimation!,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Název aplikace
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
                
                // Indikátor načítání
                if (_isLoading) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}