import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ThreeNodeSimulation> ready() async {
    final s = ThreeNodeSimulation(manualRelaySelection: true);
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    // Selecting a previously proven inbound route must remember its key too.
    await s.b.coordinator.connectSelectedPeer('C');
    s.network.disconnect('B', 'C');
    s.network.allowedLinks.remove(s.network.pair('B', 'C'));
    await s.network.pump();
    await s.a.send('queued-rotation', 'same queued message', s.c);
    await s.network.until(
      () async =>
          (await s.b.db.select(s.b.db.chatRelayOutbox).get()).isNotEmpty,
    );
    return s;
  }

  Future<void> recover(ThreeNodeSimulation s) async {
    s.c.transport.rotateLocator('C-new');
    s.network.allow('B', 'C-new');
    s.b.transport.discover('C-new');
    await s.network.until(
      () async => (await s.a.chat.loadMessages('incident-1')).any(
        (m) =>
            m.id == 'queued-rotation' &&
            m.status == ChatDeliveryStatus.delivered,
      ),
    );
    expect(s.network.linked('B', 'C-new'), isTrue);
    expect(s.b.logs, contains('selectedInstallationRecovered'));
    expect(
      (await s.c.chat.loadMessages('incident-1'))
          .where((m) => m.id == 'queued-rotation'),
      hasLength(1),
    );
    expect(s.network.linked('A', 'C-new'), isFalse);
  }

  test('selected installation reconnects after locator rotation and delivers the original queued Chat', () async {
    final s = await ready();
    await recover(s);
    // A stale picker alias may still be visible. Selecting the same proven
    // installation through that alias must not quarantine the active route.
    await s.b.coordinator.connectSelectedPeer('C');
    await s.a.send('after-known-alias', 'same device, existing route', s.c);
    await s.network.until(
      () async => (await s.a.chat.loadMessages('incident-1')).any(
        (m) =>
            m.id == 'after-known-alias' &&
            m.status == ChatDeliveryStatus.delivered,
      ),
    );
  });

  test('cloned discovery hint cannot receive incident data or inject direct SOS before proof', () async {
    final s = await ready();
    final stranger = SimNode('stranger', 9, s.network);
    addTearDown(stranger.close);
    await stranger.start();
    s.network.allow('B', 'stranger');
    s.network.dropMessage = (from, to, message) =>
        from == 'stranger' &&
        to == 'B' &&
        {
          RelayCapabilityAdvertisement.wireKind,
          RelaySessionChallenge.wireKind,
          RelaySessionResponse.wireKind,
        }.contains(message.type);
    s.b.transport.discover(
      'stranger',
      recoveryHint: s.c.transport.discoveryIdentityHint,
    );
    await s.network.until(() async => s.network.linked('B', 'stranger'));
    await s.network.pump();
    await stranger.materialize('untrusted-direct-sos');
    final fake = SosBleEnvelope.fromSosMessage(
      await stranger.db.select(stranger.db.sosMessages).getSingle(),
      messageId: 'untrusted-direct',
      senderDeviceId: 'stranger',
    ).toBleMessage();
    for (final frame in BleMessageCodec.encode(fake)) {
      await stranger.transport.send(
        'B',
        frame,
        role: BleSessionRole.peripheral,
      );
    }
    await s.network.pump();
    expect(s.b.logs, contains('recoveryPeerDataBlocked'));
    expect(
      (await s.b.db.select(s.b.db.sosMessages).get()).where(
        (r) => r.id == 'untrusted-direct-sos',
      ),
      isEmpty,
    );
    final capability = s.network.captures
        .firstWhere(
          (p) =>
              p.$1 == 'stranger' &&
              p.$2 == 'B' &&
              p.$3.type == RelayCapabilityAdvertisement.wireKind,
        )
        .$3;
    s.network.dropMessage = null;
    for (final frame in BleMessageCodec.encode(capability)) {
      await stranger.transport.send(
        'B',
        frame,
        role: BleSessionRole.peripheral,
      );
    }
    await s.network.pump();
    expect(
      s.b.logs.any((l) => l.contains('relayRecoveryIdentityRejected')),
      isTrue,
    );
    expect(s.network.linked('B', 'stranger'), isFalse);
    final allowed = {
      RelayCapabilityAdvertisement.wireKind,
      RelaySessionChallenge.wireKind,
      RelaySessionResponse.wireKind,
    };
    expect(
      s.network.captures.where(
        (p) =>
            p.$1 == 'B' && p.$2 == 'stranger' && !allowed.contains(p.$3.type),
      ),
      isEmpty,
    );
    // A rejected clone must not revoke the real installation's selection.
    await recover(s);
  });

  test('explicit disconnect prevents recovery of every new locator for that installation', () async {
    final s = await ready();
    await s.b.coordinator.disconnectSelectedPeer('C');
    s.c.transport.rotateLocator('C-new');
    s.network.allow('B', 'C-new');
    final attempts = s.b.transport.connectionCalls;
    s.b.transport.discover('C-new');
    await s.network.pump();
    expect(s.b.transport.connectionCalls, attempts);
    expect(s.network.linked('B', 'C-new'), isFalse);
  });
}
