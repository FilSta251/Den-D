/// lib/utils/validators.dart
library;

import 'package:intl/intl.dart';

/// Validators poskytuje statickĂ© metody pro ověřování vstupů.
/// Kaťdá metoda vrací null, pokud je vstup platný, nebo chybovou zprávu při neplatnosti.
class Validators {
  /// Ověří, ťe hodnota není prázdná.
  static String? validateRequired(String? value,
      {String errorMessage = 'Toto pole je povinnĂ©.'}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří, ťe hodnota má alespoĹ [minLength] znaků.
  static String? validateMinLength(String? value, int minLength,
      {String? errorMessage}) {
    if (value == null || value.trim().length < minLength) {
      return errorMessage ?? 'Hodnota musí mít alespoĹ $minLength znaků.';
    }
    return null;
  }

  /// Ověří, ťe hodnota nepřesahuje [maxLength] znaků.
  static String? validateMaxLength(String? value, int maxLength,
      {String? errorMessage}) {
    if (value != null && value.trim().length > maxLength) {
      return errorMessage ?? 'Hodnota nesmí být delĹˇí neť $maxLength znaků.';
    }
    return null;
  }

  /// Ověří formát emailovĂ© adresy.
  static String? validateEmail(
    String? value, {
    String requiredMessage = 'Email je povinný',
    String invalidMessage = 'Neplatná emailová adresa.',
  }) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return requiredMessage;

    final emailRegExp = RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,63}$',
      caseSensitive: false,
    );

    if (!emailRegExp.hasMatch(v)) return invalidMessage;
    return null;
  }

  /// Ověří, ťe heslo splĹuje minimální dĂ©lku.
  static String? validatePassword(String? value,
      {int minLength = 6, String? errorMessage}) {
    if (value == null || value.isEmpty) {
      return 'Heslo je povinnĂ©';
    }
    if (value.length < minLength) {
      return errorMessage ?? 'Heslo musí mít alespoĹ $minLength znaků.';
    }
    return null;
  }

  /// Ověří formát telefonního čísla.
  static String? validatePhoneNumber(String? value,
      {String errorMessage = 'NeplatnĂ© telefonní číslo.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefonní číslo je povinnĂ©';
    }
    final RegExp phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
    if (!phoneRegExp.hasMatch(value.trim())) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří formát URL.
  static String? validateURL(String? value,
      {String errorMessage = 'Neplatná URL adresa.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'URL je povinná';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří, ťe zadaný řetězec je platným datem.
  /// Pokud je [mustBeFuture] true, datum musí být v budoucnu; pokud [mustBePast] true, musí být v minulosti.
  static String? validateDate(String? value,
      {bool mustBeFuture = false,
      bool mustBePast = false,
      String errorMessage = 'NeplatnĂ© datum.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Datum je povinnĂ©';
    }
    try {
      final date = DateTime.parse(value.trim());
      final now = DateTime.now();
      if (mustBeFuture && !date.isAfter(now)) {
        return 'Datum musí být v budoucnu.';
      }
      if (mustBePast && !date.isBefore(now)) {
        return 'Datum musí být v minulosti.';
      }
    } catch (e) {
      return errorMessage;
    }
    return null;
  }

  /// Sloťený validátor, který aplikuje více validátorů postupně a vrací první chybovou zprávu.
  static String? composeValidators(
      String? value, List<String? Function(String? value)> validators) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
