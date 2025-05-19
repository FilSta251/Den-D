// lib/widgets/permission_error_banner.dart - nový widget pro zobrazení problémů s oprávněními

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_provider.dart';
import '../services/permission_handler.dart';

/// Widget pro zobrazení informací o problémech s oprávněními v aplikaci.
/// 
/// Tento widget se může zobrazit například v hlavním menu nebo na obrazovce nastavení,
/// aby informoval uživatele o problémech s oprávněními a nabídl řešení.
class PermissionErrorBanner extends StatefulWidget {
  const PermissionErrorBanner({Key? key}) : super(key: key);

  @override
  State<PermissionErrorBanner> createState() => _PermissionErrorBannerState();
}

class _PermissionErrorBannerState extends State<PermissionErrorBanner> {
  List<String> _errorCollections = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadErrorCollections();
  }

  Future<void> _loadErrorCollections() async {
    final user = Provider.of<SubscriptionProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final collections = await PermissionHandler.getErrorCollections(user.uid);
      setState(() {
        _errorCollections = collections;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Chyba při načítání kolekcí s problémy oprávnění: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetAllPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await PermissionHandler.resetAllPermissionErrors();
      // Resetujeme příznak problému s oprávněními v SubscriptionProvider
      final subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      await subscriptionProvider.resetPermissionError();
      
      // Znovu načteme aktuální kolekce s problémy
      await _loadErrorCollections();
      
      // Zobrazíme informaci o úspěšném resetování
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Informace o oprávněních byly resetovány.")),
      );
    } catch (e) {
      debugPrint('Chyba při resetování informací o oprávněních: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pokud nemáme žádné problémy s oprávněními, nezobrazujeme nic
    if (_errorCollections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Aplikace funguje v režimu s omezenými oprávněními",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Některé funkce používají lokální data a nebudou synchronizovány se serverem. "
            "Byly zjištěny problémy s oprávněními pro tyto kolekce: ${_errorCollections.join(', ')}.",
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _isLoading ? null : _resetAllPermissions,
                icon: const Icon(Icons.refresh),
                label: const Text("Zkusit znovu"),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}