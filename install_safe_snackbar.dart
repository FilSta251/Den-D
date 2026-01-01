// install_safe_snackbar.dart
// Kompletní řešení:
// 1. Vytvoří SafeSnackBar helper v lib/utils/
// 2. Automaticky nahradí SnackBar volání
// 3. Přidá importy
//
// Spuštění: dart run install_safe_snackbar.dart

import 'dart:io';

const safeSnackBarCode = '''
// safe_snackbar.dart
// Bezpečný SnackBar s ochranou proti overflow

import 'package:flutter/material.dart';

class SafeSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    Color? backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void error(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.red.shade700);
  }

  static void success(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.green.shade700);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.orange.shade700);
  }

  static void info(BuildContext context, String message) {
    show(context, message, backgroundColor: Colors.blue.shade700);
  }
}
''';

void main() async {
  print('╔════════════════════════════════════════════════════════════╗');
  print('║     INSTALACE SAFESNACKBAR                                 ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ CHYBA: Složka lib/ nenalezena!');
    exit(1);
  }

  // 1. Vytvoř utils složku pokud neexistuje
  final utilsDir = Directory('lib/utils');
  if (!utilsDir.existsSync()) {
    await utilsDir.create(recursive: true);
    print('📁 Vytvořena složka lib/utils/');
  }

  // 2. Vytvoř SafeSnackBar soubor
  final safeSnackBarFile = File('lib/utils/safe_snackbar.dart');
  if (!safeSnackBarFile.existsSync()) {
    await safeSnackBarFile.writeAsString(safeSnackBarCode);
    print('✅ Vytvořen lib/utils/safe_snackbar.dart');
  } else {
    print('ℹ️  lib/utils/safe_snackbar.dart již existuje');
  }

  // 3. Najdi soubory s SnackBar
  print('\n🔍 Hledám SnackBar volání...\n');

  final filesToFix = <String, int>{};
  
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.contains('safe_snackbar.dart')) continue;
    
    final content = await entity.readAsString();
    
    // Počítej SnackBar bez maxLines
    final snackBarMatches = RegExp(r'SnackBar\(').allMatches(content);
    var needsFix = 0;
    
    for (final match in snackBarMatches) {
      final after = content.substring(match.start, (match.start + 300).clamp(0, content.length));
      if (!after.contains('maxLines')) {
        needsFix++;
      }
    }
    
    if (needsFix > 0) {
      filesToFix[entity.path] = needsFix;
    }
  }

  if (filesToFix.isEmpty) {
    print('✅ Všechny SnackBar jsou již opraveny!\n');
    exit(0);
  }

  print('Soubory k opravě:');
  for (final entry in filesToFix.entries) {
    print('  ${entry.key.split(Platform.pathSeparator).last}: ${entry.value} SnackBar');
  }
  print('\nCelkem: ${filesToFix.values.reduce((a, b) => a + b)} SnackBar\n');

  print('Chceš nahradit SnackBar voláním SafeSnackBar.show()? (y/n): ');
  final input = stdin.readLineSync();
  if (input?.toLowerCase() != 'y') {
    print('\nMůžeš to udělat ručně v VS Code:');
    print('1. Otevři soubor');
    print('2. Najdi SnackBar(content: Text(...)');
    print('3. Nahraď za SafeSnackBar.show(context, ...)');
    print('4. Přidej import: import \'package:svatebni_planovac/utils/safe_snackbar.dart\';');
    exit(0);
  }

  // 4. Nahraď SnackBar volání
  var totalReplaced = 0;
  var filesModified = 0;

  for (final filePath in filesToFix.keys) {
    final file = File(filePath);
    var content = await file.readAsString();
    final original = content;
    var replaced = 0;

    // Záloha
    await file.copy('$filePath.backup');

    // Pattern 1: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('...')))
    final pattern1 = RegExp(
      r'''ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(\s*([^\)]+)\s*\)\s*,?\s*\)\s*,?\s*\)''',
      multiLine: true,
    );
    
    content = content.replaceAllMapped(pattern1, (match) {
      final textArg = match.group(1)!.trim();
      if (textArg.contains('maxLines')) return match.group(0)!;
      replaced++;
      return 'SafeSnackBar.show(context, $textArg)';
    });

    // Pattern 2: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...), ...))
    // Složitější případy - necháme na ruční opravu

    // Přidej import pokud byl nějaký replacement
    if (replaced > 0 && !content.contains("import 'package:svatebni_planovac/utils/safe_snackbar.dart'")) {
      // Najdi poslední import
      final lastImport = content.lastIndexOf(RegExp(r"import '.*';"));
      if (lastImport != -1) {
        final endOfImport = content.indexOf(';', lastImport) + 1;
        content = content.substring(0, endOfImport) +
            "\nimport 'package:svatebni_planovac/utils/safe_snackbar.dart';" +
            content.substring(endOfImport);
      }
    }

    if (content != original) {
      await file.writeAsString(content);
      filesModified++;
      totalReplaced += replaced;
      print('✅ ${filePath.split(Platform.pathSeparator).last} - nahrazeno $replaced');
    }
  }

  print('\n════════════════════════════════════════════════════════════');
  print('HOTOVO');
  print('════════════════════════════════════════════════════════════');
  print('Nahrazeno: $totalReplaced SnackBar');
  print('Souborů: $filesModified');
  print('');
  print('Zálohy: .backup soubory');
  print('Obnovení: dart run restore_backups.dart');
  print('');
  print('⚠️  Některé složitější SnackBar nebyly nahrazeny.');
  print('   Spusť: flutter analyze');
  print('   a oprav zbývající ručně.');
}
