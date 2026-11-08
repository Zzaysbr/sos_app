import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'stale native disconnect cannot retire a newer proven session',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      await s.start();
      final retired = s.network.connections[s.network.pair('A', 'B')]!.$2;
      s.network.disconnect('A', 'B');
      await s.network.pump();
      s.network.connect('A', 'B');
      await s.network.until(() => s.a.authenticated());
      // Bypass the simulator's generation filter to reproduce an incorrectly
      // surfaced native callback at the real coordinator's external boundary.
      s.a.transport.emit(
        BleEvent(
          type: 'disconnected',
          device: BleDevice(id: 'B'),
          role: BleSessionRole.central,
          attempt: retired,
        ),
      );
      s.b.transport.emit(
        BleEvent(
          type: 'disconnected',
          device: BleDevice(id: 'A'),
          role: BleSessionRole.peripheral,
          attempt: retired,
        ),
      );
      await s.network.pump();
      expect(
        await s.a.authenticated(),
        isTrue,
        reason:
            'A delayed disconnect must not retire the newer proven session.',
      );
      await s.prepareIncident();
      await s.a.send('after-stale-disconnect', 'still connected', s.c);
      await s.network.until(
        () async =>
            (await s.c.chat.loadMessages('incident-1'))
                .any((m) => m.id == 'after-stale-disconnect'),
      );

      s.network.disconnect('A', 'B');
      await s.network.pump();
      expect(await s.a.authenticated(), isFalse);
      expect(await s.c.authenticated(), isTrue);
    },
  );

  test(
    'new native readiness without disconnect requires fresh Session Proof',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      await s.start();
      final retired = s.network.connections[s.network.pair('A', 'B')]!.$2;
      s.network.holdPackets = true;
      s.network.connections.remove(s.network.pair('A', 'B'));
      s.network.connect('A', 'B');
      await s.network.pump();
      expect(await s.a.authenticated(), isFalse);
      // Even old readiness cannot restore or replace the new pending proof.
      s.a.transport.emit(
        BleEvent(
          type: 'connected',
          device: BleDevice(id: 'B'),
          role: BleSessionRole.central,
          attempt: retired,
        ),
      );
      await s.network.pump();
      expect(await s.a.authenticated(), isFalse);
      s.network.holdPackets = false;
      s.network.releaseHeld();
      await s.network.until(() => s.a.authenticated());
      expect(await s.a.authenticated(), isTrue);
      s.network.holdPackets = true;
      s.a.transport.emit(
        BleEvent(
          type: 'connected',
          device: BleDevice(id: 'B'),
          role: BleSessionRole.central,
          attempt: s.network.connections[s.network.pair('A', 'B')]!.$2,
        ),
      );
      await s.network.pump();
      expect(
        await s.a.authenticated(),
        isTrue,
        reason: 'Repeated readiness for the same attempt must preserve proof.',
      );
    },
  );
}
