import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

void main() {
  test('parses disconnect events with or without an error', () {
    final withoutError = BleEvent.fromMap({
      'type': 'disconnected',
      'device': {'id': 'peer'},
    });
    expect(withoutError.error, isNull);

    final withError = BleEvent.fromMap({
      'type': 'disconnected',
      'error': 'status 133',
    });
    expect(withError.error, 'status 133');
  });

  test('handles missing and unexpected optional event values safely', () {
    final event = BleEvent.fromMap({
      'type': 42,
      'state': 7,
      'error': const Object(),
      'device': {'id': 99, 'name': 12},
      'payload': ['invalid'],
    });
    expect(event.type, 'unknown');
    expect(event.state, isNull);
    expect(event.error, isNull);
    expect(event.device?.id, isEmpty);
    expect(event.device?.name, isNull);
    expect(event.payload, isNull);
  });

  test('preserves scan session and connection attempt diagnostics', () {
    final event = BleEvent.fromMap({
      'type': 'connecting',
      'scanSession': 3,
      'attempt': 7.0,
    });
    expect(event.scanSession, 3);
    expect(event.attempt, 7);
  });
}
