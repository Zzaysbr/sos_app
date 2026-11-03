import 'dart:convert';
import 'dart:io';

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

SosBleEnvelope _chat({
  String messageId = 'chat-legacy',
  String sosId = 'sos-1',
}) => SosBleEnvelope.chatMessage(
  messageId: messageId,
  sosId: sosId,
  senderDeviceId: 'sender-installation',
  chatSenderId: 'owner-1',
  chatText: 'Still need help',
  createdAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late AppDatabase database;
  late BleDeliveryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BleDeliveryRepository(database);
  });

  tearDown(() async => database.close());

  test('schema 9 creates BLE, relay, rescue, response, and chat tables and preserves SOS rows', () async {
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

    expect(database.schemaVersion, 9);
    expect(await database.select(database.bleOutbox).get(), isEmpty);
    expect(await database.select(database.bleInbox).get(), isEmpty);
    expect(await database.select(database.chatMessages).get(), isEmpty);
    expect(await database.select(database.bleRelayMessages).get(), isEmpty);
    expect(await database.select(database.bleRelayAttempts).get(), isEmpty);
    expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
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
    expect(migrated.schemaVersion, 9);
    expect(await migrated.select(migrated.bleOutbox).get(), isEmpty);
    expect(await migrated.select(migrated.bleInbox).get(), isEmpty);
    expect(await migrated.select(migrated.chatMessages).get(), isEmpty);
    expect(await migrated.select(migrated.bleRelayMessages).get(), isEmpty);
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
    expect(migrated.schemaVersion, 9);
    expect(await migrated.select(migrated.sosSyncQueue).get(), isEmpty);
    expect(await migrated.select(migrated.bleOutbox).get(), isEmpty);
    expect(await migrated.select(migrated.bleInbox).get(), isEmpty);
    expect(await migrated.select(migrated.chatMessages).get(), isEmpty);
    expect(await migrated.select(migrated.bleRelayMessages).get(), isEmpty);
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
    'explicit legacy Chat recovery preserves identity and owner scope',
    () async {
      final envelope = _chat();
      final before = await repository.enqueueOutbox(envelope);
      await database
          .into(database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              ownerId: 'owner-1',
              senderId: 'sender-installation',
              messageType: 'text',
              textContent: const Value('Still need help'),
              createdAt: envelope.createdAt,
              deliveryStatus: 'failed',
            ),
          );

      expect(
        await repository.assignUnroutedChatDestination(
          ownerId: 'other-owner',
          sosId: envelope.sosId,
          destinationId: 'wrong-peer',
        ),
        0,
      );
      expect(
        (await repository.lookupOutbox(envelope.messageId))!.destinationId,
        isNull,
      );

      expect(
        await repository.assignUnroutedChatDestination(
          ownerId: 'owner-1',
          sosId: envelope.sosId,
          destinationId: ' selected-peer ',
        ),
        1,
      );

      final recovered = (await repository.lookupOutbox(envelope.messageId))!;
      final chat = await database.select(database.chatMessages).getSingle();
      expect(recovered.messageId, before.messageId);
      expect(recovered.payload, before.payload);
      expect(recovered.destinationId, 'selected-peer');
      expect(recovered.state, BleOutboxState.queued.wireValue);
      expect(chat.ownerId, 'owner-1');
      expect(chat.senderId, 'sender-installation');
      expect(chat.recipientId, 'selected-peer');
      expect(chat.deliveryStatus, 'pending');
      expect(
        await repository.assignUnroutedChatDestination(
          ownerId: 'owner-1',
          sosId: envelope.sosId,
          destinationId: 'another-peer',
        ),
        0,
        reason: 'An explicit recovery must not redirect an assigned message.',
      );
    },
  );

  test(
    'legacy Chat recovery rejects wrong incident, non-Chat, and in-flight rows',
    () async {
      final chat = _chat(messageId: 'legacy-chat-race');
      await repository.enqueueOutbox(chat);
      await database
          .into(database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: chat.messageId,
              sosId: chat.sosId,
              ownerId: 'owner-1',
              senderId: 'sender-installation',
              messageType: 'text',
              textContent: const Value('Still need help'),
              createdAt: chat.createdAt,
              deliveryStatus: 'failed',
            ),
          );
      final delivery = _delivery(messageId: 'not-chat');
      await repository.enqueueOutbox(delivery);
      await database
          .into(database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: delivery.messageId,
              sosId: delivery.sosId,
              ownerId: 'owner-1',
              senderId: 'sender-installation',
              messageType: 'text',
              textContent: const Value('Not a Chat envelope'),
              createdAt: delivery.createdAt,
              deliveryStatus: 'failed',
            ),
          );

      expect(
        await repository.assignUnroutedChatDestination(
          ownerId: 'owner-1',
          sosId: 'other-incident',
          destinationId: 'peer-1',
        ),
        0,
      );
      expect(
        await repository.assignUnroutedChatDestination(
          ownerId: 'owner-1',
          sosId: chat.sosId,
          destinationId: 'peer-1',
        ),
        1,
      );
      expect(
        (await repository.lookupOutbox(delivery.messageId))!.destinationId,
        isNull,
      );

      final inFlight = _chat(messageId: 'legacy-chat-in-flight');
      await repository.enqueueOutbox(inFlight);
      await database
          .into(database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: inFlight.messageId,
              sosId: inFlight.sosId,
              ownerId: 'owner-1',
              senderId: 'sender-installation',
              messageType: 'text',
              textContent: const Value('Already being sent'),
              createdAt: inFlight.createdAt,
              deliveryStatus: 'pending',
            ),
          );
      await repository.transitionOutboxState(
        inFlight.messageId,
        BleOutboxState.sending,
      );
      expect(
        await repository.assignUnroutedChatDestination(
          ownerId: 'owner-1',
          sosId: inFlight.sosId,
          destinationId: 'peer-2',
        ),
        0,
      );
      expect(
        (await repository.lookupOutbox(inFlight.messageId))!.destinationId,
        isNull,
      );
    },
  );

  test('concurrent legacy Chat recovery assigns exactly one peer', () async {
    final chat = _chat(messageId: 'legacy-chat-concurrent');
    await repository.enqueueOutbox(chat);
    await database
        .into(database.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            messageId: chat.messageId,
            sosId: chat.sosId,
            ownerId: 'owner-1',
            senderId: 'sender-installation',
            messageType: 'text',
            textContent: const Value('Select exactly one peer'),
            createdAt: chat.createdAt,
            deliveryStatus: 'failed',
          ),
        );

    final results = await Future.wait([
      repository.assignUnroutedChatDestination(
        ownerId: 'owner-1',
        sosId: chat.sosId,
        destinationId: 'peer-a',
      ),
      repository.assignUnroutedChatDestination(
        ownerId: 'owner-1',
        sosId: chat.sosId,
        destinationId: 'peer-b',
      ),
    ]);

    expect(results.reduce((left, right) => left + right), 1);
    final outbox = (await repository.lookupOutbox(chat.messageId))!;
    final persistedChat = await database
        .select(database.chatMessages)
        .getSingle();
    expect(outbox.destinationId, anyOf('peer-a', 'peer-b'));
    expect(persistedChat.recipientId, outbox.destinationId);
    expect(outbox.state, BleOutboxState.queued.wireValue);
    expect((await repository.dueOutbox()).single.messageId, chat.messageId);
  });

  test('assigned legacy Chat remains due after database restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sos-chat-route-recovery-',
    );
    final file = File('${directory.path}/database.sqlite');
    final chat = _chat(messageId: 'legacy-chat-after-restart');
    try {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      final firstRepository = BleDeliveryRepository(first);
      await firstRepository.enqueueOutbox(chat);
      await first
          .into(first.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: chat.messageId,
              sosId: chat.sosId,
              ownerId: 'owner-1',
              senderId: 'sender-installation',
              messageType: 'text',
              textContent: const Value('Survive coordinator startup failure'),
              createdAt: chat.createdAt,
              deliveryStatus: 'failed',
            ),
          );
      expect(
        await firstRepository.assignUnroutedChatDestination(
          ownerId: 'owner-1',
          sosId: chat.sosId,
          destinationId: 'selected-peer',
        ),
        1,
      );
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      final secondRepository = BleDeliveryRepository(second);
      final due = await secondRepository.dueOutbox(ownerId: 'owner-1');
      expect(due, hasLength(1));
      expect(due.single.messageId, chat.messageId);
      expect(due.single.destinationId, 'selected-peer');
      expect(due.single.payload, jsonEncode(chat.toJson()));
      await second.close();
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test('SOS delivery watcher ignores older Chat rows', () async {
    final chat = _chat(messageId: 'chat-before-sos');
    await repository.enqueueOutbox(
      chat,
      destinationId: 'peer-1',
      now: DateTime.utc(2026, 1, 1),
    );
    final delivery = _delivery(messageId: 'sos-delivery-after-chat');
    await repository.enqueueOutbox(
      delivery,
      destinationId: 'peer-1',
      now: DateTime.utc(2026, 1, 1, 0, 1),
    );

    final watched = await repository.watchDeliveryForSos('sos-1').first;

    expect(watched?.messageId, delivery.messageId);
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
      await repository.enqueueOutbox(
        _delivery(),
        destinationId: 'selected-peer',
        now: now,
      );
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
        sourceDeviceId: 'selected-peer',
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
    'SOS ACK without an observed native peer cannot confirm delivery',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      await repository.enqueueOutbox(
        _delivery(messageId: 'peerless-sos-ack'),
        destinationId: 'selected-peer',
        now: now,
      );
      await repository.claimOutboxForSending('peerless-sos-ack', now: now);
      final ack = SosBleEnvelope.acknowledgement(
        messageId: 'ack-peerless-sos',
        sosId: 'sos-1',
        ackFor: 'peerless-sos-ack',
        ackStatus: SosBleAckStatus.persisted,
        createdAt: now,
      );

      await expectLater(
        repository.recordAcknowledgement(ack, now: now),
        throwsA(isA<BleDeliveryStateException>()),
      );
      expect(
        (await repository.lookupOutbox('peerless-sos-ack'))!.state,
        BleOutboxState.sending.wireValue,
      );
    },
  );

  test('SOS ACK confirms only the message named by ackFor', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    await repository.enqueueOutbox(
      _delivery(messageId: 'sos-target', sosId: 'incident-target'),
      destinationId: 'selected-peer',
      now: now,
    );
    await repository.enqueueOutbox(
      _delivery(messageId: 'sos-other', sosId: 'incident-other'),
      destinationId: 'selected-peer',
      now: now,
    );
    await repository.claimOutboxForSending('sos-target', now: now);
    await repository.claimOutboxForSending('sos-other', now: now);

    await repository.recordAcknowledgement(
      SosBleEnvelope.acknowledgement(
        messageId: 'ack-other-only',
        sosId: 'incident-other',
        ackFor: 'sos-other',
        ackStatus: SosBleAckStatus.persisted,
        createdAt: now,
      ),
      sourceDeviceId: 'selected-peer',
      now: now,
    );

    expect(
      (await repository.lookupOutbox('sos-target'))!.state,
      BleOutboxState.sending.wireValue,
    );
    expect(
      (await repository.lookupOutbox('sos-other'))!.state,
      BleOutboxState.acknowledged.wireValue,
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
  SosBleEnvelope ack({SosBleAckStatus status = SosBleAckStatus.persisted}) =>
      SosBleEnvelope.acknowledgement(
        messageId: 'ack-race',
        sosId: 'sos-1',
        ackFor: 'message-1',
        ackStatus: status,
        createdAt: DateTime.utc(2026),
      );

  Future<void> sending() async {
    await repository.enqueueOutbox(_delivery(), destinationId: 'selected-peer');
    await repository.claimOutboxForSending('message-1');
  }

  test(
    'early persisted ACK survives a later native write completion',
    () async {
      await sending();
      final confirmed = await repository.recordAcknowledgement(
        ack(),
        sourceDeviceId: 'selected-peer',
      );
      final completed = await repository.finishWriting('message-1');
      expect(completed.state, 'acknowledged');
      expect(completed.acknowledgedAt, confirmed.acknowledgedAt);
      expect(completed.retryCount, 1);
    },
  );

  test(
    'write completion without ACK remains awaiting, never confirmed',
    () async {
      await sending();
      final completed = await repository.finishWriting('message-1');
      expect(completed.state, 'awaitingAcknowledgement');
      expect(completed.acknowledgedAt, isNull);
    },
  );

  test(
    'delayed selected-peer ACK can confirm a timed-out failed attempt',
    () async {
      await sending();
      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.failed,
      );
      final completed = await repository.recordAcknowledgement(
        ack(),
        sourceDeviceId: 'selected-peer',
      );
      expect(completed.state, 'acknowledged');
      expect(completed.retryCount, 1);
    },
  );

  test('delayed wrong-peer ACK cannot confirm a failed attempt', () async {
    await sending();
    await repository.transitionOutboxState('message-1', BleOutboxState.failed);
    await expectLater(
      repository.recordAcknowledgement(ack(), sourceDeviceId: 'other-peer'),
      throwsA(isA<BleDeliveryStateException>()),
    );
    expect((await repository.lookupOutbox('message-1'))!.state, 'failed');
  });

  test('negative duplicate ACK cannot regress confirmed delivery', () async {
    await sending();
    final confirmed = await repository.recordAcknowledgement(
      ack(),
      sourceDeviceId: 'selected-peer',
    );
    final duplicate = await repository.recordAcknowledgement(
      ack(status: SosBleAckStatus.rejected),
      sourceDeviceId: 'selected-peer',
    );
    expect(duplicate.state, 'acknowledged');
    expect(duplicate.acknowledgedAt, confirmed.acknowledgedAt);
  });

  test(
    'expired delivery is not revived by late ACK or native completion',
    () async {
      await sending();
      await repository.transitionOutboxState(
        'message-1',
        BleOutboxState.expired,
      );
      await expectLater(
        repository.recordAcknowledgement(
          ack(),
          sourceDeviceId: 'selected-peer',
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );
      expect((await repository.finishWriting('message-1')).state, 'expired');
    },
  );
}
