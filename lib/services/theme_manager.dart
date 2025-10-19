/// lib/services/theme_manager.dart
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Správce tĂ©mat aplikace - zajiĹˇšuje přepínání mezi světlým a tmavým reťimem
class ThemeManager extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light; // Default světlý reťim

  ThemeMode get themeMode => _themeMode;

  /// Inicializuje ThemeManager a náčte uloťenĂ© nastavení
  Future<void> initialize() async {
    debugPrint('[ThemeManager] Initializing theme manager');
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeMode = prefs.getString(_themeModeKey);

      if (savedThemeMode != null) {
        switch (savedThemeMode) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          case 'system':
            _themeMode = ThemeMode.system;
            break;
          default:
            _themeMode = ThemeMode.light;
        }
      } else {
        // První spuĹˇtění - nastavíme světlý reťim jako default
        _themeMode = ThemeMode.light;
        await _saveThemeMode();
      }

      debugPrint('[ThemeManager] Theme mode initialized: $_themeMode');
      notifyListeners();
    } catch (e) {
      debugPrint('[ThemeManager] Error initializing: $e');
      // V případě chyby ponecháme světlý reťim
      _themeMode = ThemeMode.light;
      notifyListeners();
    }
  }

  /// Nastaví nový reťim tĂ©matu
  Future<void> setThemeMode(ThemeMode themeMode) async {
    debugPrint('[ThemeManager] Setting theme mode: $themeMode');
    _themeMode = themeMode;
    await _saveThemeMode();
    notifyListeners();
  }

  /// Uloťí aktuální reťim tĂ©matu do SharedPreferences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeModeString;

      switch (_themeMode) {
        case ThemeMode.light:
          themeModeString = 'light';
          break;
        case ThemeMode.dark:
          themeModeString = 'dark';
          break;
        case ThemeMode.system:
          themeModeString = 'system';
          break;
      }

      await prefs.setString(_themeModeKey, themeModeString);
      debugPrint('[ThemeManager] Theme mode saved: $themeModeString');
    } catch (e) {
      debugPrint('[ThemeManager] Error saving theme mode: $e');
    }
  }

  /// Resetuje nastavení tĂ©matu na výchozí (světlĂ©)
  Future<void> resetToDefault() async {
    debugPrint('[ThemeManager] Resetting theme to default (light)');
    await setThemeMode(ThemeMode.light);
  }

  /// Vrátí true pokud je aktuálně aktivní tmavý reťim
  bool get isDarkMode {
    return _themeMode == ThemeMode.dark;
  }

  /// Vrátí true pokud je nastaveno podle systĂ©mu
  bool get isSystemMode {
    return _themeMode == ThemeMode.system;
  }

  /// Přepne mezi světlým a tmavým reťimem
  Future<void> toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
}
