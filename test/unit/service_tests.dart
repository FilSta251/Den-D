// test/unit/service_tests.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsService Tests', () {
    late FakeAnalyticsService analyticsService;

    setUp(() {
      analyticsService = FakeAnalyticsService();
    });

    test('initialize proběhne úspěšně', () async {
      await analyticsService.initialize();
      expect(analyticsService.isInitialized, isTrue);
    });

    test('logEvent proběhne bez chyby', () async {
      await analyticsService.logEvent(
        name: 'test_event',
        parameters: {'key': 'value'},
      );
      expect(analyticsService.loggedEvents.length, equals(1));
      expect(analyticsService.loggedEvents[0]['name'], equals('test_event'));
    });

    test('setUserId nastaví ID uživatele', () async {
      await analyticsService.setUserId('test_user');
      expect(analyticsService.userId, equals('test_user'));
    });

    test('resetAnalyticsData vyčistí data', () async {
      await analyticsService.logEvent(name: 'event1');
      await analyticsService.setUserId('user1');

      await analyticsService.resetAnalyticsData();

      expect(analyticsService.loggedEvents.isEmpty, isTrue);
      expect(analyticsService.userId, isNull);
    });
  });

  group('LocalStorageService Tests', () {
    late FakeLocalStorageService localStorageService;

    setUp(() {
      localStorageService = FakeLocalStorageService();
    });

    test('saveString a getString fungují správně', () async {
      const key = 'test_key';
      const value = 'test_value';

      await localStorageService.saveString(key, value);
      final result = localStorageService.getString(key);

      expect(result, equals(value));
    });

    test('saveBool a getBool fungují správně', () async {
      const key = 'bool_key';
      const value = true;

      await localStorageService.saveBool(key, value);
      final result = localStorageService.getBool(key);

      expect(result, equals(value));
    });

    test('saveInt a getInt fungují správně', () async {
      const key = 'int_key';
      const value = 42;

      await localStorageService.saveInt(key, value);
      final result = localStorageService.getInt(key);

      expect(result, equals(value));
    });

    test('saveDouble a getDouble fungují správně', () async {
      const key = 'double_key';
      const value = 3.14;

      await localStorageService.saveDouble(key, value);
      final result = localStorageService.getDouble(key);

      expect(result, equals(value));
    });

    test('saveStringList a getStringList fungují správně', () async {
      const key = 'list_key';
      final value = ['jedna', 'dva', 'tři'];

      await localStorageService.saveStringList(key, value);
      final result = localStorageService.getStringList(key);

      expect(result, equals(value));
    });

    test('saveJson a getJson fungují správně', () async {
      const key = 'json_key';
      final jsonObject = {'name': 'test', 'value': 123};

      await localStorageService.saveJson(key, jsonObject);
      final result = localStorageService.getJson(key);

      expect(result, equals(jsonObject));
    });

    test('remove odstraní klíč', () async {
      const key = 'remove_key';

      await localStorageService.saveString(key, 'value');
      await localStorageService.remove(key);
      final result = localStorageService.getString(key);

      expect(result, isNull);
    });

    test('clear odstraní všechny hodnoty', () async {
      await localStorageService.saveString('key1', 'value1');
      await localStorageService.saveString('key2', 'value2');

      await localStorageService.clear();

      expect(localStorageService.getString('key1'), isNull);
      expect(localStorageService.getString('key2'), isNull);
    });

    test('containsKey vrátí true pro existující klíč', () async {
      const key = 'existing_key';

      await localStorageService.saveString(key, 'value');

      expect(localStorageService.containsKey(key), isTrue);
      expect(localStorageService.containsKey('nonexistent'), isFalse);
    });
  });
}

// ============================================================================
// FAKE IMPLEMENTACE PRO TESTY
// ============================================================================

class FakeAnalyticsService {
  bool isInitialized = false;
  String? userId;
  final List<Map<String, dynamic>> loggedEvents = [];

  Future<void> initialize() async {
    isInitialized = true;
  }

  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    loggedEvents.add({
      'name': name,
      'parameters': parameters,
      'timestamp': DateTime.now(),
    });
  }

  Future<void> setUserId(String id) async {
    userId = id;
  }

  Future<void> resetAnalyticsData() async {
    loggedEvents.clear();
    userId = null;
  }
}

class FakeLocalStorageService {
  final Map<String, dynamic> _storage = {};

  Future<void> initialize() async {
    // Inicializace služby
  }

  // String operace
  Future<void> saveString(String key, String value) async {
    _storage[key] = value;
  }

  String? getString(String key) {
    return _storage[key] as String?;
  }

  // Bool operace
  Future<void> saveBool(String key, bool value) async {
    _storage[key] = value;
  }

  bool? getBool(String key) {
    return _storage[key] as bool?;
  }

  // Int operace
  Future<void> saveInt(String key, int value) async {
    _storage[key] = value;
  }

  int? getInt(String key) {
    return _storage[key] as int?;
  }

  // Double operace
  Future<void> saveDouble(String key, double value) async {
    _storage[key] = value;
  }

  double? getDouble(String key) {
    return _storage[key] as double?;
  }

  // StringList operace
  Future<void> saveStringList(String key, List<String> value) async {
    _storage[key] = List<String>.from(value);
  }

  List<String>? getStringList(String key) {
    final value = _storage[key];
    if (value is List) {
      return List<String>.from(value);
    }
    return null;
  }

  // JSON operace
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    _storage[key] = Map<String, dynamic>.from(value);
  }

  Map<String, dynamic>? getJson(String key) {
    final value = _storage[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  // Odstranění
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  // Vyčištění všeho
  Future<void> clear() async {
    _storage.clear();
  }

  // Kontrola existence klíče
  bool containsKey(String key) {
    return _storage.containsKey(key);
  }

  // Získání všech klíčů
  Set<String> getKeys() {
    return _storage.keys.toSet();
  }
}
