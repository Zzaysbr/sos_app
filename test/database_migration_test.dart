import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';

import 'generated_schema.dart/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUp(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v9 upgrades preserving archived candidates and queued Chat', () async {
    final schema = await verifier.schemaAt(9);
    addTearDown(schema.close);
    schema.rawDatabase.execute(
      "INSERT INTO chat_relay_outbox VALUES ('owner','message','incident','sender','recipient','payload','queued',1,2,NULL,1000,100,101,NULL)",
    );
    schema.rawDatabase.execute(
      "INSERT INTO rescue_inbox VALUES ('owner','origin','incident','key','digest','emergency','saved',0,NULL,NULL,0,'[]',100,1000,100,'archivedLocally',NULL,NULL)",
    );
    final db = AppDatabase.forTesting(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(
      db,
      10,
      options: const ValidationOptions(validateDropped: true),
    );
    expect(
      (await db.select(db.rescueInbox).getSingle()).state,
      'archivedLocally',
    );
    expect((await db.select(db.chatRelayOutbox).getSingle()).retryCount, 2);
    expect(await db.select(db.chatReceipts).get(), isEmpty);
  });

  test('authoritative v5 schema migrates to v10 without data loss', () async {
    final schema = await verifier.schemaAt(5);
    addTearDown(schema.close);
    final raw = schema.rawDatabase;

    raw.execute('''
      INSERT INTO sos_messages VALUES
      ('sos-v5', 'guest-owner', 'emergency', 'need help', 13.7563, 100.5018,
       'active', 'local', 100, 101)
    ''');
    raw.execute('''
      INSERT INTO sos_sync_queue VALUES
      (7, 'sos-v5', 'guest-owner', 'create', '{"safe":true}', 102)
    ''');
    raw.execute('''
      INSERT INTO ble_outbox VALUES
      ('out-v5', 'sos-v5', 'peer-b', 1, '{"out":true}', 'queued', 2,
       103, 104, 'retryable', 105, 106, 107)
    ''');
    raw.execute('''
      INSERT INTO ble_inbox VALUES
      ('in-v5', 'sos-v5', 'peer-a', 1, '{"in":true}', 'persisted',
       108, 109, 'acknowledged')
    ''');
    raw.execute('''
      INSERT INTO chat_messages VALUES
      ('chat-v5', 'sos-v5', 'guest-owner', 'peer-a', 'peer-b', 'text',
       'preserve chat', 110, 'delivered', '/tmp/test-only', 'text/plain',
       'note.txt', 'remote-v5', '{"transport":"ble"}')
    ''');

    final migrated = AppDatabase.forTesting(schema.newConnection());
    addTearDown(migrated.close);
    await verifier.migrateAndValidate(
      migrated,
      10,
      options: const ValidationOptions(validateDropped: true),
    );

    final sos = await migrated.select(migrated.sosMessages).getSingle();
    expect(sos.id, 'sos-v5');
    expect(sos.ownerId, 'guest-owner');
    expect(sos.type, 'emergency');
    expect(sos.message, 'need help');
    expect(sos.latitude, 13.7563);
    expect(sos.longitude, 100.5018);
    expect(sos.status, 'active');
    expect(sos.syncState, 'local');

    final sync = await migrated.select(migrated.sosSyncQueue).getSingle();
    expect(sync.queueId, 7);
    expect(sync.sosId, 'sos-v5');
    expect(sync.ownerId, 'guest-owner');
    expect(sync.operation, 'create');
    expect(sync.payload, '{"safe":true}');

    final outbox = await migrated.select(migrated.bleOutbox).getSingle();
    expect(outbox.messageId, 'out-v5');
    expect(outbox.destinationId, 'peer-b');
    expect(outbox.schemaVersion, 1);
    expect(outbox.payload, '{"out":true}');
    expect(outbox.state, 'queued');
    expect(outbox.retryCount, 2);
    expect(outbox.lastError, 'retryable');
    expect(outbox.acknowledgedAt != null, isTrue);

    final inbox = await migrated.select(migrated.bleInbox).getSingle();
    expect(inbox.messageId, 'in-v5');
    expect(inbox.senderDeviceId, 'peer-a');
    expect(inbox.payload, '{"in":true}');
    expect(inbox.processingState, 'persisted');
    expect(inbox.persistedAt != null, isTrue);
    expect(inbox.acknowledgementStatus, 'acknowledged');

    final chat = await migrated.select(migrated.chatMessages).getSingle();
    expect(chat.messageId, 'chat-v5');
    expect(chat.sosId, 'sos-v5');
    expect(chat.ownerId, 'guest-owner');
    expect(chat.senderId, 'peer-a');
    expect(chat.recipientId, 'peer-b');
    expect(chat.messageType, 'text');
    expect(chat.textContent, 'preserve chat');
    expect(chat.deliveryStatus, 'delivered');
    expect(chat.attachmentPath, '/tmp/test-only');
    expect(chat.attachmentMimeType, 'text/plain');
    expect(chat.attachmentName, 'note.txt');
    expect(chat.remoteMessageId, 'remote-v5');
    expect(chat.transportMetadata, '{"transport":"ble"}');

    expect(await migrated.select(migrated.bleRelayMessages).get(), isEmpty);
    expect(await migrated.select(migrated.bleRelayAttempts).get(), isEmpty);
    expect(await migrated.select(migrated.bleRelayReceipts).get(), isEmpty);
  });

  test('authoritative v7 schema upgrades to v10 and validates', () async {
    final connection = await verifier.startAt(7);
    final database = AppDatabase.forTesting(connection);
    addTearDown(database.close);

    await verifier.migrateAndValidate(
      database,
      10,
      options: const ValidationOptions(validateDropped: true),
    );
    expect(await database.select(database.sosMessages).get(), isEmpty);
    expect(await database.select(database.bleRelayMessages).get(), isEmpty);
  });

  test(
    'failed v5 migration rolls back schema and preserves old rows',
    () async {
      final schema = await verifier.schemaAt(5);
      addTearDown(schema.close);
      final raw = schema.rawDatabase;
      raw.execute('''
      INSERT INTO sos_messages VALUES
      ('rollback-v5', 'owner', 'emergency', NULL, 1.0, 2.0,
       'active', 'local', 200, 201)
    ''');
      final database = _FailingMigrationDatabase(schema.newConnection());
      await expectLater(
        verifier.migrateAndValidate(database, 10),
        throwsA(anything),
      );
      await database.close();

      expect(raw.userVersion, 5);
      expect(
        raw.select('SELECT id, latitude, longitude FROM sos_messages').single,
        {'id': 'rollback-v5', 'latitude': 1.0, 'longitude': 2.0},
      );
      expect(
        raw.select(
          "SELECT name FROM sqlite_schema WHERE type = 'table' "
          "AND name IN ('ble_relay_messages', 'ble_relay_attempts', "
          "'ble_relay_receipts')",
        ),
        isEmpty,
      );
    },
  );
}

class _FailingMigrationDatabase extends AppDatabase {
  _FailingMigrationDatabase(super.executor) : super.forTesting();

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      await transaction(() async {
        if (from < 6) {
          await migrator.createTable(bleRelayMessages);
          throw StateError('Injected migration failure');
        }
      });
    },
  );
}
