#!/bin/bash

# Vytvoření adresářové struktury pro testy, pokud neexistuje
mkdir -p test/unit
mkdir -p test/widget

# Funkce pro vytvoření souboru s obsahem
create_file() {
    local file_path=$1
    local file_content=$2
    
    # Vytvoření adresářů, pokud neexistují
    mkdir -p $(dirname "$file_path")
    
    # Kontrola, zda soubor již existuje
    if [ -f "$file_path" ]; then
        echo "Soubor '$file_path' již existuje, přeskakuji."
    else
        echo "Vytvářím soubor: $file_path"
        echo "$file_content" > "$file_path"
        echo "Soubor '$file_path' byl úspěšně vytvořen."
    fi
}

# 1. environment_config.dart (kritická priorita)
create_file "lib/services/environment_config.dart" '// lib/services/environment_config.dart

import "package:flutter/foundation.dart";
import "package:flutter_dotenv/flutter_dotenv.dart";

/// Služba pro bezpečné načítání a správu konfiguračních proměnných prostředí.
///
/// Tato třída poskytuje centralizovaný přístup k proměnným prostředí a konfiguračním
/// hodnotám napříč různými prostředími (dev, staging, prod).
class EnvironmentConfig {
  // Singleton instance
  static final EnvironmentConfig _instance = EnvironmentConfig._internal();
  factory EnvironmentConfig() => _instance;
  EnvironmentConfig._internal();

  // Indikátor, zda byla konfigurace inicializována
  bool _initialized = false;
  
  // Mapa pro ukládání konfiguračních hodnot
  final Map<String, dynamic> _config = {};

  /// Inicializuje konfiguraci z .env souboru nebo proměnných prostředí.
  ///
  /// V produkčním prostředí se očekává, že proměnné budou nastaveny 
  /// v CI/CD pipeline nebo na hostingu.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      if (kReleaseMode) {
        // V produkci načítáme proměnné z prostředí
        _loadFromEnvironment();
      } else {
        // Ve vývoji načítáme z .env souboru
        await dotenv.load(fileName: ".env");
        _loadFromDotEnv();
      }
      
      _validateConfig();
      _initialized = true;
      debugPrint("EnvironmentConfig initialized successfully");
    } catch (e) {
      debugPrint("Failed to initialize EnvironmentConfig: $e");
      rethrow;
    }
  }

  /// Načte konfigurační hodnoty z proměnných prostředí.
  void _loadFromEnvironment() {
    // Firebase konfigurace
    _config["FIREBASE_API_KEY"] = const String.fromEnvironment("FIREBASE_API_KEY");
    _config["FIREBASE_APP_ID"] = const String.fromEnvironment("FIREBASE_APP_ID");
    _config["FIREBASE_PROJECT_ID"] = const String.fromEnvironment("FIREBASE_PROJECT_ID");
    _config["FIREBASE_MESSAGING_SENDER_ID"] = const String.fromEnvironment("FIREBASE_MESSAGING_SENDER_ID");
    _config["FIREBASE_STORAGE_BUCKET"] = const String.fromEnvironment("FIREBASE_STORAGE_BUCKET");
    
    // Aplikační konfigurace
    _config["APP_ENVIRONMENT"] = const String.fromEnvironment("APP_ENVIRONMENT", defaultValue: "production");
    _config["API_URL"] = const String.fromEnvironment("API_URL");
    _config["ENABLE_ANALYTICS"] = const bool.fromEnvironment("ENABLE_ANALYTICS", defaultValue: true);
    _config["ENABLE_CRASHLYTICS"] = const bool.fromEnvironment("ENABLE_CRASHLYTICS", defaultValue: true);
  }

  /// Načte konfigurační hodnoty z .env souboru.
  void _loadFromDotEnv() {
    // Firebase konfigurace
    _config["FIREBASE_API_KEY"] = dotenv.env["FIREBASE_API_KEY"];
    _config["FIREBASE_APP_ID"] = dotenv.env["FIREBASE_APP_ID"];
    _config["FIREBASE_PROJECT_ID"] = dotenv.env["FIREBASE_PROJECT_ID"];
    _config["FIREBASE_MESSAGING_SENDER_ID"] = dotenv.env["FIREBASE_MESSAGING_SENDER_ID"];
    _config["FIREBASE_STORAGE_BUCKET"] = dotenv.env["FIREBASE_STORAGE_BUCKET"];
    
    // Aplikační konfigurace
    _config["APP_ENVIRONMENT"] = dotenv.env["APP_ENVIRONMENT"] ?? "development";
    _config["API_URL"] = dotenv.env["API_URL"];
    _config["ENABLE_ANALYTICS"] = dotenv.env["ENABLE_ANALYTICS"] == "true";
    _config["ENABLE_CRASHLYTICS"] = dotenv.env["ENABLE_CRASHLYTICS"] == "true";
  }

  /// Ověří, zda jsou nastaveny všechny požadované konfigurační hodnoty.
  void _validateConfig() {
    final requiredKeys = [
      "FIREBASE_API_KEY",
      "FIREBASE_APP_ID",
      "FIREBASE_PROJECT_ID",
    ];
    
    final missingKeys = requiredKeys.where((key) => _config[key] == null || _config[key].toString().isEmpty).toList();
    
    if (missingKeys.isNotEmpty) {
      throw Exception("Missing required configuration keys: ${missingKeys.join(", ")}");
    }
  }

  /// Získá hodnotu pro zadaný klíč.
  ///
  /// Pokud klíč neexistuje a je zadána výchozí hodnota, vrátí se tato hodnota.
  /// Jinak vyhodí výjimku.
  T getValue<T>(String key, {T? defaultValue}) {
    if (!_initialized) {
      throw Exception("EnvironmentConfig not initialized. Call initialize() first.");
    }
    
    if (_config.containsKey(key)) {
      return _config[key] as T;
    } else if (defaultValue != null) {
      return defaultValue;
    } else {
      throw Exception("Configuration key \'$key\' not found and no default value provided.");
    }
  }

  /// Nastaví hodnotu pro zadaný klíč (použitelné hlavně pro testování).
  void setValue(String key, dynamic value) {
    _config[key] = value;
  }

  /// Vrátí aktuální prostředí (development, staging, production).
  String get environment => getValue<String>("APP_ENVIRONMENT", defaultValue: "development");
  
  /// Vrátí, zda je aplikace v produkčním prostředí.
  bool get isProduction => environment == "production";
  
  /// Vrátí, zda je aplikace v testovacím prostředí.
  bool get isStaging => environment == "staging";
  
  /// Vrátí, zda je aplikace ve vývojovém prostředí.
  bool get isDevelopment => environment == "development";
}
'

# 2. connectivity_manager.dart (vysoká priorita)
create_file "lib/services/connectivity_manager.dart" '// lib/services/connectivity_manager.dart

import "dart:async";
import "package:flutter/foundation.dart";
import "package:connectivity_plus/connectivity_plus.dart";

/// Manažer pro správu síťového připojení.
///
/// Poskytuje informace o aktuálním stavu připojení, změnách připojení,
/// a funkce pro práci v offline/online režimu.
class ConnectivityManager {
  // Singleton instance
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  final Connectivity _connectivity = Connectivity();
  
  // Stav připojení
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  bool _isOnline = false;
  
  // Streamový kontrolér pro zasílání aktualizací o stavu připojení
  final StreamController<ConnectivityResult> _connectionController = 
      StreamController<ConnectivityResult>.broadcast();
  
  // Streamový kontrolér pro online/offline stav
  final StreamController<bool> _onlineStatusController = 
      StreamController<bool>.broadcast();
  
  // Seznam požadavků čekajících na zpracování při obnovení připojení
  final List<Function> _pendingActions = [];
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  /// Stream změn stavu připojení
  Stream<ConnectivityResult> get connectionStream => _connectionController.stream;
  
  /// Stream změn online/offline stavu
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;
  
  /// Aktuální stav připojení
  ConnectivityResult get connectionStatus => _connectionStatus;
  
  /// Indikátor, zda je zařízení online
  bool get isOnline => _isOnline;

  /// Inicializuje manažer a začne sledovat změny připojení.
  Future<void> initialize() async {
    // Zkontrolujeme aktuální stav připojení
    final connectivityResult = await _connectivity.checkConnectivity();
    _updateConnectionStatus(connectivityResult.first);
    
    // Nastavíme posluchač změn připojení
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
    
    debugPrint("ConnectivityManager initialized");
  }
  
  /// Zpracovává změny připojení.
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Connectivity_plus může vrátit více výsledků, bereme první (nejrelevantnější)
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    _updateConnectionStatus(result);
    
    // Pokud jsme se vrátili online, zpracujeme čekající požadavky
    if (_isOnline && _pendingActions.isNotEmpty) {
      _processPendingActions();
    }
  }
  
  /// Aktualizuje stav připojení a informuje posluchače.
  void _updateConnectionStatus(ConnectivityResult result) {
    _connectionStatus = result;
    _isOnline = result != ConnectivityResult.none;
    
    _connectionController.add(result);
    _onlineStatusController.add(_isOnline);
    
    debugPrint("Connectivity status changed: $_connectionStatus (online: $_isOnline)");
  }
  
  /// Přidá akci na frontu pro spuštění po obnovení připojení.
  void addPendingAction(Function action) {
    _pendingActions.add(action);
    debugPrint("Added pending action, total: ${_pendingActions.length}");
  }
  
  /// Zpracuje všechny čekající akce po obnovení připojení.
  Future<void> _processPendingActions() async {
    debugPrint("Processing ${_pendingActions.length} pending actions");
    
    // Vytvoříme kopii seznamu, abychom mohli bezpečně iterovat
    final actionsToProcess = List<Function>.from(_pendingActions);
    _pendingActions.clear();
    
    for (final action in actionsToProcess) {
      try {
        if (action is Future Function()) {
          await action();
        } else {
          action();
        }
      } catch (e) {
        debugPrint("Error processing pending action: $e");
      }
    }
    
    debugPrint("Finished processing pending actions");
  }
  
  /// Vyčistí všechny čekající akce.
  void clearPendingActions() {
    _pendingActions.clear();
    debugPrint("Cleared all pending actions");
  }
  
  /// Provede kontrolu připojení a vrátí aktuální stav.
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result.first);
    return _isOnline;
  }
  
  /// Zaregistruje callback, který se zavolá při každé změně připojení.
  StreamSubscription<bool> onConnectivityChanged(void Function(bool isOnline) callback) {
    return onlineStatusStream.listen(callback);
  }
  
  /// Uvolní prostředky.
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
    _onlineStatusController.close();
  }
}
'

# 3. error_handler.dart (vysoká priorita)
create_file "lib/utils/error_handler.dart" '// lib/utils/error_handler.dart

import "dart:async";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "../services/navigation_service.dart";
import "../services/crash_reporting_service.dart";
import "../di/service_locator.dart" as di;

/// Globální zpracování chyb v aplikaci.
///
/// Tato třída poskytuje centralizované zachycení, zpracování a logování chyb,
/// integraci s Crashlytics a zobrazení uživatelsky přívětivých chybových zpráv.
class ErrorHandler {
  // Singleton instance
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  late final CrashReportingService _crashReportingService;
  late final NavigationService _navigationService;
  
  // Kategorie chyb
  static const String _categoryNetwork = "network";
  static const String _categoryAuthentication = "authentication";
  static const String _categoryPermission = "permission";
  static const String _categoryStorage = "storage";
  static const String _categoryUI = "ui";
  static const String _categoryUnknown = "unknown";
  
  // Maximální počet stejných chyb, které se zobrazí uživateli v určitém časovém okně
  static const int _maxSimilarErrorsThreshold = 3;
  
  // Časové okno pro sledování opakujících se chyb (v ms)
  static const int _errorWindowMs = 60000; // 1 minuta
  
  // Mapa pro sledování opakujících se chyb
  final Map<String, List<DateTime>> _errorOccurrences = {};

  /// Inicializuje ErrorHandler s potřebnými závislostmi.
  Future<void> initialize() async {
    _crashReportingService = di.locator<CrashReportingService>();
    _navigationService = di.locator<NavigationService>();
    
    // Nastavení globálního handleru pro Flutter chyby
    FlutterError.onError = _handleFlutterError;
    
    // Nastavení globálního handleru pro asynchronní chyby
    PlatformDispatcher.instance.onError = _handlePlatformError;
    
    debugPrint("ErrorHandler initialized");
  }

  /// Zpracovává Flutter chyby.
  void _handleFlutterError(FlutterErrorDetails details) {
    // Záznam do Crashlytics
    FirebaseCrashlytics.instance.recordFlutterError(details);
    
    // Záznam do naší služby
    _crashReportingService.recordError(
      details.exception,
      details.stack,
      reason: "Flutter UI Error",
      customData: {"context": details.context?.toString() ?? "unknown"},
    );
    
    debugPrint("Flutter error: ${details.exception}");
  }

  /// Zpracovává asynchronní chyby na platformě.
  bool _handlePlatformError(Object error, StackTrace stack) {
    _crashReportingService.recordError(
      error,
      stack,
      reason: "Platform Error",
      fatal: true,
    );
    
    debugPrint("Platform error: $error");
    return true; // Vrací true, aby označil chybu jako zpracovanou
  }

  /// Hlavní metoda pro zpracování chyb v aplikaci.
  ///
  /// Zaznamenává chybu, kategorizuje ji a případně zobrazí uživateli.
  /// Vrací true, pokud byla chyba úspěšně zpracována.
  Future<bool> handleError(
    dynamic error,
    StackTrace? stackTrace, {
    String? context,
    bool showToUser = true,
    bool isFatal = false,
  }) async {
    // Vytvoření identifikátoru chyby pro sledování opakování
    final errorId = _getErrorIdentifier(error, context);
    
    // Kategorizace chyby
    final category = _categorizeError(error);
    
    // Uživatelsky přívětivá zpráva
    final userMessage = _getUserFriendlyMessage(error, category);
    
    // Logování a záznam chyby
    _logAndRecordError(error, stackTrace, category, context, isFatal);
    
    // Kontrola, zda jsme nepřekročili limit podobných chyb
    if (showToUser && !_isTooManyErrors(errorId)) {
      // Zobrazení chyby uživateli podle závažnosti a kategorie
      _showErrorToUser(userMessage, category, isFatal);
    }
    
    return true;
  }

  /// Vytvoří identifikátor chyby pro sledování opakování.
  String _getErrorIdentifier(dynamic error, String? context) {
    final errorString = error.toString();
    final contextString = context ?? "global";
    
    // Jednoduchý hash pro identifikaci podobných chyb
    return "$contextString:${errorString.hashCode}";
  }

  /// Kontroluje, zda se podobná chyba nevyskytuje příliš často.
  bool _isTooManyErrors(String errorId) {
    final now = DateTime.now();
    
    // Získáme předchozí výskyty této chyby
    final occurrences = _errorOccurrences[errorId] ?? [];
    
    // Odstraníme staré výskyty mimo časové okno
    occurrences.removeWhere(
      (time) => now.difference(time).inMilliseconds > _errorWindowMs
    );
    
    // Přidáme aktuální výskyt
    occurrences.add(now);
    _errorOccurrences[errorId] = occurrences;
    
    // Kontrola, zda jsme nepřekročili limit
    return occurrences.length > _maxSimilarErrorsThreshold;
  }

  /// Kategorizuje chybu podle jejího typu a obsahu.
  String _categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains("socket") || 
        errorString.contains("timeout") || 
        errorString.contains("network") ||
        errorString.contains("connection")) {
      return _categoryNetwork;
    } else if (errorString.contains("auth") || 
               errorString.contains("login") || 
               errorString.contains("permission") ||
               errorString.contains("token")) {
      return _categoryAuthentication;
    } else if (errorString.contains("permission") || 
               errorString.contains("access denied")) {
      return _categoryPermission;
    } else if (errorString.contains("storage") || 
               errorString.contains("file") || 
               errorString.contains("disk")) {
      return _categoryStorage;
    } else if (errorString.contains("build") || 
               errorString.contains("render") || 
               errorString.contains("widget")) {
      return _categoryUI;
    }
    
    return _categoryUnknown;
  }

  /// Převádí technickou chybu na uživatelsky přívětivou zprávu.
  String _getUserFriendlyMessage(dynamic error, String category) {
    switch (category) {
      case _categoryNetwork:
        return "Nelze se připojit k serveru. Zkontrolujte své připojení k internetu a zkuste to znovu.";
      case _categoryAuthentication:
        return "Nastala chyba při ověřování. Zkuste se znovu přihlásit.";
      case _categoryPermission:
        return "Aplikace nemá potřebná oprávnění. Zkontrolujte nastavení oprávnění.";
      case _categoryStorage:
        return "Problém s úložištěm. Zkontrolujte, zda máte dostatek volného místa.";
      case _categoryUI:
        return "Nastala chyba v uživatelském rozhraní. Zkuste aplikaci restartovat.";
      default:
        return "Nastala neočekávaná chyba. Zkuste akci opakovat.";
    }
  }

  /// Loguje a zaznamenává chybu do systémů pro sledování chyb.
  void _logAndRecordError(
    dynamic error,
    StackTrace? stackTrace,
    String category,
    String? context,
    bool isFatal,
  ) {
    // Logování do konzole
    debugPrint("ERROR [$category]: $error");
    if (stackTrace != null) {
      debugPrint("Stack trace: $stackTrace");
    }
    
    // Záznam do Crashlytics a naší služby
    final customData = <String, dynamic>{
      "category": category,
      "context": context ?? "unknown",
    };
    
    _crashReportingService.recordError(
      error,
      stackTrace,
      reason: context ?? "Error in $category",
      fatal: isFatal,
      customData: customData,
    );
  }

  /// Zobrazí chybu uživateli vhodným způsobem.
  void _showErrorToUser(String message, String category, bool isFatal) {
    final context = _navigationService.navigatorKey.currentContext;
    
    if (context != null) {
      // Pro fatální chyby zobrazíme dialog
      if (isFatal) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Chyba aplikace"),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Pro opravdu fatální chyby můžeme restartovat aplikaci
                  // nebo přejít na výchozí obrazovku
                },
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        // Pro běžné chyby stačí Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
            action: category == _categoryNetwork
                ? SnackBarAction(
                    label: "Zkusit znovu",
                    onPressed: () {
                      // Zde by byla logika pro opakování poslední akce
                    },
                  )
                : null,
          ),
        );
      }
    } else {
      // Pokud nemáme context, pouze logujeme
      debugPrint("Cannot show error to user (no context): $message");
    }
  }
}
'

# 4. security_service.dart (vysoká priorita)
create_file "lib/services/security_service.dart" '// lib/services/security_service.dart

import "dart:convert";
import "dart:math";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:crypto/crypto.dart";

/// Služba pro správu bezpečnostních aspektů aplikace.
///
/// Řeší ukládání citlivých informací, práci s tokeny, šifrování dat,
/// a další bezpečnostní funkce.
class SecurityService {
  // Singleton instance
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Secure storage pro bezpečné uchovávání citlivých dat
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Instance Firebase Auth
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  
  // Konstanty pro klíče v úložišti
  static const String _keyRefreshToken = "refresh_token";
  static const String _keyAuthToken = "auth_token";
  static const String _keyTokenExpiry = "token_expiry";
  static const String _keyEncryptionKey = "encryption_key";
  
  // Random generátor pro bezpečnostní operace
  final Random _random = Random.secure();
  
  // Indikace, zda byla služba inicializována
  bool _initialized = false;

  /// Inicializuje bezpečnostní službu.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Kontrola existence šifrovacího klíče, případně jeho vytvoření
      final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
      if (!hasEncryptionKey) {
        await _generateAndStoreEncryptionKey();
      }
      
      _initialized = true;
      debugPrint("SecurityService initialized");
    } catch (e) {
      debugPrint("Failed to initialize SecurityService: $e");
      rethrow;
    }
  }

  /// Generuje a ukládá nový šifrovací klíč.
  Future<void> _generateAndStoreEncryptionKey() async {
    final key = List<int>.generate(32, (_) => _random.nextInt(256));
    final keyBase64 = base64Encode(key);
    await _secureStorage.write(key: _keyEncryptionKey, value: keyBase64);
  }

  /// Načte šifrovací klíč z bezpečného úložiště.
  Future<List<int>> _getEncryptionKey() async {
    final keyBase64 = await _secureStorage.read(key: _keyEncryptionKey);
    if (keyBase64 == null) {
      throw Exception("Encryption key not found");
    }
    return base64Decode(keyBase64);
  }

  /// Uloží token a související data.
  Future<void> storeAuthToken(String token, DateTime expiry) async {
    if (!_initialized) await initialize();
    
    await _secureStorage.write(key: _keyAuthToken, value: token);
    await _secureStorage.write(
      key: _keyTokenExpiry, 
      value: expiry.millisecondsSinceEpoch.toString()
    );
  }

  /// Uloží refresh token.
  Future<void> storeRefreshToken(String refreshToken) async {
    if (!_initialized) await initialize();
    
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  /// Získá uložený autentizační token.
  Future<String?> getAuthToken() async {
    if (!_initialized) await initialize();
    
    return _secureStorage.read(key: _keyAuthToken);
  }

  /// Získá uložený refresh token.
  Future<String?> getRefreshToken() async {
    if (!_initialized) await initialize();
    
    return _secureStorage.read(key: _keyRefreshToken);
  }

  /// Kontroluje, zda je token platný (neexpirovaný).
  Future<bool> isTokenValid() async {
    if (!_initialized) await initialize();
    
    final expiryString = await _secureStorage.read(key: _keyTokenExpiry);
    if (expiryString == null) return false;
    
    final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
    final now = DateTime.now();
    
    return now.isBefore(expiry);
  }

  /// Obnoví token pomocí refresh tokenu.
  /// 
  /// Tato metoda by měla být volána, když je potřeba obnovit expirovaný token.
  Future<bool> refreshToken() async {
    if (!_initialized) await initialize();
    
    try {
      // Zde bychom implementovali obnovu tokenu pomocí Firebase Auth
      // nebo jiného autentizačního systému
      
      // Zjednodušená implementace pro Firebase Auth
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;
      
      final idTokenResult = await currentUser.getIdTokenResult(true);
      if (idTokenResult.token != null) {
        final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
        await storeAuthToken(idTokenResult.token!, expiry);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint("Failed to refresh token: $e");
      return false;
    }
  }

  /// Odstraní všechny uložené tokeny a bezpečnostní data.
  Future<void> clearSecurityData() async {
    if (!_initialized) await initialize();
    
    await _secureStorage.delete(key: _keyAuthToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await _secureStorage.delete(key: _keyTokenExpiry);
    // Ponecháme šifrovací klíč pro případné zašifrované soubory
  }

  /// Zašifruje data pomocí bezpečného klíče.
  Future<String> encryptData(String plainText) async {
    if (!_initialized) await initialize();
    
    // Zjednodušená implementace šifrování - v produkci použijte silnější algoritmus
    final key = await _getEncryptionKey();
    final contentBytes = utf8.encode(plainText);
    final iv = List<int>.generate(16, (_) => _random.nextInt(256));
    
    // Toto je pouze zjednodušená demonstrace - v reálu použijte AES nebo jiný algoritmus
    final encryptedBytes = List<int>.from(contentBytes);
    for (int i = 0; i < encryptedBytes.length; i++) {
      encryptedBytes[i] = encryptedBytes[i] ^ key[i % key.length];
    }
    
    // Kombinace IV a zašifrovaných dat
    final result = iv + encryptedBytes;
    return base64Encode(result);
  }

  /// Dešifruje zašifrovaná data.
  Future<String> decryptData(String encryptedText) async {
  # 4. security_service.dart (vysoká priorita) - pokračování
create_file "lib/services/security_service.dart" '// lib/services/security_service.dart

import "dart:convert";
import "dart:math";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:crypto/crypto.dart";

/// Služba pro správu bezpečnostních aspektů aplikace.
///
/// Řeší ukládání citlivých informací, práci s tokeny, šifrování dat,
/// a další bezpečnostní funkce.
class SecurityService {
 // Singleton instance
 static final SecurityService _instance = SecurityService._internal();
 factory SecurityService() => _instance;
 SecurityService._internal();

 // Secure storage pro bezpečné uchovávání citlivých dat
 final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
 
 // Instance Firebase Auth
 final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
 
 // Konstanty pro klíče v úložišti
 static const String _keyRefreshToken = "refresh_token";
 static const String _keyAuthToken = "auth_token";
 static const String _keyTokenExpiry = "token_expiry";
 static const String _keyEncryptionKey = "encryption_key";
 
 // Random generátor pro bezpečnostní operace
 final Random _random = Random.secure();
 
 // Indikace, zda byla služba inicializována
 bool _initialized = false;

 /// Inicializuje bezpečnostní službu.
 Future<void> initialize() async {
   if (_initialized) return;
   
   try {
     // Kontrola existence šifrovacího klíče, případně jeho vytvoření
     final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
     if (!hasEncryptionKey) {
       await _generateAndStoreEncryptionKey();
     }
     
     _initialized = true;
     debugPrint("SecurityService initialized");
   } catch (e) {
     debugPrint("Failed to initialize SecurityService: $e");
     rethrow;
   }
 }

 /// Generuje a ukládá nový šifrovací klíč.
 Future<void> _generateAndStoreEncryptionKey() async {
   final key = List<int>.generate(32, (_) => _random.nextInt(256));
   final keyBase64 = base64Encode(key);
   await _secureStorage.write(key: _keyEncryptionKey, value: keyBase64);
 }

 /// Načte šifrovací klíč z bezpečného úložiště.
 Future<List<int>> _getEncryptionKey() async {
   final keyBase64 = await _secureStorage.read(key: _keyEncryptionKey);
   if (keyBase64 == null) {
     throw Exception("Encryption key not found");
   }
   return base64Decode(keyBase64);
 }

 /// Uloží token a související data.
 Future<void> storeAuthToken(String token, DateTime expiry) async {
   if (!_initialized) await initialize();
   
   await _secureStorage.write(key: _keyAuthToken, value: token);
   await _secureStorage.write(
     key: _keyTokenExpiry, 
     value: expiry.millisecondsSinceEpoch.toString()
   );
 }

 /// Uloží refresh token.
 Future<void> storeRefreshToken(String refreshToken) async {
   if (!_initialized) await initialize();
   
   await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
 }

 /// Získá uložený autentizační token.
 Future<String?> getAuthToken() async {
   if (!_initialized) await initialize();
   
   return _secureStorage.read(key: _keyAuthToken);
 }

 /// Získá uložený refresh token.
 Future<String?> getRefreshToken() async {
   if (!_initialized) await initialize();
   
   return _secureStorage.read(key: _keyRefreshToken);
 }

 /// Kontroluje, zda je token platný (neexpirovaný).
 Future<bool> isTokenValid() async {
   if (!_initialized) await initialize();
   
   final expiryString = await _secureStorage.read(key: _keyTokenExpiry);
   if (expiryString == null) return false;
   
   final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
   final now = DateTime.now();
   
   return now.isBefore(expiry);
 }

 /// Obnoví token pomocí refresh tokenu.
 /// 
 /// Tato metoda by měla být volána, když je potřeba obnovit expirovaný token.
 Future<bool> refreshToken() async {
   if (!_initialized) await initialize();
   
   try {
     // Zde bychom implementovali obnovu tokenu pomocí Firebase Auth
     // nebo jiného autentizačního systému
     
     // Zjednodušená implementace pro Firebase Auth
     final currentUser = _auth.currentUser;
     if (currentUser == null) return false;
     
     final idTokenResult = await currentUser.getIdTokenResult(true);
     if (idTokenResult.token != null) {
       final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
       await storeAuthToken(idTokenResult.token!, expiry);
       return true;
     }
     
     return false;
   } catch (e) {
     debugPrint("Failed to refresh token: $e");
     return false;
   }
 }

 /// Odstraní všechny uložené tokeny a bezpečnostní data.
 Future<void> clearSecurityData() async {
   if (!_initialized) await initialize();
   
   await _secureStorage.delete(key: _keyAuthToken);
   await _secureStorage.delete(key: _keyRefreshToken);
   await _secureStorage.delete(key: _keyTokenExpiry);
   // Ponecháme šifrovací klíč pro případné zašifrované soubory
 }

 /// Zašifruje data pomocí bezpečného klíče.
 Future<String> encryptData(String plainText) async {
   if (!_initialized) await initialize();
   
   // Zjednodušená implementace šifrování - v produkci použijte silnější algoritmus
   final key = await _getEncryptionKey();
   final contentBytes = utf8.encode(plainText);
   final iv = List<int>.generate(16, (_) => _random.nextInt(256));
   
   // Toto je pouze zjednodušená demonstrace - v reálu použijte AES nebo jiný algoritmus
   final encryptedBytes = List<int>.from(contentBytes);
   for (int i = 0; i < encryptedBytes.length; i++) {
     encryptedBytes[i] = encryptedBytes[i] ^ key[i % key.length];
   }
   
   // Kombinace IV a zašifrovaných dat
   final result = iv + encryptedBytes;
   return base64Encode(result);
 }

 /// Dešifruje zašifrovaná data.
 Future<String> decryptData(String encryptedText) async {
   if (!_initialized) await initialize();
   
   try {
     final key = await _getEncryptionKey();
     final data = base64Decode(encryptedText);
     
     if (data.length < 16) {
       throw Exception("Invalid encrypted data format");
     }
     
     // Oddělení IV a zašifrovaných dat
     final iv = data.sublist(0, 16);
     final encryptedBytes = data.sublist(16);
     
     // Zjednodušená implementace dešifrování - v produkci použijte silnější algoritmus
     final decryptedBytes = List<int>.from(encryptedBytes);
     for (int i = 0; i < decryptedBytes.length; i++) {
       decryptedBytes[i] = decryptedBytes[i] ^ key[i % key.length];
     }
     
     return utf8.decode(decryptedBytes);
   } catch (e) {
     debugPrint("Failed to decrypt data: $e");
     throw Exception("Decryption failed");
   }
 }

 /// Vytvoří hash z hesla pro bezpečné porovnání nebo ukládání.
 String hashPassword(String password, String salt) {
   final bytes = utf8.encode(password + salt);
   final digest = sha256.convert(bytes);
   return digest.toString();
 }

 /// Vygeneruje bezpečný salt pro hashování.
 String generateSalt() {
   final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
   return base64Encode(bytes);
 }

 /// Ověří integrity aplikace a bezpečnostních prvků.
 Future<bool> verifyAppIntegrity() async {
   if (!_initialized) await initialize();
   
   try {
     // Zde by byla implementace kontroly integrity aplikace
     // Například kontrola podpisu, detekce root/jailbreak, apod.
     
     // Zjednodušená implementace pro ukázku
     final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
     return hasEncryptionKey;
   } catch (e) {
     debugPrint("App integrity check failed: $e");
     return false;
   }
 }
}
'

# 5. performance_monitor.dart (střední priorita)
create_file "lib/utils/performance_monitor.dart" '// lib/utils/performance_monitor.dart

import "dart:collection";
import "package:flutter/foundation.dart";
import "package:firebase_performance/firebase_performance.dart";

/// Služba pro monitoring výkonu aplikace.
///
/// Umožňuje měřit výkon operací, sledovat trasové body, a integrovat 
/// s Firebase Performance Monitoring.
class PerformanceMonitor {
 // Singleton instance
 static final PerformanceMonitor _instance = PerformanceMonitor._internal();
 factory PerformanceMonitor() => _instance;
 PerformanceMonitor._internal();

 // Instance Firebase Performance
 final FirebasePerformance _performance = FirebasePerformance.instance;
 
 // Mapa aktivních trace
 final Map<String, Trace> _activeTraces = {};
 
 // Historie měření (omezená velikost)
 final Queue<_PerformanceEntry> _history = Queue<_PerformanceEntry>();
 
 // Maximální velikost historie
 static const int _maxHistorySize = 100;
 
 // Indikátor, zda je monitoring povolen
 bool _isEnabled = true;
 
 /// Nastaví, zda je monitoring povolen.
 set isEnabled(bool value) {
   _isEnabled = value;
   _performance.setPerformanceCollectionEnabled(value);
 }
 
 /// Vrací, zda je monitoring povolen.
 bool get isEnabled => _isEnabled;

 /// Inicializuje monitor výkonu.
 Future<void> initialize() async {
   await _performance.setPerformanceCollectionEnabled(_isEnabled);
   debugPrint("PerformanceMonitor initialized, collection ${_isEnabled ? "enabled" : "disabled"}");
 }

 /// Začne měřit výkon operace.
 ///
 /// Vrací ID měření, které lze použít pro zastavení měření.
 String startTrace(String name) {
   if (!_isEnabled) return "disabled";
   
   try {
     final trace = _performance.newTrace(name);
     trace.start();
     
     final traceId = "${name}_${DateTime.now().millisecondsSinceEpoch}";
     _activeTraces[traceId] = trace;
     
     debugPrint("Started trace: $name (ID: $traceId)");
     return traceId;
   } catch (e) {
     debugPrint("Failed to start trace: $e");
     return "error";
   }
 }

 /// Zastaví měření výkonu operace a zaznamená výsledek.
 Future<void> stopTrace(String traceId) async {
   if (!_isEnabled || traceId == "disabled" || traceId == "error") return;
   
   try {
     final trace = _activeTraces[traceId];
     if (trace != null) {
       final startTimeMs = (trace as dynamic).startTime as int?;
       final durationMs = startTimeMs != null 
           ? DateTime.now().millisecondsSinceEpoch - startTimeMs 
           : null;
       
       await trace.stop();
       _activeTraces.remove(traceId);
       
       _logPerformanceEntry(
         trace.name, 
         durationMs ?? 0,
         {},
       );
       
       debugPrint("Stopped trace: ${trace.name} (ID: $traceId), duration: ${durationMs ?? "unknown"} ms");
     } else {
       debugPrint("Trace not found: $traceId");
     }
   } catch (e) {
     debugPrint("Failed to stop trace: $e");
   }
 }

 /// Přidá atribut k aktivnímu trace.
 void putAttribute(String traceId, String name, String value) {
   if (!_isEnabled || traceId == "disabled" || traceId == "error") return;
   
   try {
     final trace = _activeTraces[traceId];
     if (trace != null) {
       trace.putAttribute(name, value);
       debugPrint("Added attribute to trace $traceId: $name=$value");
     }
   } catch (e) {
     debugPrint("Failed to add attribute: $e");
   }
 }

 /// Zaznamená metriku k aktivnímu trace.
 void incrementMetric(String traceId, String name, int value) {
   if (!_isEnabled || traceId == "disabled" || traceId == "error") return;
   
   try {
     final trace = _activeTraces[traceId];
     if (trace != null) {
       trace.incrementMetric(name, value);
       debugPrint("Incremented metric in trace $traceId: $name by $value");
     }
   } catch (e) {
     debugPrint("Failed to increment metric: $e");
   }
 }

 /// Začne měřit výkon HTTP požadavku.
 HttpMetric? startHttpMetric(String url, String method) {
   if (!_isEnabled) return null;
   
   try {
     final metric = _performance.newHttpMetric(url, getHttpMethod(method));
     metric.start();
     debugPrint("Started HTTP metric: $method $url");
     return metric;
   } catch (e) {
     debugPrint("Failed to start HTTP metric: $e");
     return null;
   }
 }

 /// Zastaví měření výkonu HTTP požadavku a zaznamená výsledek.
 Future<void> stopHttpMetric(HttpMetric? metric, {int? responseCode, int? requestPayloadSize, int? responsePayloadSize}) async {
   if (!_isEnabled || metric == null) return;
   
   try {
     if (responseCode != null) {
       metric.httpResponseCode = responseCode;
     }
     
     if (requestPayloadSize != null) {
       metric.requestPayloadSize = requestPayloadSize;
     }
     
     if (responsePayloadSize != null) {
       metric.responsePayloadSize = responsePayloadSize;
     }
     
     await metric.stop();
     debugPrint("Stopped HTTP metric: ${metric.url}");
   } catch (e) {
     debugPrint("Failed to stop HTTP metric: $e");
   }
 }

 /// Vrátí enum hodnotu pro HTTP metodu.
 HttpMethod getHttpMethod(String method) {
   switch (method.toUpperCase()) {
     case "GET":
       return HttpMethod.Get;
     case "POST":
       return HttpMethod.Post;
     case "PUT":
       return HttpMethod.Put;
     case "DELETE":
       return HttpMethod.Delete;
     case "PATCH":
       return HttpMethod.Patch;
     case "OPTIONS":
       return HttpMethod.Options;
     case "HEAD":
       return HttpMethod.Head;
     case "TRACE":
       return HttpMethod.Trace;
     case "CONNECT":
       return HttpMethod.Connect;
     default:
       return HttpMethod.Get;
   }
 }

 /// Měří dobu provádění funkce.
 ///
 /// Přijímá jméno funkce a callback, který se má provést.
 /// Měří dobu provádění a zaznamenává výsledek.
 Future<T> measureFunction<T>(String name, Future<T> Function() callback) async {
   if (!_isEnabled) return callback();
   
   final traceId = startTrace(name);
   final startTime = DateTime.now();
   
   try {
     final result = await callback();
     return result;
   } finally {
     final duration = DateTime.now().difference(startTime).inMilliseconds;
     await stopTrace(traceId);
     
     debugPrint("Function $name completed in ${duration}ms");
   }
 }

 /// Zaznamenává výkonnostní údaje do lokální historie.
 void _logPerformanceEntry(String name, int durationMs, Map<String, String> attributes) {
   // Přidání nového záznamu
   _history.addLast(_PerformanceEntry(
     name: name,
     timestamp: DateTime.now(),
     durationMs: durationMs,
     attributes: Map<String, String>.from(attributes),
   ));
   
   // Odstranění nejstaršího záznamu, pokud je překročen limit
   if (_history.length > _maxHistorySize) {
     _history.removeFirst();
   }
 }

 /// Vrací historii měření výkonu.
 List<Map<String, dynamic>> getPerformanceHistory() {
   return _history.map((entry) => entry.toMap()).toList();
 }

 /// Vyčistí historii měření výkonu.
 void clearHistory() {
   _history.clear();
 }

 /// Uvolní zdroje.
 void dispose() {
   // Zastavíme všechny aktivní trace
   for (final traceId in _activeTraces.keys.toList()) {
     stopTrace(traceId);
   }
   
   _activeTraces.clear();
   _history.clear();
 }
}

/// Třída reprezentující záznam výkonu v historii.
class _PerformanceEntry {
 final String name;
 final DateTime timestamp;
 final int durationMs;
 final Map<String, String> attributes;
 
 _PerformanceEntry({
   required this.name,
   required this.timestamp,
   required this.durationMs,
   required this.attributes,
 });
 
 Map<String, dynamic> toMap() {
   return {
     "name": name,
     "timestamp": timestamp.toIso8601String(),
     "durationMs": durationMs,
     "attributes": attributes,
   };
 }
}
'

# 6. responsive_layout.dart (střední priorita)
create_file "lib/widgets/responsive_layout.dart" '// lib/widgets/responsive_layout.dart

import "package:flutter/material.dart";

/// Breakpointy pro různé velikosti zařízení.
class ScreenBreakpoints {
 // Mobilní zařízení
 static const double mobileSmall = 320;
 static const double mobileMedium = 375;
 static const double mobileLarge = 414;
 
 // Tablety
 static const double tabletSmall = 600;
 static const double tabletMedium = 768;
 static const double tabletLarge = 900;
 
 // Desktopy
 static const double desktopSmall = 1024;
 static const double desktopMedium = 1280;
 static const double desktopLarge = 1440;
}

/// Enum reprezentující typ zařízení.
enum DeviceType {
 mobileSmall,
 mobileMedium,
 mobileLarge,
 tabletSmall,
 tabletMedium,
 tabletLarge,
 desktopSmall,
 desktopMedium,
 desktopLarge,
}

/// Widget pro responzivní layout, který poskytuje různé widgety
/// v závislosti na velikosti obrazovky.
class ResponsiveLayout extends StatelessWidget {
 /// Builder pro mobilní zařízení.
 final Widget Function(BuildContext context)? mobileBuilder;
 
 /// Builder pro tablety.
 final Widget Function(BuildContext context)? tabletBuilder;
 
 /// Builder pro desktopy.
 final Widget Function(BuildContext context)? desktopBuilder;
 
 /// Výchozí builder, který se použije, pokud není definován
 /// specifický builder pro danou velikost obrazovky.
 final Widget Function(BuildContext context) defaultBuilder;
 
 const ResponsiveLayout({
   Key? key,
   this.mobileBuilder,
   this.tabletBuilder,
   this.desktopBuilder,
   required this.defaultBuilder,
 }) : super(key: key);

 @override
 Widget build(BuildContext context) {
   return LayoutBuilder(
     builder: (context, constraints) {
       final deviceType = _getDeviceType(constraints.maxWidth);
       
       // Desktop layout
       if (_isDesktop(deviceType) && desktopBuilder != null) {
         return desktopBuilder!(context);
       }
       
       // Tablet layout
       if (_isTablet(deviceType) && tabletBuilder != null) {
         return tabletBuilder!(context);
       }
       
       // Mobile layout
       if (_isMobile(deviceType) && mobileBuilder != null) {
         return mobileBuilder!(context);
       }
       
       // Default layout
       return defaultBuilder(context);
     },
   );
 }

 /// Určí typ zařízení podle šířky obrazovky.
 DeviceType _getDeviceType(double width) {
   if (width < ScreenBreakpoints.mobileSmall) {
     return DeviceType.mobileSmall;
   } else if (width < ScreenBreakpoints.mobileMedium) {
     return DeviceType.mobileMedium;
   } else if (width < ScreenBreakpoints.mobileLarge) {
     return DeviceType.mobileLarge;
   } else if (width < ScreenBreakpoints.tabletSmall) {
     return DeviceType.tabletSmall;
   } else if (width < ScreenBreakpoints.tabletMedium) {
     return DeviceType.tabletMedium;
   } else if (width < ScreenBreakpoints.tabletLarge) {
     return DeviceType.tabletLarge;
   } else if (width < ScreenBreakpoints.desktopSmall) {
     return DeviceType.desktopSmall;
   } else if (width < ScreenBreakpoints.desktopMedium) {
     return DeviceType.desktopMedium;
   } else {
     return DeviceType.desktopLarge;
   }
 }

 /// Kontroluje, zda je zařízení mobilní.
 bool _isMobile(DeviceType deviceType) {
   return deviceType == DeviceType.mobileSmall ||
          deviceType == DeviceType.mobileMedium ||
          deviceType == DeviceType.mobileLarge;
 }

 /// Kontroluje, zda je zařízení tablet.
 bool _isTablet(DeviceType deviceType) {
   return deviceType == DeviceType.tabletSmall ||
          deviceType == DeviceType.tabletMedium ||
          deviceType == DeviceType.tabletLarge;
 }

 /// Kontroluje, zda je zařízení desktop.
 bool _isDesktop(DeviceType deviceType) {
   return deviceType == DeviceType.desktopSmall ||
          deviceType == DeviceType.desktopMedium ||
          deviceType == DeviceType.desktopLarge;
 }
}

/// Widget, který vrací různé widgety v závislosti na orientaci zařízení.
class OrientationLayout extends StatelessWidget {
 /// Builder pro portrétní orientaci.
 final Widget Function(BuildContext context) portraitBuilder;
 
 /// Builder pro landscape orientaci.
 final Widget Function(BuildContext context) landscapeBuilder;
 
 const OrientationLayout({
   Key? key,
   required this.portraitBuilder,
   required this.landscapeBuilder,
 }) : super(key: key);

 @override
 Widget build(BuildContext context) {
   return OrientationBuilder(
     builder: (context, orientation) {
       if (orientation == Orientation.portrait) {
         return portraitBuilder(context);
       } else {
         return landscapeBuilder(context);
       }
     },
   );
 }
}

/// Rozšíření pro získání informací o velikosti obrazovky v kontextu.
extension ScreenSizeExtension on BuildContext {
 /// Vrací šířku obrazovky.
 double get screenWidth => MediaQuery.of(this).size.width;
 
 /// Vrací výšku obrazovky.
 double get screenHeight => MediaQuery.of(this).size.height;
 
 /// Vrací orientaci obrazovky.
 Orientation get orientation => MediaQuery.of(this).orientation;
 
 /// Kontroluje, zda je zařízení mobilní.
 bool get isMobile => screenWidth < ScreenBreakpoints.tabletSmall;
 
 /// Kontroluje, zda je zařízení tablet.
 bool get isTablet => screenWidth >= ScreenBreakpoints.tabletSmall && 
                      screenWidth < ScreenBreakpoints.desktopSmall;
 
 /// Kontroluje, zda je zařízení desktop.
 bool get isDesktop => screenWidth >= ScreenBreakpoints.desktopSmall;
 
 /// Vrací typ zařízení.
 DeviceType get deviceType {
   final width = screenWidth;
   
   if (width < ScreenBreakpoints.mobileSmall) {
     return DeviceType.mobileSmall;
   } else if (width < ScreenBreakpoints.mobileMedium) {
     return DeviceType.mobileMedium;
   } else if (width < ScreenBreakpoints.mobileLarge) {
     return DeviceType.mobileLarge;
   } else if (width < ScreenBreakpoints.tabletSmall) {
     return DeviceType.tabletSmall;
   } else if (width < ScreenBreakpoints.tabletMedium) {
     return DeviceType.tabletMedium;
   } else if (width < ScreenBreakpoints.tabletLarge) {
     return DeviceType.tabletLarge;
   } else if (width < ScreenBreakpoints.desktopSmall) {
     return DeviceType.desktopSmall;
   } else if (width < ScreenBreakpoints.desktopMedium) {
     return DeviceType.desktopMedium;
   } else {
     return DeviceType.desktopLarge;
   }
 }
}

/// Třída s pomocnými metodami pro responzivní design.
class ResponsiveHelper {
 /// Vrací velikost fontu v závislosti na velikosti obrazovky.
 static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
   final deviceType = context.deviceType;
   
   switch (deviceType) {
     case DeviceType.mobileSmall:
       return baseFontSize * 0.8;
     case DeviceType.mobileMedium:
       return baseFontSize * 0.9;
     case DeviceType.mobileLarge:
       return baseFontSize;
     case DeviceType.tabletSmall:
       return baseFontSize * 1.1;
     case DeviceType.tabletMedium:
       return baseFontSize * 1.2;
     case DeviceType.tabletLarge:
       return baseFontSize * 1.3;
     case DeviceType.desktopSmall:
       return baseFontSize * 1.2;
     case DeviceType.desktopMedium:
       return baseFontSize * 1.3;
     case DeviceType.desktopLarge:
       return baseFontSize * 1.4;
   }
 }

 /// Vrací velikost mezery v závislosti na velikosti obrazovky.
 static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
   final deviceType = context.deviceType;
   
   switch (deviceType) {
     case DeviceType.mobileSmall:
       return baseSpacing * 0.8;
     case DeviceType.mobileMedium:
       return baseSpacing * 0.9;
     case DeviceType.mobileLarge:
       return baseSpacing;
     case DeviceType.tabletSmall:
       return baseSpacing * 1.2;
     case DeviceType.tabletMedium:
       return baseSpacing * 1.4;
     case DeviceType.tabletLarge:
       return baseSpacing * 1.6;
     case DeviceType.desktopSmall:
       return baseSpacing * 1.5;
     case DeviceType.desktopMedium:
       return baseSpacing * 1.7;
     case DeviceType.desktopLarge:
       return baseSpacing * 2.0;
   }
 }

 /// Vrací velikost ikony v závislosti na velikosti obrazovky.
 static double getResponsiveIconSize(BuildContext context, double baseIconSize) {
   final deviceType = context.deviceType;
   
   switch (deviceType) {
     case DeviceType.mobileSmall:
       return baseIconSize * 0.8;
     case DeviceType.mobileMedium:
       return baseIconSize * 0.9;
     case DeviceType.mobileLarge:
       return baseIconSize;
     case DeviceType.tabletSmall:
       return baseIconSize * 1.2;
     case DeviceType.tabletMedium:
       return baseIconSize * 1.3;
     case DeviceType.tabletLarge:
       return baseIconSize * 1.4;
     case DeviceType.desktopSmall:
       return baseIconSize * 1.3;
     case DeviceType.desktopMedium:
       return baseIconSize * 1.4;
     case DeviceType.desktopLarge:
       return baseIconSize * 1.5;
   }
 }
}
'

# 7. local_database.dart (střední priorita)
create_file "lib/utils/local_database.dart" '// lib/utils/local_database.dart

import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:path_provider/path_provider.dart";
import "dart:io";
import "package:crypto/crypto.dart";

/// Abstrakce nad lokálním úložištěm dat.
# 7. local_database.dart (střední priorita)
create_file "lib/utils/local_database.dart" '// lib/utils/local_database.dart

import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:path_provider/path_provider.dart";
import "dart:io";
import "package:crypto/crypto.dart";

/// Abstrakce nad lokálním úložištěm dat.
///
/// Poskytuje jednotné rozhraní pro ukládání a načítání dat z různých
/// typů lokálního úložiště (SharedPreferences, SecureStorage, soubory).
class LocalDatabase {
  // Singleton instance
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  // Instance úložišť
  late SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Indikace, zda byla databáze inicializována
  bool _initialized = false;
  
  // Kešované hodnoty
  final Map<String, dynamic> _cache = {};
  
  // Maximální velikost cache položky
  static const int _maxCacheItemSize = 1024 * 10; // 10 KB
  
  // Expirace položek v cache (ms)
  static const int _cacheExpiryMs = 1000 * 60 * 5; // 5 minut
  
  // Informace o expiraci položek
  final Map<String, DateTime> _cacheExpiry = {};
  
  // Událost pro databázové změny
  final StreamController<String> _changeController = StreamController<String>.broadcast();
  
  /// Stream pro sledování změn v databázi.
  Stream<String> get onChange => _changeController.stream;

  /// Inicializuje databázi.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _preferences = await SharedPreferences.getInstance();
      _initialized = true;
      debugPrint("LocalDatabase initialized");
    } catch (e) {
      debugPrint("Failed to initialize LocalDatabase: $e");
      rethrow;
    }
  }

  /// Ukládá hodnotu do standardního úložiště.
  Future<bool> setValue(String key, dynamic value) async {
    if (!_initialized) await initialize();
    
    try {
      // Aktualizace cache
      _updateCache(key, value);
      
      // Vynucení notifikace o změně
      _notifyChange(key);
      
      // Uložení hodnoty do patřičného úložiště v závislosti na typu
      if (value is String) {
        return await _preferences.setString(key, value);
      } else if (value is int) {
        return await _preferences.setInt(key, value);
      } else if (value is double) {
        return await _preferences.setDouble(key, value);
      } else if (value is bool) {
        return await _preferences.setBool(key, value);
      } else if (value is List<String>) {
        return await _preferences.setStringList(key, value);
      } else {
        // Pro ostatní typy serializujeme do JSON
        final jsonValue = jsonEncode(value);
        return await _preferences.setString(key, jsonValue);
      }
    } catch (e) {
      debugPrint("Failed to save value for key $key: $e");
      return false;
    }
  }

  /// Čte hodnotu ze standardního úložiště.
  dynamic getValue(String key, {dynamic defaultValue}) {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    try {
      // Nejprve zkusíme načíst z cache, pokud je položka platná
      if (_isCacheValid(key)) {
        return _cache[key];
      }
      
      // Pokud není v cache, načteme z úložiště
      if (!_preferences.containsKey(key)) {
        return defaultValue;
      }
      
      // Určíme typ uložené hodnoty a načteme ji
      final Object? rawValue = _preferences.get(key);
      
      // Pokud je hodnota null, vrátíme výchozí hodnotu
      if (rawValue == null) {
        return defaultValue;
      }
      
      // Aktualizace cache
      _updateCache(key, rawValue);
      
      return rawValue;
    } catch (e) {
      debugPrint("Failed to get value for key $key: $e");
      return defaultValue;
    }
  }

  /// Ukládá hodnotu do bezpečného úložiště.
  Future<void> setSecureValue(String key, String value) async {
    if (!_initialized) await initialize();
    
    try {
      await _secureStorage.write(key: key, value: value);
      
      // Bezpečné hodnoty neukládáme do cache!
      
      // Vynucení notifikace o změně
      _notifyChange(key);
    } catch (e) {
      debugPrint("Failed to save secure value for key $key: $e");
      rethrow;
    }
  }

  /// Čte hodnotu z bezpečného úložiště.
  Future<String?> getSecureValue(String key) async {
    if (!_initialized) await initialize();
    
    try {
      // Bezpečné hodnoty neukládáme do cache!
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint("Failed to get secure value for key $key: $e");
      rethrow;
    }
  }

  /// Ukládá objekt do úložiště jako JSON.
  Future<bool> setObject(String key, Object value) async {
    if (!_initialized) await initialize();
    
    try {
      final jsonString = jsonEncode(value);
      final success = await _preferences.setString(key, jsonString);
      
      // Aktualizace cache
      if (success) {
        _updateCache(key, value);
        _notifyChange(key);
      }
      
      return success;
    } catch (e) {
      debugPrint("Failed to save object for key $key: $e");
      return false;
    }
  }

  /// Čte objekt z úložiště jako JSON.
  T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    try {
      // Nejprve zkusíme načíst z cache
      if (_isCacheValid(key) && _cache[key] is T) {
        return _cache[key] as T;
      }
      
      // Pokud není v cache, načteme z úložiště
      final jsonString = _preferences.getString(key);
      if (jsonString == null) {
        return null;
      }
      
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final object = fromJson(jsonMap);
      
      // Aktualizace cache
      _updateCache(key, object);
      
      return object;
    } catch (e) {
      debugPrint("Failed to get object for key $key: $e");
      return null;
    }
  }

  /// Ukládá binární data do souboru.
  Future<bool> setBinaryData(String key, List<int> data) async {
    if (!_initialized) await initialize();
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/$key";
      final file = File(path);
      
      await file.writeAsBytes(data);
      
      // Aktualizace reference v SharedPreferences
      await _preferences.setString("__file_$key", path);
      
      // Vynucení notifikace o změně
      _notifyChange(key);
      
      return true;
    } catch (e) {
      debugPrint("Failed to save binary data for key $key: $e");
      return false;
    }
  }

  /// Čte binární data ze souboru.
  Future<List<int>?> getBinaryData(String key) async {
    if (!_initialized) await initialize();
    
    try {
      final path = _preferences.getString("__file_$key");
      if (path == null) {
        return null;
      }
      
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      
      return await file.readAsBytes();
    } catch (e) {
      debugPrint("Failed to get binary data for key $key: $e");
      return null;
    }
  }

  /// Odstraňuje hodnotu z úložiště.
  Future<bool> removeValue(String key) async {
    if (!_initialized) await initialize();
    
    try {
      // Odstranění z cache
      _cache.remove(key);
      _cacheExpiry.remove(key);
      
      // Kontrola, zda jde o soubor
      final isFile = _preferences.containsKey("__file_$key");
      
      if (isFile) {
        final path = _preferences.getString("__file_$key");
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          await _preferences.remove("__file_$key");
        }
      }
      
      // Kontrola, zda jde o bezpečnou hodnotu
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {
        // Ignorujeme chybu, pokud hodnota neexistuje
      }
      
      // Vynucení notifikace o změně
      _notifyChange(key);
      
      // Odstranění z běžného úložiště
      return await _preferences.remove(key);
    } catch (e) {
      debugPrint("Failed to remove value for key $key: $e");
      return false;
    }
  }

  /// Vyčistí celé úložiště.
  Future<bool> clear() async {
    if (!_initialized) await initialize();
    
    try {
      // Vyčištění cache
      _cache.clear();
      _cacheExpiry.clear();
      
      // Vyčištění souborů
      final filePrefixKeys = _preferences.getKeys()
          .where((key) => key.startsWith("__file_"))
          .toList();
      
      for (final key in filePrefixKeys) {
        final path = _preferences.getString(key);
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
      
      // Vyčištění bezpečného úložiště
      await _secureStorage.deleteAll();
      
      // Vynucení notifikace o změně
      _notifyChange("*");
      
      // Vyčištění běžného úložiště
      return await _preferences.clear();
    } catch (e) {
      debugPrint("Failed to clear database: $e");
      return false;
    }
  }

  /// Vrací všechny klíče v úložišti.
  Set<String> getKeys() {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    return _preferences.getKeys();
  }

  /// Kontroluje, zda úložiště obsahuje daný klíč.
  bool containsKey(String key) {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    return _preferences.containsKey(key) || _cache.containsKey(key);
  }

  /// Aktualizuje hodnotu v cache.
  void _updateCache(String key, dynamic value) {
    // Pokud je hodnota příliš velká, neukládáme ji do cache
    final valueSize = _estimateSize(value);
    if (valueSize > _maxCacheItemSize) {
      return;
    }
    
    _cache[key] = value;
    _cacheExpiry[key] = DateTime.now().add(Duration(milliseconds: _cacheExpiryMs));
  }

  /// Kontroluje, zda je položka v cache platná (neexpirovaná).
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheExpiry.containsKey(key)) {
      return false;
    }
    
    final expiry = _cacheExpiry[key]!;
    return DateTime.now().isBefore(expiry);
  }

  /// Odhaduje velikost hodnoty.
  int _estimateSize(dynamic value) {
    if (value is String) {
      return value.length * 2; // Přibližná velikost v UTF-16
    } else if (value is int || value is double) {
      return 8; // 64 bitů
    } else if (value is bool) {
      return 1;
    } else if (value is List) {
      return value.fold<int>(0, (sum, item) => sum + _estimateSize(item));
    } else if (value is Map) {
      return value.entries.fold<int>(
        0, 
        (sum, entry) => sum + _estimateSize(entry.key) + _estimateSize(entry.value)
      );
    } else {
      return 100; // Výchozí odhad pro ostatní typy
    }
  }

  /// Oznamuje změnu v databázi.
  void _notifyChange(String key) {
    _changeController.add(key);
  }

  /// Spočítá hash z dat.
  String computeHash(List<int> data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Uvolňuje zdroje.
  void dispose() {
    _changeController.close();
  }
}
'

# 8. base_repository.dart (střední priorita)
create_file "lib/services/base_repository.dart" '// lib/services/base_repository.dart

import "dart:async";
import "package:flutter/foundation.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "../utils/connectivity_manager.dart";
import "../utils/error_handler.dart";

/// Abstraktní třída pro repository pattern.
///
/// Poskytuje základní CRUD operace a zpracování chyb pro práci
/// s Firestore a dalšími úložišti dat.
abstract class BaseRepository<T> {
  // Instance Firestore
  final FirebaseFirestore _firestore;
  
  // Instance ConnectivityManager
  final ConnectivityManager _connectivityManager;
  
  // Instance ErrorHandler
  final ErrorHandler _errorHandler;
  
  // Název kolekce v databázi
  final String _collectionName;
  
  // Streamový kontrolér pro vysílání dat
  final StreamController<List<T>> _itemsStreamController =
      StreamController<List<T>>.broadcast();
  
  // Cache dat
  List<T> _cachedItems = [];
  
  // Poslední čas synchronizace
  DateTime? _lastSyncTime;
  
  // Indikátor, zda probíhá operace
  bool _isLoading = false;
  
  // Stream událostí Firestore
  StreamSubscription? _firestoreSubscription;

  /// Vytvoří novou instanci BaseRepository.
  BaseRepository({
    required FirebaseFirestore firestore,
    required ConnectivityManager connectivityManager,
    required ErrorHandler errorHandler,
    required String collectionName,
  }) : 
    _firestore = firestore,
    _connectivityManager = connectivityManager,
    _errorHandler = errorHandler,
    _collectionName = collectionName;

  /// Stream pro sledování dat.
  Stream<List<T>> get dataStream => _itemsStreamController.stream;
  
  /// Vrací všechny položky v cache.
  List<T> get cachedItems => _cachedItems;
  
  /// Indikátor, zda probíhá načítání.
  bool get isLoading => _isLoading;
  
  /// Poslední čas synchronizace.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Vrací odkaz na kolekci v databázi.
  CollectionReference<Map<String, dynamic>> get collection => 
      _firestore.collection(_collectionName);

  /// Inicializuje repository a nastavuje posluchače.
  Future<void> initialize() async {
    _setupFirestoreListener();
    _connectivityManager.onConnectivityChanged((isOnline) {
      if (isOnline) {
        _refreshData();
      }
    });
  }

  /// Nastaví posluchače změn v databázi.
  void _setupFirestoreListener() {
    _firestoreSubscription?.cancel();
    
    _firestoreSubscription = collection.snapshots().listen(
      (snapshot) {
        try {
          final items = snapshot.docs.map((doc) {
            final data = doc.data();
            if (!data.containsKey("id")) {
              data["id"] = doc.id;
            }
            return fromJson(data);
          }).toList();
          
          _cachedItems = items;
          _lastSyncTime = DateTime.now();
          _itemsStreamController.add(items);
          
          debugPrint("${_collectionName.toUpperCase()}: Received ${items.length} items from Firestore");
        } catch (e, stackTrace) {
          _handleError("Error processing Firestore snapshot", e, stackTrace);
        }
      },
      onError: (error, stackTrace) {
        _handleError("Error listening to Firestore", error, stackTrace);
      },
    );
  }

  /// Konvertuje JSON mapu na objekt.
  T fromJson(Map<String, dynamic> json);
  
  /// Konvertuje objekt na JSON mapu.
  Map<String, dynamic> toJson(T item);
  
  /// Získá ID objektu.
  String getId(T item);

  /// Načte všechny položky z databáze.
  Future<List<T>> fetchAll({
    int limit = 50,
    String orderBy = "createdAt",
    bool descending = true,
  }) async {
    _setLoading(true);
    
    try {
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, using cached data");
        _setLoading(false);
        return _cachedItems;
      }
      
      Query<Map<String, dynamic>> query = collection
          .orderBy(orderBy, descending: descending)
          .limit(limit);
      
      final snapshot = await query.get();
      
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey("id")) {
          data["id"] = doc.id;
        }
        return fromJson(data);
      }).toList();
      
      _cachedItems = items;
      _lastSyncTime = DateTime.now();
      _itemsStreamController.add(items);
      
      debugPrint("${_collectionName.toUpperCase()}: Fetched ${items.length} items");
      
      _setLoading(false);
      return items;
    } catch (e, stackTrace) {
      _handleError("Error fetching items", e, stackTrace);
      _setLoading(false);
      return _cachedItems;
    }
  }

  /// Načte položku podle ID.
  Future<T?> fetchById(String id) async {
    _setLoading(true);
    
    try {
      // Nejprve zkusíme najít v cache
      final cachedItem = _cachedItems.firstWhere(
        (item) => getId(item) == id,
        orElse: () => null as T,
      );
      
      if (cachedItem != null) {
        _setLoading(false);
        return cachedItem;
      }
      
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, item not found in cache");
        _setLoading(false);
        return null;
      }
      
      final docSnapshot = await collection.doc(id).get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        _setLoading(false);
        return null;
      }
      
      final data = docSnapshot.data()!;
      if (!data.containsKey("id")) {
        data["id"] = docSnapshot.id;
      }
      
      final item = fromJson(data);
      
      // Aktualizace cache
      final index = _cachedItems.indexWhere((i) => getId(i) == id);
      if (index >= 0) {
        _cachedItems[index] = item;
      } else {
        _cachedItems.add(item);
      }
      
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Fetched item with ID $id");
      
      _setLoading(false);
      return item;
    } catch (e, stackTrace) {
      _handleError("Error fetching item with ID $id", e, stackTrace);
      _setLoading(false);
      return null;
    }
  }

  /// Vytvoří novou položku v databázi.
  Future<T?> create(T item) async {
    _setLoading(true);
    
    try {
      final json = toJson(item);
      
      // Odstranění ID, pokud je null nebo prázdné
      if (json.containsKey("id") && (json["id"] == null || json["id"].toString().isEmpty)) {
        json.remove("id");
      }
      
      // Přidání časových razítek, pokud chybí
      if (!json.containsKey("createdAt")) {
        json["createdAt"] = FieldValue.serverTimestamp();
      }
      if (!json.containsKey("updatedAt")) {
        json["updatedAt"] = FieldValue.serverTimestamp();
      }
      
      // Pokud jsme offline, uložíme položku do fronty pro pozdější zpracování
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, scheduling create for later");
        _connectivityManager.addPendingAction(() => create(item));
        _setLoading(false);
        return null;
      }
      
      // Vytvoření dokumentu
      final docRef = await collection.add(json);
      
      // Načtení vytvořeného dokumentu
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        _setLoading(false);
        return null;
      }
      
      final data = docSnapshot.data()!;
      data["id"] = docSnapshot.id;
      
      final createdItem = fromJson(data);
      
      // Aktualizace cache
      _cachedItems.add(createdItem);
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Created item with ID ${docRef.id}");
      
      _setLoading(false);
      return createdItem;
    } catch (e, stackTrace) {
      _handleError("Error creating item", e, stackTrace);
      _setLoading(false);
      return null;
    }
  }

  /// Aktualizuje položku v databázi.
  Future<T?> update(T item) async {
    _setLoading(true);
    
    try {
      final id = getId(item);
      final json = toJson(item);
      
      // Přidání časového razítka aktualizace
      json["updatedAt"] = FieldValue.serverTimestamp();
      
      // Pokud jsme offline, uložíme položku do fronty pro pozdější zpracování
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, scheduling update for later");
        _connectivityManager.addPendingAction(() => update(item));
        
        // Aktualizace cache
        final index = _cachedItems.indexWhere((i) => getId(i) == id);
        if (index >= 0) {
          _cachedItems[index] = item;
          _itemsStreamController.add(_cachedItems);
        }
        
        _setLoading(false);
        return item;
      }
      
      // Aktualizace dokumentu
      await collection.doc(id).update(json);
      
      // Načtení aktualizovaného dokumentu
      final docSnapshot = await collection.doc(id).get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        _setLoading(false);
        return null;
      }
      
      final data = docSnapshot.data()!;
      data["id"] = docSnapshot.id;
      
      final updatedItem = fromJson(data);
      
      // Aktualizace cache
      final index = _cachedItems.indexWhere((i) => getId(i) == id);
      if (index >= 0) {
        _cachedItems[index] = updatedItem;
      } else {
        _cachedItems.add(updatedItem);
      }
      
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Updated item with ID $id");
      
      _setLoading(false);
      return updatedItem;
    } catch (e, stackTrace) {
      _handleError("Error updating item", e, stackTrace);
      _setLoading(false);
      return null;
    }
  }

  /// Odstraní položku z databáze.
  Future<bool> delete(String id) async {
    _setLoading(true);
    
    try {
      // Pokud jsme offline, uložíme požadavek do fronty pro pozdější zpracování
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, scheduling delete for later");
        _connectivityManager.addPendingAction(() => delete(id));
        
        // Aktualizace cache
        _cachedItems.removeWhere((item) => getId(item) == id);
        _itemsStreamController.add(_cachedItems);
        
        _setLoading(false);
        return true;
      }
      
      // Odstranění dokumentu
      await collection.doc(id).delete();
      
      // Aktualizace cache
      _cachedItems.removeWhere((item) => getId(item) == id);
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Deleted item with ID $id");
      
      _setLoading(false);
      return true;
    } catch (e, stackTrace) {
      _handleError("Error deleting item with ID $id", e, stackTrace);
      _setLoading(false);
      return false;
    }
  }

  /// Ruční aktualizace dat.
  Future<void> _refreshData() async {
    await fetchAll();
  }
  
  /// Ruční aktualizace dat (veřejná metoda).
  Future<void> refreshData() async {
    await _refreshData();
  }

  /// Nastaví stav načítání.
  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  /// Zpracovává chyby.
  void _handleError(String message, dynamic error, StackTrace stackTrace) {
    debugPrint("${_collectionName.toUpperCase()}: $message: $error");
    debugPrintStack(label: "StackTrace", stackTrace: stackTrace);
    
    _errorHandler.handleError(
      error,
      stackTrace,
      context: _collectionName,
      showToUser: false,
    );
  }

  /// Uvolní zdroje.
  void dispose() {
    _firestoreSubscription?.cancel();
    _itemsStreamController.close();
  }
}
'

# 9. Test soubory
create_file "test/unit/auth_service_test.dart" '// test/unit/auth_service_test.dart

import "package:flutter_test/flutter_test.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart";
import "package:svatebni_planovac/services/auth_service.dart";

import "auth_service_test.mocks.dart";

@GenerateMocks([fb.FirebaseAuth, fb.UserCredential, fb.User])
void main() {
  group("AuthService Tests", () {
    late MockFirebaseAuth mockFirebaseAuth;
    late AuthService authService;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      authService = AuthService();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();

      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn("test-uid");
      when(mockUser.email).thenReturn("test@example.com");
    });

    test("signInWithEmail should return UserCredential when successful", () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: "test@example.com",
        password: "password",
      )).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signInWithEmail("test@example.com", "password");

      expect(result, isNotNull);
      expect(result?.user?.uid, equals("test-uid"));
      expect(result?.user?.email, equals("test@example.com"));
    });

    test("signInWithEmail should throw AuthException when FirebaseAuthException occurs", () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: "test@example.com",
        password: "password",
      )).thenThrow(
        fb.FirebaseAuthException(
          code: "wrong-password",
          message: "The password is invalid",
        ),
      );

      expect(
        () => authService.signInWithEmail("test@example.com", "password"),
        throwsA(isA<AuthException>()),
      );
    });

    test("signOut should sign out from all providers", () async {
      await authService.signOut();
      verify(mockFirebaseAuth.signOut()).called(1);
    });
  });
}
'

create_file "test/widget/login_screen_test.dart" '// test/widget/login_screen_test.dart

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
create_file "test/widget/login_screen_test.dart" '// test/widget/login_screen_test.dart

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:provider/provider.dart";
import "package:svatebni_planovac/services/auth_service.dart";
import "package:svatebni_planovac/screens/auth_screen.dart";

import "login_screen_test.mocks.dart";

@GenerateMocks([AuthService])
void main() {
 group("Login Screen Tests", () {
   late MockAuthService mockAuthService;

   setUp(() {
     mockAuthService = MockAuthService();
   });

   testWidgets("should display login form elements", (WidgetTester tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     expect(find.text("Přihlásit se"), findsOneWidget);
     expect(find.text("Email"), findsOneWidget);
     expect(find.text("Heslo"), findsOneWidget);
     expect(find.byType(TextFormField), findsAtLeast(2));
     expect(find.byType(ElevatedButton), findsOneWidget);
   });

   testWidgets("should show error on invalid email", (WidgetTester tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     await tester.enterText(find.byType(TextFormField).first, "invalid-email");
     await tester.tap(find.byType(ElevatedButton));
     await tester.pump();

     expect(find.text("Neplatná emailová adresa."), findsOneWidget);
   });

   testWidgets("should show error on empty password", (WidgetTester tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     await tester.enterText(find.byType(TextFormField).first, "test@example.com");
     await tester.tap(find.byType(ElevatedButton));
     await tester.pump();

     expect(find.text("Heslo je povinné"), findsOneWidget);
   });

   testWidgets("should call signInWithEmail on valid form submission", (WidgetTester tester) async {
     when(mockAuthService.signInWithEmail(any, any))
       .thenAnswer((_) async => null);

     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     await tester.enterText(find.byType(TextFormField).first, "test@example.com");
     await tester.enterText(find.byType(TextFormField).last, "password123");
     await tester.tap(find.byType(ElevatedButton));
     await tester.pump();

     verify(mockAuthService.signInWithEmail("test@example.com", "password123")).called(1);
   });
 });
}
'

# 10. caching_strategy.dart (nižší priorita)
create_file "lib/services/caching_strategy.dart" '// lib/services/caching_strategy.dart

import "dart:async";
import "package:flutter/foundation.dart";
import "../utils/local_database.dart";

/// Strategie pro cachování dat v aplikaci.
///
/// Definuje různé přístupy k cachování dat podle typu dat 
/// a frekvence jejich změn.
abstract class CachingStrategy<T> {
 /// Instance LocalDatabase
 final LocalDatabase _database;
 
 /// Klíč pro ukládání do cache
 final String _cacheKey;
 
 /// Čas expirace dat v cache (v ms)
 final int _expiryTimeMs;
 
 CachingStrategy({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
 })  : _database = database,
       _cacheKey = cacheKey,
       _expiryTimeMs = expiryTimeMs;

 /// Ukládá data do cache.
 Future<void> saveToCache(T data);
 
 /// Načítá data z cache.
 Future<T?> loadFromCache();
 
 /// Kontroluje, zda jsou data v cache platná.
 Future<bool> isCacheValid();
 
 /// Načítá data z cloudového zdroje.
 Future<T> loadFromCloud();
 
 /// Vyčistí data v cache.
 Future<void> clearCache() async {
   await _database.removeValue(_cacheKey);
   await _database.removeValue("${_cacheKey}_timestamp");
 }
 
 /// Aktualizuje časové razítko v cache.
 Future<void> updateTimestamp() async {
   final now = DateTime.now().millisecondsSinceEpoch;
   await _database.setValue("${_cacheKey}_timestamp", now);
 }
 
 /// Načítá časové razítko z cache.
 Future<int?> getTimestamp() async {
   return _database.getValue("${_cacheKey}_timestamp") as int?;
 }
 
 /// Kontroluje, zda je cache expirovaná.
 Future<bool> isCacheExpired() async {
   final timestamp = await getTimestamp();
   if (timestamp == null) {
     return true;
   }
   
   final now = DateTime.now().millisecondsSinceEpoch;
   return now - timestamp > _expiryTimeMs;
 }
 
 /// Načítá data z cache nebo z cloudu, podle potřeby.
 Future<T> getData() async {
   try {
     if (await isCacheValid()) {
       final cachedData = await loadFromCache();
       if (cachedData != null) {
         debugPrint("Loaded data from cache for key $_cacheKey");
         return cachedData;
       }
     }
     
     final cloudData = await loadFromCloud();
     await saveToCache(cloudData);
     await updateTimestamp();
     
     debugPrint("Loaded data from cloud for key $_cacheKey");
     return cloudData;
   } catch (e) {
     debugPrint("Error getting data for key $_cacheKey: $e");
     
     // Pokud dojde k chybě při načítání z cloudu, zkusíme načíst z cache
     // i když je expirovaná
     final cachedData = await loadFromCache();
     if (cachedData != null) {
       debugPrint("Using expired cache data for key $_cacheKey due to error");
       return cachedData;
     }
     
     rethrow;
   }
 }
}

/// Strategie pro cachování objektů jako JSON.
class JsonCachingStrategy<T> extends CachingStrategy<T> {
 /// Funkce pro konverzi JSON mapy na objekt.
 final T Function(Map<String, dynamic> json) _fromJson;
 
 /// Funkce pro konverzi objektu na JSON mapu.
 final Map<String, dynamic> Function(T data) _toJson;
 
 /// Funkce pro načítání dat z cloudu.
 final Future<T> Function() _fetchFromCloud;

 JsonCachingStrategy({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
   required T Function(Map<String, dynamic> json) fromJson,
   required Map<String, dynamic> Function(T data) toJson,
   required Future<T> Function() fetchFromCloud,
 })  : _fromJson = fromJson,
       _toJson = toJson,
       _fetchFromCloud = fetchFromCloud,
       super(
         database: database,
         cacheKey: cacheKey,
         expiryTimeMs: expiryTimeMs,
       );

 @override
 Future<void> saveToCache(T data) async {
   final json = _toJson(data);
   await _database.setObject(_cacheKey, json);
 }

 @override
 Future<T?> loadFromCache() async {
   final json = _database.getObject<Map<String, dynamic>>(
     _cacheKey,
     (json) => json,
   );
   
   if (json == null) {
     return null;
   }
   
   return _fromJson(json);
 }

 @override
 Future<bool> isCacheValid() async {
   final hasCachedData = _database.containsKey(_cacheKey);
   if (!hasCachedData) {
     return false;
   }
   
   return !(await isCacheExpired());
 }

 @override
 Future<T> loadFromCloud() async {
   return _fetchFromCloud();
 }
}

/// Strategie pro cachování seznamu objektů.
class ListCachingStrategy<T> extends CachingStrategy<List<T>> {
 /// Funkce pro konverzi JSON mapy na objekt.
 final T Function(Map<String, dynamic> json) _fromJson;
 
 /// Funkce pro konverzi objektu na JSON mapu.
 final Map<String, dynamic> Function(T data) _toJson;
 
 /// Funkce pro načítání dat z cloudu.
 final Future<List<T>> Function() _fetchFromCloud;

 ListCachingStrategy({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
   required T Function(Map<String, dynamic> json) fromJson,
   required Map<String, dynamic> Function(T data) toJson,
   required Future<List<T>> Function() fetchFromCloud,
 })  : _fromJson = fromJson,
       _toJson = toJson,
       _fetchFromCloud = fetchFromCloud,
       super(
         database: database,
         cacheKey: cacheKey,
         expiryTimeMs: expiryTimeMs,
       );

 @override
 Future<void> saveToCache(List<T> data) async {
   final jsonList = data.map((item) => _toJson(item)).toList();
   await _database.setObject(_cacheKey, jsonList);
 }

 @override
 Future<List<T>?> loadFromCache() async {
   final jsonList = _database.getObject<List<dynamic>>(
     _cacheKey,
     (json) => json,
   );
   
   if (jsonList == null) {
     return null;
   }
   
   return jsonList
       .cast<Map<String, dynamic>>()
       .map((json) => _fromJson(json))
       .toList();
 }

 @override
 Future<bool> isCacheValid() async {
   final hasCachedData = _database.containsKey(_cacheKey);
   if (!hasCachedData) {
     return false;
   }
   
   return !(await isCacheExpired());
 }

 @override
 Future<List<T>> loadFromCloud() async {
   return _fetchFromCloud();
 }
}

/// Tovární třída pro vytváření cachingových strategií.
class CachingStrategyFactory {
 static JsonCachingStrategy<T> createJsonStrategy<T>({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
   required T Function(Map<String, dynamic> json) fromJson,
   required Map<String, dynamic> Function(T data) toJson,
   required Future<T> Function() fetchFromCloud,
 }) {
   return JsonCachingStrategy<T>(
     database: database,
     cacheKey: cacheKey,
     expiryTimeMs: expiryTimeMs,
     fromJson: fromJson,
     toJson: toJson,
     fetchFromCloud: fetchFromCloud,
   );
 }

 static ListCachingStrategy<T> createListStrategy<T>({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
   required T Function(Map<String, dynamic> json) fromJson,
   required Map<String, dynamic> Function(T data) toJson,
   required Future<List<T>> Function() fetchFromCloud,
 }) {
   return ListCachingStrategy<T>(
     database: database,
     cacheKey: cacheKey,
     expiryTimeMs: expiryTimeMs,
     fromJson: fromJson,
     toJson: toJson,
     fetchFromCloud: fetchFromCloud,
   );
 }
}
'

# Vytvoření .env souboru jako šablonu pro konfiguraci
create_file ".env.example" '# API klíče
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_PROJECT_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_STORAGE_BUCKET=

# Konfigurace aplikace
APP_ENVIRONMENT=development
API_URL=https://api.example.com
ENABLE_ANALYTICS=false
ENABLE_CRASHLYTICS=false
'

# Vytvoření README souboru s instrukcemi pro vytvoření produkční aplikace
create_file "README.md" '# Svatební Plánovač - Produkční nasazení

Tento dokument obsahuje pokyny pro nastavení a nasazení aplikace do produkčního prostředí.

## Příprava prostředí

1. Vytvořte `.env` soubor podle šablony `.env.example`:
  ```bash
  cp .env.example .env