import 'package:drift/drift.dart';

/// Durable first inbound Chat route, recipient receipt and bounded return work.
@DataClassName('ChatReceiptData')
class ChatReceipts extends Table {
  TextColumn get ownerId => text()();
  TextColumn get messageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get transfer => text()();
  TextColumn get previousKeyId => text()();
  TextColumn get receipt => text().nullable()();
  TextColumn get state => text()();
  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {ownerId, messageId};
}
