// lib/di/service_locator.dart - aktualizace pro LocalBudgetService

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Služby
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/crash_reporting_service.dart';
import '../services/local_storage_service.dart';
import '../services/local_schedule_service.dart';
import '../services/navigation_service.dart';
import '../services/local_budget_service.dart'; // Přidáno pro rozpočet

// Repositories
import '../repositories/user_repository.dart';
import '../repositories/tasks_repository.dart';
import '../repositories/wedding_repository.dart';
import '../repositories/subscription_repository.dart';

// Singleton instance
final locator = GetIt.instance;

/// Inicializace service locatoru (dependency injection)
Future<void> init() async {
  try {
    debugPrint('[DI] Inicializace service locatoru...');

    // Firebase instance
    locator.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
    locator.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);
    locator.registerSingleton<FirebaseCrashlytics>(FirebaseCrashlytics.instance);
    locator.registerSingleton<FirebaseAnalytics>(FirebaseAnalytics.instance);

    // Inicializace SharedPreferences pro LocalStorageService
    final sharedPreferences = await SharedPreferences.getInstance();
    locator.registerSingleton<SharedPreferences>(sharedPreferences);

    // Služby

    // AuthService - používá FirebaseAuth pro přihlašování
    locator.registerLazySingleton<AuthService>(() => AuthService());

    // NavigationService - centrální správa navigace
    locator.registerLazySingleton<NavigationService>(() => NavigationService());

    // NotificationService - správa notifikací
    locator.registerLazySingleton<NotificationService>(() => NotificationService());

    // LocalStorageService - práce s lokálním úložištěm
    locator.registerLazySingleton<LocalStorageService>(() => LocalStorageService(
      sharedPreferences: locator<SharedPreferences>(),
    ));

    // LocalScheduleService - lokální správa harmonogramu
    locator.registerLazySingleton<LocalScheduleService>(() => LocalScheduleService());
    
    // LocalBudgetService - lokální správa rozpočtu - NOVĚ PŘIDÁNO
    locator.registerLazySingleton<LocalBudgetService>(() => LocalBudgetService());

    // CrashReportingService - hlášení chyb
    locator.registerLazySingleton<CrashReportingService>(() => CrashReportingService.create());

    // Repositories

    // UserRepository - práce s uživatelskými údaji
    locator.registerLazySingleton<UserRepository>(() => UserRepository());

    // TasksRepository - práce s úkoly
    locator.registerLazySingleton<TasksRepository>(() => TasksRepository());

    // WeddingRepository - práce s údaji o svatbě
    locator.registerLazySingleton<WeddingRepository>(() => WeddingRepository());

    // SubscriptionRepository - práce s předplatným
    locator.registerLazySingleton<SubscriptionRepository>(() => SubscriptionRepository());

    debugPrint('[DI] Service locator inicializován úspěšně');
  } catch (e, stack) {
    debugPrint('[DI] Chyba při inicializaci service locatoru: $e');
    debugPrintStack(label: 'Stack trace', stackTrace: stack);
    // Pokusíme se zaznamenat chybu do Crashlytics, pokud je dostupné
    try {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'DI initialization failed');
    } catch (_) {
      // Ignorujeme chybu Crashlytics, protože DI selhal
    }
    rethrow;
  }
}