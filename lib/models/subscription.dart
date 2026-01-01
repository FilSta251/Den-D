/// lib/models/subscription.dart
library;

import 'package:easy_localization/easy_localization.dart';

enum SubscriptionTier { free, premium }

String subscriptionTierToString(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.free:
      return 'free';
    case SubscriptionTier.premium:
      return 'premium';
  }
}

SubscriptionTier subscriptionTierFromString(String value) {
  switch (value) {
    case 'premium':
      return SubscriptionTier.premium;
    default:
      return SubscriptionTier.free;
  }
}

/// Model představující předplatnĂ© v aplikaci.
///
/// Obsahuje údaje pro správu předplatnĂ©ho:
///  - tier: free nebo premium
///  - expiresAt: datum vyprĹˇení (null pro free)
///  - productId: ID produktu z obchodu
///  - purchaseToken: token z Google Play/App Store
///  - autoRenewing: zda se automaticky obnovuje
class Subscription {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final String? productId;
  final String? purchaseToken;
  final bool autoRenewing;

  const Subscription({
    required this.id,
    required this.userId,
    this.tier = SubscriptionTier.free,
    this.expiresAt,
    this.productId,
    this.purchaseToken,
    this.autoRenewing = false,
  });

  /// Bezpečná konverze z JSON
  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      tier: subscriptionTierFromString(json['tier'] ?? 'free'),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      productId: json['productId'] as String?,
      purchaseToken: json['purchaseToken'] as String?,
      autoRenewing: _safeBoolConversion(json['autoRenewing']) ?? false,
    );
  }

  /// Bezpečná konverze na bool - řeĹˇí problĂ©m s int/bool castu
  static bool? _safeBoolConversion(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lowerValue = value.toLowerCase();
      if (lowerValue == 'true' || lowerValue == '1') return true;
      if (lowerValue == 'false' || lowerValue == '0') return false;
    }
    return null;
  }

  /// Konverze do JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tier': subscriptionTierToString(tier),
      'expiresAt': expiresAt?.toIso8601String(),
      'productId': productId,
      'purchaseToken': purchaseToken,
      'autoRenewing': autoRenewing,
    };
  }

  /// Kopie s moťností změny hodnot
  Subscription copyWith({
    String? id,
    String? userId,
    SubscriptionTier? tier,
    DateTime? expiresAt,
    String? productId,
    String? purchaseToken,
    bool? autoRenewing,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tier: tier ?? this.tier,
      expiresAt: expiresAt ?? this.expiresAt,
      productId: productId ?? this.productId,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      autoRenewing: autoRenewing ?? this.autoRenewing,
    );
  }

  /// Getter pro zpětnou kompatibilitu - zda je předplatnĂ© aktivní
  bool get isActive =>
      tier != SubscriptionTier.free &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  /// Getter - zda je aktivní Premium předplatnĂ©
  bool get isActivePremium {
    if (tier != SubscriptionTier.premium) return false;
    if (expiresAt == null) return false;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// Kolik dní zbývá do expirace
  int get daysLeft {
    if (tier == SubscriptionTier.free) return 0;
    if (expiresAt == null) return 0;
    final diffDays = expiresAt!.difference(DateTime.now()).inDays;
    return diffDays > 0 ? diffDays : 0;
  }

  /// Vrací textový popis typu předplatnĂ©ho pro UI
  String get tierText {
    switch (tier) {
      case SubscriptionTier.free:
        return tr('subs.tier.free'); // 'Zdarma'
      case SubscriptionTier.premium:
        return tr('subs.tier.premium'); // 'Premium'
    }
  }

  /// Vrací status předplatnĂ©ho pro UI
  String get statusText {
    if (tier == SubscriptionTier.free) {
      return tr('subs.status.free'); // 'Free verze'
    }

    if (!isActivePremium) {
      return tr('subs.status.expired'); // 'VyprĹˇelo'
    }

    if (autoRenewing) {
      return tr('subs.status.active_auto'); // 'Aktivní (automatická obnova)'
    }

    return tr('subs.status.active'); // 'Aktivní'
  }

  /// Vrací informaci o expiraci pro UI
  String get expirationInfo {
    if (tier == SubscriptionTier.free) {
      return tr('subs.expiration.unlimited'); // 'NeomezenĂ©'
    }

    if (expiresAt == null) {
      return tr('subs.expiration.unknown'); // 'NeznámĂ©'
    }

    final days = daysLeft;
    if (days == 0) {
      return tr('subs.expiration.expired'); // 'VyprĹˇelo'
    } else if (days == 1) {
      return tr('subs.expiration.one_day'); // 'VyprĹˇí za 1 den'
    } else {
      return tr('subs.expiration.days')
          .replaceAll('{days}', days.toString()); // 'VyprĹˇí za {days} dní'
    }
  }
}
