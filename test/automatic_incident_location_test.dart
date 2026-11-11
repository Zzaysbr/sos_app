import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:geolocator/geolocator.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/automatic_incident_location.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';

class _Feed implements IncidentLocationFeed {
  final fixes = StreamController<Position>.broadcast();
  int starts = 0;
  bool denied = false;
  Completer<void>? pending;
  @override
  Future<void> prepare({required bool mayRequestPermission}) async {
    starts++;
    if (denied) throw const LocationPermissionRequired();
    await pending?.future;
  }

  @override
  Stream<Position> positions() => fixes.stream;
}

Position fix(DateTime time, {double latitude = 13.7}) => Position(
  longitude: 100.5,
  latitude: latitude,
  timestamp: time,
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late _Feed feed;
  late DateTime now;
  late AutomaticIncidentLocation location;
  late List<({String id, String role, int sequence})> sent;
  late bool current;

  Future<void> source(
    String id, {
    String owner = 'owner',
    String sender = 'this-install',
  }) async {
    await db
        .into(db.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: id,
            ownerId: owner,
            type: 'emergency',
            status: 'active',
            createdAt: now,
            updatedAt: now,
            syncState: 'deviceOnly',
          ),
        );
    final sos = await (db.select(
      db.sosMessages,
    )..where((r) => r.id.equals(id))).getSingle();
    await BleDeliveryRepository(db).enqueueOutbox(
      SosBleEnvelope.fromSosMessage(
        sos,
        messageId: 'sos:$id',
        senderDeviceId: sender,
      ),
      now: now,
    );
  }

  Future<void> candidate(String id, {String state = 'locallyAccepted'}) async {
    await db
        .into(db.rescueInbox)
        .insert(
          RescueInboxCompanion.insert(
            ownerId: 'owner',
            originMessageId: 'relay:$id',
            incidentId: id,
            originKeyId: 'origin-key',
            immutableDigest: 'digest',
            emergencyType: 'emergency',
            emergencyMessage: 'test',
            includeLocation: false,
            incomingHopCount: 1,
            incomingPath: '["origin-key","middle"]',
            createdAt: now,
            receivedAt: now,
            expiresAt: now.add(const Duration(minutes: 30)),
            state: state,
          ),
        );
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    feed = _Feed();
    now = DateTime.utc(2026, 11, 11, 12);
    current = true;
    sent = [];
    location = AutomaticIncidentLocation(
      database: db,
      ownerId: 'owner',
      localDeviceId: 'this-install',
      isCurrent: () => current,
      feed: feed,
      now: () => now,
      publish: (id, role, fix, at, sequence) async =>
          sent.add((id: id, role: role, sequence: sequence)),
    );
  });
  tearDown(() async {
    await location.dispose();
    await feed.fixes.close();
    await db.close();
  });

  test('saved victim location opt-out prevents automatic GPS even before public routing completes', () async {
    await location.dispose();
    await source('local');
    location = AutomaticIncidentLocation(
      database: db,
      ownerId: 'owner',
      localDeviceId: 'this-install',
      isCurrent: () => current,
      feed: feed,
      now: () => now,
      allowVictimLocation: () async => false,
      publish: (id, role, fix, at, sequence) async =>
          sent.add((id: id, role: role, sequence: sequence)),
    );
    location.start();
    await location.refresh();
    expect(feed.starts, 0);
    expect(await location.activeTargets(), isEmpty);
  });

  test('only this installation sources and accepted rescue incidents authorize tracking', () async {
    await source('local');
    await source('other-owner', owner: 'other');
    await source('restored-other-install', sender: 'another-install');
    await candidate('accepted');
    await candidate('unaccepted', state: 'pending');
    await candidate('stopped', state: 'archivedLocally');
    expect(await location.activeTargets(), {
      'local': 'victim',
      'accepted': 'rescue',
    });
  });

  test('shares both roles with no page or recipient picker, throttles and stops on cancellation', () async {
    await source('local');
    await candidate('accepted');
    location.start();
    await location.refresh();
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent.map((r) => '${r.id}:${r.role}'), [
      'local:victim',
      'accepted:rescue',
    ]);
    expect(location.state.value, AutomaticLocationState.sharing);
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent, hasLength(2));
    await (db.update(db.sosMessages)..where((r) => r.id.equals('local'))).write(
      const SosMessagesCompanion(status: Value('cancelled')),
    );
    await (db.update(db.rescueInbox)
          ..where((r) => r.incidentId.equals('accepted')))
        .write(const RescueInboxCompanion(state: Value('archivedLocally')));
    now = now.add(const Duration(seconds: 11));
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent, hasLength(2));
    expect(feed.fixes.hasListener, isFalse);
    expect(location.state.value, AutomaticLocationState.idle);
  });

  test(
    'switching account during permission acquisition never publishes',
    () async {
      await source('local');
      feed.pending = Completer<void>();
      location.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      current = false;
      feed.pending!.complete();
      feed.fixes.add(fix(now));
      await location.refresh();
      expect(sent, isEmpty);
      expect(feed.fixes.hasListener, isFalse);
    },
  );

  test('denied permission is visible and resume/retry can recover without a new SOS', () async {
    await source('local');
    feed.denied = true;
    location.start();
    await location.refresh();
    expect(location.state.value, AutomaticLocationState.permissionRequired);
    feed.denied = false;
    await location.refresh();
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent.single.id, 'local');
  });

  test('old GPS fixes cannot be relabeled as a fresh position', () async {
    await source('local');
    location.start();
    await location.refresh();
    feed.fixes.add(fix(now.subtract(const Duration(minutes: 2))));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent, isEmpty);
  });

  test('an existing stream continues publishing while the app is paused', () async {
    await source('local');
    location.start();
    await location.refresh();
    // Background execution is driven by the native position stream, not a page.
    location.didChangeAppLifecycleState(AppLifecycleState.paused);
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent.single.id, 'local');
    expect(feed.starts, 1);
  });

  test('sequence remains newer after coordinator restart', () async {
    await source('local');
    location.start();
    await location.refresh();
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    final first = sent.single.sequence;
    await location.dispose();
    now = now.add(const Duration(seconds: 11));
    location = AutomaticIncidentLocation(
      database: db,
      ownerId: 'owner',
      localDeviceId: 'this-install',
      isCurrent: () => current,
      feed: feed,
      now: () => now,
      publish: (id, role, fix, at, sequence) async =>
          sent.add((id: id, role: role, sequence: sequence)),
    );
    location.start();
    await location.refresh();
    feed.fixes.add(fix(now));
    await Future<void>.delayed(Duration.zero);
    await location.refresh();
    expect(sent.last.sequence, greaterThan(first));
  });
}
