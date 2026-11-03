import 'package:drift/drift.dart';

class ChatRelayOutbox extends Table {
  TextColumn get ownerId => text()();
  TextColumn get messageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get senderKeyId => text()();
  TextColumn get recipientKeyId => text()();
  TextColumn get payload => text()();
  TextColumn get state => text()();
  IntColumn get hopCount => integer().withDefault(const Constant(0))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, messageId};
}
