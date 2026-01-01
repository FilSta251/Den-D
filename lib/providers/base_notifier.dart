/// lib/providers/base_notifier.dart
library;

import 'package:flutter/foundation.dart';

/// Základní třída pro vĹˇechny ChangeNotifier providery v aplikaci.
///
/// poskytuje společnou funkčnost pro správu stavů náčítání, chyb a dat.
/// Výhody:
/// - Konzistentní stavovĂ© proměnnĂ© napříč providery
/// - ZjednoduĹˇený kĂłd pro nastavení stavů
/// - SnazĹˇí pouťití v UI (jednotné chování)
abstract class BaseNotifier<T> extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  T? _data;
  T? get data => _data;

  /// Nastaví stav náčítání a vymaťe případnou chybovou zprávu.
  void setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  /// Nastaví chybovou zprávu a ukončí stav náčítání.
  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }

  /// Nastaví data a ukončí stav náčítání.
  void setData(T data) {
    _data = data;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Vyčistí data, zachová ostatní stavy.
  void clearData() {
    _data = null;
    notifyListeners();
  }

  /// Vyčistí chybovou zprávu.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Vyčistí vĹˇechny stavy.
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _data = null;
    notifyListeners();
  }
}
