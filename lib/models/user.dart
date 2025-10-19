/// lib/models/user.dart
library;

import 'dart:convert';

/// Třída reprezentující uťivatele s pokročilými funkcemi a optimalizovanou strukturou.
class User {
  /// Unikátní identifikátor uťivatele.
  final String id;

  /// JmĂ©no uťivatele.
  final String name;

  /// Email uťivatele.
  final String email;

  /// URL profilovĂ©ho obrázku.
  final String profilePictureUrl;

  /// Datum svatby (volitelně).
  final DateTime? weddingDate;

  /// Role uťivatele (např. svatebčan, pomocník apod.).
  final String? role;

  /// Místo svatby (volitelně).
  final String? weddingVenue;

  /// Rozpočet pro svatbu (volitelně).
  final double? budget;

  /// Primární konstruktor.
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.profilePictureUrl = '',
    this.weddingDate,
    this.role,
    this.weddingVenue,
    this.budget,
  });

  /// Vytvoří instanci uťivatele ze struktury JSON.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profilePictureUrl: json['profilePictureUrl'] as String? ?? '',
      weddingDate: json['weddingDate'] != null
          ? DateTime.tryParse(json['weddingDate'] as String)
          : null,
      role: json['role'] as String?,
      weddingVenue: json['weddingVenue'] as String?,
      budget:
          json['budget'] != null ? (json['budget'] as num).toDouble() : null,
    );
  }

  /// Vrací instanci uťivatele jako JSON mapu.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profilePictureUrl': profilePictureUrl,
      'weddingDate': weddingDate?.toIso8601String(),
      'role': role,
      'weddingVenue': weddingVenue,
      'budget': budget,
    };
  }

  /// Vytvoří novou instanci s moťností přepsat některĂ© hodnoty.
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? profilePictureUrl,
    DateTime? weddingDate,
    String? role,
    String? weddingVenue,
    double? budget,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      weddingDate: weddingDate ?? this.weddingDate,
      role: role ?? this.role,
      weddingVenue: weddingVenue ?? this.weddingVenue,
      budget: budget ?? this.budget,
    );
  }

  /// PřepíĹˇe operátor rovnosti pro správnĂ© porovnání instancí.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is User &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.profilePictureUrl == profilePictureUrl &&
        other.weddingDate == weddingDate &&
        other.role == role &&
        other.weddingVenue == weddingVenue &&
        other.budget == budget;
  }

  /// PřepíĹˇe hashCode pro správnĂ© porovnávání instancí.
  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        profilePictureUrl.hashCode ^
        weddingDate.hashCode ^
        role.hashCode ^
        weddingVenue.hashCode ^
        budget.hashCode;
  }

  /// Vrací textovou reprezentaci instance (uťitečnĂ© pro debugování).
  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, profilePictureUrl: $profilePictureUrl, '
        'weddingDate: $weddingDate, role: $role, weddingVenue: $weddingVenue, budget: $budget)';
  }
}
