import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Stream, který vysílá změny stavu přihlášení (příchod/odchod uživatele).
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  /// Aktuálně přihlášený uživatel (může být `null`, pokud nikdo není přihlášen).
  fb.User? get currentUser => _auth.currentUser;

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
      // Debug log pro kontrolu UID
      final user = fb.FirebaseAuth.instance.currentUser;
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
      // Debug log pro kontrolu UID
      final user = fb.FirebaseAuth.instance.currentUser;
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
      if (kIsWeb) {
        final fb.GoogleAuthProvider googleProvider = fb.GoogleAuthProvider();
        googleProvider.setCustomParameters({'login_hint': 'user@example.com'});
        final userCredential = await _auth.signInWithPopup(googleProvider);
        // Debug log pro kontrolu UID
        final user = fb.FirebaseAuth.instance.currentUser;
        debugPrint('>>> CurrentUser UID (Google Web): ${user?.uid}');
        return userCredential;
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
        final userCredential = await _auth.signInWithCredential(credential);
        // Debug log pro kontrolu UID
        final user = fb.FirebaseAuth.instance.currentUser;
        debugPrint('>>> CurrentUser UID (Google): ${user?.uid}');
        return userCredential;
      }
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
      // Debug log pro kontrolu UID
      final user = fb.FirebaseAuth.instance.currentUser;
      debugPrint('>>> CurrentUser UID (Facebook): ${user?.uid}');
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
  // Odhlášení
  // -----------------------

  Future<void> signOut() async {
    try {
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
