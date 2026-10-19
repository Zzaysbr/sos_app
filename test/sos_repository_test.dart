import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;

import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockSosCloudService extends Mock implements SosCloudService {}

void main() {
  late AppDatabase database;
  late MockFirebaseAuth auth;
  late MockUser user;
  late MockSosCloudService cloud;
  late SosRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    auth = MockFirebaseAuth();
    user = MockUser();
    cloud = MockSosCloudService();

    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('test-user-1');

    repository = SosRepository(
      database: database,
      cloudService: cloud,
      firebaseAuth: auth,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('create keeps local SOS and queue when cloud fails', () async {
    when(
      () => cloud.create(
        id: any(named: 'id'),
        ownerId: any(named: 'ownerId'),
        type: any(named: 'type'),
        message: any(named: 'message'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        status: any(named: 'status'),
        createdAt: any(named: 'createdAt'),
        updatedAt: any(named: 'updatedAt'),
      ),
    ).thenThrow(Exception('offline'));

    await repository.create(id: 'sos-1', type: 'emergency', message: 'Help');

    final sos = await repository.findById('sos-1');
    final queue = await database.select(database.sosSyncQueue).get();

    expect(sos, isNotNull);
    expect(sos!.ownerId, 'test-user-1');
    expect(sos.syncState, 'pending');
    expect(queue, hasLength(1));
    expect(queue.single.operation, 'create');
  });

  test('syncPending retries a queued create successfully', () async {
    var attempts = 0;

    when(
      () => cloud.create(
        id: any(named: 'id'),
        ownerId: any(named: 'ownerId'),
        type: any(named: 'type'),
        message: any(named: 'message'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        status: any(named: 'status'),
        createdAt: any(named: 'createdAt'),
        updatedAt: any(named: 'updatedAt'),
      ),
    ).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw Exception('offline');
      }
    });

    await repository.create(
      id: 'sos-2',
      type: 'emergency',
      message: 'Retry test',
    );

    expect((await database.select(database.sosSyncQueue).get()), hasLength(1));

    await repository.syncPending();

    final sos = await repository.findById('sos-2');
    final queue = await database.select(database.sosSyncQueue).get();

    expect(attempts, 2);
    expect(queue, isEmpty);
    expect(sos!.syncState, 'synced');
  });

  test('delete keeps delete command when cloud fails', () async {
    final now = DateTime.now();

    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'sos-3',
            ownerId: 'test-user-1',
            type: 'emergency',
            message: const Value('Delete test'),
            status: 'active',
            syncState: 'synced',
            createdAt: now,
            updatedAt: now,
          ),
        );

    when(() => cloud.delete(any())).thenThrow(Exception('offline'));

    await repository.delete('sos-3');

    expect(await repository.findById('sos-3'), isNull);

    final queue = await database.select(database.sosSyncQueue).get();

    expect(queue, hasLength(1));
    expect(queue.single.operation, 'delete');
    expect(queue.single.sosId, 'sos-3');
  });

  test(
    'passes an explicitly selected BLE destination to the delivery hook',
    () async {
      String? selectedDestination;
      final withBleHook = SosRepository(
        database: database,
        cloudService: cloud,
        firebaseAuth: auth,
        onSosCreated: (sos, {destinationId}) async {
          selectedDestination = destinationId;
        },
      );

      when(
        () => cloud.create(
          id: any(named: 'id'),
          ownerId: any(named: 'ownerId'),
          type: any(named: 'type'),
          message: any(named: 'message'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          status: any(named: 'status'),
          createdAt: any(named: 'createdAt'),
          updatedAt: any(named: 'updatedAt'),
        ),
      ).thenThrow(Exception('offline'));

      await withBleHook.create(
        id: 'sos-with-peer',
        type: 'emergency',
        destinationId: 'peer-android-1',
      );

      expect(selectedDestination, 'peer-android-1');
    },
  );
}
