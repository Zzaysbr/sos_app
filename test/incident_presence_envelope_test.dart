import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/domain/incident_presence_envelope.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 11);
  Future<IncidentPresenceEnvelope> pulse() async =>
      IncidentPresenceEnvelope.sign(
        'incident',
        await RelayIdentityService(keyStore: SimulationKeys(1))
            .loadOrCreate(allowCreate: true),
        now,
      );

  test(
    'signed contact forwards without changing source or signed expiry',
    () async {
      final original = await pulse();
      final middle = await RelayIdentityService(keyStore: SimulationKeys(2))
          .loadOrCreate(allowCreate: true);
      final forwarded = IncidentPresenceEnvelope.fromMessage(
        original.forwardedBy(middle.keyId).toMessage(),
      );
      await forwarded.verify(now.add(const Duration(seconds: 44)));
      expect(forwarded.keyId, original.keyId);
      expect(forwarded.expiresAt, original.expiresAt);
      expect(forwarded.toMessage().payload.containsKey('latitude'), isFalse);
      expect(forwarded.toMessage().payload.containsKey('longitude'), isFalse);
      await expectLater(
        forwarded.verify(now.add(const Duration(seconds: 45))),
        throwsException,
      );
    },
  );

  for (final field in [
    'incidentId',
    'keyId',
    'signature',
    'expiresAt',
    'scope',
  ]) {
    test('rejects tampered $field', () async {
      final original = await pulse();
      final wire = original.toMessage();
      final changed = {
        ...wire.payload,
        field: switch (field) {
          'incidentId' => 'other-incident',
          'keyId' => 'A' * 43 + '=',
          'signature' => 'A' * 86 + '==',
          'scope' => 'direct',
          _ => now.add(const Duration(minutes: 30)).toIso8601String(),
        },
      };
      await expectLater(() async {
        final value = IncidentPresenceEnvelope.fromMessage(
          BleMessage(
            id: wire.id,
            type: wire.type,
            createdAt: wire.createdAt,
            payload: changed,
          ),
        );
        await value.verify(now);
      }, throwsException);
    });
  }

  test('rejects future clock beyond tolerance, wrong transport ID, loops and excess hops', () async {
    final value = await pulse();
    await expectLater(
      value.verify(now.subtract(const Duration(seconds: 6))),
      throwsException,
    );
    final wire = value.toMessage();
    expect(
      () => IncidentPresenceEnvelope.fromMessage(
        BleMessage(
          id: 'changed',
          type: wire.type,
          createdAt: wire.createdAt,
          payload: wire.payload,
        ),
      ),
      throwsException,
    );
    expect(() => value.forwardedBy(value.keyId), throwsException);
    final b = await RelayIdentityService(keyStore: SimulationKeys(2))
        .loadOrCreate(allowCreate: true);
    final c = await RelayIdentityService(keyStore: SimulationKeys(3))
        .loadOrCreate(allowCreate: true);
    final full = value.forwardedBy(b.keyId).forwardedBy(c.keyId);
    expect(() => full.forwardedBy('other'), throwsException);
  });
}
