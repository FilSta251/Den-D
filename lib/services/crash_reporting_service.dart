// lib/services/crash_reporting_service.dart - OPRAVENÁ VERZE

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Služba pro pokročilé hlášení chyb
///
/// Tato služba rozšiřuje základní funkčnost Firebase Crashlytics o další
/// užitečné možnosti pro diagnostiku chyb v produkci.
class CrashReportingService {
  final FirebaseCrashlytics _crashlytics;
  final fb.FirebaseAuth _auth;
  bool _initialized = false;
  
  // Informace o aplikaci
  PackageInfo? _packageInfo;
  Map<String, dynamic> _deviceInfo = {};
  
  // Seznam posledních chyb v paměti (pro ladění)
  final List<Map<String, dynamic>> _errorLog = [];
  static const int _maxErrorLogSize = 20;
  
  // Konstruktor s parametry
  CrashReportingService({
    required FirebaseCrashlytics crashlytics,
    required fb.FirebaseAuth auth,
  }) : _crashlytics = crashlytics,
       _auth = auth;
       
  // Alternativní konstruktor bez parametrů pro DI kompatibilitu
  CrashReportingService.create()
      : _crashlytics = FirebaseCrashlytics.instance,
        _auth = fb.FirebaseAuth.instance;
  
  /// Inicializace služby
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Získání informací o aplikaci
      _packageInfo = await PackageInfo.fromPlatform();
      
      // Získání informací o zařízení
      await _gatherDeviceInfo();
      
      // Nastavení ID uživatele, pokud je přihlášen
      final user = _auth.currentUser;
      if (user != null) {
        await setUserIdentifier(user.uid);
      }
      
      // Naslouchání na změny stavu přihlášení
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          setUserIdentifier(user.uid);
        } else {
          _crashlytics.setUserIdentifier('');
        }
      });
      
      // Nastavení vlastních klíčů pro Crashlytics
      await _setCustomKeys();
      
      // Povolení Crashlytics v produkci, zakázání v debug módu
      await _crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode);
      
      _initialized = true;
      debugPrint('[CrashReportingService] Inicializováno');
    } catch (e) {
      debugPrint('[CrashReportingService] Chyba při inicializaci: $e');
    }
  }
  
  /// Nastavení ID uživatele
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
  }) async {
    try {
      // Zaznamenání do lokální paměti pro ladění
      _addToErrorLog(exception, stack, reason, customData);
      
      // Zaznamenání do Crashlytics
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
        information: _buildErrorInformation(customData),
      );
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se zaznamenat chybu: $e');
    }
  }
  
  /// Zaznamenání chyby s diagnostickými informacemi
  Future<void> recordErrorWithContext(
    String errorMessage,
    String errorContext,
    StackTrace? stack,
  ) async {
    try {
      final customData = {
        'error_context': errorContext,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await recordError(
        Exception(errorMessage),
        stack,
        reason: 'Error in $errorContext',
        customData: customData,
      );
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se zaznamenat chybu: $e');
    }
  }
  
  /// Získání seznamu posledních chyb
  List<Map<String, dynamic>> getRecentErrors() {
    return List.from(_errorLog);
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
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se nastavit custom key: $e');
    }
  }
  
  /// Nastavení atributů podle stavu aplikace
  Future<void> _setCustomKeys() async {
    try {
      if (_packageInfo != null) {
        await _crashlytics.setCustomKey('app_name', _packageInfo!.appName);
        await _crashlytics.setCustomKey('package_name', _packageInfo!.packageName);
        await _crashlytics.setCustomKey('version', _packageInfo!.version);
        await _crashlytics.setCustomKey('build_number', _packageInfo!.buildNumber);
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
      
      // Přidání informace o režimu
      await _crashlytics.setCustomKey('debug_mode', kDebugMode);
      await _crashlytics.setCustomKey('release_mode', kReleaseMode);
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se nastavit custom keys: $e');
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
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        _deviceInfo = {
          'device_type': 'ios',
          'device_model': iosInfo.model,
          'device_name': iosInfo.name,
          'ios_version': iosInfo.systemVersion,
          'ios_locale': iosInfo.localizedModel,
        };
      } else {
        _deviceInfo = {
          'device_type': 'unknown',
        };
      }
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se získat informace o zařízení: $e');
      _deviceInfo = {
        'device_type': 'unknown',
        'device_info_error': e.toString(),
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
      });
    } catch (e) {
      debugPrint('[CrashReportingService] Chyba při záznamu do lokálního logu: $e');
    }
  }
  
  /// Vytvoření seznamu informací pro Crashlytics
  List<String> _buildErrorInformation(Map<String, dynamic>? customData) {
    final List<String> info = [];
    
    try {
      // Základní informace o aplikaci
      if (_packageInfo != null) {
        info.add('App: ${_packageInfo!.appName} (${_packageInfo!.version}+${_packageInfo!.buildNumber})');
      }
      
      // Informace o zařízení
      if (_deviceInfo.isNotEmpty) {
        if (_deviceInfo['device_type'] == 'android') {
          info.add('Device: ${_deviceInfo['device_manufacturer']} ${_deviceInfo['device_model']}, Android ${_deviceInfo['android_version']} (SDK ${_deviceInfo['android_sdk']})');
        } else if (_deviceInfo['device_type'] == 'ios') {
          info.add('Device: ${_deviceInfo['device_model']}, iOS ${_deviceInfo['ios_version']}');
        }
      }
      
      // Přidání stavu přihlášení
      final user = _auth.currentUser;
      if (user != null) {
        info.add('User: ${user.uid} (${user.email})');
        info.add('Email verified: ${user.emailVerified}');
      } else {
        info.add('User: Not logged in');
      }
      
      // Přidání vlastních dat
      if (customData != null && customData.isNotEmpty) {
        info.add('--- Custom Data ---');
        for (final entry in customData.entries) {
          info.add('${entry.key}: ${entry.value}');
        }
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
      // Zaznamenání, že jde o testovací pád
      await _crashlytics.log('Forcing a test crash...');
      await _crashlytics.setCustomKey('test_crash', true);
      
      // Vyvolání pádu
      FirebaseCrashlytics.instance.crash();
    } catch (e) {
      debugPrint('[CrashReportingService] Nepodařilo se vyvolat test crash: $e');
    }
  }
}