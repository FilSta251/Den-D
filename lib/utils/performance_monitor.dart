/// lib/utils/performance_monitor.dart
library;

import "dart:collection";
import "package:flutter/foundation.dart";
import "package:firebase_performance/firebase_performance.dart";

/// Služba pro monitoring výkonu aplikace.
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final FirebasePerformance _performance = FirebasePerformance.instance;

  // ✅ OPRAVENO: Ukládáme trace s metadaty
  final Map<String, _TraceData> _activeTraces = {};
  final Queue<_PerformanceEntry> _history = Queue<_PerformanceEntry>();

  static const int _maxHistorySize = 100;
  bool _isEnabled = true;

  set isEnabled(bool value) {
    _isEnabled = value;
    _performance.setPerformanceCollectionEnabled(value);
  }

  bool get isEnabled => _isEnabled;

  Future<void> initialize() async {
    await _performance.setPerformanceCollectionEnabled(_isEnabled);
    debugPrint(
        "PerformanceMonitor initialized, collection ${_isEnabled ? "enabled" : "disabled"}");
  }

  String startTrace(String name) {
    if (!_isEnabled) return "disabled";

    try {
      final trace = _performance.newTrace(name);
      trace.start();

      final traceId = "${name}_${DateTime.now().millisecondsSinceEpoch}";

      // ✅ OPRAVENO: Ukládáme trace s metadaty
      _activeTraces[traceId] = _TraceData(
        trace: trace,
        name: name,
        startTime: DateTime.now(),
      );

      debugPrint("Started trace: $name (ID: $traceId)");
      return traceId;
    } catch (e) {
      debugPrint("Failed to start trace: $e");
      return "error";
    }
  }

  Future<void> stopTrace(String traceId) async {
    if (!_isEnabled || traceId == "disabled" || traceId == "error") return;

    try {
      final traceData = _activeTraces[traceId];
      if (traceData != null) {
        // ✅ OPRAVENO: Správný výpočet duration
        final duration = DateTime.now().difference(traceData.startTime);

        await traceData.trace.stop();
        _activeTraces.remove(traceId);

        _logPerformanceEntry(
          traceData.name,
          duration.inMilliseconds,
          {},
        );

        debugPrint(
            "Stopped trace: ${traceData.name} (ID: $traceId), duration: ${duration.inMilliseconds} ms");
      } else {
        debugPrint("Trace not found: $traceId");
      }
    } catch (e) {
      debugPrint("Failed to stop trace: $e");
    }
  }

  void putAttribute(String traceId, String name, String value) {
    if (!_isEnabled || traceId == "disabled" || traceId == "error") return;

    try {
      final traceData = _activeTraces[traceId];
      if (traceData != null) {
        traceData.trace.putAttribute(name, value);
        debugPrint("Added attribute to trace $traceId: $name=$value");
      }
    } catch (e) {
      debugPrint("Failed to add attribute: $e");
    }
  }

  void incrementMetric(String traceId, String name, int value) {
    if (!_isEnabled || traceId == "disabled" || traceId == "error") return;

    try {
      final traceData = _activeTraces[traceId];
      if (traceData != null) {
        traceData.trace.incrementMetric(name, value);
        debugPrint("Incremented metric in trace $traceId: $name by $value");
      }
    } catch (e) {
      debugPrint("Failed to increment metric: $e");
    }
  }

  HttpMetric? startHttpMetric(String url, String method) {
    if (!_isEnabled) return null;

    try {
      final metric = _performance.newHttpMetric(url, getHttpMethod(method));
      metric.start();
      debugPrint("Started HTTP metric: $method $url");
      return metric;
    } catch (e) {
      debugPrint("Failed to start HTTP metric: $e");
      return null;
    }
  }

  Future<void> stopHttpMetric(HttpMetric? metric,
      {int? responseCode,
      int? requestPayloadSize,
      int? responsePayloadSize}) async {
    if (!_isEnabled || metric == null) return;

    try {
      if (responseCode != null) {
        metric.httpResponseCode = responseCode;
      }

      if (requestPayloadSize != null) {
        metric.requestPayloadSize = requestPayloadSize;
      }

      if (responsePayloadSize != null) {
        metric.responsePayloadSize = responsePayloadSize;
      }

      await metric.stop();
      // ✅ OPRAVENO: Odstraněno použití neexistující property
      debugPrint("Stopped HTTP metric");
    } catch (e) {
      debugPrint("Failed to stop HTTP metric: $e");
    }
  }

  HttpMethod getHttpMethod(String method) {
    switch (method.toUpperCase()) {
      case "GET":
        return HttpMethod.Get;
      case "POST":
        return HttpMethod.Post;
      case "PUT":
        return HttpMethod.Put;
      case "DELETE":
        return HttpMethod.Delete;
      case "PATCH":
        return HttpMethod.Patch;
      case "OPTIONS":
        return HttpMethod.Options;
      case "HEAD":
        return HttpMethod.Head;
      case "TRACE":
        return HttpMethod.Trace;
      case "CONNECT":
        return HttpMethod.Connect;
      default:
        return HttpMethod.Get;
    }
  }

  Future<T> measureFunction<T>(
      String name, Future<T> Function() callback) async {
    if (!_isEnabled) return callback();

    final traceId = startTrace(name);
    final startTime = DateTime.now();

    try {
      final result = await callback();
      return result;
    } finally {
      final duration = DateTime.now().difference(startTime).inMilliseconds;
      await stopTrace(traceId);

      debugPrint("Function $name completed in ${duration}ms");
    }
  }

  void _logPerformanceEntry(
      String name, int durationMs, Map<String, String> attributes) {
    _history.addLast(_PerformanceEntry(
      name: name,
      timestamp: DateTime.now(),
      durationMs: durationMs,
      attributes: Map<String, String>.from(attributes),
    ));

    if (_history.length > _maxHistorySize) {
      _history.removeFirst();
    }
  }

  List<Map<String, dynamic>> getPerformanceHistory() {
    return _history.map((entry) => entry.toMap()).toList();
  }

  void clearHistory() {
    _history.clear();
  }

  void dispose() {
    for (final traceId in _activeTraces.keys.toList()) {
      stopTrace(traceId);
    }

    _activeTraces.clear();
    _history.clear();
  }
}

// ✅ PŘIDÁNO: Helper třída pro ukládání trace dat
class _TraceData {
  final Trace trace;
  final String name;
  final DateTime startTime;

  _TraceData({
    required this.trace,
    required this.name,
    required this.startTime,
  });
}

class _PerformanceEntry {
  final String name;
  final DateTime timestamp;
  final int durationMs;
  final Map<String, String> attributes;

  _PerformanceEntry({
    required this.name,
    required this.timestamp,
    required this.durationMs,
    required this.attributes,
  });

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "timestamp": timestamp.toIso8601String(),
      "durationMs": durationMs,
      "attributes": attributes,
    };
  }
}
