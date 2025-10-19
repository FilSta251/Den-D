/// lib/utils/translation_helper.dart
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// Bezpečný helper pro práci s překlady
class TranslationHelper {
  /// BezpečnĂ© získání překladu s fallback hodnotou
  static String safeTranslate(
    String key, {
    List<String>? args,
    Map<String, String>? namedArgs,
    String? fallback,
  }) {
    try {
      // Pokusíme se získat překlad
      final result = tr(key, args: args, namedArgs: namedArgs);

      // Ověříme, ťe výsledek je string
      if (result.isNotEmpty) {
        return result;
      }

      // Pokud není, pouťijeme fallback nebo klíč
      debugPrint(
          '[TranslationHelper] Neplatný překlad pro klíč: $key, výsledek: $result');
      return fallback ?? key;
    } catch (e, stack) {
      debugPrint('[TranslationHelper] Chyba při překladu klíče "$key": $e');
      debugPrint('[TranslationHelper] Stack trace: $stack');

      // V případě chyby vrátíme fallback nebo klíč
      return fallback ?? key;
    }
  }

  /// Zkontroluje, zda existuje překlad pro daný klíč
  static bool hasTranslation(String key) {
    try {
      final result = tr(key);
      return result.isNotEmpty && result != key;
    } catch (e) {
      return false;
    }
  }

  /// Získá překlad s argumenty a bezpečným fallbackem
  static String translateWithArgs(
    String key,
    List<String> args, {
    String? fallback,
  }) {
    return safeTranslate(key, args: args, fallback: fallback);
  }

  /// Získá překlad s pojmenovanými argumenty a bezpečným fallbackem
  static String translateWithNamedArgs(
    String key,
    Map<String, String> namedArgs, {
    String? fallback,
  }) {
    return safeTranslate(key, namedArgs: namedArgs, fallback: fallback);
  }

  /// Seznam základních překladů pro fallback
  static const Map<String, String> _fallbackTranslations = {
    'app_name': 'Svatební plánováč',
    'loading': 'Náčítání...',
    'error': 'Chyba',
    'ok': 'OK',
    'cancel': 'ZruĹˇit',
    'save': 'Uloťit',
    'delete': 'Smazat',
    'edit': 'Upravit',
    'close': 'Zavřít',
    'back': 'Zpět',
    'next': 'DalĹˇí',
    'previous': 'Předchozí',
    'confirm': 'Potvrdit',
    'yes': 'Ano',
    'no': 'Ne',
    'settings': 'Nastavení',
    'subscription': 'PředplatnĂ©',
    'free': 'Zdarma',
    'premium': 'Premium',
    'basic': 'Základní',
    'pro': 'Pro',
    'monthly': 'Měsíčně',
    'yearly': 'Ročně',
    'price': 'Cena',
    'features': 'Funkce',
    'upgrade': 'Upgradovat',
    'subscribe': 'Předplatit',
    'current_plan': 'Současný plán',
    'expires': 'VyprĹˇí',
    'renews': 'Obnovuje se',
    'active': 'Aktivní',
    'inactive': 'Neaktivní',
    'expired': 'VyprĹˇelo',
  };

  /// Získá fallback překlad z lokální mapy
  static String getFallbackTranslation(String key) {
    return _fallbackTranslations[key] ?? key;
  }

  /// Bezpečný překlad s lokálním fallbackem
  static String safeTr(String key, {List<String>? args}) {
    return safeTranslate(
      key,
      args: args,
      fallback: getFallbackTranslation(key),
    );
  }
}

/// Extension pro snadnĂ© pouťití
extension SafeTranslation on String {
  /// Bezpečný překlad tohoto řetězce jako klíče
  String get safeTr => TranslationHelper.safeTr(this);

  /// Bezpečný překlad s argumenty
  String safeTrArgs(List<String> args) =>
      TranslationHelper.safeTr(this, args: args);
}
