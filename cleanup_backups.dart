// cleanup_backups.dart
// Smaže všechny .backup soubory vytvořené fix_all_overflow.dart
//
// Spusť AŽ PO OTESTOVÁNÍ že vše funguje!
// dart run cleanup_backups.dart

import 'dart:io';

void main() async {
  print('╔════════════════════════════════════════╗');
  print('║     SMAZÁNÍ ZÁLOŽNÍCH SOUBORŮ          ║');
  print('╚════════════════════════════════════════╝\n');

  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ Složka lib/ nenalezena!');
    exit(1);
  }

  final backups = <File>[];
  
  await for (final file in libDir.list(recursive: true)) {
    if (file is File && file.path.endsWith('.backup')) {
      backups.add(file);
    }
  }

  if (backups.isEmpty) {
    print('✅ Žádné zálohy nenalezeny.');
    exit(0);
  }

  print('Nalezeno ${backups.length} záložních souborů:\n');
  for (final backup in backups) {
    print('  - ${backup.path.split(Platform.pathSeparator).last}');
  }

  print('\n⚠️  Opravdu smazat všechny zálohy? (y/n): ');
  final input = stdin.readLineSync();
  
  if (input?.toLowerCase() != 'y') {
    print('Zrušeno.');
    exit(0);
  }

  for (final backup in backups) {
    await backup.delete();
  }

  print('\n✅ Smazáno ${backups.length} záložních souborů.');
}
