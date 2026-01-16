/// lib/screens/settings_page.dart
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../repositories/wedding_repository.dart';
import '../services/onboarding_manager.dart';
import '../services/payment_service.dart';
import '../providers/subscription_provider.dart';
import '../providers/theme_manager.dart';
import '../router/app_router.dart';
import '../utils/constants.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Stránka nastavení s položkami: jazyk, zobrazení předplatného, smazání účtu a o aplikaci.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
  }

  /// Zobrazí dialog pro výběr jazyka.
  Future<void> _showLanguageDialog() async {
    if (!mounted) return;

    debugPrint('[SettingsPage] Showing language dialog');
    await showDialog(
      context: context,
      builder: (_) => const LanguageDialog(),
    );
  }

  /// Zobrazí dialog pro výběr tématu (světlé/tmavé).
  Future<void> _showThemeDialog() async {
    if (!mounted) return;

    debugPrint('[SettingsPage] Showing theme dialog');
    await showDialog(
      context: context,
      builder: (_) => const ThemeDialog(),
    );
  }

  /// Otevře správu předplatného přes PaymentService
  Future<void> _openManageSubscriptions() async {
    try {
      if (!mounted) return;

      final paymentService =
          Provider.of<PaymentService>(context, listen: false);
      await paymentService.openManageSubscriptions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings.subscription.manage_error'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Naviguje na stránku s předplatným (detail)
  void _navigateToSubscription() {
    Navigator.pushNamed(
      context,
      '/subscription',
      arguments: {'showFreeOption': true},
    );
  }

  /// Naviguje na podmínky použití
  void _navigateToTerms() {
    AppRouter.navigateToTerms(context);
  }

  /// Naviguje na zásady ochrany údajů
  void _navigateToPrivacy() {
    AppRouter.navigateToPrivacy(context);
  }

  /// Zobrazí potvrzovací dialog pro smazání účtu.
  Future<void> _confirmDeleteAccount() async {
    debugPrint('[SettingsPage] Showing delete account confirmation dialog');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    debugPrint('[SettingsPage] Delete account confirmed: $confirmed');
    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  /// Smaže účet okamžitě včetně všech dat
  Future<void> _deleteAccount() async {
    debugPrint('[SettingsPage] Deleting account immediately');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('deleting_account_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(tr('deleting_account_message'))
          ],
        ),
      ),
    );

    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        debugPrint('[SettingsPage] Deleting user data: $uid');

        // 1. Smaž wedding_info dokument
        try {
          await FirebaseFirestore.instance
              .collection('wedding_info')
              .doc(uid)
              .delete();
          debugPrint('[SettingsPage] Deleted wedding_info document');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting wedding_info: $e');
        }

        // 2. NOVÁ ČÁST - Smaž všechny podkolekce pod users/{uid}/
        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(uid);

        // Smaž guests
        try {
          final snapshot = await userDocRef.collection('guests').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint('[SettingsPage] Deleted ${snapshot.docs.length} guests');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting guests: $e');
        }

        // Smaž budget
        try {
          final snapshot = await userDocRef.collection('budget').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${snapshot.docs.length} budget items');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting budget: $e');
        }

        // Smaž calendar_events
        try {
          final snapshot = await userDocRef.collection('calendar_events').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${snapshot.docs.length} calendar events');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting calendar_events: $e');
        }

        // Smaž schedule
        try {
          final snapshot = await userDocRef.collection('schedule').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${snapshot.docs.length} schedule items');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting schedule: $e');
        }

        // Smaž checklist_tasks
        try {
          final snapshot = await userDocRef.collection('checklist_tasks').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${snapshot.docs.length} checklist tasks');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting checklist_tasks: $e');
        }

        // Smaž checklist_categories
        try {
          final snapshot =
              await userDocRef.collection('checklist_categories').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${snapshot.docs.length} checklist categories');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting checklist_categories: $e');
        }

        // Smaž tables
        try {
          final snapshot = await userDocRef.collection('tables').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint('[SettingsPage] Deleted ${snapshot.docs.length} tables');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting tables: $e');
        }

        // Smaž suppliers
        try {
          final snapshot = await userDocRef.collection('suppliers').get();
          for (final doc in snapshot.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${snapshot.docs.length} suppliers');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting suppliers: $e');
        }

        // 3. Smaž weddings (pokud existují v hlavní kolekci)
        try {
          final weddingsQuery = await FirebaseFirestore.instance
              .collection('weddings')
              .where('userId', isEqualTo: uid)
              .get();
          for (var doc in weddingsQuery.docs) {
            await doc.reference.delete();
          }
          debugPrint(
              '[SettingsPage] Deleted ${weddingsQuery.docs.length} weddings');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting weddings: $e');
        }

        // 4. Smaž user dokument
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .delete();
          debugPrint('[SettingsPage] Deleted user document');
        } catch (e) {
          debugPrint('[SettingsPage] Error deleting user document: $e');
        }

        // 5. REAUTHENTIKACE před smazáním Auth účtu
        try {
          // Zkus smazat Auth účet
          await user.delete();
          debugPrint('[SettingsPage] Deleted Firebase Auth account');

          if (mounted) {
            Navigator.of(context).pop(); // Zavřeme loading dialog

            // Zobrazíme potvrzení
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: Text(tr('account_deleted_title')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        size: 48, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      tr('account_deleted_message'),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/auth', (route) => false);
                    },
                    child: Text(tr('ok')),
                  ),
                ],
              ),
            );
          }
        } catch (authError) {
          // Pokud selže kvůli reauthentikaci, data už jsou smazaná, jen Auth účet zůstal
          debugPrint('[SettingsPage] Auth deletion failed: $authError');

          if (mounted) {
            Navigator.of(context).pop();

            if (authError.toString().contains('requires-recent-login')) {
              // Data jsou smazaná, jen odhlásíme
              await fb.FirebaseAuth.instance.signOut();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('account_data_deleted_reauth'),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );

              Navigator.pushNamedAndRemoveUntil(
                  context, '/auth', (route) => false);
            }
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(tr('no_user_found'),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16)),
          );
        }
      }
    } catch (e, stack) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      debugPrint('[SettingsPage] Error deleting account: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('delete_account_error', args: [e.toString()]),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Zobrazí dialog s informacemi o aplikaci.
  Future<void> _showAboutDialog() async {
    debugPrint('[SettingsPage] Showing about dialog');

    // Načtení verze z package_info
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    if (mounted) {
      showAboutDialog(
        context: context,
        applicationName: tr('app_name'),
        applicationVersion: '$version+$buildNumber',
        applicationLegalese: '© 2025 Filip Šastný',
      );
    }
  }

  /// Testovací metoda pro ověření Firebase oprávnění.
  Future<void> _testFirebasePermissions() async {
    debugPrint('[SettingsPage] Starting Firebase permissions test');
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[SettingsPage] No user found for Firebase permissions test');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('no_logged_in_user'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16)),
        );
      }
      return;
    }

    if (!mounted) return;

    final weddingRepo = Provider.of<WeddingRepository>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(tr('testing_permissions_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(tr('testing_permissions_message'))
          ],
        ),
      ),
    );

    try {
      await weddingRepo.testFirestorePermissions();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('permissions_test_success'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(tr('permissions_test_error', args: [e.toString()]))),
        );
      }
    }
  }

  /// Resetuje onboarding flow (pro testování).
  Future<void> _resetOnboarding() async {
    debugPrint('[SettingsPage] Resetting onboarding flow');
    try {
      final userId = fb.FirebaseAuth.instance.currentUser?.uid;
      await OnboardingManager.resetOnboarding(userId: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('onboarding_reset_success'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(tr('onboarding_reset_error', args: [e.toString()]))),
        );
      }
    }
  }

  /// Zobrazí aktuální informace o přihlášeném uživateli.
  Future<void> _showCurrentUserInfo() async {
    debugPrint('[SettingsPage] Showing current user information');
    final user = fb.FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('no_logged_in_user'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16)),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('user_info_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('UID: ${user.uid}'),
              Text('${tr('email')}: ${user.email}'),
              Text('${tr('verified')}: ${user.emailVerified}'),
              Text(
                  'Provider: ${user.providerData.map((p) => p.providerId).join(', ')}'),
              const SizedBox(height: 16),
              Text(tr('onboarding_info'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<bool>(
                future: OnboardingManager.isOnboardingCompleted(),
                builder: (context, snapshot) {
                  return Text(
                      '${tr('onboarding_completed')}: ${snapshot.data ?? false}');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('close')),
          ),
        ],
      ),
    );
  }

  /// Vymaže cache aplikace
  Future<void> _clearAppCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('cache_cleared'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tr('cache_clear_error'),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16)),
        );
      }
    }
  }

  /// Widget pro sekci Moje předplatné
  Widget _buildSubscriptionSection() {
    return Consumer<SubscriptionProvider>(
      builder: (context, subscriptionProvider, child) {
        final subscription = subscriptionProvider.subscription;
        final isPremium = subscriptionProvider.isPremium;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPremium ? Icons.diamond : Icons.free_breakfast,
                      color: isPremium ? Colors.amber : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      tr('settings.subscription.my_subscription'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stav předplatného
                Row(
                  children: [
                    Text(
                      '${tr('settings.subscription.status')}: ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPremium
                            ? Colors.amber.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isPremium
                            ? tr('settings.subscription.premium')
                            : tr('settings.subscription.free'),
                        style: TextStyle(
                          color: isPremium
                              ? Colors.amber.shade700
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),

                // Datum expirace (pokud je Premium)
                if (isPremium && subscription?.expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${tr('settings.subscription.expires')}: ${DateFormat('dd.MM.yyyy').format(subscription!.expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${tr('settings.subscription.days_left')}: ${subscription.daysLeft}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],

                const SizedBox(height: 16),

                // ZMĚNA: Rozdílné tlačítko podle typu předplatného
                if (isPremium) ...[
                  // Premium uživatel - tlačítko Spravovat
                  ElevatedButton.icon(
                    onPressed: _openManageSubscriptions,
                    icon: const Icon(Icons.settings),
                    label: Text(tr('settings.subscription.manage')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  // Free uživatel - tlačítko Upgradovat
                  ElevatedButton.icon(
                    onPressed: _navigateToSubscription,
                    icon: const Icon(Icons.star),
                    label: Text(tr('settings.subscription.upgrade_to_premium')),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      backgroundColor: Colors.pink.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Hlavní widget stránky.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings_title')),
      ),
      body: ListView(
        children: [
          // Sekce Moje předplatné - POUZE když je subscription enabled
          if (Billing.subscriptionEnabled) ...[
            _buildSubscriptionSection(),
            const Divider(),
          ],

          ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr('settings_language')),
            onTap: _showLanguageDialog,
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(tr('settings_theme')),
            onTap: _showThemeDialog,
          ),

          const Divider(),

          // Právní odkazy
          ListTile(
            leading: const Icon(Icons.description),
            title: Text(tr('settings.legal.terms')),
            subtitle: Text(tr('settings.legal.terms_subtitle')),
            onTap: _navigateToTerms,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(tr('settings.legal.privacy')),
            subtitle: Text(tr('settings.legal.privacy_subtitle')),
            onTap: _navigateToPrivacy,
          ),

          const Divider(),

          // Tlačítko pro smazání účtu - POVINNÉ PRO APP STORE (Guideline 5.1.1(v))
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: Text(tr('settings_delete_account')),
            subtitle: Text(tr('settings_delete_account_subtitle')),
            onTap: _confirmDeleteAccount,
          ),

          ListTile(
            leading: const Icon(Icons.info),
            title: Text(tr('settings_about')),
            onTap: _showAboutDialog,
          ),

          // Vývojářské nástroje - POUZE 5 POLOŽEK
          if (kDebugMode) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(tr('dev_tools_title'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.orange),
              title: Text(tr('test_firebase_permissions')),
              onTap: _testFirebasePermissions,
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.blue),
              title: Text(tr('reset_onboarding_dev')),
              onTap: _resetOnboarding,
            ),
            ListTile(
              leading: const Icon(Icons.person_search, color: Colors.green),
              title: Text(tr('user_information')),
              onTap: _showCurrentUserInfo,
            ),
            ListTile(
              leading: const Icon(Icons.fiber_new, color: Colors.purple),
              title: Text(tr('simulate_first_install')),
              subtitle: Text(tr('simulate_first_install_subtitle')),
              onTap: () async {
                await OnboardingManager.resetOnboarding();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.red),
              title: Text(tr('dev_clear_cache')),
              subtitle: Text(tr('dev_clear_cache_subtitle')),
              onTap: _clearAppCache,
            ),
            ListTile(
              leading: const Icon(Icons.autorenew, color: Colors.amber),
              title: Text(tr('dev_renew_subscription')),
              subtitle: Text(tr('dev_renew_subscription_subtitle')),
              onTap: _navigateToSubscription,
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog pro výběr jazyka.
class LanguageDialog extends StatelessWidget {
  const LanguageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final languages = [
      {'code': 'cs', 'name': 'Čeština', 'flag': '🇨🇿'},
      {'code': 'de', 'name': 'Deutsch', 'flag': '🇩🇪'},
      {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
      {'code': 'es', 'name': 'Español', 'flag': '🇪🇸'},
      {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
      {'code': 'pl', 'name': 'Polski', 'flag': '🇵🇱'},
      {'code': 'uk', 'name': 'Українська', 'flag': '🇺🇦'},
    ];

    return AlertDialog(
      title: Text(tr('settings_language')),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: languages.length,
          itemBuilder: (context, index) {
            final language = languages[index];
            return ListTile(
              leading: Text(
                language['flag']!,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text(language['name']!),
              onTap: () {
                context.setLocale(Locale(language['code']!));
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('cancel')),
        ),
      ],
    );
  }
}

/// Dialog pro potvrzení smazání účtu - POVINNÉ PRO APP STORE (Guideline 5.1.1(v))
class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('settings_delete_account')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            tr('confirm_delete_account'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            tr('delete_account_warning'),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('confirm')),
        ),
      ],
    );
  }
}

/// Dialog pro výběr tématu.
class ThemeDialog extends StatelessWidget {
  const ThemeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeManager>(
      builder: (context, themeManager, child) {
        return AlertDialog(
          title: Text(tr('settings_theme')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.light_mode),
                title: Text(tr('theme_light')),
                trailing: themeManager.themeMode == ThemeMode.light
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  themeManager.setThemeMode(ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.dark_mode),
                title: Text(tr('theme_dark')),
                trailing: themeManager.themeMode == ThemeMode.dark
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  themeManager.setThemeMode(ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
          ],
        );
      },
    );
  }
}
