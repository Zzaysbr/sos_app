import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'three-node authorized signed Chat persists both ways exactly once',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      await s.start();
      // Production authorization requires a verified origin and signed Help Offer.
      await s.prepareIncident();
      s.network.duplicatePackets = true;
      await s.c.send('m1', 'M1', s.a);
      await s.network.until(
        () async =>
            (await s.a.chat.loadMessages('incident-1'))
                .any((m) => m.id == 'm1'),
      );
      await s.a.send('m2', 'M2', s.c);
      await s.network.until(
        () async =>
            (await s.c.chat.loadMessages('incident-1'))
                .any((m) => m.id == 'm2'),
      );
      for (final n in [s.a, s.c]) {
        final messages = await n.chat.loadMessages('incident-1');
        expect(messages.where((m) => m.id == 'm1'), hasLength(1));
        expect(messages.where((m) => m.id == 'm2'), hasLength(1));
      }
      await s.network.until(
        () async =>
            (await s.a.chat.loadMessages('incident-1'))
                    .singleWhere((m) => m.id == 'm2')
                    .status ==
                ChatDeliveryStatus.delivered &&
            (await s.c.chat.loadMessages('incident-1'))
                    .singleWhere((m) => m.id == 'm1')
                    .status ==
                ChatDeliveryStatus.delivered,
      );
    },
  );
}
