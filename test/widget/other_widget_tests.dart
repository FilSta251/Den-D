import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:den_d/widgets/custom_app_bar.dart';
import 'package:den_d/widgets/loading_widget.dart';
import 'package:den_d/widgets/error_dialog.dart';

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

      // Ověří, ťe se v custom AppBar vykreslí zadaný titulek.
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

      // Ověří, ťe widget obsahuje CircularProgressIndicator.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('ErrorDialog Widget Tests', () {
    testWidgets('ErrorDialog displays error message and default action', (WidgetTester tester) async {
      const String errorMessage = 'An error occurred';
      
      // Pouťíváme statickou metodu show pro snadnĂ© zobrazení dialogu.
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

      // Simulujeme klepnutí na tláčítko, aby se dialog zobrazil.
      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      // Ověří, ťe dialog obsahuje titulek, zprávu a tláčítko OK.
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

      // Ověří, ťe dialog obsahuje custom tláčítko "Retry".
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

