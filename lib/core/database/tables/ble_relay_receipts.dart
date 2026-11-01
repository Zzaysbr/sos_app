import 'package:drift/drift.dart';

import 'ble_relay_messages.dart';

/// Hop and final receipts remain distinct in protocol, storage, and UI state.
class BleRelayReceipts extends Table {
  TextColumn get semanticKey => text()();
  TextColumn get receiptId => text()();
  TextColumn get receiptType => text()();
  TextColumn get originMessageId => text().references(
    BleRelayMessages,
    #originMessageId,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get incidentId => text()();
  TextColumn get immutableDigest => text()();
  TextColumn get signerKeyId => text()();
  TextColumn get signerPublicKey => text()();
  TextColumn get correlationId => text()();
  TextColumn get attemptId => text().nullable()();
  TextColumn get finalAuthorizationId => text().nullable()();
  TextColumn get sourcePeerDeviceId => text()();
  TextColumn get previousHopKeyId => text().nullable()();
  TextColumn get previousHopDeviceId => text().nullable()();
  TextColumn get payload => text()();
  TextColumn get signature => text()();
  IntColumn get storageBytes => integer()();
  TextColumn get state => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {semanticKey};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {receiptId},
  ];
}
