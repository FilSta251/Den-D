/// lib/utils/global_error_handler.dart - PRODUKČNÍ VERZE
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/custom_error_widget.dart';
import 'package:den_d/widgets/error_dialog.dart';
import '../services/crash_reporting_service.dart';
import 'package:flutter/services.dart';
import '../di/service_locator.dart' as di;
import '../services/navigation_service.dart';

/// Enum pro typy chyb v aplikaci
enum ErrorType {
  network,
  auth,
  validation,
  permission,
  server,
  storage,
  critical,
  unknown,
  warning,
  info,
  timeout,
}

/// Třída reprezentující chybu v aplikaci
class AppError {
  final String message;
  final ErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final String? userMessage;
  final String? errorCode;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  AppError({
    required this.message,
    required this.type,
    this.originalError,
    this.stackTrace,
    this.userMessage,
    this.errorCode,
    this.context,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    return 'AppError(type: $type, message: $message, code: $errorCode)';
  }
}

/// Callback typ pro handling chyb
typedef ErrorCallback = void Function(AppError error);

/// Produkční globální handler pro zpracování chyb v celé aplikaci
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  static GlobalErrorHandler get instance => _instance;

  GlobalErrorHandler._internal();

  // NavigationService pro bezpečný přístup ke kontextu
  NavigationService? get _navigationService {
    try {
      return di.locator<NavigationService>();
    } catch (_) {
      return null;
    }
  }

  // Bezpečný přístup k navigator kontextu
  BuildContext? get _safeContext =>
      _navigationService?.navigatorKey.currentContext;

  // Globální scaffoldMessengerKey
  GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;

  /// Nastavení globálního scaffoldMessengerKey
  void setScaffoldMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
    debugPrint('[GlobalErrorHandler] ScaffoldMessengerKey registered');
  }

  // Callback pro custom handling chyb
  ErrorCallback? _errorCallback;

  // Service pro crash reporting
  CrashReportingService? _crashReportingService;

  // Sledování chyb
  final List<AppError> _errorHistory = [];
  static const int _maxErrorHistory = 100;

  // Throttling pro podobné chyby
  final Map<String, DateTime> _errorThrottling = {};
  static const Duration _throttleInterval = Duration(seconds: 30);

  // Počítadlo chyb
  final Map<ErrorType, int> _errorCounts = {};

  // Stream pro broadcasting chyb
  final StreamController<AppError> _errorStreamController =
      StreamController<AppError>.broadcast();

  Stream<AppError> get errorStream => _errorStreamController.stream;

  bool _initialized = false;

  /// Inicializace error handleru
  static void initialize({
    CrashReportingService? crashReportingService,
  }) {
    final handler = GlobalErrorHandler.instance;
    handler._crashReportingService = crashReportingService;

    // Nastavení Flutter error handleru
    FlutterError.onError = (FlutterErrorDetails details) {
      handler._handleFlutterError(details);
    };

    // Nastavení platform error handleru
    PlatformDispatcher.instance.onError = (error, stack) {
      handler._handlePlatformError(error, stack);
      return true;
    };

    handler._initialized = true;
    debugPrint('[GlobalErrorHandler] Production handler initialized');
  }

  /// Nastavení custom error callback
  void setErrorCallback(ErrorCallback callback) {
    _errorCallback = callback;
  }

  /// Hlavní metoda pro zpracování chyb
  Future<void> handleError(
    dynamic error, {
    StackTrace? stackTrace,
    ErrorType type = ErrorType.unknown,
    String? userMessage,
    String? errorCode,
    Map<String, dynamic>? context,
    bool showToUser = true,
    bool reportToCrashlytics = true,
  }) async {
    try {
      final appError = AppError(
        message: error.toString(),
        type: type,
        originalError: error,
        stackTrace: stackTrace,
        userMessage: userMessage,
        errorCode: errorCode,
        context: context,
      );

      // Přidání do historie
      _addToErrorHistory(appError);

      // Aktualizace počítadel
      _updateErrorCounts(type);

      // Broadcasting chyby
      _errorStreamController.add(appError);

      // Throttling kontrola
      if (_shouldThrottleError(appError)) {
        return;
      }

      // Logování
      _logError(appError);

      // Crash reporting - kritéria pro reportování
      if (reportToCrashlytics && _shouldReportToCrashlytics(type)) {
        await _reportToCrashlytics(appError);
      }

      // Custom callback
      _errorCallback?.call(appError);

      // UI handling - nezobrazovat minor chyby
      if (showToUser && _shouldShowToUser(type)) {
        await _showErrorToUser(appError);
      }
    } catch (e, stack) {
      // Fallback - pokud selže i error handler
      debugPrint('[GlobalErrorHandler] Critical: Error in error handler: $e');
      developer.log(
        'Critical error in GlobalErrorHandler',
        error: e,
        stackTrace: stack,
        level: 1000,
      );
    }
  }

  /// Zpracování Flutter chyb s inteligentním filtrováním
  void _handleFlutterError(FlutterErrorDetails details) {
    final errorString = details.exception.toString().toLowerCase();

    // Kompletní filtrování overflow chyb - NEPOSÍLAT DO CRASHLYTICS
    if (_isOverflowError(errorString)) {
      // Pouze logování v debug módu, BEZ reportování
      if (kDebugMode) {
        debugPrint('[UI Overflow - Non-fatal] ${details.exception}');
      }
      // DŮLEŽITÉ: Neposílat do Crashlytics ani nezobrazovat uživateli
      return;
    }

    // Filtrování dalších běžných UI chyb
    if (_isMinorUIError(errorString)) {
      if (kDebugMode) {
        debugPrint('[Minor UI Issue - Non-fatal] ${details.exception}');
      }
      return;
    }

    handleError(
      details.exception,
      stackTrace: details.stack,
      type: _categorizeFlutterError(details),
      context: {
        'library': details.library,
        'context': details.context?.toString(),
        'silent': details.silent,
      },
      showToUser: !details.silent && !_isMinorUIError(errorString),
    );
  }

  /// Kontrola, zda je chyba overflow - kompletní filtr
  bool _isOverflowError(String errorString) {
    final overflowPatterns = [
      'overflow',
      'overflowed',
      'renderflex',
      'renderbox',
      'viewport',
      'pixel',
      'bottom overflowed',
      'right overflowed',
      'top overflowed',
      'left overflowed',
    ];

    return overflowPatterns.any((pattern) => errorString.contains(pattern));
  }

  /// Kontrola, zda je chyba minor UI problém
  bool _isMinorUIError(String errorString) {
    final minorPatterns = [
      'renderflex',
      'renderbox',
      'viewport',
      'constraints',
      'unbounded',
      'intrinsic',
    ];

    return minorPatterns.any((pattern) => errorString.contains(pattern));
  }

  /// Zpracování platform chyb
  void _handlePlatformError(Object error, StackTrace stack) {
    handleError(
      error,
      stackTrace: stack,
      type: ErrorType.critical,
      userMessage: tr('error.critical'),
      showToUser: true,
    );
  }

  /// Kategorizace Flutter chyb
  ErrorType _categorizeFlutterError(FlutterErrorDetails details) {
    final error = details.exception.toString().toLowerCase();

    if (error.contains('network') ||
        error.contains('socket') ||
        error.contains('connection')) {
      return ErrorType.network;
    } else if (error.contains('timeout')) {
      return ErrorType.timeout;
    } else if (error.contains('permission')) {
      return ErrorType.permission;
    } else if (error.contains('storage') || error.contains('file')) {
      return ErrorType.storage;
    } else if (error.contains('auth') || error.contains('unauthorized')) {
      return ErrorType.auth;
    } else if (_isOverflowError(error) || _isMinorUIError(error)) {
      return ErrorType.info;
    } else if (error.contains('assertion')) {
      return ErrorType.validation;
    } else {
      return ErrorType.unknown;
    }
  }

  /// Rozhodnutí, zda chybu reportovat do Crashlytics
  bool _shouldReportToCrashlytics(ErrorType type) {
    // NEPOSÍLAT info, warning a timeout chyby do Crashlytics
    return type != ErrorType.info &&
        type != ErrorType.warning &&
        type != ErrorType.timeout;
  }

  /// Rozhodnutí, zda chybu zobrazit uživateli
  bool _shouldShowToUser(ErrorType type) {
    return type != ErrorType.info &&
        type != ErrorType.warning &&
        type != ErrorType.timeout;
  }

  /// Přidání chyby do historie
  void _addToErrorHistory(AppError error) {
    _errorHistory.add(error);

    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
  }

  /// Aktualizace počítadel chyb
  void _updateErrorCounts(ErrorType type) {
    _errorCounts[type] = (_errorCounts[type] ?? 0) + 1;
  }

  /// Kontrola throttlingu pro podobné chyby
  bool _shouldThrottleError(AppError error) {
    final key = '${error.type}_${error.message.hashCode}';
    final now = DateTime.now();

    if (_errorThrottling.containsKey(key)) {
      final lastTime = _errorThrottling[key]!;
      if (now.difference(lastTime) < _throttleInterval) {
        return true;
      }
    }

    _errorThrottling[key] = now;
    return false;
  }

  /// Logování chyby
  void _logError(AppError error) {
    if (kDebugMode) {
      debugPrint('[GlobalErrorHandler] ${error.type}: ${error.message}');
    }

    developer.log(
      error.message,
      name: 'GlobalErrorHandler',
      error: error.originalError,
      stackTrace: error.stackTrace,
      level: _getLogLevel(error.type),
    );

    _crashReportingService?.log(
      message: error.message,
      level: _getCrashReportingLevel(error.type),
      category: error.type.name,
      data: error.context,
    );
  }

  /// Reportování do Crashlytics s správným fatal flag
  Future<void> _reportToCrashlytics(AppError error) async {
    try {
      // Info a warning chyby NEPOSÍLAT vůbec
      if (error.type == ErrorType.info || error.type == ErrorType.warning) {
        return;
      }

      await FirebaseCrashlytics.instance.recordError(
        error.originalError ?? error.message,
        error.stackTrace,
        reason: error.userMessage ?? 'Application error',
        fatal: error.type == ErrorType.critical,
        information: [
          'Error Type: ${error.type.name}',
          'Error Code: ${error.errorCode ?? 'N/A'}',
          'Timestamp: ${error.timestamp.toIso8601String()}',
          if (error.context != null) 'Context: ${error.context}',
        ],
      );

      if (error.errorCode != null) {
        FirebaseCrashlytics.instance
            .setCustomKey('error_code', error.errorCode!);
      }
      FirebaseCrashlytics.instance.setCustomKey('error_type', error.type.name);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GlobalErrorHandler] Crashlytics reporting failed: $e');
      }
    }
  }

  /// Zobrazení chyby uživateli s bezpečným kontextem
  Future<void> _showErrorToUser(AppError error) async {
    try {
      final context = _safeContext;

      if (context == null || !context.mounted) {
        if (kDebugMode) {
          debugPrint(
              '[GlobalErrorHandler] No valid navigator context available');
        }
        return;
      }

      final shouldShowDialog = _shouldShowErrorDialog(error.type);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (shouldShowDialog) {
            _showErrorDialog(error, context);
          } else {
            _showErrorSnackBar(error);
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GlobalErrorHandler] Failed to show error UI: $e');
      }
    }
  }

  /// Rozhodnutí, zda zobrazit dialog nebo snackbar
  bool _shouldShowErrorDialog(ErrorType type) {
    return type == ErrorType.critical ||
        type == ErrorType.auth ||
        type == ErrorType.permission ||
        type == ErrorType.server;
  }

  /// Zobrazení error dialogu s bezpečným kontextem
  Future<void> _showErrorDialog(AppError error, BuildContext context) async {
    try {
      await ErrorDialog.show(
        context,
        title: _getErrorTitle(error.type),
        message: error.userMessage ?? error.message,
        errorType: error.type,
        errorCode: error.errorCode,
        technicalDetails: kDebugMode ? error.stackTrace?.toString() : null,
        recoveryActions: _getRecoveryActions(error.type),
        onRecoveryAction: (action) =>
            _handleRecoveryAction(action, error, context),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GlobalErrorHandler] Dialog display failed: $e');
      }
    }
  }

  /// Zobrazení error snackbaru - POUŽITÍ GLOBÁLNÍHO KEY
  void _showErrorSnackBar(AppError error) {
    try {
      // Použití globálního scaffoldMessengerKey pokud je dostupný
      if (_scaffoldMessengerKey?.currentState != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scaffoldMessengerKey?.currentState?.showSnackBar(
            SnackBar(
              content: Text(error.userMessage ?? _getErrorTitle(error.type)),
              backgroundColor: _getErrorColor(error.type),
              duration: _getSnackBarDuration(error.type),
            ),
          );
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GlobalErrorHandler] SnackBar display failed: $e');
      }
    }
  }

  /// Získání titulu chyby
  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return tr('error.network_title');
      case ErrorType.auth:
        return tr('error.auth_title');
      case ErrorType.validation:
        return tr('error.validation_title');
      case ErrorType.permission:
        return tr('error.permission_title');
      case ErrorType.server:
        return tr('error.server_title');
      case ErrorType.storage:
        return tr('error.storage_title');
      case ErrorType.critical:
        return tr('error.critical_title');
      case ErrorType.warning:
        return tr('error.warning_title');
      case ErrorType.info:
        return tr('error.info_title');
      case ErrorType.timeout:
        return tr('error.timeout_title');
      case ErrorType.unknown:
      default:
        return tr('error.unknown_title');
    }
  }

  /// Získání možností obnovení podle typu chyby
  List<RecoveryAction> _getRecoveryActions(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return [RecoveryAction.retry, RecoveryAction.refresh];
      case ErrorType.auth:
        return [RecoveryAction.login, RecoveryAction.retry];
      case ErrorType.validation:
        return [RecoveryAction.goBack, RecoveryAction.retry];
      case ErrorType.permission:
        return [RecoveryAction.settings, RecoveryAction.retry];
      case ErrorType.server:
        return [RecoveryAction.retry, RecoveryAction.contact];
      case ErrorType.storage:
        return [RecoveryAction.retry, RecoveryAction.settings];
      case ErrorType.critical:
        return [RecoveryAction.restart, RecoveryAction.contact];
      case ErrorType.timeout:
        return [RecoveryAction.retry, RecoveryAction.refresh];
      case ErrorType.warning:
      case ErrorType.info:
        return [RecoveryAction.ignore];
      case ErrorType.unknown:
      default:
        return [RecoveryAction.retry, RecoveryAction.goBack];
    }
  }

  /// Zpracování recovery akce
  void _handleRecoveryAction(
      RecoveryAction action, AppError error, BuildContext context) {
    switch (action) {
      case RecoveryAction.retry:
        _errorStreamController.add(AppError(
          message: 'retry_requested',
          type: error.type,
          context: {'original_error': error},
        ));
        break;

      case RecoveryAction.login:
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth',
          (route) => false,
        );
        break;

      case RecoveryAction.settings:
        debugPrint('[GlobalErrorHandler] Opening app settings');
        break;

      case RecoveryAction.contact:
        _showContactSupport(error);
        break;

      case RecoveryAction.restart:
        _showRestartDialog();
        break;

      case RecoveryAction.goBack:
        Navigator.of(context).pop();
        break;

      case RecoveryAction.refresh:
        debugPrint('[GlobalErrorHandler] Refresh requested');
        break;

      case RecoveryAction.ignore:
        break;

      default:
        break;
    }
  }

  /// Zobrazení kontaktu na podporu - s bezpečným kontextem
  void _showContactSupport(AppError error) {
    final context = _safeContext;
    if (context == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('error.contact_support')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('error.contact_info')),
              const SizedBox(height: 16),
              const SelectableText('podpora@stastnyfoto.com'),
              const SelectableText('+420 604 733 111'),
              const SizedBox(height: 16),
              Text(tr('error.error_details')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Typ: ${error.type.name}',
                        style: const TextStyle(fontSize: 12)),
                    if (error.errorCode != null)
                      Text('Kód: ${error.errorCode}',
                          style: const TextStyle(fontSize: 12)),
                    Text('Čas: ${error.timestamp.toIso8601String()}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _copyErrorForSupport(error);
            },
            child: Text(tr('error.copy_details')),
          ),
        ],
      ),
    );
  }

  /// Zobrazení restart dialogu - s bezpečným kontextem
  void _showRestartDialog() {
    final context = _safeContext;
    if (context == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('error.restart_app')),
        content: Text(tr('error.restart_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
            child: Text(tr('error.restart')),
          ),
        ],
      ),
    );
  }

  /// Kopírování detailů chyby pro podporu
  void _copyErrorForSupport(AppError error) {
    final details = StringBuffer();
    details.writeln('=== Detaily chyby ===');
    details.writeln('Čas: ${error.timestamp.toIso8601String()}');
    details.writeln('Typ: ${error.type.name}');
    details.writeln('Zpráva: ${error.message}');
    if (error.errorCode != null) details.writeln('Kód: ${error.errorCode}');
    if (error.context != null) {
      details.writeln('Kontext: ${error.context}');
    }
    details.writeln('==================');

    Clipboard.setData(ClipboardData(text: details.toString()));

    // Použití globálního scaffoldMessengerKey
    if (_scaffoldMessengerKey?.currentState != null) {
      _scaffoldMessengerKey?.currentState?.showSnackBar(
        SnackBar(
          content: Text(tr('error.details_copied')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Získání barvy podle typu chyby
  Color _getErrorColor(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.auth:
        return Colors.red;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.permission:
        return Colors.purple;
      case ErrorType.server:
        return Colors.deepOrange;
      case ErrorType.storage:
        return Colors.indigo;
      case ErrorType.critical:
        return Colors.red[700]!;
      case ErrorType.warning:
        return Colors.orange[700]!;
      case ErrorType.info:
        return Colors.blue;
      case ErrorType.timeout:
        return Colors.grey[700]!;
      case ErrorType.unknown:
      default:
        return Colors.grey;
    }
  }

  /// Získání délky zobrazení SnackBaru
  Duration _getSnackBarDuration(ErrorType type) {
    switch (type) {
      case ErrorType.critical:
        return const Duration(seconds: 6);
      case ErrorType.auth:
      case ErrorType.permission:
        return const Duration(seconds: 5);
      case ErrorType.info:
        return const Duration(seconds: 2);
      default:
        return const Duration(seconds: 3);
    }
  }

  /// Převod na log level
  int _getLogLevel(ErrorType type) {
    switch (type) {
      case ErrorType.critical:
        return 1000; // SEVERE
      case ErrorType.auth:
      case ErrorType.permission:
        return 900; // WARNING
      case ErrorType.network:
      case ErrorType.server:
        return 800; // INFO
      case ErrorType.warning:
        return 700; // CONFIG
      case ErrorType.info:
      case ErrorType.timeout:
        return 500; // FINE
      default:
        return 700; // CONFIG
    }
  }

  /// Převod na crash reporting level
  LogLevel _getCrashReportingLevel(ErrorType type) {
    switch (type) {
      case ErrorType.critical:
        return LogLevel.fatal;
      case ErrorType.auth:
      case ErrorType.permission:
      case ErrorType.server:
        return LogLevel.error;
      case ErrorType.network:
      case ErrorType.storage:
        return LogLevel.warning;
      case ErrorType.timeout:
      case ErrorType.info:
      case ErrorType.warning:
        return LogLevel.info;
      default:
        return LogLevel.info;
    }
  }

  /// Získání historie chyb
  List<AppError> getErrorHistory() {
    return List.unmodifiable(_errorHistory);
  }

  /// Získání statistik chyb
  Map<ErrorType, int> getErrorStats() {
    return Map.unmodifiable(_errorCounts);
  }

  /// Vyčištění historie chyb
  void clearErrorHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
    _errorThrottling.clear();
  }

  /// Uvolnění zdrojů
  void dispose() {
    _errorStreamController.close();
    _errorHistory.clear();
    _errorCounts.clear();
    _errorThrottling.clear();
  }
}

/// Widget wrapper pro error boundary funkcionalitu
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error)? errorBuilder;
  final void Function(Object error, StackTrace stackTrace)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      return widget.errorBuilder?.call(_error!) ??
          CustomErrorWidget(
            message: tr('error.component_error'),
            errorType: ErrorWidgetType.unknown,
            onRetry: () {
              setState(() {
                _hasError = false;
                _error = null;
              });
            },
          );
    }

    return widget.child;
  }

  void _handleError(FlutterErrorDetails details) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _error = details.exception;
      });
      widget.onError
          ?.call(details.exception, details.stack ?? StackTrace.current);

      GlobalErrorHandler.instance.handleError(
        details.exception,
        stackTrace: details.stack,
        type: ErrorType.unknown,
        userMessage: tr('error.component_error'),
        showToUser: false,
      );
    }
  }
}
