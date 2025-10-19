import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Třída pro správu stavu onboardingu.
class OnboardingManager {
  static const String _onboardingCompletedKey = 'onboardingCompleted';
  static const String _introCompletedKey = 'introCompleted';
  static const String _chatbotCompletedKey = 'chatbotCompleted';
  static const String _subscriptionShownKey = 'subscriptionShown';

  /// Kontroluje, zda byl celý onboarding dokončen.
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingCompletedKey) ?? false;
    } catch (e) {
      debugPrint('Error checking onboarding completion: $e');
      return false;
    }
  }

  /// Uloťí stav dokončenĂ©ho onboardingu.
  static Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      debugPrint('Onboarding marked as completed');
    } catch (e) {
      debugPrint('Error marking onboarding as completed: $e');
    }
  }

  /// Kontroluje, zda byla dokončena intro část.
  static Future<bool> isIntroCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_introCompletedKey) ?? false;
    } catch (e) {
      debugPrint('Error checking intro completion: $e');
      return false;
    }
  }

  /// Uloťí stav dokončenĂ©ho intra.
  static Future<void> markIntroCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_introCompletedKey, true);
      debugPrint('Intro marked as completed');
    } catch (e) {
      debugPrint('Error marking intro as completed: $e');
    }
  }

  /// Kontroluje, zda byla dokončena chatbot část.
  static Future<bool> isChatbotCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chatbotCompletedKey) ?? false;
    } catch (e) {
      debugPrint('Error checking chatbot completion: $e');
      return false;
    }
  }

  /// Uloťí stav dokončenĂ©ho chatbota.
  static Future<void> markChatbotCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatbotCompletedKey, true);
      debugPrint('Chatbot marked as completed');
    } catch (e) {
      debugPrint('Error marking chatbot as completed: $e');
    }
  }

  /// Kontroluje, zda byla zobrazena nabídka předplatnĂ©ho.
  static Future<bool> isSubscriptionShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_subscriptionShownKey) ?? false;
    } catch (e) {
      debugPrint('Error checking subscription shown: $e');
      return false;
    }
  }

  /// Uloťí stav zobrazenĂ© nabídky předplatnĂ©ho.
  static Future<void> markSubscriptionShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_subscriptionShownKey, true);
      debugPrint('Subscription shown marked as completed');
    } catch (e) {
      debugPrint('Error marking subscription shown as completed: $e');
    }
  }

  /// Resetuje vĹˇechny stavy onboardingu (např. pro testování).
  static Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingCompletedKey);
      await prefs.remove(_introCompletedKey);
      await prefs.remove(_chatbotCompletedKey);
      await prefs.remove(_subscriptionShownKey);
      debugPrint('Onboarding reset successful');
    } catch (e) {
      debugPrint('Error resetting onboarding: $e');
    }
  }
}
