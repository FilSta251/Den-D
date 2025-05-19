# PowerShell skript pro vylepšení a refaktoring aplikace pro plánování svateb
# Autor: Claude
# Datum: 2025-05-08

Write-Host "===== Začínám vylepšování aplikace =====" -ForegroundColor Green

# Vytvoření adresářové struktury pro router a témata
New-Item -Path "lib\router" -ItemType Directory -Force
New-Item -Path "lib\theme" -ItemType Directory -Force
New-Item -Path "lib\services" -ItemType Directory -Force
New-Item -Path "lib\providers" -ItemType Directory -Force

Write-Host "===== Vytvářím AppRouter =====" -ForegroundColor Green

# Vytvoření souboru app_router.dart
$appRouterContent = @'
// lib/router/app_router.dart

import 'package:flutter/material.dart';
import '../di/service_locator.dart' as di;
import '../repositories/user_repository.dart';

// Import všech obrazovek
import '../screens/splash_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/app_introduction_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/main_menu.dart';
import '../screens/bride_groom_main_menu.dart';
import '../screens/profile_page.dart';
import '../screens/wedding_info_page.dart';
import '../screens/wedding_schedule_screen.dart';
import '../screens/subscription_page.dart';
import '../screens/messages_page.dart';
import '../screens/settings_page.dart';
import '../screens/checklist_screen.dart';
import '../screens/calendar_page.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/suppliers_list_page.dart';
import '../screens/usage_selection_screen.dart';
import '../screens/home_screen.dart';
import '../screens/guests_screen.dart';
import '../screens/budget_screen.dart';
import '../screens/welcome_screen.dart';

/// Centralizovaná třída pro správu navigace v aplikaci.
/// 
/// Poskytuje statické metody pro generování rout a konstanty pro cesty.
class AppRouter {
  /// Generuje route na základě požadované cesty.
  /// Tato metoda by měla být použita v MaterialApp jako onGenerateRoute.
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    WidgetBuilder builder;
    
    switch (settings.name) {
      case Routes.splash:
        builder = (_) => const SplashScreen();
        break;
      case Routes.welcome:
        builder = (_) => const WelcomeScreen();
        break;
      case Routes.auth:
        builder = (_) => AuthScreen(userRepository: di.locator<UserRepository>());
        break;
      case Routes.onboarding:
        builder = (_) => OnboardingScreen(userRepository: di.locator<UserRepository>());
        break;
      case Routes.introduction:
        builder = (_) => const AppIntroductionScreen();
        break;
      case Routes.usageSelection:
        builder = (_) => const UsageSelectionScreen();
        break;
      case Routes.chatbot:
        builder = (_) => const ChatBotScreen();
        break;
      case Routes.main:
        builder = (_) => const MainMenu();
        break;
      case Routes.brideGroomMain:
        builder = (_) => const BrideGroomMainMenu();
        break;
      case Routes.profile:
        builder = (_) => const ProfilePage();
        break;
      case Routes.weddingInfo:
        builder = (_) => const WeddingInfoPage();
        break;
      case Routes.weddingSchedule:
        builder = (_) => const WeddingScheduleScreen();
        break;
      case Routes.subscription:
        builder = (_) => const SubscriptionPage();
        break;
      case Routes.messages:
        builder = (_) => const MessagesPage();
        break;
      case Routes.settings:
        builder = (_) => const SettingsPage();
        break;
      case Routes.checklist:
        builder = (_) => const ChecklistPage();
        break;
      case Routes.calendar:
        builder = (_) => const CalendarPage();
        break;
      case Routes.aiChat:
        builder = (_) => const AIChatScreen();
        break;
      case Routes.suppliers:
        builder = (_) => const SuppliersListPage();
        break;
      case Routes.budget:
        builder = (_) => const BudgetScreen();
        break;
      case Routes.guests:
        builder = (_) => const GuestsScreen();
        break;
      case Routes.home:
        builder = (_) => const HomeScreen();
        break;
      default:
        return _errorRoute(settings.name);
    }
    
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
  
  /// Vytváří chybovou route pro neexistující cestu.
  static Route<dynamic> _errorRoute(String? path) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Text(
            'Stránka "$path" neexistuje.',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}

/// Konstanty pro všechny cesty v aplikaci.
/// 
/// Použití konstant místo přímého zápisu řetězců pomáhá:
/// 1. Předejít překlepům v názvech cest
/// 2. Ulehčit refaktoring při změně názvů cest
/// 3. Poskytnout IDE doplňování při psaní
class Routes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String onboarding = '/onboarding';
  static const String introduction = '/introduction';
  static const String usageSelection = '/usageSelection';
  static const String chatbot = '/chatbot';
  static const String main = '/main';
  static const String brideGroomMain = '/brideGroomMain';
  static const String profile = '/profile';
  static const String weddingInfo = '/weddingInfo';
  static const String weddingSchedule = '/weddingSchedule';
  static const String subscription = '/subscription';
  static const String messages = '/messages';
  static const String settings = '/settings';
  static const String checklist = '/checklist';
  static const String calendar = '/calendar';
  static const String aiChat = '/aiChat';
  static const String suppliers = '/suppliers';
  static const String budget = '/budget';
  static const String guests = '/guests';
  static const String home = '/home';
  
  // Znemožnění vytvoření instance této třídy
  Routes._();
}
'@

Set-Content -Path "lib\router\app_router.dart" -Value $appRouterContent

Write-Host "===== Vytvářím NavigationService =====" -ForegroundColor Green

# Vytvoření navigation_service.dart
$navigationServiceContent = @'
// lib/services/navigation_service.dart

import 'package:flutter/material.dart';

/// Služba pro centralizaci navigační logiky v aplikaci.
/// 
/// Výhody použití:
/// 1. Oddělení navigace od UI
/// 2. Snadné testování
/// 3. Přístup k navigaci odkudkoliv v aplikaci (přes DI)
/// 4. Konzistentní rozhraní pro navigaci
class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Navigace na zadanou cestu s možností předání argumentů.
  Future<dynamic> navigateTo(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }

  /// Navigace na zadanou cestu s odstraněním aktuální cesty ze zásobníku.
  Future<dynamic> navigateToReplacement(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushReplacementNamed(routeName, arguments: arguments);
  }

  /// Navigace na zadanou cestu s odstraněním všech předchozích cest ze zásobníku.
  Future<dynamic> navigateToAndClearStack(String routeName, {Object? arguments}) {
    return navigatorKey.currentState!.pushNamedAndRemoveUntil(
      routeName,
      (Route<dynamic> route) => false,
      arguments: arguments,
    );
  }

  /// Návrat na předchozí cestu.
  void goBack() {
    return navigatorKey.currentState!.pop();
  }
}
'@

Set-Content -Path "lib\services\navigation_service.dart" -Value $navigationServiceContent

Write-Host "===== Vytvářím AppTheme =====" -ForegroundColor Green

# Vytvoření app_theme.dart
$appThemeContent = @'
// lib/theme/app_theme.dart

import 'package:flutter/material.dart';

/// Třída pro centrální správu tématu aplikace.
/// 
/// Poskytuje předdefinovaná témata pro světlý a tmavý režim s konzistentními
/// styly pro všechny komponenty v aplikaci.
class AppTheme {
  /// Světlé téma aplikace.
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
        brightness: Brightness.light,
        primary: Colors.pink.shade800,
        secondary: Colors.amber,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
        elevation: 2,
        scrolledUnderElevation: 4,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
  
  /// Tmavé téma aplikace.
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
        brightness: Brightness.dark,
        primary: Colors.pink.shade300,
        secondary: Colors.amber.shade200,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
        scrolledUnderElevation: 4,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.pink.shade300,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey.shade800,
      ),
    );
  }
}
'@

Set-Content -Path "lib\theme\app_theme.dart" -Value $appThemeContent

Write-Host "===== Úprava service_locator.dart =====" -ForegroundColor Green

# Záloha souboru service_locator.dart
Copy-Item -Path "lib\di\service_locator.dart" -Destination "lib\di\service_locator.backup" -Force

# Přečteme původní obsah service_locator.dart
$serviceLocator = Get-Content -Path "lib\di\service_locator.dart" -Raw

# Přidáme import pro NavigationService
$serviceLocator = $serviceLocator -replace "import '../services/ai_chat_service.dart';", "import '../services/ai_chat_service.dart';`nimport '../services/navigation_service.dart';"

# Přidáme registraci NavigationService
$serviceLocator = $serviceLocator -replace "// Registrace hlavních služeb s využitím lazy singletonu.", "// Registrace hlavních služeb s využitím lazy singletonu.`n  locator.registerLazySingleton<NavigationService>(() => NavigationService());"

# Uložíme upravený soubor
Set-Content -Path "lib\di\service_locator.dart" -Value $serviceLocator

Write-Host "===== Úprava main.dart =====" -ForegroundColor Green

# Záloha main.dart
Copy-Item -Path "lib\main.dart" -Destination "lib\main.dart.backup" -Force

# Přečteme původní obsah main.dart
$mainDart = Get-Content -Path "lib\main.dart" -Raw

# Přidáme importy pro AppRouter a AppTheme
$mainDart = $mainDart -replace "import 'di/service_locator.dart' as di;", "import 'di/service_locator.dart' as di;`nimport 'router/app_router.dart';`nimport 'theme/app_theme.dart';`nimport 'services/navigation_service.dart';"

# Nahradíme definice tématu použitím AppTheme
$mainDart = $mainDart -replace "theme: _buildTheme\(\),`n\s+darkTheme: _buildDarkTheme\(\),", "theme: AppTheme.lightTheme,`n        darkTheme: AppTheme.darkTheme,"

# Nahradíme _generateRoute použitím AppRouter.generateRoute
$mainDart = $mainDart -replace "onGenerateRoute: _generateRoute,", "onGenerateRoute: AppRouter.generateRoute,`n        navigatorKey: di.locator<NavigationService>().navigatorKey,"

# Odstraníme zbytečné metody
$mainDart = $mainDart -replace "/// Světlé téma aplikace.*?\/\/\/ Generátor tras – zde jsou definovány všechny cesty\.", ""

# Odstraníme metodu _generateRoute
$mainDart = $mainDart -replace "Route<dynamic>\? _generateRoute\(RouteSettings settings\).*?}(\s\s+})+", ""

# Uložíme upravený soubor
Set-Content -Path "lib\main.dart" -Value $mainDart

Write-Host "===== Vytváření README.md =====" -ForegroundColor Green

# Vytvoření README.md s popisem změn a nové architektury
$readmeContent = @'
# Vylepšení Svatební Aplikace

Tato aktualizace zahrnuje několik významných vylepšení architektury a kódu:

## 1. Centralizace navigace

- Vytvořená třída `AppRouter` se statickými konstantami pro cesty a metodou `generateRoute`
- Odstraněna duplicita mezi `main.dart` a `routes.dart`
- Jednotný způsob navigace v celé aplikaci

## 2. Unifikace témat

- Centralizované definice tématu v `AppTheme`
- Konzistentní vzhled napříč aplikací
- Podpora světlého a tmavého režimu

## 3. Navigační služba

- Přidána `NavigationService` pro navigaci odkudkoliv v aplikaci
- Konzistentní rozhraní pro navigaci
- Snadnější testování a přístup přes DI

## Jak používat nové funkce

### Navigace

```dart
// Import
import '../router/app_router.dart';

// Standardní navigace
Navigator.pushNamed(context, Routes.weddingInfo);

// Navigace přes službu
import '../di/service_locator.dart' as di;
import '../services/navigation_service.dart';

// Získání instance
final navigationService = di.locator<NavigationService>();

// Použití
navigationService.navigateTo(Routes.weddingInfo);