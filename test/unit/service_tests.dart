import 'package:flutter_test/flutter_test.dart';
import 'package:svatebni_planovac/services/analytics_service.dart';
import 'package:svatebni_planovac/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsService Tests', () {
    final analyticsService = AnalyticsService();

    test('initialize completes successfully', () async {
      // Testujeme, zda inicializace služby proběhne bez chyb
      await analyticsService.initialize();
      // Pokud by došlo k chybě, test selže.
    });

    test('logEvent completes without error', () async {
      // Testujeme logování události
      await analyticsService.logEvent(name: 'test_event', parameters: {'key': 'value'});
    });

    test('setUserId completes without error', () async {
      // Test nastavování uživatelského ID
      await analyticsService.setUserId('test_user');
    });

    test('resetAnalyticsData completes without error', () async {
      // Test resetu analytických dat (užitečné pro testovací účely)
      await analyticsService.resetAnalyticsData();
    });
  });

  group('LocalStorageService Tests', () {
    final localStorageService = LocalStorageService();

    setUp(() async {
      // Nastavíme počáteční hodnoty pro SharedPreferences (pro testování)
      SharedPreferences.setMockInitialValues({});
      await localStorageService.initialize();
    });

    test('saveString and getString work correctly', () async {
      const key = 'test_key';
      const value = 'test_value';
      await localStorageService.saveString(key, value);
      final result = localStorageService.getString(key);
      expect(result, equals(value));
    });

    test('saveBool and getBool work correctly', () async {
      const key = 'bool_key';
      const value = true;
      await localStorageService.saveBool(key, value);
      final result = localStorageService.getBool(key);
      expect(result, equals(value));
    });

    test('saveInt and getInt work correctly', () async {
      const key = 'int_key';
      const value = 42;
      await localStorageService.saveInt(key, value);
      final result = localStorageService.getInt(key);
      expect(result, equals(value));
    });

    test('saveDouble and getDouble work correctly', () async {
      const key = 'double_key';
      const value = 3.14;
      await localStorageService.saveDouble(key, value);
      final result = localStorageService.getDouble(key);
      expect(result, equals(value));
    });

    test('saveStringList and getStringList work correctly', () async {
      const key = 'list_key';
      final value = ['one', 'two', 'three'];
      await localStorageService.saveStringList(key, value);
      final result = localStorageService.getStringList(key);
      expect(result, equals(value));
    });

    test('saveJson and getJson work correctly', () async {
      const key = 'json_key';
      final jsonObject = {'name': 'test', 'value': 123};
      await localStorageService.saveJson(key, jsonObject);
      final result = localStorageService.getJson(key);
      expect(result, equals(jsonObject));
    });

    test('remove deletes the key', () async {
      const key = 'remove_key';
      await localStorageService.saveString(key, 'value');
      await localStorageService.remove(key);
      final result = localStorageService.getString(key);
      expect(result, isNull);
    });

    test('clear removes all values', () async {
      await localStorageService.saveString('key1', 'value1');
      await localStorageService.saveString('key2', 'value2');
      await localStorageService.clear();
      expect(localStorageService.getString('key1'), isNull);
      expect(localStorageService.getString('key2'), isNull);
    });
  });
}
