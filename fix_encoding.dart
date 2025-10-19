// fix_encoding.dart
import 'dart:io';

void main() async {
  final directory = Directory('lib');
  final files = directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  int fixedFiles = 0;

  for (final file in files) {
    try {
      String content = await file.readAsString();
      String originalContent = content;

      // České znaky - základní
      content = content.replaceAll('Ã¡', 'á');
      content = content.replaceAll('Ã©', 'é');
      content = content.replaceAll('Ã­', 'í');
      content = content.replaceAll('Ã³', 'ó');
      content = content.replaceAll('Ãº', 'ú');
      content = content.replaceAll('Ã½', 'ý');
      content = content.replaceAll('Ä›', 'ě');
      content = content.replaceAll('Å¡', 'š');
      content = content.replaceAll('Ä', 'č');
      content = content.replaceAll('Å™', 'ř');
      content = content.replaceAll('Å¾', 'ž');
      content = content.replaceAll('Å¯', 'ů');

      // České znaky - velká písmena
      content = content.replaceAll('Ã', 'Á');
      content = content.replaceAll('Ã‰', 'É');
      content = content.replaceAll('Ã', 'Í');
      content = content.replaceAll('Ãš', 'Ú');
      content = content.replaceAll('Ã', 'Ý');
      content = content.replaceAll('Äš', 'Ě');
      content = content.replaceAll('Å ', 'Š');
      content = content.replaceAll('Ä', 'Č');
      content = content.replaceAll('Å˜', 'Ř');
      content = content.replaceAll('Å½', 'Ž');
      content = content.replaceAll('Å®', 'Ů');

      // Další české znaky
      content = content.replaceAll('ÄŒ', 'Č');
      content = content.replaceAll('Å¥', 'ť');
      content = content.replaceAll('Ä', 'ď');
      content = content.replaceAll('Åˆ', 'ň');
      content = content.replaceAll('Ä¹', 'ľ');
      content = content.replaceAll('Å¤', 'Ť');
      content = content.replaceAll('ÄŽ', 'Ď');
      content = content.replaceAll('Å‡', 'Ň');
      content = content.replaceAll('Ä½', 'Ľ');

      // Problematické znaky - vynecháme ty co dělají problémy
      // content = content.replaceAll('Ã'', 'Ñ'); // španělské Ñ
      // content = content.replaceAll('Å'', 'Œ'); // francouzské Œ
      // content = content.replaceAll('Ò'', 'ґ'); // ukrajinské ґ

      // Německé znaky
      content = content.replaceAll('Ã¤', 'ä');
      content = content.replaceAll('Ã¶', 'ö');
      content = content.replaceAll('Ã¼', 'ü');
      content = content.replaceAll('ÃŸ', 'ß');
      content = content.replaceAll('Ã„', 'Ä');
      content = content.replaceAll('Ã–', 'Ö');
      content = content.replaceAll('Ãœ', 'Ü');

      // Francouzské znaky
      content = content.replaceAll('Ã ', 'à');
      content = content.replaceAll('Ã¨', 'è');
      content = content.replaceAll('Ã¹', 'ù');
      content = content.replaceAll('Ã¢', 'â');
      content = content.replaceAll('Ãª', 'ê');
      content = content.replaceAll('Ã®', 'î');
      content = content.replaceAll('Ã´', 'ô');
      content = content.replaceAll('Ã»', 'û');
      content = content.replaceAll('Ã§', 'ç');
      content = content.replaceAll('Ã¿', 'ÿ');
      content = content.replaceAll('Ã¦', 'æ');
      content = content.replaceAll('Å"', 'œ');
      content = content.replaceAll('Ã€', 'À');
      content = content.replaceAll('Ãˆ', 'È');
      content = content.replaceAll('Ã™', 'Ù');
      content = content.replaceAll('Ã‚', 'Â');
      content = content.replaceAll('ÃŠ', 'Ê');
      content = content.replaceAll('ÃŽ', 'Î');
      content = content.replaceAll('Ã›', 'Û');
      content = content.replaceAll('Ã‡', 'Ç');
      content = content.replaceAll('Å¸', 'Ÿ');
      content = content.replaceAll('Ã†', 'Æ');

      // Polské znaky
      content = content.replaceAll('Ä…', 'ą');
      content = content.replaceAll('Ä™', 'ę');
      content = content.replaceAll('Å‚', 'ł');
      content = content.replaceAll('Å„', 'ń');
      content = content.replaceAll('Å›', 'ś');
      content = content.replaceAll('Åº', 'ź');
      content = content.replaceAll('Å¼', 'ż');
      content = content.replaceAll('Ä„', 'Ą');
      content = content.replaceAll('Ä˜', 'Ę');
      content = content.replaceAll('Å', 'Ł');
      content = content.replaceAll('Åƒ', 'Ń');
      content = content.replaceAll('Åš', 'Ś');
      content = content.replaceAll('Å¹', 'Ź');
      content = content.replaceAll('Å»', 'Ż');

      // Speciální znaky - používáme Unicode escape sekvence
      content = content.replaceAll('â€™', "'"); // apostrof
      content = content.replaceAll('â€œ', '"'); // levé uvozovky
      content = content.replaceAll('â€', '"'); // pravé uvozovky
      content = content.replaceAll('â€"', '–'); // en dash
      content = content.replaceAll('â€"', '—'); // em dash
      content = content.replaceAll('â€¦', '...'); // trojtečka
      content = content.replaceAll('â€¢', '•'); // odrážka

      // Symboly
      content = content.replaceAll('Â©', '©');
      content = content.replaceAll('Â®', '®');
      content = content.replaceAll('â„¢', '™');
      content = content.replaceAll('Â°', '°');
      content = content.replaceAll('â‚¬', '€');
      content = content.replaceAll('Â£', '£');
      content = content.replaceAll('Â¥', '¥');
      content = content.replaceAll('Â§', '§');
      content = content.replaceAll('Â¶', '¶');

      // Matematické symboly
      content = content.replaceAll('Ã—', '×');
      content = content.replaceAll('Ã·', '÷');
      content = content.replaceAll('Â±', '±');

      // Mezery
      content = content.replaceAll('Â ', ' ');

      // Další časté chyby
      content = content.replaceAll('Ãƒ', 'Ã');
      content = content.replaceAll('Ã‚', 'Â');

      // Časté kombinace pro češtinu
      content = content.replaceAll('ÄÅ™', 'čř');
      content = content.replaceAll('nÄ›', 'ně');
      content = content.replaceAll('vÄ›', 'vě');
      content = content.replaceAll('dÄ›', 'dě');
      content = content.replaceAll('tÄ›', 'tě');
      content = content.replaceAll('mÄ›', 'mě');
      content = content.replaceAll('bÄ›', 'bě');
      content = content.replaceAll('pÄ›', 'pě');

      // Často poškozené slova
      content = content.replaceAll('pÅ™', 'př');
      content = content.replaceAll('tÅ™', 'tř');
      content = content.replaceAll('dÅ™', 'dř');
      content = content.replaceAll('kÅ™', 'kř');
      content = content.replaceAll('vÅ™', 'vř');
      content = content.replaceAll('stÅ™', 'stř');
      content = content.replaceAll('Å™e', 'ře');
      content = content.replaceAll('Å™i', 'ři');
      content = content.replaceAll('Å™a', 'řa');

      if (content != originalContent) {
        await file.writeAsString(content);
        fixedFiles++;
        print('Fixed: ${file.path}');
      }
    } catch (e) {
      print('Error processing ${file.path}: $e');
    }
  }

  print('\n=============================');
  print('Fixed $fixedFiles files');
  print('=============================');
}
