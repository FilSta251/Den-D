// lib/utils/safe_snackbar.dart
// Bezpečný SnackBar s ochranou proti overflow
//
// POUŽITÍ:
// Místo: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('zpráva')));
// Použij: SafeSnackBar.show(context, 'zpráva');

import 'package:flutter/material.dart';

class SafeSnackBar {
  /// Zobrazí bezpečný SnackBar s ochranou proti overflow
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Zobrazí error SnackBar (červený)
  static void error(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.red.shade700);
  }

  /// Zobrazí success SnackBar (zelený)
  static void success(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.green.shade700);
  }

  /// Zobrazí warning SnackBar (oranžový)
  static void warning(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.orange.shade700);
  }

  /// Zobrazí info SnackBar (modrý)
  static void info(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.blue.shade700);
  }
}
