import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../utils/logger.dart'; // Import vašeho loggeru

/// Výjimky pro UserRepository
class UserRepositoryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  UserRepositoryException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'UserRepositoryException: $message';
}

class UserValidationException extends UserRepositoryException {
  UserValidationException(super.message) : super(code: 'VALIDATION_ERROR');
}

class UserNotFoundException extends UserRepositoryException {
  UserNotFoundException(String userId)
      : super('Uživatel "$userId" nebyl nalezen', code: 'USER_NOT_FOUND');
}

class NetworkException extends UserRepositoryException {
  NetworkException(super.message, {super.originalError})
      : super(code: 'NETWORK_ERROR');
}

/// Parametry pro isolate funkce
class _FetchUserProfileParams {
  final String userId;
  final FirebaseFirestore firestore;
  final Source source;

  _FetchUserProfileParams({
    required this.userId,
    required this.firestore,
    this.source = Source.serverAndCache,
  });
}

class _UpdateUserProfileParams {
  final User user;
  final FirebaseFirestore firestore;
  final bool merge;

  _UpdateUserProfileParams({
    required this.user,
    required this.firestore,
    this.merge = true,
  });
}

class _CreateUserProfileParams {
  final User user;
  final FirebaseFirestore firestore;

  _CreateUserProfileParams({required this.user, required this.firestore});
}

class _BatchUpdateParams {
  final List<User> users;
  final FirebaseFirestore firestore;

  _BatchUpdateParams({required this.users, required this.firestore});
}

/// Validátor pro uživatelská data
class UserValidator {
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const String emailRegex =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  /// Validuje celý User objekt
  static void validateUser(User user) {
    validateUserId(user.id);
    validateName(user.name);
    validateEmail(user.email);
    if (user.weddingDate != null) {
      validateWeddingDate(user.weddingDate!);
    }
  }

  /// Validuje User ID
  static void validateUserId(String userId) {
    if (userId.isEmpty) {
      throw UserValidationException('User ID nesmí být prázdné');
    }
    if (userId.length < 10) {
      throw UserValidationException('User ID má neplatný formát');
    }
  }

  /// Validuje jméno uživatele
  static void validateName(String name) {
    if (name.trim().isEmpty) {
      throw UserValidationException('Jméno nesmí být prázdné');
    }
    if (name.trim().length < minNameLength) {
      throw UserValidationException(
          'Jméno musí mít alespoň $minNameLength znaky');
    }
    if (name.length > maxNameLength) {
      throw UserValidationException(
          'Jméno nesmí být delší než $maxNameLength znaků');
    }
    if (!RegExp(r'^[a-žA-Ž\s]+$', unicode: true).hasMatch(name.trim())) {
      throw UserValidationException(
          'Jméno smí obsahovat pouze písmena a mezery');
    }
  }

  /// Validuje email
  static void validateEmail(String email) {
    if (email.trim().isEmpty) {
      throw UserValidationException('Email nesmí být prázdný');
    }
    if (!RegExp(emailRegex).hasMatch(email.trim())) {
      throw UserValidationException('Email má neplatný formát');
    }
  }

  /// Validuje datum svatby
  static void validateWeddingDate(DateTime weddingDate) {
    final now = DateTime.now();
    final minDate = DateTime(1900);
    final maxDate = DateTime(now.year + 10);

    if (weddingDate.isBefore(minDate)) {
      throw UserValidationException('Datum svatby je příliš staré');
    }
    if (weddingDate.isAfter(maxDate)) {
      throw UserValidationException('Datum svatby je příliš vzdálené');
    }
  }

  /// Validuje heslo
  static void validatePassword(String password) {
    if (password.length < 8) {
      throw UserValidationException('Heslo musí mít alespoň 8 znaků');
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      throw UserValidationException(
          'Heslo musí obsahovat malé písmeno, velké písmeno a číslo');
    }
  }
}

/// Optimalizovaný UserRepository s validací dat a lepším error handlingem
class UserRepository {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  final Logger _logger = Logger();

  /// Lokální cache s TTL
  User? _cachedUser;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Query optimalizace
  late final CollectionReference<Map<String, dynamic>> _usersCollection;

  /// Stream controllery pro real-time updates
  final Map<String, StreamController<User>> _userStreams = {};

  /// Rate limiting
  DateTime? _lastFetchTime;
  static const Duration _minFetchInterval = Duration(seconds: 1);

  UserRepository({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? fb.FirebaseAuth.instance {
    _usersCollection = _firestore.collection('users');

    // Nastavení persistence pro offline podporu
    _firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    _logger.info('UserRepository initialized', category: 'user_repository');
  }

  /// Getter pro cached uživatele s TTL kontrolou
  User? get cachedUser {
    if (_cachedUser != null && _cacheTimestamp != null) {
      final isExpired =
          DateTime.now().difference(_cacheTimestamp!) > _cacheTimeout;
      if (isExpired) {
        _logger.debug('Cache expired, clearing cached user',
            category: 'user_repository');
        _cachedUser = null;
        _cacheTimestamp = null;
      }
    }
    return _cachedUser;
  }

  /// Kontrola zda je cache platná
  bool get isCacheValid {
    return _cachedUser != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) <= _cacheTimeout;
  }

  // ---------------------------------------------------------------------------
  //  FETCH A UPDATE s optimalizacemi
  // ---------------------------------------------------------------------------

  /// Optimalizované načtení profilu s cache, rate limiting a retry
  Future<User> fetchUserProfile({
    required String userId,
    bool forceRefresh = false,
    Source source = Source.serverAndCache,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      UserValidator.validateUserId(userId);

      // Rate limiting check
      if (_lastFetchTime != null && !forceRefresh) {
        final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
        if (timeSinceLastFetch < _minFetchInterval) {
          _logger.debug('Rate limited, using cache',
              category: 'user_repository');
          if (cachedUser?.id == userId) {
            return cachedUser!;
          }
        }
      }

      // Cache check
      if (!forceRefresh && isCacheValid && cachedUser?.id == userId) {
        _logger.debug('Returning cached user',
            category: 'user_repository', extra: {'userId': userId});
        return cachedUser!;
      }

      _logger
          .info('Fetching user profile', category: 'user_repository', extra: {
        'userId': userId,
        'source': source.toString(),
        'forceRefresh': forceRefresh,
      });

      const int maxAttempts = 3;
      int attempts = 0;

      while (attempts < maxAttempts) {
        try {
          final fetchedUser = await compute(
            _fetchUserProfileIsolate,
            _FetchUserProfileParams(
              userId: userId,
              firestore: _firestore,
              source: source,
            ),
          );

          UserValidator.validateUser(fetchedUser);

          _cachedUser = fetchedUser;
          _cacheTimestamp = DateTime.now();
          _lastFetchTime = DateTime.now();

          _logger.performance(
            'fetchUserProfile',
            stopwatch.elapsed,
            category: 'user_repository',
            extra: {'userId': userId, 'attempts': attempts + 1},
          );

          return fetchedUser;
        } catch (e) {
          attempts++;

          if (e is UserValidationException) {
            _logger.error('User validation failed',
                category: 'user_repository',
                exception: e,
                extra: {'userId': userId});
            rethrow;
          }

          _logger.warning('Fetch attempt $attempts failed',
              category: 'user_repository',
              exception: e,
              extra: {'userId': userId, 'attempt': attempts});

          if (attempts >= maxAttempts) {
            throw NetworkException(
              'Nepodařilo se načíst profil uživatele ani po $attempts pokusech',
              originalError: e,
            );
          }

          // Exponenciální backoff s jitter
          final baseDelay = 1000 * (1 << (attempts - 1)); // 1s, 2s, 4s
          final jitter = (baseDelay *
                  0.1 *
                  (DateTime.now().millisecondsSinceEpoch % 1000 - 500) /
                  500)
              .round();
          final delay = Duration(milliseconds: baseDelay + jitter);

          await Future.delayed(delay);
        }
      }

      throw NetworkException('Neznámá chyba při načítání uživatele');
    } catch (e) {
      _logger.error('Failed to fetch user profile',
          category: 'user_repository', exception: e, extra: {'userId': userId});
      rethrow;
    }
  }

  /// Optimalizovaná statická metoda pro isolate
  static Future<User> _fetchUserProfileIsolate(
      _FetchUserProfileParams params) async {
    try {
      final doc = await params.firestore
          .collection('users')
          .doc(params.userId)
          .get(GetOptions(source: params.source));

      if (!doc.exists || doc.data() == null) {
        throw UserNotFoundException(params.userId);
      }

      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;

      // Přidání metadata
      data['_fetchedAt'] = DateTime.now().toIso8601String();
      data['_fromCache'] = doc.metadata.isFromCache;

      return User.fromJson(data);
    } catch (e) {
      if (e is UserNotFoundException) rethrow;
      throw NetworkException('Chyba při načítání z Firestore',
          originalError: e);
    }
  }

  /// Optimalizovaná aktualizace s validací a retry
  Future<void> updateUserProfile(
    User user, {
    bool merge = true,
    List<String>? fieldsToUpdate,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      UserValidator.validateUser(user);

      _logger
          .info('Updating user profile', category: 'user_repository', extra: {
        'userId': user.id,
        'merge': merge,
        'fieldsToUpdate': fieldsToUpdate,
      });

      final params = _UpdateUserProfileParams(
        user: user,
        firestore: _firestore,
        merge: merge,
      );

      await compute(_updateUserProfileIsolate, params);

      // Aktualizovat cache pouze pokud je to stejný uživatel
      if (_cachedUser?.id == user.id) {
        _cachedUser = user;
        _cacheTimestamp = DateTime.now();
      }

      _logger.performance(
        'updateUserProfile',
        stopwatch.elapsed,
        category: 'user_repository',
        extra: {'userId': user.id},
      );
    } catch (e) {
      _logger.error('Failed to update user profile',
          category: 'user_repository',
          exception: e,
          extra: {'userId': user.id});

      if (e is UserValidationException) {
        rethrow;
      }
      throw NetworkException('Chyba při aktualizaci profilu uživatele',
          originalError: e);
    }
  }

  static Future<void> _updateUserProfileIsolate(
      _UpdateUserProfileParams params) async {
    try {
      final data = params.user.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (params.merge) {
        await params.firestore
            .collection('users')
            .doc(params.user.id)
            .set(data, SetOptions(merge: true));
      } else {
        await params.firestore
            .collection('users')
            .doc(params.user.id)
            .update(data);
      }
    } catch (e) {
      throw NetworkException('Chyba při zápisu do Firestore', originalError: e);
    }
  }

  /// Batch aktualizace více uživatelů
  Future<void> updateUsersProfilesBatch(List<User> users) async {
    if (users.isEmpty) return;

    final stopwatch = Stopwatch()..start();

    try {
      for (final user in users) {
        UserValidator.validateUser(user);
      }

      _logger.info('Batch updating user profiles',
          category: 'user_repository',
          extra: {
            'userCount': users.length,
          });

      await compute(_batchUpdateIsolate,
          _BatchUpdateParams(users: users, firestore: _firestore));

      _logger.performance(
        'updateUsersProfilesBatch',
        stopwatch.elapsed,
        category: 'user_repository',
        extra: {'userCount': users.length},
      );
    } catch (e) {
      _logger.error('Failed to batch update user profiles',
          category: 'user_repository',
          exception: e,
          extra: {'userCount': users.length});
      throw NetworkException('Chyba při batch aktualizaci', originalError: e);
    }
  }

  static Future<void> _batchUpdateIsolate(_BatchUpdateParams params) async {
    final batch = params.firestore.batch();

    for (final user in params.users) {
      final data = user.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = params.firestore.collection('users').doc(user.id);
      batch.set(docRef, data, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Optimalizovaný real-time stream s error handling
  Stream<User> userProfileStream(String userId) {
    try {
      UserValidator.validateUserId(userId);

      // Reuse existing stream if available
      if (_userStreams.containsKey(userId)) {
        return _userStreams[userId]!.stream;
      }

      _logger.info('Creating user profile stream',
          category: 'user_repository',
          extra: {
            'userId': userId,
          });

      final controller = StreamController<User>.broadcast(
        onCancel: () {
          _userStreams.remove(userId);
          _logger.debug('User stream cancelled',
              category: 'user_repository', extra: {'userId': userId});
        },
      );

      _userStreams[userId] = controller;

      _usersCollection.doc(userId).snapshots().listen(
        (snapshot) async {
          try {
            if (!snapshot.exists || snapshot.data() == null) {
              controller.addError(UserNotFoundException(userId));
              return;
            }

            final data = Map<String, dynamic>.from(snapshot.data()!);
            data['id'] = snapshot.id;
            data['_fromCache'] = snapshot.metadata.isFromCache;

            final user = await compute(_parseUserFromJson, data);
            UserValidator.validateUser(user);

            // Update cache if it's the same user
            if (_cachedUser?.id == userId) {
              _cachedUser = user;
              _cacheTimestamp = DateTime.now();
            }

            controller.add(user);
          } catch (e) {
            _logger.error('Error in user stream',
                category: 'user_repository',
                exception: e,
                extra: {'userId': userId});
            controller.addError(e);
          }
        },
        onError: (error) {
          _logger.error('User stream error',
              category: 'user_repository',
              exception: error,
              extra: {'userId': userId});
          controller.addError(NetworkException('Chyba v real-time streamu',
              originalError: error));
        },
      );

      return controller.stream;
    } catch (e) {
      _logger.error('Failed to create user stream',
          category: 'user_repository', exception: e, extra: {'userId': userId});
      rethrow;
    }
  }

  static User _parseUserFromJson(Map<String, dynamic> data) {
    return User.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  //  REGISTRACE, PŘIHLÁŠENÍ, ODHLÁŠENÍ s validací
  // ---------------------------------------------------------------------------

  /// Optimalizované přihlášení s validací
  Future<User> signInWithEmail(String email, String password) async {
    final stopwatch = Stopwatch()..start();

    try {
      UserValidator.validateEmail(email);
      UserValidator.validatePassword(password);

      _logger.info('Signing in user', category: 'user_repository', extra: {
        'email': email.trim(),
      });

      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final fbUser = result.user;
      if (fbUser == null) {
        throw UserRepositoryException(
            "Přihlášení selhalo (UserCredential.user == null).");
      }

      _logger.info('Firebase auth successful',
          category: 'user_repository',
          extra: {
            'uid': fbUser.uid,
          });

      final loadedUser =
          await fetchUserProfile(userId: fbUser.uid, forceRefresh: true);

      _logger.performance(
        'signInWithEmail',
        stopwatch.elapsed,
        category: 'user_repository',
      );

      _logger.userAction('sign_in', extra: {'method': 'email'});

      return loadedUser;
    } catch (e) {
      _logger.error('Sign in failed',
          category: 'user_repository',
          exception: e,
          extra: {'email': email.trim()});
      rethrow;
    }
  }

  /// Optimalizovaná registrace s validací
  Future<User> signUpWithEmail(
    String email,
    String password, {
    required String name,
    DateTime? weddingDate,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      UserValidator.validateEmail(email);
      UserValidator.validatePassword(password);
      UserValidator.validateName(name);
      if (weddingDate != null) {
        UserValidator.validateWeddingDate(weddingDate);
      }

      _logger.info('Signing up new user', category: 'user_repository', extra: {
        'email': email.trim(),
        'name': name.trim(),
      });

      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final fbUser = result.user;
      if (fbUser == null) {
        throw UserRepositoryException(
            'Registrace selhala (UserCredential.user == null).');
      }

      _logger.info('Firebase auth registration successful',
          category: 'user_repository',
          extra: {
            'uid': fbUser.uid,
          });

      final newUser = User(
        id: fbUser.uid,
        name: name.trim(),
        email: email.trim(),
        weddingDate: weddingDate,
      );

      await compute(_createUserProfileIsolate,
          _CreateUserProfileParams(user: newUser, firestore: _firestore));

      _cachedUser = newUser;
      _cacheTimestamp = DateTime.now();

      _logger.performance(
        'signUpWithEmail',
        stopwatch.elapsed,
        category: 'user_repository',
      );

      _logger.userAction('sign_up', extra: {'method': 'email'});

      return newUser;
    } catch (e) {
      _logger.error('Sign up failed',
          category: 'user_repository',
          exception: e,
          extra: {'email': email.trim()});
      rethrow;
    }
  }

  static Future<void> _createUserProfileIsolate(
      _CreateUserProfileParams params) async {
    try {
      final data = params.user.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await params.firestore.collection('users').doc(params.user.id).set(data);
    } catch (e) {
      throw NetworkException('Chyba při vytváření profilu v Firestore',
          originalError: e);
    }
  }

  /// Optimalizované odhlášení
  Future<void> signOut() async {
    final stopwatch = Stopwatch()..start();

    try {
      _logger.info('Signing out user', category: 'user_repository');

      await _auth.signOut();
      await clearCache();

      _logger.performance(
        'signOut',
        stopwatch.elapsed,
        category: 'user_repository',
      );

      _logger.userAction('sign_out');
    } catch (e) {
      _logger.error('Sign out failed',
          category: 'user_repository', exception: e);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  //  LOKÁLNÍ ULOŽENÍ optimalizované
  // ---------------------------------------------------------------------------

  /// Optimalizované lokální uložení s validací
  Future<void> saveUserLocally(User user) async {
    try {
      UserValidator.validateUser(user);

      _logger.debug('Saving user locally', category: 'user_repository', extra: {
        'userId': user.id,
      });

      await compute(_saveUserLocallyIsolate, user);
    } catch (e) {
      _logger.error('Failed to save user locally',
          category: 'user_repository',
          exception: e,
          extra: {'userId': user.id});
      throw UserRepositoryException('Chyba při ukládání lokálních dat',
          originalError: e);
    }
  }

  static Future<void> _saveUserLocallyIsolate(User user) async {
    final prefs = await SharedPreferences.getInstance();

    // Uložení s prefixem pro lepší organizaci
    await prefs.setString('user_id', user.id);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_saved_at', DateTime.now().toIso8601String());

    if (user.weddingDate != null) {
      await prefs.setString(
          'user_wedding_date', user.weddingDate!.toIso8601String());
    } else {
      await prefs.remove('user_wedding_date');
    }
  }

  /// Optimalizované načtení z lokálního úložiště
  Future<User?> loadUserFromLocal() async {
    try {
      _logger.debug('Loading user from local storage',
          category: 'user_repository');

      final localUser = await compute(_loadUserFromLocalIsolate, null);

      if (localUser != null) {
        try {
          UserValidator.validateUser(localUser);
          _cachedUser = localUser;
          _cacheTimestamp = DateTime.now();

          _logger.debug('User loaded from local storage',
              category: 'user_repository',
              extra: {
                'userId': localUser.id,
              });
        } catch (e) {
          _logger.warning('Invalid local user data, clearing',
              category: 'user_repository', exception: e);
          await clearLocalData();
          return null;
        }
      }

      return localUser;
    } catch (e) {
      _logger.error('Failed to load user from local storage',
          category: 'user_repository', exception: e);
      throw UserRepositoryException('Chyba při načítání lokálních dat',
          originalError: e);
    }
  }

  static Future<User?> _loadUserFromLocalIsolate(_) async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_name');
    final userEmail = prefs.getString('user_email');
    final savedAtStr = prefs.getString('user_saved_at');
    final weddingDateStr = prefs.getString('user_wedding_date');

    if (userId == null || userName == null || userEmail == null) {
      return null;
    }

    // Kontrola stáří lokálních dat (max 7 dní)
    if (savedAtStr != null) {
      final savedAt = DateTime.tryParse(savedAtStr);
      if (savedAt != null && DateTime.now().difference(savedAt).inDays > 7) {
        return null; // Příliš stará data
      }
    }

    final weddingDate =
        weddingDateStr != null ? DateTime.tryParse(weddingDateStr) : null;

    return User(
      id: userId,
      name: userName,
      email: userEmail,
      weddingDate: weddingDate,
    );
  }

  /// Optimalizované mazání lokálních dat
  Future<void> clearLocalData() async {
    try {
      _logger.debug('Clearing local data', category: 'user_repository');

      await compute(_clearLocalDataIsolate, null);
    } catch (e) {
      _logger.error('Failed to clear local data',
          category: 'user_repository', exception: e);
      throw UserRepositoryException('Chyba při mazání lokálních dat',
          originalError: e);
    }
  }

  static Future<void> _clearLocalDataIsolate(_) async {
    final prefs = await SharedPreferences.getInstance();

    // Smazání všech user prefixovaných klíčů
    final keys =
        prefs.getKeys().where((key) => key.startsWith('user_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // ---------------------------------------------------------------------------
  //  CACHE A UTILITY METODY
  // ---------------------------------------------------------------------------

  /// Vyčistit cache
  Future<void> clearCache() async {
    _cachedUser = null;
    _cacheTimestamp = null;
    _lastFetchTime = null;

    // Uzavřít všechny streams
    for (final controller in _userStreams.values) {
      await controller.close();
    }
    _userStreams.clear();

    _logger.debug('Cache cleared', category: 'user_repository');
  }

  /// Předčítat uživatele pro rychlejší přístup
  Future<void> prefetchUser(String userId) async {
    try {
      await fetchUserProfile(userId: userId, source: Source.cache);
    } catch (e) {
      _logger.debug('Prefetch failed, will fetch from server later',
          category: 'user_repository', extra: {'userId': userId});
    }
  }

  /// Získat statistiky cache
  Map<String, dynamic> getCacheStats() {
    return {
      'hasCachedUser': _cachedUser != null,
      'cacheAge': _cacheTimestamp != null
          ? DateTime.now().difference(_cacheTimestamp!).inSeconds
          : null,
      'isCacheValid': isCacheValid,
      'activeStreams': _userStreams.length,
    };
  }

  /// Zkontrolovat zdraví repository
  Future<Map<String, dynamic>> healthCheck() async {
    final results = <String, dynamic>{};

    // Test Firebase Auth
    try {
      final currentUser = _auth.currentUser;
      results['auth'] = {
        'status': 'healthy',
        'hasUser': currentUser != null,
        'userId': currentUser?.uid,
      };
    } catch (e) {
      results['auth'] = {
        'status': 'unhealthy',
        'error': e.toString(),
      };
    }

    // Test Firestore connectivity
    try {
      await _firestore
          .collection('_health')
          .doc('check')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      results['firestore'] = {'status': 'healthy'};
    } catch (e) {
      results['firestore'] = {
        'status': 'unhealthy',
        'error': e.toString(),
      };
    }

    // Cache statistics
    results['cache'] = getCacheStats();

    return results;
  }

  /// Dispose metoda pro clean up
  Future<void> dispose() async {
    await clearCache();
    _logger.debug('UserRepository disposed', category: 'user_repository');
  }
}

// ---------------------------------------------------------------------------
//  ROZŠÍŘENÍ PRO USER MODEL
// ---------------------------------------------------------------------------

/// Extension metody pro User model
extension UserExtensions on User {
  /// Kontrola, zda má uživatel vyplněné všechny povinné údaje
  bool get hasCompleteProfile {
    return name.isNotEmpty && email.isNotEmpty && weddingDate != null;
  }

  /// Počet dní do svatby
  int? get daysUntilWedding {
    if (weddingDate == null) return null;
    return weddingDate!.difference(DateTime.now()).inDays;
  }

  /// Je svatba v minulosti?
  bool get isWeddingInPast {
    if (weddingDate == null) return false;
    return weddingDate!.isBefore(DateTime.now());
  }

  /// Formátované zobrazení data svatby
  String get formattedWeddingDate {
    if (weddingDate == null) return 'Datum není nastaveno';
    final formatter = DateFormat('d. MMMM yyyy', 'cs');
    return formatter.format(weddingDate!);
  }

  /// Vytvoření kopie s upravenými hodnotami
  User copyWith({
    String? id,
    String? name,
    String? email,
    DateTime? weddingDate,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      weddingDate: weddingDate ?? this.weddingDate,
    );
  }
}

// ---------------------------------------------------------------------------
//  POMOCNÉ TŘÍDY PRO BATCH OPERACE
// ---------------------------------------------------------------------------

/// Batch loader pro efektivní načítání více uživatelů
class UserBatchLoader {
  final UserRepository _repository;
  final Set<String> _pendingIds = {};
  Timer? _batchTimer;
  final _completerMap = <String, Completer<User?>>{};

  UserBatchLoader(this._repository);

  /// Naplánuje načtení uživatele v batchi
  Future<User?> loadUser(String userId) {
    if (_completerMap.containsKey(userId)) {
      return _completerMap[userId]!.future;
    }

    final completer = Completer<User?>();
    _completerMap[userId] = completer;
    _pendingIds.add(userId);

    // Naplánuj batch load
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 50), _executeBatch);

    return completer.future;
  }

  /// Provede batch načtení
  void _executeBatch() async {
    if (_pendingIds.isEmpty) return;

    final idsToLoad = List<String>.from(_pendingIds);
    _pendingIds.clear();

    try {
      // Načti všechny uživatele najednou
      final users = await _repository._batchFetchUsers(idsToLoad);

      // Vyřeš completery
      for (final id in idsToLoad) {
        final user = users.firstWhere(
          (u) => u.id == id,
          orElse: () => throw UserNotFoundException(id),
        );
        _completerMap[id]?.complete(user);
        _completerMap.remove(id);
      }
    } catch (e) {
      // V případě chyby vyřeš všechny completery s chybou
      for (final id in idsToLoad) {
        _completerMap[id]?.completeError(e);
        _completerMap.remove(id);
      }
    }
  }

  /// Dispose
  void dispose() {
    _batchTimer?.cancel();
    for (final completer in _completerMap.values) {
      if (!completer.isCompleted) {
        completer
            .completeError(UserRepositoryException('Batch loader byl ukončen'));
      }
    }
    _completerMap.clear();
  }
}

/// Rozšíření UserRepository o batch operace
extension UserRepositoryBatch on UserRepository {
  /// Batch načtení více uživatelů
  Future<List<User>> _batchFetchUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];

    try {
      final snapshots = await _usersCollection
          .where(FieldPath.documentId, whereIn: userIds)
          .get();

      return snapshots.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return User.fromJson(data);
      }).toList();
    } catch (e) {
      throw NetworkException('Chyba při batch načítání uživatelů',
          originalError: e);
    }
  }
}
