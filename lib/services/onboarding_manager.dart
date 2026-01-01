/// lib/services/onboarding_manager.dart
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'firestore_onboarding_service.dart';

/// Třída pro správu stavu onboardingu s Firestore synchronizací
///
/// HLAVNÍ ZMĚNY:
/// - Používá Firestore jako source of truth
/// - Local cache (SharedPreferences) pro rychlý přístup a offline režim
/// - Automatická synchronizace mezi zařízeními
/// - Migration existujících dat
class OnboardingManager {
  // Lokální klíče (pro cache)
  static const String _onboardingCompletedKey = 'onboardingCompleted';
  static const String _introCompletedKey = 'introCompleted';
  static const String _chatbotCompletedKey = 'chatbotCompleted';
  static const String _subscriptionShownKey = 'subscriptionShown';
  static const String _migrationDoneKey = 'onboarding_migration_done';
  static const String _lastSyncKey = 'onboarding_last_sync';

  // Firestore service
  static final FirestoreOnboardingService _firestoreService =
      FirestoreOnboardingService.defaultInstance();

  // Cache timeout (jak dlouho je local cache validní)
  static const Duration _cacheTimeout = Duration(minutes: 30);

  /// ============================================
  /// MIGRACE EXISTUJÍCÍCH DAT
  /// ============================================

  /// Migruje existující lokální data do Firestore
  ///
  /// Volá se automaticky při prvním použití s [userId]
  /// Stará se o to, aby uživatelé, kteří už prošli onboardingem,
  /// nemuseli procházet znovu
  static Future<void> migrateToFirestore(String userId) async {
    if (userId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationDone = prefs.getBool(_migrationDoneKey) ?? false;

      if (migrationDone) {
        debugPrint('[OnboardingManager] Migrace již byla provedena');
        return;
      }

      debugPrint(
          '[OnboardingManager] Zahajuji migraci lokálních dat do Firestore');

      // Načteme lokální data
      final localIntroCompleted = prefs.getBool(_introCompletedKey) ?? false;
      final localChatbotCompleted =
          prefs.getBool(_chatbotCompletedKey) ?? false;
      final localSubscriptionShown =
          prefs.getBool(_subscriptionShownKey) ?? false;
      final localOnboardingCompleted =
          prefs.getBool(_onboardingCompletedKey) ?? false;

      // Zkontrolujeme, zda v Firestore už něco je
      final existingState = await _firestoreService.getOnboardingState(userId);

      if (existingState == null) {
        // Firestore je prázdný, přeneseme lokální data
        debugPrint('[OnboardingManager] Přenáším lokální data do Firestore');

        final state = OnboardingState(
          userId: userId,
          introCompleted: localIntroCompleted,
          chatbotCompleted: localChatbotCompleted,
          subscriptionShown: localSubscriptionShown,
          onboardingCompleted: localOnboardingCompleted,
          onboardingCompletedAt:
              localOnboardingCompleted ? DateTime.now() : null,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.saveOnboardingState(userId, state);
        debugPrint('[OnboardingManager] Lokální data přenesena do Firestore');
      } else {
        // Firestore už obsahuje data, použijeme ta (priorita má server)
        debugPrint(
            '[OnboardingManager] Firestore již obsahuje data, používám serverová data');

        // Aktualizujeme lokální cache
        await prefs.setBool(_introCompletedKey, existingState.introCompleted);
        await prefs.setBool(
            _chatbotCompletedKey, existingState.chatbotCompleted);
        await prefs.setBool(
            _subscriptionShownKey, existingState.subscriptionShown);
        await prefs.setBool(
            _onboardingCompletedKey, existingState.onboardingCompleted);
      }

      // Označíme migraci jako dokončenou
      await prefs.setBool(_migrationDoneKey, true);
      debugPrint('[OnboardingManager] Migrace dokončena');
    } catch (e) {
      debugPrint('[OnboardingManager] Chyba při migraci: $e');
      // Pokračujeme i přes chybu, abychom neblokovali aplikaci
    }
  }

  /// ============================================
  /// SYNCHRONIZACE S FIRESTORE
  /// ============================================

  /// Synchronizuje lokální cache s Firestore
  ///
  /// [userId] - ID uživatele
  /// [forceSync] - Vynutit synchronizaci i když cache je čerstvá
  static Future<void> syncWithFirestore(
    String userId, {
    bool forceSync = false,
  }) async {
    if (userId.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Kontrola, zda je potřeba synchronizovat
      if (!forceSync) {
        final lastSyncStr = prefs.getString(_lastSyncKey);
        if (lastSyncStr != null) {
          final lastSync = DateTime.parse(lastSyncStr);
          final timeSinceSync = DateTime.now().difference(lastSync);

          if (timeSinceSync < _cacheTimeout) {
            debugPrint('[OnboardingManager] Cache je čerstvá, přeskakuji sync');
            return;
          }
        }
      }

      debugPrint('[OnboardingManager] Synchronizuji s Firestore');

      // Načteme data z Firestore
      final state = await _firestoreService.getOnboardingState(userId);

      if (state != null) {
        // Aktualizujeme lokální cache
        await prefs.setBool(_introCompletedKey, state.introCompleted);
        await prefs.setBool(_chatbotCompletedKey, state.chatbotCompleted);
        await prefs.setBool(_subscriptionShownKey, state.subscriptionShown);
        await prefs.setBool(_onboardingCompletedKey, state.onboardingCompleted);
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

        debugPrint('[OnboardingManager] Synchronizace dokončena');
      }
    } catch (e) {
      debugPrint('[OnboardingManager] Chyba při synchronizaci: $e');
      // Používáme lokální cache
    }
  }

  /// ============================================
  /// HLAVNÍ API - KONTROLY STAVU
  /// ============================================

  /// Kontroluje, zda byl celý onboarding dokončen
  ///
  /// [userId] - ID uživatele (pokud není null, zkontroluje Firestore)
  static Future<bool> isOnboardingCompleted({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pokud máme userId, nejdřív synchronizujeme
      if (userId != null && userId.isNotEmpty) {
        await syncWithFirestore(userId);
      }

      return prefs.getBool(_onboardingCompletedKey) ?? false;
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při kontrole onboarding completion: $e');
      return false;
    }
  }

  /// Kontroluje, zda byla dokončena intro část
  ///
  /// [userId] - ID uživatele (pokud není null, zkontroluje Firestore)
  static Future<bool> isIntroCompleted({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pokud máme userId, nejdřív synchronizujeme
      if (userId != null && userId.isNotEmpty) {
        await syncWithFirestore(userId);
      }

      return prefs.getBool(_introCompletedKey) ?? false;
    } catch (e) {
      debugPrint('[OnboardingManager] Chyba při kontrole intro completion: $e');
      return false;
    }
  }

  /// Kontroluje, zda byla dokončena chatbot část
  ///
  /// [userId] - ID uživatele (pokud není null, zkontroluje Firestore)
  static Future<bool> isChatbotCompleted({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pokud máme userId, nejdřív synchronizujeme
      if (userId != null && userId.isNotEmpty) {
        await syncWithFirestore(userId);
      }

      return prefs.getBool(_chatbotCompletedKey) ?? false;
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při kontrole chatbot completion: $e');
      return false;
    }
  }

  /// Kontroluje, zda byla zobrazena nabídka předplatného
  ///
  /// [userId] - ID uživatele (pokud není null, zkontroluje Firestore)
  static Future<bool> isSubscriptionShown({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Pokud máme userId, nejdřív synchronizujeme
      if (userId != null && userId.isNotEmpty) {
        await syncWithFirestore(userId);
      }

      return prefs.getBool(_subscriptionShownKey) ?? false;
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při kontrole subscription shown: $e');
      return false;
    }
  }

  /// ============================================
  /// HLAVNÍ API - NASTAVENÍ STAVU
  /// ============================================

  /// Označí onboarding jako dokončený
  ///
  /// [userId] - ID uživatele (pokud není null, uloží do Firestore)
  static Future<void> markOnboardingCompleted({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);

      // Uložení do Firestore
      if (userId != null && userId.isNotEmpty) {
        await _firestoreService.markOnboardingCompleted(userId);
      }

      debugPrint('[OnboardingManager] Onboarding marked as completed');
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při označování onboarding completion: $e');
    }
  }

  /// Označí intro jako dokončené
  ///
  /// [userId] - ID uživatele (pokud není null, uloží do Firestore)
  static Future<void> markIntroCompleted({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_introCompletedKey, true);

      // Uložení do Firestore
      if (userId != null && userId.isNotEmpty) {
        await _firestoreService.markIntroCompleted(userId);
      }

      debugPrint('[OnboardingManager] Intro marked as completed');
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při označování intro completion: $e');
    }
  }

  /// Označí chatbot jako dokončený
  ///
  /// [userId] - ID uživatele (pokud není null, uloží do Firestore)
  static Future<void> markChatbotCompleted({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatbotCompletedKey, true);

      // Uložení do Firestore
      if (userId != null && userId.isNotEmpty) {
        await _firestoreService.markChatbotCompleted(userId);
      }

      debugPrint('[OnboardingManager] Chatbot marked as completed');
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při označování chatbot completion: $e');
    }
  }

  /// Označí nabídku předplatného jako zobrazenou
  ///
  /// [userId] - ID uživatele (pokud není null, uloží do Firestore)
  static Future<void> markSubscriptionShown({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_subscriptionShownKey, true);

      // Uložení do Firestore
      if (userId != null && userId.isNotEmpty) {
        await _firestoreService.markSubscriptionShown(userId);
      }

      debugPrint('[OnboardingManager] Subscription shown marked as completed');
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při označování subscription shown: $e');
    }
  }

  /// ============================================
  /// UTILITY METODY
  /// ============================================

  /// Resetuje všechny stavy onboardingu (např. pro testování)
  ///
  /// [userId] - ID uživatele (pokud není null, vymaže i z Firestore)
  static Future<void> resetOnboarding({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);
      await prefs.remove(_introCompletedKey);
      await prefs.remove(_chatbotCompletedKey);
      await prefs.remove(_subscriptionShownKey);
      await prefs.remove(_lastSyncKey);
      // NEMAZAT _migrationDoneKey - migrace by se neměla opakovat

      // Vymazání z Firestore
      if (userId != null && userId.isNotEmpty) {
        await _firestoreService.clearOnboardingState(userId);
      }

      debugPrint('[OnboardingManager] Onboarding reset successful');
    } catch (e) {
      debugPrint('[OnboardingManager] Chyba při resetování onboarding: $e');
    }
  }

  /// Získá kompletní stav onboardingu
  ///
  /// [userId] - ID uživatele
  /// Vrací mapu se všemi stavy
  static Future<Map<String, bool>> getOnboardingStatus({String? userId}) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        await syncWithFirestore(userId);
      }

      return {
        'onboardingCompleted': await isOnboardingCompleted(),
        'introCompleted': await isIntroCompleted(),
        'chatbotCompleted': await isChatbotCompleted(),
        'subscriptionShown': await isSubscriptionShown(),
      };
    } catch (e) {
      debugPrint(
          '[OnboardingManager] Chyba při získávání onboarding statusu: $e');
      return {
        'onboardingCompleted': false,
        'introCompleted': false,
        'chatbotCompleted': false,
        'subscriptionShown': false,
      };
    }
  }

  /// Vynutí okamžitou synchronizaci s Firestore
  ///
  /// [userId] - ID uživatele
  static Future<void> forceSyncNow(String userId) async {
    await syncWithFirestore(userId, forceSync: true);
  }
}
