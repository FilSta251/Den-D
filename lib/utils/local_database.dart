// lib/utils/local_database.dart

import "dart:async";
import "dart:convert";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:path_provider/path_provider.dart";
import "dart:io";
import "package:crypto/crypto.dart";

/// Abstrakce nad lokálním úložištěm dat.
///
/// Poskytuje jednotné rozhraní pro ukládání a načítání dat z různých
/// typů lokálního úložiště (SharedPreferences, SecureStorage, soubory).
class LocalDatabase {
  // Singleton instance
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  // Instance úložišť
  late SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Indikace, zda byla databáze inicializována
  bool _initialized = false;
  
  // Kešované hodnoty
  final Map<String, dynamic> _cache = {};
  
  // Maximální velikost cache položky
  static const int _maxCacheItemSize = 1024 * 10; // 10 KB
  
  // Expirace položek v cache (ms)
  static const int _cacheExpiryMs = 1000 * 60 * 5; // 5 minut
  
  // Informace o expiraci položek
  final Map<String, DateTime> _cacheExpiry = {};
  
  // Událost pro databázové změny
  final StreamController<String> _changeController = StreamController<String>.broadcast();
  
  /// Stream pro sledování změn v databázi.
  Stream<String> get onChange => _changeController.stream;

  /// Inicializuje databázi.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _preferences = await SharedPreferences.getInstance();
      _initialized = true;
      debugPrint("LocalDatabase initialized");
    } catch (e) {
      debugPrint("Failed to initialize LocalDatabase: $e");
      rethrow;
    }
  }

  /// Ukládá hodnotu do standardního úložiště.
  Future<bool> setValue(String key, dynamic value) async {
    if (!_initialized) await initialize();
    
    try {
      // Aktualizace cache
      _updateCache(key, value);
      
      // Vynucení notifikace o změně
      _notifyChange(key);
      
      // Uložení hodnoty do patřičného úložiště v závislosti na typu
      if (value is String) {
        return await _preferences.setString(key, value);
      } else if (value is int) {
        return await _preferences.setInt(key, value);
      } else if (value is double) {
        return await _preferences.setDouble(key, value);
      } else if (value is bool) {
        return await _preferences.setBool(key, value);
      } else if (value is List<String>) {
        return await _preferences.setStringList(key, value);
      } else {
        // Pro ostatní typy serializujeme do JSON
        final jsonValue = jsonEncode(value);
        return await _preferences.setString(key, jsonValue);
      }
    } catch (e) {
      debugPrint("Failed to save value for key $key: $e");
      return false;
    }
  }

  /// Čte hodnotu ze standardního úložiště.
  dynamic getValue(String key, {dynamic defaultValue}) {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    try {
      // Nejprve zkusíme načíst z cache, pokud je položka platná
      if (_isCacheValid(key)) {
        return _cache[key];
      }
      
      // Pokud není v cache, načteme z úložiště
      if (!_preferences.containsKey(key)) {
        return defaultValue;
      }
      
      // Určíme typ uložené hodnoty a načteme ji
      final Object? rawValue = _preferences.get(key);
      
      // Pokud je hodnota null, vrátíme výchozí hodnotu
      if (rawValue == null) {
        return defaultValue;
      }
      
      // Aktualizace cache
      _updateCache(key, rawValue);
      
      return rawValue;
    } catch (e) {
      debugPrint("Failed to get value for key $key: $e");
      return defaultValue;
    }
  }

  /// Ukládá hodnotu do bezpečného úložiště.
  Future<void> setSecureValue(String key, String value) async {
    if (!_initialized) await initialize();
    
    try {
      await _secureStorage.write(key: key, value: value);
      
      // Bezpečné hodnoty neukládáme do cache!
      
      // Vynucení notifikace o změně
      _notifyChange(key);
    } catch (e) {
      debugPrint("Failed to save secure value for key $key: $e");
      rethrow;
    }
  }

  /// Čte hodnotu z bezpečného úložiště.
  Future<String?> getSecureValue(String key) async {
    if (!_initialized) await initialize();
    
    try {
      // Bezpečné hodnoty neukládáme do cache!
      return await _secureStorage.read(key: key);
    } catch (e) {
      debugPrint("Failed to get secure value for key $key: $e");
      rethrow;
    }
  }

  /// Ukládá objekt do úložiště jako JSON.
  Future<bool> setObject(String key, Object value) async {
    if (!_initialized) await initialize();
    
    try {
      final jsonString = jsonEncode(value);
      final success = await _preferences.setString(key, jsonString);
      
      // Aktualizace cache
      if (success) {
        _updateCache(key, value);
        _notifyChange(key);
      }
      
      return success;
    } catch (e) {
      debugPrint("Failed to save object for key $key: $e");
      return false;
    }
  }

  /// Čte objekt z úložiště jako JSON.
  T? getObject<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    try {
      // Nejprve zkusíme načíst z cache
      if (_isCacheValid(key) && _cache[key] is T) {
        return _cache[key] as T;
      }
      
      // Pokud není v cache, načteme z úložiště
      final jsonString = _preferences.getString(key);
      if (jsonString == null) {
        return null;
      }
      
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      final object = fromJson(jsonMap);
      
      // Aktualizace cache
      _updateCache(key, object);
      
      return object;
    } catch (e) {
      debugPrint("Failed to get object for key $key: $e");
      return null;
    }
  }

  /// Ukládá binární data do souboru.
  Future<bool> setBinaryData(String key, List<int> data) async {
    if (!_initialized) await initialize();
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/$key";
      final file = File(path);
      
      await file.writeAsBytes(data);
      
      // Aktualizace reference v SharedPreferences
      await _preferences.setString("__file_$key", path);
      
      // Vynucení notifikace o změně
      _notifyChange(key);
      
      return true;
    } catch (e) {
      debugPrint("Failed to save binary data for key $key: $e");
      return false;
    }
  }

  /// Čte binární data ze souboru.
  Future<List<int>?> getBinaryData(String key) async {
    if (!_initialized) await initialize();
    
    try {
      final path = _preferences.getString("__file_$key");
      if (path == null) {
        return null;
      }
      
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      
      return await file.readAsBytes();
    } catch (e) {
      debugPrint("Failed to get binary data for key $key: $e");
      return null;
    }
  }

  /// Odstraňuje hodnotu z úložiště.
  Future<bool> removeValue(String key) async {
    if (!_initialized) await initialize();
    
    try {
      // Odstranění z cache
      _cache.remove(key);
      _cacheExpiry.remove(key);
      
      // Kontrola, zda jde o soubor
      final isFile = _preferences.containsKey("__file_$key");
      
      if (isFile) {
        final path = _preferences.getString("__file_$key");
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          await _preferences.remove("__file_$key");
        }
      }
      
      // Kontrola, zda jde o bezpečnou hodnotu
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {
        // Ignorujeme chybu, pokud hodnota neexistuje
      }
      
      // Vynucení notifikace o změně
      _notifyChange(key);
      
      // Odstranění z běžného úložiště
      return await _preferences.remove(key);
    } catch (e) {
      debugPrint("Failed to remove value for key $key: $e");
      return false;
    }
  }

  /// Vyčistí celé úložiště.
  Future<bool> clear() async {
    if (!_initialized) await initialize();
    
    try {
      // Vyčištění cache
      _cache.clear();
      _cacheExpiry.clear();
      
      // Vyčištění souborů
      final filePrefixKeys = _preferences.getKeys()
          .where((key) => key.startsWith("__file_"))
          .toList();
      
      for (final key in filePrefixKeys) {
        final path = _preferences.getString(key);
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
      
      // Vyčištění bezpečného úložiště
      await _secureStorage.deleteAll();
      
      // Vynucení notifikace o změně
      _notifyChange("*");
      
      // Vyčištění běžného úložiště
      return await _preferences.clear();
    } catch (e) {
      debugPrint("Failed to clear database: $e");
      return false;
    }
  }

  /// Vrací všechny klíče v úložišti.
  Set<String> getKeys() {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    return _preferences.getKeys();
  }

  /// Kontroluje, zda úložiště obsahuje daný klíč.
  bool containsKey(String key) {
    if (!_initialized) {
      throw Exception("LocalDatabase not initialized. Call initialize() first.");
    }
    
    return _preferences.containsKey(key) || _cache.containsKey(key);
  }

  /// Aktualizuje hodnotu v cache.
  void _updateCache(String key, dynamic value) {
    // Pokud je hodnota příliš velká, neukládáme ji do cache
    final valueSize = _estimateSize(value);
    if (valueSize > _maxCacheItemSize) {
      return;
    }
    
    _cache[key] = value;
    _cacheExpiry[key] = DateTime.now().add(Duration(milliseconds: _cacheExpiryMs));
  }

  /// Kontroluje, zda je položka v cache platná (neexpirovaná).
  bool _isCacheValid(String key) {
    if (!_cache.containsKey(key) || !_cacheExpiry.containsKey(key)) {
      return false;
    }
    
    final expiry = _cacheExpiry[key]!;
    return DateTime.now().isBefore(expiry);
  }

  /// Odhaduje velikost hodnoty.
  int _estimateSize(dynamic value) {
    if (value is String) {
      return value.length * 2; // Přibližná velikost v UTF-16
    } else if (value is int || value is double) {
      return 8; // 64 bitů
    } else if (value is bool) {
      return 1;
    } else if (value is List) {
      return value.fold<int>(0, (sum, item) => sum + _estimateSize(item));
    } else if (value is Map) {
      return value.entries.fold<int>(
        0, 
        (sum, entry) => sum + _estimateSize(entry.key) + _estimateSize(entry.value)
      );
    } else {
      return 100; // Výchozí odhad pro ostatní typy
    }
  }

  /// Oznamuje změnu v databázi.
  void _notifyChange(String key) {
    _changeController.add(key);
  }

  /// Spočítá hash z dat.
  String computeHash(List<int> data) {
    final digest = sha256.convert(data);
    return digest.toString();
  }

  /// Uvolňuje zdroje.
  void dispose() {
    _changeController.close();
  }
}
