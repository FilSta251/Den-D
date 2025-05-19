import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../repositories/wedding_repository.dart';
import '../services/onboarding_manager.dart';

/// Stránka nastavení s položkami: jazyk, změna účtu, smazání účtu a o aplikaci.
class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  /// Zobrazí dialog pro výběr jazyka.
  Future<void> _showLanguageDialog(BuildContext context) async {
    debugPrint('[SettingsPage] Showing language dialog');
    await showDialog(
      context: context,
      builder: (_) => const LanguageDialog(),
    );
  }

  /// Zobrazí dialog pro změnu účtu.
  Future<void> _showChangeAccountDialog(BuildContext context) async {
    debugPrint('[SettingsPage] Showing change account dialog');
    await showDialog(
      context: context,
      builder: (_) => const ChangeAccountDialog(),
    );
  }

  /// Zobrazí potvrzovací dialog pro smazání účtu.
  Future<void> _confirmDeleteAccount(BuildContext context) async {
    debugPrint('[SettingsPage] Showing delete account confirmation dialog');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteAccountDialog(),
    );
    debugPrint('[SettingsPage] Delete account confirmed: $confirmed');
    if (confirmed == true) {
      await _deleteAccount(context);
    }
  }

  /// Smaže aktuálně přihlášeného uživatele z Firebase Auth i Firestore,
  /// a přesměruje ho na přihlašovací stránku.
  Future<void> _deleteAccount(BuildContext context) async {
    debugPrint('[SettingsPage] Deleting account');
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        debugPrint('[SettingsPage] Deleting user: $uid');
        
        // Smazání uživatele z Firebase Auth.
        await user.delete();
        debugPrint('[SettingsPage] User deleted from Firebase Auth');
        
        // Smazání uživatelského dokumentu z Firestore.
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        debugPrint('[SettingsPage] User document deleted from Firestore');
        
        Navigator.pushReplacementNamed(context, '/auth');
      } else {
        debugPrint('[SettingsPage] No user found for deletion');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('no_user_found'))),
        );
      }
    } catch (e, stack) {
      debugPrint('[SettingsPage] Error deleting account: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('delete_account_error')}: $e')),
      );
    }
  }

  /// Zobrazí dialog s informacemi o aplikaci.
  void _showAboutDialog(BuildContext context) {
    debugPrint('[SettingsPage] Showing about dialog');
    showAboutDialog(
      context: context,
      applicationName: tr('app_name'),
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2023 Your Company Name',
    );
  }

  /// Testovací metoda pro ověření Firebase oprávnění
  Future<void> _testFirebasePermissions(BuildContext context) async {
    debugPrint('[SettingsPage] Starting Firebase permissions test');
    
    // Kontrola, zda je uživatel přihlášen
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[SettingsPage] No user found for Firebase permissions test');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žádný přihlášený uživatel')),
      );
      return;
    }
    
    debugPrint('[SettingsPage] Current user: ${user.uid}, Email: ${user.email}, EmailVerified: ${user.emailVerified}');
    
    // Získáme instanci WeddingRepository
    final weddingRepo = Provider.of<WeddingRepository>(context, listen: false);
    
    // Zobrazíme dialog s indikátorem načítání
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Testování oprávnění'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testování Firebase oprávnění...')
          ],
        ),
      ),
    );
    
    try {
      // Testujeme oprávnění
      debugPrint('[SettingsPage] Executing permissions test using WeddingRepository');
      await weddingRepo.testFirestorePermissions();
      debugPrint('[SettingsPage] Firebase permissions test completed successfully');
      
      // Zavřeme dialog
      Navigator.of(context).pop();
      
      // Zobrazíme výsledek
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test oprávnění úspěšně dokončen - viz konzole pro výsledky')),
      );
    } catch (e, stack) {
      debugPrint('[SettingsPage] Firebase permissions test failed: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      
      // Zavřeme dialog
      Navigator.of(context).pop();
      
      // Zobrazíme chybu
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při testu oprávnění: $e')),
      );
    }
  }

  /// Resetuje onboarding flow (pro testování)
  Future<void> _resetOnboarding(BuildContext context) async {
    debugPrint('[SettingsPage] Resetting onboarding flow');
    try {
      await OnboardingManager.resetOnboarding();
      debugPrint('[SettingsPage] Onboarding flow reset successful');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onboarding byl úspěšně resetován')),
      );
    } catch (e) {
      debugPrint('[SettingsPage] Error resetting onboarding flow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba při resetování onboardingu: $e')),
      );
    }
  }

  /// Zobrazí aktuální informace o přihlášeném uživateli
  Future<void> _showCurrentUserInfo(BuildContext context) async {
    debugPrint('[SettingsPage] Showing current user information');
    final user = fb.FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      debugPrint('[SettingsPage] No user found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žádný přihlášený uživatel')),
      );
      return;
    }
    
    debugPrint('[SettingsPage] Current user ID: ${user.uid}');
    debugPrint('[SettingsPage] Current user email: ${user.email}');
    debugPrint('[SettingsPage] Current user verified: ${user.emailVerified}');
    debugPrint('[SettingsPage] Provider data: ${user.providerData.map((p) => '${p.providerId}: ${p.uid}').join(', ')}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informace o uživateli'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('UID: ${user.uid}'),
              Text('Email: ${user.email}'),
              Text('Email ověřen: ${user.emailVerified}'),
              Text('Poskytovatel: ${user.providerData.map((p) => p.providerId).join(', ')}'),
              Text('Telefon: ${user.phoneNumber ?? 'Nezadáno'}'),
              Text('Jméno: ${user.displayName ?? 'Nezadáno'}'),
              Text('Foto URL: ${user.photoURL ?? 'Nezadáno'}'),
              const SizedBox(height: 16),
              const Text('Onboarding info:', style: TextStyle(fontWeight: FontWeight.bold)),
              FutureBuilder<bool>(
                future: OnboardingManager.isOnboardingCompleted(),
                builder: (context, snapshot) {
                  return Text('Onboarding dokončen: ${snapshot.data ?? false}');
                },
              ),
              FutureBuilder<bool>(
                future: OnboardingManager.isIntroCompleted(),
                builder: (context, snapshot) {
                  return Text('Intro dokončeno: ${snapshot.data ?? false}');
                },
              ),
              FutureBuilder<bool>(
                future: OnboardingManager.isChatbotCompleted(),
                builder: (context, snapshot) {
                  return Text('Chatbot dokončen: ${snapshot.data ?? false}');
                },
              ),
              FutureBuilder<bool>(
                future: OnboardingManager.isSubscriptionShown(),
                builder: (context, snapshot) {
                  return Text('Předplatné zobrazeno: ${snapshot.data ?? false}');
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('settings_title')),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(tr('settings_language')),
            onTap: () => _showLanguageDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.switch_account),
            title: Text(tr('settings_change_account')),
            onTap: () => _showChangeAccountDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(tr('settings_delete_account')),
            onTap: () => _confirmDeleteAccount(context),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(tr('settings_about')),
            onTap: () => _showAboutDialog(context),
          ),
          // Vývojářské nástroje - pouze v režimu debug
          if (kDebugMode) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Vývojářské nástroje', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.security, color: Colors.orange),
              title: const Text('Test Firebase oprávnění'),
              subtitle: const Text('Otestuje čtení, zápis a mazání v Firestore'),
              onTap: () => _testFirebasePermissions(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.blue),
              title: const Text('Reset Onboarding (Dev)'),
              subtitle: const Text('Resetuje celý onboarding flow'),
              onTap: () => _resetOnboarding(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_search, color: Colors.green),
              title: const Text('Informace o uživateli'),
              subtitle: const Text('Zobrazí detaily o přihlášeném uživateli'),
              onTap: () => _showCurrentUserInfo(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog pro výběr jazyka.
class LanguageDialog extends StatelessWidget {
  const LanguageDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('settings_language')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Čeština'),
            onTap: () {
              debugPrint('[LanguageDialog] Changing language to Czech');
              context.setLocale(const Locale('cs'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('English'),
            onTap: () {
              debugPrint('[LanguageDialog] Changing language to English');
              context.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Dialog pro změnu účtu.
class ChangeAccountDialog extends StatelessWidget {
  const ChangeAccountDialog({Key? key}) : super(key: key);

  /// Změní roli účtu na zadanou hodnotu.
  Future<void> _changeAccountRole(BuildContext context, String newRole) async {
    debugPrint('[ChangeAccountDialog] Changing account role to: $newRole');
    try {
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('[ChangeAccountDialog] Current user: ${user.uid}');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'role': newRole});
        debugPrint('[ChangeAccountDialog] Account role updated successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('account_role_changed'))),
        );
        Navigator.pop(context);
      } else {
        debugPrint('[ChangeAccountDialog] No user found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('no_user_found'))),
        );
      }
    } catch (e, stack) {
      debugPrint('[ChangeAccountDialog] Error changing account role: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('change_account_error')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('settings_change_account')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('choose_account_role')),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.business),
            title: Text(tr('supplier')),
            onTap: () => _changeAccountRole(context, 'supplier'),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(tr('wedding_planner')),
            onTap: () => _changeAccountRole(context, 'wedding'),
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
  }
}

/// Dialog pro potvrzení smazání účtu.
class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('settings_delete_account')),
      content: Text(tr('confirm_delete_account')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(tr('confirm')),
        ),
      ],
    );
  }
}