import 'package:drift/drift.dart';

class BleOutbox extends Table {
  TextColumn get messageId => text()();

  TextColumn get sosId => text()();

  TextColumn get destinationId => text().nullable()();

  IntColumn get schemaVersion => integer()();

  TextColumn get payload => text()();

  TextColumn get state => text()();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextRetryAt => dateTime().nullable()();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get acknowledgedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}
