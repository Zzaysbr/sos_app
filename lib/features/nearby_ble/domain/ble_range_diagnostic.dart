import '../data/ble_protocol.dart';

const bleRangePingType = 'debug.range.ping.v1';
const bleRangeAckType = 'debug.range.ack.v1';

class BleRangeDiagnosticMessage {
  const BleRangeDiagnosticMessage._();

  static BleMessage ping({
    required String runId,
    required int sequence,
    required DateTime sentAt,
  }) => BleMessage(
    id: '$runId:$sequence',
    type: bleRangePingType,
    createdAt: sentAt.toUtc(),
    payload: {'run': runId, 'seq': sequence},
  );

  static BleMessage acknowledgement({
    required BleMessage ping,
    required DateTime receivedAt,
  }) => BleMessage(
    id: 'ack:${ping.id}',
    type: bleRangeAckType,
    createdAt: receivedAt.toUtc(),
    payload: {'for': ping.id},
  );

  static String? acknowledgedMessageId(BleMessage message) {
    if (message.type != bleRangeAckType) return null;
    final value = message.payload['for'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

class BleRangeSnapshot {
  const BleRangeSnapshot({
    required this.runId,
    required this.targetPeerId,
    required this.startedAt,
    required this.elapsed,
    required this.attempted,
    required this.acknowledged,
    required this.nativeFailed,
    required this.timedOut,
    required this.pending,
    required this.disconnects,
    required this.reconnects,
    required this.connectionState,
    required this.ackLatencies,
  });

  final String runId;
  final String targetPeerId;
  final DateTime startedAt;
  final Duration elapsed;
  final int attempted;
  final int acknowledged;
  final int nativeFailed;
  final int timedOut;
  final int pending;
  final int disconnects;
  final int reconnects;
  final String connectionState;
  final List<Duration> ackLatencies;

  double get packetDeliveryRate =>
      attempted == 0 ? 0 : acknowledged * 100 / attempted;

  Duration? get minimumLatency => _percentile(0);
  Duration? get medianLatency => _percentile(0.5);
  Duration? get p95Latency => _percentile(0.95);
  Duration? get maximumLatency => _percentile(1);
  Duration? get averageLatency {
    if (ackLatencies.isEmpty) return null;
    final total = ackLatencies.fold<int>(
      0,
      (sum, item) => sum + item.inMicroseconds,
    );
    return Duration(microseconds: (total / ackLatencies.length).round());
  }

  Duration? _percentile(double percentile) {
    if (ackLatencies.isEmpty) return null;
    final sorted = [...ackLatencies]..sort();
    final index = ((sorted.length - 1) * percentile).ceil();
    return sorted[index];
  }
}

class BleRangeTestSession {
  BleRangeTestSession({
    required this.runId,
    required this.targetPeerId,
    required this.startedAt,
  });

  final String runId;
  final String targetPeerId;
  final DateTime startedAt;
  final Map<String, DateTime> _pending = {};
  final List<Duration> _ackLatencies = [];
  int _attempted = 0;
  int _acknowledged = 0;
  int _nativeFailed = 0;
  int _timedOut = 0;
  int _disconnects = 0;
  int _reconnects = 0;
  bool _wasDisconnected = false;
  String _connectionState = 'connected';

  void recordAttempt(String messageId, DateTime sentAt) {
    _attempted++;
    _pending[messageId] = sentAt.toUtc();
  }

  bool recordNativeFailure(String messageId) {
    if (_pending.remove(messageId) == null) return false;
    _nativeFailed++;
    return true;
  }

  bool recordAcknowledgement({
    required String messageId,
    required String sourcePeerId,
    required DateTime receivedAt,
  }) {
    if (_peerKey(sourcePeerId) != _peerKey(targetPeerId)) return false;
    final sentAt = _pending.remove(messageId);
    if (sentAt == null) return false;
    final latency = receivedAt.toUtc().difference(sentAt);
    if (latency.isNegative) return false;
    _acknowledged++;
    _ackLatencies.add(latency);
    return true;
  }

  int expire({required DateTime now, required Duration timeout}) {
    final expired = _pending.entries
        .where((entry) => now.toUtc().difference(entry.value) >= timeout)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final id in expired) {
      _pending.remove(id);
    }
    _timedOut += expired.length;
    return expired.length;
  }

  void recordDisconnected() {
    _connectionState = 'disconnected';
    if (!_wasDisconnected) {
      _disconnects++;
      _wasDisconnected = true;
    }
  }

  void recordConnected() {
    _connectionState = 'connected';
    if (_wasDisconnected) {
      _reconnects++;
      _wasDisconnected = false;
    }
  }

  BleRangeSnapshot snapshot(DateTime now) => BleRangeSnapshot(
    runId: runId,
    targetPeerId: targetPeerId,
    startedAt: startedAt,
    elapsed: now.toUtc().difference(startedAt),
    attempted: _attempted,
    acknowledged: _acknowledged,
    nativeFailed: _nativeFailed,
    timedOut: _timedOut,
    pending: _pending.length,
    disconnects: _disconnects,
    reconnects: _reconnects,
    connectionState: _connectionState,
    ackLatencies: List.unmodifiable(_ackLatencies),
  );

  static String _peerKey(String value) => value.trim().toLowerCase();
}
