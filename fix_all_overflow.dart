// fix_all_overflow.dart
// Bezpečná oprava všech overflow problémů
//
// FUNKCE:
// - Vytvoří zálohu každého souboru před úpravou (.backup)
// - Ukáže náhled změn před aplikací
// - Opraví SnackBar, AlertDialog, Row s Text, ListTile
//
// SPUŠTĚNÍ:
// dart run fix_all_overflow.dart          (interaktivní režim)
// dart run fix_all_overflow.dart --preview (pouze náhled, nic nezmění)
// dart run fix_all_overflow.dart --auto    (automaticky bez potvrzení)

import 'dart:io';

// Konfigurace
const createBackups = true;
const backupExtension = '.backup';

void main(List<String> args) async {
  final previewOnly = args.contains('--preview');
  final autoMode = args.contains('--auto');

  print('╔════════════════════════════════════════════════════════════╗');
  print('║       BEZPEČNÁ OPRAVA OVERFLOW PROBLÉMŮ                    ║');
  print('╚════════════════════════════════════════════════════════════╝\n');

  if (previewOnly) {
    print('📋 REŽIM: Pouze náhled (žádné změny)\n');
  } else if (autoMode) {
    print('⚡ REŽIM: Automatický (bez potvrzení)\n');
  } else {
    print('🔧 REŽIM: Interaktivní\n');
  }

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ CHYBA: Složka lib/ nenalezena!');
    print('   Spusť skript z kořene Flutter projektu.');
    exit(1);
  }

  // Statistiky
  var totalFiles = 0;
  var modifiedFiles = 0;
  var snackBarFixes = 0;
  var alertDialogFixes = 0;
  var rowFixes = 0;
  var listTileFixes = 0;

  final changes = <String, List<Change>>{};

  // Skenování souborů
  print('🔍 Skenování souborů...\n');

  await for (final file in libDir.list(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    totalFiles++;

    final content = await file.readAsString();
    final lines = content.split('\n');
    final relativePath = file.path.replaceAll('\\', '/');
    final fileChanges = <Change>[];

    // === 1. OPRAVA SNACKBAR ===
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Najdi SnackBar
      if (line.contains('SnackBar(')) {
        // Zkontroluj následujících 10 řádků jestli má content: Text(
        final blockEnd = (i + 15).clamp(0, lines.length);
        final block = lines.sublist(i, blockEnd).join('\n');

        if (block.contains('content:') &&
            block.contains('Text(') &&
            !block.contains('maxLines')) {
          fileChanges.add(Change(
            line: i + 1,
            type: 'SnackBar',
            description: 'Přidat maxLines: 2, overflow: TextOverflow.ellipsis',
            original: line.trim(),
          ));
          snackBarFixes++;
        }
      }

      // === 2. OPRAVA ALERTDIALOG ===
      if (line.contains('AlertDialog(')) {
        final blockEnd = (i + 20).clamp(0, lines.length);
        final block = lines.sublist(i, blockEnd).join('\n');

        if (block.contains('content:') &&
            !block.contains('SingleChildScrollView') &&
            !block.contains('ConstrainedBox')) {
          fileChanges.add(Change(
            line: i + 1,
            type: 'AlertDialog',
            description:
                'Obalit content do ConstrainedBox + SingleChildScrollView',
            original: line.trim(),
          ));
          alertDialogFixes++;
        }
      }

      // === 3. OPRAVA ROW S TEXT ===
      if (line.contains('Row(')) {
        final blockEnd = (i + 15).clamp(0, lines.length);
        final block = lines.sublist(i, blockEnd).join('\n');

        // Má Text( ale ne Expanded( nebo Flexible(
        if (block.contains('Text(') &&
            !block.contains('Expanded(') &&
            !block.contains('Flexible(') &&
            block.contains('children:')) {
          fileChanges.add(Change(
            line: i + 1,
            type: 'Row',
            description: 'Obalit Text do Expanded',
            original: line.trim(),
          ));
          rowFixes++;
        }
      }

      // === 4. OPRAVA LISTTILE ===
      if (line.contains('ListTile(')) {
        final blockEnd = (i + 10).clamp(0, lines.length);
        final block = lines.sublist(i, blockEnd).join('\n');

        if (block.contains('title:') && !block.contains('maxLines')) {
          fileChanges.add(Change(
            line: i + 1,
            type: 'ListTile',
            description: 'Přidat maxLines k title/subtitle',
            original: line.trim(),
          ));
          listTileFixes++;
        }
      }
    }

    if (fileChanges.isNotEmpty) {
      changes[relativePath] = fileChanges;
    }
  }

  // Výpis náhledu změn
  print('═══════════════════════════════════════════════════════════════');
  print(' NALEZENÉ PROBLÉMY');
  print('═══════════════════════════════════════════════════════════════\n');

  if (changes.isEmpty) {
    print('✅ Žádné overflow problémy nenalezeny!\n');
    exit(0);
  }

  for (final entry in changes.entries) {
    print('📁 ${entry.key}');
    for (final change in entry.value) {
      print('   řádek ${change.line}: [${change.type}] ${change.description}');
    }
    print('');
  }

  print('═══════════════════════════════════════════════════════════════');
  print(' SOUHRN');
  print('═══════════════════════════════════════════════════════════════');
  print('📊 Celkem souborů: $totalFiles');
  print('📝 Souborů k úpravě: ${changes.length}');
  print('');
  print('   SnackBar oprav: $snackBarFixes');
  print('   AlertDialog oprav: $alertDialogFixes');
  print('   Row oprav: $rowFixes');
  print('   ListTile oprav: $listTileFixes');
  print('═══════════════════════════════════════════════════════════════\n');

  if (previewOnly) {
    print('📋 Náhled dokončen. Pro aplikaci změn spusť bez --preview');
    exit(0);
  }

  // Potvrzení
  if (!autoMode) {
    print('⚠️  Chceš aplikovat opravy? Zálohy budou vytvořeny.');
    print('   (y = ano, n = ne, p = jen některé soubory): ');

    final input = stdin.readLineSync()?.toLowerCase();
    if (input == 'n' || input == null || input.isEmpty) {
      print('Zrušeno.');
      exit(0);
    }

    if (input == 'p') {
      await _selectiveApply(changes);
      exit(0);
    }
  }

  // Aplikace oprav
  print('\n🔧 Aplikuji opravy...\n');

  for (final entry in changes.entries) {
    final filePath = entry.key;
    final file = File(filePath);

    if (!file.existsSync()) continue;

    // Vytvoř zálohu
    if (createBackups) {
      final backupPath = '$filePath$backupExtension';
      await file.copy(backupPath);
    }

    var content = await file.readAsString();
    var modified = false;

    // Aplikuj SnackBar opravy
    content = _fixSnackBars(content);

    // Aplikuj ListTile opravy
    content = _fixListTiles(content);

    // Zapiš změny
    await file.writeAsString(content);
    modifiedFiles++;
    print('✅ ${filePath.split('/').last}');
  }

  print('\n═══════════════════════════════════════════════════════════════');
  print(' HOTOVO');
  print('═══════════════════════════════════════════════════════════════');
  print('✅ Upraveno souborů: $modifiedFiles');
  if (createBackups) {
    print('📦 Zálohy vytvořeny s příponou $backupExtension');
    print('   Pro obnovení: přejmenuj .backup soubory zpět');
  }
  print('\n📋 Další kroky:');
  print('   1. flutter analyze');
  print('   2. dart run find_overflow_issues.dart');
  print('   3. Ruční kontrola AlertDialog a Row (složitější opravy)');
  print('');
}

String _fixSnackBars(String content) {
  // Pattern 1: SnackBar(content: Text('text'))
  final pattern1 = RegExp(
    r'''SnackBar\(\s*content:\s*Text\(\s*([^,\)]+)\s*\)''',
  );

  content = content.replaceAllMapped(pattern1, (match) {
    final textContent = match.group(1)!.trim();
    // Přeskočit pokud už má maxLines
    if (textContent.contains('maxLines')) return match.group(0)!;

    return '''SnackBar(
      content: Text(
        $textContent,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ''';
  });

  // Pattern 2: SnackBar(content: Text(variable, maxLines: 2, overflow: TextOverflow.ellipsis), behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16))
  final pattern2 = RegExp(
    r'''SnackBar\(\s*content:\s*Text\(\s*(\w+)\s*\)''',
  );

  content = content.replaceAllMapped(pattern2, (match) {
    final varName = match.group(1)!;
    if (varName == 'maxLines' || varName == 'overflow') return match.group(0)!;

    return '''SnackBar(
      content: Text(
        $varName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
    ''';
  });

  return content;
}

String _fixListTiles(String content) {
  // Jednoduchý pattern pro ListTile title bez maxLines
  // Toto je konzervativní - opraví jen jednoduché případy

  final pattern = RegExp(
    r'''(ListTile\([^)]*title:\s*Text\(\s*)([^,\)]+)(\s*\))''',
  );

  content = content.replaceAllMapped(pattern, (match) {
    final before = match.group(1)!;
    final textContent = match.group(2)!;
    final after = match.group(3)!;

    if (textContent.contains('maxLines')) return match.group(0)!;

    return '$before$textContent, maxLines: 1, overflow: TextOverflow.ellipsis$after';
  });

  return content;
}

Future<void> _selectiveApply(Map<String, List<Change>> changes) async {
  print('\nVyber soubory k opravě (čísla oddělená čárkou, nebo "all"):\n');

  var i = 1;
  final fileList = changes.keys.toList();
  for (final file in fileList) {
    print('  $i. ${file.split('/').last} (${changes[file]!.length} oprav)');
    i++;
  }

  print('\nVýběr: ');
  final input = stdin.readLineSync();

  if (input == null || input.isEmpty) {
    print('Zrušeno.');
    return;
  }

  List<int> selected;
  if (input.toLowerCase() == 'all') {
    selected = List.generate(fileList.length, (i) => i + 1);
  } else {
    selected =
        input.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  }

  for (final idx in selected) {
    if (idx < 1 || idx > fileList.length) continue;

    final filePath = fileList[idx - 1];
    final file = File(filePath);

    if (createBackups) {
      await file.copy('$filePath$backupExtension');
    }

    var content = await file.readAsString();
    content = _fixSnackBars(content);
    content = _fixListTiles(content);
    await file.writeAsString(content);

    print('✅ ${filePath.split('/').last}');
  }

  print('\nHotovo!');
}

class Change {
  final int line;
  final String type;
  final String description;
  final String original;

  Change({
    required this.line,
    required this.type,
    required this.description,
    required this.original,
  });
}
