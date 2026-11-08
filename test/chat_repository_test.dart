import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';

void main() {
  late AppDatabase database;
  late PersistentChatRepository repository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.utc(2026);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'sos-a',
            ownerId: 'owner-a',
            type: 'emergency',
            status: 'active',
            syncState: 'local',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'sos-b',
            ownerId: 'owner-b',
            type: 'emergency',
            status: 'active',
            syncState: 'local',
            createdAt: now,
            updatedAt: now,
          ),
        );
    repository = PersistentChatRepository(
      database: database,
      ownerId: 'owner-a',
    );
  });

  tearDown(() => database.close());

  test('notification side effect follows durable incoming commit and cannot roll it back', () async {
    var calls = 0;
    repository = PersistentChatRepository(
      database: database,
      ownerId: 'owner-a',
      onIncomingPersisted: (message) async {
        calls++;
        final saved = await repository.loadMessages('sos-a');
        expect(saved.single.id, message.id);
        throw StateError('OS permission denied');
      },
    );
    Future<void> receive({String text = 'incoming'}) async {
      await repository.insertIncomingMessage(
        messageId: 'incoming-1',
        sosId: 'sos-a',
        senderId: 'remote',
        text: text,
        createdAt: DateTime.utc(2026),
      );
    }

    await receive();
    expect(calls, 1);
    expect(
      (await repository.loadMessages('sos-a')).single.status,
      ChatDeliveryStatus.delivered,
    );
    await receive(); // A replay may retry notification; native stable-ID dedupes it.
    expect(calls, 2);
    expect(await repository.loadMessages('sos-a'), hasLength(1));
    await expectLater(
      receive(text: 'conflict'),
      throwsA(isA<ChatRepositoryException>()),
    );
    expect(calls, 2);
    await repository.insertMessage(sosId: 'sos-a', text: 'outgoing');
    expect(calls, 2);
  });

  test('persists messages, preserves order, and updates status', () async {
    final first = await repository.insertMessage(
      sosId: 'sos-a',
      messageId: 'chat-1',
      recipientId: 'peer-helper',
      text: 'first',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    await repository.insertMessage(sosId: 'sos-a', text: 'second');
    await repository.updateDeliveryStatus(
      first.id,
      ChatDeliveryStatus.delivered,
    );

    final messages = await repository.loadMessages('sos-a');
    expect(messages.map((message) => message.text), ['first', 'second']);
    expect(messages.first.status, ChatDeliveryStatus.delivered);
    expect(messages.first.isMine, isTrue);
    expect(messages.first.recipientId, 'peer-helper');
  });

  test(
    'duplicate message ID is idempotent only for identical content',
    () async {
      final first = await repository.insertMessage(
        sosId: 'sos-a',
        messageId: 'stable-id',
        text: 'same',
      );
      final duplicate = await repository.insertMessage(
        sosId: 'sos-a',
        messageId: 'stable-id',
        text: 'same',
      );
      expect(duplicate.id, first.id);
      await repository.updateDeliveryStatus(
        first.id,
        ChatDeliveryStatus.delivered,
      );
      final replay = await repository.insertMessage(
        sosId: 'sos-a',
        messageId: 'stable-id',
        text: 'same',
      );
      expect(replay.status, ChatDeliveryStatus.delivered);
      expect(await database.select(database.chatMessages).get(), hasLength(1));
      expect(
        () => repository.insertMessage(
          sosId: 'sos-a',
          messageId: 'stable-id',
          text: 'changed',
        ),
        throwsA(isA<ChatRepositoryException>()),
      );
    },
  );

  test('rejects unauthorized SOS access and cannot leak messages', () async {
    expect(
      () => repository.loadMessages('sos-b'),
      throwsA(isA<ChatRepositoryException>()),
    );
    expect(
      () => repository.insertMessage(sosId: 'sos-b', text: 'private'),
      throwsA(isA<ChatRepositoryException>()),
    );
  });

  test('schema 4 chat data upgrades with a nullable recipient', () async {
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
          CREATE TABLE chat_messages (
            message_id TEXT NOT NULL PRIMARY KEY,
            sos_id TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            message_type TEXT NOT NULL,
            text_content TEXT,
            created_at INTEGER NOT NULL,
            delivery_status TEXT NOT NULL,
            attachment_path TEXT,
            attachment_mime_type TEXT,
            attachment_name TEXT,
            remote_message_id TEXT,
            transport_metadata TEXT
          )
        ''');
        db.execute('PRAGMA user_version = 4');
      },
    );
    final upgraded = AppDatabase.forTesting(oldExecutor);
    await upgraded
        .into(upgraded.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'migrated-sos',
            ownerId: 'owner-a',
            type: 'emergency',
            status: 'active',
            syncState: 'local',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );
    final migratedRepository = PersistentChatRepository(
      database: upgraded,
      ownerId: 'owner-a',
    );
    final message = await migratedRepository.insertMessage(
      sosId: 'migrated-sos',
      text: 'still here',
      recipientId: 'peer-after-upgrade',
    );
    expect(message.recipientId, 'peer-after-upgrade');
    await upgraded.close();
  });

  test('rejects empty text unless an attachment exists', () async {
    expect(
      () => repository.insertMessage(sosId: 'sos-a', text: '   '),
      throwsA(isA<ChatRepositoryException>()),
    );
    final message = await repository.insertMessage(
      sosId: 'sos-a',
      text: ' ',
      attachmentPath: '/tmp/photo.jpg',
      attachmentMimeType: 'image/jpeg',
      attachmentName: 'photo.jpg',
    );
    expect(message.text, isEmpty);
    expect(message.attachmentName, 'photo.jpg');
  });

  test(
    'pending chat and recipient survive a file-backed database restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sos-chat-restart-',
      );
      final file = File('${directory.path}/database.sqlite');
      try {
        final first = AppDatabase.forTesting(NativeDatabase(file));
        await first
            .into(first.sosMessages)
            .insert(
              SosMessagesCompanion.insert(
                id: 'restart-chat-sos',
                ownerId: 'owner-a',
                type: 'emergency',
                status: 'active',
                syncState: 'local',
                createdAt: DateTime.utc(2026),
                updatedAt: DateTime.utc(2026),
              ),
            );
        final firstRepository = PersistentChatRepository(
          database: first,
          ownerId: 'owner-a',
        );
        await firstRepository.insertMessage(
          sosId: 'restart-chat-sos',
          messageId: 'restart-chat-1',
          recipientId: 'peer-a',
          text: 'pending after restart',
        );
        await first.close();

        final second = AppDatabase.forTesting(NativeDatabase(file));
        final secondRepository = PersistentChatRepository(
          database: second,
          ownerId: 'owner-a',
        );
        final restored = await secondRepository.loadMessages(
          'restart-chat-sos',
        );
        expect(restored.single.id, 'restart-chat-1');
        expect(restored.single.recipientId, 'peer-a');
        expect(restored.single.status, ChatDeliveryStatus.pending);
        await second.close();
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );
  test(
    'late sent and failed updates cannot regress a delivered Chat bubble',
    () async {
      final message = await repository.insertMessage(
        sosId: 'sos-a',
        text: 'test',
      );
      await repository.updateDeliveryStatus(
        message.id,
        ChatDeliveryStatus.delivered,
      );
      await repository.updateDeliveryStatus(
        message.id,
        ChatDeliveryStatus.sent,
      );
      await repository.updateDeliveryStatus(
        message.id,
        ChatDeliveryStatus.failed,
      );
      expect(
        (await repository.loadMessages('sos-a')).single.status,
        ChatDeliveryStatus.delivered,
      );
    },
  );

  test('stable device identity preserves legacy outgoing Chat origin without rewriting it', () async {
    final old = await repository.insertMessage(
      sosId: 'sos-a',
      messageId: 'legacy-chat',
      text: 'old',
    );
    await BleDeliveryRepository(database).enqueueOutbox(
      SosBleEnvelope.chatMessage(
        messageId: old.id,
        sosId: old.sosId,
        senderDeviceId: 'owner-a',
        chatSenderId: old.senderId,
        chatText: old.text,
        createdAt: old.createdAt,
      ),
    );
    final current = PersistentChatRepository(
      database: database,
      ownerId: 'owner-a',
      senderId: 'install-A',
    );
    final retained = (await current.loadMessages('sos-a')).single;
    expect(retained.isMine, isTrue);
    expect(retained.id, old.id);
    expect(retained.senderId, old.senderId);
    expect(retained.status, old.status);
  });
}
