// test/widget/login_screen_test.mocks.dart
// Manuálně vytvořené mock objekty

import 'package:mockito/mockito.dart' as _i1;
import 'package:den_d/services/auth_service.dart' as _i2;
import 'dart:async' as _i3;
import 'package:firebase_auth/firebase_auth.dart' as _i4;

// Mock pro AuthService
class MockAuthService extends _i1.Mock implements _i2.AuthService {
  @override
  _i3.Future<_i4.UserCredential?> signInWithEmail(
          String? email, String? password) =>
      (super.noSuchMethod(
        Invocation.method(
          #signInWithEmail,
          [email, password],
        ),
        returnValue: _i3.Future<_i4.UserCredential?>.value(),
        returnValueForMissingStub: _i3.Future<_i4.UserCredential?>.value(),
      ) as _i3.Future<_i4.UserCredential?>);

  @override
  _i3.Future<_i4.UserCredential?> signUpWithEmail(
          String? email, String? password) =>
      (super.noSuchMethod(
        Invocation.method(
          #signUpWithEmail,
          [email, password],
        ),
        returnValue: _i3.Future<_i4.UserCredential?>.value(),
        returnValueForMissingStub: _i3.Future<_i4.UserCredential?>.value(),
      ) as _i3.Future<_i4.UserCredential?>);

  @override
  _i3.Future<void> signOut() => (super.noSuchMethod(
        Invocation.method(
          #signOut,
          [],
        ),
        returnValue: _i3.Future<void>.value(),
        returnValueForMissingStub: _i3.Future<void>.value(),
      ) as _i3.Future<void>);

  @override
  bool get isSignedIn => (super.noSuchMethod(
        Invocation.getter(#isSignedIn),
        returnValue: false,
        returnValueForMissingStub: false,
      ) as bool);

  @override
  _i4.User? get currentUser => (super.noSuchMethod(
        Invocation.getter(#currentUser),
      ) as _i4.User?);

  @override
  _i3.Stream<_i4.User?> get authStateChanges => (super.noSuchMethod(
        Invocation.getter(#authStateChanges),
        returnValue: _i3.Stream<_i4.User?>.empty(),
        returnValueForMissingStub: _i3.Stream<_i4.User?>.empty(),
      ) as _i3.Stream<_i4.User?>);
}
