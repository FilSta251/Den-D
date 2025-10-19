/// lib/utils/compute_helpers.dart
library;

import 'dart:async'; // Přidán import pro TimeoutException
import 'package:flutter/foundation.dart';

/// Spustí funkci v isolate pomocí [compute], ale jen pokud není v debug mĂłdu.
/// V debug mĂłdu se funkce spustí přímo, aby bylo moťnĂ© snáze debugovat.
Future<R> computeOrDirect<Q, R>(
    ComputeCallback<Q, R> callback, Q message) async {
  // Při debug mĂłdu spustíme funkci přímo pro snazĹˇí debugování
  if (kDebugMode) {
    return callback(message);
  }

  // V produkčním mĂłdu pouťijeme compute pro oddělený isolate
  return compute(callback, message);
}

/// Stejně jako [computeOrDirect], ale s časovým limitem pro zabránění deadlocku.
/// Pokud se operace nepodaří dokončit v danĂ©m limitu, vrátí výchozí hodnotu.
Future<R> computeWithTimeout<Q, R>(ComputeCallback<Q, R> callback, Q message,
    Duration timeout, R defaultValue) async {
  try {
    return await computeOrDirect(callback, message).timeout(timeout);
  } on TimeoutException {
    debugPrint('Compute operation timed out after ${timeout.inMilliseconds}ms');
    return defaultValue;
  }
}

/// Spustí zadanou funkci bez čekání na výsledek.
/// UťitečnĂ© pro asynchronní operace, kterĂ© nemusí čekat na dokončení.
void computeAsync<Q>(ComputeCallback<Q, void> callback, Q message) {
  if (kDebugMode) {
    // V debug mĂłdu spustíme asynchronně, ale ve stejnĂ©m isolate
    Future(() => callback(message));
  } else {
    // V produkčním mĂłdu pouťijeme compute
    compute(callback, message);
  }
}
