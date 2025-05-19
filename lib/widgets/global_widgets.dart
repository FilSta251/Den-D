// lib/widgets/global_widgets.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Třída s globálními widgety pro sjednocený vzhled aplikace.
/// 
/// Poskytuje předdefinované komponenty, které lze použít v celé aplikaci:
/// - Tlačítka
/// - Loadery
/// - Chybové stavy
/// - Prázdné stavy
/// - Dialogy
class GlobalWidgets {
  // Privátní konstruktor znemožní vytvoření instance
  GlobalWidgets._();
  
  /// Primární tlačítko aplikace s konzistentním vzhledem.
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isFullWidth = false,
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: isFullWidth ? const Size.fromHeight(50) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon),
                if (icon != null) const SizedBox(width: 8),
                Text(text, style: const TextStyle(fontSize: 16)),
              ],
            ),
    );
  }
  
  /// Sekundární (méně výrazné) tlačítko aplikace.
  static Widget secondaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isFullWidth = false,
    IconData? icon,
  }) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: isFullWidth ? const Size.fromHeight(50) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon),
                if (icon != null) const SizedBox(width: 8),
                Text(text, style: const TextStyle(fontSize: 16)),
              ],
            ),
    );
  }
  
  /// Widget pro stav načítání.
  static Widget loadingIndicator({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }
  
  /// Widget pro zobrazení chybového stavu.
  static Widget errorIndicator({
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(tr('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Widget pro zobrazení prázdného stavu.
  static Widget emptyState({
    required String message,
    IconData icon = Icons.inbox,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.grey,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Zobrazí dialogové okno pro potvrzení akce.
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'confirm',
    String cancelText = 'cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr(cancelText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(tr(confirmText)),
          ),
        ],
      ),
    );
  }
}
