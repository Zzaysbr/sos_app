
import 'package:drift/drift.dart';

class SosSyncQueue extends Table {
  IntColumn get queueId => integer().autoIncrement()();

  TextColumn get sosId => text()();

  TextColumn get ownerId => text()();

  // Supported operations: create, update, delete.
  TextColumn get operation => text()();

  // Snapshot of the SOS data at the time the operation was queued.
  TextColumn get payload => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}