// lib/providers/base_notifier.dart

import 'package:flutter/foundation.dart';

/// Základní třída pro všechny ChangeNotifier providery v aplikaci.
/// 
/// Poskytuje společnou funkčnost pro správu stavů načítání, chyb a dat.
/// Výhody:
/// - Konzistentní stavové proměnné napříč providery
/// - Zjednodušený kód pro nastavení stavů
/// - Snazší použití v UI (jednotné chování)
abstract class BaseNotifier<T> extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  T? _data;
  T? get data => _data;
  
  /// Nastaví stav načítání a vymaže případnou chybovou zprávu.
  void setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
    }
    notifyListeners();
  }
  
  /// Nastaví chybovou zprávu a ukončí stav načítání.
  void setError(String message) {
    _errorMessage = message;
    _isLoading = false;
    notifyListeners();
  }
  
  /// Nastaví data a ukončí stav načítání.
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
  
  /// Vyčistí všechny stavy.
  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _data = null;
    notifyListeners();
  }
}
