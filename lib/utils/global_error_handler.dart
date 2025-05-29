// lib/utils/global_error_handler.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../widgets/custom_error_widget.dart';
import 'package:svatebni_planovac/widgets/error_dialog.dart';
import '../services/crash_reporting_service.dart';
import 'package:flutter/services.dart';

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
  warning,    // PŘIDEJ
  info,       // PŘIDEJ
  timeout,    // PŘIDEJ
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
      if (showToUser && _context != null) {
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
    
    // Ořezání historie
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
        FirebaseCrashlytics.instance.setCustomKey('error_code', error.errorCode!);
      }
      FirebaseCrashlytics.instance.setCustomKey('error_type', error.type.name);
      
    } catch (e) {
      debugPrint('[GlobalErrorHandler] Failed to report to Crashlytics: $e');
    }
  }

  /// Zobrazení chyby uživateli
  Future<void> _showErrorToUser(AppError error) async {
    if (_context == null || !_context!.mounted) return;
    
    final shouldShowDialog = _shouldShowErrorDialog(error.type);
    
    if (shouldShowDialog) {
      await _showErrorDialog(error);
    } else {
      _showErrorSnackBar(error);
    }
  }

  /// Rozhodnutí, zda zobrazit dialog nebo snackbar
  bool _shouldShowErrorDialog(ErrorType type) {
    return type == ErrorType.critical || 
           type == ErrorType.auth ||
           type == ErrorType.permission;
  }

  /// Zobrazení error dialogu
  Future<void> _showErrorDialog(AppError error) async {
    if (_context == null) return;
    
    await ErrorDialog.show(
      _context!,
      title: _getErrorTitle(error.type),
      message: error.userMessage ?? error.message,
      errorType: error.type,  // Protože už používáš stejný ErrorType
      errorCode: error.errorCode,
      technicalDetails: error.stackTrace?.toString(),
      recoveryActions: _getRecoveryActions(error.type),
      onRecoveryAction: (action) => _handleRecoveryAction(action, error),
    );
  }

  /// Zobrazení error snackbaru
  void _showErrorSnackBar(AppError error) {
    if (_context == null) return;
    
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(error.userMessage ?? error.message),
        backgroundColor: _getErrorColor(error.type),
        action: _getSnackBarAction(error),
        duration: _getSnackBarDuration(error.type),
      ),
    );
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
      case ErrorType.unknown:
      default:
        return 'Chyba aplikace';
    }
  }

//

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
      case ErrorType.unknown:
      default:
        return [RecoveryAction.retry, RecoveryAction.goBack];
    }
  }

  /// Zpracování recovery akce
  void _handleRecoveryAction(RecoveryAction action, AppError error) {
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
        if (_context != null) {
          Navigator.of(_context!).pushNamedAndRemoveUntil(
            '/auth', 
            (route) => false,
          );
        }
        break;
        
      case RecoveryAction.settings:
        // Open app settings - implementace závisí na platformě
        debugPrint('Opening app settings');
        break;
        
      case RecoveryAction.contact:
        _showContactSupport(error);
        break;
        
      case RecoveryAction.restart:
        _showRestartDialog();
        break;
        
      default:
        break;
    }
  }

  /// Zobrazení kontaktu na podporu
  void _showContactSupport(AppError error) {
    if (_context == null) return;
    
    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        title: const Text('Kontaktovat podporu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Můžete nás kontaktovat na:'),
            const SizedBox(height: 16),
            const Text('📧 podpora@svatebni-planovac.cz'),
            const Text('📞 +420 123 456 789'),
            const SizedBox(height: 16),
            const Text('Detaily chyby:'),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Typ: ${error.type}'),
                  if (error.errorCode != null) Text('Kód: ${error.errorCode}'),
                  Text('Čas: ${error.timestamp}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _copyErrorForSupport(error);
            },
            child: const Text('Kopírovat detaily'),
          ),
        ],
      ),
    );
  }

  /// Zobrazení restart dialogu
  void _showRestartDialog() {
    if (_context == null) return;
    
    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Restart aplikace'),
        content: const Text(
          'Pro vyřešení problému je nutné restartovat aplikaci. '
          'Neuložená data mohou být ztracena.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton(
            onPressed: () {
              // V produkční aplikaci by zde byl restart
              debugPrint('Restarting application...');
              Navigator.of(context).pop();
            },
            child: const Text('Restartovat'),
          ),
        ],
      ),
    );
  }

  /// Kopírování detailů chyby pro podporu
  void _copyErrorForSupport(AppError error) {
    final details = StringBuffer();
    details.writeln('=== Detaily chyby pro podporu ===');
    details.writeln('Čas: ${error.timestamp}');
    details.writeln('Typ: ${error.type}');
    details.writeln('Zpráva: ${error.message}');
    if (error.errorCode != null) details.writeln('Kód: ${error.errorCode}');
    if (error.context != null) details.writeln('Kontext: ${error.context}');
    details.writeln('================================');

    Clipboard.setData(ClipboardData(text: details.toString()));
    
    if (_context != null) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        const SnackBar(
          content: Text('Detaily chyby zkopírovány do schránky'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Získání SnackBar akce
  SnackBarAction? _getSnackBarAction(AppError error) {
    switch (error.type) {
      case ErrorType.network:
        return SnackBarAction(
          label: 'Opakovat',
          onPressed: () => _handleRecoveryAction(RecoveryAction.retry, error),
        );
      case ErrorType.auth:
        return SnackBarAction(
          label: 'Přihlásit',
          onPressed: () => _handleRecoveryAction(RecoveryAction.login, error),
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
      case ErrorType.unknown:
      default:
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

/// Widget wrapper pro error boundary funkcionalitet
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error)? errorBuilder;
  final void Function(Object error, StackTrace stackTrace)? onError;

  const ErrorBoundary({
    Key? key,
    required this.child,
    this.errorBuilder,
    this.onError,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!) ?? 
             CustomErrorWidget(
               message: 'Nastala chyba v této části aplikace',
               errorType: ErrorWidgetType.unknown,
               onRetry: () {
                 setState(() {
                   _error = null;
                 });
               },
             );
    }

    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    
    // Zachycení chyb v tomto widgetu
    FlutterError.onError = (details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
        });
        widget.onError?.call(details.exception, details.stack!);
      }
    };
  }
}