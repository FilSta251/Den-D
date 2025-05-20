# Vytvoření adresářové struktury
mkdir -p test/unit
mkdir -p test/widget
mkdir -p lib/services
mkdir -p lib/utils

# Vytvoření souboru local_database.dart
cat > lib/utils/local_database.dart << 'EOF'
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
EOF
echo "Soubor lib/utils/local_database.dart byl úspěšně vytvořen."

# Vytvoření souboru base_repository.dart
cat > lib/services/base_repository.dart << 'EOF'
// lib/services/base_repository.dart

import "dart:async";
import "package:flutter/foundation.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "../utils/connectivity_manager.dart";
import "../utils/error_handler.dart";

/// Abstraktní třída pro repository pattern.
///
/// Poskytuje základní CRUD operace a zpracování chyb pro práci
/// s Firestore a dalšími úložišti dat.
abstract class BaseRepository<T> {
  // Instance Firestore
  final FirebaseFirestore _firestore;
  
  // Instance ConnectivityManager
  final ConnectivityManager _connectivityManager;
  
  // Instance ErrorHandler
  final ErrorHandler _errorHandler;
  
  // Název kolekce v databázi
  final String _collectionName;
  
  // Streamový kontrolér pro vysílání dat
  final StreamController<List<T>> _itemsStreamController =
      StreamController<List<T>>.broadcast();
  
  // Cache dat
  List<T> _cachedItems = [];
  
  // Poslední čas synchronizace
  DateTime? _lastSyncTime;
  
  // Indikátor, zda probíhá operace
  bool _isLoading = false;
  
  // Stream událostí Firestore
  StreamSubscription? _firestoreSubscription;

  /// Vytvoří novou instanci BaseRepository.
  BaseRepository({
    required FirebaseFirestore firestore,
    required ConnectivityManager connectivityManager,
    required ErrorHandler errorHandler,
    required String collectionName,
  }) : 
    _firestore = firestore,
    _connectivityManager = connectivityManager,
    _errorHandler = errorHandler,
    _collectionName = collectionName;

  /// Stream pro sledování dat.
  Stream<List<T>> get dataStream => _itemsStreamController.stream;
  
  /// Vrací všechny položky v cache.
  List<T> get cachedItems => _cachedItems;
  
  /// Indikátor, zda probíhá načítání.
  bool get isLoading => _isLoading;
  
  /// Poslední čas synchronizace.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Vrací odkaz na kolekci v databázi.
  CollectionReference<Map<String, dynamic>> get collection => 
      _firestore.collection(_collectionName);

  /// Inicializuje repository a nastavuje posluchače.
  Future<void> initialize() async {
    _setupFirestoreListener();
    _connectivityManager.onConnectivityChanged((isOnline) {
      if (isOnline) {
        _refreshData();
      }
    });
  }

  /// Nastaví posluchače změn v databázi.
  void _setupFirestoreListener() {
    _firestoreSubscription?.cancel();
    
    _firestoreSubscription = collection.snapshots().listen(
      (snapshot) {
        try {
          final items = snapshot.docs.map((doc) {
            final data = doc.data();
            if (!data.containsKey("id")) {
              data["id"] = doc.id;
            }
            return fromJson(data);
          }).toList();
          
          _cachedItems = items;
          _lastSyncTime = DateTime.now();
          _itemsStreamController.add(items);
          
          debugPrint("${_collectionName.toUpperCase()}: Received ${items.length} items from Firestore");
        } catch (e, stackTrace) {
          _handleError("Error processing Firestore snapshot", e, stackTrace);
        }
      },
      onError: (error, stackTrace) {
        _handleError("Error listening to Firestore", error, stackTrace);
      },
    );
  }

  /// Konvertuje JSON mapu na objekt.
  T fromJson(Map<String, dynamic> json);
  
  /// Konvertuje objekt na JSON mapu.
  Map<String, dynamic> toJson(T item);
  
  /// Získá ID objektu.
  String getId(T item);

  /// Načte všechny položky z databáze.
  Future<List<T>> fetchAll({
    int limit = 50,
    String orderBy = "createdAt",
    bool descending = true,
  }) async {
    _setLoading(true);
    
    try {
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, using cached data");
        _setLoading(false);
        return _cachedItems;
      }
      
      Query<Map<String, dynamic>> query = collection
          .orderBy(orderBy, descending: descending)
          .limit(limit);
      
      final snapshot = await query.get();
      
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        if (!data.containsKey("id")) {
          data["id"] = doc.id;
        }
        return fromJson(data);
      }).toList();
      
      _cachedItems = items;
      _lastSyncTime = DateTime.now();
      _itemsStreamController.add(items);
      
      debugPrint("${_collectionName.toUpperCase()}: Fetched ${items.length} items");
      
      _setLoading(false);
      return items;
    } catch (e, stackTrace) {
      _handleError("Error fetching items", e, stackTrace);
      _setLoading(false);
      return _cachedItems;
    }
  }

  /// Načte položku podle ID.
  Future<T?> fetchById(String id) async {
    _setLoading(true);
    
    try {
      // Nejprve zkusíme najít v cache
      final cachedItem = _cachedItems.firstWhere(
        (item) => getId(item) == id,
        orElse: () => null as T,
      );
      
      if (cachedItem != null) {
        _setLoading(false);
        return cachedItem;
      }
      
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, item not found in cache");
        _setLoading(false);
        return null;
      }
      
      final docSnapshot = await collection.doc(id).get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        _setLoading(false);
        return null;
      }
      
      final data = docSnapshot.data()!;
      if (!data.containsKey("id")) {
        data["id"] = docSnapshot.id;
      }
      
      final item = fromJson(data);
      
      // Aktualizace cache
      final index = _cachedItems.indexWhere((i) => getId(i) == id);
      if (index >= 0) {
        _cachedItems[index] = item;
      } else {
        _cachedItems.add(item);
      }
      
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Fetched item with ID $id");
      
      _setLoading(false);
      return item;
    } catch (e, stackTrace) {
      _handleError("Error fetching item with ID $id", e, stackTrace);
      _setLoading(false);
      return null;
    }
  }

  /// Vytvoří novou položku v databázi.
  Future<T?> create(T item) async {
    _setLoading(true);
    
    try {
      final json = toJson(item);
      
      // Odstranění ID, pokud je null nebo prázdné
      if (json.containsKey("id") && (json["id"] == null || json["id"].toString().isEmpty)) {
        json.remove("id");
      }
      
      // Přidání časových razítek, pokud chybí
      if (!json.containsKey("createdAt")) {
        json["createdAt"] = FieldValue.serverTimestamp();
      }
      if (!json.containsKey("updatedAt")) {
        json["updatedAt"] = FieldValue.serverTimestamp();
      }
      
      // Pokud jsme offline, uložíme položku do fronty pro pozdější zpracování
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, scheduling create for later");
        _connectivityManager.addPendingAction(() => create(item));
        _setLoading(false);
        return null;
      }
      
      // Vytvoření dokumentu
      final docRef = await collection.add(json);
      
      // Načtení vytvořeného dokumentu
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        _setLoading(false);
        return null;
      }
      
      final data = docSnapshot.data()!;
      data["id"] = docSnapshot.id;
      
      final createdItem = fromJson(data);
      
      // Aktualizace cache
      _cachedItems.add(createdItem);
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Created item with ID ${docRef.id}");
      
      _setLoading(false);
      return createdItem;
    } catch (e, stackTrace) {
      _handleError("Error creating item", e, stackTrace);
      _setLoading(false);
      return null;
    }
  }

  /// Aktualizuje položku v databázi.
  Future<T?> update(T item) async {
    _setLoading(true);
    
    try {
      final id = getId(item);
      final json = toJson(item);
      
      // Přidání časového razítka aktualizace
      json["updatedAt"] = FieldValue.serverTimestamp();
      
      // Pokud jsme offline, uložíme položku do fronty pro pozdější zpracování
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, scheduling update for later");
        _connectivityManager.addPendingAction(() => update(item));
        
        // Aktualizace cache
        final index = _cachedItems.indexWhere((i) => getId(i) == id);
        if (index >= 0) {
          _cachedItems[index] = item;
          _itemsStreamController.add(_cachedItems);
        }
        
        _setLoading(false);
        return item;
      }
      
      // Aktualizace dokumentu
      await collection.doc(id).update(json);
      
      // Načtení aktualizovaného dokumentu
      final docSnapshot = await collection.doc(id).get();
      
      if (!docSnapshot.exists || docSnapshot.data() == null) {
        _setLoading(false);
        return null;
      }
      
      final data = docSnapshot.data()!;
      data["id"] = docSnapshot.id;
      
      final updatedItem = fromJson(data);
      
      // Aktualizace cache
      final index = _cachedItems.indexWhere((i) => getId(i) == id);
      if (index >= 0) {
        _cachedItems[index] = updatedItem;
      } else {
        _cachedItems.add(updatedItem);
      }
      
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Updated item with ID $id");
      
      _setLoading(false);
      return updatedItem;
    } catch (e, stackTrace) {
      _handleError("Error updating item", e, stackTrace);
      _setLoading(false);
      return null;
    }
  }

  /// Odstraní položku z databáze.
  Future<bool> delete(String id) async {
    _setLoading(true);
    
    try {
      // Pokud jsme offline, uložíme požadavek do fronty pro pozdější zpracování
      if (!await _connectivityManager.checkConnectivity()) {
        debugPrint("${_collectionName.toUpperCase()}: Offline mode, scheduling delete for later");
        _connectivityManager.addPendingAction(() => delete(id));
        
        // Aktualizace cache
        _cachedItems.removeWhere((item) => getId(item) == id);
        _itemsStreamController.add(_cachedItems);
        
        _setLoading(false);
        return true;
      }
      
      // Odstranění dokumentu
      await collection.doc(id).delete();
      
      // Aktualizace cache
      _cachedItems.removeWhere((item) => getId(item) == id);
      _itemsStreamController.add(_cachedItems);
      
      debugPrint("${_collectionName.toUpperCase()}: Deleted item with ID $id");
      
      _setLoading(false);
      return true;
    } catch (e, stackTrace) {
      _handleError("Error deleting item with ID $id", e, stackTrace);
      _setLoading(false);
      return false;
    }
  }

  /// Ruční aktualizace dat.
  Future<void> _refreshData() async {
    await fetchAll();
  }
  
  /// Ruční aktualizace dat (veřejná metoda).
  Future<void> refreshData() async {
    await _refreshData();
  }

  /// Nastaví stav načítání.
  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  /// Zpracovává chyby.
  void _handleError(String message, dynamic error, StackTrace stackTrace) {
    debugPrint("${_collectionName.toUpperCase()}: $message: $error");
    debugPrintStack(label: "StackTrace", stackTrace: stackTrace);
    
    _errorHandler.handleError(
      error,
      stackTrace,
      context: _collectionName,
      showToUser: false,
    );
  }

  /// Uvolní zdroje.
  void dispose() {
    _firestoreSubscription?.cancel();
    _itemsStreamController.close();
  }
}
EOF
echo "Soubor lib/services/base_repository.dart byl úspěšně vytvořen."

# Vytvoření testovacího souboru auth_service_test.dart
cat > test/unit/auth_service_test.dart << 'EOF'
// test/unit/auth_service_test.dart

import "package:flutter_test/flutter_test.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart";
import "package:svatebni_planovac/services/auth_service.dart";

import "auth_service_test.mocks.dart";

@GenerateMocks([fb.FirebaseAuth, fb.UserCredential, fb.User])
void main() {
  group("AuthService Tests", () {
    late MockFirebaseAuth mockFirebaseAuth;
    late AuthService authService;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      authService = AuthService();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();

      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn("test-uid");
      when(mockUser.email).thenReturn("test@example.com");
    });

    test("signInWithEmail should return UserCredential when successful", () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: "test@example.com",
        password: "password",
      )).then
      # Pokračování vytvoření testovacího souboru auth_service_test.dart
cat > test/unit/auth_service_test.dart << 'EOF'
// test/unit/auth_service_test.dart

import "package:flutter_test/flutter_test.dart";
import "package:firebase_auth/firebase_auth.dart" as fb;
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart";
import "package:svatebni_planovac/services/auth_service.dart";

import "auth_service_test.mocks.dart";

@GenerateMocks([fb.FirebaseAuth, fb.UserCredential, fb.User])
void main() {
  group("AuthService Tests", () {
    late MockFirebaseAuth mockFirebaseAuth;
    late AuthService authService;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      authService = AuthService();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();

      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn("test-uid");
      when(mockUser.email).thenReturn("test@example.com");
    });

    test("signInWithEmail should return UserCredential when successful", () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: "test@example.com",
        password: "password",
      )).thenAnswer((_) async => mockUserCredential);

      final result = await authService.signInWithEmail("test@example.com", "password");

      expect(result, isNotNull);
      expect(result?.user?.uid, equals("test-uid"));
      expect(result?.user?.email, equals("test@example.com"));
    });

    test("signInWithEmail should throw AuthException when FirebaseAuthException occurs", () async {
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: "test@example.com",
        password: "password",
      )).thenThrow(
        fb.FirebaseAuthException(
          code: "wrong-password",
          message: "The password is invalid",
        ),
      );

      expect(
        () => authService.signInWithEmail("test@example.com", "password"),
        throwsA(isA<AuthException>()),
      );
    });

    test("signOut should sign out from all providers", () async {
      await authService.signOut();
      verify(mockFirebaseAuth.signOut()).called(1);
    });
  });
}
EOF
echo "Soubor test/unit/auth_service_test.dart byl úspěšně vytvořen."

# Vytvoření testovacího souboru login_screen_test.dart
cat > test/widget/login_screen_test.dart << 'EOF'
// test/widget/login_screen_test.dart

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:provider/provider.dart";
import "package:svatebni_planovac/services/auth_service.dart";
import "package:svatebni_planovac/screens/auth_screen.dart";

import "login_screen_test.mocks.dart";

@GenerateMocks([AuthService])
void main() {
 group("Login Screen Tests", () {
   late MockAuthService mockAuthService;

   setUp(() {
     mockAuthService = MockAuthService();
   });

   testWidgets("should display login form elements", (WidgetTester tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     expect(find.text("Přihlásit se"), findsOneWidget);
     expect(find.text("Email"), findsOneWidget);
     expect(find.text("Heslo"), findsOneWidget);
     expect(find.byType(TextFormField), findsAtLeast(2));
     expect(find.byType(ElevatedButton), findsOneWidget);
   });

   testWidgets("should show error on invalid email", (WidgetTester tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     await tester.enterText(find.byType(TextFormField).first, "invalid-email");
     await tester.tap(find.byType(ElevatedButton));
     await tester.pump();

     expect(find.text("Neplatná emailová adresa."), findsOneWidget);
   });

   testWidgets("should show error on empty password", (WidgetTester tester) async {
     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     await tester.enterText(find.byType(TextFormField).first, "test@example.com");
     await tester.tap(find.byType(ElevatedButton));
     await tester.pump();

     expect(find.text("Heslo je povinné"), findsOneWidget);
   });

   testWidgets("should call signInWithEmail on valid form submission", (WidgetTester tester) async {
     when(mockAuthService.signInWithEmail(any, any))
       .thenAnswer((_) async => null);

     await tester.pumpWidget(
       MaterialApp(
         home: Provider<AuthService>.value(
           value: mockAuthService,
           child: const AuthScreen(),
         ),
       ),
     );

     await tester.enterText(find.byType(TextFormField).first, "test@example.com");
     await tester.enterText(find.byType(TextFormField).last, "password123");
     await tester.tap(find.byType(ElevatedButton));
     await tester.pump();

     verify(mockAuthService.signInWithEmail("test@example.com", "password123")).called(1);
   });
 });
}
EOF
echo "Soubor test/widget/login_screen_test.dart byl úspěšně vytvořen."

# Vytvoření souboru caching_strategy.dart
cat > lib/services/caching_strategy.dart << 'EOF'
// lib/services/caching_strategy.dart

import "dart:async";
import "package:flutter/foundation.dart";
import "../utils/local_database.dart";

/// Strategie pro cachování dat v aplikaci.
///
/// Definuje různé přístupy k cachování dat podle typu dat 
/// a frekvence jejich změn.
abstract class CachingStrategy<T> {
 /// Instance LocalDatabase
 final LocalDatabase _database;
 
 /// Klíč pro ukládání do cache
 final String _cacheKey;
 
 /// Čas expirace dat v cache (v ms)
 final int _expiryTimeMs;
 
 CachingStrategy({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
 })  : _database = database,
       _cacheKey = cacheKey,
       _expiryTimeMs = expiryTimeMs;

 /// Ukládá data do cache.
 Future<void> saveToCache(T data);
 
 /// Načítá data z cache.
 Future<T?> loadFromCache();
 
 /// Kontroluje, zda jsou data v cache platná.
 Future<bool> isCacheValid();
 
 /// Načítá data z cloudového zdroje.
 Future<T> loadFromCloud();
 
 /// Vyčistí data v cache.
 Future<void> clearCache() async {
   await _database.removeValue(_cacheKey);
   await _database.removeValue("${_cacheKey}_timestamp");
 }
 
 /// Aktualizuje časové razítko v cache.
 Future<void> updateTimestamp() async {
   final now = DateTime.now().millisecondsSinceEpoch;
   await _database.setValue("${_cacheKey}_timestamp", now);
 }
 
 /// Načítá časové razítko z cache.
 Future<int?> getTimestamp() async {
   return _database.getValue("${_cacheKey}_timestamp") as int?;
 }
 
 /// Kontroluje, zda je cache expirovaná.
 Future<bool> isCacheExpired() async {
   final timestamp = await getTimestamp();
   if (timestamp == null) {
     return true;
   }
   
   final now = DateTime.now().millisecondsSinceEpoch;
   return now - timestamp > _expiryTimeMs;
 }
 
 /// Načítá data z cache nebo z cloudu, podle potřeby.
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
     
     // Pokud dojde k chybě při načítání z cloudu, zkusíme načíst z cache
     // i když je expirovaná
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
 /// Funkce pro konverzi JSON mapy na objekt.
 final T Function(Map<String, dynamic> json) _fromJson;
 
 /// Funkce pro konverzi objektu na JSON mapu.
 final Map<String, dynamic> Function(T data) _toJson;
 
 /// Funkce pro načítání dat z cloudu.
 final Future<T> Function() _fetchFromCloud;

 JsonCachingStrategy({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
   required T Function(Map<String, dynamic> json) fromJson,
   required Map<String, dynamic> Function(T data) toJson,
   required Future<T> Function() fetchFromCloud,
 })  : _fromJson = fromJson,
       _toJson = toJson,
       _fetchFromCloud = fetchFromCloud,
       super(
         database: database,
         cacheKey: cacheKey,
         expiryTimeMs: expiryTimeMs,
       );

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
 /// Funkce pro konverzi JSON mapy na objekt.
 final T Function(Map<String, dynamic> json) _fromJson;
 
 /// Funkce pro konverzi objektu na JSON mapu.
 final Map<String, dynamic> Function(T data) _toJson;
 
 /// Funkce pro načítání dat z cloudu.
 final Future<List<T>> Function() _fetchFromCloud;

 ListCachingStrategy({
   required LocalDatabase database,
   required String cacheKey,
   required int expiryTimeMs,
   required T Function(Map<String, dynamic> json) fromJson,
   required Map<String, dynamic> Function(T data) toJson,
   required Future<List<T>> Function() fetchFromCloud,
 })  : _fromJson = fromJson,
       _toJson = toJson,
       _fetchFromCloud = fetchFromCloud,
       super(
         database: database,
         cacheKey: cacheKey,
         expiryTimeMs: expiryTimeMs,
       );

 @override
 Future<void> saveToCache(List<T> data) async {
   final jsonList = data.map((item) => _toJson(item)).toList();
   await _database.setObject(_cacheKey, jsonList);
 }

 @override
 Future<List<T>?> loadFromCache() async {
   final jsonList = _database.getObject<List<dynamic>>(
     _cacheKey,
     (json) => json,
   );
   
   if (jsonList == null) {
     return null;
   }
   
   return jsonList
       .cast<Map<String, dynamic>>()
       .map((json) => _fromJson(json))
       .toList();
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
EOF
echo "Soubor lib/services/caching_strategy.dart byl úspěšně vytvořen."

# Vytvoření souboru .env.example
cat > .env.example << 'EOF'
# API klíče
FIREBASE_API_KEY=
FIREBASE_APP_ID=
FIREBASE_PROJECT_ID=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_STORAGE_BUCKET=

# Konfigurace aplikace
APP_ENVIRONMENT=development
API_URL=https://api.example.com
ENABLE_ANALYTICS=false
ENABLE_CRASHLYTICS=false
EOF
echo "Soubor .env.example byl úspěšně vytvořen."

# Vytvoření souboru README.md
cat > README.md << 'EOF'
# Svatební Plánovač - Produkční nasazení

Tento dokument obsahuje pokyny pro nastavení a nasazení aplikace do produkčního prostředí.

## Příprava prostředí

1. Vytvořte `.env` soubor podle šablony `.env.example`:
```bash
cp .env.example .env