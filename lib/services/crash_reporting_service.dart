/// lib/services/crash_reporting_service.dart
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';

/// Enum pro definici úrovně logování
enum LogLevel {
  debug,
  info,
  warning,
  error,
  fatal,
}

/// Struktura pro breadcrumb
class Breadcrumb {
  final String message;
  final String category;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final LogLevel level;

  Breadcrumb({
    required this.message,
    required this.category,
    this.data,
    LogLevel? level,
  })  : timestamp = DateTime.now(),
        level = level ?? LogLevel.info;

  Map<String, dynamic> toMap() {
    return {
      'message': message,
      'category': category,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'level': level.toString().split('.').last,
    };
  }

  @override
  String toString() {
    final dataStr = data != null ? ', data: $data' : '';
    return '[$level] [$category] $message$dataStr';
  }
}

/// Sluťba pro pokročilĂ© hláĹˇení chyb
///
/// Tato sluťba rozĹˇiřuje základní funkčnost Firebase Crashlytics o dalĹˇí
/// uťitečnĂ© moťnosti pro diagnostiku chyb v produkci, včetně breadcrumbs,
/// strukturovanĂ©ho logování a detailních informací o prostředí aplikace.
class CrashReportingService {
  final FirebaseCrashlytics _crashlytics;
  final fb.FirebaseAuth _auth;
  bool _initialized = false;

  // Informace o aplikaci
  PackageInfo? _packageInfo;
  Map<String, dynamic> _deviceInfo = {};

  // Seznam posledních chyb v paměti
  final List<Map<String, dynamic>> _errorLog = [];
  static const int _maxErrorLogSize = 50;

  // Breadcrumbs - sledování aktivit uťivatele
  final Queue<Breadcrumb> _breadcrumbs = Queue<Breadcrumb>();
  static const int _maxBreadcrumbsSize = 100;

  // Historie logů
  final Queue<Map<String, dynamic>> _logHistory = Queue<Map<String, dynamic>>();
  static const int _maxLogHistorySize = 1000;

  // Sledování výkonu
  final Map<String, Stopwatch> _performanceTrackers = {};
  final List<Map<String, dynamic>> _performanceMetrics = [];

  // Session ID pro skupinu souvisejících operací
  String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // Omezení odesílání podobných chyb
  final Map<String, DateTime> _errorThrottling = {};
  static const Duration _minErrorInterval = Duration(minutes: 5);

  // Konstruktor s parametry
  CrashReportingService({
    required FirebaseCrashlytics crashlytics,
    required fb.FirebaseAuth auth,
  })  : _crashlytics = crashlytics,
        _auth = auth;

  // Alternativní konstruktor bez parametrů pro DI kompatibilitu
  CrashReportingService.create()
      : _crashlytics = FirebaseCrashlytics.instance,
        _auth = fb.FirebaseAuth.instance;

  /// Inicializace sluťby
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Vytvoření novĂ©ho session ID
      _generateNewSessionId();

      // Získání informací o aplikaci
      _packageInfo = await PackageInfo.fromPlatform();

      // Získání informací o zařízení
      await _gatherDeviceInfo();

      // Nastavení ID uťivatele, pokud je přihláĹˇen
      final user = _auth.currentUser;
      if (user != null) {
        await setUserIdentifier(user.uid);
      }

      // Naslouchání na změny stavu přihláĹˇení
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          setUserIdentifier(user.uid);
          addBreadcrumb(
            message: 'User signed in',
            category: 'auth',
            data: {'uid': user.uid, 'email': user.email},
          );
        } else {
          _crashlytics.setUserIdentifier('');
          addBreadcrumb(
            message: 'User signed out',
            category: 'auth',
          );
        }
      });

      // Nastavení vlastních klíčů pro Crashlytics
      await _setCustomKeys();

      // Povolení Crashlytics v produkci, zakázání v debug mĂłdu
      await _crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);

      // Přidání iniciálního breadcrumb
      addBreadcrumb(
        message: 'App initialized',
        category: 'lifecycle',
        data: {
          'appVersion': _packageInfo?.version,
          'buildNumber': _packageInfo?.buildNumber,
          'platform': Platform.operatingSystem,
          'platformVersion': Platform.operatingSystemVersion,
        },
      );

      // Zaznamenání inicializace
      log(
        message: 'CrashReportingService initialized',
        level: LogLevel.info,
        category: 'system',
      );

      _initialized = true;
    } catch (e, stack) {
      debugPrint('[CrashReportingService] Chyba při inicializaci: $e');
      // Pokus o zaznamenání chyby i kdyť celková inicializace selhala
      try {
        _crashlytics.recordError(e, stack,
            reason: 'Error during initialization');
      } catch (_) {/* Ignorujeme chybu při logování */}
    }
  }

  /// Generuje novĂ© unikátní session ID
  void _generateNewSessionId() {
    _sessionId =
        '${DateTime.now().millisecondsSinceEpoch}_${_createRandomSuffix(4)}';
    try {
      _crashlytics.setCustomKey('session_id', _sessionId);
    } catch (_) {/* Ignorujeme chybu */}
  }

  /// Vytvoří náhodný řetězec pro pouťití v ID
  String _createRandomSuffix(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[DateTime.now().microsecond % chars.length]);
    }
    return buffer.toString();
  }

  /// Nastavení ID uťivatele
  Future<void> setUserIdentifier(String uid) async {
    try {
      await _crashlytics.setUserIdentifier(uid);
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se nastavit userId: $e');
    }
  }

  /// Zaznamenání chyby
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? customData,
    String? category,
  }) async {
    try {
      final errorKey = '${exception.toString()}_${reason ?? ''}';

      // Kontrola throttlingu - neodesílání stejných chyb příliĹˇ často
      if (_errorThrottling.containsKey(errorKey)) {
        final lastTime = _errorThrottling[errorKey]!;
        if (DateTime.now().difference(lastTime) < _minErrorInterval) {
          // Ignorujeme tuto chybu, byla jiť nedávno odeslána
          _addToLogHistory(
            message: 'Error throttled (duplicate): ${exception.toString()}',
            level: LogLevel.info,
            category: 'error_throttling',
          );
          return;
        }
      }

      // Aktualizace času poslední chyby tohoto typu
      _errorThrottling[errorKey] = DateTime.now();

      // Zaznamenání do lokální paměti pro ladění
      _addToErrorLog(exception, stack, reason, customData);

      // Přidání breadcrumb o chybě
      addBreadcrumb(
        message: 'Error occurred: ${exception.toString()}',
        category: category ?? 'error',
        level: fatal ? LogLevel.fatal : LogLevel.error,
        data: {
          'reason': reason,
          'custom_data': customData,
        },
      );

      // RozĹˇíření customData o session a breadcrumbs
      final enhancedCustomData = <String, dynamic>{
        ...?customData,
        'session_id': _sessionId,
        'breadcrumbs': _getRecentBreadcrumbsAsString(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Zaznamenání do Crashlytics
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
        information: _buildErrorInformation(enhancedCustomData),
      );

      // Log o zaznamenání chyby
      _addToLogHistory(
        message: 'Error recorded: ${exception.toString()}',
        level: LogLevel.error,
        category: category ?? 'error',
        data: {
          'reason': reason,
          'stack': stack
              .toString()
              .substring(0, stack.toString().length.clamp(0, 200)),
          'fatal': fatal,
        },
      );
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se zaznamenat chybu: $e');
    }
  }

  /// Zaznamenání chyby s diagnostickými informacemi a kontextem
  Future<void> recordErrorWithContext(
    String errorMessage,
    String errorContext,
    StackTrace? stack, {
    LogLevel level = LogLevel.error,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final customData = {
        'error_context': errorContext,
        'timestamp': DateTime.now().toIso8601String(),
        'session_id': _sessionId,
        ...?additionalData,
      };

      await recordError(
        Exception(errorMessage),
        stack,
        reason: 'Error in $errorContext',
        customData: customData,
        category: errorContext,
        fatal: level == LogLevel.fatal,
      );
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se zaznamenat chybu: $e');
    }
  }

  /// Získání seznamu posledních chyb
  List<Map<String, dynamic>> getRecentErrors() {
    return List.from(_errorLog);
  }

  /// Přidání breadcrumb - sledování aktivity uťivatele pro lepĹˇí pochopení
  /// co vedlo k chybě
  void addBreadcrumb({
    required String message,
    required String category,
    Map<String, dynamic>? data,
    LogLevel? level,
  }) {
    try {
      // Omezení velikosti fronty
      while (_breadcrumbs.length >= _maxBreadcrumbsSize) {
        _breadcrumbs.removeFirst();
      }

      final breadcrumb = Breadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
      );

      _breadcrumbs.add(breadcrumb);

      // Přidání do log historie
      _addToLogHistory(
        message: message,
        level: level ?? LogLevel.info,
        category: category,
        data: data,
      );

      // Zaznamenání breadcrumb i do Crashlytics logu
      try {
        _crashlytics.log(breadcrumb.toString());
      } catch (_) {/* Ignorujeme chybu */}
    } catch (e) {
      debugPrint('[CrashReportingService] Chyba při přidávání breadcrumb: $e');
    }
  }

  /// Získání nedávných breadcrumbs
  List<Breadcrumb> getRecentBreadcrumbs() {
    return List.from(_breadcrumbs);
  }

  /// Získání nedávných breadcrumbs jako string
  String _getRecentBreadcrumbsAsString() {
    final int maxItems = 20;
    final recentBreadcrumbs = _breadcrumbs.toList().reversed.take(maxItems);

    if (recentBreadcrumbs.isEmpty) {
      return 'No recent breadcrumbs';
    }

    return recentBreadcrumbs.map((b) => b.toString()).join('\n');
  }

  /// StrukturovanĂ© logování s více parametry
  void log({
    required String message,
    LogLevel level = LogLevel.info,
    String category = 'app',
    Map<String, dynamic>? data,
    bool addBreadcrumbToo = true,
  }) {
    // Přidání do log historie
    _addToLogHistory(
      message: message,
      level: level,
      category: category,
      data: data,
    );

    // Přidání jako breadcrumb, pokud je poťadováno
    if (addBreadcrumbToo) {
      addBreadcrumb(
        message: message,
        category: category,
        data: data,
        level: level,
      );
    }

    // Logování do konzole v debug reťimu
    if (kDebugMode) {
      final levelStr = '[${level.toString().split('.').last.toUpperCase()}]';
      final categoryStr = '[$category]';
      final dataStr = data != null ? ' | $data' : '';

      switch (level) {
        case LogLevel.debug:
          debugPrint('đźź¤ $levelStr $categoryStr $message$dataStr');
          break;
        case LogLevel.info:
          debugPrint('đźź˘ $levelStr $categoryStr $message$dataStr');
          break;
        case LogLevel.warning:
          debugPrint('đźź  $levelStr $categoryStr $message$dataStr');
          break;
        case LogLevel.error:
          debugPrint('đź”´ $levelStr $categoryStr $message$dataStr');
          break;
        case LogLevel.fatal:
          debugPrint('âš« $levelStr $categoryStr $message$dataStr');
          break;
      }
    }

    // Zaznamenání do Crashlytics logu
    try {
      final logEntry = '${level.toString().split('.').last}|$category|$message';
      _crashlytics.log(logEntry);
    } catch (_) {/* Ignorujeme chybu */}
  }

  /// Přidání záznamu do historie logů
  void _addToLogHistory({
    required String message,
    required LogLevel level,
    required String category,
    Map<String, dynamic>? data,
  }) {
    try {
      // Omezení velikosti historie
      while (_logHistory.length >= _maxLogHistorySize) {
        _logHistory.removeFirst();
      }

      _logHistory.add({
        'message': message,
        'level': level.toString().split('.').last,
        'category': category,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Chyba při přidávání do log historie: $e');
    }
  }

  /// Získání log historie
  List<Map<String, dynamic>> getLogHistory() {
    return List.from(_logHistory);
  }

  /// Exportuje logy do formátu JSON
  String exportLogHistoryAsJson() {
    try {
      return jsonEncode(_logHistory.toList());
    } catch (e) {
      debugPrint('[CrashReportingService] Chyba při exportu logů: $e');
      return '{"error": "Failed to export logs"}';
    }
  }

  /// Sledování výkonu - start trackeru
  void startPerformanceTracker(String name) {
    try {
      _performanceTrackers[name] = Stopwatch()..start();

      addBreadcrumb(
        message: 'Performance tracking started',
        category: 'performance',
        data: {'name': name},
        level: LogLevel.debug,
      );
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Chyba při spuĹˇtění performance trackeru: $e');
    }
  }

  /// Sledování výkonu - konec trackeru
  void stopPerformanceTracker(String name, {bool recordMetric = true}) {
    try {
      if (!_performanceTrackers.containsKey(name)) {
        debugPrint(
            '[CrashReportingService] Performance tracker "$name" není aktivní');
        return;
      }

      final stopwatch = _performanceTrackers[name]!;
      stopwatch.stop();

      final durationMs = stopwatch.elapsedMilliseconds;
      _performanceTrackers.remove(name);

      if (recordMetric) {
        _performanceMetrics.add({
          'name': name,
          'duration_ms': durationMs,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      addBreadcrumb(
        message: 'Performance tracking completed',
        category: 'performance',
        data: {
          'name': name,
          'duration_ms': durationMs,
        },
      );

      // Zaznamenat jako custom key
      if (durationMs > 100) {
        // Ukládáme jen významnĂ© metriky
        try {
          _crashlytics.setCustomKey('perf_$name', durationMs);
        } catch (_) {/* Ignorujeme chybu */}
      }
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Chyba při ukončení performance trackeru: $e');
    }
  }

  /// Získání metrik výkonu
  List<Map<String, dynamic>> getPerformanceMetrics() {
    return List.from(_performanceMetrics);
  }

  /// Nastavení atributu
  Future<void> setCustomKey(String key, dynamic value) async {
    try {
      if (value is String) {
        await _crashlytics.setCustomKey(key, value);
      } else if (value is int) {
        await _crashlytics.setCustomKey(key, value);
      } else if (value is double) {
        await _crashlytics.setCustomKey(key, value);
      } else if (value is bool) {
        await _crashlytics.setCustomKey(key, value);
      } else {
        await _crashlytics.setCustomKey(key, value.toString());
      }

      // Přidání breadcrumb pouze pro důleťitĂ© klíče
      if (!key.startsWith('_')) {
        addBreadcrumb(
          message: 'Custom key set',
          category: 'config',
          data: {'key': key, 'value': value.toString()},
          level: LogLevel.debug,
        );
      }
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Nepodařilo se nastavit custom key: $e');
    }
  }

  /// Nastavení atributů podle stavu aplikace
  Future<void> _setCustomKeys() async {
    try {
      if (_packageInfo != null) {
        await _crashlytics.setCustomKey('app_name', _packageInfo!.appName);
        await _crashlytics.setCustomKey(
            'package_name', _packageInfo!.packageName);
        await _crashlytics.setCustomKey('version', _packageInfo!.version);
        await _crashlytics.setCustomKey(
            'build_number', _packageInfo!.buildNumber);
      }

      // Nastavení informací o zařízení
      for (final entry in _deviceInfo.entries) {
        if (entry.value is String ||
            entry.value is int ||
            entry.value is double ||
            entry.value is bool) {
          await _crashlytics.setCustomKey(entry.key, entry.value);
        }
      }

      // Přidání informace o reťimu
      await _crashlytics.setCustomKey('debug_mode', kDebugMode);
      await _crashlytics.setCustomKey('release_mode', kReleaseMode);
      await _crashlytics.setCustomKey('session_id', _sessionId);
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Nepodařilo se nastavit custom keys: $e');
    }
  }

  /// Získání informací o zařízení
  Future<void> _gatherDeviceInfo() async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        _deviceInfo = {
          'device_type': 'android',
          'device_model': androidInfo.model,
          'device_manufacturer': androidInfo.manufacturer,
          'android_version': androidInfo.version.release,
          'android_sdk': androidInfo.version.sdkInt.toString(),
          'android_brand': androidInfo.brand,
          'android_device': androidInfo.device,
          'android_product': androidInfo.product,
          'android_hardware': androidInfo.hardware,
          'android_fingerprint': androidInfo.fingerprint.substring(0, 10),
          'android_supported_abis': androidInfo.supportedAbis.join(', '),
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        _deviceInfo = {
          'device_type': 'ios',
          'device_model': iosInfo.model,
          'device_name': iosInfo.name,
          'ios_version': iosInfo.systemVersion,
          'ios_locale': iosInfo.localizedModel,
          'ios_system_name': iosInfo.systemName,
          'ios_machine': iosInfo.utsname.machine,
          'ios_release': iosInfo.utsname.release,
          'ios_version_code': iosInfo.utsname.version,
        };
      } else {
        _deviceInfo = {
          'device_type': 'unknown',
          'platform': Platform.operatingSystem,
          'platform_version': Platform.operatingSystemVersion,
        };
      }

      // Přidání obecných informací o zařízení
      _deviceInfo.addAll({
        'locale': Platform.localeName,
        'number_of_processors': Platform.numberOfProcessors.toString(),
      });
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Nepodařilo se získat informace o zařízení: $e');
      _deviceInfo = {
        'device_type': 'unknown',
        'device_info_error': e.toString(),
        'platform': Platform.operatingSystem,
      };
    }
  }

  /// Přidání chyby do lokálního logu
  void _addToErrorLog(
    dynamic exception,
    StackTrace? stack,
    String? reason,
    Map<String, dynamic>? customData,
  ) {
    try {
      while (_errorLog.length >= _maxErrorLogSize) {
        _errorLog.removeAt(0);
      }

      _errorLog.add({
        'error': exception.toString(),
        'stack': stack?.toString() ?? 'No stack trace available',
        'reason': reason,
        'timestamp': DateTime.now().toIso8601String(),
        'custom_data': customData,
        'session_id': _sessionId,
      });
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Chyba při záznamu do lokálního logu: $e');
    }
  }

  /// Vytvoření seznamu informací pro Crashlytics
  List<String> _buildErrorInformation(Map<String, dynamic>? customData) {
    final List<String> info = [];

    try {
      // Základní informace o aplikaci
      if (_packageInfo != null) {
        info.add(
            'App: ${_packageInfo!.appName} (${_packageInfo!.version}+${_packageInfo!.buildNumber})');
      }

      // Informace o zařízení
      if (_deviceInfo.isNotEmpty) {
        if (_deviceInfo['device_type'] == 'android') {
          info.add(
              'Device: ${_deviceInfo['device_manufacturer']} ${_deviceInfo['device_model']}, Android ${_deviceInfo['android_version']} (SDK ${_deviceInfo['android_sdk']})');
        } else if (_deviceInfo['device_type'] == 'ios') {
          info.add(
              'Device: ${_deviceInfo['device_model']}, iOS ${_deviceInfo['ios_version']}');
        }
      }

      // Přidání stavu přihláĹˇení
      final user = _auth.currentUser;
      if (user != null) {
        info.add('User: ${user.uid} (${user.email})');
        info.add('Email verified: ${user.emailVerified}');
      } else {
        info.add('User: Not logged in');
      }

      // Přidání session ID
      info.add('Session ID: $_sessionId');

      // Přidání vlastních dat
      if (customData != null && customData.isNotEmpty) {
        info.add('--- Custom Data ---');
        for (final entry in customData.entries) {
          if (entry.key != 'breadcrumbs') {
            // Breadcrumbs zpracováváme zvláĹˇš
            info.add('${entry.key}: ${entry.value}');
          }
        }
      }

      // Přidání poslední aktivity (breadcrumbs)
      if (customData != null && customData.containsKey('breadcrumbs')) {
        info.add('--- Recent Activity ---');
        info.add(customData['breadcrumbs'].toString());
      }

      // Timestamp
      info.add('Timestamp: ${DateTime.now().toIso8601String()}');
    } catch (e) {
      info.add('Error while building error information: $e');
    }

    return info;
  }

  /// Vynucení test crash pro ověření funkčnosti
  Future<void> forceCrash() async {
    if (kReleaseMode) {
      return; // Neprovádíme v produkci
    }

    try {
      // Zaznamenání, ťe jde o testovací pád
      await _crashlytics.log('Forcing a test crash...');
      await _crashlytics.setCustomKey('test_crash', true);

      // Přidání několika breadcrumbs pro test
      for (int i = 5; i > 0; i--) {
        addBreadcrumb(
          message: 'Test breadcrumb $i before crash',
          category: 'test',
          data: {'countdown': i},
        );
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Vyvolání pádu
      FirebaseCrashlytics.instance.crash();
    } catch (e) {
      debugPrint(
          '[CrashReportingService] Nepodařilo se vyvolat test crash: $e');
    }
  }

  /// Záčátek novĂ© uťivatelskĂ© session
  void startNewSession() {
    _generateNewSessionId();

    addBreadcrumb(
      message: 'New session started',
      category: 'lifecycle',
      data: {'session_id': _sessionId},
    );

    log(
      message: 'New user session started',
      category: 'session',
      data: {'session_id': _sessionId},
      level: LogLevel.info,
    );
  }
}
