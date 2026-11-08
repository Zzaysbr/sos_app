import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/domain/incident_lifecycle_envelope.dart';

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
