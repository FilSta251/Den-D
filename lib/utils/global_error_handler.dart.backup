// lib/utils/global_error_handler.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../widgets/custom_error_widget.dart';
import 'package:den_d/widgets/error_dialog.dart';
import '../services/crash_reporting_service.dart';
import 'package:flutter/services.dart';
import '../services/navigation_service.dart';
import '../di/service_locator.dart' show locator;

/// Enum pro typy chyb v aplikaci - sjednoceno s error_dialog.dart
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

/// Pokročilý globální handler pro zpracování chyb v celé aplikaci
class GlobalErrorHandler {
  static final GlobalErrorHandler _instance = GlobalErrorHandler._internal();
  static GlobalErrorHandler get instance => _instance;

  GlobalErrorHandler._internal();

  // Context pro zobrazování dialogs a snackbars
  BuildContext? _context;

  // NavigationService pro přístup k kontextu
  NavigationService? get _navigationService {
    try {
      return locator<NavigationService>();
    } catch (_) {
      return null;
    }
  }

  // Callback pro custom handling chyb
  ErrorCallback? _errorCallback;

  // Service pro crash reporting
  CrashReportingService? _crashReportingService;

  // Sledování chyb
  final List<AppError> _errorHistory = [];
  static const int _maxErrorHistory = 50;

  // Throttling pro podobné chyby
  final Map<String, DateTime> _errorThrottling = {};
  static const Duration _throttleInterval = Duration(minutes: 1);

  // Počítadlo chyb
  final Map<ErrorType, int> _errorCounts = {};

  // Stream pro broadcasting chyb
  final StreamController<AppError> _errorStreamController =
      StreamController<AppError>.broadcast();

  Stream<AppError> get errorStream => _errorStreamController.stream;

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

    debugPrint('[GlobalErrorHandler] Initialized');
  }

  /// Nastavení kontextu pro zobrazování UI
  void setContext(BuildContext? context) {
    _context = context;
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

      // Crash reporting
      if (reportToCrashlytics) {
        await _reportToCrashlytics(appError);
      }

      // Custom callback
      _errorCallback?.call(appError);

      // UI handling
      if (showToUser) {
        await _showErrorToUser(appError);
      }
    } catch (e, stack) {
      // Fallback - pokud selže i error handler
      debugPrint('[GlobalErrorHandler] Error in error handler: $e');
      developer.log(
        'Critical error in GlobalErrorHandler',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Zpracování Flutter chyb
  void _handleFlutterError(FlutterErrorDetails details) {
    handleError(
      details.exception,
      stackTrace: details.stack,
      type: _categorizeFlutterError(details),
      context: {
        'library': details.library,
        'context': details.context?.toString(),
        'silent': details.silent,
      },
      showToUser: !details.silent,
    );
  }

  /// Zpracování platform chyb
  void _handlePlatformError(Object error, StackTrace stack) {
    handleError(
      error,
      stackTrace: stack,
      type: ErrorType.critical,
      userMessage: 'Nastala kritická chyba aplikace',
      showToUser: true,
    );
  }

  /// Kategorizace Flutter chyb
  ErrorType _categorizeFlutterError(FlutterErrorDetails details) {
    final error = details.exception.toString().toLowerCase();

    if (error.contains('network') || error.contains('socket')) {
      return ErrorType.network;
    } else if (error.contains('permission')) {
      return ErrorType.permission;
    } else if (error.contains('storage') || error.contains('file')) {
      return ErrorType.storage;
    } else if (error.contains('auth')) {
      return ErrorType.auth;
    } else {
      return ErrorType.unknown;
    }
  }

  /// Přidání chyby do historie
  void _addToErrorHistory(AppError error) {
    _errorHistory.add(error);

    //Ořezání historie
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
        return true; // Throttle tuto chybu
      }
    }

    _errorThrottling[key] = now;
    return false;
  }

  /// Logování chyby
  void _logError(AppError error) {
    // Console log
    debugPrint('[GlobalErrorHandler] ${error.type}: ${error.message}');

    // Developer log s detaily
    developer.log(
      error.message,
      name: 'GlobalErrorHandler',
      error: error.originalError,
      stackTrace: error.stackTrace,
      level: _getLogLevel(error.type),
    );

    // Crash reporting service
    _crashReportingService?.log(
      message: error.message,
      level: _getCrashReportingLevel(error.type),
      category: error.type.name,
      data: error.context,
    );
  }

  /// Reportování do Crashlytics
  Future<void> _reportToCrashlytics(AppError error) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error.originalError ?? error.message,
        error.stackTrace,
        reason: error.userMessage ?? 'Global error handler',
        fatal: error.type == ErrorType.critical,
        information: [
          'Error Type: ${error.type}',
          'Error Code: ${error.errorCode ?? 'N/A'}',
          'User Message: ${error.userMessage ?? 'N/A'}',
          'Timestamp: ${error.timestamp}',
          if (error.context != null) 'Context: ${error.context}',
        ],
      );

      // Custom keys pro Crashlytics
      if (error.errorCode != null) {
        FirebaseCrashlytics.instance
            .setCustomKey('error_code', error.errorCode!);
      }
      FirebaseCrashlytics.instance.setCustomKey('error_type', error.type.name);
    } catch (e) {
      debugPrint('[GlobalErrorHandler] Failed to report to Crashlytics: $e');
    }
  }

  /// Zobrazení chyby uživateli
  Future<void> _showErrorToUser(AppError error) async {
    try {
      // Získej kontext z NavigationService nebo použij uložený kontext
      final context =
          _context ?? _navigationService?.navigatorKey.currentContext;

      if (context == null || !context.mounted) {
        debugPrint('[GlobalErrorHandler] No valid context for showing error');
        return;
      }

      final shouldShowDialog = _shouldShowErrorDialog(error.type);

      // Použij post frame callback pro bezpečné zobrazení
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (shouldShowDialog) {
            _showErrorDialog(error, context);
          } else {
            _showErrorSnackBar(error, context);
          }
        }
      });
    } catch (e) {
      debugPrint('[GlobalErrorHandler] Error showing error to user: $e');
    }
  }

  /// Rozhodnutí, zda zobrazit dialog nebo snackbar
  bool _shouldShowErrorDialog(ErrorType type) {
    return type == ErrorType.critical ||
        type == ErrorType.auth ||
        type == ErrorType.permission;
  }

  /// Zobrazení error dialogu
  Future<void> _showErrorDialog(AppError error, BuildContext context) async {
    try {
      await ErrorDialog.show(
        context,
        title: _getErrorTitle(error.type),
        message: error.userMessage ?? error.message,
        errorType: error.type,
        errorCode: error.errorCode,
        technicalDetails: error.stackTrace?.toString(),
        recoveryActions: _getRecoveryActions(error.type),
        onRecoveryAction: (action) =>
            _handleRecoveryAction(action, error, context),
      );
    } catch (e) {
      debugPrint('[GlobalErrorHandler] Error showing dialog: $e');
    }
  }

  /// Zobrazení error snackbaru - OPRAVENO: overflow handling
  void _showErrorSnackBar(AppError error, BuildContext context) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.userMessage ?? error.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: _getErrorColor(error.type),
          action: _getSnackBarAction(error, context),
          duration: _getSnackBarDuration(error.type),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      debugPrint('[GlobalErrorHandler] Error showing snackbar: $e');
    }
  }

  /// Získání titulu chyby
  String _getErrorTitle(ErrorType type) {
    switch (type) {
      case ErrorType.network:
        return 'Problém s připojením';
      case ErrorType.auth:
        return 'Chyba autentizace';
      case ErrorType.validation:
        return 'Neplatná data';
      case ErrorType.permission:
        return 'Chybí oprávnění';
      case ErrorType.server:
        return 'Chyba serveru';
      case ErrorType.storage:
        return 'Problém s úložištěm';
      case ErrorType.critical:
        return 'Kritická chyba';
      case ErrorType.warning:
        return 'Upozornění';
      case ErrorType.info:
        return 'Informace';
      case ErrorType.timeout:
        return 'Časový limit vypršel';
      case ErrorType.unknown:
        return 'Chyba aplikace';
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
        return [RecoveryAction.retry, RecoveryAction.goBack];
    }
  }

  /// Zpracování recovery akce
  void _handleRecoveryAction(
      RecoveryAction action, AppError error, BuildContext context) {
    switch (action) {
      case RecoveryAction.retry:
        // Emit retry event - aplikace může naslouchat
        _errorStreamController.add(AppError(
          message: 'retry_requested',
          type: error.type,
          context: {'original_error': error},
        ));
        break;

      case RecoveryAction.login:
        // Navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth',
          (route) => false,
        );
        break;

      case RecoveryAction.settings:
        // Open app settings - implementace závisí na platformě
        debugPrint('Opening app settings');
        break;

      case RecoveryAction.contact:
        _showContactSupport(error, context);
        break;

      case RecoveryAction.restart:
        _showRestartDialog(context);
        break;

      case RecoveryAction.goBack:
        Navigator.of(context).pop();
        break;

      case RecoveryAction.refresh:
        // Implementace by závisela na konkrétní obrazovce
        debugPrint('Refresh requested');
        break;

      case RecoveryAction.ignore:
        // Jen zavři dialog
        break;
    }
  }

  /// Zobrazení kontaktu na podporu - OPRAVENO: overflow handling
  void _showContactSupport(AppError error, BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Kontaktovat podporu',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.5,
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Můžete nás kontaktovat na:'),
                const SizedBox(height: 16),
                const SelectableText('📧 app@stastnyfoto.com'),
                const SizedBox(height: 4),
                const SelectableText('📞 +420 604 733 111'),
                const SizedBox(height: 16),
                const Text('Detaily chyby:'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Typ: ${error.type}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (error.errorCode != null)
                        Text(
                          'Kód: ${error.errorCode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        'Čas: ${error.timestamp}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Zavřít'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _copyErrorForSupport(error, context);
            },
            child: const Text('Kopírovat detaily'),
          ),
        ],
      ),
    );
  }

  /// Zobrazení restart dialogu - OPRAVENO: overflow handling
  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Restart aplikace',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Pro vyřešení problému je nutné restartovat aplikaci. '
            'Neuložená data mohou být ztracena.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('Restarting application...');
              Navigator.of(dialogContext).pushNamedAndRemoveUntil(
                '/',
                (route) => false,
              );
            },
            child: const Text('Restartovat'),
          ),
        ],
      ),
    );
  }

  /// Kopírování detailů chyby pro podporu
  void _copyErrorForSupport(AppError error, BuildContext context) {
    final details = StringBuffer();
    details.writeln('=== Detaily chyby pro podporu ===');
    details.writeln('Čas: ${error.timestamp}');
    details.writeln('Typ: ${error.type}');
    details.writeln('Zpráva: ${error.message}');
    if (error.errorCode != null) details.writeln('Kód: ${error.errorCode}');
    if (error.context != null) details.writeln('Kontext: ${error.context}');
    details.writeln('================================');

    Clipboard.setData(ClipboardData(text: details.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Detaily chyby zkopírovány do schránky',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ),
    );
  }

  /// Získání SnackBar akce
  SnackBarAction? _getSnackBarAction(AppError error, BuildContext context) {
    switch (error.type) {
      case ErrorType.network:
        return SnackBarAction(
          label: 'Opakovat',
          onPressed: () =>
              _handleRecoveryAction(RecoveryAction.retry, error, context),
        );
      case ErrorType.auth:
        return SnackBarAction(
          label: 'Přihlásit',
          onPressed: () =>
              _handleRecoveryAction(RecoveryAction.login, error, context),
        );
      default:
        return null;
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
        return Colors.grey;
    }
  }

  /// Získání délky zobrazení SnackBaru
  Duration _getSnackBarDuration(ErrorType type) {
    switch (type) {
      case ErrorType.critical:
        return const Duration(seconds: 8);
      case ErrorType.auth:
      case ErrorType.permission:
        return const Duration(seconds: 6);
      case ErrorType.info:
        return const Duration(seconds: 3);
      default:
        return const Duration(seconds: 4);
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
      case ErrorType.timeout:
        return LogLevel.warning;
      case ErrorType.info:
      case ErrorType.warning:
      case ErrorType.validation:
      case ErrorType.unknown:
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

  /// Test crash pro Crashlytics
  Future<void> testCrash() async {
    if (kDebugMode) {
      await handleError(
        'Test crash from GlobalErrorHandler',
        type: ErrorType.critical,
        userMessage: 'Toto je testovací pád aplikace',
        showToUser: true,
      );
    }
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
  void initState() {
    super.initState();
    // Zachycení chyb v tomto widgetu
    FlutterError.onError = _handleError;
  }

  @override
  void dispose() {
    // Obnovení původního error handleru
    FlutterError.onError = GlobalErrorHandler.instance._handleFlutterError;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _error != null) {
      return widget.errorBuilder?.call(_error!) ??
          CustomErrorWidget(
            message: 'Nastala chyba v této části aplikace',
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

      // Reportuj chybu také do GlobalErrorHandler
      GlobalErrorHandler.instance.handleError(
        details.exception,
        stackTrace: details.stack,
        type: ErrorType.unknown,
        userMessage: 'Chyba v komponentě',
        showToUser: false, // Už zobrazujeme custom widget
      );
    }
  }
}
