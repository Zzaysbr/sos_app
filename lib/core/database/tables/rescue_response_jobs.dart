import 'package:drift/drift.dart';

/// Store-and-forward attempts and their authenticated route binding.
class RescueResponseJobs extends Table {
  TextColumn get ownerId => text()();
  TextColumn get responseMessageId => text()();
  TextColumn get nextHopKeyId => text()();
  TextColumn get nextHopDeviceId => text()();
  TextColumn get sessionBinding => text()();
  TextColumn get state => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {
    ownerId,
    responseMessageId,
    nextHopKeyId,
  };
}
