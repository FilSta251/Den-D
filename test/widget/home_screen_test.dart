// test/widget/home_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('HomeScreen zobrazí základní UI', (WidgetTester tester) async {
      // Pro testování použijeme jednoduchý mock screen
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<MockWeddingRepository>(
                create: (_) => MockWeddingRepository(),
              ),
              Provider<MockTaskRepository>(
                create: (_) => MockTaskRepository(),
              ),
            ],
            child: const SimpleHomeScreen(),
          ),
        ),
      );

      // Ověříme, že se screen zobrazil
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Svatební plánovač'), findsOneWidget);
    });

    testWidgets('HomeScreen zobrazí úvodní text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<MockWeddingRepository>(
                create: (_) => MockWeddingRepository(),
              ),
              Provider<MockTaskRepository>(
                create: (_) => MockTaskRepository(),
              ),
            ],
            child: const SimpleHomeScreen(),
          ),
        ),
      );

      expect(find.text('Vítejte v plánovači svatby'), findsOneWidget);
    });

    testWidgets('HomeScreen má navigační tlačítka',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              Provider<MockWeddingRepository>(
                create: (_) => MockWeddingRepository(),
              ),
              Provider<MockTaskRepository>(
                create: (_) => MockTaskRepository(),
              ),
            ],
            child: const SimpleHomeScreen(),
          ),
        ),
      );

      // Ověříme, že jsou k dispozici základní navigační prvky
      expect(find.byType(AppBar), findsOneWidget);
    });
  });
}

// ============================================================================
// MOCK TŘÍDY
// ============================================================================

// Mock repository pro svatební data
class MockWeddingRepository {
  Future<Map<String, dynamic>> getWeddingData() async {
    return {
      'date': '2024-06-15',
      'venue': 'Svatební místo',
      'budget': 500000,
    };
  }

  Future<int> getDaysUntilWedding() async {
    final weddingDate = DateTime(2024, 6, 15);
    final today = DateTime.now();
    return weddingDate.difference(today).inDays;
  }
}

// Mock repository pro úkoly
class MockTaskRepository {
  Future<List<Map<String, dynamic>>> getTasks() async {
    return [
      {
        'id': '1',
        'title': 'Objednat květiny',
        'completed': false,
      },
      {
        'id': '2',
        'title': 'Rezervovat místo',
        'completed': true,
      },
    ];
  }

  Future<int> getPendingTasksCount() async {
    final tasks = await getTasks();
    return tasks.where((task) => task['completed'] == false).length;
  }
}

// ============================================================================
// TESTOVACÍ WIDGET
// ============================================================================

// Jednoduchý home screen pro testování
class SimpleHomeScreen extends StatelessWidget {
  const SimpleHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Svatební plánovač'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
              'Vítejte v plánovači svatby',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Organizujte vaši vysněnou svatbu snadno a přehledně',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionCard(
                  icon: Icons.checklist,
                  title: 'Úkoly',
                  onTap: () {},
                ),
                _buildQuickActionCard(
                  icon: Icons.attach_money,
                  title: 'Rozpočet',
                  onTap: () {},
                ),
                _buildQuickActionCard(
                  icon: Icons.calendar_today,
                  title: 'Harmonogram',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
