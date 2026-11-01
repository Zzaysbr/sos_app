import 'package:drift/drift.dart';

import 'ble_relay_messages.dart';

/// Per-next-hop forwarding state. An origin message may be attempted through
/// more than one eligible peer without changing the logical SOS identity.
class BleRelayAttempts extends Table {
  TextColumn get originMessageId => text().references(
    BleRelayMessages,
    #originMessageId,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get nextHopKeyId => text()();
  TextColumn get attemptId => text()();
  TextColumn get correlationId => text()();
  TextColumn get nextHopDeviceId => text()();
  IntColumn get outgoingHopCount => integer()();
  TextColumn get outgoingPath => text()();
  IntColumn get storageBytes => integer()();
  TextColumn get state => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get acceptedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {originMessageId, nextHopKeyId};
}
