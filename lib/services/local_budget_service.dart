/// lib/services/local_budget_service.dart - REFAKTOROVANĂ VERZE
library;

import 'base/base_local_storage_service.dart';
import '../models/expense.dart';

/// Sluťba pro lokální správu rozpočtu svatby vyuťívající základní třídu.
class LocalBudgetService extends BaseLocalStorageService<Expense>
    with IdBasedItemsMixin<Expense>, TimeBasedItemsMixin<Expense> {
  LocalBudgetService() : super(storageKey: 'wedding_budget_expenses');

  /// Seznam výdajů (pro zpětnou kompatibilitu)
  List<Expense> get expenses => items;

  @override
  Map<String, dynamic> itemToJson(Expense item) {
    return item.toJson();
  }

  @override
  Expense itemFromJson(Map<String, dynamic> json) {
    return Expense.fromJson(json);
  }

  @override
  DateTime getItemTimestamp(Expense item) {
    return item.date;
  }

  @override
  String getItemId(Expense item) {
    return item.id;
  }

  /// Náčte výdaje (alias pro loadItems)
  Future<void> loadExpenses() async {
    await loadItems();
  }

  /// Uloťí výdaje (alias pro saveItems)
  Future<void> saveExpenses() async {
    await saveItems();
  }

  /// Přidá výdaj
  void addExpense(Expense expense) {
    addItem(expense);
  }

  /// Odebere výdaj podle ID
  void removeExpense(String id) {
    removeItemById(id);
  }

  /// Aktualizuje výdaj
  void updateExpense(Expense updatedExpense) {
    updateItemById(updatedExpense.id, updatedExpense);
  }

  /// Získá výdaj podle ID (s oĹˇetřením chyby)
  Expense getExpenseById(String id) {
    final expense = findItemById(id);
    if (expense == null) {
      throw Exception('Výdaj s ID $id nebyl nalezen');
    }
    return expense;
  }

  /// Vymaťe vĹˇechny výdaje (alias)
  void clearAllExpenses() {
    clearAllItems();
  }

  /// Nastaví výdaje bez notifikace (alias)
  void setExpensesWithoutNotify(List<Expense> expenses) {
    setItemsWithoutNotify(expenses);
  }

  /// Vypočítá celkovou částku výdajů
  double get totalAmount {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Vypočítá částku podle kategorie
  double getAmountByCategory(String category) {
    return findItems((expense) => expense.category == category)
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Získá vĹˇechny kategorie
  Set<String> get categories {
    return expenses.map((expense) => expense.category).toSet();
  }

  /// Získá výdaje podle kategorie
  List<Expense> getExpensesByCategory(String category) {
    return findItems((expense) => expense.category == category);
  }

  /// Získá výdaje podle zaplacení
  List<Expense> getPaidExpenses() {
    return findItems((expense) => expense.isPaid);
  }

  /// Získá nezaplacenĂ© výdaje
  List<Expense> getUnpaidExpenses() {
    return findItems((expense) => !expense.isPaid);
  }

  /// Vypočítá částku zaplacených výdajů
  double get paidAmount {
    return getPaidExpenses().fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Vypočítá částku nezaplacených výdajů
  double get unpaidAmount {
    return getUnpaidExpenses()
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  /// Získá výdaje v danĂ©m měsíci
  List<Expense> getExpensesByMonth(int year, int month) {
    return findItems((expense) {
      return expense.date.year == year && expense.date.month == month;
    });
  }

  /// Získá výdaje v danĂ©m roce
  List<Expense> getExpensesByYear(int year) {
    return findItems((expense) => expense.date.year == year);
  }

  /// Získá statistiky rozpočtu
  Map<String, dynamic> getBudgetStatistics() {
    return {
      'totalExpenses': itemCount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'unpaidAmount': unpaidAmount,
      'paidExpenses': getPaidExpenses().length,
      'unpaidExpenses': getUnpaidExpenses().length,
      'categories': categories.length,
      'lastModified': lastSyncTimestamp,
    };
  }

  /// Získá souhrn podle kategorií
  Map<String, double> getCategorySummary() {
    final summary = <String, double>{};
    for (final category in categories) {
      summary[category] = getAmountByCategory(category);
    }
    return summary;
  }

  /// Seřadí výdaje podle částky
  List<Expense> get expensesSortedByAmount {
    final sorted = List<Expense>.from(expenses);
    sorted.sort((a, b) => b.amount.compareTo(a.amount));
    return sorted;
  }

  /// Najde výdaje v danĂ©m rozmezí částek
  List<Expense> findExpensesInAmountRange(double minAmount, double maxAmount) {
    return findItems((expense) =>
        expense.amount >= minAmount && expense.amount <= maxAmount);
  }

  /// Získá průměrnou částku výdajů
  double get averageAmount {
    if (expenses.isEmpty) return 0.0;
    return totalAmount / expenses.length;
  }

  /// Oznáčí vĹˇechny výdaje jako zaplacenĂ©
  void markAllAsPaid() {
    for (var i = 0; i < expenses.length; i++) {
      if (!expenses[i].isPaid) {
        updateItemAt(i, expenses[i].copyWith(isPaid: true));
      }
    }
  }

  /// Vytvoří nový výdaj
  static Expense createExpense({
    required String title,
    required double amount,
    required String category,
    String? note,
    bool isPaid = false,
    DateTime? date,
  }) {
    return Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      category: category,
      note: note ?? '',
      isPaid: isPaid,
      date: date ?? DateTime.now(),
    );
  }
}
