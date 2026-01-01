// lib/services/connectivity_manager.dart

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Enum pro typy připojení
enum NetworkType {
  none,
  wifi,
  mobile,
  ethernet,
  bluetooth,
  vpn,
  other,
}

/// Třída reprezentující stav sítě
class NetworkStatus {
  final bool isConnected;
  final NetworkType type;
  final String? networkName;
  final bool isMetered;
  final int? signalStrength;
  final DateTime timestamp;

  NetworkStatus({
    required this.isConnected,
    required this.type,
    this.networkName,
    this.isMetered = false,
    this.signalStrength,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  NetworkStatus copyWith({
    bool? isConnected,
    NetworkType? type,
    String? networkName,
    bool? isMetered,
    int? signalStrength,
  }) {
    return NetworkStatus(
      isConnected: isConnected ?? this.isConnected,
      type: type ?? this.type,
      networkName: networkName ?? this.networkName,
      isMetered: isMetered ?? this.isMetered,
      signalStrength: signalStrength ?? this.signalStrength,
      // copyWith vždy nastaví "nyní"
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'NetworkStatus(connected: $isConnected, type: $type, name: $networkName, at: $timestamp)';
  }
}

/// Reprezentuje offline akci pro pozdější provedení
class PendingAction {
  final String id;
  final Future<void> Function() action;
  final String description;
  final DateTime created;
  final int maxRetries;
  int attempts;

  PendingAction({
    required this.id,
    required this.action,
    required this.description,
    this.maxRetries = 3,
    this.attempts = 0,
  }) : created = DateTime.now();

  bool get canRetry => attempts < maxRetries;

  Duration get age => DateTime.now().difference(created);
}

/// Pokročilý manager pro sledování a správu síťového připojení.
///
/// poskytuje:
/// - Sledování stavu připojení v reálném čase
/// - Rozlišení typů sítí (WiFi, mobilní data, ethernet)
/// - Offline queue pro akce
/// - Kontrolu kvality připojení
/// - Automatické opakování neúspěšných operací
/// - Měření latence a rychlosti
class ConnectivityManager {
  static final ConnectivityManager _instance = ConnectivityManager._internal();
  factory ConnectivityManager() => _instance;
  ConnectivityManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Aktuální stav sítě
  NetworkStatus _currentStatus = NetworkStatus(
    isConnected: false,
    type: NetworkType.none,
  );

  // Stream pro broadcasting změn
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  // Fronta offline akcí
  final Map<String, PendingAction> _pendingActions = {};
  Timer? _retryTimer;

  // Sledování kvality připojení
  final List<Duration> _latencyHistory = [];
  static const int _maxLatencyHistory = 10;

  // Nastavení
  bool _enableOfflineQueue = true;
  Duration _retryInterval = const Duration(seconds: 30);
  final Duration _healthCheckInterval = const Duration(minutes: 2);
  Timer? _healthCheckTimer;

  // Statistiky
  int _totalConnections = 0;
  int _totalDisconnections = 0;
  Duration _totalDowntime = Duration.zero;
  DateTime? _lastDisconnectionTime;

  bool _initialized = false;

  /// Získání aktuálního stavu sítě
  NetworkStatus get currentStatus => _currentStatus;

  /// Stream pro sledování změn stavu sítě
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Je připojení k internetu dostupné?
  bool get isConnected => _currentStatus.isConnected;

  /// Typ aktuálního připojení
  NetworkType get connectionType => _currentStatus.type;

  /// Počet čekajících offline akcí
  int get pendingActionsCount => _pendingActions.length;

  /// Průměrná latence z posledních měření
  Duration? get averageLatency {
    if (_latencyHistory.isEmpty) return null;
    final total = _latencyHistory.fold<int>(
        0, (sum, latency) => sum + latency.inMilliseconds);
    return Duration(milliseconds: total ~/ _latencyHistory.length);
  }

  /// Statistiky připojení
  Map<String, dynamic> get connectionStats => {
        'totalConnections': _totalConnections,
        'totalDisconnections': _totalDisconnections,
        'totalDowntime': _totalDowntime.inMilliseconds,
        'averageLatency': averageLatency?.inMilliseconds,
        'pendingActions': pendingActionsCount,
      };

  /// Inicializace manageru
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('[ConnectivityManager] Initializing...');

      // Získání počátečního stavu
      final initialResults = await _connectivity.checkConnectivity();
      await _updateNetworkStatus(initialResults);

      // Spuštění sledování změn
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateNetworkStatus,
        onError: (error) {
          debugPrint('[ConnectivityManager] Stream error: $error');
        },
      );

      // Spuštění health check timeru
      _startHealthCheck();

      // Spuštění retry timeru pro offline akce
      _startRetryTimer();

      _initialized = true;
      debugPrint('[ConnectivityManager] Initialized successfully');
      debugPrint('[ConnectivityManager] Initial status: $_currentStatus');
    } catch (e) {
      debugPrint('[ConnectivityManager] Initialization failed: $e');
      rethrow;
    }
  }

  /// Aktualizace stavu sítě při změně
  Future<void> _updateNetworkStatus(List<ConnectivityResult> results) async {
    try {
      final oldStatus = _currentStatus;

      // Získání nejprioritnějšího typu připojení
      final result = _getPrimaryConnectivityResult(results);
      final newType = _mapConnectivityResult(result);

      // Základní kontrola dostupnosti internetu
      bool isConnected = false;
      String? networkName;

      if (newType != NetworkType.none) {
        isConnected = await _verifyInternetConnectivity();
        if (isConnected) {
          networkName = await _getNetworkName(result);
        }
      }

      final newStatus = NetworkStatus(
        isConnected: isConnected,
        type: newType,
        networkName: networkName,
        isMetered: await _isMeteredConnection(result),
      );

      // Aktualizace pouze při změně
      if (_hasStatusChanged(oldStatus, newStatus)) {
        _currentStatus = newStatus;

        // Sledování statistik
        await _updateConnectionStats(oldStatus, newStatus);

        // Broadcast změny
        _statusController.add(newStatus);

        debugPrint(
            '[ConnectivityManager] Status changed: $oldStatus -> $newStatus');

        // Zpracování změny připojení
        await _handleConnectivityChange(oldStatus, newStatus);
      }
    } catch (e) {
      debugPrint('[ConnectivityManager] Error updating status: $e');
    }
  }

  /// Získání nejprioritnějšího typu připojení ze seznamu
  ConnectivityResult _getPrimaryConnectivityResult(
      List<ConnectivityResult> results) {
    if (results.isEmpty) return ConnectivityResult.none;

    // Priorita: wifi > ethernet > mobile > bluetooth > vpn > other > none
    const priority = [
      ConnectivityResult.wifi,
      ConnectivityResult.ethernet,
      ConnectivityResult.mobile,
      ConnectivityResult.bluetooth,
      ConnectivityResult.vpn,
      ConnectivityResult.other,
    ];

    for (final priorityResult in priority) {
      if (results.contains(priorityResult)) {
        return priorityResult;
      }
    }

    return ConnectivityResult.none;
  }

  /// Zpracování změny stavu připojení
  Future<void> _handleConnectivityChange(
      NetworkStatus oldStatus, NetworkStatus newStatus) async {
    if (!oldStatus.isConnected && newStatus.isConnected) {
      // Připojení obnoveno
      debugPrint('[ConnectivityManager] Connection restored');
      await _processPendingActions();
    } else if (oldStatus.isConnected && !newStatus.isConnected) {
      // Připojení ztraceno
      debugPrint('[ConnectivityManager] Connection lost');
    }
  }

  /// Aktualizace statistik připojení
  Future<void> _updateConnectionStats(
      NetworkStatus oldStatus, NetworkStatus newStatus) async {
    if (!oldStatus.isConnected && newStatus.isConnected) {
      _totalConnections++;

      // Vypočítání downtime
      if (_lastDisconnectionTime != null) {
        final downtime = DateTime.now().difference(_lastDisconnectionTime!);
        _totalDowntime = _totalDowntime + downtime;
        _lastDisconnectionTime = null;
      }
    } else if (oldStatus.isConnected && !newStatus.isConnected) {
      _totalDisconnections++;
      _lastDisconnectionTime = DateTime.now();
    }
  }

  /// Mapování ConnectivityResult na NetworkType
  NetworkType _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkType.wifi;
      case ConnectivityResult.mobile:
        return NetworkType.mobile;
      case ConnectivityResult.ethernet:
        return NetworkType.ethernet;
      case ConnectivityResult.bluetooth:
        return NetworkType.bluetooth;
      case ConnectivityResult.vpn:
        return NetworkType.vpn;
      case ConnectivityResult.other:
        return NetworkType.other;
      case ConnectivityResult.none:
        return NetworkType.none;
    }
  }

  /// Kontrola, zda se stav skutečně změnil
  bool _hasStatusChanged(NetworkStatus old, NetworkStatus new_) {
    return old.isConnected != new_.isConnected ||
        old.type != new_.type ||
        old.networkName != new_.networkName;
  }

  /// Ověření skutečné dostupnosti internetu pomocí ping
  Future<bool> _verifyInternetConnectivity() async {
    try {
      final stopwatch = Stopwatch()..start();

      // Pokus o připojení k spolehlivým serverům
      final servers = [
        'google.com',
        'cloudflare.com',
        '8.8.8.8',
      ];

      for (final server in servers) {
        try {
          final result = await InternetAddress.lookup(server)
              .timeout(const Duration(seconds: 5));

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            stopwatch.stop();
            _recordLatency(stopwatch.elapsed);
            return true;
          }
        } catch (e) {
          // Pokračuj na další server
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint('[ConnectivityManager] Internet verification failed: $e');
      return false;
    }
  }

  /// Zaznamenání latence pro statistiky
  void _recordLatency(Duration latency) {
    _latencyHistory.add(latency);
    if (_latencyHistory.length > _maxLatencyHistory) {
      _latencyHistory.removeAt(0);
    }
  }

  /// Získání názvu sítě (pokud je dostupný)
  Future<String?> _getNetworkName(ConnectivityResult result) async {
    try {
      if (result == ConnectivityResult.wifi) {
        // Na Androidu můžeme získat SSID, na iOS je to omezené
        // Zde by byla implementace specifická pro platformu
        return 'WiFi Network';
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Kontrola, zda je připojení měřené (mobilní data)
  Future<bool> _isMeteredConnection(ConnectivityResult result) async {
    // Mobilní data jsou obvykle měřená
    return result == ConnectivityResult.mobile;
  }

  /// Spuštění health check timeru
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      if (_currentStatus.isConnected) {
        // Ověření kvality připojení
        final isStillConnected = await _verifyInternetConnectivity();
        if (!isStillConnected) {
          // Falešně pozitivní připojení - aktualizuj stav
          await _updateNetworkStatus([ConnectivityResult.none]);
        }
      }
    });
  }

  /// Spuštění retry timeru pro offline akce
  void _startRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(_retryInterval, (timer) async {
      if (_currentStatus.isConnected && _pendingActions.isNotEmpty) {
        await _processPendingActions();
      }
    });
  }

  /// Přidání akce do offline fronty
  Future<String> addPendingAction(
    Future<void> Function() action, {
    required String description,
    int maxRetries = 3,
  }) async {
    if (!_enableOfflineQueue) {
      throw Exception('Offline queue is disabled');
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final pendingAction = PendingAction(
      id: id,
      action: action,
      description: description,
      maxRetries: maxRetries,
    );

    _pendingActions[id] = pendingAction;

    debugPrint('[ConnectivityManager] Added pending action: $description');

    // Pokud jsme online, pokus se akci provést okamžitě
    if (_currentStatus.isConnected) {
      await _executeAction(pendingAction);
    }

    return id;
  }

  /// Odstranění akce z fronty
  bool removePendingAction(String actionId) {
    final removed = _pendingActions.remove(actionId);
    if (removed != null) {
      debugPrint(
          '[ConnectivityManager] Removed pending action: ${removed.description}');
      return true;
    }
    return false;
  }

  /// Zpracování všech čekajících akcí
  Future<void> _processPendingActions() async {
    if (_pendingActions.isEmpty) return;

    debugPrint(
        '[ConnectivityManager] Processing ${_pendingActions.length} pending actions');

    final actionsToProcess = List<PendingAction>.from(_pendingActions.values);

    for (final action in actionsToProcess) {
      await _executeAction(action);

      // Krátká pauza mezi akcemi
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Provedení jednotlivé akce
  Future<void> _executeAction(PendingAction pendingAction) async {
    try {
      pendingAction.attempts++;

      await pendingAction.action();

      // Úspěch - odstraň z fronty
      _pendingActions.remove(pendingAction.id);
      debugPrint(
          '[ConnectivityManager] Action completed: ${pendingAction.description}');
    } catch (e) {
      debugPrint(
          '[ConnectivityManager] Action failed: ${pendingAction.description} - $e');

      if (!pendingAction.canRetry) {
        _pendingActions.remove(pendingAction.id);
        debugPrint(
            '[ConnectivityManager] Action removed after max retries: ${pendingAction.description}');
      }
    }
  }

  /// Měření rychlosti připojení (zjednodušená verze)
  Future<double?> measureConnectionSpeed() async {
    if (!_currentStatus.isConnected) return null;

    try {
      const testUrl = 'https://httpbin.org/bytes/1048576'; // 1MB
      final stopwatch = Stopwatch()..start();

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(testUrl));
      final response = await request.close();

      int bytesReceived = 0;
      await for (final chunk in response) {
        bytesReceived += chunk.length;
      }

      stopwatch.stop();
      client.close();

      // Výpočet rychlosti v Mbps
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      final mbps = (bytesReceived * 8) / (seconds * 1000000);

      debugPrint(
          '[ConnectivityManager] Connection speed: ${mbps.toStringAsFixed(2)} Mbps');
      return mbps;
    } catch (e) {
      debugPrint('[ConnectivityManager] Speed test failed: $e');
      return null;
    }
  }

  /// Čekání na obnovení připojení
  Future<void> waitForConnection({Duration? timeout}) async {
    if (_currentStatus.isConnected) return;

    final completer = Completer<void>();
    late StreamSubscription subscription;

    subscription = statusStream.listen((status) {
      if (status.isConnected) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    if (timeout != null) {
      Timer(timeout, () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(
              TimeoutException('Timeout waiting for connection', timeout));
        }
      });
    }

    return completer.future;
  }

  /// Kontrola kvality připojení
  Future<NetworkQuality> checkNetworkQuality() async {
    if (!_currentStatus.isConnected) {
      return NetworkQuality.none;
    }

    final latency = averageLatency;
    if (latency == null) {
      return NetworkQuality.unknown;
    }

    if (latency.inMilliseconds < 100) {
      return NetworkQuality.excellent;
    } else if (latency.inMilliseconds < 300) {
      return NetworkQuality.good;
    } else if (latency.inMilliseconds < 600) {
      return NetworkQuality.fair;
    } else {
      return NetworkQuality.poor;
    }
  }

  /// Callback registrace pro změny připojení
  void onConnectivityChanged(Function(NetworkStatus) callback) {
    statusStream.listen(callback);
  }

  /// Povolení/zakázání offline fronty
  void setOfflineQueueEnabled(bool enabled) {
    _enableOfflineQueue = enabled;
    if (!enabled) {
      _pendingActions.clear();
    }
  }

  /// Nastavení intervalu pro opakování akcí
  void setRetryInterval(Duration interval) {
    _retryInterval = interval;
    _startRetryTimer(); // Restart s novým intervalem
  }

  /// Export čekajících akcí pro debugging
  List<Map<String, dynamic>> exportPendingActions() {
    return _pendingActions.values
        .map((action) => {
              'id': action.id,
              'description': action.description,
              'attempts': action.attempts,
              'maxRetries': action.maxRetries,
              'created': action.created.toIso8601String(),
              'age': action.age.inMinutes,
            })
        .toList();
  }

  /// Kontrola dostupnosti konkrétního serveru
  Future<bool> checkServerReachability(String host, {int port = 80}) async {
    try {
      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Uvolnění zdrojů
  void dispose() {
    debugPrint('[ConnectivityManager] Disposing...');

    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    _healthCheckTimer?.cancel();
    _statusController.close();
    _pendingActions.clear();

    _initialized = false;
  }
}

/// Enum pro kvalitu sítě
enum NetworkQuality {
  none,
  poor,
  fair,
  good,
  excellent,
  unknown,
}

/// Rozšíření pro NetworkQuality
extension NetworkQualityExtension on NetworkQuality {
  String get displayName {
    switch (this) {
      case NetworkQuality.none:
        return 'Žádné připojení';
      case NetworkQuality.poor:
        return 'Slabé';
      case NetworkQuality.fair:
        return 'Průměrné';
      case NetworkQuality.good:
        return 'Dobré';
      case NetworkQuality.excellent:
        return 'Výborné';
      case NetworkQuality.unknown:
        return 'Neznámé';
    }
  }

  Color get color {
    switch (this) {
      case NetworkQuality.none:
        return Colors.grey;
      case NetworkQuality.poor:
        return Colors.red;
      case NetworkQuality.fair:
        return Colors.orange;
      case NetworkQuality.good:
        return Colors.green;
      case NetworkQuality.excellent:
        return Colors.blue;
      case NetworkQuality.unknown:
        return Colors.grey;
    }
  }
}
