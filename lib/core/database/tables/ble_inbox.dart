import 'package:drift/drift.dart';

class BleInbox extends Table {
  TextColumn get messageId => text()();

  TextColumn get sosId => text()();

  TextColumn get senderDeviceId => text().nullable()();

  IntColumn get schemaVersion => integer()();

  TextColumn get payload => text()();

  TextColumn get processingState => text()();

  DateTimeColumn get receivedAt => dateTime()();

  DateTimeColumn get persistedAt => dateTime().nullable()();

  TextColumn get acknowledgementStatus => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}
