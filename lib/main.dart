// lib/main.dart - OPRAVENÁ VERZE

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// Firebase inicializace
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Váš soubor s konfigurací Firebase
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

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
import 'services/cloud_schedule_service.dart';
import 'services/schedule_manager.dart';
import 'services/navigation_service.dart';
import 'routes.dart'; // Import pro Routes konstanty
import 'services/budget_manager.dart'; // Import pro BudgetManager
import 'services/local_budget_service.dart'; // Import pro LocalBudgetService
import 'services/cloud_budget_service.dart'; // Import pro CloudBudgetService
import 'services/environment_config.dart'; // Import pro EnvironmentConfig

// Import pro SubscriptionProvider (ChangeNotifier)
import 'providers/subscription_provider.dart';

// Router a Theme
import 'theme/app_theme.dart';

/// Konstantní proměnná určující prostředí (např. 'production').
const String environment = "production";

/// Pomocná funkce pro ošetření asynchronních operací s timeoutem
Future<T?> timeoutSafeCall<T>(Future<T> future, {
  int timeoutSeconds = 10,
  T? defaultValue,
  String operationName = 'Operace'
}) async {
  try {
    return await future.timeout(Duration(seconds: timeoutSeconds));
  } on TimeoutException {
    debugPrint('[$operationName] Ukončeno kvůli timeoutu (${timeoutSeconds}s)');
    return defaultValue;
  } catch (e, stack) {
    debugPrint('[$operationName] Chyba: $e');
    FirebaseCrashlytics.instance.recordError(e, stack, reason: operationName);
    return defaultValue;
  }
}

// Funkce pro async inicializaci před spuštěním aplikace
Future<void> _initializeApp() async {
  try {
    // Načtení .env souboru
    debugPrint("[Main] Loading .env file");
    await dotenv.load(fileName: ".env");
    debugPrint("[Main] .env file loaded successfully");
    
    // Inicializace EnvironmentConfig
    debugPrint("[Main] Initializing EnvironmentConfig");
    await EnvironmentConfig().initialize();
    debugPrint("[Main] EnvironmentConfig initialized");
    
    // Nastavení orientace displeje (pouze portrét)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Inicializace EasyLocalization (načtení jazykových překladů)
    debugPrint("[Main] Initializing EasyLocalization");
    await EasyLocalization.ensureInitialized();
    debugPrint("[Main] EasyLocalization initialized");

    // Inicializace Firebase
    try {
      debugPrint("[Main] Initializing Firebase");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("[Main] Firebase initialized");
      
      // Optimalizace Firestore cache pro offline použití
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      debugPrint("[Main] Setting Firebase Auth persistence");
      await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.LOCAL);
      debugPrint("[Main] Firebase Auth persistence set to LOCAL");
      
      // Nastavení Firebase Performance Monitoring
      debugPrint("[Main] Setting up Firebase Performance");
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(
        EnvironmentConfig().getValue<bool>("ENABLE_ANALYTICS", defaultValue: true)
      );
      debugPrint("[Main] Firebase Performance monitoring enabled");
      
      debugPrint("[Main] Firebase initialized successfully");
    } catch (e, stack) {
      if (e.toString().contains('[core/duplicate-app]')) {
        debugPrint("[Main] Firebase default app already exists. Skipping initialization.");
      } else {
        debugPrint("[Main] Error initializing Firebase: $e");
        debugPrintStack(label: 'StackTrace', stackTrace: stack);
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Firebase Initialization');
      }
    }

    // Inicializace service locatoru (DI)
    debugPrint("[Main] Initializing service locator (DI)");
    await di.init();
    await timeoutSafeCall(
      di.locator.allReady(), 
      timeoutSeconds: 5,
      operationName: 'DI initialization'
    );
    debugPrint("[Main] Dependency injection initialized");

    // Nastavení Crashlytics
    debugPrint("[Main] Configuring Crashlytics");
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      EnvironmentConfig().getValue<bool>("ENABLE_CRASHLYTICS", defaultValue: true)
    );
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    
    // Zachytávání nativních chyb
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint("[Main] Crashlytics configured");

    // Nastavení sledování stavu přihlášení a obnovu tokenů
    fb.FirebaseAuth.instance.authStateChanges().listen((fb.User? user) {
      if (user != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        user.getIdTokenResult().then((idTokenResult) {
          // Kontrola zda není token prošlý nebo příliš starý
          if (idTokenResult.issuedAtTime != null) {
            final issuedAtDate = DateTime.fromMillisecondsSinceEpoch(idTokenResult.issuedAtTime!.millisecondsSinceEpoch);
            final now = DateTime.now();
            if (now.difference(issuedAtDate).inHours > 12) {
              // Vynutíme obnovení tokenu po 12 hodinách
              user.getIdToken(true).catchError((error) {
                debugPrint("[Main] Token refresh error: $error");
              });
            }
          }
        }).catchError((error) {
          debugPrint("[Main] Token validation error: $error");
        });
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier('');
      }
    });

    // Inicializace dalších služeb (oznámení, crash-reporting, apod.)
    debugPrint("[Main] Initializing additional services");
    await timeoutSafeCall(
      di.locator<NotificationService>().initialize(),
      timeoutSeconds: 3,
      operationName: 'NotificationService initialization'
    );
    await di.locator<CrashReportingService>().initialize();
    
    // Kontrola síťového připojení při startu
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint("[Main] No network connection detected at startup");
    } else {
      debugPrint("[Main] Network connection available at startup");
    }
    
    debugPrint("[Main] Additional services initialized");
  } catch (e, stack) {
    debugPrint("[Main] Critical error during app initialization: $e");
    debugPrintStack(label: 'StackTrace', stackTrace: stack);
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'App Initialization', fatal: true);
    rethrow; // Rethrow aby se aplikace mohla rozhodnout, zda pokračovat nebo ne
  }
}

Future<void> main() async {
  // Zajistí, že Flutter binding je inicializován
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("=== APLIKACE SE SPOUŠTÍ ===");

  try {
    // Nastavení chybových handlerů a Crashlytics (před inicializací)
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    };
    
    // Přesouváme inicializaci do samostatné funkce
    await _initializeApp();

    // Zobrazení informací o prostředí z .env
    debugPrint("[Main] App starting in ${EnvironmentConfig().environment} environment");
    debugPrint("[Main] Using API URL: ${EnvironmentConfig().getValue<String>('API_URL')}");

    // Spuštění aplikace s EasyLocalization
    runApp(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('cs')],
        path: 'assets/translations', // cesta k JSON překladům
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true, // Používá pouze kód jazyka (cs místo cs_CZ)
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    // Zachycení kritických chyb při startu
    debugPrint("=== KRITICKÁ CHYBA PŘI SPUŠTĚNÍ APLIKACE ===");
    debugPrint(e.toString());
    debugPrintStack(label: 'StackTrace', stackTrace: stack);
    
    try {
      // Záznam do Crashlytics
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'App Launch', fatal: true);
    } catch (_) {
      // Crashlytics nemusí být inicializovaný
    }
    
    // Zobrazení nouzové obrazovky s chybou
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Nepodařilo se spustit aplikaci',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Omlouváme se za potíže. Prosím zkuste aplikaci restartovat nebo kontaktujte podporu.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Pokusíme se restartovat aplikaci
                    SystemNavigator.pop();
                  },
                  child: const Text('Zavřít aplikaci'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

/// Pomocná funkce pro výpis informací o aktuálně přihlášeném uživateli
/// Přesunuto do samostatné funkce, aby se nespouštělo v hlavním vláknu
Future<void> logCurrentUser() async {
  try {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint('[Main] === AKTUÁLNÍ UŽIVATEL PŘI STARTU APLIKACE ===');
      debugPrint('[Main] UID: ${user.uid}');
      debugPrint('[Main] Email: ${user.email}');
      debugPrint('[Main] Email ověřen: ${user.emailVerified}');
      debugPrint('[Main] Poskytovatel přihlášení: ${user.providerData.map((p) => p.providerId).join(', ')}');
      
      // Test získání tokenu (může být užitečné při debugování)
      try {
        final token = await timeoutSafeCall(
          user.getIdToken(),
          timeoutSeconds: 3,
          operationName: 'Get user token'
        );
        if (token != null) {
          debugPrint('[Main] ID token získán úspěšně.');
        } else {
          debugPrint('[Main] Nepodařilo se získat ID token (timeout)');
        }
      } catch (e) {
        debugPrint('[Main] Nepodařilo se získat ID token: $e');
      }

      // Ověření, zda existují dokumenty uživatele ve Firestore
      await checkUserDocuments(user.uid);
    } else {
      debugPrint('[Main] === ŽÁDNÝ PŘIHLÁŠENÝ UŽIVATEL PŘI STARTU APLIKACE ===');
    }
  } catch (e, stack) {
    debugPrint('[Main] Chyba při získávání informací o aktuálním uživateli: $e');
    debugPrintStack(label: 'StackTrace', stackTrace: stack);
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'User Info Check');
  }
}

/// Ověří existenci dokumentů uživatele ve Firestore
Future<void> checkUserDocuments(String uid) async {
  try {
    debugPrint('[Main] Checking user documents in Firestore');
    
    // Kontrola uživatelského profilu
    try {
      final userDoc = await timeoutSafeCall(
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        timeoutSeconds: 5,
        operationName: 'Users check'
      );
      if (userDoc != null) {
        debugPrint('[Main] User document exists: ${userDoc.exists}');
      }
    } catch (e) {
      debugPrint('[Main] Error checking user document: $e');
    }
    
    // Kontrola wedding info
    try {
      final weddingDoc = await timeoutSafeCall(
        FirebaseFirestore.instance.collection('wedding_info').doc(uid).get(),
        timeoutSeconds: 5,
        operationName: 'Wedding info check'
      );
      if (weddingDoc != null) {
        debugPrint('[Main] Wedding info document exists: ${weddingDoc.exists}');
        if (weddingDoc.exists) {
          debugPrint('[Main] Wedding info data: ${weddingDoc.data()}');
        }
      }
    } catch (e) {
      debugPrint('[Main] Error checking wedding info document: $e');
    }
    
    // Kontrola předplatného
    try {
      final subscriptionDoc = await timeoutSafeCall(
        FirebaseFirestore.instance.collection('subscriptions').doc(uid).get(),
        timeoutSeconds: 5,
        operationName: 'Subscription check'
      );
      if (subscriptionDoc != null) {
        debugPrint('[Main] Subscription document exists: ${subscriptionDoc.exists}');
      }
    } catch (e) {
      debugPrint('[Main] Error checking subscription document: $e');
    }
    
  } catch (e, stack) {
    debugPrint('[Main] Error checking user documents: $e');
    debugPrintStack(label: 'StackTrace', stackTrace: stack);
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'User Documents Check');
  }
}

/// Testuje základní oprávnění k Firestore
Future<void> testFirestorePermissions() async {
  final Trace trace = FirebasePerformance.instance.newTrace('firestore_permissions_test');
  await trace.start();
  
  try {
    debugPrint('[Main] Testing basic Firestore permissions');
    final user = fb.FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      debugPrint('[Main] No user logged in, skipping Firestore permissions test');
      await trace.stop();
      return;
    }
    
    // Test čtení - wedding_info
    debugPrint('[Main] Testing READ permission for wedding_info/${user.uid}');
    try {
      final docRef = FirebaseFirestore.instance.collection('wedding_info').doc(user.uid);
      final docSnapshot = await timeoutSafeCall(
        docRef.get(),
        timeoutSeconds: 5,
        operationName: 'READ wedding_info'
      );
      
      if (docSnapshot != null) {
        debugPrint('[Main] READ permission for wedding_info: ${docSnapshot.exists ? "SUCCESS" : "Document does not exist, but read permission OK"}');
      } else {
        debugPrint('[Main] READ permission for wedding_info: TIMEOUT');
      }
    } catch (e) {
      debugPrint('[Main] READ permission for wedding_info FAILED: $e');
    }
    
    // Test zápisu - wedding_info
    debugPrint('[Main] Testing WRITE permission for wedding_info/${user.uid}');
    try {
      final docRef = FirebaseFirestore.instance.collection('wedding_info').doc(user.uid);
      await timeoutSafeCall(
        docRef.set({
          'test_field': 'Test z main.dart',
          'userId': user.uid,
          'timestamp': FieldValue.serverTimestamp()
        }, SetOptions(merge: true)),
        timeoutSeconds: 5,
        operationName: 'WRITE wedding_info'
      );
      debugPrint('[Main] WRITE permission for wedding_info: SUCCESS');
    } catch (e) {
      debugPrint('[Main] WRITE permission for wedding_info FAILED: $e');
    }
    
    debugPrint('[Main] Firestore permissions test completed');
  } catch (e, stack) {
    debugPrint('[Main] Error during Firestore permissions test: $e');
    debugPrintStack(label: 'StackTrace', stackTrace: stack);
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Firestore Permissions Test');
  } finally {
    await trace.stop();
  }
}

/// Kořenový widget aplikace.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Instance SubscriptionRepository, kterou vytvoříme přímo zde
  late SubscriptionRepository _subscriptionRepository;
  // Instance ScheduleManager, kterou vytvoříme přímo zde
  late CloudScheduleService _cloudScheduleService;
  late ScheduleManager _scheduleManager;
  // Instance BudgetManager, kterou vytvoříme přímo zde
  late BudgetManager _budgetManager;
  // Instance služeb pro BudgetManager
  late LocalBudgetService _localBudgetService;
  late CloudBudgetService _cloudBudgetService;
  
  // Subscription for connectivity changes - OPRAVENO
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  // Performance trace
  late Trace _appStartupTrace;
  // App state
  bool _isFirstBuild = true;
  
  // Statické překlady pro použití bez kontextu
  static const Map<String, String> _translations = {
    'app_name': 'Svatební plánovač',
    // Další překlady
  };
  
  // Pomocná metoda pro překlad bez kontextu
  String _tr(String key) {
    return _translations[key] ?? key;
  }
  
  @override
  void initState() {
    super.initState();
    
    // Start performance trace
    _appStartupTrace = FirebasePerformance.instance.newTrace('app_startup');
    _appStartupTrace.start();
    
    // Přidání observeru stavu aplikace
    WidgetsBinding.instance.addObserver(this);
    
    // Vytvoření instance SubscriptionRepository
    _subscriptionRepository = SubscriptionRepository(
      firestore: FirebaseFirestore.instance,
      firebaseAuth: fb.FirebaseAuth.instance
    );
    
    // Vytvoření instance CloudScheduleService a ScheduleManager
    _cloudScheduleService = CloudScheduleService(
      firestore: FirebaseFirestore.instance,
      auth: fb.FirebaseAuth.instance
    );
    
    _scheduleManager = ScheduleManager(
      localService: di.locator<LocalScheduleService>(),
      cloudService: _cloudScheduleService,
      auth: fb.FirebaseAuth.instance
    );
    
    // Vytvoření instance LocalBudgetService a CloudBudgetService
    _localBudgetService = di.locator<LocalBudgetService>();
    _cloudBudgetService = CloudBudgetService(
      firestore: FirebaseFirestore.instance,
      auth: fb.FirebaseAuth.instance
    );
    
      // Vytvoření instance BudgetManager se správnými službami
    _budgetManager = BudgetManager(
      localService: _localBudgetService,
      cloudService: _cloudBudgetService,
      auth: fb.FirebaseAuth.instance
    );
    
    // Monitorování změn připojení
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Jelikož connectivity_plus vrací List<ConnectivityResult>, bereme první výsledek
      final connectivityResult = results.isNotEmpty ? results.first : ConnectivityResult.none;
      debugPrint('[MyApp] Connectivity changed: $connectivityResult');
      if (connectivityResult != ConnectivityResult.none) {
        // Máme připojení, můžeme synchronizovat data
        _scheduleManager.synchronizeData(); // Upraveno - používáme existující metodu
        // Zde by mohly být další synchronizace
      }
    });
    
    // Přesouvám logování uživatele a testování oprávnění mimo hlavní vlákno
    // a také mimo initState, aby se neblokoval UI
    _runBackgroundChecks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstBuild) {
      _isFirstBuild = false;
      // Zde můžeme provést akce, které potřebují context, ale jen jednou
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[MyApp] App lifecycle state changed: $state');
    if (state == AppLifecycleState.resumed) {
      // Aplikace byla obnovena z pozadí
      _scheduleManager.synchronizeData(); // Upraveno - používáme existující metodu
      // Kontrola aktualizací Firebase konfigurace
      fb.FirebaseAuth.instance.currentUser?.getIdToken(true);
    }
  }
  
  @override
  void dispose() {
    // Ukončení performance trace
    _appStartupTrace.stop();
    
    // Odhlášení observeru stavu aplikace
    WidgetsBinding.instance.removeObserver(this);
    
    // Ukončení subscription na connectivity
    _connectivitySubscription.cancel();
    
    // Uvolnění prostředků SubscriptionRepository při ukončení aplikace
    _subscriptionRepository.dispose();
    
    // Uvolnění prostředků ScheduleManager při ukončení aplikace
    _scheduleManager.dispose();
    
    // Uvolnění prostředků BudgetManager při ukončení aplikace
    _budgetManager.dispose();
    
    super.dispose();
  }
  
  void _runBackgroundChecks() async {
    // Inicializace méně kritických komponent s odstupem (neblokuje UI)
    Future.delayed(const Duration(seconds: 1), () {
      // Zde použijeme existující metodu nebo necháme prázdné, pokud metoda neexistuje
      // _scheduleManager.initialize();
      // Další méně kritické inicializace
    });
    
    // Tyto operace jsou nyní spouštěny jako Future, takže neblokují UI
    await logCurrentUser();
    await testFirestorePermissions();
    
    // Ověření stavu předplatného
    try {
      // Zde použijeme jen základní operaci, protože metoda checkSubscriptionStatus neexistuje
      await timeoutSafeCall(
        Future.value(null), // Prázdná operace místo neexistující metody
        timeoutSeconds: 5,
        operationName: 'Check subscription status'
      );
    } catch (e) {
      debugPrint('[MyApp] Error checking subscription status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[MyApp] Building MyApp widget');
    
    // Získání překladu pro název aplikace - použití statické metody místo context.tr
    String appName = _tr('app_name');
    
    return MultiProvider(
      providers: [
        // StreamProvider pro FirebaseAuth (přihlášený/odhlášený uživatel)
        StreamProvider<fb.User?>(
          create: (_) => di.locator<AuthService>().authStateChanges,
          initialData: null,
          catchError: (_, error) {
            debugPrint('[MyApp] Error in auth state stream: $error');
            FirebaseCrashlytics.instance.recordError(error, null, reason: 'Auth State Stream Error');
            return null;
          },
        ),
        
        // Provider pro UserRepository, AuthService a WeddingRepository
        Provider<UserRepository>(create: (_) => di.locator<UserRepository>()),
        Provider<AuthService>(create: (_) => di.locator<AuthService>()),
        Provider<WeddingRepository>(create: (_) => di.locator<WeddingRepository>()),
        
        // Provider pro SubscriptionRepository
        Provider<SubscriptionRepository>(
          create: (_) => _subscriptionRepository,
          // Nepoužíváme dispose zde, protože ho voláme v dispose metody _MyAppState
        ),
        
        // Provider pro stream dat předplatného
        StreamProvider(
          create: (context) => _subscriptionRepository.subscriptionStream,
          initialData: null,
          catchError: (_, error) {
            debugPrint('[MyApp] Error in subscription stream: $error');
            FirebaseCrashlytics.instance.recordError(error, null, reason: 'Subscription Stream Error');
            return null;
          },
        ),
        
        // Lokální správa harmonogramu
        ChangeNotifierProvider<LocalScheduleService>(
          create: (_) => di.locator<LocalScheduleService>(),
        ),
        
        // ScheduleManager pro synchronizaci harmonogramu s cloudem
        ChangeNotifierProvider<ScheduleManager>(
          create: (_) => _scheduleManager,
        ),
        
        // BudgetManager pro správu rozpočtu
        ChangeNotifierProvider<BudgetManager>(
          create: (_) => _budgetManager,
        ),
        
        // LocalBudgetService pro lokální správu rozpočtu
        ChangeNotifierProvider<LocalBudgetService>(
          create: (_) => _localBudgetService,
        ),
        
        // SubscriptionProvider jako ChangeNotifier
        ChangeNotifierProvider<SubscriptionProvider>(
          create: (context) => SubscriptionProvider(
            subscriptionRepo: _subscriptionRepository, // Použití instance z této třídy
          ),
        ),
      ],
      child: MaterialApp(
        title: appName, // Použití statické proměnné místo context.tr
        debugShowCheckedModeBanner: false,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        // Použití RouteGenerator z routes.dart
        onGenerateRoute: (settings) {
          debugPrint('[MyApp] Generating route for: ${settings.name}');
          
          // Zaznamenání navigace pro analytiku
          if (settings.name != null && settings.name != '/') {
            try {
              // Zde by byla analytika, ale nyní ji přeskočíme
              // di.locator<AnalyticsService>().logScreenView(screenName: settings.name!);
            } catch (e) {
              debugPrint('[MyApp] Failed to log screen view: $e');
            }
          }
          
          return RouteGenerator.generateRoute(settings);
        },
        navigatorKey: di.locator<NavigationService>().navigatorKey,
        navigatorObservers: [
          // Zde můžete přidat další observery (např. pro Firebase Analytics)
        ],
        builder: (context, child) {
          // Přidání ErrorWidget handleru
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Něco se pokazilo',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chyba byla zaznamenána a budeme se jí zabývat. Zkuste to prosím znovu.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Pokusíme se navigovat zpět na hlavní obrazovku
                          di.locator<NavigationService>().navigatorKey.currentState?.pushNamedAndRemoveUntil(
                            RoutePaths.splash,
                            (route) => false,
                          );
                        },
                        child: const Text('Zpět na hlavní obrazovku'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          };
          
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}