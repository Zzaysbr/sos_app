import 'package:drift/drift.dart';

/// Verified voluntary-rescue candidates, separate from relay rows and SOS history.
class RescueInbox extends Table {
  TextColumn get ownerId => text()();
  TextColumn get originMessageId => text()();
  TextColumn get incidentId => text()();
  TextColumn get originKeyId => text()();
  TextColumn get immutableDigest => text()();
  TextColumn get emergencyType => text()();
  TextColumn get emergencyMessage => text()();
  BoolColumn get includeLocation => boolean()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  IntColumn get incomingHopCount => integer()();
  TextColumn get incomingPath => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get receivedAt => dateTime()();
  TextColumn get state => text()();
  TextColumn get acceptanceId => text().nullable()();
  DateTimeColumn get acceptedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {ownerId, originMessageId};
}
