import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/sos_messages.dart';
import 'tables/sos_sync_queue.dart';
import 'tables/ble_inbox.dart';
import 'tables/ble_outbox.dart';
import 'tables/ble_relay_attempts.dart';
import 'tables/ble_relay_messages.dart';
import 'tables/ble_relay_receipts.dart';
import 'tables/chat_messages.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    SosMessages,
    SosSyncQueue,
    BleOutbox,
    BleInbox,
    ChatMessages,
    BleRelayMessages,
    BleRelayAttempts,
    BleRelayReceipts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    onUpgrade: (migrator, from, to) async {
      await transaction(() async {
        if (from < 2) {
          await migrator.createTable(sosSyncQueue);
        }
        if (from < 3) {
          await migrator.createTable(bleOutbox);
          await migrator.createTable(bleInbox);
        }
        if (from < 4) {
          await migrator.createTable(chatMessages);
        } else if (from < 5) {
          await migrator.addColumn(chatMessages, chatMessages.recipientId);
        }
        if (from < 6) {
          await migrator.createTable(bleRelayMessages);
          await migrator.createTable(bleRelayAttempts);
          await migrator.createTable(bleRelayReceipts);
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'sos_app');
  }
}
