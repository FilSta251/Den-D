// lib/utils/compute_helpers.dart

import 'dart:async'; // Přidán import pro TimeoutException
import 'package:flutter/foundation.dart';

/// Spustí funkci v isolate pomocí [compute], ale jen pokud není v debug módu.
/// V debug módu se funkce spustí přímo, aby bylo možné snáze debugovat.
Future<R> computeOrDirect<Q, R>(ComputeCallback<Q, R> callback, Q message) async {
  // Při debug módu spustíme funkci přímo pro snazší debugování
  if (kDebugMode) {
    return callback(message);
  }
  
  // V produkčním módu použijeme compute pro oddělený isolate
  return compute(callback, message);
}

/// Stejně jako [computeOrDirect], ale s časovým limitem pro zabránění deadlocku.
/// Pokud se operace nepodaří dokončit v daném limitu, vrátí výchozí hodnotu.
Future<R> computeWithTimeout<Q, R>(
  ComputeCallback<Q, R> callback, 
  Q message, 
  Duration timeout, 
  R defaultValue
) async {
  try {
    return await computeOrDirect(callback, message).timeout(timeout);
  } on TimeoutException {
    debugPrint('Compute operation timed out after ${timeout.inMilliseconds}ms');
    return defaultValue;
  }
}

/// Spustí zadanou funkci bez čekání na výsledek.
/// Užitečné pro asynchronní operace, které nemusí čekat na dokončení.
void computeAsync<Q>(ComputeCallback<Q, void> callback, Q message) {
  if (kDebugMode) {
    // V debug módu spustíme asynchronně, ale ve stejném isolate
    Future(() => callback(message));
  } else {
    // V produkčním módu použijeme compute
    compute(callback, message);
  }
}