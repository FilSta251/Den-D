// lib/services/environment_config.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart';

/// Typ prostředí aplikace
enum Environment {
  development,
  staging,
  production,
}

/// Úroveň logování
enum LogLevel {
  debug,
  info,
  warning,
  error,
  none,
}

/// Konfigurace prostředí pro produkční aplikaci Svatební plánovač
class EnvironmentConfig {
  // Singleton instance
  static final EnvironmentConfig _instance = EnvironmentConfig._internal();
  factory EnvironmentConfig() => _instance;
  EnvironmentConfig._internal();

  // Současné prostředí
  late Environment _environment;
  
  // Konfigurace načtená z JSON
  late Map<String, dynamic> _config;
  
  // Cache pro hodnoty
  final Map<String, dynamic> _cache = {};
  
  // Indikace inicializace
  bool _initialized = false;

  /// Inicializuje konfiguraci prostředí
  Future<void> initialize({
    Environment? environment,
    String? configPath,
  }) async {
    if (_initialized) return;

    try {
      // Určení prostředí
      _environment = environment ?? _determineEnvironment();
      
      // Načtení konfigurace
      final path = configPath ?? 'assets/config/${_environment.name}.json';
      final jsonString = await rootBundle.loadString(path);
      _config = json.decode(jsonString);
      
      // Validace konfigurace
      _validateConfig();
      
      _initialized = true;
      debugPrint('[EnvironmentConfig] Initialized for ${_environment.name} environment');
    } catch (e) {
      debugPrint('[EnvironmentConfig] Failed to load config: $e');
      // Fallback na výchozí konfiguraci
      _loadDefaultConfig();
      _initialized = true;
    }
  }

  /// Určí prostředí na základě různých faktorů
  Environment _determineEnvironment() {
    // Kontrola --dart-define
    const envString = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
    
    switch (envString.toLowerCase()) {
      case 'development':
      case 'dev':
        return Environment.development;
      case 'staging':
      case 'stage':
        return Environment.staging;
      case 'production':
      case 'prod':
      default:
        return Environment.production;
    }
  }

  /// Načte výchozí konfiguraci jako fallback
  void _loadDefaultConfig() {
    _environment = Environment.production;
    _config = _getDefaultProductionConfig();
  }

  /// Validuje načtenou konfiguraci
  void _validateConfig() {
    final requiredKeys = [
      'firebase',
      'api',
      'features',
      'security',
      'limits',
    ];
    
    for (final key in requiredKeys) {
      if (!_config.containsKey(key)) {
        throw ConfigurationException('Missing required configuration key: $key');
      }
    }
  }

  /// Získá hodnotu z konfigurace
  T getValue<T>(String key, {T? defaultValue}) {
    if (!_initialized) {
      throw ConfigurationException('EnvironmentConfig not initialized');
    }

    // Kontrola cache
    if (_cache.containsKey(key)) {
      return _cache[key] as T;
    }

    // Navigace přes tečkovou notaci
    final keys = key.split('.');
    dynamic value = _config;
    
    for (final k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return defaultValue ?? _getDefaultValue<T>(key);
      }
    }

    // Uložení do cache
    _cache[key] = value;
    
    return value as T;
  }

  /// Vrací výchozí hodnotu pro klíč
  T _getDefaultValue<T>(String key) {
    final defaults = _getDefaultProductionConfig();
    final keys = key.split('.');
    dynamic value = defaults;
    
    for (final k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        throw ConfigurationException('No default value for key: $key');
      }
    }
    
    return value as T;
  }

  // === GETTERY PRO BĚŽNÉ HODNOTY ===

  Environment get environment => _environment;
  bool get isProduction => _environment == Environment.production;
  bool get isStaging => _environment == Environment.staging;
  bool get isDevelopment => _environment == Environment.development;
  bool get isDebug => isDevelopment && kDebugMode;

  // Firebase konfigurace
  String get firebaseApiKey => getValue('firebase.apiKey', defaultValue: '');
  String get firebaseAuthDomain => getValue('firebase.authDomain', defaultValue: '');
  String get firebaseProjectId => getValue('firebase.projectId', defaultValue: '');
  String get firebaseStorageBucket => getValue('firebase.storageBucket', defaultValue: '');
  String get firebaseMessagingSenderId => getValue('firebase.messagingSenderId', defaultValue: '');
  String get firebaseAppId => getValue('firebase.appId', defaultValue: '');
  String get firebaseMeasurementId => getValue('firebase.measurementId', defaultValue: '');
  
  // iOS specifické
  String get firebaseIosApiKey => getValue('firebase.ios.apiKey', defaultValue: firebaseApiKey);
  String get firebaseIosAppId => getValue('firebase.ios.appId', defaultValue: firebaseAppId);
  String get firebaseIosBundleId => getValue('firebase.ios.bundleId', defaultValue: 'com.svatebni.planovac');

  // API konfigurace
  String get apiBaseUrl => getValue('api.baseUrl', defaultValue: 'https://api.svatebni-planovac.cz');
  String get apiVersion => getValue('api.version', defaultValue: 'v1');
  int get apiTimeoutSeconds => getValue('api.timeoutSeconds', defaultValue: 30);
  int get apiMaxRetries => getValue('api.maxRetries', defaultValue: 3);
  Map<String, String> get apiHeaders => Map<String, String>.from(
    getValue('api.headers', defaultValue: <String, String>{}),
  );

  // Feature flags
  bool get enableCrashlytics => getValue('features.crashlytics', defaultValue: true);
  bool get enableAnalytics => getValue('features.analytics', defaultValue: true);
  bool get enablePerformanceMonitoring => getValue('features.performanceMonitoring', defaultValue: true);
  bool get enableBiometricAuth => getValue('features.biometricAuth', defaultValue: true);
  bool get enablePushNotifications => getValue('features.pushNotifications', defaultValue: true);
  bool get enableOfflineMode => getValue('features.offlineMode', defaultValue: true);
  bool get enableDebugLogging => getValue('features.debugLogging', defaultValue: !isProduction);
  bool get enableRemoteConfig => getValue('features.remoteConfig', defaultValue: true);
  bool get enableInAppPurchases => getValue('features.inAppPurchases', defaultValue: true);
  bool get enableSocialLogin => getValue('features.socialLogin', defaultValue: true);
  bool get enableGoogleMaps => getValue('features.googleMaps', defaultValue: true);
  bool get enableImageUpload => getValue('features.imageUpload', defaultValue: true);

  // Bezpečnostní konfigurace
  int get minPasswordLength => getValue('security.minPasswordLength', defaultValue: 8);
  int get maxLoginAttempts => getValue('security.maxLoginAttempts', defaultValue: 5);
  int get sessionTimeoutMinutes => getValue('security.sessionTimeoutMinutes', defaultValue: 30);
  int get tokenRefreshMinutes => getValue('security.tokenRefreshMinutes', defaultValue: 15);
  bool get requireEmailVerification => getValue('security.requireEmailVerification', defaultValue: true);
  bool get enableEncryption => getValue('security.enableEncryption', defaultValue: true);
  int get encryptionKeyRotationDays => getValue('security.encryptionKeyRotationDays', defaultValue: 90);
  List<String> get allowedDomains => List<String>.from(
    getValue('security.allowedDomains', defaultValue: ['svatebni-planovac.cz']),
  );

  // Limity a omezení
  int get maxImageSizeMB => getValue('limits.maxImageSizeMB', defaultValue: 5);
  int get maxVideoSizeMB => getValue('limits.maxVideoSizeMB', defaultValue: 50);
  int get maxAttachmentSizeMB => getValue('limits.maxAttachmentSizeMB', defaultValue: 10);
  int get maxGuestCount => getValue('limits.maxGuestCount', defaultValue: 1000);
  int get maxTaskCount => getValue('limits.maxTaskCount', defaultValue: 500);
  int get maxBudgetItems => getValue('limits.maxBudgetItems', defaultValue: 200);
  int get maxPhotosPerAlbum => getValue('limits.maxPhotosPerAlbum', defaultValue: 100);
  int get maxVendors => getValue('limits.maxVendors', defaultValue: 50);
  int get cacheExpirationDays => getValue('limits.cacheExpirationDays', defaultValue: 7);
  int get offlineDataRetentionDays => getValue('limits.offlineDataRetentionDays', defaultValue: 30);

  // Předplatné konfigurace
  double get monthlySubscriptionPrice => getValue('subscription.monthlyPrice', defaultValue: 120.0);
  double get yearlySubscriptionPrice => getValue('subscription.yearlyPrice', defaultValue: 800.0);
  int get trialDurationDays => getValue('subscription.trialDays', defaultValue: 14);
  bool get offerFreeTrial => getValue('subscription.offerFreeTrial', defaultValue: true);
  String get stripePlanIdMonthly => getValue('subscription.stripePlanIdMonthly', defaultValue: '');
  String get stripePlanIdYearly => getValue('subscription.stripePlanIdYearly', defaultValue: '');
  String get googlePlayProductIdMonthly => getValue('subscription.googlePlayProductIdMonthly', defaultValue: '');
  String get googlePlayProductIdYearly => getValue('subscription.googlePlayProductIdYearly', defaultValue: '');
  String get appStoreProductIdMonthly => getValue('subscription.appStoreProductIdMonthly', defaultValue: '');
  String get appStoreProductIdYearly => getValue('subscription.appStoreProductIdYearly', defaultValue: '');

  // Notifikace konfigurace
  String get fcmServerKey => getValue('notifications.fcmServerKey', defaultValue: '');
  int get notificationReminderHours => getValue('notifications.reminderHours', defaultValue: 24);
  bool get enableEmailNotifications => getValue('notifications.enableEmail', defaultValue: true);
  bool get enableSmsNotifications => getValue('notifications.enableSms', defaultValue: false);
  String get defaultNotificationSound => getValue('notifications.defaultSound', defaultValue: 'default');

  // Externí služby
  String get sentryDsn => getValue('external.sentryDsn', defaultValue: '');
  String get googleMapsApiKey => getValue('external.googleMapsApiKey', defaultValue: '');
  String get stripePublishableKey => getValue('external.stripePublishableKey', defaultValue: '');
  String get mixpanelToken => getValue('external.mixpanelToken', defaultValue: '');
  String get oneSignalAppId => getValue('external.oneSignalAppId', defaultValue: '');
  String get cloudinaryCloudName => getValue('external.cloudinaryCloudName', defaultValue: '');
  String get cloudinaryApiKey => getValue('external.cloudinaryApiKey', defaultValue: '');

  // UI konfigurace
  String get defaultLanguage => getValue('ui.defaultLanguage', defaultValue: 'cs');
  List<String> get supportedLanguages => List<String>.from(
    getValue('ui.supportedLanguages', defaultValue: ['cs', 'en']),
  );
  String get dateFormat => getValue('ui.dateFormat', defaultValue: 'dd.MM.yyyy');
  String get timeFormat => getValue('ui.timeFormat', defaultValue: 'HH:mm');
  bool get use24HourFormat => getValue('ui.use24HourFormat', defaultValue: true);
  String get defaultTheme => getValue('ui.defaultTheme', defaultValue: 'system');

  // Cache konfigurace
  int get httpCacheMaxAge => getValue('cache.httpMaxAge', defaultValue: 3600);
  int get imageCacheMaxCount => getValue('cache.imageMaxCount', defaultValue: 100);
  int get imageCacheMaxSizeMB => getValue('cache.imageMaxSizeMB', defaultValue: 50);
  bool get enableAggressiveCaching => getValue('cache.enableAggressive', defaultValue: !isDevelopment);

  // Logování
  LogLevel get logLevel {
    final levelString = getValue('logging.level', defaultValue: 'info');
    return LogLevel.values.firstWhere(
      (l) => l.name == levelString,
      orElse: () => LogLevel.info,
    );
  }
  bool get logToFile => getValue('logging.toFile', defaultValue: isProduction);
  int get logRetentionDays => getValue('logging.retentionDays', defaultValue: 7);
  int get maxLogFileSizeMB => getValue('logging.maxFileSizeMB', defaultValue: 10);

  // Aplikační metadata
  String get appName => getValue('app.name', defaultValue: 'Svatební plánovač');
  String get appVersion => getValue('app.version', defaultValue: '1.0.0');
  String get buildNumber => getValue('app.buildNumber', defaultValue: '1');
  String get packageName => getValue('app.packageName', defaultValue: 'com.svatebni.planovac');
  String get appStoreId => getValue('app.appStoreId', defaultValue: '');
  String get playStoreUrl => getValue('app.playStoreUrl', defaultValue: '');
  String get websiteUrl => getValue('app.websiteUrl', defaultValue: 'https://svatebni-planovac.cz');
  String get supportEmail => getValue('app.supportEmail', defaultValue: 'podpora@svatebni-planovac.cz');
  String get privacyPolicyUrl => getValue('app.privacyPolicyUrl', defaultValue: 'https://svatebni-planovac.cz/privacy');
  String get termsOfServiceUrl => getValue('app.termsOfServiceUrl', defaultValue: 'https://svatebni-planovac.cz/terms');

  // Deep linking
  String get deepLinkScheme => getValue('deepLink.scheme', defaultValue: 'svatebni-planovac');
  String get deepLinkHost => getValue('deepLink.host', defaultValue: 'app');
  String get universalLinkDomain => getValue('deepLink.universalDomain', defaultValue: 'svatebni-planovac.cz');

  // Performance tuning
  int get imageCompressionQuality => getValue('performance.imageCompressionQuality', defaultValue: 85);
  int get thumbnailSize => getValue('performance.thumbnailSize', defaultValue: 200);
  int get listPageSize => getValue('performance.listPageSize', defaultValue: 20);
  int get searchDebounceMs => getValue('performance.searchDebounceMs', defaultValue: 300);
  bool get enableLazyLoading => getValue('performance.enableLazyLoading', defaultValue: true);

  // A/B Testing
  bool get enableABTesting => getValue('abTesting.enabled', defaultValue: false);
  Map<String, String> get abTestingFlags => Map<String, String>.from(
    getValue('abTesting.flags', defaultValue: <String, String>{}),
  );

  // Remote Config
  int get remoteConfigFetchIntervalHours => getValue('remoteConfig.fetchIntervalHours', defaultValue: 12);
  int get remoteConfigCacheExpirationHours => getValue('remoteConfig.cacheExpirationHours', defaultValue: 1);

  /// Výchozí produkční konfigurace
  Map<String, dynamic> _getDefaultProductionConfig() {
    return {
      'firebase': {
        'apiKey': 'YOUR_FIREBASE_API_KEY',
        'authDomain': 'YOUR_PROJECT.firebaseapp.com',
        'projectId': 'YOUR_PROJECT_ID',
        'storageBucket': 'YOUR_PROJECT.appspot.com',
        'messagingSenderId': 'YOUR_SENDER_ID',
        'appId': 'YOUR_APP_ID',
        'measurementId': 'YOUR_MEASUREMENT_ID',
        'ios': {
          'apiKey': 'YOUR_IOS_API_KEY',
          'appId': 'YOUR_IOS_APP_ID',
          'bundleId': 'com.svatebni.planovac',
        },
      },
      'api': {
        'baseUrl': 'https://api.svatebni-planovac.cz',
        'version': 'v1',
        'timeoutSeconds': 30,
        'maxRetries': 3,
        'headers': {
          'X-App-Version': '1.0.0',
          'X-Platform': 'flutter',
        },
      },
      'features': {
        'crashlytics': true,
        'analytics': true,
        'performanceMonitoring': true,
        'biometricAuth': true,
        'pushNotifications': true,
        'offlineMode': true,
        'debugLogging': false,
        'remoteConfig': true,
        'inAppPurchases': true,
        'socialLogin': true,
        'googleMaps': true,
        'imageUpload': true,
      },
      'security': {
        'minPasswordLength': 8,
        'maxLoginAttempts': 5,
        'sessionTimeoutMinutes': 30,
        'tokenRefreshMinutes': 15,
        'requireEmailVerification': true,
        'enableEncryption': true,
        'encryptionKeyRotationDays': 90,
        'allowedDomains': ['svatebni-planovac.cz'],
      },
      'limits': {
        'maxImageSizeMB': 5,
        'maxVideoSizeMB': 50,
        'maxAttachmentSizeMB': 10,
        'maxGuestCount': 1000,
        'maxTaskCount': 500,
        'maxBudgetItems': 200,
        'maxPhotosPerAlbum': 100,
        'maxVendors': 50,
        'cacheExpirationDays': 7,
        'offlineDataRetentionDays': 30,
      },
      'subscription': {
        'monthlyPrice': 120.0,
        'yearlyPrice': 800.0,
        'trialDays': 14,
        'offerFreeTrial': true,
      },
      'notifications': {
        'reminderHours': 24,
        'enableEmail': true,
        'enableSms': false,
        'defaultSound': 'default',
      },
      'ui': {
        'defaultLanguage': 'cs',
        'supportedLanguages': ['cs', 'en'],
        'dateFormat': 'dd.MM.yyyy',
        'timeFormat': 'HH:mm',
        'use24HourFormat': true,
        'defaultTheme': 'system',
      },
      'cache': {
        'httpMaxAge': 3600,
        'imageMaxCount': 100,
        'imageMaxSizeMB': 50,
        'enableAggressive': true,
      },
      'logging': {
        'level': 'info',
        'toFile': true,
        'retentionDays': 7,
        'maxFileSizeMB': 10,
      },
      'app': {
        'name': 'Svatební plánovač',
        'version': '1.0.0',
        'buildNumber': '1',
        'packageName': 'com.svatebni.planovac',
        'websiteUrl': 'https://svatebni-planovac.cz',
        'supportEmail': 'podpora@svatebni-planovac.cz',
        'privacyPolicyUrl': 'https://svatebni-planovac.cz/privacy',
        'termsOfServiceUrl': 'https://svatebni-planovac.cz/terms',
      },
      'deepLink': {
        'scheme': 'svatebni-planovac',
        'host': 'app',
        'universalDomain': 'svatebni-planovac.cz',
      },
      'performance': {
        'imageCompressionQuality': 85,
        'thumbnailSize': 200,
        'listPageSize': 20,
        'searchDebounceMs': 300,
        'enableLazyLoading': true,
      },
      'remoteConfig': {
        'fetchIntervalHours': 12,
        'cacheExpirationHours': 1,
      },
    };
  }

  /// Získá kompletní konfiguraci jako Map
  Map<String, dynamic> toMap() {
    return Map<String, dynamic>.from(_config);
  }

  /// Resetuje cache
  void clearCache() {
    _cache.clear();
  }

  /// Přenačte konfiguraci
  Future<void> reload({String? configPath}) async {
    _initialized = false;
    _cache.clear();
    await initialize(environment: _environment, configPath: configPath);
  }
}

/// Výjimka pro chyby v konfiguraci
class ConfigurationException implements Exception {
  final String message;
  
  ConfigurationException(this.message);
  
  @override
  String toString() => 'ConfigurationException: $message';
}

/// Extension pro snadný přístup ke konfiguraci
extension ConfigExtension on BuildContext {
  EnvironmentConfig get config => EnvironmentConfig();
}