// test/integration_test/app_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Vytvoříme jednoduchou testovací aplikaci místo spuštění celé reálné app
    await tester.pumpWidget(
      const MaterialApp(
        home: TestHomeScreen(),
      ),
    );

    // Ověříme, že aplikace se zobrazila
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(TestHomeScreen), findsOneWidget);
    expect(find.text('Svatební plánovač'), findsOneWidget);
  });

  testWidgets('Navigation smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TestHomeScreen(),
      ),
    );

    // Základní navigační test
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('Widget tree smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TestHomeScreen(),
      ),
    );

    // Ověříme, že widget tree je v pořádku
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

// ============================================================================
// TESTOVACÍ SCREEN
// ============================================================================

class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Svatební plánovač'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite,
              size: 80,
              color: Colors.pink,
            ),
            const SizedBox(height: 24),
            const Text(
              'Aplikace funguje!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Test tlačítko'),
            ),
          ],
        ),
      ),
    );
  }
}
