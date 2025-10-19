/// lib/models/table_arrangement.dart
library;

import 'package:equatable/equatable.dart';

/// Model reprezentující stůl na svatbě
class TableArrangement extends Equatable {
  final String id;
  final String name;
  final int maxCapacity;
  final DateTime createdAt;
  final DateTime updatedAt;

  TableArrangement({
    required this.id,
    required this.name,
    required this.maxCapacity,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Vytvoří instanci TableArrangement z JSON
  factory TableArrangement.fromJson(Map<String, dynamic> json) {
    return TableArrangement(
      id: json['id'] as String,
      name: json['name'] as String,
      maxCapacity: json['maxCapacity'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Převede TableArrangement na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'maxCapacity': maxCapacity,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Vytvoří kopii s upravenými hodnotami
  TableArrangement copyWith({
    String? id,
    String? name,
    int? maxCapacity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TableArrangement(
      id: id ?? this.id,
      name: name ?? this.name,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, name, maxCapacity, createdAt, updatedAt];

  @override
  String toString() =>
      'TableArrangement(id: $id, name: $name, maxCapacity: $maxCapacity)';
}
