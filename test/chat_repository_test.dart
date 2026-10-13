import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
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

  test('persists messages, preserves order, and updates status', () async {
    final first = await repository.insertMessage(
      sosId: 'sos-a',
      messageId: 'chat-1',
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
}
