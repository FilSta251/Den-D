/// lib/widgets/custom_error_widget.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

/// Enum pro typy chyb
enum ErrorWidgetType {
  unknown,
  network,
  permission,
  auth,
  server,
  validation,
  notFound,
  maintenance,
  timeout,
  storage,
}

/// Pokročilý error widget pro zobrazení různých typů chyb
class CustomErrorWidget extends StatelessWidget {
  final String message;
  final ErrorWidgetType errorType;
  final VoidCallback? onRetry;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionText;
  final IconData? secondaryActionIcon;
  final String? detailMessage;
  final String? errorCode;
  final bool showReportButton;
  final VoidCallback? onReportError;
  final String? redirectRoute;
  final Widget? customAction;
  final bool showAnimation;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.errorType = ErrorWidgetType.unknown,
    this.onRetry,
    this.onSecondaryAction,
    this.secondaryActionText,
    this.secondaryActionIcon,
    this.detailMessage,
    this.errorCode,
    this.showReportButton = false,
    this.onReportError,
    this.redirectRoute,
    this.customAction,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = _getErrorColor(theme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Animovaná ikona
                if (showAnimation)
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: _buildErrorIcon(errorColor),
                  )
                else
                  _buildErrorIcon(errorColor),

                const SizedBox(height: 32),

                // Hlavní zpráva
                AnimatedOpacity(
                  opacity: showAnimation ? 1.0 : 1.0,
                  duration: const Duration(milliseconds: 1000),
                  child: Text(
                    message,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 16),

                // Detailní zpráva
                if (detailMessage != null) ...[
                  Text(
                    detailMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                ],

                // Kód chyby
                if (errorCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: errorColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.code,
                          size: 16,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${tr('error_code')}: $errorCode',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _copyToClipboard(context, errorCode!),
                          child: Icon(
                            Icons.copy,
                            size: 16,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Akční tlačítka
                Column(
                  children: [
                    // Hlavní akce (Retry)
                    if (onRetry != null)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            tr('try_again'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Sekundární akce
                    if (onSecondaryAction != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onSecondaryAction,
                          icon: Icon(secondaryActionIcon ?? Icons.arrow_back),
                          label: Text(
                            secondaryActionText ?? tr('back'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: errorColor,
                            side: BorderSide(color: errorColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Vlastní akce
                    if (customAction != null) customAction!,

                    // Report tlačítko
                    if (showReportButton)
                      TextButton.icon(
                        onPressed:
                            onReportError ?? () => _showReportDialog(context),
                        icon: const Icon(Icons.bug_report, size: 16),
                        label: Text(
                          tr('report_problem'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // Tip pro uživatele
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getHelpText(),
                          style: theme.textTheme.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Vytvoří ikonu podle typu chyby
  Widget _buildErrorIcon(Color color) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getIconForErrorType(),
        size: 40,
        color: color,
      ),
    );
  }

  /// Vrací ikonu podle typu chyby
  IconData _getIconForErrorType() {
    switch (errorType) {
      case ErrorWidgetType.network:
        return Icons.wifi_off;
      case ErrorWidgetType.permission:
        return Icons.lock;
      case ErrorWidgetType.auth:
        return Icons.person_off;
      case ErrorWidgetType.server:
        return Icons.cloud_off;
      case ErrorWidgetType.validation:
        return Icons.error_outline;
      case ErrorWidgetType.notFound:
        return Icons.search_off;
      case ErrorWidgetType.maintenance:
        return Icons.build;
      case ErrorWidgetType.timeout:
        return Icons.timer_off;
      case ErrorWidgetType.storage:
        return Icons.storage;
      case ErrorWidgetType.unknown:
        return Icons.error;
    }
  }

  /// Vrací barvu podle typu chyby
  Color _getErrorColor(ThemeData theme) {
    switch (errorType) {
      case ErrorWidgetType.network:
        return Colors.orange;
      case ErrorWidgetType.permission:
        return Colors.purple;
      case ErrorWidgetType.auth:
        return Colors.red;
      case ErrorWidgetType.server:
        return Colors.deepOrange;
      case ErrorWidgetType.validation:
        return Colors.amber;
      case ErrorWidgetType.notFound:
        return Colors.grey;
      case ErrorWidgetType.maintenance:
        return Colors.blue;
      case ErrorWidgetType.timeout:
        return Colors.brown;
      case ErrorWidgetType.storage:
        return Colors.indigo;
      case ErrorWidgetType.unknown:
        return theme.colorScheme.error;
    }
  }

  /// Vrací pomocný text podle typu chyby
  String _getHelpText() {
    switch (errorType) {
      case ErrorWidgetType.network:
        return tr('error_help_network');
      case ErrorWidgetType.permission:
        return tr('error_help_permission');
      case ErrorWidgetType.auth:
        return tr('error_help_auth');
      case ErrorWidgetType.server:
        return tr('error_help_server');
      case ErrorWidgetType.validation:
        return tr('error_help_validation');
      case ErrorWidgetType.notFound:
        return tr('error_help_not_found');
      case ErrorWidgetType.maintenance:
        return tr('error_help_maintenance');
      case ErrorWidgetType.timeout:
        return tr('error_help_timeout');
      case ErrorWidgetType.storage:
        return tr('error_help_storage');
      case ErrorWidgetType.unknown:
        return tr('error_help_unknown');
    }
  }

  /// Kopíruje text do schránky
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('code_copied_to_clipboard', args: [text]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Zobrazí dialog pro nahlášení chyby - OPRAVENO: overflow handling
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          tr('report_problem'),
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
                Text(
                  tr('report_problem_description'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                if (errorCode != null) ...[
                  Text(
                    '${tr('error_code')}: $errorCode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '${tr('type')}: ${errorType.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${tr('message')}: $message',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detailMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${tr('detail')}: $detailMessage',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('cancel')),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _copyErrorDetailsToClipboard(context);
            },
            icon: const Icon(Icons.copy),
            label: Text(
              tr('copy_details'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Kopíruje detaily chyby do schránky
  void _copyErrorDetailsToClipboard(BuildContext context) {
    final details = StringBuffer();
    details.writeln('=== ${tr('error_details')} ===');
    details.writeln('${tr('type')}: ${errorType.name}');
    details.writeln('${tr('message')}: $message');
    if (detailMessage != null) {
      details.writeln('${tr('detail')}: $detailMessage');
    }
    if (errorCode != null) details.writeln('${tr('error_code')}: $errorCode');
    details.writeln('${tr('time')}: ${DateTime.now()}');
    details.writeln('==================');

    Clipboard.setData(ClipboardData(text: details.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('error_details_copied'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Factory pro rychlé vytvoření běžných error widgetů
class ErrorWidgetFactory {
  static Widget networkError({VoidCallback? onRetry}) {
    return CustomErrorWidget(
      message: tr('error_network'),
      errorType: ErrorWidgetType.network,
      onRetry: onRetry,
      detailMessage: tr('error_network_detail'),
      showReportButton: true,
    );
  }

  static Widget serverError({VoidCallback? onRetry, String? errorCode}) {
    return CustomErrorWidget(
      message: tr('error_server'),
      errorType: ErrorWidgetType.server,
      onRetry: onRetry,
      errorCode: errorCode,
      detailMessage: tr('error_server_detail'),
      showReportButton: true,
    );
  }

  static Widget authError({VoidCallback? onLogin}) {
    return CustomErrorWidget(
      message: tr('error_auth'),
      errorType: ErrorWidgetType.auth,
      onRetry: onLogin,
      detailMessage: tr('error_auth_detail'),
      secondaryActionText: tr('login'),
      secondaryActionIcon: Icons.login,
    );
  }

  static Widget notFoundError({VoidCallback? onGoHome}) {
    return CustomErrorWidget(
      message: tr('error_not_found'),
      errorType: ErrorWidgetType.notFound,
      onSecondaryAction: onGoHome,
      detailMessage: tr('error_not_found_detail'),
      secondaryActionText: tr('home'),
      secondaryActionIcon: Icons.home,
    );
  }
}
