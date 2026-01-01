/// lib/di/service_locator.dart
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Services
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/local_storage_service.dart';
import '../services/local_schedule_service.dart';
import '../services/cloud_schedule_service.dart';
import '../services/schedule_manager.dart';
import '../services/navigation_service.dart';
import '../services/local_budget_service.dart';
import '../services/cloud_budget_service.dart';
import '../services/budget_manager.dart';
import '../services/environment_config.dart';
import '../services/connectivity_manager.dart';
import '../services/security_service.dart';
import '../services/firestore_subscription_service.dart';
import '../services/payment_service.dart';
import '../services/analytics_service.dart';
import '../utils/error_handler.dart';

// Repositories
import '../repositories/user_repository.dart';
import '../repositories/wedding_repository.dart';
import '../repositories/subscription_repository.dart';

// Providers
import '../providers/subscription_provider.dart';
import '../providers/theme_manager.dart';

// Singleton instance
final GetIt locator = GetIt.instance;

/// Fáze inicializace DI
enum InitializationPhase {
  notStarted,
  coreServices,
  dataServices,
  repositories,
  managers,
  providers,
  completed,
  error,
}

/// Aktuální fáze inicializace
InitializationPhase _currentPhase = InitializationPhase.notStarted;

/// Získání aktuálního stavu inicializace
InitializationPhase get currentInitializationPhase => _currentPhase;

/// Nastavení fáze inicializace a logování
void _setPhase(InitializationPhase phase) {
  _currentPhase = phase;
  debugPrint('[DI] Fáze inicializace: ${phase.toString().split('.').last}');
}

/// Časový limit pro inicializaci služby v millisekundách
const int _serviceTimeoutMs = 5000;

/// Inicializace service locatoru (dependency injection) s pořadím
Future<void> init() async {
  // OCHRANA: Pokud už je inicializace dokončena, skonči
  if (_currentPhase == InitializationPhase.completed) {
    debugPrint('[DI] Service locator už je inicializován, přeskakuji');
    return;
  }

  _setPhase(InitializationPhase.notStarted);

  try {
    debugPrint('[DI] Zahájení inicializace service locatoru...');

    // ===== FÁZE 1: Základní služby =====
    _setPhase(InitializationPhase.coreServices);

    // Environment konfigurace - první, aby byla dostupná pro ostatní služby
    // OCHRANA: Registruj pouze pokud ještě není zaregistrováno
    if (!locator.isRegistered<EnvironmentConfig>()) {
      final environmentConfig = EnvironmentConfig();
      // Pokud už je inicializovaný (např. v main.dart kvůli Firebase), neděláme nic
      if (!environmentConfig.isInitialized) {
        await environmentConfig.initialize();
      }
      locator.registerSingleton<EnvironmentConfig>(environmentConfig);
      debugPrint('[DI] EnvironmentConfig zaregistrován');
    } else {
      debugPrint('[DI] EnvironmentConfig už je zaregistrován, přeskakuji');
    }

    // Firebase instance
    if (!locator.isRegistered<FirebaseAuth>()) {
      locator.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
    }
    if (!locator.isRegistered<FirebaseFirestore>()) {
      locator.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
    }
    if (!locator.isRegistered<FirebaseCrashlytics>()) {
      locator
          .registerSingleton<FirebaseCrashlytics>(FirebaseCrashlytics.instance);
    }
    if (!locator.isRegistered<FirebaseAnalytics>()) {
      locator.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics.instance);
    }

    // Connectivity pro sledování síťového připojení
    if (!locator.isRegistered<Connectivity>()) {
      locator.registerSingleton<Connectivity>(Connectivity());
    }

    // Inicializace SharedPreferences pro LocalStorageService
    if (!locator.isRegistered<SharedPreferences>()) {
      final sharedPreferences = await SharedPreferences.getInstance();
      locator.registerSingleton<SharedPreferences>(sharedPreferences);
    }

    // NavigationService MUSÍ být zaregistrován PŘED ErrorHandler
    if (!locator.isRegistered<NavigationService>()) {
      locator
          .registerLazySingleton<NavigationService>(() => NavigationService());
    }

    // CrashReportingService MUSÍ být zaregistrován PŘED ErrorHandler
    if (!locator.isRegistered<CrashReportingService>()) {
      locator.registerLazySingleton<CrashReportingService>(
          () => CrashReportingService.create());
    }

    // Inicializace CrashReportingService
    try {
      final crashService = locator<CrashReportingService>();
      await crashService
          .initialize()
          .timeout(Duration(milliseconds: _serviceTimeoutMs));
    } catch (e) {
      debugPrint('[DI] CrashReportingService timeout nebo chyba: $e');
    }

    // Error handler - NYNÍ může používat CrashReportingService a NavigationService
    if (!locator.isRegistered<ErrorHandler>()) {
      final errorHandler = ErrorHandler();
      await errorHandler.initialize();
      locator.registerSingleton<ErrorHandler>(errorHandler);
    }

    // Security service
    if (!locator.isRegistered<SecurityService>()) {
      final securityService = SecurityService();
      // Inicializace se provede v main.dart, ne tady
      locator.registerSingleton<SecurityService>(securityService);
    }

    // Connectivity manager
    if (!locator.isRegistered<ConnectivityManager>()) {
      final connectivityManager = ConnectivityManager();
      await connectivityManager.initialize();
      locator.registerSingleton<ConnectivityManager>(connectivityManager);
    }

    // ===== FÁZE 2: Datové služby =====
    _setPhase(InitializationPhase.dataServices);

    // LocalStorageService - práce s lokálním úložištěm
    if (!locator.isRegistered<LocalStorageService>()) {
      locator
          .registerLazySingleton<LocalStorageService>(() => LocalStorageService(
                sharedPreferences: locator<SharedPreferences>(),
              ));
    }

    // PaymentService - správa in-app nákupů
    if (!locator.isRegistered<PaymentService>()) {
      locator.registerLazySingleton<PaymentService>(() => PaymentService());
    }

    // FirestoreSubscriptionService - správa předplatného ve Firestore
    if (!locator.isRegistered<FirestoreSubscriptionService>()) {
      locator.registerLazySingleton<FirestoreSubscriptionService>(
          () => FirestoreSubscriptionService(locator<FirebaseFirestore>()));
    }

    // AuthService - používá FirebaseAuth pro přihlašování
    if (!locator.isRegistered<AuthService>()) {
      locator.registerLazySingleton<AuthService>(() => AuthService());
    }

    // NotificationService - správa notifikací
    if (!locator.isRegistered<NotificationService>()) {
      locator.registerLazySingleton<NotificationService>(
          () => NotificationService());
    }

    // AnalyticsService - analytika a metriky
    if (!locator.isRegistered<AnalyticsService>()) {
      locator.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
    }

    // Lokální služby (musí být inicializovány před managery)

    // LocalScheduleService - lokální správa harmonogramu
    if (!locator.isRegistered<LocalScheduleService>()) {
      locator.registerLazySingleton<LocalScheduleService>(
          () => LocalScheduleService());
    }

    // LocalBudgetService - lokální správa rozpočtu
    if (!locator.isRegistered<LocalBudgetService>()) {
      locator.registerLazySingleton<LocalBudgetService>(
          () => LocalBudgetService());
    }

    // Cloud služby

    // CloudScheduleService - cloudová synchronizace harmonogramu
    if (!locator.isRegistered<CloudScheduleService>()) {
      locator.registerLazySingleton<CloudScheduleService>(
          () => CloudScheduleService(
                firestore: locator<FirebaseFirestore>(),
                auth: locator<FirebaseAuth>(),
              ));
    }

    // CloudBudgetService - cloudová synchronizace rozpočtu
    if (!locator.isRegistered<CloudBudgetService>()) {
      locator
          .registerLazySingleton<CloudBudgetService>(() => CloudBudgetService(
                firestore: locator<FirebaseFirestore>(),
                auth: locator<FirebaseAuth>(),
              ));
    }

    // ===== FÁZE 3: Repositories =====
    _setPhase(InitializationPhase.repositories);

    // UserRepository - práce s uživatelskými údaji
    if (!locator.isRegistered<UserRepository>()) {
      locator.registerLazySingleton<UserRepository>(() => UserRepository(
            firestore: locator<FirebaseFirestore>(),
            auth: locator<FirebaseAuth>(),
          ));
    }

    // WeddingRepository - práce s údaji o svatbě
    if (!locator.isRegistered<WeddingRepository>()) {
      locator
          .registerLazySingleton<WeddingRepository>(() => WeddingRepository());
    }

    // SubscriptionRepository - práce s předplatným
    if (!locator.isRegistered<SubscriptionRepository>()) {
      locator.registerLazySingleton<SubscriptionRepository>(
          () => SubscriptionRepository(
                paymentService: locator<PaymentService>(),
                firestoreService: locator<FirestoreSubscriptionService>(),
              ));
    }

    // ===== FÁZE 4: Managery =====
    _setPhase(InitializationPhase.managers);

    // ScheduleManager - správa harmonogramu a synchronizace
    if (!locator.isRegistered<ScheduleManager>()) {
      locator.registerLazySingleton<ScheduleManager>(() => ScheduleManager(
            localService: locator<LocalScheduleService>(),
            cloudService: locator<CloudScheduleService>(),
            auth: locator<FirebaseAuth>(),
          ));
    }

    // BudgetManager - správa rozpočtu a synchronizace
    if (!locator.isRegistered<BudgetManager>()) {
      locator.registerLazySingleton<BudgetManager>(() => BudgetManager(
            localService: locator<LocalBudgetService>(),
            cloudService: locator<CloudBudgetService>(),
            auth: locator<FirebaseAuth>(),
          ));
    }

    // ===== FÁZE 5: Providers =====
    _setPhase(InitializationPhase.providers);

    // ThemeManager
    if (!locator.isRegistered<ThemeManager>()) {
      locator.registerLazySingleton<ThemeManager>(() => ThemeManager(
            localStorage: locator<LocalStorageService>(),
          ));
    }

    // SubscriptionProvider
    if (!locator.isRegistered<SubscriptionProvider>()) {
      locator.registerLazySingleton<SubscriptionProvider>(
          () => SubscriptionProvider(
                subscriptionRepository: locator<SubscriptionRepository>(),
                localStorage: locator<LocalStorageService>(),
              ));
    }

    // ===== INICIALIZACE SLUŽEB =====

    // Inicializace PaymentService
    try {
      final paymentService = locator<PaymentService>();
      await paymentService
          .initialize()
          .timeout(Duration(milliseconds: _serviceTimeoutMs));
      debugPrint('[DI] PaymentService úspěšně inicializován');
    } catch (e) {
      debugPrint('[DI] Chyba při inicializaci PaymentService: $e');
    }

    // Inicializace NotificationService
    try {
      final notificationService = locator<NotificationService>();
      await notificationService
          .initialize()
          .timeout(Duration(milliseconds: _serviceTimeoutMs));
    } catch (e) {
      debugPrint('[DI] Chyba při inicializaci NotificationService: $e');
    }

    // Inicializace AnalyticsService
    try {
      final analyticsService = locator<AnalyticsService>();
      await analyticsService
          .initialize()
          .timeout(Duration(milliseconds: _serviceTimeoutMs));
      debugPrint('[DI] AnalyticsService úspěšně inicializován');
    } catch (e) {
      debugPrint('[DI] Chyba při inicializaci AnalyticsService: $e');
    }

    _setPhase(InitializationPhase.completed);
    debugPrint('[DI] Service locator úspěšně inicializován');
  } catch (e, stack) {
    _setPhase(InitializationPhase.error);
    debugPrint('[DI] Chyba při inicializaci service locatoru: $e');
    debugPrintStack(label: 'Stack trace', stackTrace: stack);

    try {
      if (locator.isRegistered<FirebaseCrashlytics>()) {
        FirebaseCrashlytics.instance
            .recordError(e, stack, reason: 'DI initialization failed');
      }
    } catch (_) {}
    rethrow;
  }
}

/// Metoda pro bezpečné získání služby s timeoutem
Future<T?> getServiceSafely<T extends Object>(Duration timeout,
    {bool required = true}) async {
  try {
    if (locator.isRegistered<T>() && locator.isReadySync<T>()) {
      return locator<T>();
    }
    return await Future(() => locator<T>()).timeout(timeout);
  } catch (e) {
    debugPrint('[DI] Nepodařilo se získat službu $T: $e');
    if (required) rethrow;
    return null;
  }
}

/// Zkontroluje, zda je service locator připraven
Future<bool> isDiReady() async {
  try {
    return _currentPhase == InitializationPhase.completed;
  } catch (e) {
    debugPrint('[DI] Service locator není připraven: $e');
    return false;
  }
}

/// Vyčistí service locator (především pro testy)
Future<void> reset() async {
  await locator.reset();
  _setPhase(InitializationPhase.notStarted);
}
