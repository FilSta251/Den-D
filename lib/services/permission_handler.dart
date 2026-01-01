/// lib/services/permission_handler.dart - nový soubor pro správu problĂ©mů s oprávněními
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sluťba pro správu problĂ©mů s oprávněními v aplikaci.
///
/// UmoťĹuje ukládat informace o oprávněních, kterĂ© mají jednotliví uťivatelĂ©,
/// a poskytuje metody pro obnovu oprávnění a práci v reťimu s omezenými oprávněními.
class PermissionHandler {
  static const String _permissionErrorKey = 'permission_error';
  static const String _permissionUserIdKey = 'permission_user_id';
  static const String _permissionCollectionKey = 'permission_collection';

  /// Uloťí informaci o problĂ©mu s oprávněními pro danĂ©ho uťivatele a kolekci.
  static Future<void> savePermissionError(
    String userId,
    String collection,
    bool hasError,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Uloťení informace o problĂ©mu
      await prefs.setBool(
          '${_permissionErrorKey}_${userId}_$collection', hasError);

      // Uloťení seznamu uťivatelů a kolekcí s problĂ©my
      List<String> userIds = prefs.getStringList(_permissionUserIdKey) ?? [];
      List<String> collections =
          prefs.getStringList(_permissionCollectionKey) ?? [];

      if (hasError) {
        // Přidání uťivatele a kolekce do seznamů, pokud tam jeĹˇtě nejsou
        if (!userIds.contains(userId)) {
          userIds.add(userId);
          await prefs.setStringList(_permissionUserIdKey, userIds);
        }

        if (!collections.contains(collection)) {
          collections.add(collection);
          await prefs.setStringList(_permissionCollectionKey, collections);
        }
      }

      debugPrint(
          'Uloťen stav oprávnění pro uťivatele $userId, kolekci $collection: $hasError');
    } catch (e) {
      debugPrint('Chyba při ukládání stavu oprávnění: $e');
    }
  }

  /// Zjistí, zda uťivatel má problĂ©m s oprávněními pro danou kolekci.
  static Future<bool> hasPermissionError(
      String userId, String collection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('${_permissionErrorKey}_${userId}_$collection') ??
          false;
    } catch (e) {
      debugPrint('Chyba při zjiĹˇšování stavu oprávnění: $e');
      return false;
    }
  }

  /// Resetuje vĹˇechny informace o problĂ©mech s oprávněními.
  static Future<void> resetAllPermissionErrors() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Získání seznamů uťivatelů a kolekcí
      List<String> userIds = prefs.getStringList(_permissionUserIdKey) ?? [];
      List<String> collections =
          prefs.getStringList(_permissionCollectionKey) ?? [];

      // Odstranění vĹˇech klíčů s oprávněními
      for (String userId in userIds) {
        for (String collection in collections) {
          await prefs.remove('${_permissionErrorKey}_${userId}_$collection');
        }
      }

      // Odstranění seznamů
      await prefs.remove(_permissionUserIdKey);
      await prefs.remove(_permissionCollectionKey);

      debugPrint('Resetovány vĹˇechny informace o problĂ©mech s oprávněními');
    } catch (e) {
      debugPrint('Chyba při resetování informací o oprávněních: $e');
    }
  }

  /// Resetuje informace o problĂ©mech s oprávněními pro konkrĂ©tního uťivatele.
  static Future<void> resetUserPermissionErrors(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Získání seznamu kolekcí
      List<String> collections =
          prefs.getStringList(_permissionCollectionKey) ?? [];

      // Odstranění vĹˇech klíčů s oprávněními pro tohoto uťivatele
      for (String collection in collections) {
        await prefs.remove('${_permissionErrorKey}_${userId}_$collection');
      }

      // Aktualizace seznamu uťivatelů
      List<String> userIds = prefs.getStringList(_permissionUserIdKey) ?? [];
      userIds.remove(userId);
      await prefs.setStringList(_permissionUserIdKey, userIds);

      debugPrint(
          'Resetovány informace o problĂ©mech s oprávněními pro uťivatele $userId');
    } catch (e) {
      debugPrint('Chyba při resetování informací o oprávněních: $e');
    }
  }

  /// Vrátí seznam vĹˇech kolekcí, u kterých má uťivatel problĂ©m s oprávněními.
  static Future<List<String>> getErrorCollections(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> collections =
          prefs.getStringList(_permissionCollectionKey) ?? [];
      List<String> errorCollections = [];

      for (String collection in collections) {
        if (prefs.getBool('${_permissionErrorKey}_${userId}_$collection') ??
            false) {
          errorCollections.add(collection);
        }
      }

      return errorCollections;
    } catch (e) {
      debugPrint('Chyba při získávání seznamu problĂ©mových kolekcí: $e');
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
