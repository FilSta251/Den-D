import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/wedding_info.dart';
import '../repositories/wedding_repository.dart';

/// Abstraktní rozhraní pro úložiště informací o svatbě.
abstract class WeddingInfoStorage {
  Future<bool> saveWeddingInfo(WeddingInfo info);
  Future<WeddingInfo?> loadWeddingInfo();
  Future<bool> clearWeddingInfo();
}

/// Verze aktuálního uloženého formátu. Při změně schématu zvyšte tuto hodnotu.
const int _currentVersion = 1;

/// Timeout pro cloud operace
const Duration _cloudTimeout = Duration(seconds: 15);

/// Počet pokusů při selhání cloud operace
const int _maxRetries = 3;

/// Produkční implementace úložiště informací o svatbě.
/// Používá FlutterSecureStorage pro bezpečné ukládání citlivých dat.
class LocalWeddingInfoService extends ChangeNotifier
    implements WeddingInfoStorage {
  final String _storageKey = 'wedding_info_v1';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  WeddingRepository? _weddingRepository;
  bool _cloudSyncEnabled = true;
  bool _initialized = false;
  StreamSubscription<WeddingInfo?>? _cloudSubscription;

  WeddingInfo? _weddingInfo;
  WeddingInfo? get weddingInfo => _weddingInfo;

  /// Nastaví referenci na WeddingRepository
  void setWeddingRepository(WeddingRepository repository) {
    _weddingRepository = repository;
    _subscribeToCloudUpdates();
  }

  /// Povolí nebo zakáže synchronizaci s cloudem
  void setCloudSyncEnabled(bool enabled) {
    _cloudSyncEnabled = enabled;
    debugPrint(
        '[LocalWeddingInfoService] Cloud sync ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Přihlášení k odběru změn z cloudu
  void _subscribeToCloudUpdates() {
    if (_initialized) return;

    if (_weddingRepository != null) {
      debugPrint('[LocalWeddingInfoService] Initializing cloud subscription');
      _cloudSubscription = _weddingRepository!.weddingInfoStream.listen(
        (cloudInfo) {
          if (cloudInfo != null) {
            debugPrint('[LocalWeddingInfoService] Cloud update received');
            _weddingInfo = cloudInfo;
            _saveToLocalCache(cloudInfo);
            notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('[LocalWeddingInfoService] Cloud stream error: $error');
        },
      );
      _initialized = true;
    }
  }

  /// Uloží informace o svatbě do bezpečného úložiště
  Future<bool> _saveToLocalCache(WeddingInfo info) async {
    try {
      final Map<String, dynamic> storeMap = {
        'version': _currentVersion,
        'data': info.toJson(),
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      final String jsonString = jsonEncode(storeMap);

      await _secureStorage.write(
        key: _storageKey,
        value: jsonString,
      );

      debugPrint('[LocalWeddingInfoService] Data saved to secure storage');
      return true;
    } catch (e, stackTrace) {
      debugPrint(
          '[LocalWeddingInfoService] Error saving to secure storage: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Provede cloud operaci s retry mechanikou a timeout
  Future<T?> _executeCloudOperation<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        debugPrint(
            '[LocalWeddingInfoService] $operationName - attempt $attempt/$_maxRetries');
        final result = await operation().timeout(_cloudTimeout);
        debugPrint('[LocalWeddingInfoService] $operationName successful');
        return result;
      } on TimeoutException {
        debugPrint('[LocalWeddingInfoService] $operationName timed out');
        if (attempt == _maxRetries) {
          debugPrint(
              '[LocalWeddingInfoService] $operationName failed after $attempt attempts');
          return null;
        }
        await Future.delayed(Duration(seconds: attempt * 2));
      } catch (e) {
        debugPrint('[LocalWeddingInfoService] $operationName error: $e');
        if (attempt == _maxRetries) {
          debugPrint(
              '[LocalWeddingInfoService] $operationName failed after $attempt attempts');
          return null;
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    return null;
  }

  /// Uloží informace o svatbě lokálně a na cloud
  @override
  Future<bool> saveWeddingInfo(WeddingInfo info) async {
    try {
      // Lokální uložení má prioritu
      final localSuccess = await _saveToLocalCache(info);
      if (localSuccess) {
        _weddingInfo = info;
        notifyListeners();
      }

      // Cloud synchronizace na pozadí
      if (_cloudSyncEnabled && _weddingRepository != null) {
        _executeCloudOperation(
          () async {
            await _weddingRepository!.updateWeddingInfo(info);
            return true;
          },
          'Cloud sync',
        ).then((success) {
          if (success == true) {
            debugPrint(
                '[LocalWeddingInfoService] Background cloud sync completed');
          }
        });
      }

      return localSuccess;
    } catch (e, stackTrace) {
      debugPrint(
          '[LocalWeddingInfoService] Critical error in saveWeddingInfo: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Načte informace o svatbě z cloudu nebo lokálního úložiště
  @override
  Future<WeddingInfo?> loadWeddingInfo() async {
    // Pokus o načtení z cloudu
    if (_cloudSyncEnabled && _weddingRepository != null) {
      final cloudInfo = await _executeCloudOperation(
        () => _weddingRepository!.fetchWeddingInfo(),
        'Load from cloud',
      );

      if (cloudInfo != null) {
        _weddingInfo = cloudInfo;
        await _saveToLocalCache(cloudInfo);
        return cloudInfo;
      }
    }

    // Fallback na lokální úložiště
    try {
      debugPrint('[LocalWeddingInfoService] Loading from secure storage');
      final String? jsonString = await _secureStorage.read(key: _storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('[LocalWeddingInfoService] No local data found');
        return null;
      }

      final Map<String, dynamic> storeMap = jsonDecode(jsonString);
      final int version = storeMap['version'] ?? 0;
      Map<String, dynamic> dataMap = storeMap['data'] ?? {};

      // Migrace dat pokud je potřeba
      if (version != _currentVersion) {
        dataMap = await _migrateData(
          dataMap,
          fromVersion: version,
          toVersion: _currentVersion,
        );

        final migratedInfo = WeddingInfo.fromJson(dataMap);
        await saveWeddingInfo(migratedInfo);
      }

      _weddingInfo = WeddingInfo.fromJson(dataMap);
      debugPrint('[LocalWeddingInfoService] Local data loaded successfully');
      return _weddingInfo;
    } catch (e, stackTrace) {
      debugPrint(
          '[LocalWeddingInfoService] Error loading from secure storage: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Smaže všechny uložené informace lokálně i v cloudu
  @override
  Future<bool> clearWeddingInfo() async {
    try {
      // Lokální smazání
      await _secureStorage.delete(key: _storageKey);
      debugPrint('[LocalWeddingInfoService] Local data cleared');

      // Cloud smazání
      if (_cloudSyncEnabled &&
          _weddingRepository != null &&
          _weddingInfo != null) {
        final emptyInfo = WeddingInfo(
          userId: _weddingInfo!.userId,
          weddingDate: DateTime.now().add(const Duration(days: 180)),
          yourName: "",
          partnerName: "",
          weddingVenue: "",
          budget: 0.0,
          notes: "",
        );

        await _executeCloudOperation(
          () => _weddingRepository!.updateWeddingInfo(emptyInfo),
          'Clear cloud data',
        );
      }

      _weddingInfo = null;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      debugPrint('[LocalWeddingInfoService] Error clearing data: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  /// Migruje data mezi verzemi schématu
  Future<Map<String, dynamic>> _migrateData(
    Map<String, dynamic> oldData, {
    required int fromVersion,
    required int toVersion,
  }) async {
    debugPrint(
        '[LocalWeddingInfoService] Migrating data from v$fromVersion to v$toVersion');

    Map<String, dynamic> migratedData = Map<String, dynamic>.from(oldData);

    // Postupná migrace mezi verzemi
    for (int v = fromVersion; v < toVersion; v++) {
      migratedData = await _migrateFromVersion(migratedData, v);
    }

    return migratedData;
  }

  /// Migruje data z konkrétní verze na další
  Future<Map<String, dynamic>> _migrateFromVersion(
    Map<String, dynamic> data,
    int fromVersion,
  ) async {
    switch (fromVersion) {
      case 0:
        // Migrace z v0 na v1
        // Příklad: přidání nových polí s výchozími hodnotami
        return {
          ...data,
          // Zde přidejte nová pole pokud je potřeba
        };
      default:
        return data;
    }
  }

  /// Zruší všechny aktivní subscription a uvolní zdroje
  @override
  void dispose() {
    debugPrint('[LocalWeddingInfoService] Disposing service');
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
    _initialized = false;
    super.dispose();
  }
}
