import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/wedding_info.dart';
import '../repositories/wedding_repository.dart';

/// Abstraktní rozhraní pro úložiště informací o svatbě.
abstract class WeddingInfoStorage {
  Future<bool> saveWeddingInfo(WeddingInfo info);
  Future<WeddingInfo?> loadWeddingInfo();
  Future<bool> clearWeddingInfo();
}

/// Jednoduchá funkce pro "šifrování" pomocí Base64.
/// Pozor: toto není bezpečné šifrování, slouží pouze jako ukázka.
String encrypt(String plainText) {
  return base64Encode(utf8.encode(plainText));
}

/// Jednoduchá funkce pro "dešifrování" pomocí Base64.
String decrypt(String cipherText) {
  try {
    return utf8.decode(base64Decode(cipherText));
  } catch (e) {
    debugPrint('Decryption error: $e');
    return cipherText;
  }
}

/// Verze aktuálního uloženého formátu. Při změně schématu zvýšíte tuto hodnotu a implementujete migraci.
const int _currentVersion = 1;

/// Implementace úložiště informací o svatbě pomocí SharedPreferences.
/// Tato třída také rozšiřuje [ChangeNotifier] pro notifikaci posluchačů.
class LocalWeddingInfoService extends ChangeNotifier implements WeddingInfoStorage {
  final String _storageKey = 'wedding_info';
  
  WeddingRepository? _weddingRepository;
  bool _cloudSyncEnabled = true;

  WeddingInfo? _weddingInfo;
  WeddingInfo? get weddingInfo => _weddingInfo;

  /// Nastaví referenci na WeddingRepository
  void setWeddingRepository(WeddingRepository repository) {
    _weddingRepository = repository;
    // Přihlášení k odběru aktualizací z cloudu
    _subscribeToCloudUpdates();
  }

  /// Povolí nebo zakáže synchronizaci s cloudem
  void setCloudSyncEnabled(bool enabled) {
    _cloudSyncEnabled = enabled;
  }

  /// Přihlášení k odběru změn z cloudu
  void _subscribeToCloudUpdates() {
    if (_weddingRepository != null) {
      debugPrint('[LocalWeddingInfoService] Subscribing to cloud updates');
      _weddingRepository!.weddingInfoStream.listen((cloudInfo) {
        if (cloudInfo != null) {
          debugPrint('[LocalWeddingInfoService] Received cloud update: ${cloudInfo.toJson()}');
          // Aktualizujeme lokální cache a SharedPreferences
          _weddingInfo = cloudInfo;
          _saveToLocalCache(cloudInfo);
          notifyListeners();
        }
      });
    }
  }

  /// Uloží informace o svatbě do SharedPreferences spolu s verzí a "šifrováním".
  Future<bool> _saveToLocalCache(WeddingInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      // Připravíme mapu, která obsahuje verzi a data.
      final Map<String, dynamic> storeMap = {
        'version': _currentVersion,
        'data': info.toJson(),
      };
      final String jsonString = jsonEncode(storeMap);
      final String encrypted = encrypt(jsonString);
      final success = await prefs.setString(_storageKey, encrypted);
      debugPrint('[LocalWeddingInfoService] Saved to local cache: $success');
      return success;
    } catch (e) {
      debugPrint('[LocalWeddingInfoService] Error saving wedding info to local cache: $e');
      return false;
    }
  }

  /// Uloží informace o svatbě do SharedPreferences a na cloud.
  @override
  Future<bool> saveWeddingInfo(WeddingInfo info) async {
    try {
      // Nejprve uložíme lokálně
      final localSuccess = await _saveToLocalCache(info);
      if (localSuccess) {
        _weddingInfo = info;
        notifyListeners();
      }
      
      // Poté na cloud, pokud je povoleno
      if (_cloudSyncEnabled && _weddingRepository != null) {
        debugPrint('[LocalWeddingInfoService] Syncing to cloud: ${info.toJson()}');
        try {
          await _weddingRepository!.updateWeddingInfo(info);
          debugPrint('[LocalWeddingInfoService] Cloud sync successful');
        } catch (e) {
          debugPrint('[LocalWeddingInfoService] Error syncing to cloud: $e');
          // I když se nepodaří synchronizovat s cloudem, považujeme operaci za úspěšnou,
          // pokud se podařilo uložit lokálně
        }
      }
      
      return localSuccess;
    } catch (e) {
      debugPrint('[LocalWeddingInfoService] Error saving wedding info: $e');
      return false;
    }
  }

  /// Načte informace o svatbě z cloudu a pak ze SharedPreferences jako zálohu.
  @override
  Future<WeddingInfo?> loadWeddingInfo() async {
    // Pokud máme povolenu cloud synchronizaci, nejprve zkusíme získat data z cloudu
    if (_cloudSyncEnabled && _weddingRepository != null) {
      try {
        debugPrint('[LocalWeddingInfoService] Attempting to load from cloud');
        final cloudInfo = await _weddingRepository!.fetchWeddingInfo();
        if (cloudInfo != null) {
          _weddingInfo = cloudInfo;
          // Aktualizujeme lokální kopii
          await _saveToLocalCache(cloudInfo);
          debugPrint('[LocalWeddingInfoService] Cloud data loaded and cached locally');
          return cloudInfo;
        }
      } catch (e) {
        debugPrint('[LocalWeddingInfoService] Error loading from cloud: $e, falling back to local cache');
        // Pokračujeme k lokálnímu úložišti jako záloha
      }
    }

    // Pokud se nepodařilo načíst z cloudu nebo není povolená synchronizace,
    // načteme z lokálního úložiště
    try {
      debugPrint('[LocalWeddingInfoService] Loading from local cache');
      final prefs = await SharedPreferences.getInstance();
      final String? encrypted = prefs.getString(_storageKey);
      if (encrypted == null) {
        debugPrint('[LocalWeddingInfoService] No local cache found');
        return null;
      }
      
      final String jsonString = decrypt(encrypted);
      final Map<String, dynamic> storeMap = jsonDecode(jsonString);
      final int version = storeMap['version'] ?? 0;
      Map<String, dynamic> dataMap = storeMap['data'] ?? {};
      
      // Pokud je verze starší, proveďte migraci.
      if (version != _currentVersion) {
        dataMap = _migrateData(dataMap, fromVersion: version, toVersion: _currentVersion);
        // Uložte migraci zpět.
        final migratedInfo = WeddingInfo.fromJson(dataMap);
        await saveWeddingInfo(migratedInfo);
      }
      
      _weddingInfo = WeddingInfo.fromJson(dataMap);
      debugPrint('[LocalWeddingInfoService] Local cache loaded: ${_weddingInfo?.toJson()}');
      return _weddingInfo;
    } catch (e) {
      debugPrint('[LocalWeddingInfoService] Error loading from local cache: $e');
      return null;
    }
  }

  /// Smaže uložené informace o svatbě lokálně i v cloudu.
  @override
  Future<bool> clearWeddingInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.remove(_storageKey);
    
    // Pokud máme povolenu cloud synchronizaci, smažeme i na cloudu
    if (_cloudSyncEnabled && _weddingRepository != null && _weddingInfo != null) {
      try {
        // Vytvoříme prázdný objekt se stejným ID
        final emptyInfo = WeddingInfo(
          userId: _weddingInfo!.userId,
          weddingDate: DateTime.now().add(const Duration(days: 180)),
          yourName: "--",
          partnerName: "--",
          weddingVenue: "--",
          budget: 0.0,
          notes: "--",
        );
        
        await _weddingRepository!.updateWeddingInfo(emptyInfo);
        debugPrint('[LocalWeddingInfoService] Cloud data reset');
      } catch (e) {
        debugPrint('[LocalWeddingInfoService] Error clearing cloud data: $e');
      }
    }
    
    if (success) {
      _weddingInfo = null;
      notifyListeners();
    }
    return success;
  }

  /// Jednoduchá funkce pro migraci dat mezi verzemi.
  /// V této ukázce jen vypíše informace a vrátí původní data.
  /// V praxi zde implementujte konkrétní logiku migrace.
  Map<String, dynamic> _migrateData(Map<String, dynamic> oldData,
      {required int fromVersion, required int toVersion}) {
    debugPrint('[LocalWeddingInfoService] Migrating wedding info data from version $fromVersion to $toVersion');
    // Příklad: pokud se struktura změnila, upravte stará data zde.
    // Pro tuto ukázku pouze vrátíme původní data.
    return oldData;
  }
}