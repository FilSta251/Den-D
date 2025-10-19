// tool/auto_localize_hardcoded.dart
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final isDryRun = args.contains('--dry-run');
  final filteredArgs = args.where((a) => a != '--dry-run').toList();

  final projectRoot = Directory.current.path;
  final sourceDirPath = filteredArgs.isNotEmpty
      ? filteredArgs[0]
      : '$projectRoot${Platform.pathSeparator}lib';

  final sourceDir = Directory(sourceDirPath);
  if (!sourceDir.existsSync()) {
    stderr.writeln('❌ Source directory not found: $sourceDirPath');
    exit(1);
  }

  // --- Report datové struktury (nic se nepíše do cs.json)
  final suggestedKeys = <String, _Suggestion>{}; // key -> suggestion
  final converted = <_Usage>[];
  final skippedWithInterpolation = <_Usage>[];

  // Regexy
  final alreadyTrLine = RegExp(
      r"""(?:^|[^A-Za-z0-9_])(?:tr|safeTr)\s*\(\s*['"][^'"]+['"]\s*\)|['"][^'"]+['"]\s*\.tr\s*\(""");

  final patterns = <_Pattern>[
    _Pattern(
      name: "Text(...)",
      re: RegExp(r"""Text\s*\(\s*(['"])((?:\\.|(?!\1).)*)\1"""),
      replaceLiteralOnly: true,
    ),
    _Pattern(
      name: "namedParam",
      re: RegExp(
          r"""(?:labelText|hintText|helperText|errorText|title|subtitle|tooltip|semanticsLabel|screenReaderLabel|ariaLabel)\s*:\s*(['"])((?:\\.|(?!\1).)*)\1"""),
      replaceLiteralOnly: true,
    ),
    _Pattern(
      name: "child: Text(...)",
      re: RegExp(r"""child\s*:\s*Text\s*\(\s*(['"])((?:\\.|(?!\1).)*)\1"""),
      replaceLiteralOnly: true,
    ),
    _Pattern(
      name: "SnackBar(content: Text(...))",
      re: RegExp(
          r"""SnackBar\s*\(\s*content\s*:\s*Text\s*\(\s*(['"])((?:\\.|(?!\1).)*)\1"""),
      replaceLiteralOnly: true,
    ),
    _Pattern(
      name: "AppBar(title: Text(...))",
      re: RegExp(
          r"""AppBar\s*\(\s*title\s*:\s*Text\s*\(\s*(['"])((?:\\.|(?!\1).)*)\1"""),
      replaceLiteralOnly: true,
    ),
  ];

  final dartFiles = sourceDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  stdout.writeln('📁 Source: $sourceDirPath');
  stdout.writeln('🗂  Files to scan: ${dartFiles.length}');
  if (isDryRun) stdout.writeln('🔎 Mode: DRY-RUN (žádné změny souborů)\n');

  int filesChanged = 0;

  for (final file in dartFiles) {
    final original = file.readAsStringSync();
    var changed = false;

    final lines = original.split('\n');
    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];

      if (alreadyTrLine.hasMatch(line)) continue;

      for (final pat in patterns) {
        final matches = pat.re.allMatches(line).toList();
        if (matches.isEmpty) continue;

        int lastIndex = 0;
        final sb = StringBuffer();

        for (final m in matches) {
          sb.write(line.substring(lastIndex, m.start));

          final quote = m.group(1)!;
          final raw = m.group(2)!;
          final text = _unescapeDartString(raw);

          if (!_looksLikeTranslatable(text) ||
              _hasInterpolation(text) ||
              line.contains(r'${')) {
            // ponech beze změny + report případně interpolace
            if (_hasInterpolation(text) || line.contains(r'${')) {
              skippedWithInterpolation
                  .add(_Usage(file.path, i + 1, text, context: pat.name));
            }
            sb.write(line.substring(m.start, m.end));
            lastIndex = m.end;
            continue;
          }

          final fileStem = _fileStem(file.path);
          final key =
              _buildStableKey(fileStem, text, suggestedKeys.keys.toSet());

          // jen navrhneme (nepíšeme do cs.json)
          suggestedKeys.putIfAbsent(
            key,
            () => _Suggestion(
              key: key,
              value: text,
              examples: [_Usage(file.path, i + 1, text, context: pat.name)],
            ),
          );

          // nahradíme pouze literál "'...'" → "'key'.tr()"
          final replacedLiteral = "$quote$key$quote.tr()";
          final whole = line.substring(m.start, m.end);
          final qm =
              RegExp(r"""(['"])((?:\\.|(?!\1).)*)\1""").firstMatch(whole);

          if (qm != null) {
            final before = whole.substring(0, qm.start);
            final after = whole.substring(qm.end);
            sb.write(before + replacedLiteral + after);
            changed = true;
            converted.add(_Usage(file.path, i + 1, text, context: pat.name));
          } else {
            sb.write(line.substring(m.start, m.end)); // fallback
          }

          lastIndex = m.end;
        }

        sb.write(line.substring(lastIndex));
        line = sb.toString();
      }

      lines[i] = line;
    }

    if (changed && !isDryRun) {
      final bak = File('${file.path}.bak');
      if (!bak.existsSync()) {
        bak.writeAsStringSync(original);
      }
      File(file.path).writeAsStringSync(lines.join('\n'));
      filesChanged++;
    }
  }

  // Ulož report se seznamem navržených klíčů (bez zásahů do cs.json)
  final report = {
    'summary': {
      'files_scanned': dartFiles.length,
      'files_changed': isDryRun ? 0 : filesChanged,
      'converted_texts': converted.length,
      'skipped_interpolations': skippedWithInterpolation.length,
    },
    'suggested_keys': suggestedKeys.values
        .map((s) => {
              'key': s.key,
              'value': s.value,
              'examples': s.examples
                  .map((e) => {
                        'file': e.path,
                        'line': e.line,
                        'context': e.context,
                        'text': e.snippet,
                      })
                  .toList(),
            })
        .toList(),
    'skipped_interpolations': skippedWithInterpolation
        .map((u) => {
              'file': u.path,
              'line': u.line,
              'context': u.context,
              'text': u.snippet,
            })
        .toList(),
  };

  final reportPath = 'tool${Platform.pathSeparator}auto_localize_report.json';
  final pretty = const JsonEncoder.withIndent('  ').convert(report);

  if (!isDryRun) {
    File(reportPath).writeAsStringSync('$pretty\n');
  }

  // Konzolový souhrn
  stdout.writeln('\n✅ Hotovo.');
  stdout.writeln('✏️  Upravené soubory: ${isDryRun ? 0 : filesChanged}');
  stdout.writeln('🟢 Automaticky převedených textů: ${converted.length}');
  stdout.writeln(
      '🟡 Přeskočeno kvůli interpolaci \${...}: ${skippedWithInterpolation.length}');
  stdout.writeln(
      '🧾 Report: ${isDryRun ? "(dry-run → pouze konzole)" : reportPath}');

  // Krátce navržené klíče do konzole (pro rychlý náhled)
  if (suggestedKeys.isNotEmpty) {
    stdout.writeln('\n🔑 Navržené překladové klíče (výběr):');
    for (final e in suggestedKeys.entries.take(20)) {
      stdout.writeln('  ${e.key} = "${e.value.value}"');
    }
    if (suggestedKeys.length > 20) {
      stdout.writeln('  ... a další (${suggestedKeys.length - 20}) v reportu.');
    }
  }

  if (skippedWithInterpolation.isNotEmpty) {
    stdout.writeln(
        '\n📝 Ručně dořešit interpolace (navrhni klíče s placeholdery):');
    for (final u in skippedWithInterpolation.take(20)) {
      stdout.writeln(
          '  • ${u.path}:${u.line} [${u.context}] "${u.snippet.trim()}"');
    }
    if (skippedWithInterpolation.length > 20) {
      stdout.writeln('  ... a další v reportu.');
    }
  }
}

/// ---------- Pomocné struktury a funkce ----------

class _Pattern {
  final String name;
  final RegExp re;
  final bool replaceLiteralOnly;
  _Pattern(
      {required this.name, required this.re, this.replaceLiteralOnly = true});
}

class _Usage {
  final String path;
  final int line;
  final String snippet;
  final String context;
  _Usage(this.path, this.line, this.snippet, {this.context = ''});
}

class _Suggestion {
  final String key;
  final String value;
  final List<_Usage> examples;
  _Suggestion({required this.key, required this.value, required this.examples});
}

String _fileStem(String path) {
  final base = path.split(Platform.pathSeparator).last;
  final dot = base.lastIndexOf('.');
  return (dot > 0 ? base.substring(0, dot) : base).toLowerCase();
}

/// Stabilní, čitelné klíče: auto.<soubor>.<slug> nebo s doplňkem _<hash> při kolizi
String _buildStableKey(String fileStem, String text, Set<String> taken) {
  final slug = _slugAscii(text);
  String base = 'auto.$fileStem.$slug';
  if (base.length > 64) base = base.substring(0, 64);

  String candidate = base;
  int salt = 0;
  while (taken.contains(candidate)) {
    salt++;
    final h = _shortHash('$text#$salt');
    candidate = '$base\_$h';
  }
  return candidate;
}

String _shortHash(String s) {
  int h = 0;
  for (int i = 0; i < s.length; i++) {
    h = 0x1fffffff & (h + s.codeUnitAt(i));
    h = 0x1fffffff & (h + ((h << 10) & 0x1fffffff));
    h ^= (h >> 6);
  }
  h = 0x1fffffff & (h + ((h << 3) & 0x1fffffff));
  h ^= (h >> 11);
  h = 0x1fffffff & (h + ((h << 15) & 0x1fffffff));
  if (h < 0) h = -h;
  return h.toRadixString(36);
}

/// hrubé "oddiakritikování" → necháme jen [a-z0-9_], mezery na _
String _slugAscii(String s) {
  final lower = s.toLowerCase();
  final replaced = lower
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (replaced.isEmpty) return 'text';
  return replaced.length > 40 ? replaced.substring(0, 40) : replaced;
}

bool _hasInterpolation(String s) => s.contains(r'${');

bool _looksLikeTranslatable(String s) {
  final text = s.trim();
  if (text.isEmpty || text.length < 2) return false;

  final looksLikePath = text.contains('/') || text.contains('\\');
  final looksLikeUrl =
      text.startsWith('http://') || text.startsWith('https://');
  final looksLikeHex = RegExp(r'^#?[0-9A-Fa-f]{6,8}$').hasMatch(text);
  final looksLikeVersion = RegExp(r'^\d+(\.\d+)*$').hasMatch(text);
  final looksLikeKeyDot = text.contains('.') && !text.contains(' ');
  final tooNumeric = RegExp(r'^\d[\d\W]*$').hasMatch(text);
  final varLike = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(text);

  if (looksLikePath ||
      looksLikeUrl ||
      looksLikeHex ||
      looksLikeVersion ||
      looksLikeKeyDot ||
      tooNumeric) {
    return false;
  }
  if (!text.contains(' ') && varLike) return false;

  final hasLetter = RegExp(r'[A-Za-zÁ-ž]').hasMatch(text);
  return hasLetter;
}

String _unescapeDartString(String s) {
  return s
      .replaceAll(r'\"', '"')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\\', r'\');
}
