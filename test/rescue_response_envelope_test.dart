import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_response_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/rescue_response_envelope.dart';

Future<(RelayOriginBody, SimpleKeyPair, RelayCryptography)> _origin() async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    List<int>.generate(32, (index) => index + 1),
  );
  final publicKey = (await keyPair.extractPublicKey()).bytes;
  final crypto = RelayCryptography(algorithm: algorithm);
  final createdAt = DateTime.utc(2026, 11, 4, 10);
  return (
    RelayOriginBody(
      originMessageId: 'origin-message-1',
      incidentId: 'incident-1',
      originKeyId: await crypto.publicKeyId(publicKey),
      originPublicKey: base64UrlEncode(publicKey),
      emergencyType: 'emergency',
      emergencyMessage: 'Need help',
      includeLocation: false,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(minutes: 30)),
    ),
    keyPair,
    crypto,
  );
}

Future<RescueResponseEnvelope> _signedResponse(
  RelayOriginBody origin,
  SimpleKeyPair responder,
  RelayCryptography crypto,
) async {
  final responderPublic = (await responder.extractPublicKey()).bytes;
  final responseBody = RescueResponseBody(
    messageId: 'offer-message-1',
    incidentId: origin.incidentId,
    originMessageId: origin.originMessageId,
    originKeyId: origin.originKeyId,
    originDigest: await crypto.immutableDigest(origin),
    responderKeyId: await crypto.publicKeyId(responderPublic),
    responderPublicKey: base64UrlEncode(responderPublic),
    sessionBinding: 'session-binding-1',
    createdAt: DateTime.utc(2026, 11, 4, 10, 1),
    expiresAt: DateTime.utc(2026, 11, 4, 10, 16),
  );
  return RescueResponseEnvelope(
    body: responseBody,
    signature: await crypto.signRescueResponse(responseBody, responder),
  );
}

void main() {
  test(
    'rescue offer round-trips and verifies its responder signature',
    () async {
      final (origin, _, crypto) = await _origin();
      final responder = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 80),
      );
      final envelope = await _signedResponse(origin, responder, crypto);

      final decoded = RescueResponseEnvelope.fromCanonicalWire(
        envelope.toCanonicalWire(),
      );
      expect(await crypto.verifyRescueResponse(decoded), isTrue);
    },
  );

  test(
    'rescue offer must bind to the exact origin SOS digest and IDs',
    () async {
      final (origin, _, crypto) = await _origin();
      final responder = await Ed25519().newKeyPair();
      final envelope = await _signedResponse(origin, responder, crypto);

      expect(
        await crypto.verifyRescueResponseForOrigin(envelope, origin),
        isTrue,
      );
      final wrongOrigin = RelayOriginBody(
        originMessageId: origin.originMessageId,
        incidentId: 'different-incident',
        originKeyId: origin.originKeyId,
        originPublicKey: origin.originPublicKey,
        emergencyType: origin.emergencyType,
        emergencyMessage: origin.emergencyMessage,
        includeLocation: false,
        createdAt: origin.createdAt,
        expiresAt: origin.expiresAt,
      );
      expect(
        await crypto.verifyRescueResponseForOrigin(envelope, wrongOrigin),
        isFalse,
      );
    },
  );

  test('forged rescue offer signature is rejected', () async {
    final (origin, _, crypto) = await _origin();
    final responder = await Ed25519().newKeyPair();
    final envelope = await _signedResponse(origin, responder, crypto);
    final forged = RescueResponseEnvelope(
      body: envelope.body,
      signature: base64UrlEncode(List<int>.filled(64, 0)),
    );

    expect(await crypto.verifyRescueResponse(forged), isFalse);
  });

  test('expired rescue offer is rejected fail-closed', () async {
    final (origin, _, crypto) = await _origin();
    final responder = await Ed25519().newKeyPair();
    final envelope = await _signedResponse(origin, responder, crypto);

    expect(
      () => crypto.verifyRescueResponse(
        envelope,
        now: DateTime.utc(2026, 11, 4, 10, 17),
      ),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test('response hop count cannot exceed its declared limit', () async {
    final (origin, _, crypto) = await _origin();
    final responder = await Ed25519().newKeyPair();
    final valid = await _signedResponse(origin, responder, crypto);
    final invalidBody = RescueResponseBody(
      messageId: valid.body.messageId,
      incidentId: valid.body.incidentId,
      originMessageId: valid.body.originMessageId,
      originKeyId: valid.body.originKeyId,
      originDigest: valid.body.originDigest,
      responderKeyId: valid.body.responderKeyId,
      responderPublicKey: valid.body.responderPublicKey,
      sessionBinding: valid.body.sessionBinding,
      createdAt: valid.body.createdAt,
      expiresAt: valid.body.expiresAt,
      hopCount: 4,
      maxHops: 3,
    );

    expect(
      () => crypto.signRescueResponse(invalidBody, responder),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test('final recipient ACK is bound to the exact rescue response', () async {
    final (origin, originKey, crypto) = await _origin();
    final responder = await Ed25519().newKeyPair();
    final response = await _signedResponse(origin, responder, crypto);
    final originPublic = (await originKey.extractPublicKey()).bytes;
    final ackBody = RescueResponseAckBody(
      ackId: 'ack-1',
      responseMessageId: response.body.messageId,
      incidentId: origin.incidentId,
      originMessageId: origin.originMessageId,
      originKeyId: origin.originKeyId,
      signerKeyId: origin.originKeyId,
      signerPublicKey: base64UrlEncode(originPublic),
      recipientKeyId: response.body.responderKeyId,
      sessionBinding: 'session-binding-1',
      createdAt: DateTime.utc(2026, 11, 4, 10, 2),
      expiresAt: DateTime.utc(2026, 11, 4, 10, 17),
    );
    final ack = RescueResponseAckEnvelope(
      body: ackBody,
      signature: await crypto.signRescueResponseAck(ackBody, originKey),
    );

    expect(
      await crypto.verifyRescueResponseAckForResponse(ack, response, origin),
      isTrue,
    );
    final wrongResponse = RescueResponseEnvelope(
      body: RescueResponseBody(
        messageId: 'other-response',
        incidentId: response.body.incidentId,
        originMessageId: response.body.originMessageId,
        originKeyId: response.body.originKeyId,
        originDigest: response.body.originDigest,
        responderKeyId: response.body.responderKeyId,
        responderPublicKey: response.body.responderPublicKey,
        sessionBinding: response.body.sessionBinding,
        createdAt: response.body.createdAt,
        expiresAt: response.body.expiresAt,
      ),
      signature: response.signature,
    );
    expect(
      await crypto.verifyRescueResponseAckForResponse(
        ack,
        wrongResponse,
        origin,
      ),
      isFalse,
    );
  });

  test('reverse response persistence is idempotent and owner scoped', () async {
    final (origin, originKey, crypto) = await _origin();
    final responder = await Ed25519().newKeyPair();
    final response = await _signedResponse(origin, responder, crypto);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final ownerA = RescueResponseRepository(database, ownerId: 'owner-a');
    final ownerB = RescueResponseRepository(database, ownerId: 'owner-b');
    addTearDown(database.close);

    final first = await ownerA.enqueueOffer(envelope: response, origin: origin);
    final second = await ownerA.enqueueOffer(
      envelope: response,
      origin: origin,
    );
    expect(first.messageId, second.messageId);
    expect(
      await ownerA.recordIncoming(envelope: response, origin: origin),
      isTrue,
    );
    expect(
      await ownerA.recordIncoming(envelope: response, origin: origin),
      isFalse,
    );
    expect(
      await ownerA.markReplaySeen(
        messageId: response.body.messageId,
        immutableDigest: response.body.originDigest,
        expiresAt: response.body.expiresAt,
      ),
      isTrue,
    );
    expect(
      await ownerA.markReplaySeen(
        messageId: response.body.messageId,
        immutableDigest: response.body.originDigest,
        expiresAt: response.body.expiresAt,
      ),
      isFalse,
    );
    expect(await ownerB.findOutbox(response.body.messageId), isNull);

    final responderPublic = (await responder.extractPublicKey()).bytes;
    final ackBody = RescueResponseAckBody(
      ackId: 'ack-1',
      responseMessageId: response.body.messageId,
      incidentId: origin.incidentId,
      originMessageId: origin.originMessageId,
      originKeyId: origin.originKeyId,
      signerKeyId: origin.originKeyId,
      signerPublicKey: origin.originPublicKey,
      recipientKeyId: await crypto.publicKeyId(responderPublic),
      sessionBinding: response.body.sessionBinding,
      createdAt: DateTime.utc(2026, 11, 4, 10, 2),
      expiresAt: DateTime.utc(2026, 11, 4, 10, 17),
    );
    final ack = RescueResponseAckEnvelope(
      body: ackBody,
      signature: await crypto.signRescueResponseAck(ackBody, originKey),
    );
    expect(
      await ownerA.applyFinalAck(ack: ack, response: response, origin: origin),
      isTrue,
    );
    expect(
      (await ownerA.findOutbox(response.body.messageId))!.state,
      RescueResponseDeliveryState.delivered.name,
    );
  });

  test(
    'BLE response transfer round-trips without changing the signed payload',
    () {
      final transfer = RescueResponseTransfer(
        attemptId: 'attempt-1',
        correlationId: 'correlation-1',
        sessionBinding: 'binding-1',
        wireEnvelope: '{"signed":true}',
        hopCount: 1,
        maxHops: 3,
        isAck: false,
      );
      final decoded = RescueResponseTransfer.fromJson(transfer.toJson());
      decoded.validate();
      expect(decoded.wireEnvelope, transfer.wireEnvelope);
      expect(decoded.isAck, isFalse);
    },
  );

  test('BLE response transfer rejects a hop beyond its limit', () {
    final transfer = RescueResponseTransfer(
      attemptId: 'attempt-1',
      correlationId: 'correlation-1',
      sessionBinding: 'binding-1',
      wireEnvelope: '{}',
      hopCount: 4,
      maxHops: 3,
      isAck: true,
    );
    expect(() => transfer.validate(), throwsA(isA<RelayProtocolException>()));
  });
}
