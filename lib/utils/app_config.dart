import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// AppConfig slouťí k ukládání konfiguráčních hodnot pro různá prostředí
/// (např. vývoj, staging, produkce). Obsahuje hodnoty jako název aplikace,
/// základní URL pro API, příznak ladění, DSN pro Sentry, Firebase konfiguraci
/// a dalĹˇí vlastní nastavení.
@immutable
class AppConfig {
  /// Název aplikace.
  final String appName;

  /// Základní URL, na kterou se směřují API volání.
  final String apiBaseUrl;

  /// Název prostředí (např. 'development', 'staging', 'production').
  final String environment;

  /// Příznak, zda je zapnutý debug mĂłd.
  final bool debugMode;

  /// DSN pro Sentry (pro hláĹˇení chyb), volitelnĂ©.
  final String? sentryDsn;

  /// Volitelná konfigurace pro Firebase.
  final Map<String, dynamic>? firebaseOptions;

  /// DalĹˇí vlastní nastavení, např. feature flagy, výchozí jazyk apod.
  final Map<String, dynamic> extraConfig;

  /// Primární konstruktor.
  const AppConfig({
    required this.appName,
    required this.apiBaseUrl,
    required this.environment,
    this.debugMode = false,
    this.sentryDsn,
    this.firebaseOptions,
    this.extraConfig = const {},
  });

  /// Vytvoří instanci [AppConfig] z JSON mapy.
  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['appName'] as String? ?? 'Default App',
      apiBaseUrl: json['apiBaseUrl'] as String? ?? 'https://api.example.com',
      environment: json['environment'] as String? ?? 'development',
      debugMode: json['debugMode'] as bool? ?? false,
      sentryDsn: json['sentryDsn'] as String?,
      firebaseOptions: json['firebaseOptions'] is Map
          ? Map<String, dynamic>.from(json['firebaseOptions'])
          : null,
      extraConfig: json['extraConfig'] is Map
          ? Map<String, dynamic>.from(json['extraConfig'])
          : {},
    );
  }

  /// Převádí instanci [AppConfig] do JSON mapy.
  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'apiBaseUrl': apiBaseUrl,
      'environment': environment,
      'debugMode': debugMode,
      'sentryDsn': sentryDsn,
      'firebaseOptions': firebaseOptions,
      'extraConfig': extraConfig,
    };
  }

  /// Vytvoří kopii tĂ©to konfigurace s případnými upravenými hodnotami.
  AppConfig copyWith({
    String? appName,
    String? apiBaseUrl,
    String? environment,
    bool? debugMode,
    String? sentryDsn,
    Map<String, dynamic>? firebaseOptions,
    Map<String, dynamic>? extraConfig,
  }) {
    return AppConfig(
      appName: appName ?? this.appName,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      environment: environment ?? this.environment,
      debugMode: debugMode ?? this.debugMode,
      sentryDsn: sentryDsn ?? this.sentryDsn,
      firebaseOptions: firebaseOptions ?? this.firebaseOptions,
      extraConfig: extraConfig ?? this.extraConfig,
    );
  }

  @override
  String toString() {
    return 'AppConfig(appName: $appName, apiBaseUrl: $apiBaseUrl, environment: $environment, '
        'debugMode: $debugMode, sentryDsn: $sentryDsn, firebaseOptions: $firebaseOptions, '
        'extraConfig: $extraConfig)';
  }

  /// Náčte konfiguráční data ze souboru (např. "assets/config.json").
  /// Soubor musí být deklarován v sekci assets v pubspec.yaml.
  static Future<AppConfig> loadFromAsset(String assetPath) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return AppConfig.fromJson(jsonMap);
    } catch (e) {
      debugPrint("Error loading AppConfig from asset: $e");
      rethrow;
    }
  }
}

