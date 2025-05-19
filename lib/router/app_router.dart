// lib/router/app_router.dart - FINÁLNÍ VERZE

import 'package:flutter/material.dart';
import '../di/service_locator.dart' as di;
import '../repositories/user_repository.dart';

// Import všech obrazovek
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/app_introduction_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/bride_groom_main_menu.dart';
import '../screens/profile_page.dart';
import '../screens/wedding_info_page.dart';
import '../screens/wedding_schedule_screen.dart';
import '../screens/subscription_page.dart';
import '../screens/messages_page.dart';
import '../screens/settings_page.dart';
import '../screens/checklist_screen.dart';
import '../screens/calendar_page.dart';
import '../screens/suppliers_list_page.dart';
import '../screens/usage_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/guests_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/welcome_screen.dart';

/// Centralizovaná třída pro správu navigace v aplikaci.
/// 
/// Poskytuje statické metody pro generování rout a konstanty pro cesty.
class AppRouter {
  /// Generuje route na základě požadované cesty.
  /// Tato metoda by měla být použita v MaterialApp jako onGenerateRoute.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    WidgetBuilder builder;
    
    switch (settings.name) {
      case Routes.splash:
        builder = (_) => const SplashScreen();
        break;
      case Routes.welcome:
        builder = (_) => const WelcomeScreen();
        break;
      case Routes.auth:
        builder = (_) => AuthScreen(userRepository: di.locator<UserRepository>());
        break;
      case Routes.onboarding:
        builder = (_) => OnboardingScreen(userRepository: di.locator<UserRepository>());
        break;
      case Routes.introduction:
        builder = (_) => const AppIntroductionScreen();
        break;
      case Routes.usageSelection:
        builder = (_) => const UsageSelectionScreen();
        break;
      case Routes.chatbot:
        builder = (_) => const ChatBotScreen();
        break;
      case Routes.main:
        // NAHRAZENÍ MainMenu KONSTRUKTORU EXISTUJÍCÍM WIDGETEM
        builder = (_) => const BrideGroomMainMenu();
        break;
      case Routes.brideGroomMain:
        builder = (_) => const BrideGroomMainMenu();
        break;
      case Routes.profile:
        builder = (_) => const ProfilePage();
        break;
      case Routes.weddingInfo:
        builder = (_) => const WeddingInfoPage();
        break;
      case Routes.weddingSchedule:
        builder = (_) => const WeddingScheduleScreen();
        break;
      case Routes.subscription:
        builder = (_) => const SubscriptionPage();
        break;
      case Routes.messages:
        builder = (_) => const MessagesPage();
        break;
      case Routes.settings:
        builder = (_) => const SettingsPage();
        break;
      case Routes.checklist:
        builder = (_) => const ChecklistPage();
        break;
      case Routes.calendar:
        builder = (_) => const CalendarPage();
        break;
      case Routes.aiChat:
        // NAHRAZENÍ AIChatScreen KONSTRUKTORU EXISTUJÍCÍM WIDGETEM
        builder = (_) => const HomeScreen();
        break;
      case Routes.suppliers:
        builder = (_) => const SuppliersListPage();
        break;
      case Routes.budget:
        builder = (_) => const BudgetScreen();
        break;
      case Routes.guests:
        builder = (_) => const GuestsScreen();
        break;
      case Routes.home:
        builder = (_) => const HomeScreen();
        break;
      default:
        return _errorRoute(settings.name);
    }
    
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
  
  /// Vytváří chybovou route pro neexistující cestu.
  static Route<dynamic> _errorRoute(String? path) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(
            'Stránka "' + (path ?? "neznámá") + '" neexistuje.',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

/// Konstanty pro všechny cesty v aplikaci.
/// 
/// Použití konstant místo přímého zápisu řetězců pomáhá:
/// 1. Předejít překlepům v názvech cest
/// 2. Ulehčit refaktoring při změně názvů cest
/// 3. Poskytnout IDE doplňování při psaní
class Routes {
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
  static const String budget = '/budget';
  static const String guests = '/guests';
  static const String home = '/home';
  
  // Znemožnění vytvoření instance této třídy
  Routes._();
}