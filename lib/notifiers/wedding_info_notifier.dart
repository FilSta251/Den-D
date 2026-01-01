import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/wedding_info.dart';
import '../repositories/wedding_repository.dart';

/// WeddingInfoNotifier slouťí jako most mezi daty z Firestore (prostřednictvím WeddingRepository)
/// a UI. Notifier naslouchá změnám v informacích o svatbě, ukládá aktuální stav do lokální cache,
/// a při kaťdĂ© změně vyvolá [notifyListeners()] pro aktualizaci UI.
class WeddingInfoNotifier extends ChangeNotifier {
  final WeddingRepository _weddingRepository;

  WeddingInfo? _weddingInfo;
  WeddingInfo? get weddingInfo => _weddingInfo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  late final StreamSubscription<WeddingInfo?> _subscription;

  WeddingInfoNotifier({required WeddingRepository weddingRepository})
      : _weddingRepository = weddingRepository {
    _init();
  }

  /// Inicializace notifieru: Naslouchá real-time streamu z repository
  /// a loguje případnĂ© chyby.
  void _init() {
    _setLoading(true);
    _subscription = _weddingRepository.weddingInfoStream.listen(
      (wedding) {
        debugPrint('[WeddingInfoNotifier] Data received: $wedding');
        _weddingInfo = wedding;
        _error = null;
        _setLoading(false);
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[WeddingInfoNotifier] Error in stream: $error');
        _error = error.toString();
        _setLoading(false);
        notifyListeners();
      },
    );
  }

  /// Náčte informace o svatbě pomocí repository.
  /// Při úspěchu aktualizuje lokální stav a vyvolá notifikaci.
  Future<void> fetchWeddingInfo() async {
    _setLoading(true);
    try {
      final wedding = await _weddingRepository.fetchWeddingInfo();
      debugPrint('[WeddingInfoNotifier] Fetched wedding info: $wedding');
      _weddingInfo = wedding;
      _error = null;
    } catch (e) {
      debugPrint('[WeddingInfoNotifier] Error fetching wedding info: $e');
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Aktualizuje informace o svatbě prostřednictvím repository.
  /// Pokud dojde k chybě, vyvolá [notifyListeners()] s chybovou zprávou.
  Future<void> updateWeddingInfo(WeddingInfo updatedInfo) async {
    _setLoading(true);
    try {
      debugPrint('[WeddingInfoNotifier] Updating wedding info: $updatedInfo');
      await _weddingRepository.updateWeddingInfo(updatedInfo);
      _weddingInfo = updatedInfo;
      _error = null;
      debugPrint('[WeddingInfoNotifier] Wedding info updated successfully.');
    } catch (e) {
      debugPrint('[WeddingInfoNotifier] Error updating wedding info: $e');
      _error = e.toString();
      rethrow;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Vytvoří novĂ© informace o svatbě, pokud jeĹˇtě neexistují.
  Future<void> createWeddingInfo(WeddingInfo info) async {
    _setLoading(true);
    try {
      debugPrint('[WeddingInfoNotifier] Creating wedding info: $info');
      await _weddingRepository.createWeddingInfo(info);
      _weddingInfo = info;
      _error = null;
      debugPrint('[WeddingInfoNotifier] Wedding info created successfully.');
    } catch (e) {
      debugPrint('[WeddingInfoNotifier] Error creating wedding info: $e');
      _error = e.toString();
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
  }

  @override
  void dispose() {
    debugPrint('[WeddingInfoNotifier] Disposing notifier.');
    _subscription.cancel();
    super.dispose();
  }
}
