/// lib/main.dart - PRODUKČNÍ VERZE S NOTIFIKACEMI
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'routes.dart';
import 'services/budget_manager.dart';
import 'services/local_budget_service.dart';
import 'services/cloud_budget_service.dart';

// MANAGERS PRO GUESTS, CHECKLIST A CALENDAR
import 'services/guests_manager.dart';
import 'services/local_guests_service.dart';
import 'services/cloud_guests_service.dart';
import 'services/checklist_manager.dart';
import 'services/local_checklist_service.dart';
import 'services/cloud_checklist_service.dart';
import 'services/calendar_manager.dart';
import 'services/local_calendar_service.dart';
import 'services/cloud_calendar_service.dart';

// Subscription
import 'providers/subscription_provider.dart';
import 'services/payment_service.dart';

// Theme
import 'providers/theme_manager.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Router a Theme
import 'theme/app_theme.dart';

// Error handling komponenty
import 'widgets/error_dialog.dart';
import 'widgets/custom_error_widget.dart';
import 'utils/global_error_handler.dart';
import 'services/environment_config.dart';
import 'services/connectivity_manager.dart';
import 'utils/error_handler.dart';
import 'services/security_service.dart';

/// Konstanta prostředí
const String environment = "production";

/// Background message handler pro Firebase Messaging - MUSÍ BÝT TOP-LEVEL
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[Firebase] Background message: ${message.messageId}');
  debugPrint('[Firebase] Notification: ${message.notification?.title}');
}

/// Pomocná funkce pro ošetření asynchronních operací s timeoutem
Future<T?> timeoutSafeCall<T>(
  Future<T> future, {
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

    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ErrorType.timeout,
      userMessage: 'Operace $operationName trvala příliš dlouho',
      errorCode: 'TIMEOUT_001',
    );

    if (showErrorDialog && context != null) {
      ErrorDialog.show(
        context,
        message: 'Operace $operationName trvala příliš dlouho',
        errorType: ErrorType.timeout,
        recoveryActions: [RecoveryAction.retry],
        onRecoveryAction: (action) {
          if (action == RecoveryAction.retry) {
            timeoutSafeCall(future,
                timeoutSeconds: timeoutSeconds,
                defaultValue: defaultValue,
                operationName: operationName);
          }
        },
      );
    }

    return defaultValue;
  } catch (e, stack) {
    debugPrint('[$operationName] Chyba: $e');

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
    GlobalErrorHandler.initialize();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await EasyLocalization.ensureInitialized();

    final envConfig = EnvironmentConfig();
    await envConfig.initialize();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
      debugPrint("[Main] App Check aktivován úspěšně");

      // Registrace background message handleru - DŮLEŽITÉ!
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      FirebaseFirestore.instance.settings = Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    } catch (e, stack) {
      if (e.toString().contains('[core/duplicate-app]')) {
        debugPrint("[Main] Firebase již existuje, přeskakuji inicializaci.");
      } else {
        debugPrint("[Main] Chyba při inicializaci Firebase: $e");

        GlobalErrorHandler.instance.handleError(
          e,
          stackTrace: stack,
          type: ErrorType.critical,
          userMessage: 'Nepodařilo se inicializovat Firebase služby',
          errorCode: 'FIREBASE_INIT_001',
        );

        FirebaseCrashlytics.instance
            .recordError(e, stack, reason: 'Firebase Initialization');
      }
    }

    try {
      await di.init();
      await timeoutSafeCall(di.locator.allReady(),
          timeoutSeconds: 5, operationName: 'DI initialization');
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.critical,
        userMessage: 'Chyba při inicializaci aplikačních služeb',
        errorCode: 'DI_INIT_001',
      );
      rethrow;
    }

    try {
      final connectivityManager = ConnectivityManager();
      await connectivityManager.initialize();

      final securityService = SecurityService();
      await securityService.initialize();
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.server,
        userMessage: 'Chyba při inicializaci bezpečnostních služeb',
        errorCode: 'SEC_INIT_001',
      );
    }

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    FlutterError.onError = (FlutterErrorDetails details) {
      FirebaseCrashlytics.instance.recordFlutterError(details);

      GlobalErrorHandler.instance.handleError(
        details.exception,
        stackTrace: details.stack,
        type: ErrorType.critical,
        userMessage: 'Došlo k neočekávané chybě aplikace',
        errorCode: 'FLUTTER_ERROR_001',
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);

      GlobalErrorHandler.instance.handleError(
        error,
        stackTrace: stack,
        type: ErrorType.critical,
        userMessage: 'Kritická chyba systému',
        errorCode: 'PLATFORM_ERROR_001',
      );

      return true;
    };

    fb.FirebaseAuth.instance.authStateChanges().listen(
      (fb.User? user) {
        if (user != null) {
          FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
          user.getIdTokenResult().then((idTokenResult) {
            if (idTokenResult.issuedAtTime != null) {
              final issuedAtDate = DateTime.fromMillisecondsSinceEpoch(
                  idTokenResult.issuedAtTime!.millisecondsSinceEpoch);
              final now = DateTime.now();
              if (now.difference(issuedAtDate).inHours > 12) {
                user.getIdToken(true).catchError((error) {
                  debugPrint("[Main] Token refresh error: $error");

                  GlobalErrorHandler.instance.handleError(
                    error,
                    type: ErrorType.auth,
                    userMessage: 'Chyba při obnově přihlášení',
                    errorCode: 'TOKEN_REFRESH_001',
                  );
                });
              }
            }
          }).catchError((error) {
            debugPrint("[Main] Token validation error: $error");

            GlobalErrorHandler.instance.handleError(
              error,
              type: ErrorType.auth,
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
          type: ErrorType.auth,
          userMessage: 'Chyba při sledování stavu přihlášení',
          errorCode: 'AUTH_STATE_001',
        );
      },
    );

    // Inicializace NotificationService s callback handlerem
    try {
      await timeoutSafeCall(
        di.locator<NotificationService>().initialize(
          onNotificationTapped: (payload) {
            debugPrint('[Main] Notification tapped with payload: $payload');
            // Navigace na kalendář při kliknutí na notifikaci
            if (payload != null && payload.contains('calendar_event')) {
              try {
                di
                    .locator<NavigationService>()
                    .navigatorKey
                    .currentState
                    ?.pushNamed('/calendar');
              } catch (e) {
                debugPrint('[Main] Navigation error: $e');
              }
            }
          },
        ),
        timeoutSeconds: 5,
        operationName: 'NotificationService initialization',
      );
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.permission,
        userMessage: 'Chyba při inicializaci oznámení',
        errorCode: 'NOTIFICATION_INIT_001',
      );
    }

    await di.locator<CrashReportingService>().initialize();

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("[Main] Při startu nebylo detekováno síťové připojení");

        GlobalErrorHandler.instance.handleError(
          Exception('No network connectivity'),
          type: ErrorType.network,
          userMessage: 'Aplikace spuštěna bez připojení k internetu',
          errorCode: 'NETWORK_STARTUP_001',
        );
      }
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.network,
        userMessage: 'Chyba při kontrole připojení',
        errorCode: 'CONNECTIVITY_CHECK_001',
      );
    }
  } catch (e, stack) {
    debugPrint("[Main] Kritická chyba během inicializace aplikace: $e");
    FirebaseCrashlytics.instance
        .recordError(e, stack, reason: 'App Initialization', fatal: true);

    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ErrorType.critical,
      userMessage: 'Kritická chyba při spuštění aplikace',
      errorCode: 'APP_INIT_CRITICAL_001',
    );

    rethrow;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bezpečnostní pásy na začátek
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Kritická chyba zachycena: $error');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (e) {
      debugPrint('Nelze zaznamenat chybu: $e');
    }
    return true;
  };

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('Flutter chyba zachycena: ${details.exception}');
    try {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (e) {
      debugPrint('Nelze zaznamenat Flutter chybu: $e');
    }
  };

  debugPrint("=== APLIKACE SE SPOUŠTÍ ===");

  try {
    await _initializeApp();

    debugPrint("[Main] App starting in $environment environment");

    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('cs'),
          Locale('en'),
          Locale('es'),
          Locale('uk'),
          Locale('pl'),
          Locale('fr'),
          Locale('de'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        useOnlyLangCode: true,
        child: const MyApp(),
      ),
    );
  } catch (e, stack) {
    debugPrint("=== KRITICKÁ CHYBA PŘI SPOUŠTĚNÍ APLIKACE ===");
    debugPrint(e.toString());

    try {
      FirebaseCrashlytics.instance
          .recordError(e, stack, reason: 'App Launch', fatal: true);
    } catch (_) {}

    runApp(MaterialApp(
      home: Scaffold(
        body: CustomErrorWidget(
          message: 'Nepodařilo se spustit aplikaci',
          errorType: ErrorWidgetType.unknown,
          onRetry: () {
            main();
          },
          onSecondaryAction: () {
            SystemNavigator.pop();
          },
          secondaryActionText: 'Zavřít aplikaci',
          secondaryActionIcon: Icons.close,
          detailMessage:
              'Omlouváme se za potíže. Prosím zkuste aplikaci restartovat nebo kontaktujte podporu. Chyba: ${e.toString()}',
          showReportButton: true,
          onReportError: () {
            debugPrint('Reporting error: $e');
          },
        ),
      ),
    ));
  }
}

/// Pomocné funkce
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
      type: ErrorType.auth,
      userMessage: 'Chyba při získání informací o uživateli',
      errorCode: 'USER_INFO_001',
    );
    FirebaseCrashlytics.instance
        .recordError(e, stack, reason: 'User Info Check');
  }
}

Future<void> checkUserDocuments(String uid) async {
  try {
    await timeoutSafeCall(
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        timeoutSeconds: 5,
        operationName: 'Users check');

    await timeoutSafeCall(
        FirebaseFirestore.instance.collection('wedding_info').doc(uid).get(),
        timeoutSeconds: 5,
        operationName: 'Wedding info check');

    await timeoutSafeCall(
        FirebaseFirestore.instance.collection('subscriptions').doc(uid).get(),
        timeoutSeconds: 5,
        operationName: 'Subscription check');
  } catch (e, stack) {
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ErrorType.server,
      userMessage: 'Chyba při ověření uživatelských dat',
      errorCode: 'USER_DOCS_001',
    );
    FirebaseCrashlytics.instance
        .recordError(e, stack, reason: 'User Documents Check');
  }
}

Future<void> testFirestorePermissions() async {
  final Trace trace =
      FirebasePerformance.instance.newTrace('firestore_permissions_test');
  await trace.start();

  try {
    final user = fb.FirebaseAuth.instance.currentUser;

    if (user == null) {
      await trace.stop();
      return;
    }

    try {
      final docRef =
          FirebaseFirestore.instance.collection('wedding_info').doc(user.uid);
      await timeoutSafeCall(docRef.get(),
          timeoutSeconds: 5, operationName: 'READ wedding_info');
    } catch (e) {
      debugPrint('[Firestore] Chyba čtení: $e');
      GlobalErrorHandler.instance.handleError(
        e,
        type: ErrorType.permission,
        userMessage: 'Chyba při čtení svatebních informací',
        errorCode: 'FIRESTORE_READ_001',
      );
    }
  } catch (e, stack) {
    GlobalErrorHandler.instance.handleError(
      e,
      stackTrace: stack,
      type: ErrorType.server,
      userMessage: 'Chyba při testování oprávnění k databázi',
      errorCode: 'FIRESTORE_PERMISSIONS_001',
    );
    FirebaseCrashlytics.instance
        .recordError(e, stack, reason: 'Firestore Permissions Test');
  } finally {
    await trace.stop();
  }
}

/// Kořenový widget aplikace
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Existující instance
  late SubscriptionRepository _subscriptionRepository;
  late CloudScheduleService _cloudScheduleService;
  late ScheduleManager _scheduleManager;
  late BudgetManager _budgetManager;
  late LocalBudgetService _localBudgetService;
  late CloudBudgetService _cloudBudgetService;

  // INSTANCE PRO GUESTS, CHECKLIST A CALENDAR
  late GuestsManager _guestsManager;
  late LocalGuestsService _localGuestsService;
  late CloudGuestsService _cloudGuestsService;
  late ChecklistManager _checklistManager;
  late LocalChecklistService _localChecklistService;
  late CloudChecklistService _cloudChecklistService;
  late CalendarManager _calendarManager;
  late LocalCalendarService _localCalendarService;
  late CloudCalendarService _cloudCalendarService;

  // INSTANCE PRO SUBSCRIPTION SERVICES
  late PaymentService _paymentService;
  late LocalStorageService _localStorageService;
  late SubscriptionProvider _subscriptionProvider;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  late StreamSubscription<List<PurchaseDetails>> _purchaseStreamSubscription;
  late StreamSubscription<fb.User?> _authStreamSubscription;
  late Trace _appStartupTrace;
  bool _isFirstBuild = true;
  bool _subscriptionServicesInitialized = false;

  // GLOBÁLNÍ KEY PRO BEZPEČNÝ PŘÍSTUP K SCAFFOLDMESSENGER
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static const Map<String, String> _translations = {
    'app_name': 'Svatební plánovač',
  };

  String _tr(String key) {
    return _translations[key] ?? key;
  }

  // Inicializace subscription services
  Future<void> _initializeSubscriptionServices() async {
    try {
      _paymentService = di.locator<PaymentService>();

      final prefs = await SharedPreferences.getInstance();
      _localStorageService = LocalStorageService(sharedPreferences: prefs);

      _subscriptionRepository = di.locator<SubscriptionRepository>();

      _subscriptionProvider = SubscriptionProvider(
        subscriptionRepository: _subscriptionRepository,
        localStorage: _localStorageService,
      );

      _subscriptionServicesInitialized = true;
      debugPrint('[Main] Subscription services inicializovány úspěšně');
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.critical,
        userMessage: 'Chyba při inicializaci služeb předplatného',
        errorCode: 'SUBSCRIPTION_SERVICES_INIT_001',
      );
      _subscriptionServicesInitialized = false;
    }
  }

  /// Zpracování purchase stream událostí
  void _handlePurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList, String? uid) async {
    if (uid == null) {
      debugPrint('[Main] Nelze zpracovat nákup - uživatel není přihlášen');
      return;
    }

    for (final purchase in purchaseDetailsList) {
      debugPrint(
          '[Main] Zpracovávám purchase: ${purchase.productID} - ${purchase.status}');

      try {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _subscriptionRepository.handlePurchase(uid, purchase);
            await _paymentService.completePurchase(purchase);
            _showPurchaseSuccessNotification();
            break;

          case PurchaseStatus.error:
            debugPrint('[Main] Chyba nákupu: ${purchase.error}');
            final errorMessage =
                purchase.error?.message ?? tr('subs.error.unknown');
            if (errorMessage.isNotEmpty) {
              _showPurchaseErrorNotification(errorMessage);
            }
            break;

          case PurchaseStatus.pending:
            debugPrint(
                '[Main] Nákup čeká na zpracování: ${purchase.productID}');
            _showPurchasePendingNotification();
            break;

          case PurchaseStatus.canceled:
            debugPrint('[Main] Nákup zrušen uživatelem: ${purchase.productID}');
            break;
        }
      } catch (e, stack) {
        debugPrint('[Main] Chyba při zpracování purchase: $e');
        GlobalErrorHandler.instance.handleError(
          e,
          stackTrace: stack,
          type: ErrorType.critical,
          userMessage: 'Chyba při zpracování nákupu',
          errorCode: 'PURCHASE_HANDLE_001',
        );
        _showPurchaseErrorNotification('Nepodařilo se zpracovat nákup');
      }
    }
  }

  /// OPRAVENÉ METODY PRO PURCHASE NOTIFIKACE - S POSTFRAMECALLBACK
  void _showPurchaseSuccessNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(tr('subs.purchase.success')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _showPurchaseErrorNotification(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('${tr('subs.purchase.error')}: $message'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: tr('subs.purchase.retry'),
            onPressed: () {},
          ),
        ),
      );
    });
  }

  void _showPurchasePendingNotification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(tr('subs.purchase.pending')),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();

    // REGISTRACE SCAFFOLDMESSENGERKEY V GLOBALERRORHANDLER
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalErrorHandler.instance
          .setScaffoldMessengerKey(_scaffoldMessengerKey);
    });

    _appStartupTrace = FirebasePerformance.instance.newTrace('app_startup');
    _appStartupTrace.start();

    WidgetsBinding.instance.addObserver(this);

    // Inicializace subscription services
    _initializeSubscriptionServices().then((_) {
      if (_subscriptionServicesInitialized) {
        _purchaseStreamSubscription = _paymentService.purchaseStream.listen(
          (purchaseDetailsList) {
            final currentUser = fb.FirebaseAuth.instance.currentUser;
            _handlePurchaseUpdates(purchaseDetailsList, currentUser?.uid);
          },
          onError: (error) {
            debugPrint('[Main] Chyba v purchase stream: $error');
            GlobalErrorHandler.instance.handleError(
              error,
              type: ErrorType.critical,
              userMessage: 'Chyba při zpracování nákupů',
              errorCode: 'PURCHASE_STREAM_001',
            );
          },
        );

        _authStreamSubscription =
            fb.FirebaseAuth.instance.authStateChanges().listen(
          (fb.User? user) {
            if (user != null) {
              _subscriptionProvider.bindUser(user.uid);
              debugPrint(
                  '[Main] Uživatel přihlášen - SubscriptionProvider bound to ${user.uid}');
            }
          },
          onError: (error) {
            debugPrint('[Main] Chyba v auth stream: $error');
            GlobalErrorHandler.instance.handleError(
              error,
              type: ErrorType.auth,
              userMessage: 'Chyba při sledování přihlášení',
              errorCode: 'AUTH_STREAM_002',
            );
          },
        );

        setState(() {});
      }
    });

    try {
      _subscriptionRepository = di.locator<SubscriptionRepository>();

      _cloudScheduleService = CloudScheduleService(
          firestore: FirebaseFirestore.instance,
          auth: fb.FirebaseAuth.instance);

      _scheduleManager = ScheduleManager(
          localService: di.locator<LocalScheduleService>(),
          cloudService: _cloudScheduleService,
          auth: fb.FirebaseAuth.instance);

      _localBudgetService = di.locator<LocalBudgetService>();
      _cloudBudgetService = CloudBudgetService(
          firestore: FirebaseFirestore.instance,
          auth: fb.FirebaseAuth.instance);

      _budgetManager = BudgetManager(
          localService: _localBudgetService,
          cloudService: _cloudBudgetService,
          auth: fb.FirebaseAuth.instance);

      // NOVÉ INSTANCE
      _localGuestsService = LocalGuestsService();
      _cloudGuestsService = CloudGuestsService(
          firestore: FirebaseFirestore.instance,
          auth: fb.FirebaseAuth.instance);

      _guestsManager = GuestsManager(
          localService: _localGuestsService,
          cloudService: _cloudGuestsService,
          auth: fb.FirebaseAuth.instance);

      _localChecklistService = LocalChecklistService();
      _cloudChecklistService = CloudChecklistService(
          firestore: FirebaseFirestore.instance,
          auth: fb.FirebaseAuth.instance);

      _checklistManager = ChecklistManager(
          localService: _localChecklistService,
          cloudService: _cloudChecklistService,
          auth: fb.FirebaseAuth.instance);

      _localCalendarService = LocalCalendarService();
      _cloudCalendarService = CloudCalendarService(
          firestore: FirebaseFirestore.instance,
          auth: fb.FirebaseAuth.instance);

      _calendarManager = CalendarManager(
          localService: _localCalendarService,
          cloudService: _cloudCalendarService,
          auth: fb.FirebaseAuth.instance);
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.critical,
        userMessage: 'Chyba při inicializaci hlavních služeb',
        errorCode: 'MAIN_SERVICES_INIT_001',
      );
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        try {
          final connectivityResult =
              results.isNotEmpty ? results.first : ConnectivityResult.none;

          if (connectivityResult != ConnectivityResult.none) {
            _scheduleManager.forceRefreshFromCloud();
            _budgetManager.forceRefreshFromCloud();
            _guestsManager.forceRefreshFromCloud();
            _checklistManager.forceRefreshFromCloud();
            _calendarManager.forceRefreshFromCloud();
          }
        } catch (e, stack) {
          GlobalErrorHandler.instance.handleError(
            e,
            stackTrace: stack,
            type: ErrorType.network,
            userMessage: 'Chyba při zpracování změny připojení',
            errorCode: 'CONNECTIVITY_CHANGE_001',
          );
        }
      },
      onError: (error) {
        GlobalErrorHandler.instance.handleError(
          error,
          type: ErrorType.network,
          userMessage: 'Chyba při sledování stavu připojení',
          errorCode: 'CONNECTIVITY_MONITOR_001',
        );
      },
    );

    _runBackgroundChecks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirstBuild) {
      _isFirstBuild = false;
      // Bez setContext() - používáme globální keys
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        _scheduleManager.forceRefreshFromCloud();
        _budgetManager.forceRefreshFromCloud();
        _guestsManager.forceRefreshFromCloud();
        _checklistManager.forceRefreshFromCloud();
        _calendarManager.forceRefreshFromCloud();
        fb.FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (e, stack) {
        GlobalErrorHandler.instance.handleError(
          e,
          stackTrace: stack,
          type: ErrorType.auth,
          userMessage: 'Chyba při obnově aplikace',
          errorCode: 'APP_RESUME_001',
        );
      }
    }
  }

  @override
  void dispose() {
    _appStartupTrace.stop();
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _purchaseStreamSubscription.cancel();
    _authStreamSubscription.cancel();

    try {
      _subscriptionRepository.dispose();
      _scheduleManager.dispose();
      _budgetManager.dispose();
      _guestsManager.dispose();
      _checklistManager.dispose();
      _calendarManager.dispose();

      if (_subscriptionServicesInitialized) {
        _paymentService.dispose();
        _subscriptionProvider.dispose();
      }
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.unknown,
        userMessage: 'Chyba při ukončování aplikace',
        errorCode: 'APP_DISPOSE_001',
      );
    }

    super.dispose();
  }

  void _runBackgroundChecks() async {
    try {
      Future.delayed(const Duration(seconds: 1), () {});

      await logCurrentUser();
      await testFirestorePermissions();

      try {
        await timeoutSafeCall(Future.value(null),
            timeoutSeconds: 5, operationName: 'Check subscription status');
      } catch (e) {
        debugPrint('[Subscription] Chyba kontroly předplatného: $e');
      }
    } catch (e, stack) {
      GlobalErrorHandler.instance.handleError(
        e,
        stackTrace: stack,
        type: ErrorType.unknown,
        userMessage: 'Chyba při kontrolách na pozadí',
        errorCode: 'BACKGROUND_CHECKS_001',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String appName = _tr('app_name');

    if (!_subscriptionServicesInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('loading_services'.tr())
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        StreamProvider<fb.User?>(
          create: (_) => di.locator<AuthService>().authStateChanges,
          initialData: null,
          catchError: (_, error) {
            GlobalErrorHandler.instance.handleError(
              error,
              type: ErrorType.auth,
              userMessage: 'Chyba při sledování stavu přihlášení',
              errorCode: 'AUTH_STREAM_001',
            );
            FirebaseCrashlytics.instance
                .recordError(error, null, reason: 'Auth State Stream Error');
            return null;
          },
        ),
        Provider<UserRepository>(create: (_) => di.locator<UserRepository>()),
        Provider<AuthService>(create: (_) => di.locator<AuthService>()),
        Provider<WeddingRepository>(
            create: (_) => di.locator<WeddingRepository>()),

        // PŘIDÁNO: NotificationService provider
        Provider<NotificationService>(
          create: (_) => di.locator<NotificationService>(),
        ),

        Provider<PaymentService>(
          create: (_) => _paymentService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<LocalStorageService>(
          create: (_) => _localStorageService,
        ),
        Provider<SubscriptionRepository>(
          create: (_) => _subscriptionRepository,
        ),
        StreamProvider(
          create: (context) => _subscriptionRepository.subscriptionStream,
          initialData: null,
          catchError: (_, error) {
            GlobalErrorHandler.instance.handleError(
              error,
              type: ErrorType.server,
              userMessage: 'Chyba při načítání informací o předplatném',
              errorCode: 'SUBSCRIPTION_STREAM_001',
            );
            FirebaseCrashlytics.instance
                .recordError(error, null, reason: 'Subscription Stream Error');
            return null;
          },
        ),
        ChangeNotifierProvider<LocalScheduleService>(
          create: (_) => di.locator<LocalScheduleService>(),
        ),
        ChangeNotifierProvider<ScheduleManager>(
          create: (_) => _scheduleManager,
        ),
        ChangeNotifierProvider<BudgetManager>(
          create: (_) => _budgetManager,
        ),
        ChangeNotifierProvider<LocalBudgetService>(
          create: (_) => _localBudgetService,
        ),
        ChangeNotifierProvider<GuestsManager>(
          create: (_) => _guestsManager,
        ),
        ChangeNotifierProvider<LocalGuestsService>(
          create: (_) => _localGuestsService,
        ),
        ChangeNotifierProvider<ChecklistManager>(
          create: (_) => _checklistManager,
        ),
        ChangeNotifierProvider<LocalChecklistService>(
          create: (_) => _localChecklistService,
        ),
        ChangeNotifierProvider<CalendarManager>(
          create: (_) => _calendarManager,
        ),
        ChangeNotifierProvider<SubscriptionProvider>.value(
          value: _subscriptionProvider,
        ),
        ChangeNotifierProvider<ThemeManager>(
          create: (_) => di.locator<ThemeManager>(),
        ),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeManager, child) {
          return MaterialApp(
            title: appName,
            debugShowCheckedModeBanner: false,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeManager.themeMode,
            onGenerateRoute: (settings) {
              try {
                if (settings.name != null && settings.name != '/') {
                  try {
                    // Analytika
                  } catch (e) {
                    debugPrint('[Navigation] Chyba logování zobrazení: $e');
                    GlobalErrorHandler.instance.handleError(
                      e,
                      type: ErrorType.unknown,
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
                  type: ErrorType.critical,
                  userMessage: 'Chyba při generování obrazovky',
                  errorCode: 'ROUTE_GENERATION_001',
                );

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
                      detailMessage:
                          'Požadovaná obrazovka ${settings.name} se nepodařila načíst. Chyba: ${e.toString()}',
                    ),
                  ),
                );
              }
            },
            navigatorKey: di.locator<NavigationService>().navigatorKey,
            scaffoldMessengerKey: _scaffoldMessengerKey, // PŘIDÁNO
            navigatorObservers: [],
            builder: (context, child) {
              // Bez setContext() - používáme globální keys

              ErrorWidget.builder = (FlutterErrorDetails details) {
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
                      try {
                        di
                            .locator<NavigationService>()
                            .navigatorKey
                            .currentState
                            ?.pushNamedAndRemoveUntil(
                              RoutePaths.splash,
                              (route) => false,
                            );
                      } catch (e) {
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
                      showDialog(
                        context: context,
                        builder: (context) => ErrorDialog(
                          title: 'auto.main.nahl_sit_chybu'.tr(),
                          message:
                              'Chcete nahlásit tuto chybu vývojářskému týmu?',
                          errorType: ErrorType.info,
                          errorCode: 'UI_ERROR_REPORT',
                          technicalDetails: details.toString(),
                          recoveryActions: [
                            RecoveryAction.contact,
                            RecoveryAction.ignore
                          ],
                          onRecoveryAction: (action) {
                            if (action == RecoveryAction.contact) {
                              debugPrint(
                                  'Sending error report: ${details.exception}');
                            }
                          },
                        ),
                      );
                    },
                  ),
                );
              };

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
