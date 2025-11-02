/// lib/routes.dart - Kompatibilní wrapper pro app_router.dart
library;

// Tento soubor slouží jako most mezi starým a novým routing systémem
// Exportuje třídy z app_router.dart pro zpětnou kompatibilitu

export 'router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:den_d/router/app_router.dart';

// Explicitní definice RoutePaths pro zpětnou kompatibilitu
class RoutePaths {
  // Primární obrazovky
  static const String splash = AppRoutes.splash;
  //static const String welcome = AppRoutes.welcome;
  static const String auth = AppRoutes.auth;
  static const String onboarding = AppRoutes.onboarding;
  static const String introduction = AppRoutes.introduction;
  static const String usageSelection = AppRoutes.usageSelection;

  // Hlavní obrazovky
  static const String main = AppRoutes.main;
  static const String home = AppRoutes.home;
  static const String brideGroomMain = AppRoutes.brideGroomMain;

  // Funkční obrazovky
  static const String checklist = AppRoutes.checklist;
  static const String budget = AppRoutes.budget;
  static const String guests = AppRoutes.guests;
  static const String suppliers = AppRoutes.suppliers;
  static const String calendar = AppRoutes.calendar;
  static const String weddingSchedule = AppRoutes.weddingSchedule;

  // Nastavení a profil
  static const String profile = AppRoutes.profile;
  static const String settings = AppRoutes.settings;
  static const String weddingInfo = AppRoutes.weddingInfo;
  static const String subscription = AppRoutes.subscription;

  // Komunikace
  static const String messages = AppRoutes.messages;
  static const String chatbot = AppRoutes.chatbot;
  static const String aiChat = AppRoutes.aiChat;

  // Znemožnění vytvoření instance této třídy
  RoutePaths._();
}

// Pokud je potřeba kompatibilita se starým RouteGenerator
class RouteGenerator {
  /// Generuje route - deleguje na AppRouter
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return AppRouter.generateRoute(settings);
  }

  /// Vyčistí cache - deleguje na AppRouter
  static void clearCache() {
    AppRouter.clearCache();
  }

  // Další metody pro kompatibilitu
  static void resetRouteErrorCount(String routeName) {
    AppRouter.resetRouteErrorCount(routeName);
  }

  static int getRouteErrorCount(String routeName) {
    return AppRouter.getRouteErrorCount(routeName);
  }
}
