// lib/providers/subscription_provider.dart - vylepšená verze s PermissionHandler

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../services/permission_handler.dart';

/// ChangeNotifier pro správu stavu předplatného.
///
/// Obaluje SubscriptionRepository a poskytuje pohodlnou možnost
/// sledovat a upravovat stav předplatného v celé aplikaci.
/// Obsahuje také záložní mechanismy pro případ, kdy Firestore není dostupný.
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionRepository _subscriptionRepo;
  Subscription? _subscription;
  bool _loading = false;
  String? _errorMessage;
  bool _hasPermissionError = false;
  
  // Odkaz na aktuálního uživatele pro případy, kdy potřebujeme vytvořit lokální Subscription
  fb.User? get currentUser => fb.FirebaseAuth.instance.currentUser;

  SubscriptionProvider({required SubscriptionRepository subscriptionRepo})
      : _subscriptionRepo = subscriptionRepo {
    // Kontrola, zda mají být při inicializaci použita uložená oprávnění
    _checkStoredPermissions();
    
    // Připojení se ke streamu předplatného
    _subscriptionRepo.subscriptionStream.listen(
      (subscription) {
        _subscription = subscription;
        notifyListeners();
      },
      onError: (error) {
        // Nastavíme příznak, že máme problém s oprávněními
        if (PermissionHandler.isPermissionError(error)) {
          _setPermissionError(error.toString());
        }
        _errorMessage = error.toString();
        debugPrint("Chyba v SubscriptionProvider: $_errorMessage");
        notifyListeners();
      }
    );

    // Počáteční načtení předplatného
    _fetchSubscription();
  }
  
  // Zkontroluje, zda jsou uloženy informace o oprávněních pro aktuálního uživatele
  Future<void> _checkStoredPermissions() async {
    final user = currentUser;
    if (user != null) {
      final hasError = await PermissionHandler.hasPermissionError(
        user.uid, 
        'subscriptions'
      );
      
      if (hasError) {
        _hasPermissionError = true;
        _errorMessage = "Nedostatečná oprávnění pro kolekci 'subscriptions'";
        debugPrint("Použita uložená informace o oprávněních: $_errorMessage");
      }
    }
  }
  
  // Nastaví příznak problému s oprávněními a uloží informaci
  Future<void> _setPermissionError(String errorMessage) async {
    _hasPermissionError = true;
    debugPrint("Detekován problém s oprávněními při načítání předplatného");
    
    // Uložení informace o problému pro budoucí použití
    final user = currentUser;
    if (user != null) {
      await PermissionHandler.savePermissionError(
        user.uid, 
        'subscriptions', 
        true
      );
    }
  }

  /// Aktuální předplatné.
  Subscription? get subscription => _subscription;

  /// Indikátor načítání.
  bool get isLoading => _loading;

  /// Případná chybová hláška.
  String? get errorMessage => _errorMessage;
  
  /// Příznak, zda máme problém s oprávněními
  bool get hasPermissionError => _hasPermissionError;

  /// Načte předplatné z repozitáře.
  Future<void> _fetchSubscription() async {
    // Pokud již víme, že máme problém s oprávněními, nesnažíme se načítat ze serveru
    if (_hasPermissionError) {
      notifyListeners();
      return;
    }
    
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _subscriptionRepo.fetchSubscription();
    } catch (e) {
      _errorMessage = e.toString();
      if (PermissionHandler.isPermissionError(e)) {
        _setPermissionError(e.toString());
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Zakoupí měsíční předplatné.
  Future<void> purchaseMonthly() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_hasPermissionError) {
        throw Exception("Nedostatečná oprávnění pro operaci s předplatným");
      }
      
      await _subscriptionRepo.purchaseMonthlySubscription();
    } catch (e) {
      _errorMessage = e.toString();
      if (PermissionHandler.isPermissionError(e)) {
        await _setPermissionError(e.toString());
      }
      rethrow; // Chybu předáme dál, aby ji mohla obrazovka zpracovat
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Zakoupí roční předplatné s možností zkušební doby.
  Future<void> purchaseYearly({bool withTrial = false, int trialDays = 7}) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_hasPermissionError) {
        throw Exception("Nedostatečná oprávnění pro operaci s předplatným");
      }
      
      await _subscriptionRepo.purchaseYearlySubscription(
        withTrial: withTrial,
        trialDays: trialDays,
      );
    } catch (e) {
      _errorMessage = e.toString();
      if (PermissionHandler.isPermissionError(e)) {
        await _setPermissionError(e.toString());
      }
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Prodlouží roční předplatné o zadaný počet dní.
  Future<void> extendSubscription({int extraDays = 365}) async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_hasPermissionError) {
        throw Exception("Nedostatečná oprávnění pro operaci s předplatným");
      }
      
      await _subscriptionRepo.extendYearlySubscription(extraDays: extraDays);
    } catch (e) {
      _errorMessage = e.toString();
      if (PermissionHandler.isPermissionError(e)) {
        await _setPermissionError(e.toString());
      }
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Zruší předplatné.
  Future<void> cancelSubscription() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (_hasPermissionError) {
        throw Exception("Nedostatečná oprávnění pro operaci s předplatným");
      }
      
      await _subscriptionRepo.cancelSubscription();
    } catch (e) {
      _errorMessage = e.toString();
      if (PermissionHandler.isPermissionError(e)) {
        await _setPermissionError(e.toString());
      }
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Obnoví načtení předplatného.
  Future<void> refreshSubscription() async {
    await _fetchSubscription();
  }
  
  /// Vytvoří a vrátí základní (free) předplatné pro aktuálního uživatele
  Subscription? createBasicSubscription() {
    final user = currentUser;
    if (user == null) return null;
    
    return Subscription(
      id: user.uid,
      userId: user.uid,
      isActive: false,
      subscriptionType: SubscriptionType.free,
      expirationDate: null,
      isTrial: false,
      gracePeriodDays: 3,
    );
  }
  
  /// Resetuje příznak problému s oprávněními - užitečné po opětovném přihlášení
  Future<void> resetPermissionError() async {
    final user = currentUser;
    if (user != null) {
      await PermissionHandler.savePermissionError(
        user.uid, 
        'subscriptions', 
        false
      );
    }
    
    _hasPermissionError = false;
    _errorMessage = null;
    notifyListeners();
    _fetchSubscription();
  }
  
  /// Vrátí seznam všech kolekcí, u kterých má aktuální uživatel problém s oprávněními
  Future<List<String>> getPermissionErrorCollections() async {
    final user = currentUser;
    if (user == null) return [];
    
    return PermissionHandler.getErrorCollections(user.uid);
  }
}