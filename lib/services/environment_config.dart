/// lib/services/environment_config.dart
library;

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

  /// PUBLIC GETTER: Kontrola, zda je již inicializováno
  bool get isInitialized => _initialized;

  /// Inicializuje konfiguraci prostředí
  Future<void> initialize({
    Environment? environment,
    String? configPath,
  }) async {
    if (_initialized) {
      debugPrint('[EnvironmentConfig] Již inicializováno, přeskakuji');
      return;
    }

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
      debugPrint(
          '[EnvironmentConfig] Initialized for ${_environment.name} environment');
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
    const envString =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');

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
        throw ConfigurationException(
            'Missing required configuration key: $key');
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
  String get firebaseAuthDomain =>
      getValue('firebase.authDomain', defaultValue: '');
  String get firebaseProjectId =>
      getValue('firebase.projectId', defaultValue: '');
  String get firebaseStorageBucket =>
      getValue('firebase.storageBucket', defaultValue: '');
  String get firebaseMessagingSenderId =>
      getValue('firebase.messagingSenderId', defaultValue: '');
  String get firebaseAppId => getValue('firebase.appId', defaultValue: '');
  String get firebaseMeasurementId =>
      getValue('firebase.measurementId', defaultValue: '');

  // iOS specifické
  String get firebaseIosApiKey =>
      getValue('firebase.ios.apiKey', defaultValue: firebaseApiKey);
  String get firebaseIosAppId =>
      getValue('firebase.ios.appId', defaultValue: firebaseAppId);
  String get firebaseIosBundleId =>
      getValue('firebase.ios.bundleId', defaultValue: 'com.svatebni.planovac');

  // Zbytek getterů stejný jako dříve...
  // (API konfigurace, Feature flags, Bezpečnostní konfigurace, atd.)
  // Pro stručnost vynechávám, ale v reálném souboru by měly být všechny

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
