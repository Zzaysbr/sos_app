import 'package:drift/drift.dart';

/// Relay-only storage. Rows here are never part of normal SOS history or cloud
/// synchronization unless this installation explicitly accepts an incident as
/// a final recipient in a later, separately gated stage.
class BleRelayMessages extends Table {
  TextColumn get originMessageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get originKeyId => text()();
  TextColumn get originPublicKey => text()();
  TextColumn get immutablePayload => text()();
  TextColumn get wireEnvelope => text()();
  TextColumn get immutableDigest => text()();
  TextColumn get originSignature => text()();
  TextColumn get authorizationScope => text()();
  TextColumn get emergencyType => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get retentionDeadline => dateTime()();
  IntColumn get maxHops => integer()();
  IntColumn get incomingHopCount => integer()();
  TextColumn get incomingPath => text()();
  TextColumn get incomingPeerId => text()();
  TextColumn get previousHopKeyId => text()();
  TextColumn get processingState => text()();
  IntColumn get payloadBytes => integer()();
  IntColumn get storageBytes => integer()();
  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get persistedAt => dateTime()();
  TextColumn get finalReceiptState => text().nullable()();
  TextColumn get finalRecipientKeyId => text().nullable()();
  TextColumn get finalAuthorizationId => text().nullable()();
  TextColumn get finalReceiptCorrelationId => text().nullable()();
  TextColumn get finalRoutePeerDeviceId => text().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {originMessageId};
}
