import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/domain/incident_lifecycle_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ThreeNodeSimulation> ready() async {
    final s = ThreeNodeSimulation();
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    await s.network.pump();
    return s;
  }

  Future<void> cancel(
    ThreeNodeSimulation s, {
    String storedStatus = 'cancelled',
  }) async {
    await (s.a.db.update(s.a.db.sosMessages)
          ..where((r) => r.id.equals('incident-1')))
        .write(SosMessagesCompanion(status: Value(storedStatus)));
    await s.a.coordinator.enqueueIncidentLifecycle(
      sosId: 'incident-1',
      status: 'cancelled',
      destinationId: 'retired-native-address',
    );
    await s.network.pump();
  }

  Future<String> recipientStatus(ThreeNodeSimulation s) async =>
      (await s.c.db.select(s.c.db.sosMessages).getSingle()).status;

  for (final failReplay in [false, true]) {
    test(
      'lifecycle replay is once per connection and retries after reconnect ($failReplay)',
      () async {
        final s = await ready();
        s.network.disconnect('B', 'C');
        await s.network.pump();
        await (s.a.db.update(s.a.db.sosMessages)
              ..where((r) => r.id.equals('incident-1')))
            .write(const SosMessagesCompanion(status: Value('cancelled')));
        await s.a.coordinator.enqueueIncidentLifecycle(
          sosId: 'incident-1',
          status: 'cancelled',
          destinationId: 'B',
        );
        await s.a.coordinator.processDue();
        await s.network.until(
          () async =>
              (await s.b.db.select(s.b.db.sosMessages).getSingle()).status ==
              'cancelled',
        );
        if (failReplay) {
          s.network.failMessageTypeOnce = IncidentLifecycleEnvelope.wireKind;
        }
        s.network.connect('C', 'B');
        await s.network.pump();
        int replays() => s.network.captures
            .where(
              (p) =>
                  p.$1 == 'B' &&
                  p.$2 == 'C' &&
                  p.$3.type == IncidentLifecycleEnvelope.wireKind,
            )
            .length;
        expect(replays(), 1);
        if (!failReplay) expect(await recipientStatus(s), 'cancelled');
        final generation = s.network.connections[s.network.pair('B', 'C')]!.$2;
        s.b.transport.emit(
          BleEvent(
            type: 'connected',
            device: const BleDevice(id: 'C'),
            role: BleSessionRole.peripheral,
            attempt: generation,
          ),
        );
        await s.network.pump();
        for (var retry = 0; retry < 3; retry++) {
          s.b.transport.emit(
            BleEvent(
              type: 'connected',
              device: const BleDevice(id: 'C'),
              role: BleSessionRole.peripheral,
              attempt: generation,
            ),
          );
        }
        await s.network.pump();
        expect(
          replays(),
          1,
          reason: 'repeated readiness callbacks must coalesce',
        );
        if (failReplay) {
          s.network.disconnect('B', 'C');
          await s.network.pump();
          s.network.connect('C', 'B');
          await s.network.until(
            () async => await recipientStatus(s) == 'cancelled',
          );
          expect(replays(), 2);
        }
      },
    );
  }

  test(
    'relay reconnects a selected peer and sends the same queued SOS',
    () async {
      final s = ThreeNodeSimulation(manualRelaySelection: true);
      addTearDown(s.close);
      await s.start();
      await s.b.coordinator.connectSelectedPeer('C');
      s.network.disconnect('B', 'C');
      s.network.allowedLinks.remove(s.network.pair('B', 'C'));
      await s.network.pump();
      await s.b.coordinator.processDue();
      expect(s.b.transport.discovering, isTrue);

      const incident = 'queued-while-disconnected';
      await s.a.materialize(incident);
      await s.a.coordinator.enqueuePublicRelay(
        await s.a.db.select(s.a.db.sosMessages).getSingle(),
        includeLocation: false,
        scope: RelayAuthorizationScope.voluntaryRescue,
      );
      await s.network.until(
        () async =>
            (await s.b.db.select(s.b.db.bleRelayMessages).get()).isNotEmpty,
      );
      expect(await s.c.db.select(s.c.db.rescueInbox).get(), isEmpty);

      s.network.allow('B', 'C');
      s.b.transport.discover('C');
      await s.network.until(
        () async => (await s.c.db.select(s.c.db.rescueInbox).get()).isNotEmpty,
      );
      final received = await s.c.db.select(s.c.db.rescueInbox).getSingle();
      expect(received.incidentId, incident);
      expect(received.incomingHopCount, 1);
      expect(s.network.linked('A', 'C'), isFalse);
    },
  );

  test(
    'active SOS renews the same incident and expires when origin stops',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      await s.start();
      const incident = 'renewed-origin';
      await s.a.materialize(incident);
      await s.a.coordinator.enqueuePublicRelay(
        await s.a.db.select(s.a.db.sosMessages).getSingle(),
        includeLocation: false,
        scope: RelayAuthorizationScope.voluntaryRescue,
      );
      Future<List<RescueInboxData>> received() =>
          s.c.db.select(s.c.db.rescueInbox).get();
      await s.network.until(() async => (await received()).isNotEmpty);
      final first = (await received()).single;
      s.clock.advance(const Duration(minutes: 16));
      await s.a.coordinator.processDue();
      await s.network.until(
        () async =>
            (await received()).single.expiresAt.isAfter(first.expiresAt),
      );
      final renewed = (await received()).single;
      expect(renewed.originMessageId, first.originMessageId);
      expect(renewed.immutableDigest, first.immutableDigest);
      expect(renewed.incidentId, first.incidentId);

      await s.a.coordinator.stop();
      s.clock.advance(const Duration(minutes: 31));
      await s.b.coordinator.processDue();
      await s.c.coordinator.processDue();
      expect(await s.b.db.select(s.b.db.bleRelayMessages).get(), isEmpty);
      expect(await s.c.db.select(s.c.db.bleRelayMessages).get(), isEmpty);
      expect((await received()).single.incidentId, incident);
    },
  );

  test(
    'idle peripheral stays connected with replies and retires a silent link',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      s.b.transport.supportsPeripheralRecovery = true;
      // The signed handshake may recover B's identity while C never receives
      // the optional probe capability declaration.
      s.network.dropMessage = (from, to, message) =>
          from == 'B' &&
          to == 'C' &&
          message.type == RelayCapabilityAdvertisement.wireKind;
      await s.start();
      await s.network.pump();

      s.clock.advance(const Duration(seconds: 31));
      await s.b.coordinator.processDue();
      await s.network.until(
        () async => s.network.captures.any(
          (frame) =>
              frame.$1 == 'C' &&
              frame.$2 == 'B' &&
              frame.$3.type == 'sos.link.probe_reply.v1',
        ),
      );
      await s.network.pump();
      expect(s.network.linked('B', 'C'), isTrue);

      s.network.dropMessage = (from, to, message) =>
          from == 'C' && to == 'B' && message.type == 'sos.link.probe_reply.v1';
      s.clock.advance(const Duration(seconds: 31));
      await s.b.coordinator.processDue();
      await s.network.pump();
      expect(s.network.linked('B', 'C'), isTrue);
      s.clock.advance(const Duration(seconds: 46));
      await s.b.coordinator.processDue();
      await s.network.pump();
      expect(s.network.linked('B', 'C'), isFalse);
      expect(s.network.linked('A', 'B'), isTrue);
      expect(
        s.network.captures.where(
          (frame) =>
              frame.$1 == 'B' &&
              frame.$2 == 'C' &&
              frame.$3.type == 'sos.link.probe.v1',
        ),
        hasLength(2),
      );
    },
  );

  test('cancellation clears B and C after the B-C link returns', () async {
    final s = await ready();
    s.network.disconnect('B', 'C');
    await s.network.pump();
    await (s.a.db.update(s.a.db.sosMessages)
          ..where((r) => r.id.equals('incident-1')))
        .write(const SosMessagesCompanion(status: Value('cancelled')));
    await s.a.coordinator.enqueueIncidentLifecycle(
      sosId: 'incident-1',
      status: 'cancelled',
      destinationId: 'B',
    );
    await s.a.coordinator.processDue();
    await s.network.pump();
    expect(
      s.b.logs.where((line) => line.contains('lifecycle')).toList(),
      contains(contains('lifecycle_')),
    );
    await s.network.until(
      () async =>
          (await s.b.db.select(s.b.db.sosMessages).getSingle()).status ==
          'cancelled',
    );
    expect(await recipientStatus(s), 'active');
    s.network.connect('C', 'B');
    await s.network.until(() async => await recipientStatus(s) == 'cancelled');
    expect(await s.c.db.select(s.c.db.sosMessages).get(), hasLength(1));
  });

  test('restores a cancellation expired while Bluetooth was off', () async {
    final s = await ready();
    await cancel(s);
    final query = s.a.db.select(s.a.db.bleOutbox)
      ..where((r) => r.payload.like('%sos.lifecycle.v1%'));
    final original = await query.getSingle();
    await (s.a.db.update(
      s.a.db.bleOutbox,
    )..where((r) => r.messageId.equals(original.messageId))).write(
      const BleOutboxCompanion(
        state: Value('expired'),
        retryCount: Value(19),
        lastError: Value(
          'retry limit reached: Bluetooth adapter state is poweredOff',
        ),
      ),
    );
    expect(await recipientStatus(s), 'active');
    s.network.allow('A', 'C');
    s.network.connect('A', 'C');
    await s.network.pump();
    s.clock.advance(const Duration(seconds: 6));
    await s.a.coordinator.processDue();
    await s.network.until(() async => await recipientStatus(s) == 'cancelled');
    expect((await query.getSingle()).payload, original.payload);
  });

  test('live obsolete next hop does not pin cancellation beside a proven responder route', () async {
    final s = await ready();
    s.network.allow('A', 'C');
    s.network.connect('A', 'C');
    await s.network.until(
      () async =>
          (await s.a.coordinator.relayRuntimeDiagnosticsDataSource
                  .watchRuntimeDiagnostics()
                  .first)
              .peers
              .where((peer) => peer.authenticated)
              .length ==
          2,
    );
    // The old link is still alive but no longer carries terminal messages to C.
    s.network.dropMessage = (from, to, message) =>
        from == 'B' &&
        to == 'C' &&
        message.type == IncidentLifecycleEnvelope.wireKind;
    await (s.a.db.update(s.a.db.sosMessages)
          ..where((row) => row.id.equals('incident-1')))
        .write(const SosMessagesCompanion(status: Value('cancelled')));
    await s.a.coordinator.enqueueIncidentLifecycle(
      sosId: 'incident-1',
      status: 'cancelled',
      destinationId: 'B',
    );
    await s.network.pump();
    final row = await (s.a.db.select(
      s.a.db.bleOutbox,
    )..where((row) => row.payload.like('%sos.lifecycle.v1%'))).getSingle();
    expect(row.destinationId, 'C');
    await s.network.until(() async => await recipientStatus(s) == 'cancelled');
  });

  test('queued terminal event uses new route only after the same responder completes real Session Proof', () async {
    final s = await ready();
    await s.a.coordinator.setRelayParticipationEnabled(false);
    await s.network.pump();
    // Help Offer delivery TTL has elapsed; its immutable identity evidence is
    // still relevant to routing cancellation, not renewed SOS/Help forwarding.
    s.clock.advance(const Duration(minutes: 31));
    s.network.allow('A', 'C');
    s.network.holdPackets = true;
    s.network.connect('A', 'C');
    await s.network.pump();
    await cancel(s);
    expect(await s.a.coordinator.hasPendingLifecycleRecovery(), isTrue);
    expect(
      s.a.transport.discovering,
      isTrue,
      reason: 'Pending cancellation must discover a new route without creating another SOS.',
    );
    final before = await (s.a.db.select(
      s.a.db.bleOutbox,
    )..where((r) => r.payload.like('%sos.lifecycle.v1%'))).getSingle();
    expect(before.destinationId, 'retired-native-address');
    expect(await recipientStatus(s), 'active');
    s.network.holdPackets = false;
    s.network.releaseHeld();
    await s.network.until(
      () async =>
          (await s.a.coordinator.relayRuntimeDiagnosticsDataSource
                  .watchRuntimeDiagnostics()
                  .first)
              .peers
              .where((p) => p.authenticated)
              .length ==
          2,
    );
    // The unsuccessful retired-address connection retained its retry backoff.
    s.clock.advance(const Duration(seconds: 6));
    await s.a.coordinator.processDue();
    await s.network.until(() async => await recipientStatus(s) == 'cancelled');
    final after = await (s.a.db.select(
      s.a.db.bleOutbox,
    )..where((r) => r.payload.like('%sos.lifecycle.v1%'))).getSingle();
    expect(after.messageId, before.messageId);
    expect(after.payload, before.payload);
    expect(after.destinationId, 'C');
    expect(after.state, isNot('acknowledged'));
    final received = await s.c.db.select(s.c.db.bleInbox).get();
    expect(
      received.where((r) => r.processingState == 'lifecycle_authorized'),
      hasLength(1),
    );
  });

  for (final defect in ['other-owner', 'forged-offer', 'superseded-terminal']) {
    test('route recovery rejects $defect evidence', () async {
      final s = await ready();
      s.network.allow('A', 'C');
      s.network.connect('A', 'C');
      await s.network.until(
        () async =>
            (await s.a.coordinator.relayRuntimeDiagnosticsDataSource
                    .watchRuntimeDiagnostics()
                    .first)
                .peers
                .where((p) => p.authenticated)
                .length ==
            2,
      );
      if (defect == 'other-owner') {
        await s.a.db
            .update(s.a.db.rescueResponseInbox)
            .write(
              const RescueResponseInboxCompanion(ownerId: Value('other-owner')),
            );
      } else if (defect == 'forged-offer') {
        final row = await s.a.db.select(s.a.db.rescueResponseInbox).getSingle();
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        payload['signature'] = base64UrlEncode(List<int>.filled(64, 0));
        await s.a.db
            .update(s.a.db.rescueResponseInbox)
            .write(
              RescueResponseInboxCompanion(payload: Value(jsonEncode(payload))),
            );
      }
      await cancel(
        s,
        storedStatus: defect == 'superseded-terminal'
            ? 'resolved'
            : 'cancelled',
      );
      expect(
        (await (s.a.db.select(
              s.a.db.bleOutbox,
            )..where((r) => r.payload.like('%sos.lifecycle.v1%'))).getSingle())
            .destinationId,
        'retired-native-address',
      );
      expect(await recipientStatus(s), 'active');
      expect(
        s.network.captures.where(
          (p) =>
              p.$1 == 'A' &&
              p.$2 == 'C' &&
              p.$3.type == IncidentLifecycleEnvelope.wireKind,
        ),
        isEmpty,
      );
    });
  }
}
