import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_delivery_state.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';

SosBleEnvelope _delivery({
  String messageId = 'message-1',
  String sosId = 'sos-1',
  String text = 'Help',
}) => SosBleEnvelope.delivery(
  messageId: messageId,
  sosId: sosId,
  sosType: 'emergency',
  status: 'active',
  message: text,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
);

void main() {
  late AppDatabase database;
  late BleDeliveryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BleDeliveryRepository(database);
  });

  tearDown(() async => database.close());

  test('schema 3 creates BLE tables and preserves SOS rows', () async {
    final now = DateTime.utc(2026);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'existing-sos',
            ownerId: 'owner',
            type: 'emergency',
            status: 'active',
            syncState: 'synced',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(database.schemaVersion, 3);
    expect(await database.select(database.bleOutbox).get(), isEmpty);
    expect(await database.select(database.bleInbox).get(), isEmpty);
    expect(
      (await database.select(database.sosMessages).getSingle()).id,
      'existing-sos',
    );
  });

  test('migrates a version 2 database and preserves existing tables', () async {
    final oldExecutor = NativeDatabase.memory(
      setup: (db) {
        db.execute('''
      CREATE TABLE sos_messages (
        id TEXT NOT NULL PRIMARY KEY,
        owner_id TEXT NOT NULL,
        type TEXT NOT NULL,
        message TEXT,
        latitude REAL,
        longitude REAL,
        status TEXT NOT NULL,
        sync_state TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
        db.execute('''
      CREATE TABLE sos_sync_queue (
        queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
        sos_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
        db.execute('PRAGMA user_version = 2');
        db.execute(
          'INSERT INTO sos_messages '
          '(id, owner_id, type, status, sync_state, created_at, updated_at) '
          "VALUES ('old-sos', 'owner', 'emergency', 'active', 'synced', 0, 0)",
        );
      },
    );

    final migrated = AppDatabase.forTesting(oldExecutor);
    expect(migrated.schemaVersion, 3);
    expect(await migrated.select(migrated.bleOutbox).get(), isEmpty);
    expect(await migrated.select(migrated.bleInbox).get(), isEmpty);
    expect(
      (await migrated.select(migrated.sosMessages).getSingle()).id,
      'old-sos',
    );
    await migrated.close();
  });

  test(
    'outbox messageId is idempotent and conflicting reuse is rejected',
    () async {
      final first = await repository.enqueueOutbox(_delivery());
      final duplicate = await repository.enqueueOutbox(_delivery());

      expect(first.messageId, duplicate.messageId);
      expect(await database.select(database.bleOutbox).get(), hasLength(1));
      expect(
        () => repository.enqueueOutbox(_delivery(text: 'Different payload')),
        throwsA(isA<BleDeliveryStateException>()),
      );
    },
  );

  test('inbox duplicate delivery is inserted once', () async {
    final first = await repository.insertInboxDelivery(_delivery());
    final duplicate = await repository.insertInboxDelivery(_delivery());

    expect(first.inserted, isTrue);
    expect(duplicate.inserted, isFalse);
    expect(await database.select(database.bleInbox).get(), hasLength(1));
  });

  test('rolls back inbox when sosId belongs to another owner', () async {
    final now = DateTime.utc(2026);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'sos-1',
            ownerId: 'different-owner',
            type: 'emergency',
            message: const Value('Help'),
            latitude: const Value(13.7),
            longitude: const Value(100.5),
            status: 'active',
            syncState: 'synced',
            createdAt: now,
            updatedAt: now.add(const Duration(minutes: 1)),
          ),
        );

    expect(
      () => repository.persistIncomingDelivery(
        _delivery(),
        ownerId: 'owner-1',
        now: now,
      ),
      throwsA(isA<BleDeliveryStateException>()),
    );
    expect(await database.select(database.bleInbox).get(), isEmpty);
  });

  test(
    'outbox states reject illegal transitions and select due retries',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      await repository.enqueueOutbox(_delivery(), now: now);

      expect(
        () => repository.transitionOutboxState(
          'message-1',
          BleOutboxState.acknowledged,
          now: now,
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );

      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.sending,
        now: now,
      );
      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.failed,
        now: now,
        nextRetryAt: now.add(const Duration(minutes: 5)),
        error: 'temporary failure',
      );

      expect(await repository.dueOutbox(now: now), isEmpty);
      final due = await repository.dueOutbox(
        now: now.add(const Duration(minutes: 5)),
      );
      expect(due.single.messageId, 'message-1');
      expect(due.single.retryCount, 1);
    },
  );

  test(
    'remote persisted ACK is recorded separately from write acceptance',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      await repository.enqueueOutbox(_delivery(), now: now);
      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.sending,
        now: now,
      );
      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.writeAccepted,
        now: now,
      );

      final afterWrite = await repository.lookupOutbox('message-1');
      expect(afterWrite!.state, BleOutboxState.writeAccepted.wireValue);
      expect(afterWrite.acknowledgedAt, isNull);

      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.awaitingAcknowledgement,
        now: now,
      );
      final ack = SosBleEnvelope.acknowledgement(
        messageId: 'ack-1',
        sosId: 'sos-1',
        ackFor: 'message-1',
        ackStatus: SosBleAckStatus.persisted,
        createdAt: now,
      );
      final acknowledged = await repository.recordAcknowledgement(
        ack,
        now: now,
      );

      expect(acknowledged.state, BleOutboxState.acknowledged.wireValue);
      expect(acknowledged.acknowledgedAt?.toUtc(), now);
    },
  );

  test(
    'recovers stale in-progress outbox work without changing messageId',
    () async {
      final start = DateTime.utc(2026, 1, 1, 12);
      await repository.enqueueOutbox(_delivery(), now: start);
      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.sending,
        now: start,
      );
      final recovered = await repository.recoverStaleOutbox(
        olderThan: start.add(const Duration(seconds: 1)),
        nextRetryAt: start.add(const Duration(minutes: 1)),
        now: start.add(const Duration(seconds: 2)),
      );

      expect(recovered, 1);
      final row = await repository.lookupOutbox('message-1');
      expect(row!.state, BleOutboxState.failed.wireValue);
      expect(row.messageId, 'message-1');
      expect(row.nextRetryAt?.toUtc(), start.add(const Duration(minutes: 1)));
    },
  );

  test(
    'inbox can transition to persisted ACK state but never becomes an SOS row',
    () async {
      await repository.insertInboxDelivery(_delivery());
      final row = await repository.transitionInboxState(
        'message-1',
        BleInboxState.persisted,
      );

      expect(row.processingState, BleInboxState.persisted.wireValue);
      expect(
        row.acknowledgementStatus,
        BleAcknowledgementStatus.persisted.wireValue,
      );
      expect(await database.select(database.sosMessages).get(), isEmpty);
    },
  );
}
