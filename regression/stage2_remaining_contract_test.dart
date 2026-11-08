// Executable final Chat receipt acceptance contract (implemented in schema v10).
// Run explicitly: flutter test regression/stage2_remaining_contract_test.dart
// The fixed stale-disconnect contract is in test/ble_connection_generation_test.dart.
// Expectation preserved; run separately as well as the default suite.
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';

import '../test/support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'recipient persistence eventually yields signed final Chat delivery',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      await s.start();
      await s.prepareIncident();
      await s.a.send('final-receipt', 'persisted at C', s.c);
      await s.network.until(
        () async =>
            (await s.c.chat.loadMessages('incident-1'))
                .any((m) => m.id == 'final-receipt'),
      );
      await s.network.pump();
      expect(
        (await s.a.chat.loadMessages('incident-1')).single.status,
        ChatDeliveryStatus.delivered,
        reason: 'Only a verified signed recipient persistence receipt may imply delivered.',
      );
    },
  );
}
