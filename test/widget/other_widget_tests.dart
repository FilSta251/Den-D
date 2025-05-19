import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svatebni_planovac/widgets/custom_app_bar.dart';
import 'package:svatebni_planovac/widgets/loading_widget.dart';
import 'package:svatebni_planovac/widgets/error_dialog.dart';

void main() {
  group('CustomAppBar Widget Tests', () {
    testWidgets('CustomAppBar renders with correct title', (WidgetTester tester) async {
      const String title = 'Test AppBar';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(title: title),
          ),
        ),
      );

      // Ověří, že se v custom AppBar vykreslí zadaný titulek.
      expect(find.text(title), findsOneWidget);
    });
  });

  group('LoadingWidget Widget Tests', () {
    testWidgets('LoadingWidget displays CircularProgressIndicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingWidget(),
          ),
        ),
      );

      // Ověří, že widget obsahuje CircularProgressIndicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ErrorDialog Widget Tests', () {
    testWidgets('ErrorDialog displays error message and default action', (WidgetTester tester) async {
      const String errorMessage = 'An error occurred';
      
      // Používáme statickou metodu show pro snadné zobrazení dialogu.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ErrorDialog.show(
                  context,
                  title: 'Error',
                  message: errorMessage,
                );
              },
              child: const Text('Show Error'),
            ),
          ),
        ),
      );

      // Simulujeme klepnutí na tlačítko, aby se dialog zobrazil.
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      // Ověří, že dialog obsahuje titulek, zprávu a tlačítko OK.
      expect(find.text('Error'), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('ErrorDialog displays custom actions when provided', (WidgetTester tester) async {
      const String errorMessage = 'Custom error';
      
      final retryButton = TextButton(
        onPressed: () {},
        child: const Text('Retry'),
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ErrorDialog.show(
                  context,
                  title: 'Error',
                  message: errorMessage,
                  actions: [retryButton],
                );
              },
              child: const Text('Show Error with Action'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error with Action'));
      await tester.pumpAndSettle();

      // Ověří, že dialog obsahuje custom tlačítko "Retry".
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
