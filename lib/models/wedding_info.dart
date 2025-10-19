import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

/// [WeddingInfo] představuje komplexní informace o svatbě.
/// Tato třída vyuťívá [Equatable] pro správnĂ© porovnávání instancí,
/// coť je uťitečnĂ© při práci s reaktivním stavem (např. s Providerem).
class WeddingInfo extends Equatable {
  /// Jedinečný identifikátor uťivatele, ke kterĂ©mu se tato svatba váťe.
  final String userId;

  /// Datum a čas svatby.
  final DateTime weddingDate;

  /// JmĂ©no uťivatele.
  final String yourName;

  /// JmĂ©no partnera.
  final String partnerName;

  /// Místo konání svatby.
  final String weddingVenue;

  /// Finanční rozpočet na svatbu.
  final double budget;

  /// VolitelnĂ© poznámky nebo doplĹující informace.
  final String notes;

  /// Konstruktor zajiĹˇšující neměnitelnost instance.
  const WeddingInfo({
    required this.userId,
    required this.weddingDate,
    required this.yourName,
    required this.partnerName,
    required this.weddingVenue,
    required this.budget,
    this.notes = '--',
  });

  /// Factory konstruktor, který vytvoří instanci [WeddingInfo] z JSON mapy.
  /// Nejprve se pokusí o parsování data pomocí [DateTime.parse].
  /// Pokud to selťe, pouťije alternativní formát "yyyy-MM-dd" pomocí [parseStrict].
  /// V případě neúspěchu pouťije [DateTime.now()] jako fallback.
  factory WeddingInfo.fromJson(Map<String, dynamic> json) {
    final String dateRaw = json['weddingDate'] as String? ?? '';
    late final DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(dateRaw);
    } catch (_) {
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parseStrict(dateRaw);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    }
    return WeddingInfo(
      userId: json['userId'] as String? ?? '--',
      weddingDate: parsedDate,
      yourName: json['yourName'] as String? ?? '--',
      partnerName: json['partnerName'] as String? ?? '--',
      weddingVenue: json['weddingVenue'] as String? ?? '--',
      budget:
          (json['budget'] is num) ? (json['budget'] as num).toDouble() : 0.0,
      notes: json['notes'] as String? ?? '--',
    );
  }

  /// Převede tuto instanci na JSON mapu.
  /// Tuto metodu lze vyuťít k odeslání dat do backendu nebo pro lokální úloťiĹˇtě.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'weddingDate': weddingDate.toIso8601String(),
      'yourName': yourName,
      'partnerName': partnerName,
      'weddingVenue': weddingVenue,
      'budget': budget,
      'notes': notes,
    };
  }

  /// UmoťĹuje vytvořit novou instanci [WeddingInfo] s aktualizovanými hodnotami.
  /// Ideální pro úpravu a aktualizaci dat.
  WeddingInfo copyWith({
    String? userId,
    DateTime? weddingDate,
    String? yourName,
    String? partnerName,
    String? weddingVenue,
    double? budget,
    String? notes,
  }) {
    return WeddingInfo(
      userId: userId ?? this.userId,
      weddingDate: weddingDate ?? this.weddingDate,
      yourName: yourName ?? this.yourName,
      partnerName: partnerName ?? this.partnerName,
      weddingVenue: weddingVenue ?? this.weddingVenue,
      budget: budget ?? this.budget,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        weddingDate,
        yourName,
        partnerName,
        weddingVenue,
        budget,
        notes,
      ];

  @override
  String toString() {
    return 'WeddingInfo('
        'userId: $userId, '
        'weddingDate: ${weddingDate.toIso8601String()}, '
        'yourName: $yourName, '
        'partnerName: $partnerName, '
        'weddingVenue: $weddingVenue, '
        'budget: $budget, '
        'notes: $notes'
        ')';
  }

  /// Naformátuje datum svatby podle zadanĂ©ho vzoru.
  /// Výchozí vzor je "yyyy-MM-dd", ale lze zadat libovolný formát podporovaný knihovnou [intl].
  String formatWeddingDate({String pattern = 'yyyy-MM-dd'}) {
    return DateFormat(pattern).format(weddingDate);
  }

  /// Naformátuje rozpočet jako měnovou částku.
  /// Výchozí locale je 'en_US' a symbol je prázdný, takťe se zobrazí pouze číslo.
  String formatBudget({String locale = 'en_US'}) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: locale,
      symbol: '',
    );
    return formatter.format(budget);
  }
}
