import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

void main() {
  test('signed Chat relay envelope verifies and round-trips', () async {
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final public = (await pair.extractPublicKey()).bytes;
    final crypto = RelayCryptography();
    final senderKeyId = await crypto.publicKeyId(public);
    final now = DateTime.utc(2026, 11, 4, 2);
    final body = ChatRelayBody(
      messageId: 'chat-1',
      incidentId: 'incident-1',
      senderKeyId: senderKeyId,
      senderPublicKey: _b64(public),
      recipientKeyId: 'recipient-key',
      recipientPublicKey: _b64(List<int>.filled(32, 7)),
      originIncidentBinding: 'origin-binding',
      text: 'M1',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );
    final envelope = ChatRelayEnvelope(
      body: body,
      signature: await crypto.signChatRelay(body, pair),
    );
    final decoded = ChatRelayEnvelope.fromCanonicalWire(
      envelope.toCanonicalWire(),
    );
    expect(await crypto.verifyChatRelay(decoded, now: now), isTrue);
  });

  test('wrong incident binding is represented by immutable signed fields', () async {
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final public = (await pair.extractPublicKey()).bytes;
    final crypto = RelayCryptography();
    final now = DateTime.utc(2026, 11, 4, 2);
    final body = ChatRelayBody(
      messageId: 'chat-2',
      incidentId: 'incident-1',
      senderKeyId: await crypto.publicKeyId(public),
      senderPublicKey: _b64(public),
      recipientKeyId: 'recipient-key',
      recipientPublicKey: _b64(List<int>.filled(32, 8)),
      originIncidentBinding: 'origin-binding-1',
      text: 'M2',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );
    final signed = ChatRelayEnvelope(
      body: body,
      signature: await crypto.signChatRelay(body, pair),
    );
    final tampered = ChatRelayEnvelope(
      body: ChatRelayBody(
        messageId: body.messageId,
        incidentId: 'incident-2',
        senderKeyId: body.senderKeyId,
        senderPublicKey: body.senderPublicKey,
        recipientKeyId: body.recipientKeyId,
        recipientPublicKey: body.recipientPublicKey,
        originIncidentBinding: body.originIncidentBinding,
        text: body.text,
        createdAt: body.createdAt,
        expiresAt: body.expiresAt,
      ),
      signature: signed.signature,
    );
    expect(await crypto.verifyChatRelay(tampered, now: now), isFalse);
  });

  test('expired Chat relay envelope is rejected', () async {
    final algorithm = Ed25519();
    final pair = await algorithm.newKeyPair();
    final public = (await pair.extractPublicKey()).bytes;
    final crypto = RelayCryptography();
    final now = DateTime.utc(2026, 11, 4, 2);
    final body = ChatRelayBody(
      messageId: 'chat-3',
      incidentId: 'incident-1',
      senderKeyId: await crypto.publicKeyId(public),
      senderPublicKey: _b64(public),
      recipientKeyId: 'recipient-key',
      recipientPublicKey: _b64(List<int>.filled(32, 9)),
      originIncidentBinding: 'origin-binding',
      text: 'M3',
      createdAt: now.subtract(const Duration(minutes: 10)),
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );
    final envelope = ChatRelayEnvelope(
      body: body,
      signature: await crypto.signChatRelay(body, pair),
    );
    expect(
      () => crypto.verifyChatRelay(envelope, now: now),
      throwsA(isA<FormatException>()),
    );
  });
}

String _b64(List<int> value) => base64UrlEncode(value);

