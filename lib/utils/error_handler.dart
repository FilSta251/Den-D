/// lib/utils/error_handler.dart
library;

import "dart:async";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:easy_localization/easy_localization.dart";
import "../services/navigation_service.dart";
import "../services/crash_reporting_service.dart";
import '../di/service_locator.dart' show locator;

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
  static const String _categoryTimeout = "timeout";
  static const String _categoryUnknown = "unknown";

  // Maximální počet stejných chyb, které se zobrazí uživateli v určitém časovém okně
  static const int _maxSimilarErrorsThreshold = 3;

  // Časové okno pro sledování opakujících se chyb (v ms)
  static const int _errorWindowMs = 60000; // 1 minuta

  // Mapa pro sledování opakujících se chyb
  final Map<String, List<DateTime>> _errorOccurrences = {};

  /// Inicializuje ErrorHandler s potřebnými závislostmi.
  Future<void> initialize() async {
    _crashReportingService = locator<CrashReportingService>();
    _navigationService = locator<NavigationService>();

    // Nastavení globálního handleru pro Flutter chyby
    FlutterError.onError = _handleFlutterError;

    // Nastavení globálního handleru pro asynchronní chyby
    PlatformDispatcher.instance.onError = _handlePlatformError;

    debugPrint("[ErrorHandler] Initialized");
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
        (time) => now.difference(time).inMilliseconds > _errorWindowMs);

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
        errorString.contains("network") ||
        errorString.contains("connection") ||
        errorString.contains("unable to resolve host") ||
        errorString.contains("no address associated")) {
      return _categoryNetwork;
    } else if (errorString.contains("timeout") ||
        errorString.contains("trvala příliš dlouho") ||
        errorString.contains("operation") && errorString.contains("time")) {
      return _categoryTimeout;
    } else if (errorString.contains("auth") ||
        errorString.contains("login") ||
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
        errorString.contains("widget") ||
        errorString.contains("overflow")) {
      return _categoryUI;
    }

    return _categoryUnknown;
  }

  /// Převádí technickou chybu na uživatelsky přívětivou zprávu.
  String _getUserFriendlyMessage(dynamic error, String category) {
    switch (category) {
      case _categoryNetwork:
        return tr('error.network');
      case _categoryTimeout:
        return tr('error.timeout');
      case _categoryAuthentication:
        return tr('error.authentication');
      case _categoryPermission:
        return tr('error.permission');
      case _categoryStorage:
        return tr('error.storage');
      case _categoryUI:
        return tr('error.ui');
      default:
        return tr('error.unknown');
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
    // Logování do konzole pouze v debug režimu
    if (kDebugMode) {
      debugPrint("ERROR [$category]: $error");
      if (stackTrace != null) {
        debugPrint("Stack trace: $stackTrace");
      }
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

  /// Zobrazí chybu uživateli vhodným způsobem - OPRAVENO: overflow handling
  void _showErrorToUser(String message, String category, bool isFatal) {
    final context = _navigationService.navigatorKey.currentContext;

    if (context != null && context.mounted) {
      // Pro UI chyby (overflow apod.) - nezobrazovat uživateli
      if (category == _categoryUI && !isFatal) {
        return;
      }

      // Pro fatální chyby zobrazíme dialog
      if (isFatal) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogContext) => AlertDialog(
                title: Text(
                  tr('error.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.4,
                  ),
                  child: SingleChildScrollView(
                    child: Text(message),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          }
        });
      } else if (category != _categoryTimeout) {
        // Pro běžné chyby (kromě timeout) stačí Snackbar
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                action: category == _categoryNetwork
                    ? SnackBarAction(
                        label: tr('error.retry'),
                        onPressed: () {
                          // Zde by byla logika pro opakování poslední akce
                        },
                      )
                    : null,
              ),
            );
          }
        });
      }
      // Pro timeout chyby - nezobrazovat nic, jen zalogovat
    } else {
      // Pokud nemáme context, pouze logujeme
      if (kDebugMode) {
        debugPrint("Cannot show error to user (no context): $message");
      }
    }
  }
}
