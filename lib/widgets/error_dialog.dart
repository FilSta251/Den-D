import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/global_error_handler.dart';
export '../utils/global_error_handler.dart' show ErrorType;

/// Možnosti zotavení z chyby
enum RecoveryAction {
  retry, // Zkusit znovu
  goBack, // Jít zpět
  refresh, // Obnovit
  login, // Přihlásit se
  settings, // Jít do nastavení
  contact, // Kontaktovat podporu
  ignore, // Ignorovat
  restart // Restartovat aplikaci
}

/// ErrorDialog představuje univerzální chybový dialog pro zobrazení chybových hlášení
/// v reálné, komerční aplikaci. Umožňuje přizpůsobení titulu, zprávy, ikony, stylů a akcí.
class ErrorDialog extends StatelessWidget {
  /// Titul dialogu.
  final String title;

  /// Hlavní zpráva nebo popis chyby.
  final String message;

  /// Typ chyby určující vzhled a výchozí akce
  final ErrorType errorType;

  /// Volitelná ikona, která se zobrazí před titulem.
  final IconData? icon;

  /// Barva ikony. Pokud není zadána, použije se barva podle typu chyby.
  final Color? iconColor;

  /// Vlastní textový styl pro titulek.
  final TextStyle? titleTextStyle;

  /// Vlastní textový styl pro chybovou zprávu.
  final TextStyle? messageTextStyle;

  /// Akce, které se zobrazí v dolní části dialogu (tlačítka).
  final List<Widget>? actions;

  /// Možnosti zotavení z chyby
  final List<RecoveryAction> recoveryActions;

  /// Callback funkce pro handling akcí zotavení
  final Function(RecoveryAction)? onRecoveryAction;

  /// Zobrazit technické detaily chyby
  final String? technicalDetails;

  /// Kód chyby pro podporu
  final String? errorCode;

  /// Zda umožnit kopírování chybových detailů
  final bool allowCopyDetails;

  /// Konstruktor pro ErrorDialog.
  const ErrorDialog({
    super.key,
    this.title = '',
    required this.message,
    this.errorType = ErrorType.unknown,
    this.icon,
    this.iconColor,
    this.titleTextStyle,
    this.messageTextStyle,
    this.actions,
    this.recoveryActions = const [RecoveryAction.retry],
    this.onRecoveryAction,
    this.technicalDetails,
    this.errorCode,
    this.allowCopyDetails = true,
  });

  /// Statická metoda usnadňující zobrazení chybového dialogu.
  /// [barrierDismissible] určuje, zda se dialog může zavřít klepnutím mimo něj.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required String message,
    ErrorType errorType = ErrorType.unknown,
    IconData? icon,
    Color? iconColor,
    TextStyle? titleTextStyle,
    TextStyle? messageTextStyle,
    List<Widget>? actions,
    List<RecoveryAction> recoveryActions = const [RecoveryAction.retry],
    Function(RecoveryAction)? onRecoveryAction,
    String? technicalDetails,
    String? errorCode,
    bool barrierDismissible = true,
    bool allowCopyDetails = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ErrorDialog(
        title: title ?? _getDefaultTitle(context, errorType),
        message: message,
        errorType: errorType,
        icon: icon,
        iconColor: iconColor,
        titleTextStyle: titleTextStyle,
        messageTextStyle: messageTextStyle,
        actions: actions,
        recoveryActions: recoveryActions,
        onRecoveryAction: onRecoveryAction,
        technicalDetails: technicalDetails,
        errorCode: errorCode,
        allowCopyDetails: allowCopyDetails,
      ),
    );
  }

  /// Vrací výchozí titul podle typu chyby
  static String _getDefaultTitle(BuildContext context, ErrorType errorType) {
    switch (errorType) {
      case ErrorType.network:
        return tr('error_network_title');
      case ErrorType.validation:
        return tr('error_validation_title');
      case ErrorType.auth:
        return tr('error_auth_title');
      case ErrorType.server:
        return tr('error_server_title');
      case ErrorType.critical:
        return tr('error_critical_title');
      case ErrorType.warning:
        return tr('error_warning_title');
      case ErrorType.info:
        return tr('error_info_title');
      case ErrorType.permission:
        return tr('error_permission_title');
      case ErrorType.timeout:
        return tr('error_timeout_title');
      case ErrorType.unknown:
      default:
        return tr('error_title');
    }
  }

  /// Vrací výchozí ikonu podle typu chyby
  IconData _getDefaultIcon() {
    if (icon != null) return icon!;

    switch (errorType) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.validation:
        return Icons.error_outline;
      case ErrorType.auth:
        return Icons.lock;
      case ErrorType.server:
        return Icons.cloud_off;
      case ErrorType.critical:
        return Icons.dangerous;
      case ErrorType.warning:
        return Icons.warning;
      case ErrorType.info:
        return Icons.info;
      case ErrorType.permission:
        return Icons.security;
      case ErrorType.timeout:
        return Icons.timer_off;
      case ErrorType.unknown:
      default:
        return Icons.error;
    }
  }

  /// Vrací barvu podle typu chyby
  Color _getErrorColor(BuildContext context) {
    if (iconColor != null) return iconColor!;

    switch (errorType) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.validation:
        return Colors.amber;
      case ErrorType.auth:
        return Colors.red;
      case ErrorType.server:
        return Colors.deepOrange;
      case ErrorType.critical:
        return Colors.red.shade700;
      case ErrorType.warning:
        return Colors.orange;
      case ErrorType.info:
        return Colors.blue;
      case ErrorType.permission:
        return Colors.purple;
      case ErrorType.timeout:
        return Colors.brown;
      case ErrorType.unknown:
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  /// Vytvoří tlačítko pro akci zotavení
  Widget _buildRecoveryButton(BuildContext context, RecoveryAction action) {
    String text;
    IconData iconData;
    VoidCallback? onPressed;

    switch (action) {
      case RecoveryAction.retry:
        text = tr('action_retry');
        iconData = Icons.refresh;
        break;
      case RecoveryAction.goBack:
        text = tr('action_go_back');
        iconData = Icons.arrow_back;
        onPressed = () {
          Navigator.of(context).pop();
          onRecoveryAction?.call(action);
        };
        break;
      case RecoveryAction.refresh:
        text = tr('action_refresh');
        iconData = Icons.refresh;
        break;
      case RecoveryAction.login:
        text = tr('action_login');
        iconData = Icons.login;
        break;
      case RecoveryAction.settings:
        text = tr('action_settings');
        iconData = Icons.settings;
        break;
      case RecoveryAction.contact:
        text = tr('action_contact');
        iconData = Icons.support_agent;
        break;
      case RecoveryAction.ignore:
        text = tr('action_ignore');
        iconData = Icons.close;
        onPressed = () => Navigator.of(context).pop();
        break;
      case RecoveryAction.restart:
        text = tr('action_restart');
        iconData = Icons.restart_alt;
        break;
    }

    onPressed ??= () {
      Navigator.of(context).pop();
      onRecoveryAction?.call(action);
    };

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(iconData, size: 16),
      label: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Kopíruje chybové detaily do schránky
  void _copyErrorDetails(BuildContext context) {
    final details = StringBuffer();
    details.writeln(
        '${tr('error')}: ${title.isEmpty ? _getDefaultTitle(context, errorType) : title}');
    details.writeln('${tr('message')}: $message');
    if (errorCode != null) details.writeln('${tr('error_code')}: $errorCode');
    if (technicalDetails != null) {
      details.writeln('${tr('details')}: $technicalDetails');
    }
    details.writeln('${tr('time')}: ${DateTime.now()}');

    Clipboard.setData(ClipboardData(text: details.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('error_details_copied'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = _getErrorColor(context);
    final effectiveTitle =
        title.isEmpty ? _getDefaultTitle(context, errorType) : title;

    return AlertDialog(
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _getDefaultIcon(),
            color: errorColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              effectiveTitle,
              style: titleTextStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: messageTextStyle ?? theme.textTheme.bodyMedium,
              ),
              if (errorCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.code, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${tr('error_code')}: $errorCode',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (technicalDetails != null && allowCopyDetails) ...[
                const SizedBox(height: 8),
                ExpansionTile(
                  title: Text(
                    tr('technical_details'),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        technicalDetails!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _copyErrorDetails(context),
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text(
                        tr('copy_details'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: actions ??
          [
            ...recoveryActions
                .map((action) => _buildRecoveryButton(context, action)),
            if (!recoveryActions.contains(RecoveryAction.ignore))
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(tr('close')),
              ),
          ],
    );
  }
}
