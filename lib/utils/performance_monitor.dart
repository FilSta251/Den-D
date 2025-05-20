// lib/utils/performance_monitor.dart

import "dart:collection";
import "package:flutter/foundation.dart";
import "package:firebase_performance/firebase_performance.dart";

/// Služba pro monitoring výkonu aplikace.
///
/// Umožňuje měřit výkon operací, sledovat trasové body, a integrovat 
/// s Firebase Performance Monitoring.
class PerformanceMonitor {
 // Singleton instance
 static final PerformanceMonitor _instance = PerformanceMonitor._internal();
 factory PerformanceMonitor() => _instance;
 PerformanceMonitor._internal();

 // Instance Firebase Performance
 final FirebasePerformance _performance = FirebasePerformance.instance;
 
 // Mapa aktivních trace
 final Map<String, Trace> _activeTraces = {};
 
 // Historie měření (omezená velikost)
 final Queue<_PerformanceEntry> _history = Queue<_PerformanceEntry>();
 
 // Maximální velikost historie
 static const int _maxHistorySize = 100;
 
 // Indikátor, zda je monitoring povolen
 bool _isEnabled = true;
 
 /// Nastaví, zda je monitoring povolen.
 set isEnabled(bool value) {
   _isEnabled = value;
   _performance.setPerformanceCollectionEnabled(value);
 }
 
 /// Vrací, zda je monitoring povolen.
 bool get isEnabled => _isEnabled;

 /// Inicializuje monitor výkonu.
 Future<void> initialize() async {
   await _performance.setPerformanceCollectionEnabled(_isEnabled);
   debugPrint("PerformanceMonitor initialized, collection ${_isEnabled ? "enabled" : "disabled"}");
 }

 /// Začne měřit výkon operace.
 ///
 /// Vrací ID měření, které lze použít pro zastavení měření.
 String startTrace(String name) {
   if (!_isEnabled) return "disabled";
   
   try {
     final trace = _performance.newTrace(name);
     trace.start();
     
     final traceId = "${name}_${DateTime.now().millisecondsSinceEpoch}";
     _activeTraces[traceId] = trace;
     
     debugPrint("Started trace: $name (ID: $traceId)");
     return traceId;
   } catch (e) {
     debugPrint("Failed to start trace: $e");
     return "error";
   }
 }

 /// Zastaví měření výkonu operace a zaznamená výsledek.
 Future<void> stopTrace(String traceId) async {
   if (!_isEnabled || traceId == "disabled" || traceId == "error") return;
   
   try {
     final trace = _activeTraces[traceId];
     if (trace != null) {
       final startTimeMs = (trace as dynamic).startTime as int?;
       final durationMs = startTimeMs != null 
           ? DateTime.now().millisecondsSinceEpoch - startTimeMs 
           : null;
       
       await trace.stop();
       _activeTraces.remove(traceId);
       
       _logPerformanceEntry(
         trace.name, 
         durationMs ?? 0,
         {},
       );
       
       debugPrint("Stopped trace: ${trace.name} (ID: $traceId), duration: ${durationMs ?? "unknown"} ms");
     } else {
       debugPrint("Trace not found: $traceId");
     }
   } catch (e) {
     debugPrint("Failed to stop trace: $e");
   }
 }

 /// Přidá atribut k aktivnímu trace.
 void putAttribute(String traceId, String name, String value) {
   if (!_isEnabled || traceId == "disabled" || traceId == "error") return;
   
   try {
     final trace = _activeTraces[traceId];
     if (trace != null) {
       trace.putAttribute(name, value);
       debugPrint("Added attribute to trace $traceId: $name=$value");
     }
   } catch (e) {
     debugPrint("Failed to add attribute: $e");
   }
 }

 /// Zaznamená metriku k aktivnímu trace.
 void incrementMetric(String traceId, String name, int value) {
   if (!_isEnabled || traceId == "disabled" || traceId == "error") return;
   
   try {
     final trace = _activeTraces[traceId];
     if (trace != null) {
       trace.incrementMetric(name, value);
       debugPrint("Incremented metric in trace $traceId: $name by $value");
     }
   } catch (e) {
     debugPrint("Failed to increment metric: $e");
   }
 }

 /// Začne měřit výkon HTTP požadavku.
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

 /// Zastaví měření výkonu HTTP požadavku a zaznamená výsledek.
 Future<void> stopHttpMetric(HttpMetric? metric, {int? responseCode, int? requestPayloadSize, int? responsePayloadSize}) async {
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
     debugPrint("Stopped HTTP metric: ${metric.url}");
   } catch (e) {
     debugPrint("Failed to stop HTTP metric: $e");
   }
 }

 /// Vrátí enum hodnotu pro HTTP metodu.
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

 /// Měří dobu provádění funkce.
 ///
 /// Přijímá jméno funkce a callback, který se má provést.
 /// Měří dobu provádění a zaznamenává výsledek.
 Future<T> measureFunction<T>(String name, Future<T> Function() callback) async {
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

 /// Zaznamenává výkonnostní údaje do lokální historie.
 void _logPerformanceEntry(String name, int durationMs, Map<String, String> attributes) {
   // Přidání nového záznamu
   _history.addLast(_PerformanceEntry(
     name: name,
     timestamp: DateTime.now(),
     durationMs: durationMs,
     attributes: Map<String, String>.from(attributes),
   ));
   
   // Odstranění nejstaršího záznamu, pokud je překročen limit
   if (_history.length > _maxHistorySize) {
     _history.removeFirst();
   }
 }

 /// Vrací historii měření výkonu.
 List<Map<String, dynamic>> getPerformanceHistory() {
   return _history.map((entry) => entry.toMap()).toList();
 }

 /// Vyčistí historii měření výkonu.
 void clearHistory() {
   _history.clear();
 }

 /// Uvolní zdroje.
 void dispose() {
   // Zastavíme všechny aktivní trace
   for (final traceId in _activeTraces.keys.toList()) {
     stopTrace(traceId);
   }
   
   _activeTraces.clear();
   _history.clear();
 }
}

/// Třída reprezentující záznam výkonu v historii.
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
