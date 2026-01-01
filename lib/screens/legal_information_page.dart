import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class LegalInformationPage extends StatefulWidget {
  final String contentType;

  const LegalInformationPage({
    super.key,
    required this.contentType,
  });

  @override
  State<LegalInformationPage> createState() => _LegalInformationPageState();
}

class _LegalInformationPageState extends State<LegalInformationPage> {
  String _content = '';
  bool _isLoading = true;
  String? _error;
  bool _hasLoadedOnce = false; // ✅ PŘIDÁNO: zabránit opakovanému načítání

  @override
  void initState() {
    super.initState();
    // ❌ NEDĚLÁME TU NIC - čekáme na didChangeDependencies
  }

  // ✅ PŘIDÁNO: Načítání až když je context plně připravený
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedOnce) {
      _hasLoadedOnce = true;
      _loadContent();
    }
  }

  /// Vrací cestu k markdown souboru podle jazyka
  String _getLocalizedFilePath() {
    // ✅ OPRAVENO: Získáme locale až tady, když je context připravený
    final String currentLocale = context.locale.languageCode;
    final String fileName = widget.contentType == 'privacy'
        ? 'privacy_policy.md'
        : 'terms_of_service.md';

    // Podporované jazyky s vlastními markdown soubory
    const List<String> supportedLanguages = [
      'cs', // Čeština
      'en', // Angličtina
      'de', // Němčina
      'es', // Španělština
      'fr', // Francouzština
      'pl', // Polština
      'uk', // Ukrajinština
    ];

    debugPrint('[LegalInformationPage] Detekovaný jazyk: $currentLocale');

    if (supportedLanguages.contains(currentLocale)) {
      final path = 'assets/legal/$currentLocale/$fileName';
      debugPrint('[LegalInformationPage] Používám lokalizovanou verzi: $path');
      return path;
    }

    // Pro nepodporované jazyky použijeme angličtinu jako fallback
    debugPrint(
        '[LegalInformationPage] Jazyk $currentLocale není podporován, používám EN');
    return 'assets/legal/en/$fileName';
  }

  /// Načte obsah markdown souboru podle typu a jazyka
  Future<void> _loadContent() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final String filePath = _getLocalizedFilePath();

      debugPrint('[LegalInformationPage] Načítám soubor: $filePath');

      final String content = await rootBundle.loadString(filePath);

      if (mounted) {
        setState(() {
          _content = content;
          _isLoading = false;
        });
      }

      debugPrint(
          '[LegalInformationPage] Obsah úspěšně načten (${content.length} znaků)');
    } catch (e) {
      debugPrint('[LegalInformationPage] Chyba při načítání obsahu: $e');

      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        // Pokud selže načtení, zkusíme anglickou verzi
        _tryLoadEnglishFallback();
      }
    }
  }

  /// Pokusí se načíst anglickou verzi jako zálohu
  Future<void> _tryLoadEnglishFallback() async {
    try {
      final String fileName = widget.contentType == 'privacy'
          ? 'privacy_policy.md'
          : 'terms_of_service.md';
      final String fallbackPath = 'assets/legal/en/$fileName';

      debugPrint(
          '[LegalInformationPage] Načítám záložní anglickou verzi: $fallbackPath');

      final String content = await rootBundle.loadString(fallbackPath);

      if (mounted) {
        setState(() {
          _content = content;
          _error = null;
        });
      }

      debugPrint('[LegalInformationPage] Anglická verze úspěšně načtena');
    } catch (e) {
      debugPrint('[LegalInformationPage] Selhalo i načtení anglické verze: $e');
      // Pokud selže i angličtina, zobrazíme error
    }
  }

  /// Vrací název stránky podle typu obsahu
  String _getPageTitle() {
    switch (widget.contentType) {
      case 'privacy':
        return tr('legal.privacy.title');
      case 'terms':
      default:
        return tr('legal.terms.title');
    }
  }

  /// Vrací popisek podle typu obsahu
  String _getPageDescription() {
    switch (widget.contentType) {
      case 'privacy':
        return tr('legal.privacy.description');
      case 'terms':
      default:
        return tr('legal.terms.description');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(tr('legal.loading')),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tr('legal.error.title'),
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('legal.error.message'),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadContent,
                          icon: const Icon(Icons.refresh),
                          label: Text(tr('legal.error.retry')),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Debug: $_error',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header s informací o typu obsahu
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Row(
                        children: [
                          Icon(
                            widget.contentType == 'privacy'
                                ? Icons.privacy_tip_outlined
                                : Icons.description_outlined,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getPageTitle(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getPageDescription(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Markdown obsah
                    Expanded(
                      child: Markdown(
                        data: _content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: Theme.of(context).textTheme.bodyMedium,
                          h1: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                          h2: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                          h3: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          blockquote:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[700],
                                  ),
                          code: TextStyle(
                            fontFamily: 'monospace',
                            backgroundColor: Colors.grey[100],
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onTapLink: (text, href, title) {
                          debugPrint(
                              '[LegalInformationPage] Kliknuto na odkaz: $href');
                        },
                      ),
                    ),
                  ],
                ),

      // Dolní lišta s rychlými odkazy
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Colors.grey[300]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (widget.contentType != 'terms')
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    '/legal',
                    arguments: 'terms',
                  );
                },
                icon: const Icon(Icons.description_outlined),
                label: Text(tr('legal.terms.button')),
              ),
            if (widget.contentType != 'privacy')
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    '/legal',
                    arguments: 'privacy',
                  );
                },
                icon: const Icon(Icons.privacy_tip_outlined),
                label: Text(tr('legal.privacy.button')),
              ),
          ],
        ),
      ),
    );
  }
}
