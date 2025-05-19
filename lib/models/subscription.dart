// lib/models/subscription.dart

enum SubscriptionType {
  free,
  monthly,
  yearly,
  // Můžete přidat i weekly, lifetime, apod.
}

String subscriptionTypeToString(SubscriptionType type) {
  switch (type) {
    case SubscriptionType.free:
      return 'free';
    case SubscriptionType.monthly:
      return 'monthly';
    case SubscriptionType.yearly:
      return 'yearly';
  }
}

SubscriptionType subscriptionTypeFromString(String value) {
  switch (value) {
    case 'monthly':
      return SubscriptionType.monthly;
    case 'yearly':
      return SubscriptionType.yearly;
    default:
      return SubscriptionType.free;
  }
}

/// Model představující předplatné v aplikaci.
///
/// Obsahuje i údaje typu:
///  - gracePeriodDays – kolik dnů "milosti" po vypršení.
///  - isTrial pro zkušební verzi.
///  - isAutoRenewal pro automatické obnovení.
///
/// daysLeft a isStillValid pak poskytují užitečné getter funkce pro
/// zjištění stavu předplatného (např. pro UI).
class Subscription {
  final String id;
  final String userId;
  final bool isActive;
  final SubscriptionType subscriptionType;

  /// Datum, kdy předplatné vyprší (nebo null pro free).
  final DateTime? expirationDate;

  /// Kdy bylo naposledy obnoveno (volitelné).
  final DateTime? lastRenewalDate;

  /// Cena (např. 800.0) a měna (CZK, EUR...).
  final double? price;
  final String? currency;

  /// Zda se předplatné samo obnovuje (auto-renew).
  final bool isAutoRenewal;

  /// Zda je předplatné v trial režimu.
  final bool isTrial;

  /// Počet dní, kdy i po vypršení dáváme "čas milosti" (tzv. grace period).
  final int gracePeriodDays;

  const Subscription({
    required this.id,
    required this.userId,
    required this.isActive,
    required this.subscriptionType,
    this.expirationDate,
    this.lastRenewalDate,
    this.price,
    this.currency,
    this.isAutoRenewal = false,
    this.isTrial = false,
    this.gracePeriodDays = 0,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['userId'] as String,
      isActive: json['isActive'] as bool,
      subscriptionType: subscriptionTypeFromString(json['subscriptionType'] ?? 'free'),
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'] as String)
          : null,
      lastRenewalDate: json['lastRenewalDate'] != null
          ? DateTime.tryParse(json['lastRenewalDate'] as String)
          : null,
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      isAutoRenewal: json['isAutoRenewal'] as bool? ?? false,
      isTrial: json['isTrial'] as bool? ?? false,
      gracePeriodDays: json['gracePeriodDays'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'isActive': isActive,
      'subscriptionType': subscriptionTypeToString(subscriptionType),
      'expirationDate': expirationDate?.toIso8601String(),
      'lastRenewalDate': lastRenewalDate?.toIso8601String(),
      'price': price,
      'currency': currency,
      'isAutoRenewal': isAutoRenewal,
      'isTrial': isTrial,
      'gracePeriodDays': gracePeriodDays,
    };
  }

  Subscription copyWith({
    String? id,
    String? userId,
    bool? isActive,
    SubscriptionType? subscriptionType,
    DateTime? expirationDate,
    DateTime? lastRenewalDate,
    double? price,
    String? currency,
    bool? isAutoRenewal,
    bool? isTrial,
    int? gracePeriodDays,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      expirationDate: expirationDate ?? this.expirationDate,
      lastRenewalDate: lastRenewalDate ?? this.lastRenewalDate,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isAutoRenewal: isAutoRenewal ?? this.isAutoRenewal,
      isTrial: isTrial ?? this.isTrial,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
    );
  }

  /// Kolik dní zbývá do expirace (včetně grace period).
  /// Pokud je předplatné neaktivní (isActive=false), může vracet 0 nebo zápornou hodnotu.
  int get daysLeft {
    if (!isActive) return 0;
    if (expirationDate == null) return 9999; // free => neomezeně
    final extended = expirationDate!.add(Duration(days: gracePeriodDays));
    final diffDays = extended.difference(DateTime.now()).inDays;
    return diffDays;
  }

  /// Zda je subscription stále platné (i v rámci grace period).
  bool get isStillValid {
    if (!isActive) return false;
    if (expirationDate == null) return true; // free = neomezené
    final extended = expirationDate!.add(Duration(days: gracePeriodDays));
    return DateTime.now().isBefore(extended);
  }
}
