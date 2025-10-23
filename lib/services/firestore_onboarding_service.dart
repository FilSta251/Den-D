/// lib/services/firestore_onboarding_service.dart
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Model pro onboarding stav
class OnboardingState {
  final String userId;
  final bool onboardingCompleted;
  final bool introCompleted;
  final bool chatbotCompleted;
  final bool subscriptionShown;
  final DateTime? onboardingCompletedAt;
  final DateTime updatedAt;

  const OnboardingState({
    required this.userId,
    this.onboardingCompleted = false,
    this.introCompleted = false,
    this.chatbotCompleted = false,
    this.subscriptionShown = false,
    this.onboardingCompletedAt,
    required this.updatedAt,
  });

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    return OnboardingState(
      userId: json['userId'] as String? ?? '',
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      introCompleted: json['introCompleted'] as bool? ?? false,
      chatbotCompleted: json['chatbotCompleted'] as bool? ?? false,
      subscriptionShown: json['subscriptionShown'] as bool? ?? false,
      onboardingCompletedAt: json['onboardingCompletedAt'] != null
          ? (json['onboardingCompletedAt'] as Timestamp).toDate()
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'onboardingCompleted': onboardingCompleted,
      'introCompleted': introCompleted,
      'chatbotCompleted': chatbotCompleted,
      'subscriptionShown': subscriptionShown,
      'onboardingCompletedAt': onboardingCompletedAt != null
          ? Timestamp.fromDate(onboardingCompletedAt!)
          : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OnboardingState copyWith({
    String? userId,
    bool? onboardingCompleted,
    bool? introCompleted,
    bool? chatbotCompleted,
    bool? subscriptionShown,
    DateTime? onboardingCompletedAt,
    DateTime? updatedAt,
  }) {
    return OnboardingState(
      userId: userId ?? this.userId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      introCompleted: introCompleted ?? this.introCompleted,
      chatbotCompleted: chatbotCompleted ?? this.chatbotCompleted,
      subscriptionShown: subscriptionShown ?? this.subscriptionShown,
      onboardingCompletedAt:
          onboardingCompletedAt ?? this.onboardingCompletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Služba pro správu onboarding stavu ve Firestore
///
/// Synchronizuje stav onboardingu mezi všemi zařízeními uživatele
class FirestoreOnboardingService {
  final FirebaseFirestore _firestore;

  FirestoreOnboardingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Defaultní singleton instance
  static FirestoreOnboardingService? _defaultInstance;

  factory FirestoreOnboardingService.defaultInstance() {
    _defaultInstance ??= FirestoreOnboardingService();
    return _defaultInstance!;
  }

  /// Kolekce pro onboarding stavy (pod uživatelskými dokumenty)
  DocumentReference<Map<String, dynamic>> _getOnboardingDoc(String userId) {
    return _firestore.collection('users').doc(userId);
  }

  /// Načte onboarding stav z Firestore
  ///
  /// [userId] - ID uživatele
  /// Vrací OnboardingState nebo null pokud neexistuje
  Future<OnboardingState?> getOnboardingState(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('userId nemůže být prázdné');
      }

      debugPrint(
          '[FirestoreOnboardingService] Načítám onboarding stav pro: $userId');

      final doc = await _getOnboardingDoc(userId).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint(
            '[FirestoreOnboardingService] Onboarding stav neexistuje, vracím null');
        return null;
      }

      final data = doc.data()!;
      final state = OnboardingState.fromJson(data);

      debugPrint('[FirestoreOnboardingService] Načten stav: '
          'intro=${state.introCompleted}, '
          'chatbot=${state.chatbotCompleted}, '
          'subscription=${state.subscriptionShown}, '
          'completed=${state.onboardingCompleted}');

      return state;
    } catch (e) {
      debugPrint('[FirestoreOnboardingService] Chyba při načítání stavu: $e');
      return null;
    }
  }

  /// Uloží onboarding stav do Firestore
  ///
  /// [userId] - ID uživatele
  /// [state] - Stav k uložení
  Future<void> saveOnboardingState(String userId, OnboardingState state) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('userId nemůže být prázdné');
      }

      debugPrint(
          '[FirestoreOnboardingService] Ukládám onboarding stav pro: $userId');

      final updatedState = state.copyWith(updatedAt: DateTime.now());

      await _getOnboardingDoc(userId).set(
        updatedState.toJson(),
        SetOptions(merge: true),
      );

      debugPrint('[FirestoreOnboardingService] Stav úspěšně uložen');
    } catch (e) {
      debugPrint('[FirestoreOnboardingService] Chyba při ukládání stavu: $e');
      rethrow;
    }
  }

  /// Aktualizuje částečně onboarding stav
  ///
  /// [userId] - ID uživatele
  /// [updates] - Mapa s hodnotami k aktualizaci
  Future<void> updateOnboardingState(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('userId nemůže být prázdné');
      }

      debugPrint(
          '[FirestoreOnboardingService] Aktualizuji onboarding stav pro: $userId');

      // Přidáme updatedAt timestamp
      final data = Map<String, dynamic>.from(updates);
      data['updatedAt'] = Timestamp.fromDate(DateTime.now());
      data['userId'] = userId; // Ujistíme se, že userId je vždy přítomno

      await _getOnboardingDoc(userId).set(
        data,
        SetOptions(merge: true),
      );

      debugPrint(
          '[FirestoreOnboardingService] Stav úspěšně aktualizován: $updates');
    } catch (e) {
      debugPrint(
          '[FirestoreOnboardingService] Chyba při aktualizaci stavu: $e');
      rethrow;
    }
  }

  /// Sleduje změny onboarding stavu v real-time
  ///
  /// [userId] - ID uživatele
  /// Vrací Stream<OnboardingState?>
  Stream<OnboardingState?> watchOnboardingState(String userId) {
    if (userId.isEmpty) {
      return Stream.error(ArgumentError('userId nemůže být prázdné'));
    }

    debugPrint(
        '[FirestoreOnboardingService] Spouštím real-time sledování pro: $userId');

    return _getOnboardingDoc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return OnboardingState.fromJson(snapshot.data()!);
    }).handleError((error) {
      debugPrint('[FirestoreOnboardingService] Chyba v stream: $error');
      return null;
    });
  }

  /// Vymaže onboarding stav (užitečné pro testing)
  ///
  /// [userId] - ID uživatele
  Future<void> clearOnboardingState(String userId) async {
    try {
      if (userId.isEmpty) {
        throw ArgumentError('userId nemůže být prázdné');
      }

      debugPrint(
          '[FirestoreOnboardingService] Mažu onboarding stav pro: $userId');

      // Nastavíme vše zpět na false
      await _getOnboardingDoc(userId).set(
        {
          'userId': userId,
          'onboardingCompleted': false,
          'introCompleted': false,
          'chatbotCompleted': false,
          'subscriptionShown': false,
          'onboardingCompletedAt': null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
        SetOptions(merge: true),
      );

      debugPrint('[FirestoreOnboardingService] Stav úspěšně vymazán');
    } catch (e) {
      debugPrint('[FirestoreOnboardingService] Chyba při mazání stavu: $e');
      rethrow;
    }
  }

  /// Označí intro jako dokončené
  Future<void> markIntroCompleted(String userId) async {
    await updateOnboardingState(userId, {'introCompleted': true});
  }

  /// Označí chatbot jako dokončený
  Future<void> markChatbotCompleted(String userId) async {
    await updateOnboardingState(userId, {'chatbotCompleted': true});
  }

  /// Označí subscription jako zobrazenou
  Future<void> markSubscriptionShown(String userId) async {
    await updateOnboardingState(userId, {'subscriptionShown': true});
  }

  /// Označí celý onboarding jako dokončený
  Future<void> markOnboardingCompleted(String userId) async {
    await updateOnboardingState(userId, {
      'onboardingCompleted': true,
      'onboardingCompletedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
