import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../models/message.dart';

/// MessageRepository poskytuje metody pro správu zpráv v rámci konverzace.
/// - Náčítá zprávy s real-time synchronizací pomocí Firestore snapshot listeneru.
/// - UmoťĹuje odeslání, aktualizaci a smazání zpráv.
/// - Podporuje lazy loading/paginaci zpráv.
/// - Uchovává lokální cache a poskytuje stream pro reaktivní aktualizace v UI.
class MessageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  /// Identifikátor konverzace, pro kterou se zprávy náčítají.
  final String conversationId;

  // Lokální cache náčtených zpráv.
  List<Message> _cachedMessages = [];

  // StreamController pro vysílání aktuálního seznamu zpráv.
  final StreamController<List<Message>> _messagesStreamController =
      StreamController<List<Message>>.broadcast();

  /// Exponovaný stream pro předplatitele (např. UI) k zobrazení zpráv.
  Stream<List<Message>> get messageStream => _messagesStreamController.stream;

  /// Konstruktor vyťadující parametr conversationId.
  MessageRepository({required this.conversationId}) {
    _initializeListener();
  }

  /// Nastaví real-time poslucháče změn v kolekci 'messages' pro danou konverzaci.
  void _initializeListener() {
    try {
      _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen((snapshot) {
        _cachedMessages = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Message.fromJson(data);
        }).toList();
        _messagesStreamController.add(_cachedMessages);
      }, onError: (error) {
        print('Error listening to messages: $error');
      });
    } catch (e) {
      print('Exception in _initializeListener: $e');
    }
  }

  /// Náčte zprávy pro danou konverzaci s podporou paginace.
  /// [limit] určuje počet zpráv náčtených najednou.
  /// [lastDoc] umoťĹuje náčíst dalĹˇí stránku zpráv, pokud jiť existuje.
  Future<List<Message>> fetchMessages(
      {int limit = 20, DocumentSnapshot? lastDoc}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: false)
          .limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snapshot = await query.get();
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Message.fromJson(data);
      }).toList();

      if (lastDoc == null) {
        // Pokud náčítáme první stránku, aktualizujeme celou cache.
        _cachedMessages = messages;
      } else {
        _cachedMessages.addAll(messages);
      }
      _messagesStreamController.add(_cachedMessages);
      return messages;
    } catch (e, stackTrace) {
      print('Error fetching messages: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Odesílá zprávu s obsahem [content] do Firestore.
  /// Vrací Future, kterĂ© signalizuje úspěĹˇnĂ© odeslání zprávy.
  Future<void> sendMessage(String content) async {
    final fb.User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Uťivatel není přihláĹˇen.');
    }
    if (content.trim().isEmpty) {
      throw Exception('Zpráva nesmí být prázdná.');
    }
    try {
      final Map<String, dynamic> messageData = {
        'conversationId': conversationId,
        'senderId': currentUser.uid,
        'content': content.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('messages').add(messageData);
      // Firestore aktualizuje stream díky snapshot listeneru.
    } catch (e, stackTrace) {
      print('Error sending message: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Aktualizuje zprávu s ID [messageId] s danými změnami.
  Future<void> updateMessage(
      String messageId, Map<String, dynamic> changes) async {
    try {
      await _firestore.collection('messages').doc(messageId).update(changes);
    } catch (e, stackTrace) {
      print('Error updating message: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Maťe zprávu s ID [messageId].
  Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('messages').doc(messageId).delete();
    } catch (e, stackTrace) {
      print('Error deleting message: $e');
      print(stackTrace);
      rethrow;
    }
  }

  /// Vrací filtrovaný seznam zpráv na základě zadanĂ©ho dotazu.
  List<Message> getFilteredMessages({String? query}) {
    if (query == null || query.trim().isEmpty) return _cachedMessages;
    return _cachedMessages
        .where((message) =>
            message.content.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
  }

  /// Zavře stream controller.
  void dispose() {
    _messagesStreamController.close();
  }
}
