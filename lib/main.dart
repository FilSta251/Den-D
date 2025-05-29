// lib/main.dart - OPRAVENÁ VERZE S CHYBOVÝMI KOMPONENTAMI

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

// Nové importy
import 'services/environment_config.dart';
import 'services/connectivity_manager.dart';
import 'utils/error_handler.dart';
import 'services/security_service.dart';

// Import pro SubscriptionProvider (ChangeNotifier)
import 'providers/subscription_provider.dart';

// Router a Theme
import 'theme/app_theme.dart';

// NOVÉ IMPORTY - CHYBOVÉ KOMPONENTY
import 'widgets/error_dialog.dart';
import 'widgets/custom_error_widget.dart';
import 'utils/global_error_handler.dart';
import 'package:svatebni_planovac/utils/global_error_handler.dart' as geh;
import 'package:svatebni_planovac/widgets/error_dialog.dart' as ed;

/// Konstantní proměnná určující prostředí (např. 'production').
const String environment = "production";

/// Pomocná funkce pro ošetření asynchronních operací s timeoutem
/// ROZŠÍŘENO o podporu ErrorDialog
Future<T?> timeoutSafeCall<T>(Future<T> future, {
  int timeoutSeconds = 10,
  T? defaultValue,
  String operationName = 'Operace',
  BuildContext? context,
  bool showErrorDialog = false,
}) async {
  try {
    return await future.timeout(Duration(seconds: timeoutSeconds));
  } on TimeoutException catch (e, stack) {
    debugPrint('[$operationName] Ukončeno kvůli timeoutu (${timeoutSeconds}s)');
    
    // Globální handling
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ed.ErrorType.timeout,
      userMessage: 'Operace $operationName trvala příliš dlouho',
      errorCode: 'TIMEOUT_001',
    );
    
    // Volitelně zobrazit dialog
    if (showErrorDialog && context != null) {
      ErrorDialog.show(
        context,
        message: 'Operace $operationName trvala příliš dlouho',
        errorType: ed.ErrorType.timeout,
        recoveryActions: [RecoveryAction.retry],
        onRecoveryAction: (action) {
          if (action == RecoveryAction.retry) {
            // Retry logika
            timeoutSafeCall(future, 
              timeoutSeconds: timeoutSeconds, 
              defaultValue: defaultValue, 
              operationName: operationName
            );
          }
        },
      );
    }
    
    return defaultValue;
  } catch (e, stack) {
    debugPrint('[$operationName] Chyba: $e');
    
    // Globální handling
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      userMessage: 'Chyba v operaci $operationName',
      errorCode: 'OP_ERROR_001',
    );
    
    FirebaseCrashlytics.instance.recordError(e, stack, reason: operationName);
    return defaultValue;
  }
}

// Funkce pro async inicializaci před spuštěním aplikace
Future<void> _initializeApp() async {
  try {
    // NOVÉ: Inicializace globálního error handleru
    GlobalErrorHandler.initialize();
    
    // Nastavení orientace displeje (pouze portrét)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    
    
    // Inicializace EasyLocalization (načtení jazykových překladů)
    await EasyLocalization.ensureInitialized();

    // Inicializace environment konfigurace
    final envConfig = EnvironmentConfig();
    await envConfig.initialize();

    // Inicializace Firebase s error handlingem
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
            
      // Optimalizace Firestore cache pro offline použití
      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      
      
      // Nastavení Firebase Performance Monitoring
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    } catch (e, stack) {
      if (e.toString().contains('[core/duplicate-app]')) {
        debugPrint("[Main] Firebase již existuje, přeskakuji inicializaci.");
      } else {
        debugPrint("[Main] Chyba při inicializaci Firebase: $e");
        
        // Použití globálního error handleru
        GlobalErrorHandler.instance.handleError(
          e,
          stackTrace: stack,
          type: ed.ErrorType.critical,
          userMessage: 'Nepodařilo se inicializovat Firebase služby',
          errorCode: 'FIREBASE_INIT_001',
        );
        
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Firebase Initialization');
      }
    }

    // Inicializace service locatoru (DI) s error handlingem
    try {
      await di.init();
      await timeoutSafeCall(
        di.locator.allReady(), 
        timeoutSeconds: 5,
        operationName: 'DI initialization'
      );
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.critical,
        userMessage: 'Chyba při inicializaci aplikačních služeb',
        errorCode: 'DI_INIT_001',
      );
      rethrow;
    }

    // Inicializace nových služeb s error handlingem
    try {
      final errorHandler = ErrorHandler();
      await errorHandler.initialize();

      final connectivityManager = ConnectivityManager();
      await connectivityManager.initialize();

      final securityService = SecurityService();
      await securityService.initialize();
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.server,
        userMessage: 'Chyba při inicializaci bezpečnostních služeb',
        errorCode: 'SEC_INIT_001',
      );
    }

    // Nastavení Crashlytics s našimi error komponentami
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    // Přepsání FlutterError.onError pro použití našeho systému
    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
      
      // Také použij náš globální handler
      GlobalErrorHandler.instance.handleError(
        details.exception,
        stackTrace: details.stack,
        type: ed.ErrorType.critical,
        userMessage: 'Došlo k neočekávané chybě aplikace',
        errorCode: 'FLUTTER_ERROR_001',
      );
    };
    
    // Zachytávání nativních chyb
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      
      // Také použij náš globální handler
      GlobalErrorHandler.instance.handleError(
        error,
        stackTrace: stack,
        type: ed.ErrorType.critical,
        userMessage: 'Kritická chyba systému',
        errorCode: 'PLATFORM_ERROR_001',
      );
      
      return true;
    };

    // Nastavení sledování stavu přihlášení a obnovu tokenů s error handlingem
    fb.FirebaseAuth.instance.authStateChanges().listen(
      (fb.User? user) {
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
                  
                  GlobalErrorHandler.instance.handleError(
                    error,
                    type: ed.ErrorType.auth,
                    userMessage: 'Chyba při obnovení přihlášení',
                    errorCode: 'TOKEN_REFRESH_001',
                  );
                });
              }
            }
          }).catchError((error) {
            debugPrint("[Main] Token validation error: $error");
            
            GlobalErrorHandler.instance.handleError(
              error,
              type: ed.ErrorType.auth,
              userMessage: 'Chyba při ověření přihlášení',
              errorCode: 'TOKEN_VALIDATION_001',
            );
          });
        } else {
          FirebaseCrashlytics.instance.setUserIdentifier('');
        }
      },
      onError: (error) {
        GlobalErrorHandler.instance.handleError(
          error,
          type: ed.ErrorType.auth,
          userMessage: 'Chyba při sledování stavu přihlášení',
          errorCode: 'AUTH_STATE_001',
        );
      },
    );

    // Inicializace dalších služeb s error handlingem
    try {
      await timeoutSafeCall(
        di.locator<NotificationService>().initialize(),
        timeoutSeconds: 3,
        operationName: 'NotificationService initialization'
      );
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.permission,
        userMessage: 'Chyba při inicializaci oznámení',
        errorCode: 'NOTIFICATION_INIT_001',
      );
    }
    
    await di.locator<CrashReportingService>().initialize();
    
    // Kontrola síťového připojení při startu s error handlingem
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("[Main] Při startu nebylo detekováno síťové připojení");
        
        GlobalErrorHandler.instance.handleError(
          Exception('No network connectivity'),
          type: ed.ErrorType.network,
          userMessage: 'Aplikace spuštěna bez připojení k internetu',
          errorCode: 'NETWORK_STARTUP_001',
        );
      }
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.network,
        userMessage: 'Chyba při kontrole připojení',
        errorCode: 'CONNECTIVITY_CHECK_001',
      );
    }
  } catch (e, stack) {
    debugPrint("[Main] Kritická chyba během inicializace aplikace: $e");
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'App Initialization', fatal: true);
    
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ed.ErrorType.critical,
      userMessage: 'Kritická chyba při spuštění aplikace',
      errorCode: 'APP_INIT_CRITICAL_001',
    );
    
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

    debugPrint("[Main] App starting in $environment environment");

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
    // Zachycení kritických chyb při startu - POUŽITÍ NAŠICH KOMPONENT
    debugPrint("=== KRITICKÁ CHYBA PŘI SPUŠTĚNÍ APLIKACE ===");
    debugPrint(e.toString());
    
    try {
      // Záznam do Crashlytics
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'App Launch', fatal: true);
    } catch (_) {
      // Crashlytics nemusí být inicializovaný
    }
    
    // NOVÁ CHYBOVÁ OBRAZOVKA s našimi komponentami
    runApp(MaterialApp(
      home: Scaffold(
        body: CustomErrorWidget(
          message: 'Nepodařilo se spustit aplikaci',
          errorType: ErrorWidgetType.unknown,
          onRetry: () {
            // Pokus o restart aplikace
            main();
          },
          onSecondaryAction: () {
            SystemNavigator.pop();
          },
          secondaryActionText: 'Zavřít aplikaci',
          secondaryActionIcon: Icons.close,
          detailMessage: 'Omlouváme se za potíže. Prosím zkuste aplikaci restartovat nebo kontaktujte podporu. Chyba: ${e.toString()}',
          showReportButton: true,
          onReportError: () {
            // Zde by byla implementace reportování chyby
            debugPrint('Reporting error: $e');
          },
        ),
      ),
    ));
  }
}

/// Pomocná funkce pro výpis informací o aktuálně přihlášeném uživateli
/// ROZŠÍŘENO o error handling
Future<void> logCurrentUser() async {
  try {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user != null) {
      debugPrint('[Auth] Přihlášený uživatel: ${user.uid}');
    }
  } catch (e, stack) {
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ed.ErrorType.auth,
      userMessage: 'Chyba při získání informací o uživateli',
      errorCode: 'USER_INFO_001',
    );
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'User Info Check');
  }
}

/// Ověří existenci dokumentů uživatele ve Firestore
/// ROZŠÍŘENO o lepší error handling
Future<void> checkUserDocuments(String uid) async {
  try {
    // Kontrola uživatelského profilu
    final userDoc = await timeoutSafeCall(
      FirebaseFirestore.instance.collection('users').doc(uid).get(),
      timeoutSeconds: 5,
      operationName: 'Users check'
    );
    
    // Kontrola wedding info
    final weddingDoc = await timeoutSafeCall(
      FirebaseFirestore.instance.collection('wedding_info').doc(uid).get(),
      timeoutSeconds: 5,
      operationName: 'Wedding info check'
    );
    
    // Kontrola předplatného
    final subscriptionDoc = await timeoutSafeCall(
      FirebaseFirestore.instance.collection('subscriptions').doc(uid).get(),
      timeoutSeconds: 5,
      operationName: 'Subscription check'
    );
    
  } catch (e, stack) {
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ed.ErrorType.server,
      userMessage: 'Chyba při ověření uživatelských dat',
      errorCode: 'USER_DOCS_001',
    );
    FirebaseCrashlytics.instance.recordError(e, stack, reason: 'User Documents Check');
  }
}

/// Testuje základní oprávnění k Firestore
/// ROZŠÍŘENO o error handling
Future<void> testFirestorePermissions() async {
  final Trace trace = FirebasePerformance.instance.newTrace('firestore_permissions_test');
  await trace.start();
  
  try {
    final user = fb.FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      await trace.stop();
      return;
    }
    
    // Test čtení - wedding_info
    try {
      final docRef = FirebaseFirestore.instance.collection('wedding_info').doc(user.uid);
      await timeoutSafeCall(
        docRef.get(),
        timeoutSeconds: 5,
        operationName: 'READ wedding_info'
      );
    } catch (e) {
      debugPrint('[Firestore] Chyba čtení: $e');
      GlobalErrorHandler.instance.handleError(
        e,
        type: ed.ErrorType.permission,
        userMessage: 'Chyba při čtení svatebních informací',
        errorCode: 'FIRESTORE_READ_001',
      );
    }
    
    // Test zápisu - wedding_info
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
    } catch (e) {
      debugPrint('[Firestore] Chyba zápisu: $e');
      GlobalErrorHandler.instance.handleError(
        e,
        type: ed.ErrorType.permission,
        userMessage: 'Chyba při ukládání svatebních informací',
        errorCode: 'FIRESTORE_WRITE_001',
      );
    }
  } catch (e, stack) {
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ed.ErrorType.server,
      userMessage: 'Chyba při testování oprávnění k databázi',
      errorCode: 'FIRESTORE_PERMISSIONS_001',
    );
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
    
    // NOVÉ: Nastavení kontextu pro globální error handler
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalErrorHandler.instance.setContext(context);
    });
    
    // Start performance trace
    _appStartupTrace = FirebasePerformance.instance.newTrace('app_startup');
    _appStartupTrace.start();
    
    // Přidání observeru stavu aplikace
    WidgetsBinding.instance.addObserver(this);
    
    try {
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
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.critical,
        userMessage: 'Chyba při inicializaci hlavních služeb',
        errorCode: 'MAIN_SERVICES_INIT_001',
      );
    }
    
    // Monitorování změn připojení s error handlingem
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        try {
          // Jelikož connectivity_plus vrací List<ConnectivityResult>, bereme první výsledek
          final connectivityResult = results.isNotEmpty ? results.first : ConnectivityResult.none;
          
          if (connectivityResult != ConnectivityResult.none) {
            // Máme připojení, můžeme synchronizovat data
            _scheduleManager.synchronizeData(); // Upraveno - používáme existující metodu
            // Zde by mohly být další synchronizace
          }
        } catch (e, stack) {
          GlobalErrorHandler.instance.handleError(
            e,
            stackTrace: stack,
            type: ed.ErrorType.network,
            userMessage: 'Chyba při zpracování změny připojení',
            errorCode: 'CONNECTIVITY_CHANGE_001',
          );
        }
      },
      onError: (error) {
        GlobalErrorHandler.instance.handleError(
          error,
          type: ed.ErrorType.network,
          userMessage: 'Chyba při sledování stavu připojení',
          errorCode: 'CONNECTIVITY_MONITOR_001',
        );
      },
    );
    
    // Přesouvám logování uživatele a testování oprávnění mimo hlavní vlákno
    _runBackgroundChecks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstBuild) {
      _isFirstBuild = false;
      // NOVÉ: Aktualizace kontextu pro error handler
      GlobalErrorHandler.instance.setContext(context);
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        // Aplikace byla obnovena z pozadí
        _scheduleManager.synchronizeData(); // Upraveno - používáme existující metodu
        // Kontrola aktualizací Firebase konfigurace
        fb.FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (e, stack) {
        GlobalErrorHandler.instance.handleError(
          e,
          stackTrace: stack,
          type: ed.ErrorType.auth,
          userMessage: 'Chyba při obnovení aplikace',
          errorCode: 'APP_RESUME_001',
        );
      }
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
    
    // Uvolnění prostředků s error handlingem
    try {
      _subscriptionRepository.dispose();
      _scheduleManager.dispose();
      _budgetManager.dispose();
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.unknown,
        userMessage: 'Chyba při ukončování aplikace',
        errorCode: 'APP_DISPOSE_001',
      );
    }
    
    super.dispose();
  }
  
  void _runBackgroundChecks() async {
    try {
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
        debugPrint('[Subscription] Chyba kontroly předplatného: $e');
      }
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ed.ErrorType.unknown,
        userMessage: 'Chyba při kontrolách na pozadí',
        errorCode: 'BACKGROUND_CHECKS_001',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Získání překladu pro název aplikace - použití statické metody místo context.tr
    String appName = _tr('app_name');
    
    return MultiProvider(
      providers: [
        // StreamProvider pro FirebaseAuth (přihlášený/odhlášený uživatel)
        StreamProvider<fb.User?>(
          create: (_) => di.locator<AuthService>().authStateChanges,
          initialData: null,
          catchError: (_, error) {
            GlobalErrorHandler.instance.handleError(
              error,
              type: ed.ErrorType.auth,
              userMessage: 'Chyba při sledování stavu přihlášení',
              errorCode: 'AUTH_STREAM_001',
            );
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
            GlobalErrorHandler.instance.handleError(
              error,
              type: ed.ErrorType.server,
              userMessage: 'Chyba při načítání informací o předplatném',
              errorCode: 'SUBSCRIPTION_STREAM_001',
            );
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
          try {
            // Zaznamenání navigace pro analytiku
            if (settings.name != null && settings.name != '/') {
              try {
                // Zde by byla analytika, ale nyní ji přeskočíme
                // di.locator<AnalyticsService>().logScreenView(screenName: settings.name!);
              } catch (e) {
                debugPrint('[Navigation] Chyba logování zobrazení: $e');
                GlobalErrorHandler.instance.handleError(
                  e,
                  type: ed.ErrorType.unknown,
                  userMessage: 'Chyba při zaznamenání navigace',
                  errorCode: 'NAVIGATION_LOG_001',
                );
              }
            }
            
            return RouteGenerator.generateRoute(settings);
          } catch (e, stack) {
            GlobalErrorHandler.instance.handleError(
              e,
              stackTrace: stack,
              type: ed.ErrorType.critical,
              userMessage: 'Chyba při generování obrazovky',
              errorCode: 'ROUTE_GENERATION_001',
            );
            
            // Fallback route s našimi error komponentami
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: CustomErrorWidget(
                  message: 'Chyba při načítání obrazovky',
                  errorType: ErrorWidgetType.unknown,
                  onRetry: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      RoutePaths.splash,
                      (route) => false,
                    );
                  },
                  detailMessage: 'Požadovaná obrazovka ${settings.name} se nepodařila načíst. Chyba: ${e.toString()}',
                ),
              ),
            );
          }
        },
        navigatorKey: di.locator<NavigationService>().navigatorKey,
        navigatorObservers: [
          // Zde můžete přidat další observery (např. pro Firebase Analytics)
        ],
        builder: (context, child) {
          // AKTUALIZACE kontextu pro globální error handler
          GlobalErrorHandler.instance.setContext(context);
          
          // NOVÝ ErrorWidget handler s našimi komponentami
          ErrorWidget.builder = (FlutterErrorDetails details) {
            // Zaznamenání chyby
            GlobalErrorHandler.instance.handleError(
              details.exception,
              stackTrace: details.stack,
              type: ErrorType.critical,
              userMessage: 'Neočekávaná chyba v uživatelském rozhraní',
              errorCode: 'UI_ERROR_001',
            );
            
            return Scaffold(
              body: CustomErrorWidget(
                message: 'Něco se pokazilo',
                errorType: ErrorWidgetType.unknown,
                onRetry: () {
                  // Pokusíme se navigovat zpět na hlavní obrazovku
                  try {
                    di.locator<NavigationService>().navigatorKey.currentState?.pushNamedAndRemoveUntil(
                      RoutePaths.splash,
                      (route) => false,
                    );
                  } catch (e) {
                    // Backup - restart celé aplikace
                    main();
                  }
                },
                onSecondaryAction: () {
                  SystemNavigator.pop();
                },
                secondaryActionText: 'Zavřít aplikaci',
                secondaryActionIcon: Icons.close,
                detailMessage: kDebugMode 
                    ? 'Technické detaily: ${details.exception}\n\nStack trace: ${details.stack}'
                    : 'Došlo k neočekávané chybě. Kontaktujte podporu pokud problém přetrvává.',
                showReportButton: true,
                onReportError: () {
                  // Zobrazit dialog pro reportování chyby
                  showDialog(
                    context: context,
                    builder: (context) => ErrorDialog(
                      title: 'Nahlásit chybu',
                      message: 'Chcete nahlásit tuto chybu vývojářskému týmu?',
                      errorType: ErrorType.info,
                      errorCode: 'UI_ERROR_REPORT',
                      technicalDetails: details.toString(),
                      recoveryActions: [RecoveryAction.contact, RecoveryAction.ignore],
                      onRecoveryAction: (action) {
                        if (action == RecoveryAction.contact) {
                          // Implementace kontaktu na podporu
                          debugPrint('Sending error report: ${details.exception}');
                        }
                      },
                    ),
                  );
                },
              ),
            );
          };
          
          // Wrapper pro automatické zavírání klávesnice
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