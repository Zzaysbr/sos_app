import 'package:drift/drift.dart';

/// Replay/deduplication records. Kept owner-scoped and separate from SOS history.
class RescueResponseReplay extends Table {
  TextColumn get ownerId => text()();
  TextColumn get messageId => text()();
  TextColumn get immutableDigest => text()();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, messageId};
}
