// lib/models/expense.dart

import 'dart:convert';

/// Třída reprezentující výdaj ve vaší aplikaci.
class Expense {
  /// Unikátní identifikátor výdaje.
  final String id;

  /// Název nebo popis výdaje.
  final String title;

  /// Kategorie výdaje (např. "jídlo", "ubytování", "doplňky").
  final String category;

  /// Částka, která byla zaplacena.
  final double paid;

  /// Částka, která ještě nebyla vyřízena či je očekávaná.
  final double pending;

  /// Datum výdaje nebo datum vytvoření záznamu.
  final DateTime date;

  /// Primární konstruktor s povinnými parametry.
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.paid,
    required this.pending,
    required this.date,
  });

  /// Vytvoří instanci [Expense] z JSON mapy.
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      paid: (json['paid'] as num).toDouble(),
      pending: (json['pending'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }

  /// Vrací instanci [Expense] jako JSON mapu.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'paid': paid,
      'pending': pending,
      'date': date.toIso8601String(),
    };
  }

  /// Umožňuje vytvoření nové instance s možností přepsat vybrané hodnoty.
  Expense copyWith({
    String? id,
    String? title,
    String? category,
    double? paid,
    double? pending,
    DateTime? date,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      paid: paid ?? this.paid,
      pending: pending ?? this.pending,
      date: date ?? this.date,
    );
  }

  /// Přepis operátoru rovnosti pro správné porovnání instancí.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense &&
        other.id == id &&
        other.title == title &&
        other.category == category &&
        other.paid == paid &&
        other.pending == pending &&
        other.date == date;
  }

  /// Přepis hashCode pro správné porovnání instancí.
  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        category.hashCode ^
        paid.hashCode ^
        pending.hashCode ^
        date.hashCode;
  }

  /// Vrací textovou reprezentaci instance (užitečné při ladění).
  @override
  String toString() {
    return 'Expense(id: $id, title: $title, category: $category, paid: $paid, pending: $pending, date: $date)';
  }

  /// Volitelná metoda pro formátování částky s měnou.
  String formatAmount(double amount, {String currency = 'Kč'}) {
    // Jednoduché formátování – případně můžete použít balíček intl pro pokročilejší formátování.
    return '$amount $currency';
  }
}
