import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';

SosMessage _sos({double? latitude = 13.7563, double? longitude = 100.5018}) =>
    SosMessage(
      id: 'sos-123',
      ownerId: 'owner-1',
      type: 'emergency',
      message: 'Help',
      latitude: latitude,
      longitude: longitude,
      status: 'active',
      syncState: 'pending',
      createdAt: DateTime.utc(2026, 1, 1, 10),
      updatedAt: DateTime.utc(2026, 1, 1, 10, 1),
    );

void main() {
  test('round trips a delivery and maps back to the existing SOS schema', () {
    final envelope = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'transport-1',
      senderDeviceId: 'device-a',
    );

    final decoded = SosBleEnvelope.fromBleMessage(envelope.toBleMessage());
    final companion = decoded.toSosCompanion(ownerId: 'owner-1');

    expect(decoded.messageId, 'transport-1');
    expect(decoded.sosId, 'sos-123');
    expect(companion.id.value, 'sos-123');
    expect(companion.latitude.value, 13.7563);
    expect(companion.status.value, 'active');
  });

  test('keeps messageId stable when the same envelope is encoded again', () {
    final envelope = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'retry-message',
    );

    expect(envelope.toBleMessage().id, envelope.toBleMessage().id);
    expect(envelope.toJson()['messageId'], 'retry-message');
  });

  test('rejects malformed JSON, missing fields, and unsupported versions', () {
    expect(
      () => SosBleEnvelope.fromJsonString('{not json'),
      throwsA(isA<SosBleEnvelopeException>()),
    );
    expect(
      () => SosBleEnvelope.fromJson(const {'schemaVersion': 1}),
      throwsA(isA<SosBleEnvelopeException>()),
    );
    expect(
      () => SosBleEnvelope.fromJson({..._deliveryJson(), 'schemaVersion': 999}),
      throwsA(isA<SosBleEnvelopeException>()),
    );
  });

  test('rejects a transport type that disagrees with the envelope kind', () {
    final envelope = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'transport-mismatch',
    );
    final message = BleMessage(
      id: envelope.messageId,
      type: 'chat.message',
      createdAt: envelope.createdAt,
      payload: envelope.toJson(),
    );
    expect(
      () => SosBleEnvelope.fromBleMessage(message),
      throwsA(isA<SosBleEnvelopeException>()),
    );
  });

  test('rejects invalid coordinates and mismatched coordinate pairs', () {
    expect(
      () => SosBleEnvelope.delivery(
        messageId: 'm',
        sosId: 's',
        sosType: 'emergency',
        status: 'active',
        latitude: 91,
        longitude: 10,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      throwsA(isA<SosBleEnvelopeException>()),
    );
    expect(
      () => SosBleEnvelope.delivery(
        messageId: 'm',
        sosId: 's',
        sosType: 'emergency',
        status: 'active',
        latitude: 10,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
      throwsA(isA<SosBleEnvelopeException>()),
    );
  });

  test('rejects an envelope over the application payload limit', () {
    final json = _deliveryJson()..['message'] = 'x' * 20_000;
    expect(
      () => SosBleEnvelope.fromJson(json),
      throwsA(isA<SosBleEnvelopeException>()),
    );
  });

  test('supports typed acknowledgement without treating it as delivery', () {
    final ack = SosBleEnvelope.acknowledgement(
      messageId: 'ack-message',
      sosId: 'sos-123',
      ackFor: 'transport-1',
      ackStatus: SosBleAckStatus.persisted,
      createdAt: DateTime.utc(2026),
    );
    final decoded = SosBleEnvelope.fromBleMessage(ack.toBleMessage());

    expect(decoded.kind, SosBleMessageKind.acknowledgement);
    expect(decoded.ackFor, 'transport-1');
    expect(
      () => decoded.toSosCompanion(ownerId: 'owner-1'),
      throwsA(isA<SosBleEnvelopeException>()),
    );
  });

  test('round trips chat messages and chat acknowledgements', () {
    final message = SosBleEnvelope.chatMessage(
      messageId: 'chat-1',
      sosId: 'sos-1',
      senderDeviceId: 'device-a',
      chatSenderId: 'user-a',
      chatText: 'Need assistance',
      createdAt: DateTime.utc(2026),
    );
    final parsed = SosBleEnvelope.fromJsonString(jsonEncode(message.toJson()));
    expect(parsed.kind, SosBleMessageKind.chatMessage);
    expect(parsed.chatText, 'Need assistance');

    final ack = SosBleEnvelope.chatAcknowledgement(
      messageId: 'ack:chat-1',
      sosId: 'sos-1',
      ackFor: 'chat-1',
      ackStatus: SosBleAckStatus.persisted,
      createdAt: DateTime.utc(2026),
    );
    expect(
      SosBleEnvelope.fromJsonString(jsonEncode(ack.toJson())).kind,
      SosBleMessageKind.chatAcknowledgement,
    );
  });

  test('rejects empty or oversized chat text', () {
    expect(
      () => SosBleEnvelope.chatMessage(
        messageId: 'chat-1',
        sosId: 'sos-1',
        senderDeviceId: 'device-a',
        chatSenderId: 'user-a',
        chatText: '',
        createdAt: DateTime.utc(2026),
      ),
      throwsA(isA<SosBleEnvelopeException>()),
    );
    expect(
      () => SosBleEnvelope.chatMessage(
        messageId: 'chat-1',
        sosId: 'sos-1',
        senderDeviceId: 'device-a',
        chatSenderId: 'user-a',
        chatText: 'x' * (SosBleEnvelope.maxMessageLength + 1),
        createdAt: DateTime.utc(2026),
      ),
      throwsA(isA<SosBleEnvelopeException>()),
    );
  });
}

Map<String, Object?> _deliveryJson() => {
  'schemaVersion': 1,
  'kind': 'sos.delivery',
  'messageId': 'transport-1',
  'sosId': 'sos-123',
  'type': 'emergency',
  'status': 'active',
  'message': 'Help',
  'latitude': 13.7563,
  'longitude': 100.5018,
  'createdAt': '2026-01-01T10:00:00.000Z',
  'updatedAt': '2026-01-01T10:01:00.000Z',
};
