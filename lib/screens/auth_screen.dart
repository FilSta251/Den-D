// lib/screens/auth_screen.dart - OPRAVENÁ VERZE

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';

// Vlastní knihovny ve vašem projektu
import '../repositories/user_repository.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../utils/validators.dart';
import '../router/app_router.dart';
import '../routes.dart';
import '../services/onboarding_manager.dart';
import '../theme/app_theme.dart';
import '../di/service_locator.dart'; // Import pro service locator

/// Kódy chyb přeložíme do lidské řeči
final Map<String, String> errorMessages = {
  'invalid-email': 'Neplatná e-mailová adresa.',
  'user-disabled': 'Tento účet byl deaktivován.',
  'user-not-found': 'Účet neexistuje, zkontrolujte e-mail.',
  'wrong-password': 'Nesprávné heslo.',
  'email-already-in-use': 'E-mail je již používán. Zkuste se přihlásit nebo použijte jiný e-mail.',
  'operation-not-allowed': 'Tento typ přihlášení není povolen.',
  'weak-password': 'Heslo je příliš slabé.',
  'passwords-dont-match': 'Hesla se neshodují.',
};

/// AuthScreen zajišťuje registraci, přihlášení, sociální login, "zapomenuté heslo"
/// a volitelnou volbu "pamatuj si mě" pro e-mail.
///
/// Po úspěšném přihlášení/registraci navazuje multi-step flow.
class AuthScreen extends StatefulWidget {
  final UserRepository userRepository;

  const AuthScreen({Key? key, required this.userRepository}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // region: Vlastnosti & controlery
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final AuthService _authService = AuthService();
  // Získáme AnalyticsService z DI místo inicializace v kódu
  AnalyticsService? _analyticsService;

  bool _isLogin = true;       // režim přihlášení vs. registrace
  bool _isLoading = false;    // spinner pro primární akci
  bool _isBusy = false;       // spinner pro doplňující akce (např. reset hesla)
  bool _rememberMe = false;   // volba "pamatuj e-mail"
  bool _obscurePassword = true;  // Zobrazit/skrýt heslo
  bool _obscureConfirmPassword = true;  // Zobrazit/skrýt potvrzení hesla

  String _errorMessage = "";
  // endregion

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    // Získáme instanci AnalyticsService z service locatoru, když je dostupný
    try {
      _analyticsService = locator<AnalyticsService>();
    } catch (e) {
      debugPrint('Nepodařilo se získat AnalyticsService z DI: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // region: "Pamatuj si mě" – ukládáme e-mail do SharedPreferences
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
      setState(() {
        _rememberMe = true;
      });
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

  // region: Navigace na další obrazovku po úspěšném přihlášení
  Future<void> _navigateAfterAuth() async {
    // Kontrola, zda uživatel dokončil celý onboarding
    final onboardingCompleted = await OnboardingManager.isOnboardingCompleted();
    
    if (onboardingCompleted) {
      // Pokud ano, přejdeme přímo na hlavní menu
      Navigator.pushReplacementNamed(context, '/brideGroomMain');
    } else {
      // Kontrola, zda uživatel již dokončil některé části onboardingu
      final introCompleted = await OnboardingManager.isIntroCompleted();
      final chatbotCompleted = await OnboardingManager.isChatbotCompleted();
      final subscriptionShown = await OnboardingManager.isSubscriptionShown();
      
      if (subscriptionShown) {
        // Pokud už viděl nabídku předplatného, rovnou na hlavní menu
        Navigator.pushReplacementNamed(context, '/brideGroomMain');
        await OnboardingManager.markOnboardingCompleted(); // Označíme jako dokončené
      } else if (chatbotCompleted) {
        // Pokud dokončil chatbota, pokračuje na předplatné
        Navigator.pushReplacementNamed(context, '/subscription');
      } else if (introCompleted) {
        // Pokud dokončil intro, pokračuje na chatbota
        Navigator.pushReplacementNamed(context, '/chatbot');
      } else {
        // Jinak začne od začátku - intro
        Navigator.pushReplacementNamed(context, '/introduction');
      }
    }
  }
  // endregion

  // region: Logika pro přihlášení/registraci + spouštění multi-step flow
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

      if (userCredential != null) {
        // OPRAVA: Použití instance analytiky z DI, když je dostupná
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'login_email');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }
        
        // Zobrazíme úspěšné přihlášení
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('login_successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        await _saveRememberedEmail(email);
        await _navigateAfterAuth();
      }
    } on fb.FirebaseAuthException catch (e) {
      _showError(e.code);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_validateForm()) return;
    
    // Ověření, že hesla se shodují
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

      final fb.UserCredential? userCredential =
          await _authService.signUpWithEmail(email, password);

      if (userCredential != null) {
        // OPRAVA: Použití instance analytiky z DI, když je dostupná
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'register_email');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }
        
        // Odeslání verifikačního emailu
        await userCredential.user?.sendEmailVerification();
        
        // Informování uživatele
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('registration_successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        await _saveRememberedEmail(email);
        
        // Pro nové uživatele vždy začínáme od intro obrazovky
        await OnboardingManager.resetOnboarding();
        Navigator.pushReplacementNamed(context, '/introduction');
      }
    } on fb.FirebaseAuthException catch (e) {
      _showError(e.code);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // endregion

  // region: Sociální login – Google, Facebook
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });
    try {
      final fb.UserCredential? userCredential =
          await _authService.signInWithGoogle();
      if (userCredential != null) {
        // OPRAVA: Použití instance analytiky z DI, když je dostupná
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'login_google');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }
        
        await _saveRememberedEmail(userCredential.user?.email ?? '');
        
        // Zobrazíme úspěšné přihlášení
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('login_successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        await _navigateAfterAuth();
      }
    } on fb.FirebaseAuthException catch (e) {
      _showError(e.code);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleFacebookSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });
    try {
      final fb.UserCredential? userCredential =
          await _authService.signInWithFacebook();
      if (userCredential != null) {
        // OPRAVA: Použití instance analytiky z DI, když je dostupná
        if (_analyticsService != null) {
          try {
            _analyticsService!.logEvent(name: 'login_facebook');
          } catch (e) {
            debugPrint('Chyba při logování analytiky: $e');
          }
        }
        
        await _saveRememberedEmail(userCredential.user?.email ?? '');
        
        // Zobrazíme úspěšné přihlášení
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('login_successful')),
            backgroundColor: Colors.green,
          ),
        );
        
        await _navigateAfterAuth();
      }
    } on fb.FirebaseAuthException catch (e) {
      _showError(e.code);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  // endregion

  // region: Zapomenuté heslo
  Future<void> _handleForgotPassword() async {
    setState(() => _isBusy = true);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError(tr('enter_email'));
      setState(() => _isBusy = false);
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      
      // OPRAVA: Použití instance analytiky z DI, když je dostupná
      if (_analyticsService != null) {
        try {
          _analyticsService!.logEvent(name: 'forgot_password');
        } catch (e) {
          debugPrint('Chyba při logování analytiky: $e');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('password_reset_sent', args: [email])),
          backgroundColor: Colors.blue,
        ),
      );
    } on fb.FirebaseAuthException catch (e) {
      _showError(e.code);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isBusy = false);
    }
  }
  // endregion

  // region: Helpery – validace, chyby
  bool _validateForm() {
    final form = _formKey.currentState;
    return form?.validate() ?? false;
  }

  void _showError(String codeOrMessage) {
    final msg = errorMessages[codeOrMessage] ?? codeOrMessage;
    setState(() => _errorMessage = msg);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('auth_error', args: [msg])),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: tr('common.ok'),
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  // endregion

  // region: UI – formulář, sociální login, jazyk, zapomenuté heslo
  Widget _buildEmailForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              labelText: tr('email'),
              hintText: tr('enter_email'),
              prefixIcon: const Icon(Icons.email),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              return Validators.composeValidators(value, [
                Validators.validateRequired,
                Validators.validateEmail,
              ]);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: tr('password'),
              hintText: tr('enter_password'),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            obscureText: _obscurePassword,
            textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
            validator: (value) {
              return Validators.composeValidators(value, [
                Validators.validateRequired,
                (val) => Validators.validatePassword(val, minLength: 6),
              ]);
            },
          ),
          // Přidat pole pro potvrzení hesla, zobrazit pouze v režimu registrace
          if (!_isLogin) 
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                controller: _confirmPasswordController,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: tr('confirm_password'),
                  hintText: tr('repeat_password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                ),
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return tr('passwords_dont_match');
                  }
                  return null;
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _rememberMe = val;
                      });
                    },
                  ),
                  Text(tr('remember_me')),
                ],
              ),
              TextButton(
                onPressed: _handleForgotPassword,
                child: _isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(tr('forgot_password')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLogin ? _handleSignInWithEmail : _handleSignUp,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _isLogin 
                  ? _isLoading ? tr('logging_in') : tr('login')
                  : _isLoading ? tr('registering') : tr('register'),
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
                // Vyčistit pole pro potvrzení hesla při přepnutí režimu
                if (_isLogin) {
                  _confirmPasswordController.clear();
                }
              });
            },
            child: Text(
              _isLogin 
                ? tr('dont_have_account') 
                : tr('already_have_account')
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(tr('or_sign_in_with'), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google přihlášení
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.g_mobiledata, color: Colors.red, size: 24),
                  label: Text(tr('continue_with_google')),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Facebook přihlášení
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _handleFacebookSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.facebook, color: Colors.white, size: 24),
                  label: Text(tr('continue_with_facebook')),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: () {
              context.setLocale(const Locale('cs'));
            },
            child: const Text('Čeština'),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () {
              context.setLocale(const Locale('en'));
            },
            child: const Text('English'),
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
                  // Logo nebo ikona aplikace
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 80,
                    ),
                  ),
                  // Nadpis obrazovky
                  Text(
                    _isLogin ? tr('login') : tr('register'),
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold
                    ),
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