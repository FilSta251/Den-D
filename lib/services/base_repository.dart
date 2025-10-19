/// lib/services/base_repository.dart
library;

import "dart:async";
import "package:flutter/foundation.dart";
import "package:cloud_firestore/cloud_firestore.dart";
import "../services/connectivity_manager.dart"; // ✅ OPRAVENO: správná cesta
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
  })  : _firestore = firestore,
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

    // ✅ OPRAVENO: správné použití ConnectivityManager API
    _connectivityManager.statusStream.listen((status) {
      if (status.isConnected) {
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

          debugPrint(
              "${_collectionName.toUpperCase()}: Received ${items.length} items from Firestore");
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
      // ✅ OPRAVENO: použití isConnected property
      if (!_connectivityManager.isConnected) {
        debugPrint(
            "${_collectionName.toUpperCase()}: Offline mode, using cached data");
        _setLoading(false);
        return _cachedItems;
      }

      Query<Map<String, dynamic>> query =
          collection.orderBy(orderBy, descending: descending).limit(limit);

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

      debugPrint(
          "${_collectionName.toUpperCase()}: Fetched ${items.length} items");

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

      // ✅ OPRAVENO
      if (!_connectivityManager.isConnected) {
        debugPrint(
            "${_collectionName.toUpperCase()}: Offline mode, item not found in cache");
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
      if (json.containsKey("id") &&
          (json["id"] == null || json["id"].toString().isEmpty)) {
        json.remove("id");
      }

      // Přidání časových razítek, pokud chybí
      if (!json.containsKey("createdAt")) {
        json["createdAt"] = FieldValue.serverTimestamp();
      }
      if (!json.containsKey("updatedAt")) {
        json["updatedAt"] = FieldValue.serverTimestamp();
      }

      // ✅ OPRAVENO: použití addPendingAction správně
      if (!_connectivityManager.isConnected) {
        debugPrint(
            "${_collectionName.toUpperCase()}: Offline mode, scheduling create for later");
        await _connectivityManager.addPendingAction(
          () => create(item),
          description: 'Create item in $_collectionName',
        );
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

      debugPrint(
          "${_collectionName.toUpperCase()}: Created item with ID ${docRef.id}");

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

      // ✅ OPRAVENO
      if (!_connectivityManager.isConnected) {
        debugPrint(
            "${_collectionName.toUpperCase()}: Offline mode, scheduling update for later");
        await _connectivityManager.addPendingAction(
          () => update(item),
          description: 'Update item in $_collectionName',
        );

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
      // ✅ OPRAVENO
      if (!_connectivityManager.isConnected) {
        debugPrint(
            "${_collectionName.toUpperCase()}: Offline mode, scheduling delete for later");
        await _connectivityManager.addPendingAction(
          () => delete(id),
          description: 'Delete item from $_collectionName',
        );

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
