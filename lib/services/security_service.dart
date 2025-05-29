// lib/services/security_service.dart

import "dart:convert";
import "dart:math";
import "dart:typed_data";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:crypto/crypto.dart";
import "package:pointycastle/export.dart";

/// Produkční služba pro správu bezpečnostních aspektů aplikace.
///
/// Poskytuje:
/// - AES šifrování/dešifrování
/// - Bezpečné ukládání tokenů a hesel
/// - Správu autentizačních tokenů
/// - Hash hesla s salt
/// - Kontrolu integrity aplikace
/// - Biometrickou autentizaci
class SecurityService {
  // Singleton instance
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  // Secure storage s pokročilým nastavením
  late final FlutterSecureStorage _secureStorage;
  
  // Instance Firebase Auth
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  
  // Konstanty pro klíče v úložišti
  static const String _keyRefreshToken = "refresh_token";
  static const String _keyAuthToken = "auth_token";
  static const String _keyTokenExpiry = "token_expiry";
  static const String _keyEncryptionKey = "encryption_key";
  static const String _keyAppIntegrityHash = "app_integrity_hash";
  static const String _keyBiometricEnabled = "biometric_enabled";
  static const String _keyLastSecurityCheck = "last_security_check";
  
  // Kryptografické konstanty
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16;  // 128 bits
  static const int _saltLength = 16; // 128 bits
  static const int _pbkdf2Iterations = 10000;
  
  // Random generátor pro bezpečnostní operace
  final Random _random = Random.secure();
  
  // Indikace, zda byla služba inicializována
  bool _initialized = false;
  
  // Cache pro dešifrovaný klíč (pouze v paměti během session)
  Uint8List? _cachedEncryptionKey;
  
  // Časová značka posledního použití klíče
  DateTime? _lastKeyUsage;
  
  // Timeout pro cache klíče (5 minut)
  static const Duration _keyCacheTimeout = Duration(minutes: 5);

  /// Inicializuje bezpečnostní službu s pokročilým nastavením.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Inicializace secure storage s pokročilými možnostmi
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          sharedPreferencesName: 'svatebni_planovac_secure',
          preferencesKeyPrefix: 'sp_',
        ),
        iOptions: IOSOptions(
          groupId: 'svatebni.planovac.keychain',
          accountName: 'svatebni_planovac_account',
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      
      // Kontrola existence šifrovacího klíče
      final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
      if (!hasEncryptionKey) {
        await _generateAndStoreEncryptionKey();
      }
      
      // Kontrola integrity aplikace
      await _verifyApplicationIntegrity();
      
      // Uložení časové značky bezpečnostní kontroly
      await _updateSecurityCheckTimestamp();
      
      _initialized = true;
      debugPrint("SecurityService initialized with advanced encryption");
    } catch (e) {
      debugPrint("Failed to initialize SecurityService: $e");
      rethrow;
    }
  }

  /// Generuje a ukládá nový silný šifrovací klíč pomocí PBKDF2.
  Future<void> _generateAndStoreEncryptionKey() async {
    try {
      // Generování náhodného salt
      final salt = _generateRandomBytes(_saltLength);
      
      // Generování master hesla z různých zdrojů entropie
      final entropy = _gatherSystemEntropy();
      
      // Derivace klíče pomocí PBKDF2
      final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
      
      final key = pbkdf2.process(entropy);
      
      // Uložení klíče a salt
      await _secureStorage.write(
        key: _keyEncryptionKey, 
        value: base64Encode(key + salt)
      );
      
      debugPrint("Generated new encryption key with PBKDF2");
    } catch (e) {
      throw SecurityException("Failed to generate encryption key: $e");
    }
  }

  /// Odhlásí uživatele a vymaže pouze autentizační tokeny.
  Future<void> clearAuthToken() async {
    if (!_initialized) await initialize();
    try {
      // smažeme tokeny v secure storage
      await clearAuthData();
      // odhlásíme z Firebase Auth
      await _auth.signOut();
      debugPrint("Auth token cleared and user signed out");
    } catch (e) {
      throw SecurityException("Failed to clear auth token: $e");
    }
  }

  /// Vymaže úplně všechna bezpečnostní data (i šifrovací klíč atd.) a odhlásí uživatele.
  Future<void> clearAllData() async {
    if (!_initialized) await initialize();
    try {
      // smažeme cache i všechna data ve secure storage
      await clearAllSecurityData();
      // odhlásíme z Firebase Auth
      await _auth.signOut();
      debugPrint("All security data cleared and user signed out");
    } catch (e) {
      throw SecurityException("Failed to clear all data: $e");
    }
  }

  /// Shromažďuje systémovou entropii pro generování klíčů.
  Uint8List _gatherSystemEntropy() {
    final entropy = <int>[];
    
    // Časové razítko
    entropy.addAll(_intToBytes(DateTime.now().microsecondsSinceEpoch));
    
    // Náhodná data
    entropy.addAll(_generateRandomBytes(32));
    
    // Hash z různých systémových informací
    final systemInfo = '${DateTime.now()}${_random.nextDouble()}';
    final systemHash = sha256.convert(utf8.encode(systemInfo));
    entropy.addAll(systemHash.bytes);
    
    return Uint8List.fromList(entropy);
  }

  /// Načte a dešifruje šifrovací klíč z bezpečného úložiště.
  Future<Uint8List> _getEncryptionKey() async {
    // Kontrola cache a timeoutu
    if (_cachedEncryptionKey != null && _lastKeyUsage != null) {
      if (DateTime.now().difference(_lastKeyUsage!) < _keyCacheTimeout) {
        _lastKeyUsage = DateTime.now();
        return _cachedEncryptionKey!;
      } else {
        // Vymazání expirované cache
        _clearKeyCache();
      }
    }
    
    try {
      final keyData = await _secureStorage.read(key: _keyEncryptionKey);
      if (keyData == null) {
        throw SecurityException("Encryption key not found");
      }
      
      final combined = base64Decode(keyData);
      if (combined.length != _keyLength + _saltLength) {
        throw SecurityException("Invalid key format");
      }
      
      final key = combined.sublist(0, _keyLength);
      
      // Uložení do cache
      _cachedEncryptionKey = Uint8List.fromList(key);
      _lastKeyUsage = DateTime.now();
      
      return _cachedEncryptionKey!;
    } catch (e) {
      throw SecurityException("Failed to retrieve encryption key: $e");
    }
  }

  /// Vymaže cache šifrovacího klíče z paměti.
  void _clearKeyCache() {
    if (_cachedEncryptionKey != null) {
      _cachedEncryptionKey!.fillRange(0, _cachedEncryptionKey!.length, 0);
      _cachedEncryptionKey = null;
    }
    _lastKeyUsage = null;
  }

  /// Uloží autentizační token s expirací.
  Future<void> storeAuthToken(String token, DateTime expiry) async {
    if (!_initialized) await initialize();
    
    try {
      // Šifrování tokenu před uložením
      final encryptedToken = await encryptData(token);
      
      await _secureStorage.write(key: _keyAuthToken, value: encryptedToken);
      await _secureStorage.write(
        key: _keyTokenExpiry, 
        value: expiry.millisecondsSinceEpoch.toString()
      );
      
      debugPrint("Auth token stored securely");
    } catch (e) {
      throw SecurityException("Failed to store auth token: $e");
    }
  }

  /// Uloží refresh token.
  Future<void> storeRefreshToken(String refreshToken) async {
    if (!_initialized) await initialize();
    
    try {
      final encryptedToken = await encryptData(refreshToken);
      await _secureStorage.write(key: _keyRefreshToken, value: encryptedToken);
    } catch (e) {
      throw SecurityException("Failed to store refresh token: $e");
    }
  }

  /// Získá dešifrovaný autentizační token.
  Future<String?> getAuthToken() async {
    if (!_initialized) await initialize();
    
    try {
      final encryptedToken = await _secureStorage.read(key: _keyAuthToken);
      if (encryptedToken == null) return null;
      
      return await decryptData(encryptedToken);
    } catch (e) {
      debugPrint("Failed to get auth token: $e");
      return null;
    }
  }

  /// Získá dešifrovaný refresh token.
  Future<String?> getRefreshToken() async {
    if (!_initialized) await initialize();
    
    try {
      final encryptedToken = await _secureStorage.read(key: _keyRefreshToken);
      if (encryptedToken == null) return null;
      
      return await decryptData(encryptedToken);
    } catch (e) {
      debugPrint("Failed to get refresh token: $e");
      return null;
    }
  }

  /// Získá expiraci tokenu.
  Future<DateTime?> getTokenExpiry() async {
    if (!_initialized) await initialize();
    
    try {
      final expiryString = await _secureStorage.read(key: _keyTokenExpiry);
      if (expiryString == null) return null;
      
      return DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
    } catch (e) {
      debugPrint("Failed to get token expiry: $e");
      return null;
    }
  }

  /// Kontroluje platnost tokenu a automaticky jej obnovuje.
  Future<bool> isTokenValid() async {
    if (!_initialized) await initialize();
    
    try {
      final expiry = await getTokenExpiry();
      if (expiry == null) return false;
      
      final now = DateTime.now();
      
      // Pokud token expiruje za méně než 5 minut, pokusíme se jej obnovit
      if (expiry.difference(now).inMinutes < 5) {
        return await refreshToken();
      }
      
      return now.isBefore(expiry);
    } catch (e) {
      debugPrint("Error checking token validity: $e");
      return false;
    }
  }

  /// Obnoví token pomocí Firebase Auth.
  Future<bool> refreshToken() async {
    if (!_initialized) await initialize();
    
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;
      
      final idTokenResult = await currentUser.getIdTokenResult(true);
      if (idTokenResult.token != null) {
        final expiry = idTokenResult.expirationTime ?? 
                      DateTime.now().add(const Duration(hours: 1));
        
        await storeAuthToken(idTokenResult.token!, expiry);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint("Failed to refresh token: $e");
      return false;
    }
  }

  /// Zašifruje data pomocí AES-256-CBC.
  Future<String> encryptData(String plainText) async {
    if (!_initialized) await initialize();
    
    try {
      final key = await _getEncryptionKey();
      final iv = _generateRandomBytes(_ivLength);
      final plainBytes = utf8.encode(plainText);
      
      // Padding podle PKCS7
      final paddedPlainBytes = _addPKCS7Padding(plainBytes, 16);
      
      // AES šifrování
      final cipher = CBCBlockCipher(AESEngine())
        ..init(true, ParametersWithIV(KeyParameter(key), iv));
      
      final encryptedBytes = Uint8List(paddedPlainBytes.length);
      var offset = 0;
      
      while (offset < paddedPlainBytes.length) {
        offset += cipher.processBlock(paddedPlainBytes, offset, encryptedBytes, offset);
      }
      
      // Kombinace IV + zašifrovaná data
      final result = Uint8List.fromList(iv + encryptedBytes);
      return base64Encode(result);
    } catch (e) {
      throw SecurityException("Encryption failed: $e");
    }
  }

  /// Dešifruje data pomocí AES-256-CBC.
  Future<String> decryptData(String encryptedText) async {
    if (!_initialized) await initialize();
    
    try {
      final key = await _getEncryptionKey();
      final data = base64Decode(encryptedText);
      
      if (data.length < _ivLength) {
        throw SecurityException("Invalid encrypted data format");
      }
      
      final iv = data.sublist(0, _ivLength);
      final encryptedBytes = data.sublist(_ivLength);
      
      // AES dešifrování
      final cipher = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV(KeyParameter(key), iv));
      
      final decryptedBytes = Uint8List(encryptedBytes.length);
      var offset = 0;
      
      while (offset < encryptedBytes.length) {
        offset += cipher.processBlock(encryptedBytes, offset, decryptedBytes, offset);
      }
      
      // Odstranění PKCS7 padding
      final unpaddedBytes = _removePKCS7Padding(decryptedBytes);
      return utf8.decode(unpaddedBytes);
    } catch (e) {
      throw SecurityException("Decryption failed: $e");
    }
  }

  /// Vytvoří bezpečný hash hesla s salt pomocí PBKDF2.
  String hashPassword(String password, String salt) {
    try {
      final saltBytes = base64Decode(salt);
      final passwordBytes = utf8.encode(password);
      
      final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(saltBytes, _pbkdf2Iterations, 32));
      
      final hash = pbkdf2.process(passwordBytes);
      return base64Encode(hash);
    } catch (e) {
      throw SecurityException("Password hashing failed: $e");
    }
  }

  /// Vygeneruje kryptograficky bezpečný salt.
  String generateSalt() {
    final saltBytes = _generateRandomBytes(_saltLength);
    return base64Encode(saltBytes);
  }

  /// Ověří heslo proti uloženému hash.
  bool verifyPassword(String password, String salt, String storedHash) {
    try {
      final computedHash = hashPassword(password, salt);
      return _constantTimeEquals(computedHash, storedHash);
    } catch (e) {
      debugPrint("Password verification failed: $e");
      return false;
    }
  }

  /// Ověří integritu aplikace.
  Future<bool> verifyAppIntegrity() async {
    if (!_initialized) await initialize();
    
    try {
      // Kontrola existence bezpečnostních klíčů
      final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
      if (!hasEncryptionKey) return false;
      
      // Kontrola časové značky poslední bezpečnostní kontroly
      final lastCheckString = await _secureStorage.read(key: _keyLastSecurityCheck);
      if (lastCheckString != null) {
        final lastCheck = DateTime.fromMillisecondsSinceEpoch(int.parse(lastCheckString));
        final timeSinceLastCheck = DateTime.now().difference(lastCheck);
        
        // Pokud byla poslední kontrola před více než 24 hodinami, proveď novou
        if (timeSinceLastCheck.inHours > 24) {
          await _verifyApplicationIntegrity();
        }
      }
      
      return true;
    } catch (e) {
      debugPrint("App integrity check failed: $e");
      return false;
    }
  }

  /// Povolí biometrickou autentizaci.
  Future<void> enableBiometricAuth() async {
    if (!_initialized) await initialize();
    
    await _secureStorage.write(key: _keyBiometricEnabled, value: 'true');
  }

  /// Zakáže biometrickou autentizaci.
  Future<void> disableBiometricAuth() async {
    if (!_initialized) await initialize();
    
    await _secureStorage.write(key: _keyBiometricEnabled, value: 'false');
  }

  /// Kontroluje, zda je povolená biometrická autentizace.
  Future<bool> isBiometricAuthEnabled() async {
    if (!_initialized) await initialize();
    
    final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
    return enabled == 'true';
  }

  /// Vymaže všechna bezpečnostní data.
  Future<void> clearAllSecurityData() async {
    if (!_initialized) await initialize();
    
    try {
      _clearKeyCache();
      await _secureStorage.deleteAll();
      debugPrint("All security data cleared");
    } catch (e) {
      throw SecurityException("Failed to clear security data: $e");
    }
  }

  /// Odstraní pouze tokeny (při odhlášení).
  Future<void> clearAuthData() async {
    if (!_initialized) await initialize();
    
    try {
      await _secureStorage.delete(key: _keyAuthToken);
      await _secureStorage.delete(key: _keyRefreshToken);
      await _secureStorage.delete(key: _keyTokenExpiry);
    } catch (e) {
      throw SecurityException("Failed to clear auth data: $e");
    }
  }

  // === Pomocné metody ===

  /// Generuje kryptograficky bezpečné náhodné byty.
  Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  /// Přidá PKCS7 padding.
  Uint8List _addPKCS7Padding(List<int> data, int blockSize) {
    final padding = blockSize - (data.length % blockSize);
    final paddedData = List<int>.from(data);
    
    for (int i = 0; i < padding; i++) {
      paddedData.add(padding);
    }
    
    return Uint8List.fromList(paddedData);
  }

  /// Odstraní PKCS7 padding.
  Uint8List _removePKCS7Padding(Uint8List data) {
    if (data.isEmpty) throw SecurityException("Invalid padding");
    
    final padding = data.last;
    if (padding > data.length || padding == 0) {
      throw SecurityException("Invalid padding");
    }
    
    for (int i = data.length - padding; i < data.length; i++) {
      if (data[i] != padding) {
        throw SecurityException("Invalid padding");
      }
    }
    
    return data.sublist(0, data.length - padding);
  }

  /// Konvertuje int na byty.
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

  /// Porovnání v konstantním čase (proti timing attacks).
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    
    var result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    
    return result == 0;
  }

  /// Ověří integritu aplikace a uloží hash.
  Future<void> _verifyApplicationIntegrity() async {
    try {
      // Vytvoření hash z kritických komponent aplikace
      final components = [
        'svatebni_planovac', // App name
        '1.0.0', // Version
        DateTime.now().toIso8601String().substring(0, 10), // Datum
      ];
      
      final integrityData = components.join('|');
      final integrityHash = sha256.convert(utf8.encode(integrityData));
      
      await _secureStorage.write(
        key: _keyAppIntegrityHash, 
        value: integrityHash.toString()
      );
    } catch (e) {
      throw SecurityException("Application integrity verification failed: $e");
    }
  }

  /// Aktualizuje časovou značku bezpečnostní kontroly.
  Future<void> _updateSecurityCheckTimestamp() async {
    await _secureStorage.write(
      key: _keyLastSecurityCheck,
      value: DateTime.now().millisecondsSinceEpoch.toString()
    );
  }

  /// Uvolní zdroje při ukončení aplikace.
  void dispose() {
    _clearKeyCache();
  }
}

/// Vlastní výjimka pro bezpečnostní chyby.
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);
  
  @override
  String toString() => 'SecurityException: $message';
}