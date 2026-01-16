/// lib/services/app_tracking_service.dart
///
/// Service pro App Tracking Transparency (ATT) na iOS.
/// POVINNÉ PRO APP STORE (Guideline 5.1.2)
///
/// Tato služba zajišťuje, že aplikace požádá uživatele o souhlas
/// se sledováním před jakýmkoliv trackingem.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Status trackování pro interní použití
enum AppTrackingStatus {
  /// Stav ještě nebyl určen
  notDetermined,

  /// Uživatel omezil přístup k trackování
  restricted,

  /// Uživatel odmítl tracking
  denied,

  /// Uživatel povolil tracking
  authorized,

  /// Platforma nepodporuje ATT (Android, starší iOS)
  notSupported,
}

/// Service pro správu App Tracking Transparency
///
/// Použití:
/// ```dart
/// final attService = AppTrackingService();
/// await attService.initialize();
///
/// if (attService.isTrackingAuthorized) {
///   // Můžeme trackovat
/// }
/// ```
class AppTrackingService {
  // Singleton instance
  static final AppTrackingService _instance = AppTrackingService._internal();

  factory AppTrackingService() => _instance;

  AppTrackingService._internal();

  // Aktuální status
  AppTrackingStatus _status = AppTrackingStatus.notDetermined;
  bool _isInitialized = false;

  /// Getter pro aktuální tracking status
  AppTrackingStatus get status => _status;

  /// Getter pro kontrolu, zda je tracking autorizován
  bool get isTrackingAuthorized => _status == AppTrackingStatus.authorized;

  /// Getter pro kontrolu, zda je možné požádat o povolení
  bool get canRequestTracking =>
      _status == AppTrackingStatus.notDetermined && Platform.isIOS;

  /// Getter pro kontrolu inicializace
  bool get isInitialized => _isInitialized;

  /// Inicializuje ATT service a zjistí aktuální stav
  ///
  /// Volat při startu aplikace PŘED jakýmkoliv trackingem
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[AppTrackingService] Already initialized');
      return;
    }

    try {
      // ATT je pouze pro iOS 14+
      if (!Platform.isIOS) {
        debugPrint(
            '[AppTrackingService] Not iOS - tracking not restricted by ATT');
        _status = AppTrackingStatus.notSupported;
        _isInitialized = true;
        return;
      }

      // Získání aktuálního stavu
      final trackingStatus =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      _status = _convertStatus(trackingStatus);

      debugPrint(
          '[AppTrackingService] Initialized with status: $_status (raw: $trackingStatus)');
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AppTrackingService] Error during initialization: $e');
      // V případě chyby předpokládáme, že tracking není povolen
      _status = AppTrackingStatus.notSupported;
      _isInitialized = true;
    }
  }

  /// Požádá uživatele o povolení trackingu
  ///
  /// DŮLEŽITÉ: Volat POUZE jednou, nejlépe po zobrazení vysvětlení uživateli.
  /// Na iOS 14+ se zobrazí systémový dialog.
  ///
  /// Vrací aktuální AppTrackingStatus po rozhodnutí uživatele.
  Future<AppTrackingStatus> requestTrackingAuthorization() async {
    try {
      // ATT je pouze pro iOS
      if (!Platform.isIOS) {
        debugPrint('[AppTrackingService] Not iOS - skipping ATT request');
        return AppTrackingStatus.notSupported;
      }

      // Pokud už máme odpověď, nevyžadujeme znovu
      if (_status != AppTrackingStatus.notDetermined) {
        debugPrint(
            '[AppTrackingService] Tracking status already determined: $_status');
        return _status;
      }

      debugPrint('[AppTrackingService] Requesting tracking authorization...');

      // Zobrazení systémového dialogu
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      _status = _convertStatus(status);

      debugPrint(
          '[AppTrackingService] User response: $_status (raw: $status)');

      return _status;
    } catch (e) {
      debugPrint('[AppTrackingService] Error requesting authorization: $e');
      return _status;
    }
  }

  /// Získá reklamní identifikátor (IDFA) pokud je tracking povolen
  ///
  /// Vrací null pokud tracking není povolen nebo není dostupný
  Future<String?> getAdvertisingIdentifier() async {
    try {
      if (!Platform.isIOS) {
        return null;
      }

      if (!isTrackingAuthorized) {
        debugPrint(
            '[AppTrackingService] Cannot get IDFA - tracking not authorized');
        return null;
      }

      final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
      debugPrint('[AppTrackingService] Got IDFA: ${idfa.isNotEmpty}');
      return idfa.isNotEmpty ? idfa : null;
    } catch (e) {
      debugPrint('[AppTrackingService] Error getting IDFA: $e');
      return null;
    }
  }

  /// Konvertuje nativní TrackingStatus na interní AppTrackingStatus
  AppTrackingStatus _convertStatus(TrackingStatus nativeStatus) {
    switch (nativeStatus) {
      case TrackingStatus.notDetermined:
        return AppTrackingStatus.notDetermined;
      case TrackingStatus.restricted:
        return AppTrackingStatus.restricted;
      case TrackingStatus.denied:
        return AppTrackingStatus.denied;
      case TrackingStatus.authorized:
        return AppTrackingStatus.authorized;
      case TrackingStatus.notSupported:
        return AppTrackingStatus.notSupported;
    }
  }

  /// Vrací textový popis stavu pro logování/debugging
  String getStatusDescription() {
    switch (_status) {
      case AppTrackingStatus.notDetermined:
        return 'Uživatel ještě nerozhodl o trackingu';
      case AppTrackingStatus.restricted:
        return 'Tracking je omezen (např. rodičovská kontrola)';
      case AppTrackingStatus.denied:
        return 'Uživatel odmítl tracking';
      case AppTrackingStatus.authorized:
        return 'Uživatel povolil tracking';
      case AppTrackingStatus.notSupported:
        return 'ATT není na této platformě podporováno';
    }
  }
}
