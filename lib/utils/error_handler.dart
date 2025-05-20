// lib/utils/error_handler.dart

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
