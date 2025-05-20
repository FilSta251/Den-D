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
