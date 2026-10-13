import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/sos_messages.dart';
import 'tables/sos_sync_queue.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [SosMessages, SosSyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(sosSyncQueue);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sos_app');
  }
}
