import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

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

  test('schema 5 creates BLE and chat tables and preserves SOS rows', () async {
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

    expect(database.schemaVersion, 5);
    expect(await database.select(database.bleOutbox).get(), isEmpty);
    expect(await database.select(database.bleInbox).get(), isEmpty);
    expect(await database.select(database.chatMessages).get(), isEmpty);
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
    expect(migrated.schemaVersion, 5);
    expect(await migrated.select(migrated.bleOutbox).get(), isEmpty);
    expect(await migrated.select(migrated.bleInbox).get(), isEmpty);
    expect(await migrated.select(migrated.chatMessages).get(), isEmpty);
    expect(
      (await migrated.select(migrated.sosMessages).getSingle()).id,
      'old-sos',
    );
    await migrated.close();
  });

  test('migrates a version 1 database through all delivery tables', () async {
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
        db.execute('PRAGMA user_version = 1');
        db.execute(
          'INSERT INTO sos_messages '
          '(id, owner_id, type, status, sync_state, created_at, updated_at) '
          "VALUES ('v1-sos', 'owner', 'emergency', 'active', 'local', 0, 0)",
        );
      },
    );

    final migrated = AppDatabase.forTesting(oldExecutor);
    expect(migrated.schemaVersion, 5);
    expect(await migrated.select(migrated.sosSyncQueue).get(), isEmpty);
    expect(await migrated.select(migrated.bleOutbox).get(), isEmpty);
    expect(await migrated.select(migrated.bleInbox).get(), isEmpty);
    expect(await migrated.select(migrated.chatMessages).get(), isEmpty);
    expect(
      (await migrated.select(migrated.sosMessages).getSingle()).id,
      'v1-sos',
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

  test('outbox accepts chat envelopes', () async {
    final chat = SosBleEnvelope.chatMessage(
      messageId: 'chat-1',
      sosId: 'sos-1',
      senderDeviceId: 'device-a',
      chatSenderId: 'owner-a',
      chatText: 'Status update',
      createdAt: DateTime.utc(2026),
    );
    final row = await repository.enqueueOutbox(chat);
    expect(row.messageId, 'chat-1');
    expect(row.sosId, 'sos-1');
  });

  test('reconciles an active SOS that has no BLE outbox row', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'recover-sos',
            ownerId: 'owner-1',
            type: 'emergency',
            message: const Value('Help'),
            latitude: const Value(13.7),
            longitude: const Value(100.5),
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(
      await repository.reconcileMissingSosOutbox(ownerId: 'owner-1', now: now),
      1,
    );
    final row = await repository.lookupOutbox('sos:recover-sos:delivery:v1');
    expect(row, isNotNull);
    expect(row!.destinationId, isNull);
    expect(row.state, BleOutboxState.queued.wireValue);
  });

  test(
    'reconciliation is idempotent and preserves an assigned destination',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'assigned-sos',
              ownerId: 'owner-1',
              type: 'emergency',
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await repository.enqueueOutbox(
        _delivery(messageId: 'legacy-delivery', sosId: 'assigned-sos'),
        destinationId: 'peer-a',
        now: now,
      );

      expect(
        await repository.reconcileMissingSosOutbox(
          ownerId: 'owner-1',
          now: now,
        ),
        0,
      );
      expect(
        (await repository.lookupOutbox('legacy-delivery'))!.destinationId,
        'peer-a',
      );
      expect(await database.select(database.bleOutbox).get(), hasLength(1));
    },
  );

  test(
    'reconciliation skips cancelled SOS records and terminal deliveries',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'cancelled-sos',
              ownerId: 'owner-1',
              type: 'emergency',
              status: 'cancelled',
              syncState: 'synced',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'terminal-sos',
              ownerId: 'owner-1',
              type: 'emergency',
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await repository.enqueueOutbox(
        _delivery(messageId: 'terminal-delivery', sosId: 'terminal-sos'),
        destinationId: 'peer-1',
        now: now,
      );
      await repository.transitionOutboxState(
        'terminal-delivery',
        BleOutboxState.sending,
        now: now,
      );
      await repository.transitionOutboxState(
        'terminal-delivery',
        BleOutboxState.acknowledged,
        now: now,
      );

      expect(
        await repository.reconcileMissingSosOutbox(
          ownerId: 'owner-1',
          now: now,
        ),
        0,
      );
      expect(await database.select(database.bleOutbox).get(), hasLength(1));
      expect(
        (await repository.lookupOutbox('terminal-delivery'))!.state,
        BleOutboxState.acknowledged.wireValue,
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
      await repository.enqueueOutbox(
        _delivery(),
        destinationId: 'peer-1',
        now: now,
      );

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

  test('concurrent outbox claims allow only one sender', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await repository.enqueueOutbox(
      _delivery(messageId: 'claim-message'),
      destinationId: 'peer-1',
      now: now,
    );

    final claims = await Future.wait([
      repository.claimOutboxForSending('claim-message', now: now),
      repository.claimOutboxForSending('claim-message', now: now),
    ]);
    expect(claims.whereType<BleOutboxData>(), hasLength(1));
    final row = await repository.lookupOutbox('claim-message');
    expect(row!.state, BleOutboxState.sending.wireValue);
    expect(row.retryCount, 1);
  });

  test(
    'file-backed SOS and recovered outbox survive a database restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sos-app-recovery-',
      );
      final file = File('${directory.path}/database.sqlite');
      final now = DateTime.utc(2026, 1, 1);
      try {
        final first = AppDatabase.forTesting(NativeDatabase(file));
        final firstRepository = BleDeliveryRepository(first);
        await first
            .into(first.sosMessages)
            .insert(
              SosMessagesCompanion.insert(
                id: 'restart-sos',
                ownerId: 'owner-1',
                type: 'emergency',
                status: 'active',
                syncState: 'pending',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await firstRepository.reconcileMissingSosOutbox(
          ownerId: 'owner-1',
          now: now,
        );
        await first.close();

        final second = AppDatabase.forTesting(NativeDatabase(file));
        final secondRepository = BleDeliveryRepository(second);
        final row = await secondRepository.lookupOutbox(
          'sos:restart-sos:delivery:v1',
        );
        expect(row, isNotNull);
        expect(row!.state, BleOutboxState.queued.wireValue);
        expect(row.destinationId, isNull);
        expect(
          await second
              .select(second.sosMessages)
              .getSingle()
              .then((sos) => sos.id),
          'restart-sos',
        );
        await second.close();
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  test(
    'outbox without a destination waits until a route is assigned',
    () async {
      final row = await repository.enqueueOutbox(_delivery());
      expect(await repository.dueOutbox(), isEmpty);

      await repository.assignDestinationIfMissing(row.messageId, 'peer-1');
      expect((await repository.dueOutbox()).single.destinationId, 'peer-1');
    },
  );

  test('blank destinations are normalized and can be resolved later', () async {
    final row = await repository.enqueueOutbox(
      _delivery(messageId: 'blank-destination'),
      destinationId: '   ',
    );
    expect(row.destinationId, isNull);
    await repository.assignDestinationIfMissing(row.messageId, ' peer-2 ');
    expect(
      (await repository.lookupOutbox(row.messageId))!.destinationId,
      'peer-2',
    );
  });

  test(
    'destination assignment cannot redirect an in-flight delivery',
    () async {
      final row = await repository.enqueueOutbox(
        _delivery(messageId: 'in-flight'),
      );
      await repository.transitionOutboxState(
        row.messageId,
        BleOutboxState.sending,
      );

      final unchanged = await repository.assignDestinationIfMissing(
        row.messageId,
        'peer-2',
      );

      expect(unchanged.state, BleOutboxState.sending.wireValue);
      expect(unchanged.destinationId, isNull);
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

  test('a peer ACK cannot claim an unassigned outbox row', () async {
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
    await repository.transitionOutboxState(
      'message-1',
      BleOutboxState.awaitingAcknowledgement,
      now: now,
    );
    final ack = SosBleEnvelope.acknowledgement(
      messageId: 'ack-unassigned',
      sosId: 'sos-1',
      ackFor: 'message-1',
      ackStatus: SosBleAckStatus.persisted,
      createdAt: now,
    );

    await expectLater(
      repository.recordAcknowledgement(
        ack,
        sourceDeviceId: 'unexpected-peer',
        now: now,
      ),
      throwsA(isA<BleDeliveryStateException>()),
    );
    expect(
      (await repository.lookupOutbox('message-1'))!.state,
      BleOutboxState.awaitingAcknowledgement.wireValue,
    );
  });

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
