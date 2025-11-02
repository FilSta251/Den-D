/// lib/models/payment.dart
library;

/// Model pro platební záznamy.
class Payment {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final DateTime transactionDate;
  final String status; // "success", "pending", "failed"
  final String
      paymentMethod; // "card", "bank_transfer", "apple_pay", "google_pay"
  final String? subscriptionId;
  final Map<String, dynamic>? metadata;

  Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    required this.status,
    required this.paymentMethod,
    this.subscriptionId,
    this.metadata,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      transactionDate: DateTime.parse(json['transactionDate'] as String),
      status: json['status'] as String,
      paymentMethod: json['paymentMethod'] as String,
      subscriptionId: json['subscriptionId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'currency': currency,
      'transactionDate': transactionDate.toIso8601String(),
      'status': status,
      'paymentMethod': paymentMethod,
      'subscriptionId': subscriptionId,
      'metadata': metadata,
    };
  }

  Payment copyWith({
    String? id,
    String? userId,
    double? amount,
    String? currency,
    DateTime? transactionDate,
    String? status,
    String? paymentMethod,
    String? subscriptionId,
    Map<String, dynamic>? metadata,
  }) {
    return Payment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'Payment{id: $id, userId: $userId, amount: $amount, currency: $currency, '
        'transactionDate: $transactionDate, status: $status, '
        'paymentMethod: $paymentMethod, subscriptionId: $subscriptionId}';
  }
}
