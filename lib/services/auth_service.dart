import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'security_service.dart';

/// AuthService zajišťuje autentizační metody pro:
/// - E-mail + heslo
/// - Google OAuth
/// - Facebook OAuth
/// - (Volitelně) Anonymní přihlášení
/// - Reset hesla (password reset)
///
/// Po přihlášení vždy spravuje stav FirebaseAuth, Google Sign-In a Facebook Auth.
/// V odhlášení se odhlásí ze všech poskytovatelů najednou.
/// Je možné přidat i další poskytovatele (Apple Sign-In, PhoneAuth, atd.).
class AuthService {
  /// Instance Firebase Auth SDK.
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  /// Google Sign-In klient.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email', 'profile'],
  );

  /// Instance bezpečnostní služby pro správu tokenů
  final SecurityService _securityService = SecurityService();

  /// Stream, který vysílá změny stavu přihlášení (příchod/odchod uživatele).
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  /// Aktuálně přihlášený uživatel (může být `null`, pokud nikdo není přihlášen).
  fb.User? get currentUser => _auth.currentUser;

  // -----------------------
  // Token Management
  // -----------------------

  /// Obnoví autentizační token a uloží jej
  Future<bool> refreshAuthToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final idTokenResult = await user.getIdTokenResult(true);
      if (idTokenResult.token != null) {
        final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
        await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Failed to refresh auth token: $e");
      return false;
    }
  }

  // -----------------------
  // Email + Heslo
  // -----------------------

  /// Přihlášení uživatele pomocí e-mailu a hesla.
  /// Po úspěchu vrací `UserCredential` a vypíše UID do logu.
  Future<fb.UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // Uložení tokenu
      final user = userCredential.user;
      if (user != null) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.token != null) {
          final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
      }
      
      // Debug log pro kontrolu UID
      debugPrint('>>> CurrentUser UID (Email): ${user?.uid}');
      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null; // Tento kód se sem nedostane, protože _handleAuthError vyhazuje výjimku.
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  /// Registrace nového uživatele pomocí e-mailu a hesla.
  /// Po úspěchu vrací `UserCredential` a vypíše UID do logu.
  Future<fb.UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // Uložení tokenu
      final user = userCredential.user;
      if (user != null) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.token != null) {
          final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
      }
      
      // Debug log pro kontrolu UID
      debugPrint('>>> New User UID (Email): ${user?.uid}');
      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  // -----------------------
  // Google OAuth
  // -----------------------

  /// Přihlášení přes Google OAuth.
  /// Před každým přihlášením se pokusí odpojit předchozí Google účet, aby se vyvolal výběr účtu.
  /// Na webu využívá signInWithPopup().
  Future<fb.UserCredential?> signInWithGoogle() async {
    try {
      fb.UserCredential? userCredential;
      
      if (kIsWeb) {
        final fb.GoogleAuthProvider googleProvider = fb.GoogleAuthProvider();
        googleProvider.setCustomParameters({'login_hint': 'user@example.com'});
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Pokusíme se odpojit předchozí účet; pokud selže, chybu zalogujeme, ale pokračujeme.
        try {
          await _googleSignIn.disconnect();
        } catch (disconnectError) {
          debugPrint('Error disconnecting previous Google account: $disconnectError');
        }
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('Google sign-in cancelled by user.');
          return null;
        }
        final googleAuth = await googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }
      
      // Uložení tokenu
      final user = userCredential.user;
      if (user != null) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.token != null) {
          final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
        // Debug log pro kontrolu UID
        debugPrint('>>> CurrentUser UID (Google): ${user.uid}');
      }
      
      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  // -----------------------
  // Facebook OAuth
  // -----------------------

  /// Přihlášení přes Facebook OAuth.
  /// Po úspěchu vrací `UserCredential` a vypíše UID do logu.
  Future<fb.UserCredential?> signInWithFacebook() async {
    try {
      final result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw Exception('Facebook login failed: ${result.status}');
      }
      final credential = fb.FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Uložení tokenu
      final user = userCredential.user;
      if (user != null) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.token != null) {
          final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
        // Debug log pro kontrolu UID
        debugPrint('>>> CurrentUser UID (Facebook): ${user.uid}');
      }
      
      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  // -----------------------
  // Anonymní přihlášení
  // -----------------------

  Future<fb.UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      
      // Uložení tokenu
      final user = userCredential.user;
      if (user != null) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.token != null) {
          final expiry = idTokenResult.expirationTime ?? DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
      }
      
      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  // -----------------------
  // Password Reset
  // -----------------------

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent to $email');
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  // -----------------------
  // Validace tokenu
  // -----------------------
  
  Future<bool> validateToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      final token = await _securityService.getAuthToken();
      if (token == null) return false;
      
      // Kontrola expirace tokenu
      final expiry = await _securityService.getTokenExpiry();
      if (expiry == null) return false;
      
      // Pokud token vyprší za méně než 5 minut, obnovíme ho
      if (DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)))) {
        return await refreshAuthToken();
      }
      
      return true;
    } catch (e) {
      debugPrint("Error validating token: $e");
      return false;
    }
  }

  // -----------------------
  // Odhlášení
  // -----------------------

  Future<void> signOut() async {
    try {
      // OPRAVENO: Použití správných metod SecurityService
      await _securityService.clearAuthToken();
      await _securityService.clearAllData();
      
      await _auth.signOut();
      await _googleSignIn.signOut();
      await FacebookAuth.instance.logOut();
      debugPrint('User signed out from all providers.');
    } catch (e, stackTrace) {
      debugPrint('Error during sign out: $e\n$stackTrace');
      rethrow;
    }
  }

  // -----------------------
  // Utility metody
  // -----------------------

  /// Kontrola, zda je uživatel přihlášen
  bool get isSignedIn => _auth.currentUser != null;

  /// Získání ID tokenu aktuálního uživatele
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('Error getting ID token: $e');
      return null;
    }
  }

  /// Získání informací o tokenech uživatele
  Future<fb.IdTokenResult?> getIdTokenResult({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      return await user.getIdTokenResult(forceRefresh);
    } catch (e) {
      debugPrint('Error getting ID token result: $e');
      return null;
    }
  }

  /// Ověření e-mailové adresy
  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
      }
      
      if (user.emailVerified) {
        debugPrint('Email already verified');
        return;
      }
      
      await user.sendEmailVerification();
      debugPrint('Verification email sent to ${user.email}');
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  /// Kontrola, zda je e-mail ověřen
  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // Reload user data to get fresh email verification status
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  /// Aktualizace profilu uživatele
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
      }
      
      await user.updateProfile(displayName: displayName, photoURL: photoURL);
      await user.reload();
      debugPrint('User profile updated');
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  /// Změna hesla
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
      }
      
      await user.updatePassword(newPassword);
      debugPrint('Password updated successfully');
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  /// Re-autentizace uživatele (potřebná před některými citlivými operacemi)
  Future<void> reauthenticateWithEmail(String email, String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
      }
      
      final credential = fb.EmailAuthProvider.credential(
        email: email.trim(),
        password: password.trim(),
      );
      
      await user.reauthenticateWithCredential(credential);
      debugPrint('User reauthenticated successfully');
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  /// Smazání účtu
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
      }
      
      // Vyčistit bezpečnostní data před smazáním účtu
      await _securityService.clearAuthToken();
      await _securityService.clearAllData();
      
      await user.delete();
      debugPrint('User account deleted');
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  // -----------------------
  // Interní zpracování chyb
  // -----------------------

  void _handleAuthError(fb.FirebaseAuthException e, StackTrace stackTrace) {
    final errorMessages = <String, String>{
      'wrong-password': 'Neplatné heslo.',
      'user-not-found': 'Uživatel neexistuje.',
      'invalid-email': 'Neplatný e-mail.',
      'email-already-in-use': 'Tento e-mail je již registrován.',
      'operation-not-allowed': 'Tato metoda přihlášení není povolena.',
      'account-exists-with-different-credential': 'Účet existuje s jiným způsobem přihlášení.',
      'invalid-credential': 'Neplatné přihlašovací údaje.',
      'user-disabled': 'Účet byl zablokován.',
      'token-expired': 'Platnost přihlášení vypršela. Přihlaste se znovu.',
      'invalid-token': 'Neplatný přihlašovací token.',
      'network-request-failed': 'Chyba připojení k síti.',
      'weak-password': 'Heslo je příliš slabé.',
      'requires-recent-login': 'Tato operace vyžaduje nedávné přihlášení. Přihlaste se znovu.',
      'too-many-requests': 'Příliš mnoho neúspěšných pokusů. Zkuste to později.',
      'provider-already-linked': 'Tento poskytovatel je již propojen s účtem.',
      'credential-already-in-use': 'Tyto přihlašovací údaje jsou již použity jiným účtem.',
    };

    final message = errorMessages[e.code] ?? 'Chyba přihlášení: ${e.message}';
    debugPrint('Auth error: [${e.code}] $message');
    throw AuthException(message, e.code, stackTrace);
  }
}

/// AuthException zapouzdřuje chybové stavy z FirebaseAuth, včetně kódu chyby a stack trace.
class AuthException implements Exception {
  final String message;
  final String code;
  final StackTrace stackTrace;

  AuthException(this.message, this.code, this.stackTrace);

  @override
  String toString() => 'AuthException(code: $code, message: $message)';
}