import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('device-free idle scheduler counters over 60 virtual seconds', () async {
    final s = ThreeNodeSimulation();
    addTearDown(s.close);
    // No incident, peer links or pending jobs: isolate idle scheduler work.
    for (final node in [s.a, s.b, s.c]) {
      await node.start();
      node.sql.reset();
      node.logs.clear();
    }
    final watch = Stopwatch()..start();
    for (var tick = 0; tick < 12; tick++) {
      s.clock.advance(const Duration(seconds: 5));
      for (final node in [s.a, s.b, s.c]) {
        await node.coordinator.processDue();
      }
    }
    watch.stop();
    expect(s.network.frameWrites, 0);
    expect(s.network.connections, isEmpty);
    // Measurements have no timing threshold: host speed is not mobile FPS.
    // ignore: avoid_print
    print(
      'SIMULATION_IDLE ${jsonEncode({
        'virtualSeconds': 60,
        'explicitTicksPerNode': 12,
        'hostMicroseconds': watch.elapsedMicroseconds,
        'nodes': {
          for (final n in [s.a, s.b, s.c]) n.id: {'sql': n.sql.snapshot, 'hopTicks': n.logs.where((l) => l.contains('relay_scheduler_tick')).length, 'connectCalls': n.transport.connectionCalls, 'discoveryStarts': n.transport.discoveryStarts, 'discoveryStops': n.transport.discoveryStops},
        },
      })}',
    );
  });
}
