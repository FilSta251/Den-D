// test/unit/auth_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:den_d/services/auth_service.dart';
import 'package:den_d/services/security_service.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([fb.FirebaseAuth, fb.UserCredential, fb.User, SecurityService])
void main() {
  group('AuthService Tests', () {
    late MockFirebaseAuth mockFirebaseAuth;
    late MockSecurityService mockSecurityService;
    late AuthService authService;
    late MockUserCredential mockUserCredential;
    late MockUser mockUser;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockSecurityService = MockSecurityService();
      mockUserCredential = MockUserCredential();
      mockUser = MockUser();

      // Vytvoření AuthService s mock objekty
      authService = AuthService(
        auth: mockFirebaseAuth,
        securityService: mockSecurityService,
      );

      // Nastavení základních mock odpovědí
      when(mockUserCredential.user).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test-uid');
      when(mockUser.email).thenReturn('test@example.com');

      // Mock pro SecurityService
      when(mockSecurityService.storeAuthToken(any, any))
          .thenAnswer((_) async => {});
    });

    test('signInWithEmail vrátí UserCredential při úspěchu', () async {
      // Arrange
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockUserCredential);

      when(mockUser.getIdTokenResult(any)).thenAnswer(
        (_) async => MockIdTokenResult(
            'mock-token', DateTime.now().add(Duration(hours: 1))),
      );

      // Act
      final result =
          await authService.signInWithEmail('test@example.com', 'password123');

      // Assert
      expect(result, isNotNull);
      expect(result?.user?.uid, equals('test-uid'));
      expect(result?.user?.email, equals('test@example.com'));

      // Ověření, že byla volána správná metoda
      verify(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });

    test('signInWithEmail vyhodí AuthException při FirebaseAuthException',
        () async {
      // Arrange
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'wrong-password',
      )).thenThrow(
        fb.FirebaseAuthException(
          code: 'wrong-password',
          message: 'Neplatné heslo',
        ),
      );

      // Act & Assert
      expect(
        () => authService.signInWithEmail('test@example.com', 'wrong-password'),
        throwsA(isA<AuthException>()),
      );
    });

    test('signUpWithEmail vytvoří nového uživatele', () async {
      // Arrange
      when(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: 'new@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockUserCredential);

      when(mockUser.getIdTokenResult(any)).thenAnswer(
        (_) async => MockIdTokenResult(
            'mock-token', DateTime.now().add(Duration(hours: 1))),
      );

      // Act
      final result =
          await authService.signUpWithEmail('new@example.com', 'password123');

      // Assert
      expect(result, isNotNull);
      expect(result?.user, isNotNull);

      verify(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: 'new@example.com',
        password: 'password123',
      )).called(1);
    });

    test('signOut odhlásí uživatele ze všech poskytovatelů', () async {
      // Arrange
      when(mockFirebaseAuth.signOut()).thenAnswer((_) async => {});
      when(mockSecurityService.clearAuthToken()).thenAnswer((_) async => {});
      when(mockSecurityService.clearAllData()).thenAnswer((_) async => {});

      // Act
      await authService.signOut();

      // Assert
      verify(mockFirebaseAuth.signOut()).called(1);
      verify(mockSecurityService.clearAuthToken()).called(1);
      verify(mockSecurityService.clearAllData()).called(1);
    });

    test('currentUser vrátí aktuálního uživatele', () {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

      // Act
      final user = authService.currentUser;

      // Assert
      expect(user, isNotNull);
      expect(user?.uid, equals('test-uid'));
    });

    test('isSignedIn vrátí true pokud je uživatel přihlášen', () {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

      // Act
      final isSignedIn = authService.isSignedIn;

      // Assert
      expect(isSignedIn, isTrue);
    });

    test('isSignedIn vrátí false pokud není uživatel přihlášen', () {
      // Arrange
      when(mockFirebaseAuth.currentUser).thenReturn(null);

      // Act
      final isSignedIn = authService.isSignedIn;

      // Assert
      expect(isSignedIn, isFalse);
    });
  });
}

// Pomocná třída pro mock IdTokenResult
class MockIdTokenResult extends Mock implements fb.IdTokenResult {
  final String? _token;
  final DateTime? _expirationTime;

  MockIdTokenResult(this._token, this._expirationTime);

  @override
  String? get token => _token;

  @override
  DateTime? get expirationTime => _expirationTime;
}
