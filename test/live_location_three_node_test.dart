import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sos_app/features/nearby_ble/data/automatic_incident_location.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/live_location_envelope.dart';

import 'support/three_node_ble_simulation.dart';

class _LiveFeed implements IncidentLocationFeed {
  final fixes = StreamController<Position>.broadcast();
  @override
  Future<void> prepare({required bool mayRequestPermission}) async {}
  @override
  Stream<Position> positions() => fixes.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('signed positions reach only the known opposite participant over A-B-C and C-B-A', () async {
    final sim = ThreeNodeSimulation();
    addTearDown(sim.close);
    await sim.start();
    await sim.prepareIncident();
    final time = sim.clock.now;
    final victim = await sim.a.coordinator.createLiveLocationEnvelope(
      sosId: 'incident-1',
      participantId: 'A',
      participantRole: 'victim',
      sequence: 10,
      latitude: 13.71,
      longitude: 100.51,
      createdAt: time,
      expiresAt: time.add(const Duration(minutes: 2)),
    );
    await sim.a.coordinator.enqueueLiveLocation(
      envelope: victim,
      destinationId: 'B',
    );
    await sim.network.until(
      () async =>
          await BleDeliveryRepository(sim.c.db)
              .latestLiveLocation('incident-1', now: time) !=
          null,
    );
    final receivedVictim = await sim.c.coordinator
        .watchLiveLocation('incident-1')
        .first;
    expect(receivedVictim!.originKeyId, (await sim.a.identity()).keyId);
    expect(receivedVictim.latitude, 13.71);
    expect(receivedVictim.participantRole, 'victim');
    expect(receivedVictim.hopCount, 1);

    final rescue = await sim.c.coordinator.createLiveLocationEnvelope(
      sosId: 'incident-1',
      participantId: 'C',
      participantRole: 'rescue',
      sequence: 11,
      latitude: 13.72,
      longitude: 100.52,
      createdAt: time,
      expiresAt: time.add(const Duration(minutes: 2)),
    );
    await sim.c.coordinator.enqueueLiveLocation(
      envelope: rescue,
      destinationId: 'B',
    );
    await sim.network.until(
      () async =>
          await BleDeliveryRepository(sim.a.db)
              .latestLiveLocation('incident-1', now: time) !=
          null,
    );
    final receivedRescue = await sim.a.coordinator
        .watchLiveLocation('incident-1')
        .first;
    expect(receivedRescue!.originKeyId, (await sim.c.identity()).keyId);
    expect(receivedRescue.participantRole, 'rescue');
    expect(receivedRescue.latitude, 13.72);
    expect(
      sim.network.allowedLinks.contains(sim.network.pair('A', 'C')),
      isFalse,
    );

    // A valid-looking role/name does not rescue a modified signed position.
    final tampered = LiveLocationEnvelope.fromJson({
      ...rescue.toJson(),
      'messageId': 'tampered-location',
      'sequence': 12,
      'latitude': 14.0,
    });
    await sim.c.coordinator.enqueueLiveLocation(
      envelope: tampered,
      destinationId: 'B',
    );
    await sim.network.pump();
    expect(
      await BleDeliveryRepository(sim.b.db).lookupInbox('tampered-location'),
      isNull,
    );
    expect(
      (await sim.a.coordinator.watchLiveLocation('incident-1').first)!.latitude,
      13.72,
    );
  });
  test('automatic GPS broadcasts both ways without a page, picker or manual location outbox', () async {
    final source = _LiveFeed();
    final rescue = _LiveFeed();
    final sim = ThreeNodeSimulation(
      aLocationFeed: source,
      cLocationFeed: rescue,
    );
    sim.clock.now = DateTime.now().toUtc();
    addTearDown(() async {
      await sim.close();
      await source.fixes.close();
      await rescue.fixes.close();
    });
    await sim.start();
    await sim.prepareIncident();
    await RescueInboxRepository(
      sim.c.db,
      ownerId: sim.c.id,
    ).acceptLocally('relay:incident-1');
    await sim.network.until(
      () async => source.fixes.hasListener && rescue.fixes.hasListener,
    );
    Position fix(double latitude) => Position(
      latitude: latitude,
      longitude: 100.5,
      timestamp: sim.clock.now,
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    source.fixes.add(fix(13.73));
    rescue.fixes.add(fix(13.74));
    await sim.network.until(
      () async =>
          await BleDeliveryRepository(sim.a.db)
                  .latestLiveLocation('incident-1', now: sim.clock.now) !=
              null &&
          await BleDeliveryRepository(sim.c.db)
                  .latestLiveLocation('incident-1', now: sim.clock.now) !=
              null,
    );
    expect(
      (await sim.a.coordinator.watchLiveLocation('incident-1').first)!.latitude,
      13.74,
    );
    expect(
      (await sim.c.coordinator.watchLiveLocation('incident-1').first)!.latitude,
      13.73,
    );
    final captured = sim.network.captures.where(
      (p) => p.$3.type == LiveLocationEnvelope.wireKind,
    );
    expect(
      captured.map((p) => '${p.$1}->${p.$2}'),
      containsAll(['A->B', 'B->C', 'C->B', 'B->A']),
    );
    expect(
      sim.network.allowedLinks.contains(sim.network.pair('A', 'C')),
      isFalse,
    );
  });
}
