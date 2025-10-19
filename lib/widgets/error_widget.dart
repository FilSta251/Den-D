import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A reusable, highly customizable error display widget.
class CustomErrorWidget extends StatelessWidget {
  /// The main error message.
  final String message;

  /// Primary retry callback.
  final VoidCallback onRetry;

  /// Optional secondary action label and callback (e.g. 'Cancel').
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional icon to display above the message.
  final IconData? icon;

  /// Text style for the [message].
  final TextStyle? textStyle;

  /// Style for the primary retry button.
  final ButtonStyle? retryButtonStyle;

  /// Style for the secondary button.
  final ButtonStyle? secondaryButtonStyle;

  /// Creates a customizable error widget.
  const CustomErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
    this.icon,
    this.textStyle,
    this.retryButtonStyle,
    this.secondaryButtonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: textStyle ??
                  theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: onRetry,
                  style: retryButtonStyle,
                  child: Text(tr('error.retry')),
                ),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    style: secondaryButtonStyle,
                    child: Text(tr(secondaryLabel!)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
