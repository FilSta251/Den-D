/// lib/providers/theme_manager.dart
library;

import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

/// Provider pro správu tématu aplikace (světlý/tmavý režim)
class ThemeManager extends ChangeNotifier {
  final LocalStorageService _localStorage;

  // Klíč pro uložení preference v local storage
  static const String _themeKey = 'theme_mode';

  // Aktuální režim tématu - vždy začínáme se světlým režimem
  ThemeMode _themeMode = ThemeMode.light;

  ThemeManager({required LocalStorageService localStorage})
      : _localStorage = localStorage {
    _loadThemePreference();
  }

  /// Získá aktuální režim tématu
  ThemeMode get themeMode => _themeMode;

  /// Zjistí, zda je aktivní tmavý režim
  bool get isDarkMode {
    return _themeMode == ThemeMode.dark;
  }

  /// Načte uloženou preferenci tématu
  Future<void> _loadThemePreference() async {
    try {
      final savedTheme =
          _localStorage.getValue(_themeKey, defaultValue: 'light') as String;

      switch (savedTheme) {
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          // Vše ostatní včetně 'light' a 'system' nastavíme na light
          _themeMode = ThemeMode.light;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Chyba při načítání preference tématu: $e');
      _themeMode = ThemeMode.light;
    }
  }

  /// Uloží preferenci tématu
  Future<void> _saveThemePreference() async {
    try {
      String value;
      switch (_themeMode) {
        case ThemeMode.dark:
          value = 'dark';
          break;
        default:
          // Light i System ukládáme jako light
          value = 'light';
      }

      await _localStorage.setValue(_themeKey, value);
    } catch (e) {
      debugPrint('Chyba při ukládání preference tématu: $e');
    }
  }

  /// Nastaví režim tématu
  Future<void> setThemeMode(ThemeMode mode) async {
    // System mode převedeme na light
    final actualMode = mode == ThemeMode.system ? ThemeMode.light : mode;

    if (_themeMode != actualMode) {
      _themeMode = actualMode;
      await _saveThemePreference();
      notifyListeners();
    }
  }

  /// Přepne mezi světlým a tmavým režimem
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }

  /// Nastaví světlý režim
  Future<void> setLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  /// Nastaví tmavý režim
  Future<void> setDarkMode() async {
    await setThemeMode(ThemeMode.dark);
  }

  /// Nastaví automatický režim podle systému - převede se na světlý režim
  Future<void> setSystemMode() async {
    await setThemeMode(ThemeMode.light);
  }
}
