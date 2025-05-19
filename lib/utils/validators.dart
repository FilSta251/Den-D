// lib/utils/validators.dart

import 'package:intl/intl.dart';

/// Validators poskytuje statické metody pro ověřování vstupů.
/// Každá metoda vrací null, pokud je vstup platný, nebo chybovou zprávu při neplatnosti.
class Validators {
  /// Ověří, že hodnota není prázdná.
  static String? validateRequired(String? value, {String errorMessage = 'Toto pole je povinné.'}) {
    if (value == null || value.trim().isEmpty) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří, že hodnota má alespoň [minLength] znaků.
  static String? validateMinLength(String? value, int minLength, {String? errorMessage}) {
    if (value == null || value.trim().length < minLength) {
      return errorMessage ?? 'Hodnota musí mít alespoň $minLength znaků.';
    }
    return null;
  }

  /// Ověří, že hodnota nepřesahuje [maxLength] znaků.
  static String? validateMaxLength(String? value, int maxLength, {String? errorMessage}) {
    if (value != null && value.trim().length > maxLength) {
      return errorMessage ?? 'Hodnota nesmí být delší než $maxLength znaků.';
    }
    return null;
  }

  /// Ověří formát emailové adresy.
  static String? validateEmail(String? value, {String errorMessage = 'Neplatná emailová adresa.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Email je povinný';
    }
    final RegExp emailRegExp = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří, že heslo splňuje minimální délku.
  static String? validatePassword(String? value, {int minLength = 6, String? errorMessage}) {
    if (value == null || value.isEmpty) {
      return 'Heslo je povinné';
    }
    if (value.length < minLength) {
      return errorMessage ?? 'Heslo musí mít alespoň $minLength znaků.';
    }
    return null;
  }

  /// Ověří formát telefonního čísla.
  static String? validatePhoneNumber(String? value, {String errorMessage = 'Neplatné telefonní číslo.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefonní číslo je povinné';
    }
    final RegExp phoneRegExp = RegExp(r'^\+?[0-9]{7,15}$');
    if (!phoneRegExp.hasMatch(value.trim())) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří formát URL.
  static String? validateURL(String? value, {String errorMessage = 'Neplatná URL adresa.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'URL je povinná';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return errorMessage;
    }
    return null;
  }

  /// Ověří, že zadaný řetězec je platným datem.
  /// Pokud je [mustBeFuture] true, datum musí být v budoucnu; pokud [mustBePast] true, musí být v minulosti.
  static String? validateDate(String? value,
      {bool mustBeFuture = false, bool mustBePast = false, String errorMessage = 'Neplatné datum.'}) {
    if (value == null || value.trim().isEmpty) {
      return 'Datum je povinné';
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

  /// Složený validátor, který aplikuje více validátorů postupně a vrací první chybovou zprávu.
  static String? composeValidators(String? value, List<String? Function(String? value)> validators) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}
