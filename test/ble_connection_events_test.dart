import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_connection_events.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

void main() {
  BleEvent event(
    String type, {
    int? attempt,
    BleSessionRole? role = BleSessionRole.central,
    String peer = 'peer',
  }) => BleEvent(
    type: type,
    device: BleDevice(id: peer),
    role: role,
    attempt: attempt,
  );

  test('old and unrelated disconnects cannot consume current generation', () {
    final events = BleConnectionEvents();
    events.accept(event('connected', attempt: 2));
    expect(events.accept(event('disconnected', attempt: 1)), isEmpty);
    expect(events.accept(event('disconnected', attempt: 3)), isEmpty);
    expect(events.accept(event('connected', attempt: 1)), isEmpty);
    expect(events.accept(event('disconnected', attempt: 2)), hasLength(1));
  });

  test(
    'peer and role attempts are independent, including role-less disconnect',
    () {
      final events = BleConnectionEvents();
      events.accept(event('connected', attempt: 2));
      events.accept(
        event('connected', attempt: 7, role: BleSessionRole.peripheral),
      );
      events.accept(event('connected', attempt: 9, peer: 'other'));
      final accepted = events.accept(
        event('disconnected', attempt: 2, role: null),
      );
      expect(accepted.map((e) => e.role), [BleSessionRole.central]);
      expect(
        events.accept(
          event('disconnected', attempt: 2, role: BleSessionRole.peripheral),
        ),
        isEmpty,
      );
      expect(
        events.accept(event('disconnected', attempt: 2, peer: 'other')),
        isEmpty,
      );
      expect(
        events.accept(
          event('disconnected', attempt: 7, role: BleSessionRole.peripheral),
        ),
        hasLength(1),
      );
      expect(
        events.accept(event('disconnected', attempt: 9, peer: 'other')),
        hasLength(1),
      );
    },
  );

  test(
    'missing generation still retires a session for legacy native events',
    () {
      final events = BleConnectionEvents();
      events.accept(event('connected', attempt: 2));
      expect(events.accept(event('disconnected')), hasLength(1));
      events.accept(event('connected', role: BleSessionRole.peripheral));
      expect(events.accept(event('disconnected', role: null)), hasLength(1));
      events.clear();
      expect(events.accept(event('connected', attempt: 1)), hasLength(1));
    },
  );
}
