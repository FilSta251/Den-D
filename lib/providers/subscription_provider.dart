/// lib/providers/subscription_provider.dart
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../services/local_storage_service.dart';

/// Enum pro typy interakcí v free verzi
enum InteractionType {
  addChecklistItem,
  addScheduleItem,
  addGuest,
  addExpense,
  // Další typy můžeš přidat podle potřeby
  addNote,
  uploadPhoto,
}

/// Provider pro správu předplatného a free limit logiky
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository _subscriptionRepository;
  final LocalStorageService _localStorage;
  final FirebaseAuth _auth;

  // Stav předplatného
  Subscription? _sub;
  bool _isLoading = false;
  String? _errorMessage;

  // Free limit logika - celkové počty interakcí pro každý typ
  Map<String, int> _counters = {};
  String? _currentUserId;

  // Klíče pro LocalStorage
  static const String _countersKey = 'interaction_counters';

  // ZMĚNA: Celkový limit na funkci místo denního
  static const int FREE_INTERACTION_LIMIT = 3;

  SubscriptionProvider({
    required SubscriptionRepository subscriptionRepository,
    required LocalStorageService localStorage,
    FirebaseAuth? auth,
  })  : _subscriptionRepository = subscriptionRepository,
        _localStorage = localStorage,
        _auth = auth ?? FirebaseAuth.instance;

  /// Gettery
  Subscription? get subscription => _sub;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Getter pro současného uživatele
  User? get currentUser => _auth.currentUser;

  /// Zda má uživatel aktivní Premium předplatné
  bool get isPremium {
    return _sub?.isActivePremium ?? false;
  }

  /// Getter pro zbývající free pokusy pro daný typ
  int getRemainingTriesForType(InteractionType type) {
    final count = _counters[type.toString()] ?? 0;
    return math.max(0, FREE_INTERACTION_LIMIT - count);
  }

  /// Metoda pro kontrolu a konzumaci akce (pro zpětnou kompatibilitu)
  Future<bool> checkAndConsumeAction() async {
    return await registerInteraction(InteractionType.addChecklistItem);
  }

  /// Metoda pro reset permission error
  Future<void> resetPermissionError() async {
    notifyListeners();
  }

  /// Přihlásí se na sledování předplatného konkrétního uživatele
  Future<void> bindUser(String uid) async {
    try {
      if (uid.isEmpty) {
        throw ArgumentError('error_uid_empty'.tr());
      }

      _isLoading = true;
      _currentUserId = uid;
      notifyListeners();

      debugPrint('[SubscriptionProvider] Bindování uživatele: $uid');

      // Načíst lokální čítáče
      await _loadLocalCounters();

      // Přihlásit se na stream z repository
      _subscriptionRepository.watch(uid).listen(
        (subscription) {
          _sub = subscription;
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
          debugPrint(
              '[SubscriptionProvider] Předplatné aktualizováno: ${subscription?.tier}');
        },
        onError: (error) {
          _errorMessage = error.toString();
          _isLoading = false;
          notifyListeners();
          debugPrint('[SubscriptionProvider] Chyba ve stream: $error');
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[SubscriptionProvider] Chyba při bindování uživatele: $e');
    }
  }

  /// Načte lokální čítáče z LocalStorage
  Future<void> _loadLocalCounters() async {
    try {
      final Map<String, int>? savedCounters =
          await _localStorage.getJsonMap(_countersKey);

      if (savedCounters != null) {
        _counters = Map<String, int>.from(savedCounters);
      } else {
        // Inicializace výchozích čítáčů
        _counters = {
          for (var type in InteractionType.values) type.toString(): 0
        };
      }

      debugPrint('[SubscriptionProvider] Načteny čítáče: $_counters');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Chyba při načítání čítáčů: $e');
      _counters = {for (var type in InteractionType.values) type.toString(): 0};
    }
  }

  /// Uloží čítáče do LocalStorage
  Future<void> _saveLocalCounters() async {
    try {
      await _localStorage.setJsonMap(_countersKey, _counters);
      debugPrint('[SubscriptionProvider] Čítáče uloženy: $_counters');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Chyba při ukládání čítáčů: $e');
    }
  }

  /// Kontrola, zda může uživatel provést free interakci
  bool canUseFreeInteraction(InteractionType type) {
    // Premium uživatelé mohou vše
    if (isPremium) {
      return true;
    }

    // Kontrola free limitu - celkový počet interakcí
    final currentCount = _counters[type.toString()] ?? 0;
    return currentCount < FREE_INTERACTION_LIMIT;
  }

  /// Registruje použití free interakce
  Future<bool> registerInteraction(InteractionType type) async {
    try {
      // Premium uživatelé mohou vše
      if (isPremium) {
        return true;
      }

      // Kontrola limitu
      if (!canUseFreeInteraction(type)) {
        debugPrint(
            '[SubscriptionProvider] Dosažen limit pro ${type.toString()}: ${_counters[type.toString()]}/$FREE_INTERACTION_LIMIT');
        return false;
      }

      // Zvýšit čítač
      final currentCount = _counters[type.toString()] ?? 0;
      _counters[type.toString()] = currentCount + 1;

      // Uložit do LocalStorage
      await _saveLocalCounters();

      notifyListeners();

      debugPrint(
          '[SubscriptionProvider] Registrována interakce ${type.toString()}: ${_counters[type.toString()]}/$FREE_INTERACTION_LIMIT');

      return true;
    } catch (e) {
      debugPrint('[SubscriptionProvider] Chyba při registraci interakce: $e');
      return false;
    }
  }

  /// Vrací počet zbývajících free interakcí pro daný typ
  int remaining(InteractionType type) {
    if (isPremium) {
      return 999; // Neomezené pro Premium
    }

    final currentCount = _counters[type.toString()] ?? 0;
    final remaining = FREE_INTERACTION_LIMIT - currentCount;
    return remaining > 0 ? remaining : 0;
  }

  /// Vrací celkový počet použitých interakcí pro daný typ
  int getUsedCount(InteractionType type) {
    return _counters[type.toString()] ?? 0;
  }

  /// Resetuje čítáče (užitečné pro testování nebo po upgrade na Premium)
  Future<void> resetCounters() async {
    try {
      _counters = {for (var type in InteractionType.values) type.toString(): 0};

      await _saveLocalCounters();
      notifyListeners();

      debugPrint('[SubscriptionProvider] Čítáče resetovány');
    } catch (e) {
      debugPrint('[SubscriptionProvider] Chyba při resetování čítáčů: $e');
    }
  }

  /// Zahájí nákup Premium předplatného
  Future<void> startPremiumPurchase() async {
    if (_currentUserId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _subscriptionRepository.startPremiumPurchase(_currentUserId!);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[SubscriptionProvider] Chyba při zahájení nákupu: $e');
      rethrow;
    }
  }

  /// Obnoví předchozí nákupy
  Future<void> restorePurchases() async {
    if (_currentUserId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _subscriptionRepository.restorePurchases(_currentUserId!);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[SubscriptionProvider] Chyba při obnově nákupů: $e');
      rethrow;
    }
  }

  /// Otevře správu předplatného
  Future<void> openManageSubscriptions() async {
    try {
      await _subscriptionRepository.openManageSubscriptions();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('[SubscriptionProvider] Chyba při otevírání správy: $e');
      rethrow;
    }
  }

  /// Nastaví Free tier pro aktuálního uživatele
  Future<void> setFreeTier() async {
    if (_currentUserId == null) {
      throw Exception('error_user_not_logged_in'.tr());
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      debugPrint(
          '[SubscriptionProvider] Nastavuji Free tier pro: $_currentUserId');

      await _subscriptionRepository.downgradeToFree(_currentUserId!);

      debugPrint('[SubscriptionProvider] Free tier nastaven úspěšně');
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[SubscriptionProvider] Chyba při nastavování Free tier: $e');
      rethrow;
    }
  }

  /// Vymaže chybovou zprávu
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Vrací textový popis pro daný typ interakce
  String getInteractionTypeText(InteractionType type) {
    switch (type) {
      case InteractionType.addChecklistItem:
        return tr('interaction.add_checklist_item');
      case InteractionType.addGuest:
        return tr('interaction.add_guest');
      case InteractionType.addScheduleItem:
        return tr('interaction.add_schedule_item');
      case InteractionType.addExpense:
        return tr('interaction.add_expense');
      case InteractionType.addNote:
        return tr('interaction.add_note');
      case InteractionType.uploadPhoto:
        return tr('interaction.upload_photo');
    }
  }

  /// Vrací souhrn všech čítáčů pro UI
  Map<String, dynamic> getCountersSummary() {
    final summary = <String, dynamic>{};

    for (var type in InteractionType.values) {
      final typeKey = type.toString();
      summary[typeKey] = {
        'used': getUsedCount(type),
        'remaining': remaining(type),
        'limit': FREE_INTERACTION_LIMIT,
        'canUse': canUseFreeInteraction(type),
        'displayName': getInteractionTypeText(type),
      };
    }

    return summary;
  }

  /// Kontrola dostupnosti platebního systému
  Future<bool> isPaymentAvailable() async {
    return await _subscriptionRepository.isPaymentAvailable();
  }

  @override
  void dispose() {
    _subscriptionRepository.dispose();
    super.dispose();
  }
}
