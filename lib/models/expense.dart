/// lib/models/expense.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Třída reprezentující výdaj ve vaĹˇí aplikaci.
class Expense {
  /// Unikátní identifikátor výdaje.
  final String id;

  /// Název nebo popis výdaje.
  final String title;

  /// Kategorie výdaje (např. "jídlo", "ubytování", "doplĹky").
  final String category;

  /// Celková částka výdaje
  final double amount;

  /// Poznámka k výdaji
  final String note;

  /// Zda je výdaj zaplacen
  final bool isPaid;

  /// Datum výdaje nebo datum vytvoření záznamu.
  final DateTime date;

  /// ďŚas vytvoření záznamu
  final DateTime createdAt;

  /// ďŚas poslední aktualizace
  final DateTime? updatedAt;

  /// Primární konstruktor s povinnými parametry.
  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.note = '',
    this.isPaid = false,
    required this.date,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? date;

  /// Pro zpětnou kompatibilitu - vypočítanĂ© vlastnosti
  double get paid => isPaid ? amount : 0.0;
  double get pending => isPaid ? 0.0 : amount;

  /// Vytvoří instanci [Expense] z JSON mapy.
  factory Expense.fromJson(Map<String, dynamic> json) {
    // Zpětná kompatibilita - pokud máme paid/pending, převedeme na amount/isPaid
    if (json.containsKey('paid') && json.containsKey('pending')) {
      final paidAmount = (json['paid'] as num).toDouble();
      final pendingAmount = (json['pending'] as num).toDouble();

      return Expense(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        amount: paidAmount + pendingAmount,
        note: json['note'] as String? ?? '',
        isPaid: pendingAmount == 0,
        date: DateTime.parse(json['date'] as String),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
    }

    // Nový formát
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      isPaid: json['isPaid'] as bool? ?? false,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Vytvoří instanci z Firestore dokumentu
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Zpětná kompatibilita
    if (data.containsKey('paid') && data.containsKey('pending')) {
      final paidAmount = (data['paid'] as num).toDouble();
      final pendingAmount = (data['pending'] as num).toDouble();

      return Expense(
        id: doc.id,
        title: data['title'] as String,
        category: data['category'] as String,
        amount: paidAmount + pendingAmount,
        note: data['note'] as String? ?? '',
        isPaid: pendingAmount == 0,
        date: _parseFirestoreDate(data['date']),
        createdAt: data['createdAt'] != null
            ? _parseFirestoreDate(data['createdAt'])
            : null,
        updatedAt: data['updatedAt'] != null
            ? _parseFirestoreDate(data['updatedAt'])
            : null,
      );
    }

    return Expense(
      id: doc.id,
      title: data['title'] as String,
      category: data['category'] as String,
      amount: (data['amount'] as num).toDouble(),
      note: data['note'] as String? ?? '',
      isPaid: data['isPaid'] as bool? ?? false,
      date: _parseFirestoreDate(data['date']),
      createdAt: data['createdAt'] != null
          ? _parseFirestoreDate(data['createdAt'])
          : null,
      updatedAt: data['updatedAt'] != null
          ? _parseFirestoreDate(data['updatedAt'])
          : null,
    );
  }

  /// Vrací instanci [Expense] jako JSON mapu.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'note': note,
      'isPaid': isPaid,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      // Pro zpětnou kompatibilitu
      'paid': paid,
      'pending': pending,
    };
  }

  /// Převede na Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'category': category,
      'amount': amount,
      'note': note,
      'isPaid': isPaid,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      // Pro zpětnou kompatibilitu
      'paid': paid,
      'pending': pending,
    };
  }

  /// UmoťĹuje vytvoření novĂ© instance s moťností přepsat vybranĂ© hodnoty.
  Expense copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    String? note,
    bool? isPaid,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Helper pro parsování Firestore data
  static DateTime _parseFirestoreDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  /// Přepis operátoru rovnosti pro správnĂ© porovnání instancí.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense &&
        other.id == id &&
        other.title == title &&
        other.category == category &&
        other.amount == amount &&
        other.isPaid == isPaid &&
        other.date == date;
  }

  /// Přepis hashCode pro správnĂ© porovnání instancí.
  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        category.hashCode ^
        amount.hashCode ^
        isPaid.hashCode ^
        date.hashCode;
  }

  /// Vrací textovou reprezentaci instance (uťitečnĂ© při ladění).
  @override
  String toString() {
    return 'Expense(id: $id, title: $title, category: $category, amount: $amount, isPaid: $isPaid, date: $date)';
  }

  /// Volitelná metoda pro formátování částky s měnou.
  String formatAmount({String currency = 'Kč'}) {
    // JednoduchĂ© formátování "“ případně můťete pouťít balíček intl pro pokročilejĹˇí formátování.
    return '${amount.toStringAsFixed(2)} $currency';
  }
}
