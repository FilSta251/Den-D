import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:svatebni_planovac/main.dart' as app;

void main() {
  // Zajistí, že integrační testování běží správně.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-end test: Splash Screen to Home Screen', (WidgetTester tester) async {
    // Spustí aplikaci
    app.main();
    await tester.pumpAndSettle();

    // Ověří, že se zobrazí splash obrazovka s textem "Načítání aplikace..."
    expect(find.text('Načítání aplikace...'), findsOneWidget);

    // Simulace čekání na dokončení splash obrazovky (upravit podle skutečného času, který splash trvá)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Ověří, že se objeví domovská obrazovka (např. text "Dnešní úkoly" by měl být viditelný)
    expect(find.text('Dnešní úkoly'), findsOneWidget);
  });
}
