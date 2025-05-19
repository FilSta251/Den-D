import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/payment.dart';

/// PaymentRepository zajišťuje správu platebních záznamů z Firestore.
/// Poskytuje CRUD operace, real-time synchronizaci, lokální cachování
/// a metody pro filtrování platebních záznamů.
class PaymentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference<Map<String, dynamic>> _paymentsCollection =
      _firestore.collection('payments');

  // Lokální cache seznamu plateb.
  List<Payment> _cachedPayments = [];

  // Stream controller pro vysílání aktuálního seznamu plateb.
  final StreamController<List<Payment>> _paymentsStreamController =
      StreamController<List<Payment>>.broadcast();

  // Firestore subscription pro real-time aktualizace.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  /// Stream, který vysílá aktuální seznam plateb v reálném čase.
  Stream<List<Payment>> get paymentsStream => _paymentsStreamController.stream;

  PaymentRepository() {
    _initializeListener();
  }

  /// Nastaví real-time posluchače změn v kolekci 'payments' na Firestore.
  void _initializeListener() {
    _subscription = _paymentsCollection.snapshots().listen(
      (snapshot) {
        try {
          _cachedPayments = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id; // Ujistíme se, že máme dokumentové ID.
            return Payment.fromJson(data);
          }).toList();
          _paymentsStreamController.add(_cachedPayments);
        } catch (error, stackTrace) {
          debugPrint("Error processing payments snapshot: $error");
          debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
          _paymentsStreamController.addError(error);
        }
      },
      onError: (error) {
        debugPrint("Error listening to payments collection: $error");
        _paymentsStreamController.addError(error);
      },
    );
  }

  /// Načte seznam plateb z Firestore.
  Future<List<Payment>> fetchPayments() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot =
          await _paymentsCollection.get();
      _cachedPayments = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Payment.fromJson(data);
      }).toList();
      _paymentsStreamController.add(_cachedPayments);
      return _cachedPayments;
    } catch (error, stackTrace) {
      debugPrint("Error fetching payments: $error");
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Přidá nový platební záznam do Firestore.
  Future<void> addPayment(Payment payment) async {
    try {
      if (payment.id.isNotEmpty) {
        await _paymentsCollection.doc(payment.id).set(payment.toJson());
      } else {
        await _paymentsCollection.add(payment.toJson());
      }
    } catch (error, stackTrace) {
      debugPrint("Error adding payment: $error");
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Aktualizuje existující platební záznam.
  Future<void> updatePayment(Payment payment) async {
    try {
      final DocumentReference<Map<String, dynamic>> docRef =
          _paymentsCollection.doc(payment.id);
      await docRef.update(payment.toJson());
    } catch (error, stackTrace) {
      debugPrint("Error updating payment: $error");
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Smaže platební záznam podle jeho ID.
  Future<void> deletePayment(String paymentId) async {
    try {
      await _paymentsCollection.doc(paymentId).delete();
    } catch (error, stackTrace) {
      debugPrint("Error deleting payment: $error");
      debugPrintStack(label: 'StackTrace', stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Vrací filtrovaný seznam plateb dle zadaných kritérií.
  /// Např. můžete filtrovat podle uživatelského ID, data transakce nebo stavu.
  List<Payment> getFilteredPayments({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) {
    List<Payment> filtered = List.from(_cachedPayments);
    if (userId != null && userId.isNotEmpty) {
      filtered = filtered.where((payment) => payment.userId == userId).toList();
    }
    if (startDate != null) {
      filtered = filtered.where((payment) =>
          payment.transactionDate.isAfter(startDate) ||
          payment.transactionDate.isAtSameMomentAs(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered.where((payment) =>
          payment.transactionDate.isBefore(endDate) ||
          payment.transactionDate.isAtSameMomentAs(endDate)).toList();
    }
    if (status != null && status.isNotEmpty) {
      filtered = filtered.where((payment) =>
          payment.status.toLowerCase() == status.toLowerCase()).toList();
    }
    return filtered;
  }

  /// Uvolní zdroje – zruší Firestore subscription a zavře stream controller.
  void dispose() {
    _subscription?.cancel();
    _paymentsStreamController.close();
  }
}
