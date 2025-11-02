// test/widget/other_widget_tests.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomAppBar Widget Tests', () {
    testWidgets('CustomAppBar zobrazí správný titulek',
        (WidgetTester tester) async {
      const String title = 'Test AppBar';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(title: title),
          ),
        ),
      );

      // Ověří, že se v custom AppBar vykreslí zadaný titulek
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('CustomAppBar má správnou výšku', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: CustomAppBar(title: 'Test'),
          ),
        ),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.preferredSize.height, equals(kToolbarHeight));
    });
  });

  group('LoadingWidget Widget Tests', () {
    testWidgets('LoadingWidget zobrazí CircularProgressIndicator',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingWidget(),
          ),
        ),
      );

      // Ověří, že widget obsahuje CircularProgressIndicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('LoadingWidget má správné centrum',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingWidget(),
          ),
        ),
      );

      // Ověří, že loading widget je ve středu
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('ErrorDialog Widget Tests', () {
    testWidgets('ErrorDialog zobrazí chybovou zprávu',
        (WidgetTester tester) async {
      const String errorMessage = 'Nastala chyba';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ErrorDialog.show(
                  context,
                  title: 'Chyba',
                  message: errorMessage,
                );
              },
              child: const Text('Zobrazit chybu'),
            ),
          ),
        ),
      );

      // Simulujeme kliknutí na tlačítko
      await tester.tap(find.text('Zobrazit chybu'));
      await tester.pumpAndSettle();

      // Ověří, že dialog obsahuje titulek, zprávu a tlačítko OK
      expect(find.text('Chyba'), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('ErrorDialog zavře po kliknutí na OK',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ErrorDialog.show(
                  context,
                  title: 'Chyba',
                  message: 'Test zpráva',
                );
              },
              child: const Text('Zobrazit chybu'),
            ),
          ),
        ),
      );

      // Zobrazíme dialog
      await tester.tap(find.text('Zobrazit chybu'));
      await tester.pumpAndSettle();

      // Klikneme na OK
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Ověříme, že dialog už není vidět
      expect(find.text('Test zpráva'), findsNothing);
    });

    testWidgets('ErrorDialog zobrazí vlastní akce',
        (WidgetTester tester) async {
      bool retryPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ErrorDialog.show(
                  context,
                  title: 'Chyba',
                  message: 'Vlastní chyba',
                  actions: [
                    TextButton(
                      onPressed: () {
                        retryPressed = true;
                        Navigator.of(context).pop();
                      },
                      child: const Text('Zkusit znovu'),
                    ),
                  ],
                );
              },
              child: const Text('Zobrazit s akcí'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Zobrazit s akcí'));
      await tester.pumpAndSettle();

      // Ověří, že dialog obsahuje vlastní tlačítko
      expect(find.text('Zkusit znovu'), findsOneWidget);

      // Klikneme na vlastní tlačítko
      await tester.tap(find.text('Zkusit znovu'));
      await tester.pumpAndSettle();

      // Ověříme, že byl callback zavolán
      expect(retryPressed, isTrue);
    });
  });
}

// ============================================================================
// POMOCNÉ WIDGETY PRO TESTY
// ============================================================================

/// Vlastní AppBar widget
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Loading widget s indikátorem
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

/// Error dialog pro zobrazení chyb
class ErrorDialog {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: actions ??
              [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
        );
      },
    );
  }
}
