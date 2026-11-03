import 'package:drift/drift.dart';

class ChatRelayInbox extends Table {
  TextColumn get ownerId => text()();
  TextColumn get messageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get senderKeyId => text()();
  TextColumn get recipientKeyId => text()();
  TextColumn get payload => text()();
  TextColumn get state => text()();
  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, messageId};
}
