import 'package:drift/drift.dart';

class ChatMessages extends Table {
  TextColumn get messageId => text()();

  TextColumn get sosId => text()();

  TextColumn get ownerId => text()();

  TextColumn get senderId => text()();

  TextColumn get recipientId => text().nullable()();

  TextColumn get messageType => text()();

  TextColumn get textContent => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  TextColumn get deliveryStatus => text()();

  TextColumn get attachmentPath => text().nullable()();

  TextColumn get attachmentMimeType => text().nullable()();

  TextColumn get attachmentName => text().nullable()();

  TextColumn get remoteMessageId => text().nullable()();

  TextColumn get transportMetadata => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {messageId};
}
