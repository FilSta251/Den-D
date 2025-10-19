/// lib/models/guest.dart
library;

import 'package:equatable/equatable.dart';
import 'package:easy_localization/easy_localization.dart';

/// Konstanty pro hodnoty v databázi - NEMĚNIT!
class GuestConstants {
  // Pohlaví
  static const String genderMale = 'male';
  static const String genderFemale = 'female';
  static const String genderOther = 'other';

  // Účast
  static const String attendanceConfirmed = 'confirmed';
  static const String attendanceDeclined = 'declined';
  static const String attendancePending = 'pending';

  // Stůl
  static const String unassignedTable = 'unassigned';
}

/// Model reprezentující hosta svatby
class Guest extends Equatable {
  final String id;
  final String name;
  final String group;
  final String? contact;
  final String gender; // UKLÁDÁ SE: 'male', 'female', 'other'
  final String table; // UKLÁDÁ SE: 'unassigned' nebo název stolu
  final String attendance; // UKLÁDÁ SE: 'confirmed', 'declined', 'pending'
  final DateTime createdAt;
  final DateTime updatedAt;

  Guest({
    required this.id,
    required this.name,
    required this.group,
    this.contact,
    required this.gender,
    this.table = GuestConstants.unassignedTable,
    this.attendance = GuestConstants.attendancePending,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// HELPER: Zobrazitelný text pro pohlaví (přeložený)
  String get genderDisplay {
    switch (gender) {
      case GuestConstants.genderMale:
        return 'guest.gender_male'.tr();
      case GuestConstants.genderFemale:
        return 'guest.gender_female'.tr();
      case GuestConstants.genderOther:
        return 'guest.gender_other'.tr();
      default:
        return gender;
    }
  }

  /// HELPER: Zobrazitelný text pro účast (přeložený)
  String get attendanceDisplay {
    switch (attendance) {
      case GuestConstants.attendanceConfirmed:
        return 'guest.attendance_confirmed'.tr();
      case GuestConstants.attendanceDeclined:
        return 'guest.attendance_declined'.tr();
      case GuestConstants.attendancePending:
        return 'guest.attendance_pending'.tr();
      default:
        return attendance;
    }
  }

  /// HELPER: Zobrazitelný text pro stůl (přeložený)
  String get tableDisplay {
    return table == GuestConstants.unassignedTable
        ? 'guest.unassigned_table'.tr()
        : table;
  }

  /// Vytvoří instanci Guest z JSON - S AUTOMATICKOU MIGRACÍ
  factory Guest.fromJson(Map<String, dynamic> json) {
    // Pomocná funkce pro migraci pohlaví
    String migrateGender(String? value) {
      if (value == null) return GuestConstants.genderMale;

      switch (value) {
        case 'Muž':
          return GuestConstants.genderMale;
        case 'Žena':
          return GuestConstants.genderFemale;
        case 'Jiné':
          return GuestConstants.genderOther;
        case GuestConstants.genderMale:
        case GuestConstants.genderFemale:
        case GuestConstants.genderOther:
          return value;
        default:
          return GuestConstants.genderMale;
      }
    }

    // Pomocná funkce pro migraci účasti
    String migrateAttendance(String? value) {
      if (value == null) return GuestConstants.attendancePending;

      switch (value) {
        case 'Potvrzená':
          return GuestConstants.attendanceConfirmed;
        case 'Neutvrzená':
          return GuestConstants.attendanceDeclined;
        case 'Neodpovězeno':
          return GuestConstants.attendancePending;
        case GuestConstants.attendanceConfirmed:
        case GuestConstants.attendanceDeclined:
        case GuestConstants.attendancePending:
          return value;
        default:
          return GuestConstants.attendancePending;
      }
    }

    // Pomocná funkce pro migraci stolu
    String migrateTable(String? value) {
      if (value == null) return GuestConstants.unassignedTable;
      if (value == 'Nepřiřazen') return GuestConstants.unassignedTable;
      return value;
    }

    return Guest(
      id: json['id'] as String,
      name: json['name'] as String,
      group: json['group'] as String,
      contact: json['contact'] as String?,
      gender: migrateGender(json['gender'] as String?),
      table: migrateTable(json['table'] as String?),
      attendance: migrateAttendance(json['attendance'] as String?),
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
