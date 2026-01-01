/// lib/services/purchase_verification_service.dart
///
/// Service pro server-side verifikaci nákupů přes Firebase Cloud Functions.
/// Volá verifyPlaySubscription funkci a zpracovává odpověď.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Výsledek verifikace nákupu
class VerificationResult {
  final bool valid;
  final String? orderId;
  final DateTime? expiresAt;
  final bool? autoRenewing;
  final double? price;
  final String? currency;
  final String? error;
  final bool alreadyProcessed;

  VerificationResult({
    required this.valid,
    this.orderId,
    this.expiresAt,
    this.autoRenewing,
    this.price,
    this.currency,
    this.error,
    this.alreadyProcessed = false,
  });

  factory VerificationResult.fromMap(Map<String, dynamic> map) {
    DateTime? expiresAt;
    if (map['expiryTimeMillis'] != null) {
      final millis = int.tryParse(map['expiryTimeMillis'].toString());
      if (millis != null) {
        expiresAt = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    double? price;
    if (map['priceAmountMicros'] != null) {
      final micros = int.tryParse(map['priceAmountMicros'].toString());
      if (micros != null) {
        price = micros / 1000000.0; // Převod z mikro jednotek
      }
    }

    return VerificationResult(
      valid: map['valid'] == true,
      orderId: map['orderId'] as String?,
      expiresAt: expiresAt,
      autoRenewing: map['autoRenewing'] as bool?,
      price: price,
      currency: map['priceCurrencyCode'] as String?,
      error: map['error'] as String?,
      alreadyProcessed: map['alreadyProcessed'] == true,
    );
  }

  factory VerificationResult.error(String message) {
    return VerificationResult(
      valid: false,
      error: message,
    );
  }

  @override
  String toString() {
    return 'VerificationResult(valid: $valid, orderId: $orderId, '
        'expiresAt: $expiresAt, autoRenewing: $autoRenewing, '
        'alreadyProcessed: $alreadyProcessed, error: $error)';
  }
}

/// Service pro verifikaci nákupů přes Cloud Functions
class PurchaseVerificationService {
  // Singleton instance
  static final PurchaseVerificationService _instance =
      PurchaseVerificationService._internal();
  factory PurchaseVerificationService() => _instance;
  PurchaseVerificationService._internal();

  // Firebase Cloud Functions instance
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Ověří Google Play subscription nákup na serveru
  ///
  /// [uid] - ID uživatele
  /// [productId] - ID produktu (subscription ID)
  /// [purchaseToken] - Token nákupu z Google Play
  ///
  /// Vrací VerificationResult s výsledkem ověření
  Future<VerificationResult> verifyPlaySubscription({
    required String uid,
    required String productId,
    required String purchaseToken,
  }) async {
    debugPrint('[PurchaseVerificationService] Verifying purchase: '
        'uid=$uid, productId=$productId');

    try {
      // Zavolání Cloud Function
      final callable = _functions.httpsCallable(
        'verifyPlaySubscription',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'uid': uid,
        'productId': productId,
        'purchaseToken': purchaseToken,
        'platform': 'android',
      });

      final data = result.data;
      debugPrint('[PurchaseVerificationService] Response: $data');

      return VerificationResult.fromMap(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[PurchaseVerificationService] Firebase Functions error: '
          'code=${e.code}, message=${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'unauthenticated':
          errorMessage = 'Nejste přihlášeni. Přihlaste se a zkuste znovu.';
          break;
        case 'invalid-argument':
          errorMessage = 'Neplatné údaje o nákupu.';
          break;
        case 'permission-denied':
          errorMessage = 'Nemáte oprávnění k této akci.';
          break;
        case 'already-exists':
          errorMessage = 'Tento nákup byl již zpracován.';
          break;
        case 'not-found':
          errorMessage = 'Nákup nebyl nalezen.';
          break;
        default:
          errorMessage = e.message ?? 'Chyba při ověřování nákupu.';
      }

      return VerificationResult.error(errorMessage);
    } catch (e) {
      debugPrint('[PurchaseVerificationService] Unexpected error: $e');
      return VerificationResult.error(
          'Neočekávaná chyba při ověřování nákupu: $e');
    }
  }

  /// Kontrola, zda je služba dostupná
  Future<bool> isAvailable() async {
    try {
      // Jednoduchý test - pokusíme se získat callable
      // (nezavolá funkci, jen ověří dostupnost)
      _functions.httpsCallable('verifyPlaySubscription');
      return true;
    } catch (e) {
      debugPrint('[PurchaseVerificationService] Service not available: $e');
      return false;
    }
  }
}
