// lib/widgets/custom_error_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    Key? key,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = _getErrorColor(theme);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Detailní zpráva
              if (detailMessage != null) ...[
                Text(
                  detailMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
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
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: errorColor.withOpacity(0.3),
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
                      Text(
                        'Kód: $errorCode',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
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
                        label: const Text('Zkusit znovu'),
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
                        label: Text(secondaryActionText ?? 'Zpět'),
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
                      onPressed: onReportError ?? () => _showReportDialog(context),
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('Nahlásit problém'),
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
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
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
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        color: color.withOpacity(0.1),
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
      default:
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
      default:
        return theme.colorScheme.error;
    }
  }

  /// Vrací pomocný text podle typu chyby
  String _getHelpText() {
    switch (errorType) {
      case ErrorWidgetType.network:
        return 'Zkontrolujte připojení k internetu a zkuste to znovu.';
      case ErrorWidgetType.permission:
        return 'Aplikace potřebuje dodatečná oprávnění pro správné fungování.';
      case ErrorWidgetType.auth:
        return 'Zkuste se odhlásit a znovu přihlásit.';
      case ErrorWidgetType.server:
        return 'Server momentálně neodpovídá. Zkuste to později.';
      case ErrorWidgetType.validation:
        return 'Zkontrolujte zadané údaje a opravte chyby.';
      case ErrorWidgetType.notFound:
        return 'Požadovaný obsah nebyl nalezen.';
      case ErrorWidgetType.maintenance:
        return 'Aplikace se aktualizuje. Zkuste to za chvíli.';
      case ErrorWidgetType.timeout:
        return 'Operace trvala příliš dlouho. Zkuste to znovu.';
      case ErrorWidgetType.storage:
        return 'Problém s úložištěm dat. Zkontrolujte volné místo.';
      case ErrorWidgetType.unknown:
      default:
        return 'Pokud problém přetrvává, kontaktujte podporu.';
    }
  }

  /// Kopíruje text do schránky
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kód "$text" zkopírován do schránky'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Zobrazí dialog pro nahlášení chyby
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nahlásit problém'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pomožte nám vylepšit aplikaci nahlášením tohoto problému.'),
            const SizedBox(height: 16),
            if (errorCode != null) ...[
              Text('Kód chyby: $errorCode'),
              const SizedBox(height: 8),
            ],
            Text('Typ: ${errorType.name}'),
            const SizedBox(height: 8),
            Text('Zpráva: $message'),
            if (detailMessage != null) ...[
              const SizedBox(height: 8),
              Text('Detail: $detailMessage'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zrušit'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _copyErrorDetailsToClipboard(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopírovat detaily'),
          ),
        ],
      ),
    );
  }

  /// Kopíruje detaily chyby do schránky
  void _copyErrorDetailsToClipboard(BuildContext context) {
    final details = StringBuffer();
    details.writeln('=== Detaily chyby ===');
    details.writeln('Typ: ${errorType.name}');
    details.writeln('Zpráva: $message');
    if (detailMessage != null) details.writeln('Detail: $detailMessage');
    if (errorCode != null) details.writeln('Kód: $errorCode');
    details.writeln('Čas: ${DateTime.now()}');
    details.writeln('==================');

    Clipboard.setData(ClipboardData(text: details.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Detaily chyby zkopírovány do schránky'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

/// Factory pro rychlé vytvoření běžných error widgetů
class ErrorWidgetFactory {
  static Widget networkError({VoidCallback? onRetry}) {
    return CustomErrorWidget(
      message: 'Problém s připojením',
      errorType: ErrorWidgetType.network,
      onRetry: onRetry,
      detailMessage: 'Nepodařilo se připojit k internetu',
      showReportButton: true,
    );
  }

  static Widget serverError({VoidCallback? onRetry, String? errorCode}) {
    return CustomErrorWidget(
      message: 'Chyba serveru',
      errorType: ErrorWidgetType.server,
      onRetry: onRetry,
      errorCode: errorCode,
      detailMessage: 'Server momentálně neodpovídá',
      showReportButton: true,
    );
  }

  static Widget authError({VoidCallback? onLogin}) {
    return CustomErrorWidget(
      message: 'Problémy s přihlášením',
      errorType: ErrorWidgetType.auth,
      onRetry: onLogin,
      detailMessage: 'Přihlášení vypršelo nebo je neplatné',
      secondaryActionText: 'Přihlásit se',
      secondaryActionIcon: Icons.login,
    );
  }

  static Widget notFoundError({VoidCallback? onGoHome}) {
    return CustomErrorWidget(
      message: 'Stránka nenalezena',
      errorType: ErrorWidgetType.notFound,
      onSecondaryAction: onGoHome,
      detailMessage: 'Požadovaná stránka neexistuje',
      secondaryActionText: 'Domů',
      secondaryActionIcon: Icons.home,
    );
  }
}