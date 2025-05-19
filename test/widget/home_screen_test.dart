import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svatebni_planovac/screens/home_screen.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('HomeScreen displays countdown widget and tasks header', (WidgetTester tester) async {
      // Vytvoříme widget pomocí MaterialApp pro správnou navigaci a témata
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(),
        ),
      );

      // Necháme běžet čas pro inicializaci a případné animace
      await tester.pumpAndSettle();

      // Ověříme, že se na obrazovce objeví text "Dnešní úkoly"
      expect(find.text('Dnešní úkoly'), findsOneWidget);

      // Ověříme, že je zobrazen odpočet (hledáme nějaký text, který obsahuje "d" - den)
      expect(find.byWidgetPredicate((widget) {
        if (widget is Text) {
          return widget.data != null && widget.data!.contains('d');
        }
        return false;
      }), findsOneWidget);
    });
  });
}
