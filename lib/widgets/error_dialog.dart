import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/global_error_handler.dart';
export '../utils/global_error_handler.dart' show ErrorType;


/// Typ chyby určující vzhled a chování dialogu
//enum DialogErrorType {
 // network,      // Síťové chyby
 // validation,   // Validační chyby
 // auth,         // Autentizační chyby
 // server,       // Serverové chyby
 // critical,     // Kritické chyby
 // warning,      // Varování
 // info,         // Informační zprávy
 // permission,   // Chyby oprávnění
//timeout,      // Timeout chyby
 // unknown       // Neznámé chyby
//}

/// Možnosti zotavení z chyby
enum RecoveryAction {
  retry,        // Zkusit znovu
  goBack,       // Jít zpět
  refresh,      // Obnovit
  login,        // Přihlásit se
  settings,     // Jít do nastavení
  contact,      // Kontaktovat podporu
  ignore,       // Ignorovat
  restart       // Restartovat aplikaci
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
    Key? key,
    this.title = 'Chyba',
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
  }) : super(key: key);

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
        title: title ?? _getDefaultTitle(errorType),
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
  static String _getDefaultTitle(ErrorType errorType) {
    switch (errorType) {
      case ErrorType.network:
        return 'Chyba sítě';
      case ErrorType.validation:
        return 'Neplatné údaje';
      case ErrorType.auth:
        return 'Chyba autentizace';
      case ErrorType.server:
        return 'Chyba serveru';
      case ErrorType.critical:
        return 'Kritická chyba';
      case ErrorType.warning:
        return 'Upozornění';
      case ErrorType.info:
        return 'Informace';
      case ErrorType.permission:
        return 'Nedostatečná oprávnění';
      case ErrorType.timeout:
        return 'Vypršel časový limit';
      case ErrorType.unknown:
      default:
        return 'Chyba';
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
        text = 'Zkusit znovu';
        iconData = Icons.refresh;
        break;
      case RecoveryAction.goBack:
        text = 'Zpět';
        iconData = Icons.arrow_back;
        onPressed = () {
          Navigator.of(context).pop();
          onRecoveryAction?.call(action);
        };
        break;
      case RecoveryAction.refresh:
        text = 'Obnovit';
        iconData = Icons.refresh;
        break;
      case RecoveryAction.login:
        text = 'Přihlásit se';
        iconData = Icons.login;
        break;
      case RecoveryAction.settings:
        text = 'Nastavení';
        iconData = Icons.settings;
        break;
      case RecoveryAction.contact:
        text = 'Kontakt';
        iconData = Icons.support_agent;
        break;
      case RecoveryAction.ignore:
        text = 'Ignorovat';
        iconData = Icons.close;
        onPressed = () => Navigator.of(context).pop();
        break;
      case RecoveryAction.restart:
        text = 'Restartovat';
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
      label: Text(text),
    );
  }

  /// Kopíruje chybové detaily do schránky
  void _copyErrorDetails(BuildContext context) {
    final details = StringBuffer();
    details.writeln('Chyba: $title');
    details.writeln('Zpráva: $message');
    if (errorCode != null) details.writeln('Kód: $errorCode');
    if (technicalDetails != null) details.writeln('Detaily: $technicalDetails');
    details.writeln('Čas: ${DateTime.now()}');

    Clipboard.setData(ClipboardData(text: details.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Detaily chyby zkopírovány do schránky'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = _getErrorColor(context);

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
              title,
              style: titleTextStyle ??
                  theme.textTheme.titleLarge?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
      content: Column(
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
                  Text(
                    'Kód: $errorCode',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (technicalDetails != null && allowCopyDetails) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text(
                'Technické detaily',
                style: TextStyle(fontSize: 14),
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
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _copyErrorDetails(context),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Kopírovat detaily'),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: actions ??
          [
            ...recoveryActions.map((action) => _buildRecoveryButton(context, action)),
            if (!recoveryActions.contains(RecoveryAction.ignore))
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zavřít'),
              ),
          ],
    );
  }
}