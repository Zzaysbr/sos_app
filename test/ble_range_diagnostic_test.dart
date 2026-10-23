import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_range_diagnostic.dart';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);

  test('reports application ACK delivery rate and latency percentiles', () {
    final session = BleRangeTestSession(
      runId: 'run-1',
      targetPeerId: 'Peer-A',
      startedAt: start,
    );
    for (var i = 0; i < 4; i++) {
      session.recordAttempt('run-1:$i', start.add(Duration(seconds: i)));
    }
    expect(
      session.recordAcknowledgement(
        messageId: 'run-1:0',
        sourcePeerId: 'peer-a',
        receivedAt: start.add(const Duration(milliseconds: 100)),
      ),
      isTrue,
    );
    session.recordAcknowledgement(
      messageId: 'run-1:1',
      sourcePeerId: 'PEER-A',
      receivedAt: start.add(const Duration(seconds: 1, milliseconds: 300)),
    );
    session.recordAcknowledgement(
      messageId: 'run-1:2',
      sourcePeerId: 'peer-a',
      receivedAt: start.add(const Duration(seconds: 2, milliseconds: 500)),
    );
    session.expire(
      now: start.add(const Duration(seconds: 10)),
      timeout: const Duration(seconds: 3),
    );

    final result = session.snapshot(start.add(const Duration(seconds: 10)));
    expect(result.attempted, 4);
    expect(result.acknowledged, 3);
    expect(result.timedOut, 1);
    expect(result.packetDeliveryRate, 75);
    expect(result.minimumLatency, const Duration(milliseconds: 100));
    expect(result.medianLatency, const Duration(milliseconds: 300));
    expect(result.p95Latency, const Duration(milliseconds: 500));
    expect(result.averageLatency, const Duration(milliseconds: 300));
  });

  test('rejects wrong-peer, duplicate and late application ACKs', () {
    final session = BleRangeTestSession(
      runId: 'run-2',
      targetPeerId: 'peer-a',
      startedAt: start,
    );
    session.recordAttempt('run-2:0', start);
    expect(
      session.recordAcknowledgement(
        messageId: 'run-2:0',
        sourcePeerId: 'peer-b',
        receivedAt: start.add(const Duration(milliseconds: 50)),
      ),
      isFalse,
    );
    session.expire(
      now: start.add(const Duration(seconds: 3)),
      timeout: const Duration(seconds: 3),
    );
    expect(
      session.recordAcknowledgement(
        messageId: 'run-2:0',
        sourcePeerId: 'peer-a',
        receivedAt: start.add(const Duration(seconds: 4)),
      ),
      isFalse,
    );
    expect(session.snapshot(start).acknowledged, 0);
  });

  test('separates native failure and reconnect transitions', () {
    final session = BleRangeTestSession(
      runId: 'run-3',
      targetPeerId: 'peer-a',
      startedAt: start,
    );
    session.recordAttempt('run-3:0', start);
    expect(session.recordNativeFailure('run-3:0'), isTrue);
    expect(session.recordNativeFailure('run-3:0'), isFalse);
    session.recordDisconnected();
    session.recordDisconnected();
    session.recordConnected();
    session.recordConnected();

    final result = session.snapshot(start.add(const Duration(seconds: 1)));
    expect(result.nativeFailed, 1);
    expect(result.acknowledged, 0);
    expect(result.disconnects, 1);
    expect(result.reconnects, 1);
    expect(result.connectionState, 'connected');
  });
}
