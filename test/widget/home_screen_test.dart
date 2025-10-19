import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:den_d/screens/home_screen.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('HomeScreen displays countdown widget and tasks header', (WidgetTester tester) async {
      // Vytvoříme widget pomocí MaterialApp pro správnou navigaci a tĂ©mata
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Necháme běťet čas pro inicializaci a případnĂ© animace
      await tester.pumpAndSettle();

      // Ověříme, ťe se na obrazovce objeví text "DneĹˇní úkoly"
      expect(find.text('DneĹˇní úkoly'), findsOneWidget);

      // Ověříme, ťe je zobrazen odpočet (hledáme nějaký text, který obsahuje "d" - den)
      expect(find.byWidgetPredicate((widget) {
        if (widget is Text) {
          return widget.data != null && widget.data!.contains('d');
        }
        return false;
      }), findsOneWidget);
    });
  });
}

