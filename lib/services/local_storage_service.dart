// lib/services/local_storage_service.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Třída pro práci s lokálním úložištěm.
/// 
/// Tato služba zapouzdřuje operace s SharedPreferences a poskytuje metody
/// pro ukládání a načítání dat různých typů.
class LocalStorageService {
  final SharedPreferences _sharedPreferences;
  
  // Klíče pro uložené hodnoty
  static const String _scheduleItemsKey = 'schedule_items';
  static const String _userPreferencesKey = 'user_preferences';
  
  // Konstruktor s povinným parametrem SharedPreferences
  LocalStorageService({
    required SharedPreferences sharedPreferences,
  }) : _sharedPreferences = sharedPreferences;
  
  /// Uloží seznam položek do lokálního úložiště.
  Future<bool> saveItems(List<dynamic> items, String key) async {
    try {
      // Převedeme položky na JSON
      final jsonData = jsonEncode(items);
      
      // Uložíme JSON do SharedPreferences
      return await _sharedPreferences.setString(key, jsonData);
    } catch (e) {
      debugPrint('Chyba při ukládání položek: $e');
      return false;
    }
  }
  
  /// Načte seznam položek z lokálního úložiště.
  List<dynamic> loadItems(String key) {
    try {
      // Načteme JSON ze SharedPreferences
      final jsonData = _sharedPreferences.getString(key);
      
      // Pokud je JSON prázdný, vrátíme prázdný seznam
      if (jsonData == null || jsonData.isEmpty) {
        return [];
      }
      
      // Převedeme JSON na seznam položek
      return jsonDecode(jsonData) as List<dynamic>;
    } catch (e) {
      debugPrint('Chyba při načítání položek: $e');
      return [];
    }
  }
  
  /// Uloží harmonogram do lokálního úložiště.
  Future<bool> saveScheduleItems(List<dynamic> items) async {
    return await saveItems(items, _scheduleItemsKey);
  }
  
  /// Načte harmonogram z lokálního úložiště.
  List<dynamic> loadScheduleItems() {
    return loadItems(_scheduleItemsKey);
  }
  
  /// Uloží uživatelské preference do lokálního úložiště.
  Future<bool> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      // Převedeme preference na JSON
      final jsonData = jsonEncode(preferences);
      
      // Uložíme JSON do SharedPreferences
      return await _sharedPreferences.setString(_userPreferencesKey, jsonData);
    } catch (e) {
      debugPrint('Chyba při ukládání uživatelských preferencí: $e');
      return false;
    }
  }
  
  /// Načte uživatelské preference z lokálního úložiště.
  Map<String, dynamic> loadUserPreferences() {
    try {
      // Načteme JSON ze SharedPreferences
      final jsonData = _sharedPreferences.getString(_userPreferencesKey);
      
      // Pokud je JSON prázdný, vrátíme prázdnou mapu
      if (jsonData == null || jsonData.isEmpty) {
        return {};
      }
      
      // Převedeme JSON na mapu preferencí
      return jsonDecode(jsonData) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Chyba při načítání uživatelských preferencí: $e');
      return {};
    }
  }
  
  /// Uloží hodnotu do lokálního úložiště.
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
  
  /// Načte hodnotu z lokálního úložiště.
  dynamic getValue(String key, {dynamic defaultValue}) {
    try {
      if (!_sharedPreferences.containsKey(key)) {
        return defaultValue;
      }
      
      // Pokusíme se načíst hodnotu
      return _sharedPreferences.get(key);
    } catch (e) {
      debugPrint('Chyba při načítání hodnoty: $e');
      return defaultValue;
    }
  }
  
  /// Odstraní hodnotu z lokálního úložiště.
  Future<bool> removeValue(String key) async {
    try {
      return await _sharedPreferences.remove(key);
    } catch (e) {
      debugPrint('Chyba při odstraňování hodnoty: $e');
      return false;
    }
  }
  
  /// Vyčistí lokální úložiště.
  Future<bool> clear() async {
    try {
      return await _sharedPreferences.clear();
    } catch (e) {
      debugPrint('Chyba při čištění lokálního úložiště: $e');
      return false;
    }
  }
}