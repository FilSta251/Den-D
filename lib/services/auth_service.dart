import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'security_service.dart';

/// AuthService zajišťuje autentizační metody pro:
/// - E-mail + heslo
/// - Google OAuth
/// - Apple Sign In (iOS/macOS)
/// - (Volitelně) Anonymní přihlášení
/// - Reset hesla (password reset)
///
/// Po přihlášení vždy spravuje stav FirebaseAuth a Google Sign-In.
/// V odhlášení se odhlásí ze všech poskytovatelů najednou.
class AuthService {
  /// Instance Firebase Auth SDK.
  final fb.FirebaseAuth _auth;

  /// Google Sign-In klient pro verzi 6.2.1
  final GoogleSignIn _googleSignIn;

  /// Instance bezpečnostní služby pro správu tokenů
  final SecurityService _securityService;

  /// Konstruktor s dependency injection
  /// Pokud nejsou poskytnuty závislosti, použijí se výchozí produkční instance
  AuthService({
    fb.FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    SecurityService? securityService,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: <String>['email', 'profile'],
              forceCodeForRefreshToken: true,
            ),
        _securityService = securityService ?? SecurityService();

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
        final expiry = idTokenResult.expirationTime ??
            DateTime.now().add(const Duration(hours: 1));
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
  Future<fb.UserCredential?> signInWithEmail(
      String email, String password) async {
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
          final expiry = idTokenResult.expirationTime ??
              DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
      }

      // Debug log pro kontrolu UID
      debugPrint('>>> CurrentUser UID (Email): ${user?.uid}');
      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null;
    } catch (e, stackTrace) {
      throw AuthException(e.toString(), 'unknown', stackTrace);
    }
  }

  /// Registrace nového uživatele pomocí e-mailu a hesla.
  /// Po úspěchu vrací `UserCredential` a vypíše UID do logu.
  Future<fb.UserCredential?> signUpWithEmail(
      String email, String password) async {
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
          final expiry = idTokenResult.expirationTime ??
              DateTime.now().add(const Duration(hours: 1));
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
        // Nejdříve zkontrolujeme, zda je uživatel připojen
        try {
          final currentUser = await _googleSignIn.signInSilently();
          if (currentUser != null) {
            await _googleSignIn.disconnect();
            debugPrint('Previous Google account disconnected successfully');
          }
        } catch (disconnectError) {
          debugPrint(
              'Error disconnecting previous Google account: $disconnectError');
        }

        // Použití správné metody pro google_sign_in 6.2.1
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          debugPrint('Google sign-in cancelled by user.');
          return null;
        }

        // Získání autentizačních tokenů
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

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
          final expiry = idTokenResult.expirationTime ??
              DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
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
  // Apple Sign In
  // -----------------------

  /// Přihlášení pomocí Apple Sign In
  /// Podporováno pouze na iOS 13+ a macOS 10.15+
  Future<fb.UserCredential?> signInWithApple() async {
    try {
      debugPrint('Zahajuji Apple Sign In...');

      // Zkontrolujte dostupnost Apple Sign In
      if (!await SignInWithApple.isAvailable()) {
        debugPrint('Apple Sign In není dostupný na tomto zařízení');
        throw AuthException(
          'Apple Sign In není dostupný na tomto zařízení',
          'apple-signin-not-available',
          StackTrace.current,
        );
      }

      // Vygenerujte náhodný řetězec pro nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Požádejte o Apple přihlašovací údaje
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // ✅ DEBUG: Kontrola Apple credential
      debugPrint('Apple credential získán:');
      debugPrint('  - identityToken: ${appleCredential.identityToken != null ? "OK (${appleCredential.identityToken!.length} znaků)" : "NULL ⚠️"}');
      debugPrint('  - authorizationCode: ${appleCredential.authorizationCode.isNotEmpty ? "OK (${appleCredential.authorizationCode.length} znaků)" : "PRÁZDNÝ ⚠️"}');
      debugPrint('  - email: ${appleCredential.email ?? "není k dispozici"}');
      debugPrint('  - userIdentifier: ${appleCredential.userIdentifier ?? "není k dispozici"}');

      // Kontrola, že identityToken existuje
      if (appleCredential.identityToken == null) {
        throw AuthException(
          'Apple neposkytl identity token. Zkontrolujte Xcode capability "Sign in with Apple".',
          'apple-missing-token',
          StackTrace.current,
        );
      }

      // ✅ DEBUG: Dekódujme JWT token a podívejme se na audience
      try {
        final parts = appleCredential.identityToken!.split('.');
        if (parts.length == 3) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          debugPrint('Apple JWT payload: $decoded');
        }
      } catch (e) {
        debugPrint('Nepodařilo se dekódovat JWT: $e');
      }

      // Vytvořte OAuthCredential pro Firebase
      debugPrint('Vytvářím Firebase credential s rawNonce a accessToken...');
      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
        rawNonce: rawNonce,
      );

      // Přihlaste se do Firebase
      debugPrint('Odesílám credential do Firebase...');
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      debugPrint('Apple Sign In úspěšný: ${userCredential.user?.uid}');

      // Pokud je dostupné jméno, aktualizujte profil
      if (appleCredential.givenName != null ||
          appleCredential.familyName != null) {
        final displayName =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (displayName.isNotEmpty) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }

      // Uložení tokenu
      final user = userCredential.user;
      if (user != null) {
        final idTokenResult = await user.getIdTokenResult();
        if (idTokenResult.token != null) {
          final expiry = idTokenResult.expirationTime ??
              DateTime.now().add(const Duration(hours: 1));
          await _securityService.storeAuthToken(idTokenResult.token!, expiry);
        }
        debugPrint('>>> CurrentUser UID (Apple): ${user.uid}');
      }

      return userCredential;
    } on fb.FirebaseAuthException catch (e, stackTrace) {
      _handleAuthError(e, stackTrace);
      return null;
    } on SignInWithAppleAuthorizationException catch (e, stackTrace) {
      debugPrint(
          'Apple Sign In AuthorizationException: ${e.code} - ${e.message}');

      // Zpracování specifických Apple chyb
      String message;
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          message = 'Přihlášení bylo zrušeno';
          break;
        case AuthorizationErrorCode.failed:
          message = 'Přihlášení selhalo';
          break;
        case AuthorizationErrorCode.invalidResponse:
          message = 'Neplatná odpověď od Apple';
          break;
        case AuthorizationErrorCode.notHandled:
          message = 'Požadavek nebyl zpracován';
          break;
        case AuthorizationErrorCode.unknown:
        default:
          message = 'Neznámá chyba při přihlášení přes Apple';
      }

      throw AuthException(message, e.code.toString(), stackTrace);
    } catch (e, stackTrace) {
      debugPrint('Neočekávaná chyba při Apple Sign In: $e');
      throw AuthException(
        'Chyba při přihlášení přes Apple: $e',
        'apple-signin-error',
        stackTrace,
      );
    }
  }

  /// Vygeneruje náhodný řetězec pro nonce
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Vrátí SHA256 hash řetězce
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
          final expiry = idTokenResult.expirationTime ??
              DateTime.now().add(const Duration(hours: 1));
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
  // Password Reset - OPRAVENO PRO VÍCEJAZYČNOST
  // -----------------------

  Future<void> sendPasswordResetEmail(String email, String languageCode) async {
    try {
      // Nastavení jazyka pro Firebase Auth e-maily
      await _auth.setLanguageCode(languageCode);
      debugPrint('Setting Firebase Auth language to: $languageCode');

      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint(
          'Password reset email sent to $email in language: $languageCode');
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
      // Vyčištění bezpečnostních dat
      await _securityService.clearAuthToken();
      await _securityService.clearAllData();

      // Odhlášení z Firebase
      await _auth.signOut();

      // Bezpečné odhlášení z Google
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign out error: $e');
      }

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
  Future<fb.IdTokenResult?> getIdTokenResult(
      {bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await user.getIdTokenResult(forceRefresh);
    } catch (e) {
      debugPrint('Error getting ID token result: $e');
      return null;
    }
  }

  /// Ověření e-mailové adresy - OPRAVENO PRO VÍCEJAZYČNOST
  Future<void> sendEmailVerification({String? languageCode}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException(
            'Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
      }

      if (user.emailVerified) {
        debugPrint('Email already verified');
        return;
      }

      // Nastavení jazyka pokud je poskytnut
      if (languageCode != null) {
        await _auth.setLanguageCode(languageCode);
        debugPrint('Setting Firebase Auth language to: $languageCode');
      }

      await user.sendEmailVerification();
      debugPrint(
          'Verification email sent to ${user.email} in language: ${languageCode ?? "default"}');
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
        throw AuthException(
            'Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
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
        throw AuthException(
            'Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
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
        throw AuthException(
            'Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
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
        throw AuthException(
            'Žádný uživatel není přihlášen', 'no-user', StackTrace.current);
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
      'account-exists-with-different-credential':
          'Účet existuje s jiným způsobem přihlášení.',
      'invalid-credential': 'Neplatné přihlašovací údaje.',
      'user-disabled': 'Účet byl zablokován.',
      'token-expired': 'Platnost přihlášení vypršela. Přihlaste se znovu.',
      'invalid-token': 'Neplatný přihlašovací token.',
      'network-request-failed': 'Chyba připojení k síti.',
      'weak-password': 'Heslo je příliš slabé.',
      'requires-recent-login':
          'Tato operace vyžaduje nedávné přihlášení. Přihlaste se znovu.',
      'too-many-requests':
          'Příliš mnoho neúspěšných pokusů. Zkuste to později.',
      'provider-already-linked': 'Tento poskytovatel je již propojen s účtem.',
      'credential-already-in-use':
          'Tyto přihlašovací údaje jsou již použity jiným účtem.',
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
