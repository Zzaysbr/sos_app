import 'dart:convert';

import '../domain/relay_envelope.dart';

/// Deterministic accounting for the approved 1 MiB logical relay-data budget.
///
/// This deliberately counts table/column names, nulls, timestamps, states and
/// every persisted logical value. It is conservative for logical data, but it
/// is not a cap on the physical SQLite file: pages, indices, WAL files and
/// unrelated application tables are outside this model.
int relayLogicalRecordBytes(
  String tableName,
  Map<String, Object?> persistedFields,
) {
  var accountedBytes = 0;
  for (var iteration = 0; iteration < 16; iteration++) {
    final wire = relayCanonicalJson({
      'table': tableName,
      ...persistedFields,
      'storageBytes': accountedBytes,
    });
    final next = utf8.encode(wire).length;
    if (next == accountedBytes) return next;
    accountedBytes = next;
  }
  throw const RelayProtocolException(
    'Relay logical storage accounting did not converge.',
  );
}
