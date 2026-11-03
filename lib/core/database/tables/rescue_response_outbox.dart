import 'package:drift/drift.dart';

/// Owner-scoped authenticated rescue responses waiting for a verified route.
class RescueResponseOutbox extends Table {
  TextColumn get ownerId => text()();
  TextColumn get messageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get originMessageId => text()();
  TextColumn get originKeyId => text()();
  TextColumn get responderKeyId => text()();
  TextColumn get payload => text()();
  TextColumn get state => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get finalAckAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, messageId};
}
