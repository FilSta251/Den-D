/// lib/services/caching_strategy.dart
library;

import "dart:async";
import "package:flutter/foundation.dart";
import "../utils/local_database.dart";

/// Strategie pro cachování dat v aplikaci.
abstract class CachingStrategy<T> {
  final LocalDatabase _database;
  final String _cacheKey;
  final int _expiryTimeMs;

  CachingStrategy({
    required LocalDatabase database,
    required String cacheKey,
    required int expiryTimeMs,
  })  : _database = database,
        _cacheKey = cacheKey,
        _expiryTimeMs = expiryTimeMs;

  Future<void> saveToCache(T data);
  Future<T?> loadFromCache();
  Future<bool> isCacheValid();
  Future<T> loadFromCloud();

  Future<void> clearCache() async {
    await _database.removeValue(_cacheKey);
    await _database.removeValue("${_cacheKey}_timestamp");
  }

  Future<void> updateTimestamp() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.setValue("${_cacheKey}_timestamp", now);
  }

  Future<int?> getTimestamp() async {
    return _database.getValue("${_cacheKey}_timestamp") as int?;
  }

  Future<bool> isCacheExpired() async {
    final timestamp = await getTimestamp();
    if (timestamp == null) {
      return true;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    return now - timestamp > _expiryTimeMs;
  }

  Future<T> getData() async {
    try {
      if (await isCacheValid()) {
        final cachedData = await loadFromCache();
        if (cachedData != null) {
          debugPrint("Loaded data from cache for key $_cacheKey");
          return cachedData;
        }
      }

      final cloudData = await loadFromCloud();
      await saveToCache(cloudData);
      await updateTimestamp();

      debugPrint("Loaded data from cloud for key $_cacheKey");
      return cloudData;
    } catch (e) {
      debugPrint("Error getting data for key $_cacheKey: $e");

      final cachedData = await loadFromCache();
      if (cachedData != null) {
        debugPrint("Using expired cache data for key $_cacheKey due to error");
        return cachedData;
      }

      rethrow;
    }
  }
}

/// Strategie pro cachování objektů jako JSON.
class JsonCachingStrategy<T> extends CachingStrategy<T> {
  final T Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T data) _toJson;
  final Future<T> Function() _fetchFromCloud;

  JsonCachingStrategy({
    required super.database,
    required super.cacheKey,
    required super.expiryTimeMs,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T data) toJson,
    required Future<T> Function() fetchFromCloud,
  })  : _fromJson = fromJson,
        _toJson = toJson,
        _fetchFromCloud = fetchFromCloud;

  @override
  Future<void> saveToCache(T data) async {
    final json = _toJson(data);
    await _database.setObject(_cacheKey, json);
  }

  @override
  Future<T?> loadFromCache() async {
    final json = _database.getObject<Map<String, dynamic>>(
      _cacheKey,
      (json) => json,
    );

    if (json == null) {
      return null;
    }

    return _fromJson(json);
  }

  @override
  Future<bool> isCacheValid() async {
    final hasCachedData = _database.containsKey(_cacheKey);
    if (!hasCachedData) {
      return false;
    }

    return !(await isCacheExpired());
  }

  @override
  Future<T> loadFromCloud() async {
    return _fetchFromCloud();
  }
}

/// Strategie pro cachování seznamu objektů.
class ListCachingStrategy<T> extends CachingStrategy<List<T>> {
  final T Function(Map<String, dynamic> json) _fromJson;
  final Map<String, dynamic> Function(T data) _toJson;
  final Future<List<T>> Function() _fetchFromCloud;

  ListCachingStrategy({
    required super.database,
    required super.cacheKey,
    required super.expiryTimeMs,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T data) toJson,
    required Future<List<T>> Function() fetchFromCloud,
  })  : _fromJson = fromJson,
        _toJson = toJson,
        _fetchFromCloud = fetchFromCloud;

  @override
  Future<void> saveToCache(List<T> data) async {
    final jsonList = data.map((item) => _toJson(item)).toList();
    await _database.setObject(_cacheKey, jsonList);
  }

  @override
  Future<List<T>?> loadFromCache() async {
    // ✅ OPRAVENO: správná konverze List<dynamic> na List<Map<String, dynamic>>
    final jsonList = _database.getObject<List<dynamic>>(
      _cacheKey,
      (data) => data as List<dynamic>,
    );

    if (jsonList == null || jsonList.isEmpty) {
      return null;
    }

    try {
      return jsonList
          .map((item) => _fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading list from cache: $e');
      return null;
    }
  }

  @override
  Future<bool> isCacheValid() async {
    final hasCachedData = _database.containsKey(_cacheKey);
    if (!hasCachedData) {
      return false;
    }

    return !(await isCacheExpired());
  }

  @override
  Future<List<T>> loadFromCloud() async {
    return _fetchFromCloud();
  }
}

/// Tovární třída pro vytváření cachingových strategií.
class CachingStrategyFactory {
  static JsonCachingStrategy<T> createJsonStrategy<T>({
    required LocalDatabase database,
    required String cacheKey,
    required int expiryTimeMs,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T data) toJson,
    required Future<T> Function() fetchFromCloud,
  }) {
    return JsonCachingStrategy<T>(
      database: database,
      cacheKey: cacheKey,
      expiryTimeMs: expiryTimeMs,
      fromJson: fromJson,
      toJson: toJson,
      fetchFromCloud: fetchFromCloud,
    );
  }

  static ListCachingStrategy<T> createListStrategy<T>({
    required LocalDatabase database,
    required String cacheKey,
    required int expiryTimeMs,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T data) toJson,
    required Future<List<T>> Function() fetchFromCloud,
  }) {
    return ListCachingStrategy<T>(
      database: database,
      cacheKey: cacheKey,
      expiryTimeMs: expiryTimeMs,
      fromJson: fromJson,
      toJson: toJson,
      fetchFromCloud: fetchFromCloud,
    );
  }
}
