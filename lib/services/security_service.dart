// lib/services/security_service.dart

import "dart:convert";
import "dart:math";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:crypto/crypto.dart";

/// Služba pro správu bezpečnostních aspektů aplikace.
///
/// Řeší ukládání citlivých informací, práci s tokeny, šifrování dat,
/// a další bezpečnostní funkce.
class SecurityService {
 // Singleton instance
 static final SecurityService _instance = SecurityService._internal();
 factory SecurityService() => _instance;
 SecurityService._internal();

 // Secure storage pro bezpečné uchovávání citlivých dat
 final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
 
 // Instance Firebase Auth
 final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
 
 // Konstanty pro klíče v úložišti
 static const String _keyRefreshToken = "refresh_token";
 static const String _keyAuthToken = "auth_token";
 static const String _keyTokenExpiry = "token_expiry";
 static const String _keyEncryptionKey = "encryption_key";
 
 // Random generátor pro bezpečnostní operace
 final Random _random = Random.secure();
 
 // Indikace, zda byla služba inicializována
 bool _initialized = false;

 /// Inicializuje bezpečnostní službu.
 Future<void> initialize() async {
   if (_initialized) return;
   
   try {
     // Kontrola existence šifrovacího klíče, případně jeho vytvoření
     final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
     if (!hasEncryptionKey) {
       await _generateAndStoreEncryptionKey();
     }
     
     _initialized = true;
     debugPrint("SecurityService initialized");
   } catch (e) {
     debugPrint("Failed to initialize SecurityService: $e");
     rethrow;
   }
 }

 /// Generuje a ukládá nový šifrovací klíč.
 Future<void> _generateAndStoreEncryptionKey() async {
   final key = List<int>.generate(32, (_) => _random.nextInt(256));
   final keyBase64 = base64Encode(key);
   await _secureStorage.write(key: _keyEncryptionKey, value: keyBase64);
 }

 /// Načte šifrovací klíč z bezpečného úložiště.
 Future<List<int>> _getEncryptionKey() async {
   final keyBase64 = await _secureStorage.read(key: _keyEncryptionKey);
   if (keyBase64 == null) {
     throw Exception("Encryption key not found");
   }
   return base64Decode(keyBase64);
 }

 /// Uloží token a související data.
 Future<void> storeAuthToken(String token, DateTime expiry) async {
   if (!_initialized) await initialize();
   
   await _secureStorage.write(key: _keyAuthToken, value: token);
   await _secureStorage.write(
     key: _keyTokenExpiry, 
     value: expiry.millisecondsSinceEpoch.toString()
   );
 }

 /// Uloží refresh token.
 Future<void> storeRefreshToken(String refreshToken) async {
   if (!_initialized) await initialize();
   
   await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
 }

 /// Získá uložený autentizační token.
 Future<String?> getAuthToken() async {
   if (!_initialized) await initialize();
   
   return _secureStorage.read(key: _keyAuthToken);
 }

 /// Získá uložený refresh token.
 Future<String?> getRefreshToken() async {
   if (!_initialized) await initialize();
   
   return _secureStorage.read(key: _keyRefreshToken);
 }

 /// Kontroluje, zda je token platný (neexpirovaný).
 Future<bool> isTokenValid() async {
   if (!_initialized) await initialize();
   
   final expiryString = await _secureStorage.read(key: _keyTokenExpiry);
   if (expiryString == null) return false;
   
   final expiry = DateTime.fromMillisecondsSinceEpoch(int.parse(expiryString));
   final now = DateTime.now();
   
   return now.isBefore(expiry);
 }

 /// Obnoví token pomocí refresh tokenu.
 /// 
 /// Tato metoda by měla být volána, když je potřeba obnovit expirovaný token.
 Future<bool> refreshToken() async {
   if (!_initialized) await initialize();
   
   try {
     // Zde bychom implementovali obnovu tokenu pomocí Firebase Auth
     // nebo jiného autentizačního systému
     
     // Zjednodušená implementace pro Firebase Auth
     final currentUser = _auth.currentUser;
     if (currentUser == null) return false;
     
     final idTokenResult = await currentUser.getIdTokenResult(true);
     if (idTokenResult.token != null) {
       final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
       await storeAuthToken(idTokenResult.token!, expiry);
       return true;
     }
     
     return false;
   } catch (e) {
     debugPrint("Failed to refresh token: $e");
     return false;
   }
 }

 /// Odstraní všechny uložené tokeny a bezpečnostní data.
 Future<void> clearSecurityData() async {
   if (!_initialized) await initialize();
   
   await _secureStorage.delete(key: _keyAuthToken);
   await _secureStorage.delete(key: _keyRefreshToken);
   await _secureStorage.delete(key: _keyTokenExpiry);
   // Ponecháme šifrovací klíč pro případné zašifrované soubory
 }

 /// Zašifruje data pomocí bezpečného klíče.
 Future<String> encryptData(String plainText) async {
   if (!_initialized) await initialize();
   
   // Zjednodušená implementace šifrování - v produkci použijte silnější algoritmus
   final key = await _getEncryptionKey();
   final contentBytes = utf8.encode(plainText);
   final iv = List<int>.generate(16, (_) => _random.nextInt(256));
   
   // Toto je pouze zjednodušená demonstrace - v reálu použijte AES nebo jiný algoritmus
   final encryptedBytes = List<int>.from(contentBytes);
   for (int i = 0; i < encryptedBytes.length; i++) {
     encryptedBytes[i] = encryptedBytes[i] ^ key[i % key.length];
   }
   
   // Kombinace IV a zašifrovaných dat
   final result = iv + encryptedBytes;
   return base64Encode(result);
 }

 /// Dešifruje zašifrovaná data.
 Future<String> decryptData(String encryptedText) async {
   if (!_initialized) await initialize();
   
   try {
     final key = await _getEncryptionKey();
     final data = base64Decode(encryptedText);
     
     if (data.length < 16) {
       throw Exception("Invalid encrypted data format");
     }
     
     // Oddělení IV a zašifrovaných dat
     final iv = data.sublist(
     /// Dešifruje zašifrovaná data.
 Future<String> decryptData(String encryptedText) async {
   if (!_initialized) await initialize();
   
   try {
     final key = await _getEncryptionKey();
     final data = base64Decode(encryptedText);
     
     if (data.length < 16) {
       throw Exception("Invalid encrypted data format");
     }
     
     // Oddělení IV a zašifrovaných dat
     final iv = data.sublist(0, 16);
     final encryptedBytes = data.sublist(16);
     
     // Zjednodušená implementace dešifrování - v produkci použijte silnější algoritmus
     final decryptedBytes = List<int>.from(encryptedBytes);
     for (int i = 0; i < decryptedBytes.length; i++) {
       decryptedBytes[i] = decryptedBytes[i] ^ key[i % key.length];
     }
     
     return utf8.decode(decryptedBytes);
   } catch (e) {
     debugPrint("Failed to decrypt data: $e");
     throw Exception("Decryption failed");
   }
 }

 /// Vytvoří hash z hesla pro bezpečné porovnání nebo ukládání.
 String hashPassword(String password, String salt) {
   final bytes = utf8.encode(password + salt);
   final digest = sha256.convert(bytes);
   return digest.toString();
 }

 /// Vygeneruje bezpečný salt pro hashování.
 String generateSalt() {
   final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
   return base64Encode(bytes);
 }

 /// Ověří integrity aplikace a bezpečnostních prvků.
 Future<bool> verifyAppIntegrity() async {
   if (!_initialized) await initialize();
   
   try {
     // Zde by byla implementace kontroly integrity aplikace
     // Například kontrola podpisu, detekce root/jailbreak, apod.
     
     // Zjednodušená implementace pro ukázku
     final hasEncryptionKey = await _secureStorage.containsKey(key: _keyEncryptionKey);
     return hasEncryptionKey;
   } catch (e) {
     debugPrint("App integrity check failed: $e");
     return false;
   }
 }
}
