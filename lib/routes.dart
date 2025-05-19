// lib/routes.dart - OPTIMALIZOVÁNO PRO PRODUKCI

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import './di/service_locator.dart';
import './repositories/user_repository.dart';
import './services/analytics_service.dart';

// Import obrazovek
import 'screens/splash_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/app_introduction_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/bride_groom_main_menu.dart';
import 'screens/home_screen.dart';
import 'screens/checklist_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/guests_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/profile_page.dart';
import 'screens/wedding_info_page.dart';
import 'screens/subscription_page.dart';
import 'screens/messages_page.dart';
import 'screens/settings_page.dart';
import 'screens/calendar_page.dart';
import 'screens/suppliers_list_page.dart';
import 'screens/usage_selection_screen.dart';
import 'screens/wedding_schedule_screen.dart';  // Obrazovka harmonogramu

/// Centralizovaná definice názvů tras.
class RoutePaths {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String onboarding = '/onboarding';
  static const String introduction = '/introduction';
  static const String usageSelection = '/usageSelection';
  static const String chatbot = '/chatbot';
  static const String main = '/main';
  static const String brideGroomMain = '/brideGroomMain';
  static const String profile = '/profile';
  static const String weddingInfo = '/weddingInfo';
  static const String weddingSchedule = '/weddingSchedule';
  static const String subscription = '/subscription';
  static const String messages = '/messages';
  static const String settings = '/settings';
  static const String checklist = '/checklist';
  static const String calendar = '/calendar';
  static const String aiChat = '/aiChat';
  static const String suppliers = '/suppliers';
  static const String tasks = '/tasks';
  static const String guests = '/guests';
  static const String budget = '/budget';
}

/// Generátor tras s optimalizovaným mechanismem načítání obrazovek.
class RouteGenerator {
  // Zachycení chyb při navigaci pro zlepšení diagnostiky
  static void _logNavigationError(Object error, StackTrace? stackTrace, String routeName) {
    debugPrint('Chyba při navigaci na $routeName: $error');
    FirebaseCrashlytics.instance.recordError(
      error, 
      stackTrace,
      reason: 'Navigation to $routeName failed', 
      printDetails: true
    );
  }

  // Cache pro již vytvořené widgety (lazy-loading s cachováním)
  static final Map<String, Widget> _cachedWidgets = {};

  // Metoda pro generování trasy
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Měření výkonu navigace
    final Trace navigationTrace = FirebasePerformance.instance.newTrace('navigation_${settings.name?.replaceAll("/", "_") ?? "unknown"}');
    navigationTrace.start();

    // Vždy zaznamenáme navigaci pro analytiku
    try {
      // Jednoduchá kontrola argumentů
      String? fromScreen;
      if (settings.arguments is Map<String, dynamic>) {
        fromScreen = (settings.arguments as Map<String, dynamic>)['from_screen'] as String?;
      }
      
      // Použití analytiky - zakomentováno pro teď
      // final analytics = locator<AnalyticsService>();
      // analytics.logScreenChange(
      //   fromScreen: fromScreen,
      //   toScreen: settings.name,
      // );
    } catch (e) {
      debugPrint('Chyba při logování navigace: $e');
    }

    Route<dynamic> route = _buildRoute(settings);
    
    // Po vytvoření trasy ukončíme měření výkonu
    Future.delayed(Duration.zero, () {
      navigationTrace.stop();
    });
    
    return route;
  }

  // Metoda pro vytvoření widgetu v závislosti na cestě
  static Route<dynamic> _buildRoute(RouteSettings settings) {
    Widget targetWidget;
    bool useAnimation = true;
    
    // Pokus o získání widgetu z cache, pokud není kritická obrazovka
    if (!_isHighPriorityRoute(settings.name) && _cachedWidgets.containsKey(settings.name)) {
      debugPrint('Použití cached widgetu pro ${settings.name}');
      targetWidget = _cachedWidgets[settings.name]!;
    } else {
      try {
        targetWidget = _createWidgetForRoute(settings);
        
        // Uložit do cache, pouze pokud není kritická obrazovka
        if (!_isHighPriorityRoute(settings.name)) {
          _cachedWidgets[settings.name!] = targetWidget;
        }
      } catch (e, stackTrace) {
        _logNavigationError(e, stackTrace, settings.name ?? 'unknown');
        return _errorRoute(message: e.toString());
      }
    }

    // Vytvoření nového PageRouteBuilder s FadeTransition
    if (useAnimation) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => targetWidget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
    } else {
      // Pro některé obrazovky může být vhodné přeskočit animaci
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => targetWidget,
      );
    }
  }

  // Metoda určující, zda je trasa kritická a neměla by být cachována
  static bool _isHighPriorityRoute(String? routeName) {
    final highPriorityRoutes = [
      RoutePaths.splash,
      RoutePaths.auth,
      RoutePaths.brideGroomMain
    ];
    
    return routeName != null && highPriorityRoutes.contains(routeName);
  }

  // Vytvoření widgetu pro konkrétní cestu
  static Widget _createWidgetForRoute(RouteSettings settings) {
    debugPrint('Vytváření widgetu pro ${settings.name}');
    
    switch (settings.name) {
      case RoutePaths.splash:
        return const SplashScreen();
      case RoutePaths.welcome:
        return const WelcomeScreen();
      case RoutePaths.auth:
        // Předáváme repository jako závislost
        try {
          final userRepository = locator<UserRepository>();
          return AuthScreen(userRepository: userRepository);
        } catch (e) {
          debugPrint('Nepodařilo se získat UserRepository: $e');
          // Fallback, pokud DI selže
          return AuthScreen(userRepository: UserRepository());
        }
      case RoutePaths.onboarding:
        try {
          final userRepository = locator<UserRepository>();
          return OnboardingScreen(userRepository: userRepository);
        } catch (e) {
          debugPrint('Nepodařilo se získat UserRepository: $e');
          return OnboardingScreen(userRepository: UserRepository());
        }
      case RoutePaths.introduction:
        return const AppIntroductionScreen();
      case RoutePaths.usageSelection:
        return const UsageSelectionScreen();
      case RoutePaths.chatbot:
        return const ChatBotScreen();
      case RoutePaths.main:
        // NAHRAZENÍ MainMenu KONSTRUKTORU EXISTUJÍCÍM WIDGETEM
        return const BrideGroomMainMenu();
      case RoutePaths.brideGroomMain:
        return const BrideGroomMainMenu();
      case RoutePaths.profile:
        return const ProfilePage();
      case RoutePaths.weddingInfo:
        return const WeddingInfoPage();
      case RoutePaths.weddingSchedule:
        return const WeddingScheduleScreen();
      case RoutePaths.subscription:
        return const SubscriptionPage();
      case RoutePaths.messages:
        return const MessagesPage();
      case RoutePaths.settings:
        return const SettingsPage();
      case RoutePaths.checklist:
        return const ChecklistPage();
      case RoutePaths.calendar:
        return const CalendarPage();
      case RoutePaths.aiChat:
        // NAHRAZENÍ AIChatScreen KONSTRUKTORU EXISTUJÍCÍM WIDGETEM
        return const HomeScreen();
      case RoutePaths.suppliers:
        return const SuppliersListPage();
      case RoutePaths.tasks:
        return const TasksScreen();
      case RoutePaths.guests:
        return const GuestsScreen();
      case RoutePaths.budget:
        return const BudgetScreen();
      default:
        throw Exception('Neznámá cesta: ${settings.name}');
    }
  }

  // Chybová trasa s volitelnou zprávou
  static Route<dynamic> _errorRoute({String? message}) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Chyba navigace'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Stránka nenalezena',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (message != null) Text(
                  'Detaily: $message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(_).pushNamedAndRemoveUntil(
                      RoutePaths.splash, 
                      (route) => false
                    );
                  },
                  child: const Text('Zpět na úvodní obrazovku'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Metoda pro vyčištění cache při odhlášení
  static void clearCache() {
    _cachedWidgets.clear();
    debugPrint('Route cache byla vyčištěna');
  }
}