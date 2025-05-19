// lib/services/permission_handler.dart - nový soubor pro správu problémů s oprávněními

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Služba pro správu problémů s oprávněními v aplikaci.
///
/// Umožňuje ukládat informace o oprávněních, které mají jednotliví uživatelé,
/// a poskytuje metody pro obnovu oprávnění a práci v režimu s omezenými oprávněními.
class PermissionHandler {
  static const String _permissionErrorKey = 'permission_error';
  static const String _permissionUserIdKey = 'permission_user_id';
  static const String _permissionCollectionKey = 'permission_collection';
  
  /// Uloží informaci o problému s oprávněními pro daného uživatele a kolekci.
  static Future<void> savePermissionError(
    String userId, 
    String collection, 
    bool hasError,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Uložení informace o problému
      await prefs.setBool('${_permissionErrorKey}_${userId}_${collection}', hasError);
      
      // Uložení seznamu uživatelů a kolekcí s problémy
      List<String> userIds = prefs.getStringList(_permissionUserIdKey) ?? [];
      List<String> collections = prefs.getStringList(_permissionCollectionKey) ?? [];
      
      if (hasError) {
        // Přidání uživatele a kolekce do seznamů, pokud tam ještě nejsou
        if (!userIds.contains(userId)) {
          userIds.add(userId);
          await prefs.setStringList(_permissionUserIdKey, userIds);
        }
        
        if (!collections.contains(collection)) {
          collections.add(collection);
          await prefs.setStringList(_permissionCollectionKey, collections);
        }
      }
      
      debugPrint('Uložen stav oprávnění pro uživatele $userId, kolekci $collection: $hasError');
    } catch (e) {
      debugPrint('Chyba při ukládání stavu oprávnění: $e');
    }
  }
  
  /// Zjistí, zda uživatel má problém s oprávněními pro danou kolekci.
  static Future<bool> hasPermissionError(String userId, String collection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_permissionErrorKey}_${userId}_${collection}') ?? false;
    } catch (e) {
      debugPrint('Chyba při zjišťování stavu oprávnění: $e');
      return false;
    }
  }
  
  /// Resetuje všechny informace o problémech s oprávněními.
  static Future<void> resetAllPermissionErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Získání seznamů uživatelů a kolekcí
      List<String> userIds = prefs.getStringList(_permissionUserIdKey) ?? [];
      List<String> collections = prefs.getStringList(_permissionCollectionKey) ?? [];
      
      // Odstranění všech klíčů s oprávněními
      for (String userId in userIds) {
        for (String collection in collections) {
          await prefs.remove('${_permissionErrorKey}_${userId}_${collection}');
        }
      }
      
      // Odstranění seznamů
      await prefs.remove(_permissionUserIdKey);
      await prefs.remove(_permissionCollectionKey);
      
      debugPrint('Resetovány všechny informace o problémech s oprávněními');
    } catch (e) {
      debugPrint('Chyba při resetování informací o oprávněních: $e');
    }
  }
  
  /// Resetuje informace o problémech s oprávněními pro konkrétního uživatele.
  static Future<void> resetUserPermissionErrors(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Získání seznamu kolekcí
      List<String> collections = prefs.getStringList(_permissionCollectionKey) ?? [];
      
      // Odstranění všech klíčů s oprávněními pro tohoto uživatele
      for (String collection in collections) {
        await prefs.remove('${_permissionErrorKey}_${userId}_${collection}');
      }
      
      // Aktualizace seznamu uživatelů
      List<String> userIds = prefs.getStringList(_permissionUserIdKey) ?? [];
      userIds.remove(userId);
      await prefs.setStringList(_permissionUserIdKey, userIds);
      
      debugPrint('Resetovány informace o problémech s oprávněními pro uživatele $userId');
    } catch (e) {
      debugPrint('Chyba při resetování informací o oprávněních: $e');
    }
  }
  
  /// Vrátí seznam všech kolekcí, u kterých má uživatel problém s oprávněními.
  static Future<List<String>> getErrorCollections(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> collections = prefs.getStringList(_permissionCollectionKey) ?? [];
      List<String> errorCollections = [];
      
      for (String collection in collections) {
        if (prefs.getBool('${_permissionErrorKey}_${userId}_${collection}') ?? false) {
          errorCollections.add(collection);
        }
      }
      
      return errorCollections;
    } catch (e) {
      debugPrint('Chyba při získávání seznamu problémových kolekcí: $e');
      return [];
    }
  }
  
  /// Určí, zda je chyba způsobená nedostatečnými oprávněními.
  static bool isPermissionError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') || 
           errorStr.contains('permission_denied') ||
           errorStr.contains('insufficient permissions');
  }
}