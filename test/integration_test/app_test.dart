import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:den_d/main.dart' as app;

void main() {
  // Zajistí, ťe integráční testování běťí správně.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end test: Splash Screen to Home Screen', (WidgetTester tester) async {
    // Spustí aplikaci
    app.main();
    await tester.pumpAndSettle();

    // Ověří, ťe se zobrazí splash obrazovka s textem "Náčítání aplikace..."
    expect(find.text('Náčítání aplikace...'), findsOneWidget);

    // Simulace čekání na dokončení splash obrazovky (upravit podle skutečnĂ©ho času, který splash trvá)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Ověří, ťe se objeví domovská obrazovka (např. text "DneĹˇní úkoly" by měl být viditelný)
    expect(find.text('DneĹˇní úkoly'), findsOneWidget);
  });
}

