import 'package:flutter/material.dart';

/// Constants obsahuje všechny globální konstanty používané v celé aplikaci.
class Constants {
  // ================================
  // APLIKAČNÍ METADATA
  // ================================
  static const String appName = 'Svatební plánovač';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;

  // ================================
  // FIREBASE KONFIGURACE
  // ================================
  static const String firebaseProjectId = 'svatba-1e96b';
  static const String firebaseRegion = 'europe-west1';

  // Pro budoucí API rozšíření
  static const String baseUrlProduction = '';
  static const String baseUrlStaging = '';
  static const String baseUrlDevelopment = '';

  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String userProfileEndpoint = '/user/profile';

  // ================================
  // BILLING KONSTANTY
  // ================================

  // ✅ OPRAVENO: Product IDs pro in-app nákupy
  // Musí přesně odpovídat ID v Google Play Console: "premium_yearly"
  // POZOR: V Google Play Console je ID produktu "premium_yearly" (bez package name prefix!)
  static const String productPremiumYearlyAndroid = 'premium_yearly';
  static const String productPremiumYearlyIOS =
      'cz.filipstastny.dend.premium_yearly';

  // Free tier limity - počet povolených akcí v každé funkci
  // Uživatel může provést 3 akce v checklistu, 3 ve schedule, 3 v guests atd.
  static const int freeInteractionLimit = 3;

  // Premium předplatné - ceny pro zobrazení (skutečná cena se načítá z obchodu)
  static const double premiumPriceYearly = 200.0; // Kč za rok
  static const String currency = 'CZK';
  static const String currencySymbol = 'Kč';

  // ================================
  // LEGAL LINKS
  // ================================
  static const String termsPath = 'additional_files/legal/terms_of_service.md';
  static const String privacyPath = 'additional_files/legal/privacy_policy.md';

  // ================================
  // PACKAGE INFO
  // ================================
  // ✅ OPRAVENO: Musí odpovídat Bundle ID v App Store Connect a Package Name v Google Play
  static const String packageName = 'cz.filipstastny.dend';
  static const String bundleId = 'cz.filipstastny.dend';

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
  static const String subscriptionRoute = '/subscription';
  static const String legalRoute = '/legal';

  // Globální navigační klíč pro přístup k navigaci odkudkoli.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
  static final RegExp emailRegExp =
      RegExp(r"^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$");
  static final RegExp phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
  static final RegExp urlRegExp =
      RegExp(r'^(http|https):\/\/[^\s$.?#].[^\s]*$');

  static const String emailError = 'Neplatná emailová adresa.';
  static const String requiredFieldError = 'Toto pole je povinné.';
  static const String minLengthError = 'Hodnota je příliš krátká.';

  // ================================
  // LOKALIZACE
  // ================================
  static const List<String> supportedLocales = ['cs', 'en'];
  static const String defaultLocale = 'cs';

  // ================================
  // NOTIFIKACE
  // ================================
  static const String defaultChannelId = 'default_channel';
  static const String defaultChannelName = 'Výchozí notifikace';
  static const String defaultChannelDescription =
      'Tento kanál se používá pro výchozí notifikace.';

  // ================================
  // ENVIRONMENT
  // ================================
  static const bool isDebug = bool.fromEnvironment('dart.vm.product') == false;
  static const String environment =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

  // ================================
  // LAYOUT A UI
  // ================================
  // Maximální šířka obsahu (např. pro web nebo tablety).
  static const double maxContentWidth = 600.0;
  // Breakpointy pro responzivní design.
  static const double smallScreenBreakpoint = 360.0;
  static const double mediumScreenBreakpoint = 720.0;

  // ================================
  // FIRESTORE COLLECTIONS
  // ================================
  static const String usersCollection = 'users';
  static const String subscriptionsCollection = 'subscriptions';
  static const String weddingsCollection = 'weddings';
  static const String guestsCollection = 'guests';
  static const String tasksCollection = 'tasks';
  static const String expensesCollection = 'expenses';
  static const String suppliersCollection = 'suppliers';
  static const String messagesCollection = 'messages';
  static const String weddingInfoCollection = 'wedding_info';
  static const String budgetCollection = 'budget';
  static const String scheduleCollection = 'schedule';
  static const String checklistCollection = 'checklist';
  static const String tablesCollection = 'tables';

  // ================================
  // SUBSCRIPTION FEATURES
  // ================================
  // Popis free a premium features pro UI
  static const List<String> freeFeaturesKeys = [
    'subs.free.limited_interactions',
    'subs.free.with_ads',
  ];

  static const List<String> premiumFeaturesKeys = [
    'subs.premium.unlimited_functions',
    'subs.premium.no_ads',
    'subs.premium.cloud_sync',
    'subs.premium.priority_support',
  ];

  // ================================
  // INTERACTION TYPES
  // ================================
  // Typy interakcí pro free limit tracking
  static const String interactionChecklist = 'addChecklistItem';
  static const String interactionSchedule = 'addScheduleItem';
  static const String interactionGuest = 'addGuest';
  static const String interactionExpense = 'addExpense';
  static const String interactionNote = 'addNote';
  static const String interactionPhoto = 'uploadPhoto';
}

/// Billing konstanty pro snadnější přístup
///
/// Tato třída poskytuje přístup k billing konstantám
/// pro správu předplatného a in-app nákupů.
class Billing {
  // Product IDs - ✅ OPRAVENO: Pouze "premium_yearly" bez package name
  static const String productPremiumYearlyAndroid =
      Constants.productPremiumYearlyAndroid;
  static const String productPremiumYearlyIOS =
      Constants.productPremiumYearlyIOS;

  // Limity
  static const int freeInteractionLimit = Constants.freeInteractionLimit;

  // Ceny
  static const double premiumPriceYearly = Constants.premiumPriceYearly;
  static const String currency = Constants.currency;
  static const String currencySymbol = Constants.currencySymbol;

  // Features
  static const List<String> freeFeaturesKeys = Constants.freeFeaturesKeys;
  static const List<String> premiumFeaturesKeys = Constants.premiumFeaturesKeys;
}

/// Legal links konstanty
///
/// Obsahuje cesty k právním dokumentům aplikace.
class LegalLinks {
  static const String termsPath = Constants.termsPath;
  static const String privacyPath = Constants.privacyPath;
}

/// Firestore collection names
///
/// Centralizované názvy kolekcí pro Firestore.
class FirestoreCollections {
  static const String users = Constants.usersCollection;
  static const String subscriptions = Constants.subscriptionsCollection;
  static const String weddings = Constants.weddingsCollection;
  static const String guests = Constants.guestsCollection;
  static const String tasks = Constants.tasksCollection;
  static const String expenses = Constants.expensesCollection;
  static const String suppliers = Constants.suppliersCollection;
  static const String messages = Constants.messagesCollection;
  static const String weddingInfo = Constants.weddingInfoCollection;
  static const String budget = Constants.budgetCollection;
  static const String schedule = Constants.scheduleCollection;
  static const String checklist = Constants.checklistCollection;
  static const String tables = Constants.tablesCollection;
}

/// UI konstanty
///
/// Konstanty pro UI design a animace.
class UIConstants {
  // Barvy
  static const Color primaryColor = Constants.primaryColor;
  static const Color secondaryColor = Constants.secondaryColor;
  static const Color backgroundColor = Constants.backgroundColor;
  static const Color accentColor = Constants.accentColor;
  static const Color textColor = Constants.textColor;

  // Typography
  static const String fontFamily = Constants.fontFamily;
  static const double defaultFontSize = Constants.defaultFontSize;

  // Spacing
  static const double defaultPadding = Constants.defaultPadding;
  static const double defaultMargin = Constants.defaultMargin;
  static const double borderRadius = Constants.borderRadius;

  // Animace
  static const Duration defaultAnimationDuration =
      Constants.defaultAnimationDuration;
  static const Duration longAnimationDuration = Constants.longAnimationDuration;
  static const Curve defaultCurve = Constants.defaultCurve;
  static const Duration defaultDelay = Constants.defaultDelay;

  // Layout
  static const double maxContentWidth = Constants.maxContentWidth;
  static const double smallScreenBreakpoint = Constants.smallScreenBreakpoint;
  static const double mediumScreenBreakpoint = Constants.mediumScreenBreakpoint;
}

/// Validace konstanty
///
/// Regulární výrazy a chybové hlášky pro validaci.
class ValidationConstants {
  static final RegExp emailRegExp = Constants.emailRegExp;
  static final RegExp phoneRegExp = Constants.phoneRegExp;
  static final RegExp urlRegExp = Constants.urlRegExp;

  static const String emailError = Constants.emailError;
  static const String requiredFieldError = Constants.requiredFieldError;
  static const String minLengthError = Constants.minLengthError;
}
