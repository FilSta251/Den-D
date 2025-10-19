/// lib/services/analytics_service.dart - OPRAVENĂ VERZE
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Třída pro centralizovanou správu analytics
///
/// Tato sluťba poskytuje jednotné rozhraní pro logování událostí
/// a metrik v aplikaci.
class AnalyticsService {
  final FirebaseAnalytics _analytics;
  final fb.FirebaseAuth _auth;
  bool _initialized = false;

  // Konstruktor s DI
  AnalyticsService({
    required FirebaseAnalytics analytics,
    required fb.FirebaseAuth auth,
  })  : _analytics = analytics,
        _auth = auth;

  // Alternativní konstruktor pro manuální vytvoření
  AnalyticsService.create()
      : _analytics = FirebaseAnalytics.instance,
        _auth = fb.FirebaseAuth.instance;

  /// Inicializace sluťby
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Nastavení ID uťivatele, pokud je přihláĹˇen
      final user = _auth.currentUser;
      if (user != null) {
        await setUserId(user.uid);
      }

      // Nastavení vlastního parametru pro prostředí
      await _analytics.setDefaultEventParameters({
        'app_environment': kReleaseMode ? 'production' : 'development',
      });

      // Naslouchání na změny stavu přihláĹˇení
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          setUserId(user.uid);
          setUserProperties(
            emailVerified: user.emailVerified,
            provider: user.providerData.isNotEmpty
                ? user.providerData.first.providerId
                : 'unknown',
          );
        } else {
          _analytics.setUserId(id: null);
        }
      });

      _initialized = true;
      debugPrint('[AnalyticsService] Inicializováno');
    } catch (e, stack) {
      debugPrint('[AnalyticsService] Chyba při inicializaci: $e');
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'Analytics Init');
    }
  }

  /// Nastavení ID uťivatele
  Future<void> setUserId(String uid) async {
    try {
      await _analytics.setUserId(id: uid);
    } catch (e) {
      debugPrint('[AnalyticsService] Nepodařilo se nastavit userId: $e');
    }
  }

  /// Nastavení vlastností uťivatele
  Future<void> setUserProperties({
    bool? emailVerified,
    String? provider,
    String? subscriptionType,
    String? userRole,
  }) async {
    try {
      if (emailVerified != null) {
        await _analytics.setUserProperty(
          name: 'email_verified',
          value: emailVerified.toString(),
        );
      }

      if (provider != null) {
        await _analytics.setUserProperty(
          name: 'auth_provider',
          value: provider,
        );
      }

      if (subscriptionType != null) {
        await _analytics.setUserProperty(
          name: 'subscription_type',
          value: subscriptionType,
        );
      }

      if (userRole != null) {
        await _analytics.setUserProperty(
          name: 'user_role',
          value: userRole,
        );
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Nepodařilo se nastavit user property: $e');
    }
  }

  /// Logování změny obrazovky
  Future<void> logScreenView({required String screenName}) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      debugPrint(
          '[AnalyticsService] Zaznamenáno zobrazení obrazovky: $screenName');
    } catch (e) {
      debugPrint('[AnalyticsService] Nepodařilo se zaznamenat screen view: $e');
    }
  }

  /// RozĹˇířenĂ© logování změny obrazovky (s odkud-kam)
  Future<void> logScreenChange({
    String? fromScreen,
    String? toScreen,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'screen_transition',
        parameters: {
          'from_screen': fromScreen ?? 'unknown',
          'to_screen': toScreen ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint(
          '[AnalyticsService] Nepodařilo se zaznamenat screen transition: $e');
    }
  }

  /// Logování přihláĹˇení
  Future<void> logLogin({required String method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('[AnalyticsService] Nepodařilo se zaznamenat login: $e');
    }
  }

  /// Logování registrace
  Future<void> logSignUp({required String method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('[AnalyticsService] Nepodařilo se zaznamenat sign up: $e');
    }
  }

  /// Logování aktualizace předplatnĂ©ho
  Future<void> logSubscriptionUpdated({
    required String level,
    String? oldLevel,
    double? price,
  }) async {
    try {
      final Map<String, Object> parameters = {
        'level': level,
        'old_level': oldLevel ?? 'none',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Přidáme cenu pouze pokud není null
      if (price != null) {
        parameters['price'] = price;
      }

      await _analytics.logEvent(
        name: 'subscription_updated',
        parameters: parameters,
      );

      // Aktualizace user property
      await setUserProperties(subscriptionType: level);
    } catch (e) {
      debugPrint(
          '[AnalyticsService] Nepodařilo se zaznamenat subscription update: $e');
    }
  }

  /// Logování chyby
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? errorContext,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
          'error_context': errorContext ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[AnalyticsService] Nepodařilo se zaznamenat error: $e');
    }
  }

  /// Logování dokončení úkolu
  Future<void> logTaskComplete({
    required String taskId,
    required String taskName,
    required bool isCustomTask,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'task_complete',
        parameters: {
          'task_id': taskId,
          'task_name': taskName,
          'is_custom_task': isCustomTask,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint(
          '[AnalyticsService] Nepodařilo se zaznamenat task_complete: $e');
    }
  }

  /// Logování vytvoření události harmonogramu
  Future<void> logScheduleEventCreated({
    required String eventId,
    required String eventName,
    required DateTime eventTime,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'schedule_event_created',
        parameters: {
          'event_id': eventId,
          'event_name': eventName,
          'event_time': eventTime.toIso8601String(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint(
          '[AnalyticsService] Nepodařilo se zaznamenat schedule_event_created: $e');
    }
  }

  /// Obecná metoda pro logování událostí
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      // Přidání časovĂ©ho razítka, pokud jeĹˇtě není
      final Map<String, Object> params = parameters ?? {};
      if (!params.containsKey('timestamp')) {
        params['timestamp'] = DateTime.now().toIso8601String();
      }

      await _analytics.logEvent(
        name: name,
        parameters: params,
      );
    } catch (e) {
      debugPrint(
          '[AnalyticsService] Nepodařilo se zaznamenat událost $name: $e');
    }
  }

  /// Logování výkonu (např. doba trvání operace)
  Future<void> logPerformanceMetric({
    required String metricName,
    required int durationMs,
    Map<String, Object>? additionalParams,
  }) async {
    try {
      final Map<String, Object> params = additionalParams ?? {};
      params['duration_ms'] = durationMs;
      params['timestamp'] = DateTime.now().toIso8601String();

      await _analytics.logEvent(
        name: 'performance_metric',
        parameters: params,
      );
    } catch (e) {
      debugPrint(
          '[AnalyticsService] Nepodařilo se zaznamenat metriku $metricName: $e');
    }
  }
}
