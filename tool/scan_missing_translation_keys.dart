/// tool/scan_missing_translation_keys.dart
library;

import 'dart:convert';
import 'dart:io';

/// Entry:
///   dart run tool/scan_missing_translation_keys.dart [path/to/cs.json] [sourceDir]
void main(List<String> args) {
  final projectRoot = Directory.current.path;

  final translationFilePath =
      args.isNotEmpty ? args[0] : 'assets/translations/cs.json';
  final sourceDirPath =
      args.length >= 2 ? args[1] : '$projectRoot${Platform.pathSeparator}lib';

  final translationFile = File(translationFilePath);
  if (!translationFile.existsSync()) {
    stderr.writeln('❌ Translation file not found: $translationFilePath');
    exit(1);
  }

  final sourceDir = Directory(sourceDirPath);
  if (!sourceDir.existsSync()) {
    stderr.writeln('❌ Source directory not found: $sourceDirPath');
    exit(1);
  }

  // --- Load & flatten translation keys
  final Map<String, dynamic> jsonMap = json.decode(
    translationFile.readAsStringSync(),
  ) as Map<String, dynamic>;

  final translationKeys = _flattenJsonKeys(jsonMap);

  // --- Scan .dart files
  final usedKeys = <String>{};
  final keyUsages = <String, List<_Usage>>{}; // For potential future needs

  final hardcodedTexts = <_Usage>[];

  final dartFiles = sourceDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final trFuncRegex = RegExp(
      r"""(?:(?:^|[^A-Za-z0-9_]))(?:tr|safeTr)\(\s*['"]([A-Za-z0-9_.-]+)['"]\s*\)""");
  final trExtRegex = RegExp(r"""['"]([A-Za-z0-9_.-]+)['"]\s*\.tr\s*\(\s*\)""");

  // UI string patterns to detect hardcoded texts
  final textCtorRegex = RegExp(
      r"""Text\s*\(\s*(['"])(?:(?=(\\?))\2.)*?\1"""); // Text('...') with escapes
  final namedParamStringRegex = RegExp(
      r"""(?:labelText|hintText|helperText|errorText|title|subtitle|tooltip|semanticsLabel|screenReaderLabel|ariaLabel)\s*:\s*(['"])(?:(?=(\\?))\2.)*?\1""");
  final childTextRegex =
      RegExp(r"""child\s*:\s*Text\s*\(\s*(['"])(?:(?=(\\?))\2.)*?\1""");
  final snackBarRegex = RegExp(
      r"""SnackBar\s*\(\s*content\s*:\s*Text\s*\(\s*(['"])(?:(?=(\\?))\2.)*?\1""");
  final appBarTitleRegex = RegExp(
      r"""AppBar\s*\(\s*title\s*:\s*Text\s*\(\s*(['"])(?:(?=(\\?))\2.)*?\1""");

  for (final file in dartFiles) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Gather used translation keys
      for (final m in trFuncRegex.allMatches(line)) {
        final key = m.group(1)!;
        usedKeys.add(key);
        keyUsages.putIfAbsent(key, () => []).add(_Usage(file.path, i + 1, key));
      }
      for (final m in trExtRegex.allMatches(line)) {
        final key = m.group(1)!;
        usedKeys.add(key);
        keyUsages.putIfAbsent(key, () => []).add(_Usage(file.path, i + 1, key));
      }

      // Find potential hardcoded UI strings
      void _collectMatches(RegExp re, String kind) {
        for (final m in re.allMatches(line)) {
          final raw = m.group(0)!;
          final captured = _extractFirstQuoted(raw);
          if (captured == null) continue;
          final text = _unescapeDartString(captured);
          if (_looksLikeTranslatable(text) &&
              !_looksLikeAlreadyTrUsage(line, captured)) {
            hardcodedTexts.add(_Usage(file.path, i + 1, text, context: kind));
          }
        }
      }

      _collectMatches(textCtorRegex, 'Text(...)');
      _collectMatches(namedParamStringRegex, 'namedParam');
      _collectMatches(childTextRegex, 'child: Text(...)');
      _collectMatches(snackBarRegex, 'SnackBar(content: Text(...))');
      _collectMatches(appBarTitleRegex, 'AppBar(title: Text(...))');
    }
  }

  // Compare
  final missing = usedKeys.difference(translationKeys);
  final unused = translationKeys.difference(usedKeys);

  // --- Report
  stdout.writeln('📁 Source: $sourceDirPath');
  stdout.writeln('🗂  Files scanned: ${dartFiles.length}');
  stdout.writeln('→ Found ${usedKeys.length} used tr() keys in source.');
  stdout.writeln(
      '→ Found ${translationKeys.length} keys in JSON: $translationFilePath\n');

  // Missing
  if (missing.isEmpty) {
    stdout.writeln('✅ No missing translation keys.');
  } else {
    stdout.writeln('❌ Missing keys (${missing.length}):');
    final sorted = missing.toList()..sort();
    for (final k in sorted) {
      stdout.writeln('  • $k');
      // If you want locations where the key is referenced, uncomment below:
      // final usages = keyUsages[k] ?? const [];
      // for (final u in usages) {
      //   stdout.writeln('      - ${u.path}:${u.line}');
      // }
    }
  }

  // Unused
  if (unused.isEmpty) {
    stdout.writeln('\n✅ No unused keys.');
  } else {
    stdout.writeln('\n⚠️ Unused keys (${unused.length}):');
    final sorted = unused.toList()..sort();
    for (final k in sorted) {
      stdout.writeln('  • $k');
    }
  }

  // Hardcoded texts
  if (hardcodedTexts.isEmpty) {
    stdout.writeln('\n✅ No hardcoded UI texts found.');
  } else {
    stdout.writeln('\n🔎 Hardcoded UI texts to replace with translation keys '
        '(${hardcodedTexts.length}):');
    hardcodedTexts.sort((a, b) {
      final c = a.path.compareTo(b.path);
      if (c != 0) return c;
      return a.line.compareTo(b.line);
    });
    for (final u in hardcodedTexts) {
      stdout.writeln(
          '  • ${u.path}:${u.line}  [${u.context}]  "${u.snippet.trim()}"');
    }
  }
}

/// Flattens JSON keys to dot notation set
Set<String> _flattenJsonKeys(Map<String, dynamic> map) {
  final out = <String>{};
  void walk(String prefix, dynamic node) {
    if (node is Map<String, dynamic>) {
      node.forEach((k, v) {
        final full = prefix.isEmpty ? k : '$prefix.$k';
        if (v is String) {
          out.add(full);
        } else {
          walk(full, v);
        }
      });
    }
  }

  walk('', map);
  return out;
}

class _Usage {
  final String path;
  final int line;
  final String snippet;
  final String context;
  _Usage(this.path, this.line, this.snippet, {this.context = ''});
}

/// Extracts the first quoted string content (without quotes) from a match text.
String? _extractFirstQuoted(String s) {
  // Matches '...' or "..." with possible escaped quotes inside
  final re = RegExp(r"""(['"])((?:(?!\1).|\\\1)*?)\1""");
  final m = re.firstMatch(s);
  return m?.group(2);
}

/// Unescape common Dart string sequences (minimal; good enough for scanning)
String _unescapeDartString(String s) {
  return s
      .replaceAll(r'\"', '"')
      .replaceAll(r"\'", "'")
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '\t')
      .replaceAll(r'\\', r'\');
}

/// Heuristic: should this literal be considered human-facing text?
bool _looksLikeTranslatable(String s) {
  final text = s.trim();

  // Quickly ignore empties or ultra-short
  if (text.isEmpty || text.length < 2) return false;

  // Common short tokens not meant for translation
  const stoplist = {
    'OK',
    'Ok',
    'O.K.',
    'km',
    'm',
    'ID',
    'N/A',
    'UTC',
    'PDF',
    'CSV',
    'XML',
    'JSON',
    'API',
    'UI',
    'UX',
  };
  if (stoplist.contains(text)) return false;

  // Paths, routes, file names, extensions, hex colors, likely technical tokens
  final looksLikePath = text.contains('/') || text.contains('\\');
  final looksLikeUrl =
      text.startsWith('http://') || text.startsWith('https://');
  final looksLikeHexColor = RegExp(r'^#?[0-9A-Fa-f]{6,8}$').hasMatch(text);
  final looksLikeVersion = RegExp(r'^\d+(\.\d+)*$').hasMatch(text);
  final looksLikeKeyDot = text.contains('.') && !text.contains(' ');
  final looksLikeVarLike = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(text);
  final tooNumeric = RegExp(r'^\d[\d\W]*$').hasMatch(text);

  if (looksLikePath ||
      looksLikeUrl ||
      looksLikeHexColor ||
      looksLikeVersion ||
      looksLikeKeyDot ||
      tooNumeric) return false;

  // If it's a single "word-like" token without spaces and not capitalized like a label, skip
  if (!text.contains(' ') && looksLikeVarLike) return false;

  // If it has letters, assume it's UI text to translate
  final hasLetter = RegExp(r'[A-Za-zÁ-ž]').hasMatch(text);
  return hasLetter;
}

/// If the same line already contains tr(...) or ".tr()", don't report it as hardcoded.
bool _looksLikeAlreadyTrUsage(String line, String capturedLiteral) {
  // If the literal itself is the key for .tr() (e.g., "home.title".tr()), skip
  if (RegExp(r"""['"][A-Za-z0-9_.-]+['"]\s*\.tr\s*\(""").hasMatch(line)) {
    return true;
  }
  // If the call looks like tr("key")/safeTr("key") on this line, skip
  if (RegExp(
          r"""(?:^|[^A-Za-z0-9_])(tr|safeTr)\s*\(\s*['"][A-Za-z0-9_.-]+['"]\s*\)""")
      .hasMatch(line)) {
    return true;
  }
  return false;
}
