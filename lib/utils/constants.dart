import 'package:flutter/material.dart';

/// Constants obsahuje všechny globální konstanty používané v celé aplikaci.
class Constants {
  // ================================
  // APLIKAČNÍ METADATA
  // ================================
  static const String appName = 'Wedding Planner';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // ================================
  // API KONFIGURACE
  // ================================
  static const String baseUrlProduction = 'https://api.example.com';
  static const String baseUrlStaging = 'https://staging.api.example.com';
  static const String baseUrlDevelopment = 'http://localhost:3000';

  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String userProfileEndpoint = '/user/profile';

  // Poznámka: V reálné aplikaci je vhodné ukládat API klíče bezpečně mimo zdrojový kód.
  static const String apiKey = 'YOUR_API_KEY_HERE';

  // ================================
  // TÉMATICKÉ KONSTANTY
  // ================================
  static const Color primaryColor = Colors.pink;
  static const Color secondaryColor = Colors.deepPurple;
  static const Color backgroundColor = Colors.white;
  static const Color accentColor = Colors.amber;
  static const Color textColor = Colors.black;

  static const String fontFamily = 'Roboto';
  static const double defaultFontSize = 16.0;

  static const double defaultPadding = 16.0;
  static const double defaultMargin = 16.0;
  static const double borderRadius = 8.0;

  // ================================
  // NAVIGAČNÍ KONSTANTY
  // ================================
  static const String homeRoute = '/';
  static const String authRoute = '/auth';
  static const String profileRoute = '/profile';
  static const String onboardingRoute = '/onboarding';
  static const String mainMenuRoute = '/mainMenu';
  // Další trasy mohou být přidány dle potřeby (např. /tasks, /settings apod.)

  // Globální navigační klíč pro přístup k navigaci odkudkoli.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ================================
  // KONSTANTY PRO ANIMACE
  // ================================
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  static const Curve defaultCurve = Curves.easeInOut;
  static const Duration defaultDelay = Duration(milliseconds: 200);

  // ================================
  // VALIDACE A REGULÁRNÍ VÝRAZY
  // ================================
  static final RegExp emailRegExp = RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$");
  static final RegExp phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
  static final RegExp urlRegExp = RegExp(r'^(http|https):\/\/[^\s$.?#].[^\s]*$');

  static const String emailError = 'Neplatná emailová adresa.';
  static const String requiredFieldError = 'Toto pole je povinné.';
  static const String minLengthError = 'Hodnota je příliš krátká.';

  // ================================
  // LOKALIZACE
  // ================================
  static const List<String> supportedLocales = ['en', 'cs'];
  static const String defaultLocale = 'en';

  // ================================
  // NOTIFIKACE
  // ================================
  static const String defaultChannelId = 'default_channel';
  static const String defaultChannelName = 'Default Notifications';
  static const String defaultChannelDescription =
      'This channel is used for default notifications.';

  // ================================
  // ENVIRONMENT
  // ================================
  // Využijte například --dart-define při buildu pro dynamické nastavení prostředí.
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
  static const String environment = 'production'; // nebo 'development', 'staging'

  // ================================
  // LAYOUT A UI
  // ================================
  // Maximální šířka obsahu (např. pro web nebo tablety).
  static const double maxContentWidth = 600.0;
  // Breakpointy pro responzivní design.
  static const double smallScreenBreakpoint = 360.0;
  static const double mediumScreenBreakpoint = 720.0;
}
