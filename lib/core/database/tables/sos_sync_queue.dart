import 'package:drift/drift.dart';

class SosSyncQueue extends Table {
  IntColumn get queueId => integer().autoIncrement()();

  TextColumn get sosId => text()();

  TextColumn get ownerId => text()();

  // Pending operations: create, update, delete. deleteConfirmed is a retained
  // owner-scoped deletion marker, excluded from uploads, preventing restoration
  // from an older archive snapshot. No schema change is required.
  TextColumn get operation => text()();

  // Snapshot of the SOS data at the time the operation was queued.
  TextColumn get payload => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
