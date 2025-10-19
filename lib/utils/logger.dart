/// lib/utils/logger.dart
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';

/// Enum pro různĂ© úrovně logování
enum LogLevel {
  trace(0, 'TRACE'),
  debug(1, 'DEBUG'),
  info(2, 'INFO'),
  warning(3, 'WARNING'),
  error(4, 'ERROR'),
  fatal(5, 'FATAL');

  const LogLevel(this.value, this.name);
  final int value;
  final String name;
}

/// Struktura pro log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? category;
  final Map<String, dynamic>? extra;
  final dynamic error;
  final StackTrace? stackTrace;
  final String? userId;
  final String? sessionId;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.extra,
    this.error,
    this.stackTrace,
    this.userId,
    this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'category': category,
      'extra': extra,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
      'userId': userId,
      'sessionId': sessionId,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${level.name}] ');
    buffer.write('${DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(timestamp)} ');
    if (category != null) {
      buffer.write('[$category] ');
    }
    buffer.write('- $message');

    if (extra != null && extra!.isNotEmpty) {
      buffer.write(' | Extra: ${jsonEncode(extra)}');
    }

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (stackTrace != null) {
      buffer.write('\nStackTrace: $stackTrace');
    }

    return buffer.toString();
  }
}

/// Interface pro analytics integraci
abstract class AnalyticsProvider {
  Future<void> trackEvent(String eventName, Map<String, dynamic> parameters);
  Future<void> trackError(String error, Map<String, dynamic> parameters);
  Future<void> setUserProperty(String name, String value);
}

/// Interface pro log output
abstract class LogOutput {
  Future<void> write(LogEntry entry);
  Future<void> flush();
}

/// Konzolový output
class ConsoleLogOutput implements LogOutput {
  @override
  Future<void> write(LogEntry entry) async {
    debugPrint(entry.toString());
  }

  @override
  Future<void> flush() async {
    // Console nepotřebuje flush
  }
}

/// Souborový output
class FileLogOutput implements LogOutput {
  final String filePath;
  final int maxFileSize;
  final int maxFiles;
  File? _currentFile;

  FileLogOutput({
    required this.filePath,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
    this.maxFiles = 5,
  });

  @override
  Future<void> write(LogEntry entry) async {
    try {
      await _ensureFile();
      await _currentFile!.writeAsString(
        '${jsonEncode(entry.toJson())}\n',
        mode: FileMode.append,
      );
      await _rotateIfNeeded();
    } catch (e) {
      debugPrint('Failed to write log to file: $e');
    }
  }

  Future<void> _ensureFile() async {
    if (_currentFile == null) {
      _currentFile = File(filePath);
      await _currentFile!.create(recursive: true);
    }
  }

  Future<void> _rotateIfNeeded() async {
    if (_currentFile == null) return;

    final stat = await _currentFile!.stat();
    if (stat.size > maxFileSize) {
      await _rotateFiles();
    }
  }

  Future<void> _rotateFiles() async {
    try {
      // Přesunout existující soubory
      for (int i = maxFiles - 1; i > 0; i--) {
        final oldFile = File('$filePath.$i');
        final newFile = File('$filePath.${i + 1}');
        if (await oldFile.exists()) {
          if (i == maxFiles - 1) {
            await oldFile.delete();
          } else {
            await oldFile.rename(newFile.path);
          }
        }
      }

      // Přesunout aktuální soubor
      if (await _currentFile!.exists()) {
        await _currentFile!.rename('$filePath.1');
      }

      // Vytvořit nový soubor
      _currentFile = File(filePath);
      await _currentFile!.create(recursive: true);
    } catch (e) {
      debugPrint('Failed to rotate log files: $e');
    }
  }

  @override
  Future<void> flush() async {
    // Soubory jsou automaticky flush při zápisu
  }
}

/// Analytics output
class AnalyticsLogOutput implements LogOutput {
  final AnalyticsProvider analyticsProvider;

  AnalyticsLogOutput(this.analyticsProvider);

  @override
  Future<void> write(LogEntry entry) async {
    try {
      if (entry.level.value >= LogLevel.warning.value) {
        // Trackovat chyby a varování
        await analyticsProvider.trackError(
          entry.message,
          {
            'level': entry.level.name,
            'category': entry.category ?? 'unknown',
            'timestamp': entry.timestamp.toIso8601String(),
            'userId': entry.userId,
            'sessionId': entry.sessionId,
            ...?entry.extra,
          },
        );
      } else if (entry.category != null) {
        // Trackovat obecnĂ© eventy
        await analyticsProvider.trackEvent(
          'log_${entry.category}',
          {
            'level': entry.level.name,
            'message': entry.message,
            'timestamp': entry.timestamp.toIso8601String(),
            'userId': entry.userId,
            'sessionId': entry.sessionId,
            ...?entry.extra,
          },
        );
      }
    } catch (e) {
      debugPrint('Failed to send log to analytics: $e');
    }
  }

  @override
  Future<void> flush() async {
    // Analytics nepotřebuje explicitní flush
  }
}

/// Pokročilý Logger s podporou strukturovanĂ©ho logování a analytics
class Logger {
  // Singleton instance
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal() {
    // Inicializace s výchozím console outputem
    _outputs.add(ConsoleLogOutput());
  }

  /// Minimální úroveĹ logování
  LogLevel minLevel = kDebugMode ? LogLevel.trace : LogLevel.info;

  /// Seznam výstupů pro logy
  final List<LogOutput> _outputs = [];

  /// Informace o uťivateli a session
  String? _userId;
  String? _sessionId;

  /// Buffer pro batch odesílání
  final List<LogEntry> _buffer = [];
  static const int _bufferLimit = 100;

  /// Inicializace loggeru
  void initialize({
    LogLevel? minLevel,
    List<LogOutput>? outputs,
    AnalyticsProvider? analyticsProvider,
  }) {
    if (minLevel != null) {
      this.minLevel = minLevel;
    }

    _outputs.clear();

    // Přidat výchozí konzolový output
    _outputs.add(ConsoleLogOutput());

    // Přidat custom outputs
    if (outputs != null) {
      _outputs.addAll(outputs);
    }

    // Přidat analytics output pokud je poskytnut
    if (analyticsProvider != null) {
      _outputs.add(AnalyticsLogOutput(analyticsProvider));
    }

    // Nelogovat info o inicializaci, aby nedoĹˇlo k rekurzi
    debugPrint('[Logger] Initialized with ${_outputs.length} outputs');
  }

  /// Nastavení uťivatelských informací
  void setUserInfo({String? userId, String? sessionId}) {
    _userId = userId;
    _sessionId = sessionId;
    // Pouťít přímý výstup místo rekurzivního volání
    debugPrint(
        '[Logger] User info updated - userId: $userId, sessionId: $sessionId');
  }

  /// Obecná metoda pro logování
  void log(
    LogLevel level,
    String message, {
    String? category,
    Map<String, dynamic>? extra,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    if (level.value < minLevel.value) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      category: category,
      extra: extra,
      error: error,
      stackTrace: stackTrace,
      userId: _userId,
      sessionId: _sessionId,
    );

    _writeToOutputs(entry);
  }

  /// Trace level logování
  void trace(
    String message, {
    String? category,
    Map<String, dynamic>? extra,
  }) {
    log(LogLevel.trace, message, category: category, extra: extra);
  }

  /// Debug level logování
  void debug(
    String message, {
    String? category,
    Map<String, dynamic>? extra,
  }) {
    log(LogLevel.debug, message, category: category, extra: extra);
  }

  /// Info level logování
  void info(
    String message, {
    String? category,
    Map<String, dynamic>? extra,
  }) {
    log(LogLevel.info, message, category: category, extra: extra);
  }

  /// Warning level logování
  void warning(
    String message, {
    String? category,
    Map<String, dynamic>? extra,
    dynamic exception,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.warning,
      message,
      category: category,
      extra: extra,
      error: exception,
      stackTrace: stackTrace,
    );
  }

  /// Error level logování
  void error(
    String message, {
    String? category,
    dynamic exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log(
      LogLevel.error,
      message,
      category: category,
      error: exception,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Fatal level logování
  void fatal(
    String message, {
    String? category,
    dynamic exception,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    log(
      LogLevel.fatal,
      message,
      category: category,
      error: exception,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Logování výjimky - upraveno pro konzistenci s user_repository.dart
  void exception(
    Exception exception, {
    String? message,
    String? category,
    StackTrace? stackTrace,
    Map<String, dynamic>? extra,
  }) {
    error(
      message ?? 'Exception caught: ${exception.toString()}',
      category: category,
      exception: exception,
      stackTrace: stackTrace,
      extra: extra,
    );
  }

  /// Performance tracking
  void performance(
    String operation,
    Duration duration, {
    String? category,
    Map<String, dynamic>? extra,
  }) {
    info(
      'Performance: $operation took ${duration.inMilliseconds}ms',
      category: category ?? 'performance',
      extra: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
        ...?extra,
      },
    );
  }

  /// API call tracking
  void apiCall(
    String method,
    String url,
    int statusCode,
    Duration duration, {
    Map<String, dynamic>? extra,
  }) {
    final level = statusCode >= 400 ? LogLevel.error : LogLevel.info;
    log(
      level,
      'API Call: $method $url -> $statusCode (${duration.inMilliseconds}ms)',
      category: 'api',
      extra: {
        'method': method,
        'url': url,
        'status_code': statusCode,
        'duration_ms': duration.inMilliseconds,
        ...?extra,
      },
    );
  }

  /// User action tracking
  void userAction(
    String action, {
    String? screen,
    Map<String, dynamic>? extra,
  }) {
    info(
      'User action: $action',
      category: 'user_action',
      extra: {
        'action': action,
        'screen': screen,
        ...?extra,
      },
    );
  }

  /// Zapsat do vĹˇech výstupů - OPRAVENO
  Future<void> _writeToOutputs(LogEntry entry) async {
    // Pokud nejsou ťádnĂ© výstupy, pouťij fallback
    if (_outputs.isEmpty) {
      debugPrint(entry.toString());
      return;
    }

    _buffer.add(entry);

    // Okamťitě zapsat do konzole pro debug
    if (kDebugMode && _outputs.isNotEmpty) {
      try {
        await _outputs.first.write(entry);
      } catch (e) {
        debugPrint('Failed to write to console output: $e');
        debugPrint(entry.toString()); // Fallback
      }
    }

    // Batch zpracování pro ostatní výstupy
    if (_buffer.length >= _bufferLimit) {
      await flush();
    }
  }

  /// Vyprázdnit buffer a zapsat vĹˇechny čekající logy
  Future<void> flush() async {
    if (_buffer.isEmpty) return;

    final entriesToWrite = List<LogEntry>.from(_buffer);
    _buffer.clear();

    for (final output in _outputs) {
      try {
        for (final entry in entriesToWrite) {
          await output.write(entry);
        }
        await output.flush();
      } catch (e) {
        debugPrint('Failed to write to output: $e');
      }
    }
  }

  /// Změna minimální úrovně logování
  void setMinLevel(LogLevel level) {
    minLevel = level;
    debugPrint('[Logger] Min level changed to: ${level.name}');
  }

  /// Backup pro původní API (zpětná kompatibilita)
  void logDebug(String message,
      {String? category, Map<String, dynamic>? extra}) {
    debug(message, category: category, extra: extra);
  }

  void logInfo(String message,
      {String? category, Map<String, dynamic>? extra}) {
    info(message, category: category, extra: extra);
  }

  void logWarning(String message,
      {String? category, Map<String, dynamic>? extra}) {
    warning(message, category: category, extra: extra);
  }

  void logError(
    String message, {
    dynamic exception,
    StackTrace? stackTrace,
    String? category,
    Map<String, dynamic>? extra,
  }) {
    error(message,
        exception: exception,
        stackTrace: stackTrace,
        category: category,
        extra: extra);
  }

  void logException(
    Exception exception, {
    StackTrace? stackTrace,
    String? category,
    Map<String, dynamic>? extra,
  }) {
    this.exception(exception,
        stackTrace: stackTrace, category: category, extra: extra);
  }

  void setEnabled(bool enabled) {
    setMinLevel(enabled ? LogLevel.trace : LogLevel.fatal);
  }

  /// Convenience metody pro strukturovanĂ© logování
  void logApiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
    Map<String, dynamic>? extra,
  }) {
    debug(
      'API Request: $method $url',
      category: 'api_request',
      extra: {
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
        ...?extra,
      },
    );
  }

  void logApiResponse({
    required String method,
    required String url,
    required int statusCode,
    required Duration duration,
    dynamic body,
    Map<String, dynamic>? extra,
  }) {
    apiCall(method, url, statusCode, duration, extra: {
      'response_body': body,
      ...?extra,
    });
  }

  void logDatabaseQuery({
    required String operation,
    required String collection,
    String? documentId,
    Map<String, dynamic>? query,
    Duration? duration,
    Map<String, dynamic>? extra,
  }) {
    info(
      'Database $operation on $collection',
      category: 'database',
      extra: {
        'operation': operation,
        'collection': collection,
        'documentId': documentId,
        'query': query,
        'duration_ms': duration?.inMilliseconds,
        ...?extra,
      },
    );
  }

  /// Získat historii logů (pro debugging)
  List<LogEntry> getRecentLogs({int limit = 100}) {
    return List<LogEntry>.from(_buffer.take(limit));
  }

  /// Vyčistit historii logů
  void clearHistory() {
    _buffer.clear();
  }

  /// Získat statistiky loggeru
  Map<String, dynamic> getStats() {
    final levelCounts = <String, int>{};
    for (final entry in _buffer) {
      levelCounts[entry.level.name] = (levelCounts[entry.level.name] ?? 0) + 1;
    }

    return {
      'bufferSize': _buffer.length,
      'outputs': _outputs.length,
      'minLevel': minLevel.name,
      'userId': _userId,
      'sessionId': _sessionId,
      'levelCounts': levelCounts,
    };
  }
}
