// Mock SDK boundaries only; all archive/repository behavior under test is real.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/sos/data/cloud_archive_service.dart';
import 'package:sos_app/features/sos/data/media_attachment_store.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';

class _Firestore extends Mock implements FirebaseFirestore {}

class _Collection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _Reference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _Query extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

class _Document extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class _Auth extends Mock implements FirebaseAuth {}

class _User extends Mock implements User {}

class _Cloud extends Mock implements SosCloudService {}

void main() {
  late AppDatabase db;
  late CloudArchiveService archive;
  late SosRepository repository;
  late _Reference incident;
  late _Collection archives;
  late _Cloud cloud;
  late _Collection chats;
  late _Query chatQuery;
  late _Document document;
  final now = DateTime.utc(2026, 11, 11);

  setUpAll(() => registerFallbackValue(SetOptions(merge: true)));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final firestore = _Firestore();
    final accounts = _Collection();
    final account = _Reference();
    archives = _Collection();
    incident = _Reference();
    final query = _Query();
    document = _Document();
    chats = _Collection();
    chatQuery = _Query();
    when(() => firestore.collection('accounts')).thenReturn(accounts);
    when(() => accounts.doc('owner')).thenReturn(account);
    when(() => account.collection('archiveSos')).thenReturn(archives);
    when(() => archives.doc('incident')).thenReturn(incident);
    when(() => archives.get()).thenAnswer((_) async => query);
    when(() => query.docs).thenReturn([document]);
    when(() => document.id).thenReturn('incident');
    when(() => document.reference).thenReturn(incident);
    when(() => document.data()).thenReturn({
      'id': 'incident',
      'ownerId': 'owner',
      'type': 'emergency',
      'message': null,
      'latitude': null,
      'longitude': null,
      'status': 'cancelled',
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });
    when(() => incident.delete()).thenAnswer((_) async {});
    when(() => incident.set(any(), any())).thenAnswer((_) async {});
    when(() => incident.collection('chat')).thenReturn(chats);
    when(() => chats.get()).thenAnswer((_) async => chatQuery);
    when(() => chatQuery.docs).thenReturn([]);
    archive = CloudArchiveService(firestore: firestore);
    final auth = _Auth();
    final user = _User();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('owner');
    cloud = _Cloud();
    when(() => cloud.delete('incident')).thenAnswer((_) async {});
    repository = SosRepository(
      database: db,
      cloudService: cloud,
      firebaseAuth: auth,
      cloudArchiveService: archive,
    );
  });
  tearDown(() async => db.close());

  Future<void> seed() => db
      .into(db.sosMessages)
      .insert(
        SosMessagesCompanion.insert(
          id: 'incident',
          ownerId: 'owner',
          type: 'emergency',
          status: 'cancelled',
          syncState: 'synced',
          createdAt: now,
          updatedAt: now,
        ),
      )
      .then((_) {});

  test('metadata-only archive cannot erase an existing local attachment or receipt', () async {
    await seed();
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            messageId: 'media',
            sosId: 'incident',
            ownerId: 'owner',
            senderId: 'peer',
            messageType: 'media',
            textContent: const Value('Photo'),
            createdAt: now,
            deliveryStatus: 'delivered',
            attachmentPath: const Value('chat-media-v1/local/content'),
            attachmentMimeType: const Value('image/jpeg'),
          ),
        );
    final before = (await db.select(db.chatMessages).getSingle()).toJson();
    final remote = _Document();
    final ref = _Reference();
    when(() => chats.doc('media')).thenReturn(ref);
    when(() => ref.set(any(), any())).thenAnswer((_) async {});
    when(() => chatQuery.docs).thenReturn([remote]);
    when(() => remote.data()).thenReturn({
      'messageId': 'media',
      'sosId': 'incident',
      'ownerId': 'owner',
      'senderId': 'peer',
      'messageType': 'media',
      'textContent': 'Photo',
      'createdAt': Timestamp.fromDate(now),
      'deliveryStatus': 'sent',
      'attachmentMimeType': 'image/jpeg',
      'attachmentPath': '/untrusted/cloud/path',
    });
    final store = MediaAttachmentStore(ownerId: 'owner');
    for (var i = 0; i < 2; i++) {
      await archive.reconcile(
        ownerId: 'owner',
        database: db,
        attachments: store,
      );
      expect((await db.select(db.chatMessages).getSingle()).toJson(), before);
    }
  });

  test(
    'remote message ID collision cannot replace another owner local row',
    () async {
      await seed();
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: 'collision',
              sosId: 'private-incident',
              ownerId: 'other',
              senderId: 'peer',
              messageType: 'text',
              textContent: const Value('private'),
              createdAt: now,
              deliveryStatus: 'delivered',
            ),
          );
      final before = (await db.select(db.chatMessages).getSingle()).toJson();
      final remote = _Document();
      when(() => chatQuery.docs).thenReturn([remote]);
      when(() => remote.data()).thenReturn({
        'messageId': 'collision',
        'sosId': 'incident',
        'ownerId': 'owner',
        'senderId': 'peer',
        'messageType': 'media',
        'createdAt': Timestamp.fromDate(now),
        'attachmentMimeType': 'image/jpeg',
      });
      await archive.reconcile(
        ownerId: 'owner',
        database: db,
        attachments: MediaAttachmentStore(ownerId: 'owner'),
      );
      expect((await db.select(db.chatMessages).getSingle()).toJson(), before);
    },
  );

  test('archive restores missing media metadata without importing a remote file path', () async {
    await seed();
    final remote = _Document();
    when(() => chatQuery.docs).thenReturn([remote]);
    when(() => remote.data()).thenReturn({
      'messageId': 'new-media',
      'sosId': 'incident',
      'ownerId': 'owner',
      'senderId': 'peer',
      'messageType': 'media',
      'textContent': 'Video',
      'createdAt': Timestamp.fromDate(now),
      'deliveryStatus': 'delivered',
      'attachmentMimeType': 'video/mp4',
      'attachmentPath': '/remote/invalid/path',
    });
    await archive.reconcile(
      ownerId: 'owner',
      database: db,
      attachments: MediaAttachmentStore(ownerId: 'owner'),
    );
    final restored = await db.select(db.chatMessages).getSingle();
    expect(restored.messageType, 'media');
    expect(restored.attachmentPath, isNull);
    expect(restored.attachmentMimeType, 'video/mp4');
  });

  test('authenticated deletion removes both cloud copies and rejects a stale archive snapshot', () async {
    await seed();
    await repository.delete('incident');
    expect(await repository.findById('incident'), isNull);
    final marker = await db.select(db.sosSyncQueue).getSingle();
    expect(marker.operation, 'deleteConfirmed');
    // The fake archive continues returning the old record to reproduce an
    // in-flight or stale restore result even after its server delete succeeded.
    await repository.syncPending();
    expect(await repository.findById('incident'), isNull);
    verify(() => incident.delete()).called(1);
    verify(() => cloud.delete('incident')).called(1);
    verifyNever(() => incident.collection('chat'));
  });

  test('failed archive delete stays queued and cannot restore while offline; retry completes', () async {
    await seed();
    var attempts = 0;
    when(() => incident.delete()).thenAnswer((_) async {
      if (++attempts == 1) throw StateError('offline');
    });
    await repository.delete('incident');
    expect(await repository.findById('incident'), isNull);
    expect((await db.select(db.sosSyncQueue).getSingle()).operation, 'delete');
    verifyNever(() => cloud.delete('incident'));
    await repository.syncPending();
    expect(await repository.findById('incident'), isNull);
    expect(
      (await db.select(db.sosSyncQueue).getSingle()).operation,
      'deleteConfirmed',
    );
    verify(() => cloud.delete('incident')).called(1);
  });

  test('deletion supersedes an older failed create rather than getting blocked behind it', () async {
    await seed();
    await db
        .into(db.sosSyncQueue)
        .insert(
          SosSyncQueueCompanion.insert(
            sosId: 'incident',
            ownerId: 'owner',
            operation: 'create',
            payload: const Value('{}'),
            createdAt: now,
          ),
        );
    await repository.delete('incident');
    expect(await repository.findById('incident'), isNull);
    expect(
      (await db.select(db.sosSyncQueue).getSingle()).operation,
      'deleteConfirmed',
    );
  });

  test(
    'another owner deletion marker cannot hide this account restore',
    () async {
      await db
          .into(db.sosSyncQueue)
          .insert(
            SosSyncQueueCompanion.insert(
              sosId: 'incident',
              ownerId: 'another-owner',
              operation: 'deleteConfirmed',
              createdAt: now,
            ),
          );
      await archive.reconcile(
        ownerId: 'owner',
        database: db,
        attachments: MediaAttachmentStore(ownerId: 'owner'),
      );
      expect(await repository.findById('incident'), isNotNull);
    },
  );
}
