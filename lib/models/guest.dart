// lib/models/guest.dart

import 'package:equatable/equatable.dart';

/// Model reprezentující hosta svatby
class Guest extends Equatable {
  final String id;
  final String name;
  final String group;
  final String? contact;
  final String gender;
  final String table;
  final String attendance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Guest({
    required this.id,
    required this.name,
    required this.group,
    this.contact,
    required this.gender,
    this.table = 'Nepřiřazen',
    this.attendance = 'Neodpovězeno',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? const DateTime.now(),
       updatedAt = updatedAt ?? const DateTime.now();

  /// Vytvoří instanci Guest z JSON
  factory Guest.fromJson(Map<String, dynamic> json) {
    return Guest(
      id: json['id'] as String,
      name: json['name'] as String,
      group: json['group'] as String,
      contact: json['contact'] as String?,
      gender: json['gender'] as String? ?? 'Muž',
      table: json['table'] as String? ?? 'Nepřiřazen',
      attendance: json['attendance'] as String? ?? 'Neodpovězeno',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String) 
          : DateTime.now(),
    );
  }

  /// Převede Guest na JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'group': group,
      'contact': contact,
      'gender': gender,
      'table': table,
      'attendance': attendance,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Vytvoří kopii s upravenými hodnotami
  Guest copyWith({
    String? id,
    String? name,
    String? group,
    String? contact,
    String? gender,
    String? table,
    String? attendance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Guest(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      contact: contact ?? this.contact,
      gender: gender ?? this.gender,
      table: table ?? this.table,
      attendance: attendance ?? this.attendance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id, 
    name, 
    group, 
    contact, 
    gender, 
    table, 
    attendance,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() {
    return 'Guest(id: $id, name: $name, group: $group, gender: $gender, table: $table, attendance: $attendance)';
  }
}