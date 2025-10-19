/// lib/services/local_storage_service.dart
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Třída pro práci s lokálním úloťiĹˇtěm.
///
/// Tato sluťba zapouzdřuje operace s SharedPreferences a poskytuje metody
/// pro ukládání a náčítání dat různých typů.
class LocalStorageService {
  final SharedPreferences _sharedPreferences;

  // Klíče pro uloťenĂ© hodnoty
  static const String _scheduleItemsKey = 'schedule_items';
  static const String _userPreferencesKey = 'user_preferences';

  // Konstruktor s povinným parametrem SharedPreferences
  LocalStorageService({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;

  /// Uloťí seznam poloťek do lokálního úloťiĹˇtě.
  Future<bool> saveItems(List<dynamic> items, String key) async {
    try {
      // Převedeme poloťky na JSON
      final jsonData = jsonEncode(items);

      // Uloťíme JSON do SharedPreferences
      return await _sharedPreferences.setString(key, jsonData);
    } catch (e) {
      debugPrint('Chyba při ukládání poloťek: $e');
      return false;
    }
  }

  /// Náčte seznam poloťek z lokálního úloťiĹˇtě.
  List<dynamic> loadItems(String key) {
    try {
      // Náčteme JSON ze SharedPreferences
      final jsonData = _sharedPreferences.getString(key);

      // Pokud je JSON prázdný, vrátíme prázdný seznam
      if (jsonData == null || jsonData.isEmpty) {
        return [];
      }

      // Převedeme JSON na seznam poloťek
      return jsonDecode(jsonData) as List<dynamic>;
    } catch (e) {
      debugPrint('Chyba při náčítání poloťek: $e');
      return [];
    }
  }

  /// Uloťí harmonogram do lokálního úloťiĹˇtě.
  Future<bool> saveScheduleItems(List<dynamic> items) async {
    return await saveItems(items, _scheduleItemsKey);
  }

  /// Náčte harmonogram z lokálního úloťiĹˇtě.
  List<dynamic> loadScheduleItems() {
    return loadItems(_scheduleItemsKey);
  }

  /// Uloťí uťivatelskĂ© preference do lokálního úloťiĹˇtě.
  Future<bool> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      // Převedeme preference na JSON
      final jsonData = jsonEncode(preferences);

      // Uloťíme JSON do SharedPreferences
      return await _sharedPreferences.setString(_userPreferencesKey, jsonData);
    } catch (e) {
      debugPrint('Chyba při ukládání uťivatelských preferencí: $e');
      return false;
    }
  }

  /// Náčte uťivatelskĂ© preference z lokálního úloťiĹˇtě.
  Map<String, dynamic> loadUserPreferences() {
    try {
      // Náčteme JSON ze SharedPreferences
      final jsonData = _sharedPreferences.getString(_userPreferencesKey);

      // Pokud je JSON prázdný, vrátíme prázdnou mapu
      if (jsonData == null || jsonData.isEmpty) {
        return {};
      }

      // Převedeme JSON na mapu preferencí
      return jsonDecode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Chyba při náčítání uťivatelských preferencí: $e');
      return {};
    }
  }

  /// Uloťí hodnotu do lokálního úloťiĹˇtě.
  Future<bool> setValue(String key, dynamic value) async {
    try {
      if (value is String) {
        return await _sharedPreferences.setString(key, value);
      } else if (value is int) {
        return await _sharedPreferences.setInt(key, value);
      } else if (value is double) {
        return await _sharedPreferences.setDouble(key, value);
      } else if (value is bool) {
        return await _sharedPreferences.setBool(key, value);
      } else if (value is List<String>) {
        return await _sharedPreferences.setStringList(key, value);
      } else {
        // Pro ostatní typy převedeme na JSON
        final jsonData = jsonEncode(value);
        return await _sharedPreferences.setString(key, jsonData);
      }
    } catch (e) {
      debugPrint('Chyba při ukládání hodnoty: $e');
      return false;
    }
  }

  /// Náčte hodnotu z lokálního úloťiĹˇtě.
  dynamic getValue(String key, {dynamic defaultValue}) {
    try {
      if (!_sharedPreferences.containsKey(key)) {
        return defaultValue;
      }

      // Pokusíme se náčíst hodnotu
      return _sharedPreferences.get(key);
    } catch (e) {
      debugPrint('Chyba při náčítání hodnoty: $e');
      return defaultValue;
    }
  }

  /// Odstraní hodnotu z lokálního úloťiĹˇtě.
  Future<bool> removeValue(String key) async {
    try {
      return await _sharedPreferences.remove(key);
    } catch (e) {
      debugPrint('Chyba při odstraĹování hodnoty: $e');
      return false;
    }
  }

  /// Vyčistí lokální úloťiĹˇtě.
  Future<bool> clear() async {
    try {
      return await _sharedPreferences.clear();
    } catch (e) {
      debugPrint('Chyba při čiĹˇtění lokálního úloťiĹˇtě: $e');
      return false;
    }
  }

  /// Získání int hodnoty
  Future<int?> getInt(String key) async {
    try {
      return _sharedPreferences.getInt(key);
    } catch (e) {
      debugPrint('Chyba při čtení int hodnoty pro klíč $key: $e');
      return null;
    }
  }

  /// Uloťení int hodnoty
  Future<bool> setInt(String key, int value) async {
    try {
      return await _sharedPreferences.setInt(key, value);
    } catch (e) {
      debugPrint('Chyba při ukládání int hodnoty pro klíč $key: $e');
      return false;
    }
  }

  /// Získání string hodnoty
  Future<String?> getString(String key) async {
    try {
      return _sharedPreferences.getString(key);
    } catch (e) {
      debugPrint('Chyba při čtení string hodnoty pro klíč $key: $e');
      return null;
    }
  }

  /// Uloťení string hodnoty
  Future<bool> setString(String key, String value) async {
    try {
      return await _sharedPreferences.setString(key, value);
    } catch (e) {
      debugPrint('Chyba při ukládání string hodnoty pro klíč $key: $e');
      return false;
    }
  }

  /// Získání JSON mapy z lokálního úloťiĹˇtě - NOVĂ METODA
  Future<Map<String, int>?> getJsonMap(String key) async {
    try {
      final jsonString = _sharedPreferences.getString(key);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }

      final decoded = jsonDecode(jsonString);
      return Map<String, int>.from(decoded);
    } catch (e) {
      debugPrint('Chyba při čtení JSON mapy pro klíč $key: $e');
      return null;
    }
  }

  /// Uloťení JSON mapy do lokálního úloťiĹˇtě - NOVĂ METODA
  Future<bool> setJsonMap(String key, Map<String, int> value) async {
    try {
      final jsonString = jsonEncode(value);
      return await _sharedPreferences.setString(key, jsonString);
    } catch (e) {
      debugPrint('Chyba při ukládání JSON mapy pro klíč $key: $e');
      return false;
    }
  }
}
