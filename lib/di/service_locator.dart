// lib/di/service_locator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Služby
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
import '../utils/error_handler.dart';

// Repositories
import '../repositories/user_repository.dart';
import '../repositories/wedding_repository.dart';
import '../repositories/subscription_repository.dart';

// Providers
import '../providers/subscription_provider.dart';

// Singleton instance
final locator = GetIt.instance;

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
  _setPhase(InitializationPhase.notStarted);
  
  try {
    debugPrint('[DI] Zahájení inicializace service locatoru...');
    
    // ===== FÁZE 1: Základní služby =====
    _setPhase(InitializationPhase.coreServices);
    
    // Environment konfigurace - první, aby byla dostupná pro ostatní služby
    final environmentConfig = EnvironmentConfig();
    await environmentConfig.initialize();
    locator.registerSingleton<EnvironmentConfig>(environmentConfig);
    
    // Firebase instance
    locator.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
    locator.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
    locator.registerSingleton<FirebaseCrashlytics>(FirebaseCrashlytics.instance);
    locator.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics.instance);
    
    // Connectivity pro sledování síťového připojení
    locator.registerSingleton<Connectivity>(Connectivity());

    // Inicializace SharedPreferences pro LocalStorageService
    final sharedPreferences = await SharedPreferences.getInstance();
    locator.registerSingleton<SharedPreferences>(sharedPreferences);
    
    // NavigationService MUSÍ být zaregistrován PŘED ErrorHandler
    locator.registerLazySingleton<NavigationService>(() => NavigationService());
    
    // CrashReportingService MUSÍ být zaregistrován PŘED ErrorHandler
    locator.registerLazySingleton<CrashReportingService>(() => CrashReportingService.create());
    
    // Inicializace CrashReportingService
    final crashService = locator<CrashReportingService>();
    await crashService.initialize().timeout(Duration(milliseconds: _serviceTimeoutMs));
    
    // Error handler - NYNÍ může používat CrashReportingService a NavigationService
    final errorHandler = ErrorHandler();
    await errorHandler.initialize();
    locator.registerSingleton<ErrorHandler>(errorHandler);
    
    // Security service
    final securityService = SecurityService();
    await securityService.initialize();
    locator.registerSingleton<SecurityService>(securityService);
    
    // Connectivity manager
    final connectivityManager = ConnectivityManager();
    await connectivityManager.initialize();
    locator.registerSingleton<ConnectivityManager>(connectivityManager);
    
    // ===== FÁZE 2: Datové služby =====
    _setPhase(InitializationPhase.dataServices);

    // LocalStorageService - práce s lokálním úložištěm
    locator.registerLazySingleton<LocalStorageService>(() => LocalStorageService(
      sharedPreferences: locator<SharedPreferences>(),
    ));
    
    // AuthService - používá FirebaseAuth pro přihlašování
    locator.registerLazySingleton<AuthService>(() => AuthService());
    
    // NotificationService - správa notifikací
    locator.registerLazySingleton<NotificationService>(() => NotificationService());
    
    // Lokální služby (musí být inicializovány před managery)
    
    // LocalScheduleService - lokální správa harmonogramu
    locator.registerLazySingleton<LocalScheduleService>(() => LocalScheduleService());
    
    // LocalBudgetService - lokální správa rozpočtu
    locator.registerLazySingleton<LocalBudgetService>(() => LocalBudgetService());
    
    // Cloud služby
    
    // CloudScheduleService - cloudová synchronizace harmonogramu
    locator.registerLazySingleton<CloudScheduleService>(() => CloudScheduleService(
      firestore: locator<FirebaseFirestore>(),
      auth: locator<FirebaseAuth>(),
    ));
    
    // CloudBudgetService - cloudová synchronizace rozpočtu
    locator.registerLazySingleton<CloudBudgetService>(() => CloudBudgetService(
      firestore: locator<FirebaseFirestore>(),
      auth: locator<FirebaseAuth>(),
    ));
    
    // ===== FÁZE 3: Repositories =====
    _setPhase(InitializationPhase.repositories);

    // UserRepository - práce s uživatelskými údaji
    locator.registerLazySingleton<UserRepository>(() => UserRepository(
      firestore: locator<FirebaseFirestore>(),
      auth: locator<FirebaseAuth>(),
    ));

    // WeddingRepository - práce s údaji o svatbě
    locator.registerLazySingleton<WeddingRepository>(() => WeddingRepository());

    // SubscriptionRepository - práce s předplatným
    locator.registerLazySingleton<SubscriptionRepository>(() => SubscriptionRepository(
      firestore: locator<FirebaseFirestore>(),
      firebaseAuth: locator<FirebaseAuth>(),
    ));
    
    // ===== FÁZE 4: Managery =====
    _setPhase(InitializationPhase.managers);
    
    // ScheduleManager - správa harmonogramu a synchronizace
    locator.registerLazySingleton<ScheduleManager>(() => ScheduleManager(
      localService: locator<LocalScheduleService>(),
      cloudService: locator<CloudScheduleService>(),
      auth: locator<FirebaseAuth>(),
    ));
    
    // BudgetManager - správa rozpočtu a synchronizace
    locator.registerLazySingleton<BudgetManager>(() => BudgetManager(
      localService: locator<LocalBudgetService>(),
      cloudService: locator<CloudBudgetService>(),
      auth: locator<FirebaseAuth>(),
    ));
    
    // ===== FÁZE 5: Providers =====
    _setPhase(InitializationPhase.providers);
    
    // SubscriptionProvider
    locator.registerLazySingleton<SubscriptionProvider>(() => SubscriptionProvider(
      subscriptionRepo: locator<SubscriptionRepository>(),
    ));

    // Inicializace NotificationService
    try {
      final notificationService = locator<NotificationService>();
      await notificationService.initialize().timeout(Duration(milliseconds: _serviceTimeoutMs));
    } catch (e) {
      debugPrint('[DI] Chyba při inicializaci NotificationService: $e');
      // Pokračujeme dál, notifikace nejsou kritické
    }
    
    _setPhase(InitializationPhase.completed);
    debugPrint('[DI] Service locator úspěšně inicializován');
    
  } catch (e, stack) {
    _setPhase(InitializationPhase.error);
    debugPrint('[DI] Chyba při inicializaci service locatoru: $e');
    debugPrintStack(label: 'Stack trace', stackTrace: stack);
    
    // Pokusíme se zaznamenat chybu do Crashlytics, pokud je dostupné
    try {
      if (locator.isRegistered<FirebaseCrashlytics>()) {
        FirebaseCrashlytics.instance.recordError(e, stack, reason: 'DI initialization failed');
      }
    } catch (_) {
      // Ignorujeme chybu Crashlytics, protože DI selhal
    }
    rethrow;
  }
}

/// Metoda pro bezpečné získání služby s timeoutem
Future<T?> getServiceSafely<T extends Object>(Duration timeout, {bool required = true}) async {
  try {
    // Pokud je služba už zaregistrovaná a inicializovaná, vrátíme ji hned
    if (locator.isRegistered<T>() && locator.isReadySync<T>()) {
      return locator<T>();
    }
    
    // Jinak počkáme na inicializaci
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
    // Kontrolujeme jen synchronní služby
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