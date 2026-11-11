import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/domain/incident_presence_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fresh real public SOS and contact traverse two hops before any help offer',
    () async {
      final s = ThreeNodeSimulation();
      s.clock.now = DateTime.now().toUtc();
      addTearDown(s.close);
      await s.start();
      await s.a.materialize('fresh-presence');
      await s.a.coordinator.enqueuePublicRelay(
        await s.a.db.select(s.a.db.sosMessages).getSingle(),
        includeLocation: false,
        scope: RelayAuthorizationScope.voluntaryRescue,
      );
      await s.network.until(
        () async => (await s.c.db.select(s.c.db.rescueInbox).get()).isNotEmpty,
      );
      s.clock.advance(const Duration(seconds: 11));
      await s.a.coordinator.processDue();
      await s.network.until(
        () async => s.c.coordinator.reachableIncidents!.value.contains(
          'fresh-presence',
        ),
      );
      final inbox = RescueInboxRepository(s.c.db, ownerId: 'C');
      final accepted = await inbox.acceptLocally('relay:fresh-presence');
      expect(accepted!.state, 'locallyAccepted');
      s.network.disconnect('A', 'B');
      s.network.allowedLinks.remove(s.network.pair('A', 'B'));
      await s.network.pump();
      s.clock.advance(const Duration(seconds: 50));
      await s.c.coordinator.processDue();
      expect(s.c.coordinator.reachableIncidents!.value, isEmpty);
      expect(
        (await inbox.find('relay:fresh-presence'))!.acceptanceId,
        accepted.acceptanceId,
      );
    },
  );
  test(
    'private Direct SOS contact is bound to its recipient and never relayed',
    () async {
      final s = ThreeNodeSimulation(requirePeerBinding: true);
      addTearDown(s.close);
      await s.start();
      await s.a.materialize('private-incident');
      await s.a.coordinator.enqueueSos(
        await s.a.db.select(s.a.db.sosMessages).getSingle(),
        destinationId: 'B',
      );
      await s.network.until(
        () async => (await s.b.db.select(s.b.db.sosMessages).get()).isNotEmpty,
      );
      await s.a.coordinator.processDue();
      await s.network.until(
        () async => s.b.coordinator.reachableIncidents!.value.contains(
          'private-incident',
        ),
      );
      final pulses = s.network.captures
          .where((entry) => entry.$3.type == IncidentPresenceEnvelope.wireKind)
          .toList();
      expect(pulses, isNotEmpty);
      expect(
        pulses.every(
          (entry) =>
              entry.$1 == 'A' &&
              entry.$2 == 'B' &&
              entry.$3.payload['scope'] == 'direct',
        ),
        isTrue,
      );
      expect(s.c.coordinator.reachableIncidents!.value, isEmpty);
    },
  );
  Future<ThreeNodeSimulation> ready() async {
    final s = ThreeNodeSimulation();
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    await s.a.materialize('incident-1');
    await s.c.materialize('incident-1');
    // Prepare the accepted boundary; no connection/proof state is fabricated.
    await (s.c.db.update(
      s.c.db.rescueInbox,
    )..where((row) => row.incidentId.equals('incident-1'))).write(
      const RescueInboxCompanion(
        state: Value('locallyAccepted'),
        acceptanceId: Value('accepted-before-loss'),
      ),
    );
    await s.a.coordinator.processDue();
    await s.network.until(
      () async =>
          s.c.coordinator.reachableIncidents!.value.contains('incident-1'),
    );
    return s;
  }

  test('source loss hides behind a live middle link and fresh reconnect restores original acceptance', () async {
    final s = await ready();
    await s.a.send('presence-chat', 'retained conversation', s.c);
    await s.network.until(
      () async => (await s.c.chat.loadMessages('incident-1')).isNotEmpty,
    );
    final offers = await s.c.db.select(s.c.db.rescueResponseInbox).get();
    s.network.disconnect('A', 'B');
    s.network.allowedLinks.remove(s.network.pair('A', 'B'));
    await s.network.pump();
    expect(s.network.linked('B', 'C'), isTrue);
    s.clock.advance(const Duration(seconds: 50));
    await s.c.coordinator.processDue();
    await s.network.pump();
    expect(s.c.coordinator.reachableIncidents!.value, isEmpty);
    expect(
      (await s.c.db.select(s.c.db.sosMessages).getSingle()).status,
      'active',
    );
    final accepted = await s.c.db.select(s.c.db.rescueInbox).getSingle();
    expect(accepted.state, 'locallyAccepted');
    expect(accepted.acceptanceId, 'accepted-before-loss');
    expect(await s.c.chat.loadMessages('incident-1'), hasLength(1));
    s.network.allow('A', 'B');
    s.network.connect('A', 'B');
    await s.network.until(() async => await s.a.authenticated());
    await s.a.coordinator.processDue();
    await s.network.until(
      () async =>
          s.c.coordinator.reachableIncidents!.value.contains('incident-1'),
    );
    expect(
      (await s.c.db.select(s.c.db.rescueInbox).getSingle()).acceptanceId,
      accepted.acceptanceId,
    );
    expect(await s.c.db.select(s.c.db.rescueResponseInbox).get(), offers);
  });

  test('last-hop disconnect hides immediately and another proven path keeps the incident visible', () async {
    final s = await ready();
    s.network.disconnect('B', 'C');
    s.network.allowedLinks.remove(s.network.pair('B', 'C'));
    await s.network.pump();
    expect(s.c.coordinator.reachableIncidents!.value, isEmpty);
    s.network.allow('A', 'C');
    s.network.connect('A', 'C');
    await s.network.until(() async => await s.c.authenticated());
    s.clock.advance(const Duration(seconds: 11));
    await s.a.coordinator.processDue();
    await s.network.until(
      () async =>
          s.c.coordinator.reachableIncidents!.value.contains('incident-1'),
    );
    // Rebuild the second path and receive the same fresh pulse by both paths.
    s.network.allow('B', 'C');
    s.network.connect('C', 'B');
    await s.network.pump();
    s.clock.advance(const Duration(seconds: 11));
    await s.a.coordinator.processDue();
    await s.network.pump();
    s.network.disconnect('A', 'C');
    s.network.allowedLinks.remove(s.network.pair('A', 'C'));
    await s.network.pump();
    expect(s.c.coordinator.reachableIncidents!.value, contains('incident-1'));
  });

  test('replaying a pulse inside clock tolerance cannot extend its first local freshness window', () async {
    final s = await ready();
    final pulse = (await IncidentPresenceEnvelope.sign(
      'incident-1',
      await s.a.identity(),
      s.clock.now.add(const Duration(seconds: 5)),
    )).forwardedBy((await s.b.identity()).keyId).toMessage();
    s.network.inject('B', 'C', pulse);
    await s.network.pump();
    s.network.disconnect('A', 'B');
    s.network.allowedLinks.remove(s.network.pair('A', 'B'));
    await s.network.pump();
    s.clock.advance(const Duration(seconds: 40));
    s.network.inject('B', 'C', pulse);
    await s.network.pump();
    s.clock.advance(const Duration(seconds: 6));
    await s.c.coordinator.processDue();
    s.network.inject('B', 'C', pulse);
    await s.network.pump();
    expect(s.c.coordinator.reachableIncidents!.value, isEmpty);
  });

  test('relay cannot forge source freshness and expired replay cannot restore visibility', () async {
    final s = await ready();
    final old = s.network.captures
        .firstWhere(
          (entry) =>
              entry.$1 == 'B' &&
              entry.$2 == 'C' &&
              entry.$3.type == IncidentPresenceEnvelope.wireKind,
        )
        .$3;
    s.network.disconnect('A', 'B');
    s.network.allowedLinks.remove(s.network.pair('A', 'B'));
    await s.network.pump();
    s.clock.advance(const Duration(seconds: 50));
    await s.c.coordinator.processDue();
    final forged = await IncidentPresenceEnvelope.sign(
      'incident-1',
      await s.b.identity(),
      s.clock.now,
    );
    s.network.inject('B', 'C', forged.toMessage());
    s.network.inject('B', 'C', old);
    await s.network.pump();
    expect(s.c.coordinator.reachableIncidents!.value, isEmpty);
    expect(
      (await s.c.db.select(s.c.db.rescueInbox).getSingle()).state,
      'locallyAccepted',
    );
  });
}
