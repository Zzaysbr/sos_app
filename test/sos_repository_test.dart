import 'dart:convert';

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

  test('verified rescue candidate can be materialized for local chat access', () async {
    when(() => auth.currentUser).thenReturn(null);
    final guestRepository = SosRepository(
      database: database,
      cloudService: cloud,
      firebaseAuth: auth,
      localOwnerId: guestDeviceOwnerId,
    );

    final createdAt = DateTime.utc(2026, 11, 4, 3);
    final incident = await guestRepository.ensureReceivedIncident(
      id: 'incident-from-rescue-candidate',
      type: 'emergency',
      message: 'Victim needs help',
      latitude: 13.7,
      longitude: 100.5,
      createdAt: createdAt,
    );

    expect(incident.ownerId, guestDeviceOwnerId);
    expect(incident.syncState, 'deviceOnly');
    expect(incident.latitude, 13.7);
    expect(incident.longitude, 100.5);
    expect(
      await guestRepository.ensureReceivedIncident(
        id: incident.id,
        type: 'emergency',
        createdAt: createdAt,
      ),
      equals(incident),
    );
    expect(await database.select(database.sosSyncQueue).get(), isEmpty);
  });

  test(
    'guest creates local SOS without attempting authenticated cloud sync',
    () async {
      when(() => auth.currentUser).thenReturn(null);
      final guestRepository = SosRepository(
        database: database,
        cloudService: cloud,
        firebaseAuth: auth,
        localOwnerId: 'guest-local-device',
      );

      await guestRepository.create(id: 'guest-sos', type: 'emergency');

      final sos = await guestRepository.findById('guest-sos');
      expect(guestRepository.isGuest, isTrue);
      expect(sos?.ownerId, 'guest-local-device');
      verifyNever(
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
      );
    },
  );

  test('create persists a valid incident snapshot unchanged', () async {
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
    ).thenAnswer((_) async {});

    await repository.create(
      id: 'sos-location-1',
      type: 'emergency',
      latitude: 13.7563,
      longitude: 100.5018,
    );

    final sos = await repository.findById('sos-location-1');
    expect(sos!.latitude, 13.7563);
    expect(sos.longitude, 100.5018);
  });

  test(
    'invalid incident coordinates do not block creation or enter storage',
    () async {
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
      ).thenAnswer((_) async {});

      await repository.create(
        id: 'sos-location-invalid',
        type: 'emergency',
        latitude: double.nan,
        longitude: 200,
      );

      final sos = await repository.findById('sos-location-invalid');
      expect(sos, isNotNull);
      expect(sos!.latitude, isNull);
      expect(sos.longitude, isNull);
    },
  );

  test(
    'pending cloud sync retains the incident location in its payload',
    () async {
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

      await repository.create(
        id: 'sos-location-queued',
        type: 'emergency',
        latitude: 13.7563,
        longitude: 100.5018,
      );

      final queue = await database.select(database.sosSyncQueue).getSingle();
      final payload = jsonDecode(queue.payload!) as Map<String, dynamic>;
      expect(payload['latitude'], 13.7563);
      expect(payload['longitude'], 100.5018);
    },
  );

  test('updating an SOS cannot replace its valid incident snapshot', () async {
    final now = DateTime.now();
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'sos-location-preserve',
            ownerId: 'test-user-1',
            type: 'emergency',
            latitude: const Value(13.7563),
            longitude: const Value(100.5018),
            status: 'active',
            syncState: 'synced',
            createdAt: now,
            updatedAt: now,
          ),
        );

    when(
      () => cloud.update(
        id: any(named: 'id'),
        type: any(named: 'type'),
        message: any(named: 'message'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        status: any(named: 'status'),
        updatedAt: any(named: 'updatedAt'),
      ),
    ).thenAnswer((_) async {});

    await repository.update(
      id: 'sos-location-preserve',
      type: 'emergency',
      message: 'Updated without changing location',
      latitude: 14.0,
      longitude: 101.0,
      status: 'active',
    );

    final sos = await repository.findById('sos-location-preserve');
    expect(sos!.latitude, 13.7563);
    expect(sos.longitude, 100.5018);
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
