import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/sos/data/media_attachment_store.dart';

void main() {
  late Directory temp, original, relocated;
  late AppDatabase db;
  late MediaAttachmentStore store;
  late PersistentChatRepository repo;
  late File content;
  final now = DateTime.utc(2026, 11, 9);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('chat-path-regression-');
    original = Directory('${temp.path}/old/chat-media-v1');
    relocated = Directory('${temp.path}/new/chat-media-v1');
    store = MediaAttachmentStore(ownerId: 'owner', root: original);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'incident',
            ownerId: 'owner',
            type: 'emergency',
            status: 'cancelled',
            syncState: 'deviceOnly',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final source = File('${temp.path}/photo.png');
    await source.writeAsBytes(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS2UAAAAASUVORK5CYII=',
      ),
    );
    content = (await store.importFile(
      id: 'message',
      incident: 'incident',
      source: source,
      mime: 'image/png',
    )).file;
    repo = PersistentChatRepository(
      database: db,
      ownerId: 'owner',
      attachmentStore: store,
    );
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });

  Future<void> send() => repo
      .insertMessage(
        sosId: 'incident',
        text: 'Photo',
        messageId: 'message',
        messageType: 'media',
        attachmentPath: content.path,
        attachmentMimeType: 'image/png',
        attachmentName: 'Photo',
      )
      .then((_) {});
  Future<void> move() async {
    await relocated.parent.create(recursive: true);
    await original.rename(relocated.path);
    store = MediaAttachmentStore(ownerId: 'owner', root: relocated);
    repo = PersistentChatRepository(
      database: db,
      ownerId: 'owner',
      attachmentStore: store,
    );
  }

  test(
    'new media stores a stable reference and resolves after sandbox relocation',
    () async {
      await send();
      final stored = await db.select(db.chatMessages).getSingle();
      expect(stored.attachmentPath, startsWith('chat-media-v1/'));
      expect(File(stored.attachmentPath!).isAbsolute, isFalse);
      final bytes = await content.readAsBytes();
      await move();
      final message = (await repo.loadMessages('incident')).single;
      expect(await File(message.attachmentPath!).readAsBytes(), bytes);
      expect(message.attachmentPath, startsWith(relocated.path));
    },
  );

  test('legacy absolute history resolves without rewriting the row or copying content', () async {
    await send();
    await db
        .update(db.chatMessages)
        .write(ChatMessagesCompanion(attachmentPath: Value(content.path)));
    final old = await db.select(db.chatMessages).getSingle();
    await move();
    final loaded = (await repo.loadMessages('incident')).single;
    expect(await File(loaded.attachmentPath!).exists(), isTrue);
    expect(
      (await db.select(db.chatMessages).getSingle()).toJson(),
      old.toJson(),
    );
    expect(await File(old.attachmentPath!).exists(), isFalse);
  });

  test('metadata-only history recovers a null path after cancellation and sandbox move', () async {
    await send();
    await db
        .update(db.chatMessages)
        .write(const ChatMessagesCompanion(attachmentPath: Value(null)));
    await move();
    final before = (await db.select(db.chatMessages).getSingle()).toJson();
    final loaded = (await repo.loadMessages('incident')).single;
    expect(loaded.attachmentPath, isNotNull);
    expect(
      await File(loaded.attachmentPath!).readAsBytes(),
      await (await store.find('message'))!.file.readAsBytes(),
    );
    expect((await db.select(db.chatMessages).getSingle()).toJson(), before);
  });

  test('null reference recovery rejects other namespaces, MIME and corrupt content', () async {
    Future<String?> resolve(
      MediaAttachmentStore source, {
      String id = 'message',
      String incident = 'incident',
      String mime = 'image/png',
    }) => source.resolveChatPath(
      id: id,
      incident: incident,
      mime: mime,
      path: null,
    );
    expect(
      await resolve(MediaAttachmentStore(ownerId: 'other', root: original)),
      isNull,
    );
    expect(await resolve(store, id: 'other'), isNull);
    expect(await resolve(store, incident: 'other'), isNull);
    expect(await resolve(store, mime: 'video/mp4'), isNull);
    final bytes = await content.readAsBytes();
    bytes[bytes.length - 1] ^= 1;
    await content.writeAsBytes(bytes);
    expect(await resolve(store), isNull);
  });

  test('incoming replay after relocation stays one row and preserves stored status', () async {
    Future<void> receive(String path) => repo
        .insertIncomingMessage(
          messageId: 'message',
          sosId: 'incident',
          senderId: 'peer',
          text: 'Photo',
          createdAt: now,
          attachmentPath: path,
          attachmentMimeType: 'image/png',
          attachmentName: 'Photo',
        )
        .then((_) {});
    await receive(content.path);
    await db
        .update(db.chatMessages)
        .write(ChatMessagesCompanion(attachmentPath: Value(content.path)));
    await move();
    final current = (await store.find('message'))!.file;
    await receive(current.path);
    expect(await db.select(db.chatMessages).get(), hasLength(1));
    expect(
      (await repo.loadMessages('incident')).single.status,
      ChatDeliveryStatus.delivered,
    );
  });

  test('resolver does not rebase another owner, message, incident, MIME or symlink', () async {
    final other = MediaAttachmentStore(ownerId: 'other', root: original);
    expect(
      await other.resolveChatPath(
        id: 'message',
        incident: 'incident',
        mime: 'image/png',
        path: content.path,
      ),
      content.path,
    );
    expect(
      await store.resolveChatPath(
        id: 'different',
        incident: 'incident',
        mime: 'image/png',
        path: content.path,
      ),
      content.path,
    );
    expect(
      await store.resolveChatPath(
        id: 'message',
        incident: 'wrong',
        mime: 'image/png',
        path: content.path,
      ),
      content.path,
    );
    expect(
      await store.resolveChatPath(
        id: 'message',
        incident: 'incident',
        mime: 'video/mp4',
        path: content.path,
      ),
      content.path,
    );
    final ref = await store.canonicalChatPath(
      id: 'message',
      incident: 'incident',
      mime: 'image/png',
      path: content.path,
    );
    await content.delete();
    await Link(content.path).create('${temp.path}/photo.png');
    expect(
      await store.resolveChatPath(
        id: 'message',
        incident: 'incident',
        mime: 'image/png',
        path: ref,
      ),
      ref,
    );
  });
}
