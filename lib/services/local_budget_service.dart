// lib/services/local_budget_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';

/// Služba pro lokální správu rozpočtu svatby.
class LocalBudgetService extends ChangeNotifier {
  final String _storageKey = 'wedding_budget_expenses';
  List<Expense> _expenses = [];
  Timer? _saveDebounce;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Expense> get expenses => _expenses;
  
  // Časová značka poslední aktualizace seznamu
  DateTime _lastSyncTimestamp = DateTime(2000); // Výchozí hodnota v minulosti
  DateTime get lastSyncTimestamp => _lastSyncTimestamp;

  LocalBudgetService() {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("=== LOKÁLNÍ SLUŽBA: NAČÍTÁM ROZPOČET Z ÚLOŽIŠTĚ ===");
      
      // Použití přímého přístupu namísto compute
      final items = await _loadExpensesIsolate();
      _expenses = items;
      
      // Aktualizace časové značky podle nejnovější položky
      _updateLastSyncTimestamp();
      
      debugPrint("=== LOKÁLNÍ SLUŽBA: NAČTENO ${_expenses.length} POLOŽEK ROZPOČTU Z LOKÁLNÍHO ÚLOŽIŠTĚ ===");
    } catch (e) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: CHYBA PŘI NAČÍTÁNÍ: $e ===");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Aktualizuje časovou značku poslední synchronizace
  void _updateLastSyncTimestamp() {
    if (_expenses.isNotEmpty) {
      _lastSyncTimestamp = _expenses
          .map((item) => item.date)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    debugPrint("=== LOKÁLNÍ SLUŽBA: POSLEDNÍ SYNCHRONIZACE ROZPOČTU: $_lastSyncTimestamp ===");
  }
  
  // Načítání položek přímo místo compute
  Future<List<Expense>> _loadExpensesIsolate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(_storageKey);
      if (storedData != null) {
        List<dynamic> jsonData = jsonDecode(storedData);
        return jsonData.map((e) => Expense.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Error parsing expense items: $e");
    }
    return [];
  }

  Future<void> saveExpenses() async {
    try {
      debugPrint("=== LOKÁLNÍ SLUŽBA: UKLÁDÁM ROZPOČET DO ÚLOŽIŠTĚ ===");
      
      // Ukládání přímo místo compute
      await _saveExpensesIsolate();
      
      // Aktualizace časové značky
      _updateLastSyncTimestamp();
      
      debugPrint("=== LOKÁLNÍ SLUŽBA: ROZPOČET ULOŽEN, ${_expenses.length} POLOŽEK ===");
    } catch (e) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: CHYBA PŘI UKLÁDÁNÍ: $e ===");
    }
  }
  
  // Ukládání položek přímo místo compute
  Future<void> _saveExpensesIsolate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _expenses.map((item) => item.toJson()).toList();
      final String jsonData = jsonEncode(data);
      await prefs.setString(_storageKey, jsonData);
    } catch (e) {
      debugPrint("Error saving expense items: $e");
    }
  }
  
  void addExpense(Expense expense) {
    debugPrint("=== LOKÁLNÍ SLUŽBA: PŘIDÁVÁM VÝDAJ: ${expense.title} ===");
    _expenses.add(expense);
    _notifyChange();
  }

  void removeExpense(String id) {
    final index = _expenses.indexWhere((expense) => expense.id == id);
    if (index != -1) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: ODSTRAŇUJI VÝDAJ: ${_expenses[index].title} ===");
      _expenses.removeAt(index);
      _notifyChange();
    }
  }

  void updateExpense(Expense updatedExpense) {
    final index = _expenses.indexWhere((expense) => expense.id == updatedExpense.id);
    if (index != -1) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: AKTUALIZUJI VÝDAJ: ${updatedExpense.title} ===");
      _expenses[index] = updatedExpense;
      _notifyChange();
    }
  }

  void clearAllExpenses() {
    debugPrint("=== LOKÁLNÍ SLUŽBA: MAŽU VŠECHNY VÝDAJE ===");
    _expenses.clear();
    _notifyChange();
  }
  
  /// Aktualizuje seznam položek bez notifikace posluchačů (pro interní použití)
  void setExpensesWithoutNotify(List<Expense> expenses) {
    debugPrint("=== LOKÁLNÍ SLUŽBA: NASTAVUJI ${expenses.length} VÝDAJŮ BEZ NOTIFIKACE ===");
    _expenses = expenses;
    saveExpenses();
  }

  String exportToJson() {
    debugPrint("=== LOKÁLNÍ SLUŽBA: EXPORTUJI ROZPOČET DO JSON ===");
    return jsonEncode(_expenses.map((item) => item.toJson()).toList());
  }

  Future<void> importFromJson(String jsonData) async {
    debugPrint("=== LOKÁLNÍ SLUŽBA: IMPORTUJI ROZPOČET Z JSON ===");
    try {
      // Parsování JSON dat přímo místo compute
      List<dynamic> data = jsonDecode(jsonData);
      _expenses = data.map((e) => Expense.fromJson(e)).toList();
      _notifyChange();
    } catch (e) {
      debugPrint("=== LOKÁLNÍ SLUŽBA: CHYBA PŘI IMPORTU: $e ===");
    }
  }

  void _notifyChange() {
    notifyListeners();
    _debounceSave();
  }

  void _debounceSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      saveExpenses();
    });
  }

  @override
  void dispose() {
    debugPrint("=== LOKÁLNÍ SLUŽBA: UKONČUJI SLUŽBU ROZPOČTU ===");
    _saveDebounce?.cancel();
    super.dispose();
  }
}