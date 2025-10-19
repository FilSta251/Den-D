/// test/widget/login_screen_test.dart
library;

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mockito/mockito.dart";
import "package:mockito/annotations.dart";
import "package:provider/provider.dart";
import "package:den_d/services/auth_service.dart";
import "package:den_d/screens/auth_screen.dart";

import "login_screen_test.mocks.dart";

@GenerateMocks([AuthService])
void main() {
  group("Login Screen Tests", () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets("should display login form elements",
        (WidgetTester tester) async {
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

    testWidgets("should show error on invalid email",
        (WidgetTester tester) async {
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

    testWidgets("should show error on empty password",
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<AuthService>.value(
            value: mockAuthService,
            child: const AuthScreen(),
          ),
        ),
      );

      await tester.enterText(
          find.byType(TextFormField).first, "test@example.com");
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text("Heslo je povinnĂ©"), findsOneWidget);
    });

    testWidgets("should call signInWithEmail on valid form submission",
        (WidgetTester tester) async {
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

      await tester.enterText(
          find.byType(TextFormField).first, "test@example.com");
      await tester.enterText(find.byType(TextFormField).last, "password123");
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      verify(mockAuthService.signInWithEmail("test@example.com", "password123"))
          .called(1);
    });
  });
}
