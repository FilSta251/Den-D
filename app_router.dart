#!/bin/bash

# Skript pro vylepšení a refaktoring aplikace pro plánování svateb
# Autor: Claude
# Datum: 2025-05-08

echo "===== Začínám vylepšování aplikace ====="

# Vytvoření adresářové struktury pro router a témata
mkdir -p lib/router
mkdir -p lib/theme
mkdir -p lib/services

echo "===== Vytvářím AppRouter ====="

# Vytvoření souboru app_router.dart
cat > lib/router/app_router.dart << 'EOF'
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
EOF

echo "===== Vytvářím NavigationService ====="

# Vytvoření navigation_service.dart
cat > lib/services/navigation_service.dart << 'EOF'
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
EOF

echo "===== Vytvářím AppTheme ====="

# Vytvoření app_theme.dart
cat > lib/theme/app_theme.dart << 'EOF'
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
EOF

echo "===== Vytvářím CloudScheduleService ====="

# Vytvoření cloud_schedule_service.dart
cat > lib/services/cloud_schedule_service.dart << 'EOF'
// lib/services/cloud_schedule_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import '../services/local_schedule_service.dart';

/// Služba pro cloudovou synchronizaci harmonogramu svatby.
/// 
/// Umožňuje:
/// - Ukládání harmonogramu do Firestore
/// - Načítání harmonogramu z Firestore
/// - Synchronizaci mezi zařízeními
/// - Sledování změn v reálném čase
class CloudScheduleService {
  final FirebaseFirestore _firestore;
  final fb.FirebaseAuth _auth;
  
  CloudScheduleService({
    FirebaseFirestore? firestore,
    fb.FirebaseAuth? auth,
  }) : 
    _firestore = firestore ?? FirebaseFirestore.instance,
    _auth = auth ?? fb.FirebaseAuth.instance;
  
  /// Vrací ID aktuálně přihlášeného uživatele, nebo null pokud není nikdo přihlášen.
  String? get _userId => _auth.currentUser?.uid;
  
  /// Vrací referenci na kolekci harmonogramu pro aktuálního uživatele.
  CollectionReference<Map<String, dynamic>> _getScheduleCollection() {
    if (_userId == null) {
      throw Exception('Uživatel není přihlášen.');
    }
    return _firestore.collection('users').doc(_userId).collection('schedule');
  }
  
  /// Získá stream položek harmonogramu, který se aktualizuje v reálném čase.
  Stream<List<ScheduleItem>> getScheduleItemsStream() {
    try {
      return _getScheduleCollection()
          .orderBy('time', descending: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ScheduleItem.fromJson(data);
        }).toList();
      });
    } catch (e, stackTrace) {
      debugPrint('Error getting schedule items stream: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      // Vracíme prázdný stream v případě chyby
      return Stream.value([]);
    }
  }
  
  /// Načte položky harmonogramu z Firestore.
  Future<List<ScheduleItem>> fetchScheduleItems() async {
    try {
      final snapshot = await _getScheduleCollection().orderBy('time', descending: false).get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ScheduleItem.fromJson(data);
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('Error fetching schedule items: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      // Vracíme prázdný seznam v případě chyby
      return [];
    }
  }
  
  /// Přidá novou položku do harmonogramu.
  Future<void> addItem(ScheduleItem item) async {
    try {
      await _getScheduleCollection().doc(item.id).set(item.toJson());
    } catch (e, stackTrace) {
      debugPrint('Error adding schedule item: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Aktualizuje existující položku harmonogramu.
  Future<void> updateItem(ScheduleItem item) async {
    try {
      await _getScheduleCollection().doc(item.id).update(item.toJson());
    } catch (e, stackTrace) {
      debugPrint('Error updating schedule item: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Odstraní položku harmonogramu.
  Future<void> removeItem(String itemId) async {
    try {
      await _getScheduleCollection().doc(itemId).delete();
    } catch (e, stackTrace) {
      debugPrint('Error removing schedule item: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Vymaže všechny položky harmonogramu.
  Future<void> clearAllItems() async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _getScheduleCollection().get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('Error clearing all schedule items: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
  
  /// Synchronizuje položky z lokálního úložiště do cloudu.
  Future<void> syncFromLocal(List<ScheduleItem> localItems) async {
    try {
      final batch = _firestore.batch();
      // Nejprve vyčistíme současnou kolekci
      final snapshot = await _getScheduleCollection().get();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      // Pak přidáme všechny lokální položky
      for (final item in localItems) {
        final docRef = _getScheduleCollection().doc(item.id);
        batch.set(docRef, item.toJson());
      }
      await batch.commit();
    } catch (e, stackTrace) {
      debugPrint('Error syncing from local: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }
}
EOF

echo "===== Úprava service_locator.dart ====="

# Výpis aktuálního obsahu service_locator.dart, abychom ho mohli manuálně upravit
cat lib/di/service_locator.dart > service_locator.backup

# Vytvořme modifikovaný service_locator.dart s přidanou NavigationService a CloudScheduleService
# Potřebujeme najít vhodný blok kódu, kam přidat nové služby
cat > lib/di/service_locator.dart.new << 'EOF'
import 'package:get_it/get_it.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

// Repositories
import '../repositories/user_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/wedding_repository.dart';
import '../repositories/subscription_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/tasks_repository.dart';
import '../repositories/supplier_repository.dart';

// Services
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import '../services/local_storage_service.dart';
import '../services/analytics_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/ai_chat_service.dart';
import '../services/navigation_service.dart'; // Nový import
import '../services/cloud_schedule_service.dart'; // Nový import
import '../services/local_schedule_service.dart';

final GetIt locator = GetIt.instance;

/// Inicializace DI a registrace všech služeb a repozitářů.
/// Zavolejte ji jako `await init();` na začátku aplikace.
Future<void> init() async {
  await setupServiceLocator();
}

/// Registruje všechny závislosti.
Future<void> setupServiceLocator() async {
  // Reset locatoru, aby nedošlo k duplicitní registraci (užitečné např. při hot restartu).
  await locator.reset();

  // Asynchroní inicializace základních utilit.
  final sharedPreferences = await SharedPreferences.getInstance();
  final secureStorage = const FlutterSecureStorage();

  // Registrace základních utilit.
  locator.registerSingleton<SharedPreferences>(sharedPreferences);
  locator.registerSingleton<FlutterSecureStorage>(secureStorage);

  // Registrace asynchronních služeb s vlastní inicializací.
  try {
    locator.registerSingletonAsync<NotificationService>(() async {
      final service = NotificationService();
      await service.initialize();
      return service;
    });
  } catch (e) {
    print("Error registering NotificationService: $e");
  }

  try {
    locator.registerSingletonAsync<CrashReportingService>(() async {
      final service = CrashReportingService();
      await service.initialize();
      return service;
    });
  } catch (e) {
    print("Error registering CrashReportingService: $e");
  }

  try {
    locator.registerSingletonAsync<PaymentService>(() async {
      final service = PaymentService();
      // Pokud PaymentService obsahuje metodu configure, zavolejte ji zde:
      // await service.configure();
      return service;
    });
  } catch (e) {
    print("Error registering PaymentService: $e");
  }

  // Firebase závislosti – registrujeme instanci FirebaseAuth.
  locator.registerSingleton<fb.FirebaseAuth>(fb.FirebaseAuth.instance);

  // Registrace hlavních služeb s využitím lazy singletonu.
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<LocalStorageService>(
    () => LocalStorageService(
      sharedPreferences: locator<SharedPreferences>(),
      secureStorage: locator<FlutterSecureStorage>(),
      crashReporting: locator<CrashReportingService>(),
    ),
  );
  locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());

  // Nové služby
  locator.registerLazySingleton<NavigationService>(() => NavigationService());
  locator.registerLazySingleton<CloudScheduleService>(() => CloudScheduleService());
  locator.registerLazySingleton<LocalScheduleService>(() => LocalScheduleService());

  // Registrace repozitářů.
  locator.registerLazySingleton<UserRepository>(() => UserRepository());
  locator.registerLazySingleton<EventRepository>(() => EventRepository());
  locator.registerLazySingleton<WeddingRepository>(() => WeddingRepository());
  locator.registerLazySingleton<SubscriptionRepository>(() => SubscriptionRepository());
  locator.registerLazySingleton<TasksRepository>(() => TasksRepository());
  locator.registerLazySingleton<SupplierRepository>(() => SupplierRepository());

  // Registrace MessageRepository pomocí factory, která přijímá parametr conversationId.
  locator.registerFactoryParam<MessageRepository, String, void>(
    (conversationId, _) => MessageRepository(conversationId: conversationId),
  );

  // Registrace AIChatService.
  locator.registerLazySingleton<AIChatService>(() => AIChatService(
        apiUrl: 'https://api-inference.huggingface.co/models/microsoft/DialoGPT-medium',
        apiKey: 'hf_XXXXXXXXXXXXXXXXXXXXXX', // Nahraďte svým reálným tokenem
      ));

  // Počkáme, až všechny asynchronní registrace dokončí inicializaci.
  await locator.allReady();

  // Debug log: vypíšeme, zda klíčové služby a repozitáře byly registrovány.
  _logRegistrationStatus();
}

/// Pomocná funkce pro výpis registračního statusu.
void _logRegistrationStatus() {
  final servicesToCheck = {
    'AuthService': locator.isRegistered<AuthService>(),
    'NotificationService': locator.isRegistered<NotificationService>(),
    'PaymentService': locator.isRegistered<PaymentService>(),
    'UserRepository': locator.isRegistered<UserRepository>(),
    'MessageRepository': locator.isRegistered<MessageRepository>(),
    'SupplierRepository': locator.isRegistered<SupplierRepository>(),
    'AIChatService': locator.isRegistered<AIChatService>(),
    'NavigationService': locator.isRegistered<NavigationService>(),
    'CloudScheduleService': locator.isRegistered<CloudScheduleService>(),
    'LocalScheduleService': locator.isRegistered<LocalScheduleService>(),
  };

  servicesToCheck.forEach((serviceName, isRegistered) {
    if (isRegistered) {
      print('ServiceLocator: $serviceName registered successfully');
    } else {
      print('ServiceLocator: $serviceName registration failed');
    }
  });
}
EOF

# Nahradit starý soubor novým
mv lib/di/service_locator.dart.new lib/di/service_locator.dart

echo "===== Úprava main.dart ====="

# Záloha původního main.dart
cp lib/main.dart lib/main.dart.backup

# Úprava main.dart
# Tady je třeba být opatrní, potřebujeme správně nahradit import a přepínače témat

cat > lib/main.dart.new << 'EOF'
import 'package:flutter/material.dart';
// Firebase inicializace
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Váš soubor s konfigurací Firebase
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Repositories and Services
import 'repositories/user_repository.dart';
import 'repositories/tasks_repository.dart';
import 'repositories/wedding_repository.dart';
import 'repositories/subscription_repository.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/crash_reporting_service.dart';
import 'di/service_locator.dart' as di;
import 'services/local_storage_service.dart';
import 'services/local_schedule_service.dart';
import 'services/navigation_service.dart';

// Import pro SubscriptionProvider (ChangeNotifier)
import 'providers/subscription_provider.dart';

// Router a Theme
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Konstantní proměnná určující prostředí (např. 'production').
const String environment = "production";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializace EasyLocalization (načtení jazykových překladů)
  await EasyLocalization.ensureInitialized();

  // Inicializace Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.LOCAL);
    debugPrint("Firebase initialized successfully.");
  } catch (e) {
    if (e.toString().contains('[core/duplicate-app]')) {
      debugPrint("Firebase default app already exists. Skipping initialization.");
    } else {
      rethrow;
    }
  }

  // Inicializace service locatoru (DI)
  await di.init();
  await di.locator.allReady();
  debugPrint("Dependency injection initialized.");

  // Nastavení Crashlytics
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  debugPrint("Crashlytics configured.");

  // Inicializace dalších služeb (oznámení, crash-reporting, apod.)
  await di.locator<NotificationService>().initialize();
  await di.locator<CrashReportingService>().initialize();
  debugPrint("Additional services initialized.");

  debugPrint("App starting in $environment environment.");

  // Spuštění aplikace s EasyLocalization
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('cs')],
      path: 'assets/translations', // cesta k JSON překladům
      fallbackLocale: const Locale('en'),
      child: const MyApp(),
    ),
  );
}

/// Kořenový widget aplikace.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // StreamProvider pro FirebaseAuth (přihlášený/odhlášený uživatel)
        StreamProvider<fb.User?>(
          create: (_) => di.locator<AuthService>().authStateChanges,
          initialData: null,
          catchError: (_, __) => null,
        ),
        // Provider pro UserRepository, AuthService a WeddingRepository
        Provider<UserRepository>(create: (_) => di.locator<UserRepository>()),
        Provider<AuthService>(create: (_) => di.locator<AuthService>()),
        Provider<WeddingRepository>(create: (_) => di.locator<WeddingRepository>()),
        // Provider pro SubscriptionRepository (předplatné)
        StreamProvider(
          create: (_) => di.locator<SubscriptionRepository>().subscriptionStream,
          initialData: null,
        ),
        // Lokální správa harmonogramu
        ChangeNotifierProvider<LocalScheduleService>(
          create: (_) => di.locator<LocalScheduleService>(),
        ),
        // SubscriptionProvider jako ChangeNotifier
        ChangeNotifierProvider<SubscriptionProvider>(
        create: (_) => SubscriptionProvider(
            subscriptionRepo: di.locator<SubscriptionRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: tr('app_name'),
        debugShowCheckedModeBanner: false,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        onGenerateRoute: AppRouter.generateRoute,
        navigatorKey: di.locator<NavigationService>().navigatorKey,
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
EOF

# Nahradit starý soubor novým
mv lib/main.dart.new lib/main.dart

echo "===== Úprava schedule_screen.dart pro práci s cloudem ====="

# Vytvoření nového ScheduleManager pro synchronizaci mezi lokálním a cloudovým uložištěm
cat > lib/services/schedule_manager.dart << 'EOF'
// lib/services/schedule_manager.dart

import 'package:flutter/foundation.dart';
import '../services/local_schedule_service.dart';
import '../services/cloud_schedule_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Služba pro správu harmonogramu svatby, která zajišťuje synchronizaci 
/// mezi lokálním a cloudovým uložištěm.
class ScheduleManager extends ChangeNotifier {
  final LocalScheduleService _localService;
  final CloudScheduleService _cloudService;
  final fb.FirebaseAuth _auth;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  
  List<ScheduleItem> get scheduleItems => _localService.scheduleItems;
  
  ScheduleManager({
    required LocalScheduleService localService,
    required CloudScheduleService cloudService,
    fb.FirebaseAuth? auth,
  }) : 
    _localService = localService,
    _cloudService = cloudService,
    _auth = auth ?? fb.FirebaseAuth.instance {
    _init();
  }
  
  void _init() {
    // Poslouchej změny v lokálním harmonogramu
    _localService.addListener(_onLocalScheduleChanged);
    
    // Zkus načíst data z cloudu
    _syncFromCloud();
  }
  
  void _onLocalScheduleChanged() {
    notifyListeners();
    // Pokud nejsme právě uprostřed synchronizace, pošli změny do cloudu
    if (!_isSyncing && _auth.currentUser != null) {
      _pushLocalToCloud();
    }
  }
  
  /// Synchronizuje položky harmonogramu z cloudu do lokálního úložiště.
  Future<void> _syncFromCloud() async {
    if (_auth.currentUser == null) return;
    
    _isSyncing = true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Získej data z cloudu
      final cloudItems = await _cloudService.fetchScheduleItems();
      
      // Pokud jsou data dostupná, nahraď lokální data
      if (cloudItems.isNotEmpty) {
        // Vyčisti původní položky
        _localService.clearAllItems();
        
        // Přidej položky z cloudu
        for (final item in cloudItems) {
          _localService.addItem(item);
        }
        
        debugPrint('Schedule synced from cloud: ${cloudItems.length} items');
      } else {
        // Pokud nejsou cloudová data, zkusíme odeslat lokální data do cloudu
        await _pushLocalToCloud();
      }
    } catch (e, stackTrace) {
      _errorMessage = e.toString();
      debugPrint('Error syncing from cloud: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Odešle lokální harmonogram do cloudu.
  Future<void> _pushLocalToCloud() async {
    if (_auth.currentUser == null || _isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      await _cloudService.syncFromLocal(_localService.scheduleItems);
      debugPrint('Schedule pushed to cloud: ${_localService.scheduleItems.length} items');
    } catch (e, stackTrace) {
      _errorMessage = e.toString();
      debugPrint('Error pushing to cloud: $e');
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Přidá novou položku do harmonogramu.
  void addItem(ScheduleItem item) {
    _localService.addItem(item);
  }
  
  /// Aktualizuje existující položku.
  void updateItem(int index, ScheduleItem updatedItem) {
    _localService.updateItem(index, updatedItem);
  }
  
  /// Odstraní položku na daném indexu.
  void removeItem(int index) {
    _localService.removeItem(index);
  }
  
  /// Změní pořadí položek.
  void reorderItems(int oldIndex, int newIndex) {
    _localService.reorderItems(oldIndex, newIndex);
  }
  
  /// Vymaže všechny položky harmonogramu.
  void clearAllItems() {
    _localService.clearAllItems();
  }
  
  /// Ručně spustí synchronizaci z cloudu.
  Future<void> syncWithCloud() async {
    await _syncFromCloud();
  }
  
  @override
  void dispose() {
    _localService.removeListener(_onLocalScheduleChanged);
    super.dispose();
  }
}
EOF

# Registrace ScheduleManager v service_locator.dart
echo "
# Přidání ScheduleManager do service_locator.dart
cat >> lib/di/service_locator.dart << 'EOF'

// Přidej tyto importy na začátek souboru, pokud ještě neexistují
import '../services/schedule_manager.dart';

// A přidej tuto registraci do setupServiceLocator, před await locator.allReady():
locator.registerLazySingleton<ScheduleManager>(() => ScheduleManager(
  localService: locator<LocalScheduleService>(),
  cloudService: locator<CloudScheduleService>(),
));
EOF
"

echo "===== Vytváření BaseNotifier ====="

# Vytvoření BaseNotifier.dart pro jednotnou správu stavů
cat > lib/providers/base_notifier.dart << 'EOF'
// lib/providers/base_notifier.dart

import 'package:flutter/foundation.dart';

/// Základní třída pro všechny ChangeNotifier providery v aplikaci.
/// 
/// Poskytuje společnou funkčnost pro správu stavů načítání, chyb a dat.
/// Výhody:
/// - Konzistentní stavové proměnné napříč providery
/// - Zjednodušený kód pro nastavení stavů
/// - Snazší použití v UI (jednotné chování)
abstract class BaseNotifier<T> extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  T? _data;
  T? get data => _data;
  
  /// Nastaví stav načítání a vymaže případnou chybovou zprávu.
  void setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
    }
    notifyListeners();
  }
  
  /// Nastaví chybovou zprávu a ukončí stav načítání.
  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Nastaví data a ukončí stav načítání.
  void setData(T data) {
    _data = data;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Vyčistí data, zachová ostatní stavy.
  void clearData() {
    _data = null;
    notifyListeners();
  }
  
  /// Vyčistí chybovou zprávu.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Vyčistí všechny stavy.
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _data = null;
    notifyListeners();
  }
}
EOF

echo "===== Vytváření GlobalWidgets ====="

# Vytvoření global_widgets.dart pro sdílené UI komponenty
cat > lib/widgets/global_widgets.dart << 'EOF'
// lib/widgets/global_widgets.dart

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Třída s globálními widgety pro sjednocený vzhled aplikace.
/// 
/// Poskytuje předdefinované komponenty, které lze použít v celé aplikaci:
/// - Tlačítka
/// - Loadery
/// - Chybové stavy
/// - Prázdné stavy
/// - Dialogy
class GlobalWidgets {
  // Privátní konstruktor znemožní vytvoření instance
  GlobalWidgets._();
  
  /// Primární tlačítko aplikace s konzistentním vzhledem.
  static Widget primaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isFullWidth = false,
    IconData? icon,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: isFullWidth ? const Size.fromHeight(50) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon),
                if (icon != null) const SizedBox(width: 8),
                Text(text, style: const TextStyle(fontSize: 16)),
              ],
            ),
    );
  }
  
  /// Sekundární (méně výrazné) tlačítko aplikace.
  static Widget secondaryButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isFullWidth = false,
    IconData? icon,
  }) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: isFullWidth ? const Size.fromHeight(50) : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) Icon(icon),
                if (icon != null) const SizedBox(width: 8),
                Text(text, style: const TextStyle(fontSize: 16)),
              ],
            ),
    );
  }
  
  /// Widget pro stav načítání.
  static Widget loadingIndicator({String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 16)),
          ],
        ],
      ),
    );
  }
  
  /// Widget pro zobrazení chybového stavu.
  static Widget errorIndicator({
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(tr('retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Widget pro zobrazení prázdného stavu.
  static Widget emptyState({
    required String message,
    IconData icon = Icons.inbox,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.grey,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Zobrazí dialogové okno pro potvrzení akce.
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'confirm',
    String cancelText = 'cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr(cancelText)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(tr(confirmText)),
          ),
        ],
      ),
    );
  }
}
EOF

echo "===== Finální příprava projektu ====="

# Vytvořme skript pro aktualizaci importů ve všech zdrojových souborech
cat > update_imports.sh << 'EOF'
#!/bin/bash

echo "Aktualizuji importy v souborech Dart..."

# Nahrazení přímých cest konstantami z Routes
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/auth"|Navigator.pushNamed(context, Routes.auth|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/main"|Navigator.pushNamed(context, Routes.main|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/brideGroomMain"|Navigator.pushNamed(context, Routes.brideGroomMain|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/profile"|Navigator.pushNamed(context, Routes.profile|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/weddingInfo"|Navigator.pushNamed(context, Routes.weddingInfo|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/weddingSchedule"|Navigator.pushNamed(context, Routes.weddingSchedule|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/subscription"|Navigator.pushNamed(context, Routes.subscription|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/messages"|Navigator.pushNamed(context, Routes.messages|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/settings"|Navigator.pushNamed(context, Routes.settings|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/checklist"|Navigator.pushNamed(context, Routes.checklist|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/calendar"|Navigator.pushNamed(context, Routes.calendar|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/aiChat"|Navigator.pushNamed(context, Routes.aiChat|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/suppliers"|Navigator.pushNamed(context, Routes.suppliers|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/budget"|Navigator.pushNamed(context, Routes.budget|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/guests"|Navigator.pushNamed(context, Routes.guests|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/home"|Navigator.pushNamed(context, Routes.home|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/usageSelection"|Navigator.pushNamed(context, Routes.usageSelection|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/introduction"|Navigator.pushNamed(context, Routes.introduction|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/onboarding"|Navigator.pushNamed(context, Routes.onboarding|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/chatbot"|Navigator.pushNamed(context, Routes.chatbot|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/welcome"|Navigator.pushNamed(context, Routes.welcome|g' {} \;
find lib -name "*.dart" -type f -exec sed -i 's|Navigator\.pushNamed(context, "/"|Navigator.pushNamed(context, Routes.splash|g' {} \;

# Přidání importu Routes tam, kde se používá
find lib -name "*.dart" -type f -exec grep -l "Routes\." {} \; | xargs -I{} sed -i '1,10 s|^import|import '\''../router/app_router.dart'\'';\nimport|' {} \;

echo "Importy aktualizovány!"
EOF

# Dejme skriptu oprávnění k spuštění
chmod +x update_imports.sh

echo "===== Vytvoření dokumentace ====="

# Vytvoření README.md s popisem změn a nové architektury
cat > README.md << 'EOF'
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

## 3. Synchronizace harmonogramu

- Přidán `CloudScheduleService` pro ukládání harmonogramu do Firestore
- Implementován `ScheduleManager` pro synchronizaci mezi lokálním a cloudovým úložištěm
- Automatická synchronizace při změnách

## 4. Jednotný state management

- Vytvořen `BaseNotifier` pro sdílené chování stavů
- Konzistentní správa stavů načítání, chyb a dat
- Lepší zobrazení stavů v UI

## 5. Sdílené UI komponenty

- Globální widgety v `GlobalWidgets`
- Předpřipravené komponenty pro tlačítka, loadery, chybové stavy
- Konzistentní vzhled a chování

## Jak používat nové funkce

### Navigace

```dart
// Import
import '../router/app_router.dart';

// Použití
Navigator.pushNamed(context, Routes.weddingInfo);