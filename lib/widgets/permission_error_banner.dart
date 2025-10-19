/// lib/widgets/permission_error_banner.dart - nový widget pro zobrazení problĂ©mů s oprávněními
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/subscription_provider.dart';
import '../services/permission_handler.dart';

/// Widget pro zobrazení informací o problĂ©mech s oprávněními v aplikaci.
///
/// Tento widget se můťe zobrazit například v hlavním menu nebo na obrazovce nastavení,
/// aby informoval uťivatele o problĂ©mech s oprávněními a nabídl řeĹˇení.
class PermissionErrorBanner extends StatefulWidget {
  const PermissionErrorBanner({super.key});

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final collections = await PermissionHandler.getErrorCollections(user.uid);
      if (mounted) {
        setState(() {
          _errorCollections = collections;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Chyba při náčítání kolekcí s problĂ©my oprávnění: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetAllPermissions() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await PermissionHandler.resetAllPermissionErrors();

      // Resetujeme příznak problĂ©mu s oprávněními v SubscriptionProvider
      // Pokud metoda resetPermissionError neexistuje, zakomentujte tyto řádky
      /*
     final subscriptionProvider =
         Provider.of<SubscriptionProvider>(context, listen: false);
     await subscriptionProvider.resetPermissionError();
     */

      // Znovu náčteme aktuální kolekce s problĂ©my
      await _loadErrorCollections();

      // Zobrazíme informaci o úspěĹˇnĂ©m resetování
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('permission_error_banner.reset_success'))),
        );
      }
    } catch (e) {
      debugPrint('Chyba při resetování informací o oprávněních: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pokud nemáme ťádnĂ© problĂ©my s oprávněními, nezobrazujeme nic
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
              Expanded(
                child: Text(
                  tr('permission_error_banner.title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              'permission_error_banner.description',
              args: [_errorCollections.join(', ')],
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _isLoading ? null : _resetAllPermissions,
                icon: const Icon(Icons.refresh),
                label: Text(tr('retry')),
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

