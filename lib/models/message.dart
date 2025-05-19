import 'package:intl/intl.dart';
import 'package:equatable/equatable.dart';

/// Model představující zprávu v aplikaci.
class Message extends Equatable {
  /// Unikátní identifikátor zprávy.
  final String id;

  /// Identifikátor konverzace, ke které zpráva patří.
  final String conversationId;

  /// Identifikátor odesílatele zprávy.
  final String senderId;

  /// Obsah zprávy.
  final String content;

  /// Časové razítko, kdy byla zpráva odeslána.
  final DateTime timestamp;

  /// Indikátor, zda byla zpráva přečtena.
  final bool isRead;

  /// Primární konstruktor.
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  /// Vytvoří instanci [Message] z JSON mapy.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Převádí instanci [Message] do JSON mapy.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  /// Vytvoří novou instanci [Message] s možností přepsat některé hodnoty.
  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Vlastnosti pro porovnávání objektů pomocí Equatable.
  @override
  List<Object?> get props => [id, conversationId, senderId, content, timestamp, isRead];

  @override
  String toString() {
    return 'Message(id: $id, conversationId: $conversationId, senderId: $senderId, '
           'content: $content, timestamp: $timestamp, isRead: $isRead)';
  }

  /// Vrací formátované časové razítko zprávy.
  /// Výchozí vzor je 'HH:mm, dd.MM.yyyy'.
  String formatTimestamp({String pattern = 'HH:mm, dd.MM.yyyy'}) {
    return DateFormat(pattern).format(timestamp);
  }

  /// Metoda, která určuje, zda zpráva pochází od aktuálního uživatele.
  /// Předáte aktuální uživatelské ID a porovná se s ID odesílatele.
  bool isSentBy(String currentUserId) {
    return senderId == currentUserId;
  }

  /// Statická proměnná, do které by se mělo uložit aktuální uživatelské ID.
  /// Například při přihlášení uživatele.
  static String? currentUserId;

  /// Getter, který vrací true, pokud zpráva pochází od aktuálního uživatele.
  bool get isSentByCurrentUser => currentUserId != null && senderId == currentUserId;
}
