/// lib/utils/safe_tr.dart - Globální bezpečná náhrada tr() funkce
library;

import 'package:easy_localization/easy_localization.dart' as easy;
import 'package:flutter/foundation.dart';
import 'translation_helper.dart';

/// Bezpečná náhrada tr() funkce
String tr(
  String key, {
  List<String>? args,
  Map<String, String>? namedArgs,
  String? gender,
}) {
  try {
    // Pokusíme se pouťít původní tr() funkci
    final result =
        easy.tr(key, args: args, namedArgs: namedArgs, gender: gender);

    // Ověříme, ťe výsledek je platný string
    if (result.isNotEmpty) {
      return result;
    }

    // Pokud není, pouťijeme náĹˇ bezpečný helper
    debugPrint('[SafeTr] Neplatný překlad pro klíč: $key, pouťívám fallback');
    return TranslationHelper.safeTranslate(
      key,
      args: args,
      namedArgs: namedArgs,
      fallback: TranslationHelper.getFallbackTranslation(key),
    );
  } catch (e, stack) {
    debugPrint('[SafeTr] Chyba při překladu klíče "$key": $e');
    if (kDebugMode) {
      debugPrint('[SafeTr] Stack trace: $stack');
    }

    // Vrátíme bezpečný fallback
    return TranslationHelper.safeTranslate(
      key,
      args: args,
      namedArgs: namedArgs,
      fallback: TranslationHelper.getFallbackTranslation(key),
    );
  }
}

/// Bezpečná náhrada plural() funkce
String plural(
  String key,
  num value, {
  List<String>? args,
  Map<String, String>? namedArgs,
  String? name,
  String? gender,
}) {
  try {
    final result = easy.plural(
      key,
      value,
      args: args,
      namedArgs: namedArgs,
      name: name,
    ); // Uzavřel jsi závorku

    if (result.isNotEmpty) {
      return result;
    }

    // Fallback pro plural
    debugPrint('[SafeTr] Neplatný plural překlad pro klíč: $key');
    return TranslationHelper.safeTranslate(
      key,
      args: args,
      namedArgs: namedArgs,
      fallback: '$key ($value)',
    );
  } catch (e) {
    debugPrint('[SafeTr] Chyba při plural překladu klíče "$key": $e');
    return TranslationHelper.safeTranslate(
      key,
      args: args,
      namedArgs: namedArgs,
      fallback: '$key ($value)',
    );
  }
}
