// restore_backups.dart
// Obnoví všechny soubory ze záloh (.backup)
// Použij když oprava pokazila soubory!
//
// dart run restore_backups.dart

import 'dart:io';

void main() async {
  print('╔════════════════════════════════════════╗');
  print('║     OBNOVENÍ ZE ZÁLOH                  ║');
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
    print('❌ Žádné zálohy nenalezeny!');
    exit(0);
  }

  print('Nalezeno ${backups.length} záložních souborů.\n');
  print('⚠️  Obnovit všechny soubory ze záloh? (y/n): ');
  
  final input = stdin.readLineSync();
  if (input?.toLowerCase() != 'y') {
    print('Zrušeno.');
    exit(0);
  }

  var restored = 0;
  for (final backup in backups) {
    final originalPath = backup.path.replaceAll('.backup', '');
    final originalFile = File(originalPath);
    
    // Smaž upravený soubor
    if (originalFile.existsSync()) {
      await originalFile.delete();
    }
    
    // Přejmenuj zálohu zpět
    await backup.rename(originalPath);
    restored++;
    print('✅ ${originalPath.split(Platform.pathSeparator).last}');
  }

  print('\n✅ Obnoveno $restored souborů.');
  print('   Projekt je zpět v původním stavu.');
}
