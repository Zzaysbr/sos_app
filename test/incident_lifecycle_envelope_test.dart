import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/domain/incident_lifecycle_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

Future<RelaySigningIdentity> _identity() async {
  final algorithm = Ed25519();
  final pair = await algorithm.newKeyPair();
  final public = (await pair.extractPublicKey()).bytes;
  final keyId = await RelayCryptography().publicKeyId(public);
  return RelaySigningIdentity(keyPair: pair, publicKey: public, keyId: keyId);
}

void main() {
  test('signs and verifies a terminal lifecycle event', () async {
    final identity = await _identity();
    final event = await IncidentLifecycleEnvelope.sign(
      incidentId: 'incident-1',
      status: 'cancelled',
      identity: identity,
      now: DateTime.utc(2026, 1, 1),
    );

    await expectLater(event.validate(now: DateTime.utc(2026, 1, 1)), completes);
    final decoded = IncidentLifecycleEnvelope.fromJson(
      jsonDecode(event.toCanonicalWire()) as Map<String, Object?>,
    );
    await expectLater(decoded.validate(), completes);
  });

  test('rejects tampered status and unauthorized actor', () async {
    final identity = await _identity();
    final event = await IncidentLifecycleEnvelope.sign(
      incidentId: 'incident-2',
      status: 'resolved',
      identity: identity,
      now: DateTime.utc(2026, 1, 1),
    );
    final tampered = IncidentLifecycleEnvelope.fromJson({
      ...event.toJson(),
      'status': 'cancelled',
    });
    await expectLater(
      tampered.validate(),
      throwsA(isA<RelayProtocolException>()),
    );
    final unauthorized = IncidentLifecycleEnvelope(
      eventId: event.eventId,
      incidentId: event.incidentId,
      status: event.status,
      originKeyId: event.originKeyId,
      originPublicKey: event.originPublicKey,
      actorKeyId: 'other-actor',
      createdAt: event.createdAt,
      signature: event.signature,
    );
    await expectLater(
      unauthorized.validate(),
      throwsA(isA<RelayProtocolException>()),
    );
  });
}
