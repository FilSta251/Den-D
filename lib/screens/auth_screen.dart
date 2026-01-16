/// lib/screens/auth_screen.dart - FINÁLNÍ FUNKČNÍ VERZE S VÍCEJAZYČNÝMI E-MAILY
/// OPRAVENO: Správné zobrazení social login tlačítek podle platformy
library;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

// Vlastní knihovny ve vašem projektu
import '../repositories/user_repository.dart';
import '../repositories/subscription_repository.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../utils/validators.dart';
import '../utils/constants.dart';
import '../services/onboarding_manager.dart';
import '../di/service_locator.dart';

/// Mapa chybových kódů s vícejazyčnými klíči
Map<String, String> getErrorMessages() => {
      'invalid-email': tr('auth_error_invalid_email'),
      'user-disabled': tr('auth_error_user_disabled'),
      'user-not-found': tr('auth_error_user_not_found'),
      'wrong-password': tr('auth_error_wrong_password'),
      'email-already-in-use': tr('auth_error_email_in_use'),
      'operation-not-allowed': tr('auth_error_operation_not_allowed'),
      'weak-password': tr('auth_error_weak_password'),
      'passwords-dont-match': tr('auth_error_passwords_dont_match'),
      'apple-signin-not-available': tr('auth_error_apple_not_available'),
    };

/// Podporované jazyky s jejich názvy
final Map<String, Map<String, String>> supportedLanguages = {
  'cs': {'name': 'CS', 'fullName': 'Čeština'},
  'en': {'name': 'EN', 'fullName': 'English'},
  'es': {'name': 'ES', 'fullName': 'Español'},
  'uk': {'name': 'UK', 'fullName': 'Українська'},
  'pl': {'name': 'PL', 'fullName': 'Polski'},
  'fr': {'name': 'FR', 'fullName': 'Français'},
  'de': {'name': 'DE', 'fullName': 'Deutsch'},
};

/// AuthScreen zajišťuje registraci, přihlášení, sociální login a zapomenuté heslo.
class AuthScreen extends StatefulWidget {
  final UserRepository userRepository;

  const AuthScreen({super.key, required this.userRepository});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // region: Vlastnosti & controlery
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  AnalyticsService? _analyticsService;
  SubscriptionRepository? _subscriptionRepository;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isBusy = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String _errorMessage = "";
  // endregion

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    _setDefaultLanguage();
    try {
      _analyticsService = locator<AnalyticsService>();
      _subscriptionRepository = locator<SubscriptionRepository>();
    } catch (e) {
      debugPrint('Nepodařilo se získat services z DI: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // region: Automatické nastavení jazyka podle lokality
  Future<void> _setDefaultLanguage() async {
    try {
      final systemLocale = Platform.localeName;
      final languageCode = systemLocale.split('_')[0].toLowerCase();

      if (supportedLanguages.containsKey(languageCode)) {
        final prefs = await SharedPreferences.getInstance();
        final savedLanguage = prefs.getString('preferred_language');

        if (savedLanguage == null) {
          if (mounted) {
            await context.setLocale(Locale(languageCode));
          }
          await prefs.setString('preferred_language', languageCode);
          debugPrint('Automaticky nastaven jazyk: $languageCode');
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final savedLanguage = prefs.getString('preferred_language');

        if (savedLanguage == null) {
          if (mounted) {
            await context.setLocale(const Locale('en'));
          }
          await prefs.setString('preferred_language', 'en');
          debugPrint('Nastaven výchozí jazyk: en');
        }
      }
    } catch (e) {
      debugPrint('Chyba při nastavování automatického jazyka: $e');
      if (mounted) {
        await context.setLocale(const Locale('en'));
      }
    }
  }
  // endregion

  // region: "Pamatuj si mě"
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      if (mounted) {
        _emailController.text = savedEmail;
        setState(() {
          _rememberMe = true;
        });
      }
    }
  }

  Future<void> _saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remembered_email', email);
    } else {
      await prefs.remove('remembered_email');
    }
  }
  // endregion

  // region: Navigační logika

  /// Kontrola aktivního předplatného
  Future<bool> _hasActiveSubscription(String uid) async {
    try {
      if (_subscriptionRepository == null) {
        debugPrint('SubscriptionRepository není k dispozici');
        return false;
      }

      final subscription =
          await _subscriptionRepository!.getCurrentSubscription(uid);
      final isActive = subscription?.isActive ?? false;
      debugPrint('Kontrola předplatného pro $uid: $isActive');
      return isActive;
    } catch (e) {
      debugPrint('Chyba při kontrole předplatného: $e');
      return false;
    }
  }

  /// Navigace po úspěšném PŘIHLÁŠENÍ
  Future<void> _navigateAfterLogin() async {
    if (!mounted) return;

    try {
      debugPrint('=== Navigace po přihlášení (existující uživatel) ===');

      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('Chyba: UID uživatele není k dispozici');
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/introduction');
        }
        return;
      }

      final hasActiveSubscription = await _hasActiveSubscription(uid);
      debugPrint('Aktivní předplatné: $hasActiveSubscription');

      if (!mounted) return;

      if (hasActiveSubscription) {
        debugPrint('→ Má aktivní předplatné, jde přímo na /brideGroomMain');
        Navigator.pushReplacementNamed(context, '/brideGroomMain');
        return;
      }

      final introCompleted =
          await OnboardingManager.isIntroCompleted(userId: uid);
      debugPrint('App Introduction dokončena: $introCompleted');

      if (!mounted) return;

      if (!introCompleted) {
        debugPrint('→ Navigace na /introduction');
        Navigator.pushReplacementNamed(context, '/introduction');
        return;
      }

      final chatbotCompleted =
          await OnboardingManager.isChatbotCompleted(userId: uid);
      debugPrint('Chatbot dokončen: $chatbotCompleted');

      if (!mounted) return;

      if (!chatbotCompleted) {
        debugPrint('→ Navigace na /chatbot');
        Navigator.pushReplacementNamed(context, '/chatbot');
        return;
      }

      // DOČASNĚ: Když je subscription disabled, přeskočíme na hlavní menu
      if (!Billing.subscriptionEnabled) {
        debugPrint('→ Subscription disabled - jde přímo na /brideGroomMain');
        await OnboardingManager.markSubscriptionShown(userId: uid);
        Navigator.pushReplacementNamed(context, '/brideGroomMain');
        return;
      }

      debugPrint('→ Navigace na /subscription (paywall)');
      Navigator.pushReplacementNamed(context, '/subscription');
    } catch (e) {
      debugPrint('Chyba při navigaci po přihlášení: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/introduction');
      }
    }
  }

  /// Navigace po úspěšné REGISTRACI
  Future<void> _navigateAfterRegistration() async {
    if (!mounted) return;

    try {
      debugPrint('=== Navigace po registraci (nový uživatel) ===');

      await OnboardingManager.resetOnboarding();
      debugPrint('Všechny flagy resetovány');

      if (!mounted) return;

      debugPrint('→ Navigace na /introduction (AppIntroductionScreen)');
      Navigator.pushReplacementNamed(context, '/introduction');
    } catch (e) {
      debugPrint('Chyba při navigaci po registraci: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/introduction');
      }
    }
  }
  // endregion

  // region: Přihlášení/registrace
  Future<void> _handleSignInWithEmail() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final fb.UserCredential? userCredential =
          await _authService.signInWithEmail(email, password);

      if (!mounted) return;

      if (userCredential != null) {
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'login_email');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('login_successful'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green,
          ),
        );

        await _saveRememberedEmail(email);
        await _navigateAfterLogin();
      }
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) _showError(e.code);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_validateForm()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('passwords-dont-match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // ✅ DŮLEŽITÉ: Definuj currentLanguage TADY - před jakýmkoli async voláním!
      final currentLanguage = context.locale.languageCode;
      debugPrint('Jazyk pro registraci: $currentLanguage');

      final fb.UserCredential? userCredential =
          await _authService.signUpWithEmail(email, password);

      if (!mounted) return;

      if (userCredential != null) {
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'register_email');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }

        // Teď můžeš použít currentLanguage - už je definovaná
        debugPrint('Odesílám ověřovací e-mail v jazyce: $currentLanguage');
        await _authService.sendEmailVerification(languageCode: currentLanguage);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('registration_successful'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green,
          ),
        );

        await _saveRememberedEmail(email);
        await _navigateAfterRegistration();
      }
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) _showError(e.code);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // endregion

  // region: Sociální login

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final fb.UserCredential? userCredential =
          await _authService.signInWithGoogle();

      if (!mounted) return;

      if (userCredential != null) {
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'login_google');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }

        await _saveRememberedEmail(userCredential.user?.email ?? '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('login_successful'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green,
          ),
        );

        await _navigateAfterLogin();
      }
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) _showError(e.code);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ APPLE SIGN IN
  Future<void> _handleAppleSignIn() async {
    // OPRAVENO: Kontrola platformy před pokusem o Apple Sign-In
    if (!Platform.isIOS && !Platform.isMacOS) {
      _showError('apple-signin-not-available');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final fb.UserCredential? userCredential =
          await _authService.signInWithApple();

      if (!mounted) return;

      if (userCredential != null) {
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'login_apple');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }

        await _saveRememberedEmail(userCredential.user?.email ?? '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('login_successful'),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.green,
          ),
        );

        await _navigateAfterLogin();
      }
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) _showError(e.code);
    } on AuthException catch (e) {
      if (mounted) _showError(e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // endregion

  // region: Zapomenuté heslo
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('enter_email_for_reset'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      final currentLanguage = context.locale.languageCode;
      debugPrint('Odesílám reset hesla pro: $email v jazyce: $currentLanguage');

      await fb.FirebaseAuth.instance.setLanguageCode(currentLanguage);
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('password_reset_sent'),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          backgroundColor: Colors.green,
        ),
      );
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) _showError(e.code);
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
  // endregion

  // region: Změna jazyka
  Future<void> _changeLanguage(String languageCode) async {
    try {
      if (mounted) {
        await context.setLocale(Locale(languageCode));
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('preferred_language', languageCode);

      debugPrint('Jazyk změněn na: $languageCode');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr('language_changed')}: ${supportedLanguages[languageCode]?['fullName'] ?? languageCode}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Chyba při změně jazyka: $e');
    }
  }
  // endregion

  // region: Pomocné metody
  bool _validateForm() {
    final form = _formKey.currentState;
    if (form == null) return false;
    return form.validate();
  }

  void _showError(String errorCode) {
    setState(() {
      _errorMessage = getErrorMessages()[errorCode] ??
          tr('auth_error_generic').replaceAll('{error}', errorCode);
    });
  }
  // endregion

  // region: UI Widgets
  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: tr('email'),
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) => Validators.validateEmail(
              value,
              requiredMessage: tr('enter_email'),
              invalidMessage: tr('auth_error_invalid_email'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: tr('password'),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return tr('enter_password');
              }
              if (value.length < 6) {
                return tr('password_min_length');
              }
              return null;
            },
          ),
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: tr('confirm_password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return tr('confirm_your_password');
                }
                if (value != _passwordController.text) {
                  return tr('auth_error_passwords_dont_match');
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        tr('remember_me'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isBusy ? null : _handleForgotPassword,
                child: _isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        tr('forgot_password'),
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_isLogin ? _handleSignInWithEmail : _handleSignUp),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _isLogin ? tr('login') : tr('register'),
                      style: const TextStyle(fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _isLogin = !_isLogin;
                _errorMessage = "";
                if (_isLogin) {
                  _confirmPasswordController.clear();
                }
              });
            },
            child: Text(_isLogin
                ? tr('dont_have_account')
                : tr('already_have_account')),
          ),
        ],
      ),
    );
  }

  /// OPRAVENO: Zobrazuje správná tlačítka podle platformy
  /// - iOS/macOS: Google + Apple
  /// - Android: Pouze Google
  Widget _buildSocialButtons() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(tr('or_sign_in_with'), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),

        // Google Sign-In - zobrazit na VŠECH platformách
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
            label: Text(tr('continue_with_google')),
          ),
        ),

        // Apple Sign-In - zobrazit POUZE na iOS/macOS
        if (Platform.isIOS || Platform.isMacOS) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleAppleSignIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.apple, color: Colors.white, size: 24),
              label: Text(tr('continue_with_apple')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLanguageSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Text(
            tr('settings_language'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: supportedLanguages.entries.map((entry) {
              final languageCode = entry.key;
              final languageData = entry.value;
              final isSelected = context.locale.languageCode == languageCode;

              return GestureDetector(
                onTap: () => _changeLanguage(languageCode),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    languageData['name']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  // endregion

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? tr('login') : tr('register')),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 80,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                  Text(
                    _isLogin ? tr('login') : tr('register'),
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildEmailForm(),
                  _buildSocialButtons(),
                  _buildLanguageSwitcher(),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
