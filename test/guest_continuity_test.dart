import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/auth/data/auth_service.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';

class TestAuth extends Mock implements FirebaseAuth {}

class TestUser extends Mock implements User {}

class TestCloud extends Mock implements SosCloudService {}

void main() {
  late AppDatabase db;
  late TestAuth auth;
  late TestCloud cloud;
  late StreamController<User?> changes;
  User? current;

  User account(String uid) {
    final user = TestUser();
    when(() => user.uid).thenReturn(uid);
    return user;
  }

  SosRepository repository() => SosRepository(
    database: db,
    cloudService: cloud,
    firebaseAuth: auth,
    localOwnerId: current == null ? guestDeviceOwnerId : null,
  );

  void transition(User? user) {
    current = user;
    changes.add(user);
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = TestAuth();
    cloud = TestCloud();
    current = null;
    changes = StreamController<User?>.broadcast();
    when(() => auth.currentUser).thenAnswer((_) => current);
    when(() => auth.authStateChanges()).thenAnswer((_) => changes.stream);
  });
  tearDown(() async {
    await changes.close();
    await db.close();
  });

  test(
    'guest identity and SOS survive closing and reopening the database',
    () async {
      final dir = await Directory.systemTemp.createTemp('sos-continuity-');
      final file = File('${dir.path}/device.sqlite');
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      await repository().create(id: 'guest', type: 'emergency');
      final before = await db.select(db.sosMessages).getSingle();
      final queue = await db.select(db.sosSyncQueue).get();
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      expect(await repository().findById('guest'), before);
      expect(await repository().watchDeviceHistory().first, [before]);
      expect(await db.select(db.sosSyncQueue).get(), queue);
      verifyZeroInteractions(cloud);
      transition(account('A'));
      await repository().create(id: 'account-a', type: 'emergency');
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      expect((await repository().watchAll().first).single.id, 'account-a');
      expect(await repository().watchDeviceHistory().first, [before]);
      expect(await db.select(db.sosSyncQueue).get(), hasLength(2));
      // Close before removing SQLite files; tearDown closes the replacement DB.
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await dir.delete(recursive: true);
    },
  );

  test('login keeps guest local history, ownership, queue and timestamps unchanged', () async {
    final guest = repository();
    await guest.create(id: 'guest', type: 'emergency');
    final rows = await db.select(db.sosMessages).get();
    final queue = await db.select(db.sosSyncQueue).get();
    transition(account('A'));
    final signedIn = repository();
    await signedIn.syncPending();
    await signedIn.syncPending();
    expect(await signedIn.watchAll().first, isEmpty);
    expect(await signedIn.findById('guest'), isNull);
    expect(await signedIn.watchDeviceHistory().first, rows);
    expect(await db.select(db.sosMessages).get(), rows);
    expect(await db.select(db.sosSyncQueue).get(), queue);
    await expectLater(
      guest.create(id: 'stale', type: 'emergency'),
      throwsA(isA<SosRepositoryException>()),
    );
    verifyZeroInteractions(cloud);
  });

  test(
    'logout and A to B isolate cached account history and stale repositories',
    () async {
      await repository().create(id: 'guest', type: 'emergency');
      transition(account('A'));
      final a = repository();
      await a.create(
        id: 'a',
        type: 'emergency',
      ); // Failed cloud call stays queued.
      final rows = await db.select(db.sosMessages).get();
      final queue = await db.select(db.sosSyncQueue).get();
      transition(null);
      expect((await repository().watchAll().first).single.id, 'guest');
      expect(await a.findById('a'), isNull);
      transition(account('B'));
      final b = repository();
      expect(await b.watchAll().first, isEmpty);
      expect(await b.findById('a'), isNull);
      await b.delete('a');
      await expectLater(
        b.update(id: 'a', type: 'emergency', status: 'resolved'),
        throwsA(isA<SosRepositoryException>()),
      );
      await b.syncPending();
      expect(await db.select(db.sosMessages).get(), rows);
      expect(await db.select(db.sosSyncQueue).get(), queue);
      transition(account('A'));
      expect((await repository().watchAll().first).single.id, 'a');
    },
  );

  test(
    'retained account subscription clears immediately on session expiry',
    () async {
      transition(account('A'));
      final a = repository();
      await a.create(id: 'a', type: 'emergency');
      final events = <List<SosMessage>>[];
      final loaded = Completer<void>();
      final cleared = Completer<void>();
      final subscription = a.watchAll().listen((rows) {
        events.add(rows);
        if (rows.isNotEmpty && !loaded.isCompleted) loaded.complete();
        if (rows.isEmpty && loaded.isCompleted && !cleared.isCompleted) {
          cleared.complete();
        }
      });
      await loaded.future;
      transition(null);
      await cleared.future;
      expect(events.last, isEmpty);
      expect(await db.select(db.sosMessages).get(), hasLength(1));
      await subscription.cancel();
    },
  );

  test('failed or cancelled login leaves guest scope intact and creates no duplicates', () async {
    final guest = repository();
    await guest.create(id: 'guest', type: 'emergency');
    when(
      () => auth.signInWithEmailAndPassword(
        email: 'a@example.com',
        password: 'wrong',
      ),
    ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    await expectLater(
      AuthService(firebaseAuth: auth)
          .login(email: 'a@example.com', password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
    // Cancel has no Firebase state event; the same repository remains active.
    expect((await guest.watchAll().first).single.id, 'guest');
    await guest.syncPending();
    expect(await db.select(db.sosMessages).get(), hasLength(1));
    expect(await db.select(db.sosSyncQueue).get(), hasLength(1));
    verifyZeroInteractions(cloud);
  });

  test(
    'authenticated restart retains A history without guest upload',
    () async {
      await repository().create(id: 'guest', type: 'emergency');
      transition(account('A'));
      await repository().create(id: 'a', type: 'emergency');
      final restarted = repository();
      expect((await restarted.watchAll().first).single.id, 'a');
      expect((await restarted.watchDeviceHistory().first).single.id, 'guest');
      expect(await db.select(db.sosSyncQueue).get(), hasLength(2));
    },
  );

  test(
    'account change during cloud write preserves queue and prevents B retry',
    () async {
      transition(account('A'));
      final started = Completer<void>();
      final request = Completer<void>();
      when(
        () => cloud.create(
          id: 'in-flight-a',
          ownerId: 'A',
          type: 'emergency',
          message: null,
          latitude: null,
          longitude: null,
          status: 'active',
          createdAt: any(named: 'createdAt'),
          updatedAt: any(named: 'updatedAt'),
        ),
      ).thenAnswer((_) {
        started.complete();
        return request.future;
      });
      final a = repository();
      final creation = a.create(id: 'in-flight-a', type: 'emergency');
      await started.future;
      transition(account('B'));
      request.complete();
      await creation;
      final queue = await db.select(db.sosSyncQueue).get();
      expect(queue, hasLength(1));
      expect(queue.single.ownerId, 'A');
      expect(
        (await db.select(db.sosMessages).getSingle()).syncState,
        'pending',
      );
      await repository().syncPending();
      expect(await db.select(db.sosSyncQueue).get(), queue);
      verify(
        () => cloud.create(
          id: 'in-flight-a',
          ownerId: 'A',
          type: 'emergency',
          message: null,
          latitude: null,
          longitude: null,
          status: 'active',
          createdAt: any(named: 'createdAt'),
          updatedAt: any(named: 'updatedAt'),
        ),
      ).called(1);
    },
  );

  test(
    'auth transitions preserve BLE inbox/outbox identity and delivery status',
    () async {
      await repository().create(id: 'guest', type: 'emergency');
      final now = DateTime.utc(2026);
      await db
          .into(db.bleOutbox)
          .insert(
            BleOutboxCompanion.insert(
              messageId: 'ble-original',
              sosId: 'guest',
              schemaVersion: 1,
              payload: 'original-payload',
              state: 'acknowledged',
              createdAt: now,
              updatedAt: now,
              acknowledgedAt: Value(now),
              retryCount: const Value(2),
            ),
          );
      await db
          .into(db.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: 'in-original',
              sosId: 'guest',
              schemaVersion: 1,
              payload: 'original-incoming',
              processingState: 'persisted',
              receivedAt: now,
            ),
          );
      final outbox = await db.select(db.bleOutbox).get();
      final inbox = await db.select(db.bleInbox).get();
      for (final user in [account('A'), null, account('B'), null]) {
        transition(user);
        await repository().syncPending();
      }
      expect(await db.select(db.bleOutbox).get(), outbox);
      expect(await db.select(db.bleInbox).get(), inbox);
    },
  );

  test('BLE due and recovery scopes leave guest and other account queues untouched', () async {
    final now = DateTime.utc(2026, 10, 20);
    for (final owner in [guestDeviceOwnerId, 'A', 'B']) {
      await db
          .into(db.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: owner,
              ownerId: owner,
              type: 'emergency',
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.bleOutbox)
          .insert(
            BleOutboxCompanion.insert(
              messageId: 'ble-$owner',
              sosId: owner,
              schemaVersion: 1,
              payload: 'unchanged',
              state: 'sending',
              destinationId: const Value('peer'),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    final ble = BleDeliveryRepository(db);
    expect(
      await ble.recoverStaleOutbox(
        ownerId: 'A',
        olderThan: now,
        nextRetryAt: now,
        now: now,
      ),
      1,
    );
    expect(
      (await ble.dueOutbox(ownerId: 'A', now: now)).single.messageId,
      'ble-A',
    );
    expect(await ble.dueOutbox(ownerId: 'B', now: now), isEmpty);
    final untouched = await (db.select(
      db.bleOutbox,
    )..where((t) => t.messageId.isNotValue('ble-A'))).get();
    expect(untouched.map((row) => row.state), everyElement('sending'));
    expect(untouched.map((row) => row.payload), everyElement('unchanged'));
  });
}
