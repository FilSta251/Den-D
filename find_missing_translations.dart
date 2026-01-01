// find_missing_translations.dart
// Spuštění: dart run find_missing_translations.dart
//
// Umísti tento soubor do kořene projektu a spusť

import 'dart:io';
import 'dart:convert';

void main() async {
  print('========================================');
  print('  DETEKCE CHYBĚJÍCÍCH PŘEKLADŮ');
  print('========================================\n');

  final libDir = Directory('lib');
  final translationsDir = Directory('assets/translations');

  if (!libDir.existsSync()) {
    print('CHYBA: Složka lib/ nebyla nalezena!');
    print('Spusť skript z kořene Flutter projektu.');
    exit(1);
  }

  // 1. Najdi všechny tr() klíče v Dart souborech
  print('Skenování Dart souborů...');
  final keys = <String>{};

  await for (final file in libDir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      
      // tr('key') nebo tr("key")
      final trMatches = RegExp(r'''tr\s*\(\s*['"]([\w\._]+)['"]''').allMatches(content);
      for (final match in trMatches) {
        if (match.group(1) != null) {
          keys.add(match.group(1)!);
        }
      }
      
      // 'key'.tr nebo "key".tr
      final extMatches = RegExp(r'''['"]([\w\._]+)['"]\s*\.tr''').allMatches(content);
      for (final match in extMatches) {
        if (match.group(1) != null) {
          keys.add(match.group(1)!);
        }
      }
      
      // plural('key', ...)
      final pluralMatches = RegExp(r'''plural\s*\(\s*['"]([\w\._]+)['"]''').allMatches(content);
      for (final match in pluralMatches) {
        if (match.group(1) != null) {
          keys.add(match.group(1)!);
        }
      }
    }
  }

  final sortedKeys = keys.toList()..sort();
  print('Nalezeno ${sortedKeys.length} unikátních překladových klíčů\n');

  // 2. Zkontroluj každý JSON soubor
  if (!translationsDir.existsSync()) {
    print('VAROVÁNÍ: Složka assets/translations/ nenalezena');
    print('Zkontroluj cestu k překladům\n');
    
    // Vypíš alespoň všechny nalezené klíče
    print('Nalezené klíče:');
    for (final key in sortedKeys) {
      print('  - $key');
    }
    exit(0);
  }

  final jsonFiles = translationsDir.listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  final allMissing = <String, List<String>>{};

  for (final jsonFile in jsonFiles) {
    final lang = jsonFile.path.split(Platform.pathSeparator).last.replaceAll('.json', '');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('  Jazyk: $lang');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final content = await jsonFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      
      // Flatten nested keys
      final flatKeys = <String>{};
      void flattenJson(Map<String, dynamic> map, [String prefix = '']) {
        for (final entry in map.entries) {
          final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
          if (entry.value is Map<String, dynamic>) {
            flattenJson(entry.value as Map<String, dynamic>, key);
          } else {
            flatKeys.add(key);
          }
          // Také přidej samotný klíč bez prefixu pro vnořené objekty
          flatKeys.add(entry.key);
        }
      }
      flattenJson(json);

      final missing = <String>[];
      for (final key in sortedKeys) {
        if (!flatKeys.contains(key)) {
          // Zkus najít jako vnořený klíč
          bool found = false;
          if (key.contains('.')) {
            final parts = key.split('.');
            dynamic current = json;
            for (final part in parts) {
              if (current is Map && current.containsKey(part)) {
                current = current[part];
                found = true;
              } else {
                found = false;
                break;
              }
            }
          }
          if (!found) {
            missing.add(key);
          }
        }
      }

      if (missing.isEmpty) {
        print('✓ Všechny klíče jsou přeloženy\n');
      } else {
        print('✗ Chybí ${missing.length} klíčů:');
        for (final key in missing) {
          print('  - $key');
        }
        print('');
        allMissing[lang] = missing;
      }
    } catch (e) {
      print('CHYBA při čtení $lang.json: $e\n');
    }
  }

  // 3. Souhrn
  if (allMissing.isNotEmpty) {
    print('\n========================================');
    print('  SOUHRN CHYBĚJÍCÍCH KLÍČŮ');
    print('========================================\n');
    
    // Najdi klíče které chybí ve všech jazycích
    final commonMissing = allMissing.values
        .fold<Set<String>>(
          allMissing.values.first.toSet(),
          (a, b) => a.intersection(b.toSet()),
        )
        .toList()
      ..sort();

    if (commonMissing.isNotEmpty) {
      print('Chybí ve VŠECH jazycích (${commonMissing.length}):');
      for (final key in commonMissing) {
        print('  - $key');
      }
    }
  }

  print('\nHotovo!');
}
