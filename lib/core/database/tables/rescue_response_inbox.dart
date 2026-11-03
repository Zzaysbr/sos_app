import 'package:drift/drift.dart';

/// Owner-scoped authenticated responses received for local verification.
class RescueResponseInbox extends Table {
  TextColumn get ownerId => text()();
  TextColumn get messageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get originMessageId => text()();
  TextColumn get responderKeyId => text()();
  TextColumn get immutableDigest => text()();
  TextColumn get payload => text()();
  TextColumn get state => text()();
  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get processedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, messageId};
}
