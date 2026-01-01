// lib/router/app_router.dart

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'dart:collection';
import '../di/service_locator.dart';
import '../services/crash_reporting_service.dart';
import '../repositories/user_repository.dart';

// NOVÉ IMPORTY - CHYBOVÉ KOMPONENTY
import '../widgets/error_dialog.dart';
import '../widgets/custom_error_widget.dart';
import '../utils/global_error_handler.dart';
import 'package:den_d/widgets/error_dialog.dart' as ed;

// Import obrazovek
import '../screens/splash_screen.dart';
//import '../screens/welcome_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/app_introduction_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/bride_groom_main_menu.dart';
import '../screens/home_screen.dart';
import '../screens/checklist_screen.dart';
import '../screens/guests_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/profile_page.dart';
import '../screens/wedding_info_page.dart';
import '../screens/subscription_page.dart';
import '../screens/legal_information_page.dart';
import '../screens/messages_page.dart';
import '../screens/settings_page.dart';
import '../screens/calendar_page.dart';
import '../screens/suppliers_list_page.dart';
import '../screens/usage_selection_screen.dart';
import '../screens/wedding_schedule_screen.dart';

/// Centralizovaná definice názvů tras.
class AppRoutes {
  // Primární obrazovky
  static const String splash = '/';
  //static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String onboarding = '/onboarding';
  static const String introduction = '/introduction';
  static const String usageSelection = '/usageSelection';

  // Hlavní obrazovky
  static const String main = '/main';
  static const String home = '/home';
  static const String brideGroomMain = '/brideGroomMain';

  // Funkční obrazovky
  static const String checklist = '/checklist';
  static const String budget = '/budget';
  static const String guests = '/guests';
  static const String suppliers = '/suppliers';
  static const String calendar = '/calendar';
  static const String weddingSchedule = '/weddingSchedule';

  // Nastavení a profil
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String weddingInfo = '/weddingInfo';
  static const String subscription = '/subscription';
  static const String legal = '/legal';

  // Komunikace
  static const String messages = '/messages';
  static const String chatbot = '/chatbot';
  static const String aiChat = '/aiChat';

  // ✅ OPRAVENO: Přidán legal do kritických tras (vypne caching)
  // Kategorizace tras podle priority
  static final Set<String> _criticalRoutes = {
    splash,
    auth,
    main,
    brideGroomMain,
    home,
    legal, // ✅ PŘIDÁNO - zakáže caching pro legal stránku
  };

  static final Set<String> _heavyRoutes = {
    budget,
    guests,
    weddingSchedule,
    suppliers
  };

  // NOVÉ: Trasy náchylné k chybám (potřebují extra error handling)
  static final Set<String> _errorProneRoutes = {
    budget,
    guests,
    weddingSchedule,
    subscription,
    auth,
  };

  // Znemožnění vytvoření instance této třídy
  AppRoutes._();

  /// Kontroluje, zda je trasa kritická (nemá být cachována)
  static bool isCriticalRoute(String routeName) =>
      _criticalRoutes.contains(routeName);

  /// Kontroluje, zda je trasa náročná (má být prefetchována)
  static bool isHeavyRoute(String routeName) =>
      _heavyRoutes.contains(routeName);

  /// NOVÉ: Kontroluje, zda je trasa náchylná k chybám
  static bool isErrorProneRoute(String routeName) =>
      _errorProneRoutes.contains(routeName);
}

/// Centralizovaná třída pro správu navigace v aplikaci.
///
/// Poskytuje metody pro generování rout, správu navigačního cache
/// a analytiku navigace.
class AppRouter {
  // Cache pro již vytvořené widgety s LRU mechanismem
  static final LRUCache<String, Widget> _widgetCache =
      LRUCache<String, Widget>(maxSize: 10);

  // Aktivní trace pro měření výkonu
  static final Map<String, Trace> _activeTraces = {};

  // Instance služby pro hlášení chyb
  static CrashReportingService? _crashReporting;

  // NOVÉ: Počítadlo chyb pro jednotlivé trasy
  static final Map<String, int> _routeErrorCounts = {};

  // NOVÉ: Maximální počet chyb před fallback routou
  static const int _maxErrorsPerRoute = 3;

  /// Inicializace routeru
  static void initialize() {
    try {
      _crashReporting = locator<CrashReportingService>();

      // Inicializace globálního error handleru pro router
      GlobalErrorHandler.instance.setErrorCallback((AppError error) {
        _handleRouterError(error);
      });

      debugPrint('AppRouter inicializován s error handling');
    } catch (e) {
      debugPrint(
          'Varování: CrashReportingService není dostupný, navigace nebude měřena');
    }
  }

  /// NOVÉ: Handling chyb specifických pro router
  static void _handleRouterError(AppError error) {
    debugPrint('Router error: ${error.message}');

    // Zde můžete přidat specifickou logiku pro router chyby
    // např. přesměrování na bezpečnou obrazovku při opakovaných chybách
  }

  /// Generuje route na základě požadované cesty.
  /// ROZŠÍŘENO o lepší error handling
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Spuštění měření výkonu navigace
    final String routeName = settings.name ?? 'unknown';
    _startNavigationTrace(routeName);

    // Zaznamenání navigace do analytiky a jako breadcrumb
    _logNavigation(settings);

    try {
      // NOVÉ: Kontrola počtu chyb pro tuto trasu
      final errorCount = _routeErrorCounts[routeName] ?? 0;
      if (errorCount >= _maxErrorsPerRoute) {
        _stopNavigationTrace(routeName);
        return _createFallbackRoute(
            routeName, 'Příliš mnoho chyb pro tuto obrazovku');
      }

      // Vytvoření widgetu pro požadovanou cestu
      final Widget widget = _resolveWidget(settings);

      // NOVÉ: Obalení error-prone tras do ErrorBoundary
      final Widget wrappedWidget = AppRoutes.isErrorProneRoute(routeName)
          ? _wrapWithErrorBoundary(widget, routeName)
          : widget;

      // Ukončení měření výkonu
      _stopNavigationTrace(routeName);

      // Volba typu animace a vytvoření route
      return _createRoute(settings, wrappedWidget);
    } catch (e, stack) {
      // NOVÉ: Počítání chyb pro trasu
      _routeErrorCounts[routeName] = (_routeErrorCounts[routeName] ?? 0) + 1;

      // Zachycení a zaznamenání chyby
      _logNavigationError(e, stack, routeName);

      // Použití globálního error handleru
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.critical,
        userMessage: 'Chyba při načítání obrazovky $routeName',
        errorCode: 'ROUTE_ERROR_${routeName.toUpperCase()}',
      );

      // Ukončení měření výkonu
      _stopNavigationTrace(routeName);

      // Vytvoření chybové route s našimi komponentami
      return _errorRoute(routeName, e.toString());
    }
  }

  /// NOVÉ: Obalení widgetu do ErrorBoundary
  static Widget _wrapWithErrorBoundary(Widget widget, String routeName) {
    return ErrorBoundary(
      child: widget,
      onError: (error, stackTrace) {
        GlobalErrorHandler.instance.handleError(
          error,
          stackTrace: stackTrace,
          type: ed.ErrorType.critical,
          userMessage: 'Chyba na obrazovce $routeName',
          errorCode: 'SCREEN_ERROR_${routeName.toUpperCase()}',
        );
      },
      errorBuilder: (error) => CustomErrorWidget(
        message: 'Chyba na obrazovce',
        errorType: ErrorWidgetType.unknown,
        onRetry: () {
          // Reset error count a pokus o reload
          _routeErrorCounts[routeName] = 0;
        },
        detailMessage:
            'Došlo k chybě na obrazovce $routeName: ${error.toString()}',
      ),
    );
  }

  /// Vytvoří route s animací fade transition
  static Route<dynamic> _createRoute(RouteSettings settings, Widget widget) {
    // Rozhodnutí, zda použít animaci nebo ne
    final bool useAnimation = !AppRoutes.isCriticalRoute(settings.name ?? '');

    if (useAnimation) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, animation, secondaryAnimation) => widget,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
    } else {
      // Pro kritické obrazovky přeskočíme animaci
      return MaterialPageRoute(
        settings: settings,
        builder: (context) => widget,
      );
    }
  }

  /// Rozhodne, zda použít cachovaný widget nebo vytvořit nový
  static Widget _resolveWidget(RouteSettings settings) {
    final String routeName = settings.name ?? 'unknown';

    // ✅ Pro kritické trasy (včetně legal) vždy vytvoříme novou instanci
    if (AppRoutes.isCriticalRoute(routeName)) {
      debugPrint('Vytváření nové instance pro kritickou trasu: $routeName');
      return _createWidgetForRoute(settings);
    }

    // Pro ostatní trasy se podíváme do cache
    if (_widgetCache.containsKey(routeName)) {
      debugPrint('Použití cached widgetu pro $routeName');
      return _widgetCache.get(routeName)!;
    }

    // Vytvoření a cachování nové instance
    final Widget widget = _createWidgetForRoute(settings);
    _widgetCache.put(routeName, widget);
    return widget;
  }

  /// Vytvoří widget pro danou cestu a její argumenty
  /// ROZŠÍŘENO o error handling pro jednotlivé obrazovky
  static Widget _createWidgetForRoute(RouteSettings settings) {
    final arguments = settings.arguments;

    try {
      switch (settings.name) {
        case AppRoutes.splash:
          return const SplashScreen();
        //case AppRoutes.welcome:
        //return const WelcomeScreen();
        case AppRoutes.auth:
          return AuthScreen(userRepository: locator<UserRepository>());
        case AppRoutes.introduction:
          return const AppIntroductionScreen();
        case AppRoutes.usageSelection:
          return const UsageSelectionScreen();
        case AppRoutes.chatbot:
          return const ChatBotScreen();
        case AppRoutes.main:
          return const BrideGroomMainMenu();
        case AppRoutes.brideGroomMain:
          return const BrideGroomMainMenu();
        case AppRoutes.profile:
          return const ProfilePage();
        case AppRoutes.weddingInfo:
          return const WeddingInfoPage();
        case AppRoutes.weddingSchedule:
          return const WeddingScheduleScreen();
        case AppRoutes.subscription:
          return const SubscriptionPage();
        case AppRoutes.legal:
          // Předání argumentu pro přepínač terms/privacy
          final String contentType = (arguments as String?) ?? 'terms';
          debugPrint(
              '[AppRouter] Vytváření LegalInformationPage s contentType: $contentType');
          return LegalInformationPage(contentType: contentType);
        case AppRoutes.messages:
          return const MessagesPage();
        case AppRoutes.settings:
          return const SettingsPage();
        case AppRoutes.checklist:
          return const ChecklistPage();
        case AppRoutes.calendar:
          return const CalendarPage();
        case AppRoutes.aiChat:
          return const HomeScreen();
        case AppRoutes.suppliers:
          return const SuppliersListPage();
        case AppRoutes.guests:
          return const GuestsScreen();
        case AppRoutes.budget:
          return const BudgetScreen();
        case AppRoutes.home:
          return const HomeScreen();
        default:
          throw RouteNotFoundException('Neznámá cesta: ${settings.name}');
      }
    } catch (e, stack) {
      // Specifické handlování chyb pro vytváření widgetů
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.critical,
        userMessage: 'Chyba při vytváření obrazovky ${settings.name}',
        errorCode: 'WIDGET_CREATION_ERROR',
      );

      // Fallback widget s error komponentou
      return CustomErrorWidget(
        message: 'Chyba při načítání obrazovky',
        errorType: ErrorWidgetType.unknown,
        onRetry: () {
          // Vyčistit cache a zkusit znovu
          _widgetCache.remove(settings.name ?? '');
        },
        detailMessage:
            'Obrazovka ${settings.name} se nepodařila načíst: ${e.toString()}',
      );
    }
  }

  /// NOVÉ: Metody pro navigaci na subscription stránky
  static void navigateToSubscription(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.subscription);
  }

  static void navigateToTerms(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.legal, arguments: 'terms');
  }

  static void navigateToPrivacy(BuildContext context) {
    Navigator.of(context).pushNamed(AppRoutes.legal, arguments: 'privacy');
  }

  /// NOVÉ: Metoda pro navigaci z paywallu
  static void navigateFromPaywall(BuildContext context, {String? source}) {
    Navigator.of(context).pushNamed(
      AppRoutes.subscription,
      arguments: {'source': source ?? 'paywall'},
    );
  }

  /// NOVÉ: Metoda pro navigaci z onboardingu
  static void navigateFromOnboarding(BuildContext context) {
    Navigator.of(context).pushNamed(
      AppRoutes.subscription,
      arguments: {'source': 'onboarding'},
    );
  }

  /// NOVÉ: Vytvoří fallback route při příliš mnoha chybách
  static Route<dynamic> _createFallbackRoute(String routeName, String reason) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text('auto.app_router.obrazovka_nedostupn'.tr()),
          backgroundColor: Colors.orange,
        ),
        body: CustomErrorWidget(
          message: 'Obrazovka dočasně nedostupná',
          errorType: ErrorWidgetType.maintenance,
          onRetry: () {
            // Reset error count
            _routeErrorCounts[routeName] = 0;
            Navigator.of(context).pushReplacementNamed(routeName);
          },
          onSecondaryAction: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            );
          },
          secondaryActionText: 'Domů',
          secondaryActionIcon: Icons.home,
          detailMessage:
              'Obrazovka $routeName byla dočasně zakázána kvůli opakovaným chybám. Důvod: $reason',
          showReportButton: true,
          onReportError: () {
            // Zobrazit error dialog pro report
            ErrorDialog.show(
              context,
              title: 'auto.app_router.nahl_sit_probl_m'.tr(),
              message:
                  'Chcete nahlásit opakované problémy s obrazovkou $routeName?',
              errorType: ed.ErrorType.critical,
              errorCode: 'REPEATED_ROUTE_ERRORS',
              technicalDetails:
                  'Route: $routeName\nError count: ${_routeErrorCounts[routeName]}\nReason: $reason',
              recoveryActions: [RecoveryAction.contact, RecoveryAction.ignore],
              onRecoveryAction: (action) {
                if (action == RecoveryAction.contact) {
                  // Implementace kontaktu
                  debugPrint('Reporting repeated errors for route: $routeName');
                }
              },
            );
          },
        ),
      ),
    );
  }

  /// Vytvoří chybovou route s našimi error komponentami
  /// AKTUALIZOVÁNO pro použití našich komponent
  static Route<dynamic> _errorRoute(String path, String errorMessage) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text('auto.app_router.chyba_navigace'.tr()),
          backgroundColor: Colors.red,
        ),
        body: CustomErrorWidget(
          message: 'Stránka nenalezena',
          errorType: ErrorWidgetType.notFound,
          onRetry: () {
            Navigator.of(context)
                .pushNamedAndRemoveUntil(AppRoutes.splash, (route) => false);
          },
          onSecondaryAction: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            );
          },
          secondaryActionText: 'Domů',
          secondaryActionIcon: Icons.home,
          detailMessage: 'Cesta: $path\nDetaily: $errorMessage',
          showReportButton: true,
          onReportError: () {
            ErrorDialog.show(
              context,
              title: 'auto.app_router.nahl_sit_chybu_navigace'.tr(),
              message: 'Chcete nahlásit problém s navigací?',
              errorType: ed.ErrorType.critical,
              errorCode: 'NAVIGATION_ERROR',
              technicalDetails: 'Path: $path\nError: $errorMessage',
              recoveryActions: [RecoveryAction.contact, RecoveryAction.ignore],
            );
          },
        ),
      ),
    );
  }

  /// Zahájení měření výkonu navigace
  static void _startNavigationTrace(String routeName) {
    try {
      // Vytvoření a spuštění trace
      final String traceName = 'navigation_${routeName.replaceAll("/", "_")}';
      final trace = FirebasePerformance.instance.newTrace(traceName);
      trace.start();
      _activeTraces[routeName] = trace;
    } catch (e) {
      debugPrint('Chyba při zahájení měření navigace: $e');
      GlobalErrorHandler.instance.handleError(
        e,
        type: ed.ErrorType.unknown,
        userMessage: 'Chyba při měření výkonu navigace',
        errorCode: 'NAVIGATION_TRACE_START_ERROR',
      );
    }
  }

  /// Ukončení měření výkonu navigace
  static void _stopNavigationTrace(String routeName) {
    try {
      if (_activeTraces.containsKey(routeName)) {
        final trace = _activeTraces[routeName]!;
        trace.stop();
        _activeTraces.remove(routeName);
      }
    } catch (e) {
      debugPrint('Chyba při ukončení měření navigace: $e');
      GlobalErrorHandler.instance.handleError(
        e,
        type: ed.ErrorType.unknown,
        userMessage: 'Chyba při ukončení měření výkonu',
        errorCode: 'NAVIGATION_TRACE_STOP_ERROR',
      );
    }
  }

  /// Zaznamenání navigace do analytiky
  static void _logNavigation(RouteSettings settings) {
    try {
      // Získání informací o odkud a kam navigujeme
      String? fromScreen;
      if (settings.arguments is Map<String, dynamic>) {
        fromScreen = (settings.arguments as Map<String, dynamic>)['from_screen']
            as String?;
      }

      // Zaznamenání do analytiky (pokud je dostupná)
      try {
        // final analytics = locator<AnalyticsService>();
        // analytics.logScreenView(screenName: settings.name ?? 'unknown');
      } catch (_) {
        // Analytika nemusí být dostupná
      }

      // Zaznamenání jako breadcrumb (pokud je dostupná služba)
      if (_crashReporting != null) {
        _crashReporting!.addBreadcrumb(
          message: 'Navigace na obrazovku',
          category: 'navigation',
          data: {
            'to_screen': settings.name,
            'from_screen': fromScreen,
            'arguments': settings.arguments?.toString(),
            'error_count': _routeErrorCounts[settings.name ?? 'unknown'] ?? 0,
          },
        );
      }
    } catch (e) {
      debugPrint('Chyba při logování navigace: $e');
      GlobalErrorHandler.instance.handleError(
        e,
        type: ed.ErrorType.unknown,
        userMessage: 'Chyba při zaznamenání navigace',
        errorCode: 'NAVIGATION_LOG_ERROR',
      );
    }
  }

  /// Zaznamenání chyby navigace
  static void _logNavigationError(
      Object error, StackTrace? stackTrace, String routeName) {
    debugPrint('Chyba při navigaci na $routeName: $error');

    // Zaznamenání do Crashlytics
    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Navigation to $routeName failed',
        printDetails: true,
      );
    } catch (_) {
      // Crashlytics nemusí být dostupné
    }

    // Zaznamenání do rozšířeného systému hlášení chyb
    if (_crashReporting != null) {
      _crashReporting!.recordErrorWithContext(
          error.toString(), 'navigation', stackTrace,
          additionalData: {
            'route': routeName,
            'error_count': _routeErrorCounts[routeName] ?? 0,
          });
    }
  }

  /// Vyčištění cache
  static void clearCache() {
    _widgetCache.clear();
    // NOVÉ: Reset error counts
    _routeErrorCounts.clear();
    debugPrint('Router cache a error counts byly vyčištěny');
  }

  /// NOVÉ: Reset error count pro specifickou trasu
  static void resetRouteErrorCount(String routeName) {
    _routeErrorCounts.remove(routeName);
    debugPrint('Error count pro trasu $routeName byl resetován');
  }

  /// NOVÉ: Získání počtu chyb pro trasu
  static int getRouteErrorCount(String routeName) {
    return _routeErrorCounts[routeName] ?? 0;
  }

  /// Prefetching těžkých obrazovek s error handlingem
  static void prefetchHeavyScreens() {
    debugPrint('Zahájení prefetchingu těžkých obrazovek');

    // Vytvoření a uložení těžkých obrazovek do cache
    for (final route in AppRoutes._heavyRoutes) {
      try {
        final settings = RouteSettings(name: route);
        final widget = _createWidgetForRoute(settings);
        _widgetCache.put(route, widget);
        debugPrint('Prefetched obrazovka: $route');
      } catch (e, stack) {
        debugPrint('Chyba při prefetchingu obrazovky $route: $e');
        GlobalErrorHandler.instance.handleError(
          e,
          stackTrace: stack,
          type: ed.ErrorType.unknown,
          userMessage: 'Chyba při předčítání obrazovky $route',
          errorCode: 'PREFETCH_ERROR',
        );
      }
    }
  }
}

/// NOVÉ: Custom exception pro neznámé trasy
class RouteNotFoundException implements Exception {
  final String message;
  RouteNotFoundException(this.message);

  @override
  String toString() => 'RouteNotFoundException: $message';
}

/// LRU (Least Recently Used) Cache implementace pro widgety
class LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  LRUCache({required this.maxSize});

  /// Kontrola, zda klíč existuje v cache
  bool containsKey(K key) => _cache.containsKey(key);

  /// Získání hodnoty z cache
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;

    // Přesunutí hodnoty na konec mapy (označení jako nedávno použité)
    final V value = _cache[key] as V;
    _cache.remove(key);
    _cache[key] = value;

    return value;
  }

  /// Vložení hodnoty do cache
  void put(K key, V value) {
    // Pokud klíč již existuje, nejprve ho odstraníme
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    }
    // Pokud je cache plný, odstraníme nejstarší položku
    else if (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    // Přidání nové hodnoty
    _cache[key] = value;
  }

  /// Odstranění hodnoty z cache
  void remove(K key) {
    _cache.remove(key);
  }

  /// Vyčištění celé cache
  void clear() {
    _cache.clear();
  }

  /// Aktuální velikost cache
  int get size => _cache.length;
}
