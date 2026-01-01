// test/widget/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:den_d/services/auth_service.dart';

import 'login_screen_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  group('Login Screen Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets('zobrazí přihlašovací formulář', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<AuthService>.value(
            value: mockAuthService,
            child: const SimpleLoginScreen(),
          ),
        ),
      );

      // Kontrola AppBar title
      expect(find.widgetWithText(AppBar, 'Přihlásit se'), findsOneWidget);
      // Kontrola textových polí
      expect(find.byType(TextField), findsNWidgets(2)); // Email + Heslo
      // Kontrola tlačítka
      expect(
          find.widgetWithText(ElevatedButton, 'Přihlásit se'), findsOneWidget);
    });

    testWidgets('zobrazí chybu při neplatném emailu',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<AuthService>.value(
            value: mockAuthService,
            child: const SimpleLoginScreen(),
          ),
        ),
      );

      // Zadáme neplatný email
      await tester.enterText(find.byType(TextField).first, 'neplatny-email');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Neplatná emailová adresa'), findsOneWidget);
    });

    testWidgets('zobrazí chybu při prázdném heslu',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Provider<AuthService>.value(
            value: mockAuthService,
            child: const SimpleLoginScreen(),
          ),
        ),
      );

      // Zadáme email, ale prázdné heslo
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Heslo je povinné'), findsOneWidget);
    });

    testWidgets('zavolá signInWithEmail při platném formuláři',
        (WidgetTester tester) async {
      // Arrange
      when(mockAuthService.signInWithEmail(any, any))
          .thenAnswer((_) async => null);

      await tester.pumpWidget(
        MaterialApp(
          home: Provider<AuthService>.value(
            value: mockAuthService,
            child: const SimpleLoginScreen(),
          ),
        ),
      );

      // Act
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Assert
      verify(mockAuthService.signInWithEmail('test@example.com', 'password123'))
          .called(1);
    });
  });
}

// ============================================================================
// POMOCNÝ WIDGET PRO TESTOVÁNÍ
// ============================================================================

// Jednoduchý přihlašovací screen pro testování
class SimpleLoginScreen extends StatefulWidget {
  const SimpleLoginScreen({Key? key}) : super(key: key);

  @override
  State<SimpleLoginScreen> createState() => _SimpleLoginScreenState();
}

class _SimpleLoginScreenState extends State<SimpleLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    // Validace
    if (!_validateEmail(_emailController.text)) {
      setState(() {
        _emailError = 'Neplatná emailová adresa';
      });
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'Heslo je povinné';
      });
      return;
    }

    // Přihlášení
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Přihlásit se'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: _emailError,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Heslo',
                errorText: _passwordError,
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Přihlásit se'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
