/// lib/services/analytics_service.dart
///
/// Kompletní Analytics Service pro měření konverzí Google Ads,
/// user engagement, funnel tracking a remarketing.
///
/// Implementuje "gold standard" tracking s deduplikací.
/// AKTUALIZOVÁNO: Integrace App Tracking Transparency pro iOS
library;

import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_tracking_service.dart';

/// Service pro Google Analytics / Firebase Analytics eventy
///
/// Poskytuje metody pro:
/// - Purchase tracking (s deduplikací a server-side validací)
/// - User properties (pro segmentaci v GA4 a Google Ads)
/// - Funnel tracking (sledování konverzního trychtýře)
/// - Feature engagement (které funkce jsou populární)
/// - Timing events (kdy uživatelé konvertují)
/// - Remarketing audiences (pro Google Ads)
///
/// DŮLEŽITÉ: logPurchase volat pouze po server-side ověření nákupu!
class AnalyticsService {
  // Singleton instance
  static final AnalyticsService _instance = AnalyticsService._internal();

  /// Factory konstruktor - singleton pattern
  /// Parametry [analytics] a [auth] jsou volitelné pro zpětnou kompatibilitu
  /// s DI (service_locator), ale interně používá vlastní instance
  factory AnalyticsService({
    FirebaseAnalytics? analytics,
    FirebaseAuth? auth,
  }) {
    // Pokud jsou předány instance, můžeme je použít pro inicializaci
    // ale singleton pattern zajistí konzistenci
    return _instance;
  }

  AnalyticsService._internal();

  // Firebase Analytics instance
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Klíče pro SharedPreferences
  static const String _lastLoggedOrderIdKey = 'analytics_last_logged_order_id';
  static const String _installDateKey = 'analytics_install_date';
  static const String _firstSessionKey = 'analytics_first_session';
  static const String _sessionCountKey = 'analytics_session_count';
  static const String _lastSessionKey = 'analytics_last_session';

  // Cache pro deduplikaci v rámci session
  final Set<String> _loggedOrderIds = {};

  // Session tracking
  DateTime? _sessionStartTime;
  int _sessionCount = 0;
  bool _isInitialized = false;

  // ATT (App Tracking Transparency) - POVINNÉ PRO iOS
  final AppTrackingService _attService = AppTrackingService();
  bool _isTrackingAllowed = true; // Default pro Android

  /// Getter pro ATT status
  bool get isTrackingAllowed => _isTrackingAllowed;

  /// Getter pro ATT service (pro UI)
  AppTrackingService get attService => _attService;

  // ============================================================
  // INICIALIZACE
  // ============================================================

  /// Inicializuje Analytics Service
  ///
  /// - Inicializuje App Tracking Transparency (iOS)
  /// - Načte poslední zalogované orderId pro deduplikaci
  /// - Inicializuje session tracking
  /// - Nastaví install date při prvním spuštění
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[AnalyticsService] Already initialized');
      return;
    }

    try {
      // NOVÉ: Inicializace ATT pro iOS - POVINNÉ PRO APP STORE
      if (Platform.isIOS) {
        await _attService.initialize();
        _isTrackingAllowed = _attService.isTrackingAuthorized ||
            _attService.status == AppTrackingStatus.notDetermined;
        debugPrint(
            '[AnalyticsService] ATT status: ${_attService.status}, tracking allowed: $_isTrackingAllowed');
      }

      final prefs = await SharedPreferences.getInstance();

      // Načtení posledního orderId pro deduplikaci
      final lastOrderId = prefs.getString(_lastLoggedOrderIdKey);
      if (lastOrderId != null && lastOrderId.isNotEmpty) {
        _loggedOrderIds.add(lastOrderId);
        debugPrint(
            '[AnalyticsService] Loaded last logged orderId: $lastOrderId');
      }

      // Install date tracking
      final installDate = prefs.getString(_installDateKey);
      if (installDate == null) {
        await prefs.setString(
            _installDateKey, DateTime.now().toIso8601String());
        debugPrint('[AnalyticsService] First install detected');
      }

      // Session tracking
      _sessionCount = prefs.getInt(_sessionCountKey) ?? 0;
      _sessionCount++;
      await prefs.setInt(_sessionCountKey, _sessionCount);
      _sessionStartTime = DateTime.now();
      await prefs.setString(
          _lastSessionKey, _sessionStartTime!.toIso8601String());

      _isInitialized = true;
      debugPrint('[AnalyticsService] Initialized (session #$_sessionCount)');

      // Log session start
      await logSessionStart();
    } catch (e) {
      debugPrint('[AnalyticsService] Error during initialization: $e');
    }
  }

  /// Požádá o ATT povolení na iOS
  ///
  /// DŮLEŽITÉ: Volat po zobrazení vysvětlení uživateli,
  /// ideálně při prvním spuštění nebo před prvním trackingem.
  Future<AppTrackingStatus> requestTrackingAuthorization() async {
    if (!Platform.isIOS) {
      return AppTrackingStatus.notSupported;
    }

    final status = await _attService.requestTrackingAuthorization();
    _isTrackingAllowed = status == AppTrackingStatus.authorized;

    debugPrint(
        '[AnalyticsService] ATT authorization result: $status, tracking allowed: $_isTrackingAllowed');

    return status;
  }

  // ============================================================
  // OBECNÉ LOGOVÁNÍ (zpětná kompatibilita)
  // ============================================================

  /// Loguje obecný event - pro zpětnou kompatibilitu
  ///
  /// [name] - název eventu (např. 'login_email', 'button_click')
  /// [parameters] - volitelné parametry
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      // Na iOS respektujeme ATT volbu
      if (Platform.isIOS && !_isTrackingAllowed) {
        debugPrint('[AnalyticsService] Skipping event $name - tracking not allowed');
        return;
      }

      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('[AnalyticsService] Logged event: $name');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging event $name: $e');
    }
  }

  /// Loguje zobrazení obrazovky
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      debugPrint('[AnalyticsService] Logged screen_view: $screenName');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging screen_view: $e');
    }
  }

  // ============================================================
  // PURCHASE TRACKING (Google Ads Conversions)
  // ============================================================

  /// Loguje zobrazení paywall/subscription stránky
  ///
  /// [source] - odkud uživatel přišel (např. 'onboarding', 'settings', 'feature_gate')
  /// [screen] - název obrazovky (např. 'subscription_page', 'subscription_dialog')
  Future<void> logPaywallView({
    required String source,
    required String screen,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'paywall_view',
        parameters: {
          'source': source,
          'screen': screen,
          'session_number': _sessionCount,
        },
      );

      debugPrint(
          '[AnalyticsService] Logged paywall_view: source=$source, screen=$screen');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging paywall_view: $e');
    }
  }

  /// Loguje zahájení checkout procesu
  ///
  /// [plan] - typ plánu (např. 'premium_yearly')
  /// [productId] - ID produktu z Google Play/App Store
  /// [price] - cena produktu (volitelná)
  /// [currency] - měna (volitelná, default CZK)
  Future<void> logBeginCheckout({
    required String plan,
    required String productId,
    double? price,
    String currency = 'CZK',
  }) async {
    try {
      await _analytics.logBeginCheckout(
        currency: currency,
        value: price ?? 0,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: plan,
            itemCategory: 'subscription',
            price: price,
            quantity: 1,
          ),
        ],
      );

      debugPrint(
          '[AnalyticsService] Logged begin_checkout: plan=$plan, productId=$productId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging begin_checkout: $e');
    }
  }

  /// Loguje úspěšný nákup - VOLAT POUZE PO SERVER-SIDE OVĚŘENÍ!
  ///
  /// Implementuje deduplikaci pomocí orderId:
  /// - Kontroluje local storage pro persistentní deduplikaci
  /// - Kontroluje in-memory cache pro session deduplikaci
  ///
  /// [orderId] - unikátní ID objednávky z Google Play
  /// [productId] - ID produktu
  /// [price] - cena v měně (např. 199.0)
  /// [currency] - měna (např. 'CZK')
  ///
  /// Vrací true pokud byl event zalogován, false pokud byl deduplikován
  Future<bool> logPurchase({
    required String orderId,
    required String productId,
    required double price,
    required String currency,
  }) async {
    // Validace orderId
    if (orderId.isEmpty) {
      debugPrint('[AnalyticsService] Cannot log purchase: empty orderId');
      return false;
    }

    // DEDUPLIKACE: Kontrola v in-memory cache
    if (_loggedOrderIds.contains(orderId)) {
      debugPrint(
          '[AnalyticsService] Purchase already logged (memory cache): $orderId');
      return false;
    }

    // DEDUPLIKACE: Kontrola v local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOrderId = prefs.getString(_lastLoggedOrderIdKey);

      if (lastOrderId == orderId) {
        debugPrint(
            '[AnalyticsService] Purchase already logged (local storage): $orderId');
        _loggedOrderIds.add(orderId);
        return false;
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error checking dedupe storage: $e');
    }

    // LOGOVÁNÍ: Firebase Analytics purchase event
    try {
      await _analytics.logPurchase(
        transactionId: orderId,
        currency: currency,
        value: price,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: _getProductName(productId),
            itemCategory: 'subscription',
            price: price,
            quantity: 1,
          ),
        ],
      );

      debugPrint('[AnalyticsService] Logged purchase: '
          'orderId=$orderId, productId=$productId, price=$price $currency');

      // Log timing metrics
      await _logConversionTiming();

      // ULOŽENÍ: Aktualizace deduplikace
      _loggedOrderIds.add(orderId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastLoggedOrderIdKey, orderId);

      // Update user property
      await setSubscriptionTier('premium');

      debugPrint('[AnalyticsService] Saved orderId for dedupe: $orderId');

      return true;
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging purchase: $e');
      return false;
    }
  }

  /// Loguje obnovení předplatného (restore) - BEZ conversion tracking
  ///
  /// Pouze pro analytické účely, NENÍ to konverze pro Google Ads
  Future<void> logRestorePurchase({
    required String productId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'restore_purchase',
        parameters: {
          'product_id': productId,
        },
      );

      await setSubscriptionTier('premium');

      debugPrint('[AnalyticsService] Logged restore_purchase: $productId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging restore_purchase: $e');
    }
  }

  /// Loguje chybu při nákupu
  Future<void> logPurchaseError({
    required String productId,
    required String error,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'purchase_error',
        parameters: {
          'product_id': productId,
          'error': error.length > 100 ? error.substring(0, 100) : error,
        },
      );

      debugPrint(
          '[AnalyticsService] Logged purchase_error: $productId - $error');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging purchase_error: $e');
    }
  }

  /// Loguje zrušení nákupu uživatelem
  Future<void> logPurchaseCanceled({
    required String productId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'purchase_canceled',
        parameters: {
          'product_id': productId,
        },
      );

      debugPrint('[AnalyticsService] Logged purchase_canceled: $productId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging purchase_canceled: $e');
    }
  }

  // ============================================================
  // USER PROPERTIES (pro segmentaci v GA4 a Google Ads)
  // ============================================================

  /// Nastaví user ID pro cross-device tracking
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('[AnalyticsService] Set userId: $userId');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting userId: $e');
    }
  }

  /// Nastaví user property pro subscription tier (free/premium)
  Future<void> setSubscriptionTier(String tier) async {
    try {
      await _analytics.setUserProperty(name: 'subscription_tier', value: tier);
      debugPrint('[AnalyticsService] Set subscription_tier: $tier');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting subscription_tier: $e');
    }
  }

  /// Nastaví počet dní do svatby - pro cílení reklam
  Future<void> setDaysUntilWedding(int? days) async {
    try {
      String value;
      if (days == null) {
        value = 'not_set';
      } else if (days < 0) {
        value = 'past';
      } else if (days <= 30) {
        value = '0-30';
      } else if (days <= 90) {
        value = '31-90';
      } else if (days <= 180) {
        value = '91-180';
      } else if (days <= 365) {
        value = '181-365';
      } else {
        value = '365+';
      }

      await _analytics.setUserProperty(
          name: 'days_until_wedding', value: value);
      debugPrint('[AnalyticsService] Set days_until_wedding: $value');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting days_until_wedding: $e');
    }
  }

  /// Nastaví velikost svatby (počet hostů) - pro segmentaci
  Future<void> setGuestCount(int? count) async {
    try {
      String value;
      if (count == null) {
        value = 'not_set';
      } else if (count <= 20) {
        value = '1-20';
      } else if (count <= 50) {
        value = '21-50';
      } else if (count <= 100) {
        value = '51-100';
      } else if (count <= 150) {
        value = '101-150';
      } else {
        value = '150+';
      }

      await _analytics.setUserProperty(name: 'guest_count', value: value);
      debugPrint('[AnalyticsService] Set guest_count: $value');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting guest_count: $e');
    }
  }

  /// Nastaví rozpočet svatby - pro segmentaci
  Future<void> setBudgetRange(double? budget) async {
    try {
      String value;
      if (budget == null) {
        value = 'not_set';
      } else if (budget <= 100000) {
        value = '0-100k';
      } else if (budget <= 200000) {
        value = '100-200k';
      } else if (budget <= 300000) {
        value = '200-300k';
      } else if (budget <= 500000) {
        value = '300-500k';
      } else {
        value = '500k+';
      }

      await _analytics.setUserProperty(name: 'budget_range', value: value);
      debugPrint('[AnalyticsService] Set budget_range: $value');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting budget_range: $e');
    }
  }

  /// Nastaví jazyk uživatele
  Future<void> setUserLanguage(String languageCode) async {
    try {
      await _analytics.setUserProperty(
          name: 'app_language', value: languageCode);
      debugPrint('[AnalyticsService] Set app_language: $languageCode');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting app_language: $e');
    }
  }

  /// Nastaví zemi uživatele
  Future<void> setUserCountry(String countryCode) async {
    try {
      await _analytics.setUserProperty(
          name: 'user_country', value: countryCode);
      debugPrint('[AnalyticsService] Set user_country: $countryCode');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting user_country: $e');
    }
  }

  /// Nastaví stav onboardingu
  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      await _analytics.setUserProperty(
        name: 'onboarding_completed',
        value: completed ? 'true' : 'false',
      );
      debugPrint('[AnalyticsService] Set onboarding_completed: $completed');
    } catch (e) {
      debugPrint('[AnalyticsService] Error setting onboarding_completed: $e');
    }
  }

  // ============================================================
  // FUNNEL TRACKING (sledování konverzního trychtýře)
  // ============================================================

  /// Loguje krok v konverzním funnelu
  ///
  /// Kroky: registration → onboarding_start → onboarding_complete →
  /// feature_used_first → paywall_view → purchase_started → purchase_completed
  Future<void> logFunnelStep(String step) async {
    try {
      await _analytics.logEvent(
        name: 'funnel_step',
        parameters: {
          'step': step,
          'session_number': _sessionCount,
        },
      );
      debugPrint('[AnalyticsService] Logged funnel_step: $step');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging funnel_step: $e');
    }
  }

  /// Loguje dokončení registrace
  Future<void> logRegistration({String method = 'email'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      await logFunnelStep('registration');
      debugPrint('[AnalyticsService] Logged registration: $method');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging registration: $e');
    }
  }

  /// Loguje přihlášení
  Future<void> logLogin({String method = 'email'}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      debugPrint('[AnalyticsService] Logged login: $method');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging login: $e');
    }
  }

  /// Loguje začátek onboardingu
  Future<void> logOnboardingStart() async {
    await logFunnelStep('onboarding_start');
  }

  /// Loguje dokončení onboardingu
  Future<void> logOnboardingComplete() async {
    await logFunnelStep('onboarding_complete');
    await setOnboardingCompleted(true);
  }

  /// Loguje opuštění onboardingu
  Future<void> logOnboardingSkipped({String? atStep}) async {
    try {
      await _analytics.logEvent(
        name: 'onboarding_skipped',
        parameters: {
          'at_step': atStep ?? 'unknown',
        },
      );
      debugPrint('[AnalyticsService] Logged onboarding_skipped: $atStep');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging onboarding_skipped: $e');
    }
  }

  // ============================================================
  // FEATURE ENGAGEMENT (které funkce jsou populární)
  // ============================================================

  /// Loguje použití funkce
  ///
  /// [feature] - název funkce: 'checklist', 'budget', 'guests',
  /// 'calendar', 'schedule', 'chatbot', 'suppliers'
  Future<void> logFeatureUsed(String feature) async {
    try {
      await _analytics.logEvent(
        name: 'feature_used',
        parameters: {
          'feature': feature,
          'session_number': _sessionCount,
        },
      );
      debugPrint('[AnalyticsService] Logged feature_used: $feature');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging feature_used: $e');
    }
  }

  /// Loguje první použití funkce (milestone)
  Future<void> logFeatureUsedFirst(String feature) async {
    try {
      await _analytics.logEvent(
        name: 'feature_used_first',
        parameters: {
          'feature': feature,
        },
      );
      await logFunnelStep('feature_used_first');
      debugPrint('[AnalyticsService] Logged feature_used_first: $feature');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging feature_used_first: $e');
    }
  }

  /// Loguje přidání položky (host, úkol, výdaj, událost)
  Future<void> logItemAdded({
    required String itemType,
    int? totalCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'item_added',
        parameters: {
          'item_type': itemType,
          if (totalCount != null) 'total_count': totalCount,
        },
      );
      debugPrint('[AnalyticsService] Logged item_added: $itemType');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging item_added: $e');
    }
  }

  /// Loguje dosažení milníku (např. 10 hostů, 50% úkolů)
  Future<void> logMilestoneReached({
    required String milestone,
    required String feature,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'milestone_reached',
        parameters: {
          'milestone': milestone,
          'feature': feature,
        },
      );
      debugPrint(
          '[AnalyticsService] Logged milestone_reached: $milestone in $feature');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging milestone_reached: $e');
    }
  }

  // ============================================================
  // SESSION & TIMING TRACKING
  // ============================================================

  /// Loguje začátek session
  Future<void> logSessionStart() async {
    try {
      await _analytics.logEvent(
        name: 'session_start_custom',
        parameters: {
          'session_number': _sessionCount,
        },
      );
      debugPrint('[AnalyticsService] Logged session_start: #$_sessionCount');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging session_start: $e');
    }
  }

  /// Loguje konec session s délkou trvání
  Future<void> logSessionEnd() async {
    try {
      final duration = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 0;

      await _analytics.logEvent(
        name: 'session_end',
        parameters: {
          'session_number': _sessionCount,
          'duration_seconds': duration,
        },
      );
      debugPrint('[AnalyticsService] Logged session_end: ${duration}s');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging session_end: $e');
    }
  }

  /// Interní: Loguje časové metriky při konverzi
  Future<void> _logConversionTiming() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final installDateStr = prefs.getString(_installDateKey);

      if (installDateStr != null) {
        final installDate = DateTime.parse(installDateStr);
        final daysToConversion = DateTime.now().difference(installDate).inDays;

        await _analytics.logEvent(
          name: 'conversion_timing',
          parameters: {
            'days_to_conversion': daysToConversion,
            'sessions_to_conversion': _sessionCount,
          },
        );

        debugPrint('[AnalyticsService] Conversion timing: '
            '$daysToConversion days, $_sessionCount sessions');
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging conversion_timing: $e');
    }
  }

  // ============================================================
  // CHURN & RETENTION SIGNALS
  // ============================================================

  /// Loguje varování o neaktivitě (volat při zjištění dlouhé neaktivity)
  Future<void> logInactivityWarning(int daysSinceLastSession) async {
    try {
      await _analytics.logEvent(
        name: 'inactivity_warning',
        parameters: {
          'days_inactive': daysSinceLastSession,
        },
      );
      debugPrint(
          '[AnalyticsService] Logged inactivity_warning: $daysSinceLastSession days');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging inactivity_warning: $e');
    }
  }

  /// Loguje návrat po dlouhé neaktivitě
  Future<void> logUserReturned(int daysInactive) async {
    try {
      await _analytics.logEvent(
        name: 'user_returned',
        parameters: {
          'days_inactive': daysInactive,
        },
      );
      debugPrint(
          '[AnalyticsService] Logged user_returned after $daysInactive days');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging user_returned: $e');
    }
  }

  /// Kontroluje a loguje návrat uživatele
  Future<void> checkAndLogUserReturn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSessionStr = prefs.getString(_lastSessionKey);

      if (lastSessionStr != null) {
        final lastSession = DateTime.parse(lastSessionStr);
        final daysInactive = DateTime.now().difference(lastSession).inDays;

        if (daysInactive >= 7) {
          await logUserReturned(daysInactive);
        }
      }
    } catch (e) {
      debugPrint('[AnalyticsService] Error checking user return: $e');
    }
  }

  // ============================================================
  // REMARKETING AUDIENCES
  // ============================================================

  /// Označí uživatele pro remarketing audience
  ///
  /// [audience] - název audience:
  /// - 'viewed_paywall_no_purchase'
  /// - 'premium_user_expiring'
  /// - 'high_engagement_free_user'
  /// - 'wedding_in_30_days'
  /// - 'abandoned_onboarding'
  Future<void> markForRemarketing(String audience) async {
    try {
      await _analytics.logEvent(
        name: 'remarketing_audience',
        parameters: {
          'audience': audience,
        },
      );

      // Také nastavit jako user property pro trvalou segmentaci
      await _analytics.setUserProperty(
        name: 'remarketing_$audience',
        value: 'true',
      );

      debugPrint('[AnalyticsService] Marked for remarketing: $audience');
    } catch (e) {
      debugPrint('[AnalyticsService] Error marking for remarketing: $e');
    }
  }

  /// Odstraní uživatele z remarketing audience (např. po nákupu)
  Future<void> removeFromRemarketing(String audience) async {
    try {
      await _analytics.setUserProperty(
        name: 'remarketing_$audience',
        value: null,
      );
      debugPrint('[AnalyticsService] Removed from remarketing: $audience');
    } catch (e) {
      debugPrint('[AnalyticsService] Error removing from remarketing: $e');
    }
  }

  // ============================================================
  // TRIAL TRACKING
  // ============================================================

  /// Loguje začátek trial období
  Future<void> logTrialStarted() async {
    try {
      await _analytics.logEvent(name: 'trial_started');
      await _analytics.setUserProperty(name: 'trial_user', value: 'true');
      debugPrint('[AnalyticsService] Logged trial_started');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging trial_started: $e');
    }
  }

  /// Loguje konverzi z trialu
  Future<void> logTrialConverted() async {
    try {
      await _analytics.logEvent(name: 'trial_converted');
      await _analytics.setUserProperty(name: 'trial_user', value: null);
      await removeFromRemarketing('trial_expiring');
      debugPrint('[AnalyticsService] Logged trial_converted');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging trial_converted: $e');
    }
  }

  /// Loguje vypršení trialu bez konverze
  Future<void> logTrialExpired() async {
    try {
      await _analytics.logEvent(name: 'trial_expired');
      await _analytics.setUserProperty(name: 'trial_user', value: 'expired');
      await markForRemarketing('trial_expired_no_conversion');
      debugPrint('[AnalyticsService] Logged trial_expired');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging trial_expired: $e');
    }
  }

  // ============================================================
  // ERROR & CRASH TRACKING
  // ============================================================

  /// Loguje zachycenou chybu (ne-fatální)
  Future<void> logError({
    required String errorType,
    required String message,
    String? screen,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'message': message.length > 100 ? message.substring(0, 100) : message,
          if (screen != null) 'screen': screen,
        },
      );
      debugPrint('[AnalyticsService] Logged app_error: $errorType');
    } catch (e) {
      debugPrint('[AnalyticsService] Error logging app_error: $e');
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Helper: Získá čitelný název produktu
  String _getProductName(String productId) {
    if (productId.contains('yearly')) {
      return 'Premium Roční';
    } else if (productId.contains('monthly')) {
      return 'Premium Měsíční';
    }
    return 'Premium';
  }

  /// Getter pro Firebase Analytics Observer (pro navigaci)
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Getter pro počet sessions
  int get sessionCount => _sessionCount;

  /// Getter pro kontrolu inicializace
  bool get isInitialized => _isInitialized;
}
