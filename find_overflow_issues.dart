// find_overflow_issues.dart
// Spuštění: dart run find_overflow_issues.dart
//
// Umísti tento soubor do kořene projektu a spusť

import 'dart:io';

void main() async {
  print('========================================');
  print('  DETEKCE OVERFLOW PROBLÉMŮ');
  print('========================================\n');

  final libDir = Directory('lib');

  if (!libDir.existsSync()) {
    print('CHYBA: Složka lib/ nebyla nalezena!');
    print('Spusť skript z kořene Flutter projektu.');
    exit(1);
  }

  final issues = <String, List<String>>{};

  await for (final file in libDir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = await file.readAsString();
      final lines = content.split('\n');
      final relativePath = file.path.replaceAll('\\', '/');
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNum = i + 1;
        
        // 1. SnackBar bez overflow handling
        if (line.contains('SnackBar(') && !_hasNearby(lines, i, 'maxLines', 5)) {
          _addIssue(issues, relativePath, lineNum, 'SnackBar bez maxLines/overflow');
        }
        
        // 2. AlertDialog content bez scroll
        if (line.contains('AlertDialog(') && 
            !_hasNearby(lines, i, 'SingleChildScrollView', 15) &&
            !_hasNearby(lines, i, 'ConstrainedBox', 15)) {
          _addIssue(issues, relativePath, lineNum, 'AlertDialog možná bez scroll/constraints');
        }
        
        // 3. Text v Row bez Expanded/Flexible
        if (line.contains('Row(')) {
          final rowEnd = _findClosingBracket(lines, i);
          if (rowEnd != null) {
            final rowContent = lines.sublist(i, rowEnd + 1).join('\n');
            if (rowContent.contains('Text(') && 
                !rowContent.contains('Expanded(') && 
                !rowContent.contains('Flexible(')) {
              _addIssue(issues, relativePath, lineNum, 'Row s Text bez Expanded/Flexible');
            }
          }
        }
        
        // 4. ListTile title bez overflow
        if (line.contains('ListTile(')) {
          final tileEnd = _findClosingBracket(lines, i);
          if (tileEnd != null) {
            final tileContent = lines.sublist(i, tileEnd + 1).join('\n');
            if (tileContent.contains('title:') && !tileContent.contains('maxLines')) {
              _addIssue(issues, relativePath, lineNum, 'ListTile title možná bez maxLines');
            }
          }
        }
      }
    }
  }

  // Výpis výsledků
  if (issues.isEmpty) {
    print('✓ Žádné zjevné overflow problémy nenalezeny!\n');
  } else {
    int totalIssues = 0;
    for (final entry in issues.entries) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📁 ${entry.key}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      for (final issue in entry.value) {
        print('  $issue');
        totalIssues++;
      }
      print('');
    }
    
    print('========================================');
    print('  CELKEM: $totalIssues potenciálních problémů');
    print('========================================\n');
  }

  print('DOPORUČENÍ PRO OPRAVU:');
  print('───────────────────────────────────────');
  print('1. SnackBar: přidej maxLines: 2, overflow: TextOverflow.ellipsis');
  print('2. AlertDialog: obal content do ConstrainedBox + SingleChildScrollView');
  print('3. Row s Text: obal Text do Expanded nebo Flexible');
  print('4. ListTile: přidej maxLines a overflow k title/subtitle');
  print('5. Dlouhé texty: vždy přidej maxLines a overflow');
  print('');
}

void _addIssue(Map<String, List<String>> issues, String file, int line, String desc) {
  issues.putIfAbsent(file, () => []);
  issues[file]!.add('řádek $line: $desc');
}

bool _hasNearby(List<String> lines, int start, String search, int range) {
  final end = (start + range).clamp(0, lines.length);
  for (int i = start; i < end; i++) {
    if (lines[i].contains(search)) return true;
  }
  return false;
}

int? _findClosingBracket(List<String> lines, int start) {
  int depth = 0;
  for (int i = start; i < lines.length && i < start + 50; i++) {
    for (final char in lines[i].split('')) {
      if (char == '(') depth++;
      if (char == ')') depth--;
      if (depth == 0 && i > start) return i;
    }
  }
  return null;
}
