import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart'; // Pro debugPrint nebo eventuální logging
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

/// Parametry pro funkci fetchUserProfile
class _FetchUserProfileParams {
  final String userId;
  final FirebaseFirestore firestore;
  
  _FetchUserProfileParams({required this.userId, required this.firestore});
}

/// Parametry pro isolate
class _UpdateUserProfileParams {
  final User user;
  final FirebaseFirestore firestore;
  
  _UpdateUserProfileParams({required this.user, required this.firestore});
}

/// Parametry pro isolate
class _CreateUserProfileParams {
  final User user;
  final FirebaseFirestore firestore;
  
  _CreateUserProfileParams({required this.user, required this.firestore});
}

/// UserRepository zajišťuje:
///  - Načtení a uložení profilu uživatele z/do Firestore
///  - Lokální cachování uživatele
///  - Registraci, přihlášení a odhlášení uživatele
///  - Ukládání a načítání uživatelských dat ze SharedPreferences
///  - Exponenciální retry pro fetchUserProfile (dočasné chyby sítě apod.)
///
/// Poznámka: UID (User ID) je generováno automaticky Firebase Authentication
/// na serveru při registraci nového uživatele. V kódu získáváme UID pomocí
/// `fb.FirebaseAuth.instance.currentUser.uid` a ukládáme jej do modelu [User].
class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  /// Lokální cache pro data uživatele, abychom se vyhnuli zbytečným dotazům.
  User? _cachedUser;

  /// Getter pro již načteného uživatele v paměti.
  User? get cachedUser => _cachedUser;

  UserRepository();

  // ---------------------------------------------------------------------------
  //  FETCH A UPDATE
  // ---------------------------------------------------------------------------

  /// Načte profil uživatele z Firestore podle zadaného [userId].
  /// Při dočasných síťových chybách používá exponenciální backoff s max. 3 pokusy.
  ///
  /// Po úspěšném načtení uloží výsledek i do `_cachedUser`.
  /// Vyvolá [Exception], pokud se po 3 pokusech nepodaří úspěšně načíst profil.
  Future<User> fetchUserProfile({required String userId}) async {
    const int maxAttempts = 3;
    int attempts = 0;

    while (attempts < maxAttempts) {
      try {
        // Použití compute pro přesun náročné operace mimo hlavní vlákno
        final fetchedUser = await compute(
          _fetchUserProfileIsolate, 
          _FetchUserProfileParams(userId: userId, firestore: _firestore)
        );
        
        _cachedUser = fetchedUser;
        return fetchedUser;
      } catch (e, stackTrace) {
        attempts++;
        debugPrint('Chyba při načítání profilu (pokus $attempts): $e\n$stackTrace');

        // Pokud je to poslední pokus, vyhodíme chybu
        if (attempts >= maxAttempts) {
          throw Exception('Nepodařilo se načíst profil uživatele ani po $attempts pokusech: $e\n$stackTrace');
        }

        // Exponenciální backoff
        final delaySeconds = 2 * attempts; // 2, 4, 6
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    // Teoreticky by se sem kód neměl nikdy dostat
    throw Exception('Neznámá chyba při načítání uživatele "$userId". (Max. pokusů překročeno)');
  }
  
  // Statická metoda pro isolate
  static Future<User> _fetchUserProfileIsolate(_FetchUserProfileParams params) async {
    final doc = await params.firestore.collection('users').doc(params.userId).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      // Doplníme ID dokumentu, abychom ho měli přímo v modelu
      data['id'] = doc.id;

      return User.fromJson(data);
    } else {
      throw Exception('Uživatel "${params.userId}" nebyl nalezen ve Firestore.');
    }
  }

  /// Aktualizuje profil uživatele v kolekci `users` na Firestore.
  /// Zároveň upraví `_cachedUser`, pokud update proběhne úspěšně.
  Future<void> updateUserProfile(User user) async {
    try {
      // Použití compute pro přesun náročné operace mimo hlavní vlákno
      await compute(_updateUserProfileIsolate, 
        _UpdateUserProfileParams(user: user, firestore: _firestore));
      
      _cachedUser = user;
    } catch (e, stackTrace) {
      debugPrint('Chyba při aktualizaci profilu: $e\n$stackTrace');
      throw Exception('Chyba při aktualizaci profilu uživatele: $e\n$stackTrace');
    }
  }
  
  // Statická metoda pro isolate
  static Future<void> _updateUserProfileIsolate(_UpdateUserProfileParams params) async {
    await params.firestore.collection('users').doc(params.user.id).update(params.user.toJson());
  }

  /// Vrací [Stream], který poskytuje uživatelský profil v reálném čase
  /// (tj. pokud se data na Firestore změní, dojde k aktualizaci).
  ///
  /// POZOR: Při chybě (např. neexistující dokument) vyvolá [Exception].
  /// Tato metoda vždy nahrazuje `_cachedUser`, pokud snapshot existuje.
  Stream<User> userProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map(
      (snapshot) async {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          data['id'] = snapshot.id;

          // Použití compute pro přesun parsování mimo hlavní vlákno
          final fetchedUser = await compute(_parseUserFromJson, data);
          
          _cachedUser = fetchedUser;
          return fetchedUser;
        } else {
          throw Exception('Uživatel "$userId" nebyl nalezen nebo dokument neexistuje.');
        }
      },
    ).asyncMap((futureUser) => futureUser); // Konvertuje Stream<Future<User>> na Stream<User>
  }
  
  // Statická metoda pro isolate
  static User _parseUserFromJson(Map<String, dynamic> data) {
    return User.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  //  REGISTRACE, PŘIHLÁŠENÍ, ODHLÁŠENÍ
  // ---------------------------------------------------------------------------

  /// Přihlášení pomocí e-mailu a hesla (Firebase Auth).
  /// Po úspěšném signIn načte a vrátí [User] z Firestore, zároveň uloží do `_cachedUser`.
  Future<User> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final fb.User? fbUser = result.user;
      if (fbUser == null) {
        throw Exception("Přihlášení selhalo (UserCredential.user == null).");
      }
      // UID je generováno automaticky Firebase při registraci a je dostupné jako fbUser.uid
      debugPrint('>>> CurrentUser UID: ${fbUser.uid}');
      final loadedUser = await fetchUserProfile(userId: fbUser.uid);
      return loadedUser;
    } catch (e, stackTrace) {
      debugPrint('Chyba při přihlášení: $e\n$stackTrace');
      rethrow;
    }
  }

  /// Registrace nového uživatele pomocí e-mailu a hesla.
  /// Po úspěšné registraci se v `users/{uid}` vytvoří záznam s [User].
  /// Zároveň `_cachedUser` získá novou hodnotu.
  Future<User> signUpWithEmail(
    String email,
    String password, {
    required String name,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final fb.User? fbUser = result.user;
      if (fbUser == null) {
        throw Exception('Registrace selhala (UserCredential.user == null).');
      }

      // UID je generováno automaticky Firebase při registraci
      debugPrint('>>> New User UID: ${fbUser.uid}');

      // Vytvoříme nového uživatele, lze doplnit další pole
      final newUser = User(
        id: fbUser.uid,
        name: name,
        email: email,
        weddingDate: null,
      );

      // Uložíme do Firestore s použitím compute
      await compute(_createUserProfileIsolate, 
        _CreateUserProfileParams(user: newUser, firestore: _firestore));

      // Cache
      _cachedUser = newUser;
      return newUser;
    } catch (e, stackTrace) {
      debugPrint('Chyba při registraci: $e\n$stackTrace');
      rethrow;
    }
  }
  
  // Statická metoda pro isolate
  static Future<void> _createUserProfileIsolate(_CreateUserProfileParams params) async {
    await params.firestore.collection('users').doc(params.user.id).set(params.user.toJson());
  }

  /// Odhlášení uživatele z Firebase Auth i lokální cache.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _cachedUser = null;
    } catch (e, stackTrace) {
      debugPrint('Chyba při odhlašování: $e\n$stackTrace');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  //  LOKÁLNÍ ULOŽENÍ (SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Ukládá uživatelská data do `SharedPreferences` pod klíči:
  ///   - userId, userName, userEmail, userWeddingDate
  ///
  /// Tato metoda neslouží jako bezpečné úložiště, spíše pro dočasný caching.
  Future<void> saveUserLocally(User user) async {
    try {
      // Použití compute pro přesun operace mimo hlavní vlákno
      await compute(_saveUserLocallyIsolate, user);
    } catch (e, stackTrace) {
      debugPrint('Chyba při ukládání lokálních dat: $e\n$stackTrace');
      throw Exception('Chyba při ukládání lokálních dat: $e\n$stackTrace');
    }
  }
  
  // Statická metoda pro isolate
  static Future<void> _saveUserLocallyIsolate(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userId', user.id);
    await prefs.setString('userName', user.name);
    await prefs.setString('userEmail', user.email);
    if (user.weddingDate != null) {
      await prefs.setString('userWeddingDate', user.weddingDate!.toIso8601String());
    }
  }

  /// Načte uživatelská data z `SharedPreferences`. Pokud neexistují, vrací `null`.
  /// Pokud se data naleznou, také je uloží do `_cachedUser`.
  Future<User?> loadUserFromLocal() async {
    try {
      // Použití compute pro přesun operace mimo hlavní vlákno
      final localUser = await compute(_loadUserFromLocalIsolate, null);
      
      if (localUser != null) {
        _cachedUser = localUser;
      }
      
      return localUser;
    } catch (e, stackTrace) {
      debugPrint('Chyba při načítání lokálních dat: $e\n$stackTrace');
      throw Exception('Chyba při načítání lokálních dat: $e\n$stackTrace');
    }
  }
  
  // Statická metoda pro isolate
  static Future<User?> _loadUserFromLocalIsolate(_) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userName = prefs.getString('userName');
    final userEmail = prefs.getString('userEmail');
    final weddingDateStr = prefs.getString('userWeddingDate');

    // Pokud chybí ID, jméno nebo email, považujeme data za neplatná
    if (userId != null && userName != null && userEmail != null) {
      final weddingDate = weddingDateStr != null ? DateTime.tryParse(weddingDateStr) : null;

      return User(
        id: userId,
        name: userName,
        email: userEmail,
        weddingDate: weddingDate,
      );
    }
    return null;
  }

  /// Vymaže lokálně uložená data uživatele (ID, jméno, email, datum).
  /// Zároveň vynuluje `_cachedUser`.
  Future<void> clearLocalData() async {
    try {
      // Použití compute pro přesun operace mimo hlavní vlákno
      await compute(_clearLocalDataIsolate, null);
      _cachedUser = null;
    } catch (e, stackTrace) {
      debugPrint('Chyba při mazání lokálních dat: $e\n$stackTrace');
      throw Exception('Chyba při mazání lokálních dat: $e\n$stackTrace');
    }
  }
  
  // Statická metoda pro isolate
  static Future<void> _clearLocalDataIsolate(_) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userWeddingDate');
  }
}