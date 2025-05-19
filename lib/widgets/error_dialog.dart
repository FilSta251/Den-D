import 'package:flutter/material.dart';

/// ErrorDialog představuje univerzální chybový dialog pro zobrazení chybových hlášení
/// v reálné, komerční aplikaci. Umožňuje přizpůsobení titulu, zprávy, ikony, stylů a akcí.
class ErrorDialog extends StatelessWidget {
  /// Titul dialogu.
  final String title;

  /// Hlavní zpráva nebo popis chyby.
  final String message;

  /// Volitelná ikona, která se zobrazí před titulem.
  final IconData? icon;

  /// Barva ikony. Pokud není zadána, použije se barva chyby z tématu.
  final Color? iconColor;

  /// Vlastní textový styl pro titulek.
  final TextStyle? titleTextStyle;

  /// Vlastní textový styl pro chybovou zprávu.
  final TextStyle? messageTextStyle;

  /// Akce, které se zobrazí v dolní části dialogu (tlačítka).
  final List<Widget>? actions;

  /// Konstruktor pro ErrorDialog.
  const ErrorDialog({
    Key? key,
    this.title = 'Chyba',
    required this.message,
    this.icon,
    this.iconColor,
    this.titleTextStyle,
    this.messageTextStyle,
    this.actions,
  }) : super(key: key);

  /// Statická metoda usnadňující zobrazení chybového dialogu.
  /// [barrierDismissible] určuje, zda se dialog může zavřít klepnutím mimo něj.
  static Future<void> show(
    BuildContext context, {
    String title = 'Chyba',
    required String message,
    IconData? icon,
    Color? iconColor,
    TextStyle? titleTextStyle,
    TextStyle? messageTextStyle,
    List<Widget>? actions,
    bool barrierDismissible = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        icon: icon,
        iconColor: iconColor,
        titleTextStyle: titleTextStyle,
        messageTextStyle: messageTextStyle,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(
              icon,
              color: iconColor ?? Theme.of(context).errorColor,
            ),
          if (icon != null)
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: titleTextStyle ??
                  Theme.of(context).textTheme.headline6?.copyWith(
                        color: Theme.of(context).errorColor,
                      ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: messageTextStyle ?? Theme.of(context).textTheme.bodyText2,
      ),
      actions: actions ??
          [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
    );
  }
}
