/// lib/theme/app_theme.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Třída pro centrální správu tĂ©matu aplikace.
///
/// poskytuje předdefinovaná tĂ©mata pro světlý a tmavý reťim s konzistentními
/// styly pro vĹˇechny komponenty v aplikaci.
class AppTheme {
  /// SvětlĂ© tĂ©ma aplikace.
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
        brightness: Brightness.light,
        primary: Colors.pink.shade800,
        secondary: Colors.amber,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 2,
        scrolledUnderElevation: 4,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      // NOVĂ‰: Globální nastavení pro kapitalizaci textu
      textTheme: const TextTheme().apply(
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      // Nastavení pro TextField a TextFormField
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Colors.pink.shade800,
        selectionColor: Colors.pink.shade200,
        selectionHandleColor: Colors.pink.shade800,
      ),
    );
  }

  /// TmavĂ© tĂ©ma aplikace.
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
        brightness: Brightness.dark,
        primary: Colors.pink.shade300,
        secondary: Colors.amber.shade200,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
        scrolledUnderElevation: 4,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink.shade300,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade800,
      ),
      // NOVĂ‰: Globální nastavení pro kapitalizaci textu
      textTheme: const TextTheme().apply(
        bodyColor: Colors.white70,
        displayColor: Colors.white70,
      ),
      // Nastavení pro TextField a TextFormField
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: Colors.pink.shade300,
        selectionColor: Colors.pink.shade700,
        selectionHandleColor: Colors.pink.shade300,
      ),
    );
  }

  /// Pomocná metoda pro získání InputDecoration s kapitalizací
  static InputDecoration getTextFieldDecoration({
    String? labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      enabled: enabled,
      // Automatická kapitalizace prvního písmena
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
    );
  }

  /// Pomocná metoda pro TextInputFormatter s kapitalizací
  static List<TextInputFormatter> getTextFormatters({
    int? maxLength,
    bool enableCapitalization = true,
    TextInputType? keyboardType,
  }) {
    final formatters = <TextInputFormatter>[];

    if (maxLength != null) {
      formatters.add(LengthLimitingTextInputFormatter(maxLength));
    }

    if (enableCapitalization) {
      formatters.add(CapitalizeWordsFormatter());
    }

    // Pro specifickĂ© typy klávesnic
    if (keyboardType == TextInputType.emailAddress) {
      formatters.add(LowerCaseTextFormatter());
    }

    return formatters;
  }
}

/// Custom TextInputFormatter pro kapitalizaci prvního písmena kaťdĂ©ho slova
class CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String newText = newValue.text;

    // Kapitalizace prvního písmena
    if (newText.isNotEmpty) {
      newText = newText[0].toUpperCase() + newText.substring(1);
    }

    // Kapitalizace po mezeře, tečce, vykřičníku, otazníku
    final RegExp regex = RegExp(r'(\s|\.|\!|\?)([a-záčďŹĂ©ěíĹĂłřĹˇšúůýť])');
    newText = newText.replaceAllMapped(regex, (match) {
      return '${match.group(1)}${match.group(2)?.toUpperCase() ?? ''}';
    });

    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }
}

/// Custom TextInputFormatter pro malá písmena (např. emaily)
class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: newValue.selection,
    );
  }
}

/// Pomocná třída pro rychlĂ© vytvoření TextFormField s kapitalizací
class AppTextField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final bool enabled;
  final int? maxLength;
  final int? maxLines;
  final bool enableCapitalization;

  const AppTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.controller,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.enableCapitalization = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: enableCapitalization
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      inputFormatters: AppTheme.getTextFormatters(
        maxLength: maxLength,
        enableCapitalization: enableCapitalization,
        keyboardType: keyboardType,
      ),
      decoration: AppTheme.getTextFieldDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        enabled: enabled,
      ),
    );
  }
}
