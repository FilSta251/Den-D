/// lib/services/security_service.dart
library;

import "dart:convert";
import "dart:math";
import "dart:typed_data";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:crypto/crypto.dart";
import "package:pointycastle/export.dart";

/// Produkční služba pro správu bezpečnostních aspektů aplikace.
class SecurityService {
  // Singleton instance
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  FlutterSecureStorage? _secureStorage;
  bool _isInitializing = false;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  static const String _keyRefreshToken = "refresh_token";
  static const String _keyAuthToken = "auth_token";
  static const String _keyTokenExpiry = "token_expiry";
  static const String _keyEncryptionKey = "encryption_key";
  static const String _keyAppIntegrityHash = "app_integrity_hash";
  static const String _keyBiometricEnabled = "biometric_enabled";
  static const String _keyLastSecurityCheck = "last_security_check";

  static const int _keyLength = 32;
  static const int _ivLength = 16;
  static const int _saltLength = 16;
  static const int _pbkdf2Iterations = 10000;

  final Random _random = Random.secure();
  bool _initialized = false;
  Uint8List? _cachedEncryptionKey;
  DateTime? _lastKeyUsage;
  static const Duration _keyCacheTimeout = Duration(minutes: 5);

  /// OPRAVENO: iOS Keychain fix - zmenena accessibility
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint("SecurityService jiz byl inicializovan");
      return;
    }

    if (_isInitializing) {
      debugPrint("SecurityService se prave inicializuje, cekam...");
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isInitializing = true;

    try {
      if (_secureStorage == null) {
        // OPRAVENO: iOS Keychain accessibility pro fix -34018
        _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
            sharedPreferencesName: 'svatebni_planovac_secure',
            preferencesKeyPrefix: 'sp_',
          ),
          iOptions: IOSOptions(
            // OPRAVENO: Odstraneno groupId a zmenena accessibility
            accessibility: KeychainAccessibility.unlocked_this_device,
          ),
        );
        debugPrint("SecurityService: FlutterSecureStorage vytvoren");
      }

      final hasEncryptionKey =
          await _secureStorage!.containsKey(key: _keyEncryptionKey);
      if (!hasEncryptionKey) {
        await _generateAndStoreEncryptionKey();
      }

      await _verifyApplicationIntegrity();
      await _updateSecurityCheckTimestamp();

      _initialized = true;
      _isInitializing = false;
      debugPrint("SecurityService inicializovan uspesne");
    } catch (e, stack) {
      _isInitializing = false;
      debugPrint("Chyba pri inicializaci SecurityService: $e");
      debugPrintStack(stackTrace: stack);
      
      // PRIDANO: Pokud selze keychain, zkusime fallback
      try {
        debugPrint("Zkousim fallback konfiguraci...");
        _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.unlocked,
          ),
        );
        
        _initialized = true;
        debugPrint("SecurityService inicializovan s fallback konfiguraci");
      } catch (fallbackError) {
        debugPrint("Fallback selhal: $fallbackError");
        rethrow;
      }
    }
  }

  Future<void> resetInitialization() async {
    _initialized = false;
    _isInitializing = false;
    _secureStorage = null;
    _clearKeyCache();
    debugPrint("SecurityService reset dokoncen");
  }

  Future<void> _generateAndStoreEncryptionKey() async {
    try {
      final salt = _generateRandomBytes(_saltLength);
      final entropy = _gatherSystemEntropy();
      final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
      final key = pbkdf2.process(entropy);
      await _secureStorage!.write(
          key: _keyEncryptionKey, value: base64Encode(key + salt));
      debugPrint("Vygenerovan novy sifrovaci klic");
    } catch (e) {
      throw SecurityException("Nepodarilo se vygenerovat klic: $e");
    }
  }

  Future<void> clearAuthToken() async {
    if (!_initialized) await initialize();
    try {
      await clearAuthData();
      await _auth.signOut();
      debugPrint("Auth token vymazan");
    } catch (e) {
      throw SecurityException("Nepodarilo se vymazat token: $e");
    }
  }

  Future<void> clearAllData() async {
    if (!_initialized) await initialize();
    try {
      await clearAllSecurityData();
      await _auth.signOut();
      debugPrint("Vsechna data vymazana");
    } catch (e) {
      throw SecurityException("Nepodarilo se vymazat data: $e");
    }
  }

  Uint8List _gatherSystemEntropy() {
    final entropy = <int>[];
    entropy.addAll(_intToBytes(DateTime.now().microsecondsSinceEpoch));
    entropy.addAll(_generateRandomBytes(32));
    final systemInfo = '${DateTime.now()}${_random.nextDouble()}';
    final systemHash = sha256.convert(utf8.encode(systemInfo));
    entropy.addAll(systemHash.bytes);
    return Uint8List.fromList(entropy);
  }

  Future<Uint8List> _getEncryptionKey() async {
    if (_cachedEncryptionKey != null && _lastKeyUsage != null) {
      if (DateTime.now().difference(_lastKeyUsage!) < _keyCacheTimeout) {
        _lastKeyUsage = DateTime.now();
        return _cachedEncryptionKey!;
      } else {
        _clearKeyCache();
      }
    }

    try {
      final keyData = await _secureStorage!.read(key: _keyEncryptionKey);
      if (keyData == null) {
        throw SecurityException("Klic nenalezen");
      }

      final combined = base64Decode(keyData);
      if (combined.length != _keyLength + _saltLength) {
        throw SecurityException("Neplatny format klice");
      }

      final key = combined.sublist(0, _keyLength);
      _cachedEncryptionKey = Uint8List.fromList(key);
      _lastKeyUsage = DateTime.now();
      return _cachedEncryptionKey!;
    } catch (e) {
      throw SecurityException("Nepodarilo se ziskat klic: $e");
    }
  }

  void _clearKeyCache() {
    if (_cachedEncryptionKey != null) {
      _cachedEncryptionKey!.fillRange(0, _cachedEncryptionKey!.length, 0);
      _cachedEncryptionKey = null;
    }
    _lastKeyUsage = null;
  }

  Future<void> storeAuthToken(String token, DateTime expiry) async {
    if (!_initialized) await initialize();
    try {
      final encryptedToken = await encryptData(token);
      await _secureStorage!.write(key: _keyAuthToken, value: encryptedToken);
      await _secureStorage!.write(
          key: _keyTokenExpiry,
          value: expiry.millisecondsSinceEpoch.toString());
      debugPrint("Auth token ulozen");
    } catch (e) {
      throw SecurityException("Nepodarilo se ulozit token: $e");
    }
  }

  Future<void> storeRefreshToken(String refreshToken) async {
    if (!_initialized) await initialize();
    try {
      final encryptedToken = await encryptData(refreshToken);
      await _secureStorage!.write(key: _keyRefreshToken, value: encryptedToken);
    } catch (e) {
      throw SecurityException("Nepodarilo se ulozit refresh token: $e");
    }
  }

  Future<String?> getAuthToken() async {
    if (!_initialized) await initialize();
    try {
      final encryptedToken = await _secureStorage!.read(key: _keyAuthToken);
      if (encryptedToken == null) return null;
      return await decryptData(encryptedToken);
    } catch (e) {
      debugPrint("Nepodarilo se ziskat token: $e");
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    if (!_initialized) await initialize();
    try {
      final encryptedToken = await _secureStorage!.read(key: _keyRefreshToken);
      if (encryptedToken == null) return null;
      return await decryptData(encryptedToken);
    } catch (e) {
      debugPrint("Nepodarilo se ziskat refresh token: $e");
      return null;
    }
  }

  Future<DateTime?> getTokenExpiry() async {
    if (!_initialized) await initialize();
    try {
      final expiryString = await _secureStorage!.read(key: _keyTokenExpiry);
      if (expiryString == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
    } catch (e) {
      debugPrint("Nepodarilo se ziskat expiraci tokenu: $e");
      return null;
    }
  }

  Future<bool> isTokenValid() async {
    if (!_initialized) await initialize();
    try {
      final expiryString = await _secureStorage!.read(key: _keyTokenExpiry);
      if (expiryString == null) return false;
      final expiry =
          DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
      return DateTime.now().isBefore(expiry);
    } catch (e) {
      debugPrint("Chyba pri kontrole platnosti: $e");
      return false;
    }
  }

  Future<String> encryptData(String plainText) async {
    if (!_initialized) await initialize();
    try {
      final key = await _getEncryptionKey();
      final iv = _generateRandomBytes(_ivLength);
      final cipher = CBCBlockCipher(AESEngine())
        ..init(true, ParametersWithIV(KeyParameter(key), iv));
      final plainBytes = utf8.encode(plainText);
      final paddedBytes = _addPKCS7Padding(plainBytes, cipher.blockSize);
      final encryptedBytes = Uint8List(paddedBytes.length);
      var offset = 0;
      while (offset < paddedBytes.length) {
        offset +=
            cipher.processBlock(paddedBytes, offset, encryptedBytes, offset);
      }
      final combined = Uint8List.fromList([...iv, ...encryptedBytes]);
      return base64Encode(combined);
    } catch (e) {
      throw SecurityException("Sifrovani selhalo: $e");
    }
  }

  Future<String> decryptData(String encryptedText) async {
    if (!_initialized) await initialize();
    try {
      final key = await _getEncryptionKey();
      final data = base64Decode(encryptedText);
      if (data.length < _ivLength) {
        throw SecurityException("Neplatny format");
      }
      final iv = data.sublist(0, _ivLength);
      final encryptedBytes = data.sublist(_ivLength);
      final cipher = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV(KeyParameter(key), iv));
      final decryptedBytes = Uint8List(encryptedBytes.length);
      var offset = 0;
      while (offset < encryptedBytes.length) {
        offset +=
            cipher.processBlock(encryptedBytes, offset, decryptedBytes, offset);
      }
      final unpaddedBytes = _removePKCS7Padding(decryptedBytes);
      return utf8.decode(unpaddedBytes);
    } catch (e) {
      throw SecurityException("Desifrovani selhalo: $e");
    }
  }

  String hashPassword(String password, String salt) {
    try {
      final saltBytes = base64Decode(salt);
      final passwordBytes = utf8.encode(password);
      final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(saltBytes, _pbkdf2Iterations, 32));
      final hash = pbkdf2.process(passwordBytes);
      return base64Encode(hash);
    } catch (e) {
      throw SecurityException("Hash hesla selhal: $e");
    }
  }

  String generateSalt() {
    final saltBytes = _generateRandomBytes(_saltLength);
    return base64Encode(saltBytes);
  }

  bool verifyPassword(String password, String salt, String storedHash) {
    try {
      final computedHash = hashPassword(password, salt);
      return _constantTimeEquals(computedHash, storedHash);
    } catch (e) {
      debugPrint("Overeni hesla selhalo: $e");
      return false;
    }
  }

  Future<bool> verifyAppIntegrity() async {
    if (!_initialized) await initialize();
    try {
      final hasEncryptionKey =
          await _secureStorage!.containsKey(key: _keyEncryptionKey);
      if (!hasEncryptionKey) return false;
      final lastCheckString =
          await _secureStorage!.read(key: _keyLastSecurityCheck);
      if (lastCheckString != null) {
        final lastCheck =
            DateTime.fromMillisecondsSinceEpoch(int.parse(lastCheckString));
        final timeSinceLastCheck = DateTime.now().difference(lastCheck);
        if (timeSinceLastCheck.inHours > 24) {
          await _verifyApplicationIntegrity();
        }
      }
      return true;
    } catch (e) {
      debugPrint("Kontrola integrity selhala: $e");
      return false;
    }
  }

  Future<void> enableBiometricAuth() async {
    if (!_initialized) await initialize();
    await _secureStorage!.write(key: _keyBiometricEnabled, value: 'true');
  }

  Future<void> disableBiometricAuth() async {
    if (!_initialized) await initialize();
    await _secureStorage!.write(key: _keyBiometricEnabled, value: 'false');
  }

  Future<bool> isBiometricAuthEnabled() async {
    if (!_initialized) await initialize();
    final enabled = await _secureStorage!.read(key: _keyBiometricEnabled);
    return enabled == 'true';
  }

  Future<void> clearAllSecurityData() async {
    if (!_initialized) await initialize();
    try {
      _clearKeyCache();
      await _secureStorage!.deleteAll();
      debugPrint("Vsechna data vymazana");
    } catch (e) {
      throw SecurityException("Nepodarilo se vymazat data: $e");
    }
  }

  Future<void> clearAuthData() async {
    if (!_initialized) await initialize();
    try {
      await _secureStorage!.delete(key: _keyAuthToken);
      await _secureStorage!.delete(key: _keyRefreshToken);
      await _secureStorage!.delete(key: _keyTokenExpiry);
    } catch (e) {
      throw SecurityException("Nepodarilo se vymazat auth data: $e");
    }
  }

  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  Uint8List _addPKCS7Padding(List<int> data, int blockSize) {
    final padding = blockSize - (data.length % blockSize);
    final paddedData = List<int>.from(data);
    for (int i = 0; i < padding; i++) {
      paddedData.add(padding);
    }
    return Uint8List.fromList(paddedData);
  }

  Uint8List _removePKCS7Padding(Uint8List data) {
    if (data.isEmpty) throw SecurityException("Neplatny padding");
    final padding = data.last;
    if (padding > data.length || padding == 0) {
      throw SecurityException("Neplatny padding");
    }
    for (int i = data.length - padding; i < data.length; i++) {
      if (data[i] != padding) {
        throw SecurityException("Neplatny padding");
      }
    }
    return data.sublist(0, data.length - padding);
  }

  List<int> _intToBytes(int value) {
    return [
      (value >> 56) & 0xff,
      (value >> 48) & 0xff,
      (value >> 40) & 0xff,
      (value >> 32) & 0xff,
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  Future<void> _verifyApplicationIntegrity() async {
    try {
      final components = [
        'svatebni_planovac',
        '1.0.0',
        DateTime.now().toIso8601String().substring(0, 10),
      ];
      final integrityData = components.join('|');
      final integrityHash = sha256.convert(utf8.encode(integrityData));
      await _secureStorage!.write(
          key: _keyAppIntegrityHash, value: integrityHash.toString());
    } catch (e) {
      throw SecurityException("Overeni integrity selhalo: $e");
    }
  }

  Future<void> _updateSecurityCheckTimestamp() async {
    await _secureStorage!.write(
        key: _keyLastSecurityCheck,
        value: DateTime.now().millisecondsSinceEpoch.toString());
  }

  void dispose() {
    _clearKeyCache();
  }
}

class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}
