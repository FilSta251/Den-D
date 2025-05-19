import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Logger poskytuje metody pro logování zpráv různých úrovní.
/// Je implementován jako singleton, takže se používá jediná instance v celé aplikaci.
class Logger {
  // Singleton instance
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  /// Příznak, zda je logování povoleno. Výchozí hodnota je nastavena na true, pokud je aplikace spuštěna v debug módu.
  bool isEnabled = kDebugMode;

  /// Vrací aktuální časové razítko ve formátu "YYYY-MM-DD HH:mm:ss".
  String _timestamp() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  }

  /// Loguje debug zprávy.
  void logDebug(String message) {
    if (!isEnabled) return;
    debugPrint("[DEBUG] ${_timestamp()} - $message");
  }

  /// Loguje informační zprávy.
  void logInfo(String message) {
    if (!isEnabled) return;
    debugPrint("[INFO] ${_timestamp()} - $message");
  }

  /// Loguje varovné zprávy.
  void logWarning(String message) {
    if (!isEnabled) return;
    debugPrint("[WARNING] ${_timestamp()} - $message");
  }

  /// Loguje chybové zprávy. Volitelně lze předat i detail chyby a stack trace.
  void logError(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!isEnabled) return;
    debugPrint("[ERROR] ${_timestamp()} - $message");
    if (error != null) {
      debugPrint("Error: $error");
    }
    if (stackTrace != null) {
      debugPrint("StackTrace: $stackTrace");
    }
  }

  /// Loguje výjimku s volitelným stack trace.
  void logException(Exception exception, [StackTrace? stackTrace]) {
    logError("Exception caught: ${exception.toString()}", exception, stackTrace);
  }

  /// Umožňuje nastavit, zda je logování povoleno.
  void setEnabled(bool enabled) {
    isEnabled = enabled;
    debugPrint("Logger isEnabled set to: $isEnabled");
  }
}
