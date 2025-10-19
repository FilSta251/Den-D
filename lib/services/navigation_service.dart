/// lib/services/navigation_service.dart - AKTUALIZACE
library;

import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:easy_localization/easy_localization.dart';
import '../routes.dart';

/// Vylepšená služba pro centrální správu navigace v aplikaci.
///
/// Umožňuje navigaci bez nutnosti mít přístup k kontextu a poskytuje
/// dodatečné metody pro bezpečnou navigaci.
class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Základní navigace na pojmenovanou trasu
  Future<T?> navigateTo<T>(String routeName, {Object? arguments}) {
    try {
      if (navigatorKey.currentState == null) {
        _logError('navigateTo: Navigator není inicializován', routeName);
        return Future.value(null);
      }

      return navigatorKey.currentState!
          .pushNamed<T>(routeName, arguments: arguments);
    } catch (e, stack) {
      _logError('navigateTo: $e', routeName, stack);
      return Future.value(null);
    }
  }

  /// Navigace a odstranění všech předchozích tras
  Future<T?> navigateToAndRemoveUntil<T>(
      String routeName, RoutePredicate predicate,
      {Object? arguments}) {
    try {
      if (navigatorKey.currentState == null) {
        _logError('navigateToAndRemoveUntil: Navigator není inicializován',
            routeName);
        return Future.value(null);
      }

      return navigatorKey.currentState!.pushNamedAndRemoveUntil<T>(
          routeName, predicate,
          arguments: arguments);
    } catch (e, stack) {
      _logError('navigateToAndRemoveUntil: $e', routeName, stack);
      return Future.value(null);
    }
  }

  /// Navigace a odstranění všech předchozích tras (s příznakem)
  Future<T?> navigateToNamed<T>(String routeName,
      {Object? arguments, bool clearStack = false}) {
    if (clearStack) {
      return navigateToAndRemoveUntil<T>(
          routeName, (Route<dynamic> route) => false,
          arguments: arguments);
    } else {
      return navigateTo<T>(routeName, arguments: arguments);
    }
  }

  /// Navigace zpět
  void goBack<T extends Object?>([T? result]) {
    try {
      if (navigatorKey.currentState == null) {
        _logError('goBack: Navigator není inicializován', 'back');
        return;
      }

      if (navigatorKey.currentState!.canPop()) {
        navigatorKey.currentState!.pop<T>(result);
      } else {
        _logError('goBack: Nelze se vrátit zpět, není kde', 'back');
      }
    } catch (e, stack) {
      _logError('goBack: $e', 'back', stack);
    }
  }

  /// Navigace zpět na konkrétní trasu (hledání v zásobníku)
  void goBackToRoute(String routeName) {
    try {
      if (navigatorKey.currentState == null) {
        _logError('goBackToRoute: Navigator není inicializován', routeName);
        return;
      }

      navigatorKey.currentState!
          .popUntil((route) => route.settings.name == routeName);
    } catch (e, stack) {
      _logError('goBackToRoute: $e', routeName, stack);
    }
  }

  /// Navigace na domovskou obrazovku (smazání všech předchozích)
  Future<void> navigateToHome() {
    return navigateToAndRemoveUntil(
      RoutePaths.brideGroomMain,
      (route) => false,
    );
  }

  /// Navigace na přihlašovací obrazovku (po odhlášení)
  Future<void> navigateToLogin() {
    // Před navigací na login vyčistíme cache tras
    RouteGenerator.clearCache();

    return navigateToAndRemoveUntil(
      RoutePaths.auth,
      (route) => false,
    );
  }

  /// Navigace při chybě s možností návratu na domovskou obrazovku
  Future<T?> navigateToError<T>(String errorMessage, {bool allowBack = true}) {
    try {
      if (navigatorKey.currentState == null) {
        _logError('navigateToError: Navigator není inicializován', 'error');
        return Future.value(null);
      }

      return navigatorKey.currentState!.push<T>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: allowBack
                ? AppBar(
                    title: Text('error'.tr()),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => goBack(),
                    ),
                  )
                : null,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'error_occurred'.tr(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    if (!allowBack)
                      ElevatedButton(
                        onPressed: () => navigateToHome(),
                        child: Text('back_to_home'.tr()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e, stack) {
      _logError('navigateToError: $e', 'error', stack);
      return Future.value(null);
    }
  }

  /// Bezpečné replaceování aktuální obrazovky bez vytváření nové v zásobníku
  Future<T?> replaceWith<T>(String routeName, {Object? arguments}) {
    try {
      if (navigatorKey.currentState == null) {
        _logError('replaceWith: Navigator není inicializován', routeName);
        return Future.value(null);
      }

      return navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
        routeName,
        arguments: arguments,
      );
    } catch (e, stack) {
      _logError('replaceWith: $e', routeName, stack);
      return Future.value(null);
    }
  }

  /// Pomocná metoda pro logování chyb navigace
  void _logError(String message, String routeName, [StackTrace? stackTrace]) {
    debugPrint('[NavigationService] $message (Route: $routeName)');
    try {
      FirebaseCrashlytics.instance.recordError(
        Exception('Navigační chyba: $message'),
        stackTrace,
        reason: 'Navigation to $routeName failed',
      );
    } catch (_) {
      // Ignorujeme chyby Crashlytics
    }
  }

  /// Získání aktuálního názvu trasy
  String? getCurrentRouteName() {
    try {
      if (navigatorKey.currentState == null ||
          navigatorKey.currentContext == null) {
        return null;
      }

      Route? currentRoute;
      navigatorKey.currentState!.popUntil((route) {
        currentRoute = route;
        return true;
      });

      return currentRoute?.settings.name;
    } catch (e) {
      debugPrint('[NavigationService] Chyba při získávání aktuální trasy: $e');
      return null;
    }
  }

  /// Metoda pro zálohování navigačního stavu (pro případ obnovení)
  Map<String, dynamic> backupNavigationState() {
    final routes = <String>[];
    final arguments = <Map<String, dynamic>>[];

    try {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.popUntil((route) {
          if (route.settings.name != null) {
            routes.add(route.settings.name!);
            arguments
                .add(route.settings.arguments as Map<String, dynamic>? ?? {});
          }
          return true;
        });
      }
    } catch (e) {
      debugPrint('[NavigationService] Chyba při zálohování stavu navigace: $e');
    }

    return {
      'routes': routes,
      'arguments': arguments,
    };
  }

  /// Metoda pro obnovení navigačního stavu
  Future<void> restoreNavigationState(Map<String, dynamic> state) async {
    try {
      final routes = state['routes'] as List<String>?;
      final arguments = state['arguments'] as List<Map<String, dynamic>>?;

      if (routes == null || arguments == null || routes.isEmpty) {
        return;
      }

      // Nejprve přejdeme na domovskou obrazovku
      await navigateToHome();

      // Poté postupně obnovíme zásobník
      for (int i = routes.length - 1; i >= 0; i--) {
        await navigateTo(routes[i], arguments: arguments[i]);
      }
    } catch (e, stack) {
      _logError('restoreNavigationState: $e', 'restore', stack);
    }
  }
}
