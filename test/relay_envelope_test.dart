import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

class _MemoryKeyStore implements RelayPrivateKeyStore {
  List<int>? seed;
  bool failReads = false;

  @override
  Future<List<int>?> readSeed() async {
    if (failReads) throw StateError('secure storage unavailable');
    return seed == null ? null : List<int>.from(seed!);
  }

  @override
  Future<void> writeSeed(List<int> seed) async {
    this.seed = List<int>.from(seed);
  }
}

Future<(RelayOriginBody, SimpleKeyPair)> _body({
  String message = 'Need help',
  bool includeLocation = false,
  DateTime? expiresAt,
  int maxHops = 3,
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    List<int>.generate(32, (index) => index),
  );
  final publicKey = (await keyPair.extractPublicKey()).bytes;
  final crypto = RelayCryptography();
  final createdAt = DateTime.utc(2026, 10, 25, 12);
  return (
    RelayOriginBody(
      originMessageId: 'relay-message-1',
      incidentId: 'incident-1',
      originKeyId: await crypto.publicKeyId(publicKey),
      originPublicKey: base64UrlEncode(publicKey),
      emergencyType: 'emergency',
      emergencyMessage: message,
      includeLocation: includeLocation,
      latitude: includeLocation ? 13.75 : null,
      longitude: includeLocation ? 100.5 : null,
      createdAt: createdAt,
      expiresAt: expiresAt ?? createdAt.add(const Duration(minutes: 30)),
      maxHops: maxHops,
    ),
    keyPair,
  );
}

Future<RelayOfferEnvelope> _signedOffer({
  String message = 'Need help',
  bool includeLocation = false,
}) async {
  final (body, keyPair) = await _body(
    message: message,
    includeLocation: includeLocation,
  );
  final signature = await RelayCryptography().signOriginBody(body, keyPair);
  return RelayOfferEnvelope(
    body: body,
    originSignature: signature,
    hopCount: 0,
    pathKeyIds: [body.originKeyId],
    immediateSenderKeyId: body.originKeyId,
  );
}

Future<RelayOfferEnvelope> _forwardedOffer(
  RelayOfferEnvelope origin,
  int hopCount,
) async {
  final crypto = RelayCryptography();
  final digest = await crypto.immutableDigest(origin.body);
  final path = <String>[origin.body.originKeyId];
  final attestations = <RelayHopAttestation>[];
  for (var hop = 1; hop <= hopCount; hop++) {
    final pair = await Ed25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + (hop * 40)),
    );
    final publicKey = (await pair.extractPublicKey()).bytes;
    final keyId = await crypto.publicKeyId(publicKey);
    path.add(keyId);
    final unsigned = RelayHopAttestation(
      originMessageId: origin.body.originMessageId,
      immutableDigest: digest,
      relayKeyId: keyId,
      relayPublicKey: base64UrlEncode(publicKey),
      hopCount: hop,
      pathKeyIds: List.unmodifiable(path),
      signature: '',
    );
    attestations.add(
      RelayHopAttestation(
        originMessageId: unsigned.originMessageId,
        immutableDigest: unsigned.immutableDigest,
        relayKeyId: unsigned.relayKeyId,
        relayPublicKey: unsigned.relayPublicKey,
        hopCount: unsigned.hopCount,
        pathKeyIds: unsigned.pathKeyIds,
        signature: await crypto.signHopAttestation(unsigned, pair),
      ),
    );
  }
  return RelayOfferEnvelope(
    body: origin.body,
    originSignature: origin.originSignature,
    hopCount: hopCount,
    pathKeyIds: List.unmodifiable(path),
    immediateSenderKeyId: path.last,
    hopAttestations: List.unmodifiable(attestations),
  );
}

void main() {
  test('relay capability negotiation is additive and fails closed', () async {
    final pair = await Ed25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 90),
    );
    final publicKey = (await pair.extractPublicKey()).bytes;
    final keyId = await RelayCryptography().publicKeyId(publicKey);
    final advertisement = RelayCapabilityAdvertisement(
      capabilities: const [RelayProtocolCapabilities.relayV2],
      participating: true,
      relayKeyId: keyId,
      relayPublicKey: base64UrlEncode(publicKey),
      sessionGeneration: 1,
      sessionRole: 'central',
    );

    expect(
      RelayCapabilityAdvertisement.fromJson(advertisement.toJson()).toJson(),
      advertisement.toJson(),
    );
    expect(
      RelayCapabilityAdvertisement.fromJson(const {
        'kind': RelayCapabilityAdvertisement.wireKind,
        'schemaVersion': 1,
        'capabilities': <String>[],
        'participating': false,
        'relayKeyId': null,
        'relayPublicKey': null,
        'sessionGeneration': null,
        'sessionRole': null,
      }).participating,
      isFalse,
    );
    expect(
      () => RelayCapabilityAdvertisement.fromJson({
        ...advertisement.toJson(),
        'relayPublicKey': null,
        'sessionGeneration': null,
        'sessionRole': null,
      }),
      throwsA(isA<RelayProtocolException>()),
    );
    expect(
      () => RelayCapabilityAdvertisement.fromJson(const {
        'kind': RelayCapabilityAdvertisement.wireKind,
        'schemaVersion': 1,
        'capabilities': <String>[],
        'participating': true,
        'relayKeyId': null,
        'relayPublicKey': null,
        'sessionGeneration': null,
        'sessionRole': null,
      }),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test(
    'session proof signatures bind keys, nonce, roles, and generations',
    () async {
      final crypto = RelayCryptography();
      final challengerPair = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 10),
      );
      final responderPair = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 50),
      );
      final challengerPublic = (await challengerPair.extractPublicKey()).bytes;
      final responderPublic = (await responderPair.extractPublicKey()).bytes;
      final unsignedChallenge = RelaySessionChallenge(
        nonce: base64UrlEncode(List<int>.generate(32, (index) => index + 90)),
        challengerKeyId: await crypto.publicKeyId(challengerPublic),
        challengerPublicKey: base64UrlEncode(challengerPublic),
        challengedKeyId: await crypto.publicKeyId(responderPublic),
        challengerRole: 'central',
        challengedRole: 'peripheral',
        challengerGeneration: 3,
        challengedGeneration: 8,
        challengerParticipating: true,
        signature: base64UrlEncode(List<int>.filled(64, 0)),
      );
      final challenge = RelaySessionChallenge(
        nonce: unsignedChallenge.nonce,
        challengerKeyId: unsignedChallenge.challengerKeyId,
        challengerPublicKey: unsignedChallenge.challengerPublicKey,
        challengedKeyId: unsignedChallenge.challengedKeyId,
        challengerRole: unsignedChallenge.challengerRole,
        challengedRole: unsignedChallenge.challengedRole,
        challengerGeneration: unsignedChallenge.challengerGeneration,
        challengedGeneration: unsignedChallenge.challengedGeneration,
        challengerParticipating: unsignedChallenge.challengerParticipating,
        signature: await crypto.signSessionChallenge(
          unsignedChallenge,
          challengerPair,
        ),
      );
      expect(await crypto.verifySessionChallenge(challenge), isTrue);

      final staleNonce = RelaySessionChallenge(
        nonce: base64UrlEncode(List<int>.filled(32, 7)),
        challengerKeyId: challenge.challengerKeyId,
        challengerPublicKey: challenge.challengerPublicKey,
        challengedKeyId: challenge.challengedKeyId,
        challengerRole: challenge.challengerRole,
        challengedRole: challenge.challengedRole,
        challengerGeneration: challenge.challengerGeneration,
        challengedGeneration: challenge.challengedGeneration,
        challengerParticipating: challenge.challengerParticipating,
        signature: challenge.signature,
      );
      expect(await crypto.verifySessionChallenge(staleNonce), isFalse);

      final unsignedResponse = RelaySessionResponse(
        challenge: challenge,
        responderKeyId: unsignedChallenge.challengedKeyId,
        responderPublicKey: base64UrlEncode(responderPublic),
        responderGeneration: challenge.challengedGeneration,
        responderParticipating: true,
        signature: base64UrlEncode(List<int>.filled(64, 0)),
      );
      final response = RelaySessionResponse(
        challenge: challenge,
        responderKeyId: unsignedResponse.responderKeyId,
        responderPublicKey: unsignedResponse.responderPublicKey,
        responderGeneration: unsignedResponse.responderGeneration,
        responderParticipating: unsignedResponse.responderParticipating,
        signature: await crypto.signSessionResponse(
          unsignedResponse,
          responderPair,
        ),
      );
      expect(await crypto.verifySessionResponse(response), isTrue);

      final wrongGeneration = RelaySessionResponse(
        challenge: response.challenge,
        responderKeyId: response.responderKeyId,
        responderPublicKey: response.responderPublicKey,
        responderGeneration: response.responderGeneration + 1,
        responderParticipating: response.responderParticipating,
        signature: response.signature,
      );
      expect(await crypto.verifySessionResponse(wrongGeneration), isFalse);
      final wrongKey = RelaySessionResponse(
        challenge: response.challenge,
        responderKeyId: response.responderKeyId,
        responderPublicKey: base64UrlEncode(challengerPublic),
        responderGeneration: response.responderGeneration,
        responderParticipating: response.responderParticipating,
        signature: response.signature,
      );
      expect(await crypto.verifySessionResponse(wrongKey), isFalse);
    },
  );

  test(
    'relay transfer preserves exact binding and rejects malformed input',
    () {
      const transfer = RelayOfferTransfer(
        wireOffer: '{"signed":"offer"}',
        attemptId: 'attempt-1',
        correlationId: 'correlation-1',
      );

      expect(
        RelayOfferTransfer.fromJson(transfer.toJson()).toJson(),
        transfer.toJson(),
      );
      expect(
        () => RelayOfferTransfer.fromJson({
          ...transfer.toJson(),
          'schemaVersion': 2,
        }),
        throwsA(isA<RelayProtocolException>()),
      );
      expect(
        () =>
            RelayOfferTransfer.fromJson({...transfer.toJson(), 'extra': true}),
        throwsA(isA<RelayProtocolException>()),
      );
    },
  );

  test('canonical JSON golden vector is stable and key-sorted', () async {
    final (body, _) = await _body();
    expect(
      relayCanonicalJson(body.toCanonicalMap()),
      '{"createdAt":"2026-10-25T12:00:00.000Z",'
      '"emergencyMessage":"Need help","emergencyType":"emergency",'
      '"expiresAt":"2026-10-25T12:30:00.000Z",'
      '"incidentId":"incident-1","includeLocation":false,"maxHops":3,'
      '"originKeyId":"${body.originKeyId}",'
      '"originMessageId":"relay-message-1",'
      '"originPublicKey":"${body.originPublicKey}",'
      '"schemaVersion":2,"scope":"publicEmergencyRelay"}',
    );
  });

  test('canonical JSON covers nested maps, Unicode, nulls, and numbers', () {
    expect(
      relayCanonicalJson({
        'z': null,
        'nested': {
          'ไทย': 'ช่วยด้วย',
          'negativeZero': -0.0,
          'decimal': 1.25,
          'integer': 2,
        },
        'list': [true, null, '🚨'],
      }),
      '{"list":[true,null,"🚨"],"nested":{"decimal":1.25,'
      '"integer":2,"negativeZero":0,"ไทย":"ช่วยด้วย"},"z":null}',
    );
    expect(
      () => relayCanonicalJson({'invalid': double.nan}),
      throwsA(isA<RelayProtocolException>()),
    );
    expect(
      () => relayCanonicalJson({'invalid': double.infinity}),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test(
    'canonical wire parsing rejects malformed, unknown, and reordered data',
    () async {
      final offer = await _signedOffer();
      expect(
        RelayOfferEnvelope.fromCanonicalWire(offer.toCanonicalWire()).toJson(),
        offer.toJson(),
      );
      expect(
        () => RelayOfferEnvelope.fromCanonicalWire('{not-json'),
        throwsA(isA<RelayProtocolException>()),
      );
      final withUnknown = Map<String, Object?>.from(offer.toJson())
        ..['unexpected'] = true;
      expect(
        () => RelayOfferEnvelope.fromCanonicalWire(
          relayCanonicalJson(withUnknown),
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      expect(
        () => RelayOfferEnvelope.fromCanonicalWire(jsonEncode(offer.toJson())),
        throwsA(isA<RelayProtocolException>()),
      );
    },
  );

  test(
    'fixed Ed25519 vectors cover origin, hop, and both receipt types',
    () async {
      final (body, originPair) = await _body();
      final crypto = RelayCryptography();
      final originSignature = await crypto.signOriginBody(body, originPair);
      expect(
        [body.originPublicKey, body.originKeyId],
        [
          'A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg=',
          'Vkdap1RjR0wChd9dvyvKtz2mUTWIOem3dIGy6rEHcIw=',
        ],
      );
      final relayPair = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 40),
      );
      final relayPublic = (await relayPair.extractPublicKey()).bytes;
      final relayKeyId = await crypto.publicKeyId(relayPublic);
      final hop = RelayHopAttestation(
        originMessageId: body.originMessageId,
        immutableDigest: await crypto.immutableDigest(body),
        relayKeyId: relayKeyId,
        relayPublicKey: base64UrlEncode(relayPublic),
        hopCount: 1,
        pathKeyIds: [body.originKeyId, relayKeyId],
        signature: '',
      );
      Future<String> receiptSignature(RelayReceiptType type) async {
        final receipt = RelayReceiptEnvelope(
          receiptId: '${type.name}-golden',
          type: type,
          originMessageId: body.originMessageId,
          incidentId: body.incidentId,
          immutableDigest: await crypto.immutableDigest(body),
          signerKeyId: relayKeyId,
          signerPublicKey: base64UrlEncode(relayPublic),
          status: 'persisted',
          createdAt: DateTime.utc(2026, 10, 25, 12, 1),
          expiresAt: body.expiresAt,
          signature: '',
          correlationId: 'golden-correlation',
          attemptId: type == RelayReceiptType.hop ? 'golden-attempt' : null,
          finalAuthorizationId: type == RelayReceiptType.finalRecipient
              ? 'golden-authorization'
              : null,
        );
        return crypto.signReceipt(receipt, relayPair);
      }

      expect(
        [
          originSignature,
          await crypto.signHopAttestation(hop, relayPair),
          await receiptSignature(RelayReceiptType.hop),
          await receiptSignature(RelayReceiptType.finalRecipient),
        ],
        [
          'tn-2PN5q_oBvQHJpxo55t29-9q8r4euXZaoaPClFU3kOc55-AJ8D2P6XE5VHSZzO9Nz5b9PXndOyfdWjdiddBQ==',
          'zs8aopGIY3QqFE5OWTvzCKC4roQTSV7AKJZ5M-b_HhKMGLOPJHMqh8FYbyUFZ59qTWYLS9FCD1duLYICtugGDA==',
          'LOAJxNloR8Ru508eJYcA4yLgtQiS_jdgKpM5kpRbZAfB-CSzXKUt68OVqWC4FRptw7dtMhy5d022_0fuVvFtAA==',
          'Xr_CXnsKsfFRspJjHZ3CvtrfL8xWOc5FR00jrmqWWs1TWB1Bcc8C7mcfgOoP4qDec1ejfjD4zcfvRUfIMviuDw==',
        ],
      );
    },
  );

  test('Ed25519 offer signature verifies and tampering fails closed', () async {
    final offer = await _signedOffer();
    final crypto = RelayCryptography();
    expect(
      await crypto.verifyOffer(offer, now: DateTime.utc(2026, 10, 25, 12, 1)),
      isTrue,
    );

    final (changedBody, _) = await _body(message: 'Changed payload');
    final changed = RelayOfferEnvelope(
      body: changedBody,
      originSignature: offer.originSignature,
      hopCount: 0,
      pathKeyIds: [changedBody.originKeyId],
      immediateSenderKeyId: changedBody.originKeyId,
    );
    expect(
      await crypto.verifyOffer(changed, now: DateTime.utc(2026, 10, 25, 12, 1)),
      isFalse,
    );
  });

  test(
    'offer JSON round trip retains stable identities and signature',
    () async {
      final original = await _signedOffer(includeLocation: true);
      final decoded = RelayOfferEnvelope.fromJson(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(original.toJson())) as Map,
        ),
      );
      expect(decoded.body.originMessageId, original.body.originMessageId);
      expect(decoded.body.incidentId, original.body.incidentId);
      expect(decoded.originSignature, original.originSignature);
      expect(decoded.body.latitude, 13.75);
      expect(
        await RelayCryptography().verifyOffer(
          decoded,
          now: DateTime.utc(2026, 10, 25, 12, 1),
        ),
        isTrue,
      );
    },
  );

  test('signed hop attestation locks path and hop count', () async {
    final origin = await _signedOffer();
    final relayPair = await Ed25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + 40),
    );
    final relayPublicKey = (await relayPair.extractPublicKey()).bytes;
    final crypto = RelayCryptography();
    final relayKeyId = await crypto.publicKeyId(relayPublicKey);
    final unsigned = RelayHopAttestation(
      originMessageId: origin.body.originMessageId,
      immutableDigest: await crypto.immutableDigest(origin.body),
      relayKeyId: relayKeyId,
      relayPublicKey: base64UrlEncode(relayPublicKey),
      hopCount: 1,
      pathKeyIds: [origin.body.originKeyId, relayKeyId],
      signature: '',
    );
    final signed = RelayHopAttestation(
      originMessageId: unsigned.originMessageId,
      immutableDigest: unsigned.immutableDigest,
      relayKeyId: unsigned.relayKeyId,
      relayPublicKey: unsigned.relayPublicKey,
      hopCount: unsigned.hopCount,
      pathKeyIds: unsigned.pathKeyIds,
      signature: await crypto.signHopAttestation(unsigned, relayPair),
    );
    final forwarded = RelayOfferEnvelope(
      body: origin.body,
      originSignature: origin.originSignature,
      hopCount: 1,
      pathKeyIds: signed.pathKeyIds,
      immediateSenderKeyId: relayKeyId,
      hopAttestations: [signed],
    );
    expect(
      await crypto.verifyOffer(
        forwarded,
        now: DateTime.utc(2026, 10, 25, 12, 2),
      ),
      isTrue,
    );

    final otherKeyId = await crypto.publicKeyId(List<int>.filled(32, 9));
    final changedPath = RelayOfferEnvelope(
      body: origin.body,
      originSignature: origin.originSignature,
      hopCount: 1,
      pathKeyIds: [origin.body.originKeyId, otherKeyId],
      immediateSenderKeyId: otherKeyId,
      hopAttestations: [signed],
    );
    expect(
      () => changedPath.validate(allowExpired: true),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test('approved maximum of three hops is inclusive', () async {
    final offer = await _forwardedOffer(await _signedOffer(), 3);
    expect(
      await RelayCryptography().verifyOffer(
        offer,
        now: DateTime.utc(2026, 10, 25, 12, 2),
      ),
      isTrue,
    );
  });

  test('location requires explicit per-incident consent', () async {
    final (valid, _) = await _body();
    final invalid = RelayOriginBody(
      originMessageId: valid.originMessageId,
      incidentId: valid.incidentId,
      originKeyId: valid.originKeyId,
      originPublicKey: valid.originPublicKey,
      emergencyType: valid.emergencyType,
      emergencyMessage: valid.emergencyMessage,
      includeLocation: false,
      latitude: 13,
      longitude: 100,
      createdAt: valid.createdAt,
      expiresAt: valid.expiresAt,
    );
    expect(
      () => invalid.validate(allowExpired: true),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test(
    '30-minute lifetime, 3-hop cap, message bytes and loops are enforced',
    () async {
      final (base, keyPair) = await _body();
      final crypto = RelayCryptography();
      final tooLong = RelayOriginBody(
        originMessageId: base.originMessageId,
        incidentId: base.incidentId,
        originKeyId: base.originKeyId,
        originPublicKey: base.originPublicKey,
        emergencyType: base.emergencyType,
        emergencyMessage: List<String>.filled(171, 'ก').join(),
        includeLocation: false,
        createdAt: base.createdAt,
        expiresAt: base.expiresAt,
      );
      expect(
        () => tooLong.validate(allowExpired: true),
        throwsA(isA<RelayProtocolException>()),
      );

      final (late, _) = await _body(
        expiresAt: base.createdAt.add(const Duration(minutes: 31)),
      );
      expect(
        () => late.validate(allowExpired: true),
        throwsA(isA<RelayProtocolException>()),
      );

      final signature = await crypto.signOriginBody(base, keyPair);
      final loop = RelayOfferEnvelope(
        body: base,
        originSignature: signature,
        hopCount: 1,
        pathKeyIds: [base.originKeyId, base.originKeyId],
        immediateSenderKeyId: base.originKeyId,
      );
      expect(
        () => loop.validate(allowExpired: true),
        throwsA(isA<RelayProtocolException>()),
      );
    },
  );

  test('future origin timestamp beyond clock skew fails closed', () async {
    final (base, _) = await _body();
    final future = RelayOriginBody(
      originMessageId: base.originMessageId,
      incidentId: base.incidentId,
      originKeyId: base.originKeyId,
      originPublicKey: base.originPublicKey,
      emergencyType: base.emergencyType,
      emergencyMessage: base.emergencyMessage,
      includeLocation: false,
      createdAt: DateTime.utc(2026, 10, 25, 12, 4),
      expiresAt: DateTime.utc(2026, 10, 25, 12, 30),
    );
    expect(
      () => future.validate(now: DateTime.utc(2026, 10, 25, 12)),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test(
    'receipt type and signature are distinct from an offer/hop write',
    () async {
      final (body, keyPair) = await _body();
      final crypto = RelayCryptography();
      final publicKey = (await keyPair.extractPublicKey()).bytes;
      final unsigned = RelayReceiptEnvelope(
        receiptId: 'hop-receipt-1',
        type: RelayReceiptType.hop,
        originMessageId: body.originMessageId,
        incidentId: body.incidentId,
        immutableDigest: await crypto.immutableDigest(body),
        signerKeyId: await crypto.publicKeyId(publicKey),
        signerPublicKey: base64UrlEncode(publicKey),
        status: 'persisted',
        createdAt: body.createdAt.add(const Duration(minutes: 1)),
        expiresAt: body.expiresAt,
        signature: '',
        correlationId: 'correlation-1',
        attemptId: 'attempt-1',
      );
      final signed = RelayReceiptEnvelope(
        receiptId: unsigned.receiptId,
        type: unsigned.type,
        originMessageId: unsigned.originMessageId,
        incidentId: unsigned.incidentId,
        immutableDigest: unsigned.immutableDigest,
        signerKeyId: unsigned.signerKeyId,
        signerPublicKey: unsigned.signerPublicKey,
        status: unsigned.status,
        createdAt: unsigned.createdAt,
        expiresAt: unsigned.expiresAt,
        signature: await crypto.signReceipt(unsigned, keyPair),
        correlationId: unsigned.correlationId,
        attemptId: unsigned.attemptId,
      );
      expect(
        await crypto.verifyReceipt(
          signed,
          now: DateTime.utc(2026, 10, 25, 12, 2),
        ),
        isTrue,
      );
      expect(signed.type, RelayReceiptType.hop);
    },
  );

  test('receipt parser rejects unsupported schema versions', () async {
    final (body, keyPair) = await _body();
    final crypto = RelayCryptography();
    final publicKey = (await keyPair.extractPublicKey()).bytes;
    final receipt = RelayReceiptEnvelope(
      receiptId: 'receipt-schema-test',
      type: RelayReceiptType.hop,
      originMessageId: body.originMessageId,
      incidentId: body.incidentId,
      immutableDigest: await crypto.immutableDigest(body),
      signerKeyId: await crypto.publicKeyId(publicKey),
      signerPublicKey: base64UrlEncode(publicKey),
      status: 'persisted',
      createdAt: body.createdAt.add(const Duration(minutes: 1)),
      expiresAt: body.expiresAt,
      signature: base64UrlEncode(List<int>.filled(64, 1)),
      correlationId: 'correlation-schema',
      attemptId: 'attempt-schema',
    );
    final json = receipt.toJson()..['schemaVersion'] = 99;
    expect(
      () => RelayReceiptEnvelope.fromJson(json),
      throwsA(isA<RelayProtocolException>()),
    );
  });

  test(
    'secure identity remains stable and storage failure fails closed',
    () async {
      final store = _MemoryKeyStore();
      final first = await RelayIdentityService(keyStore: store)
          .loadOrCreate(allowCreate: true);
      final second = await RelayIdentityService(keyStore: store)
          .loadOrCreate(allowCreate: false);
      expect(second.keyId, first.keyId);
      expect(second.publicKey, first.publicKey);
      expect(store.seed, hasLength(32));

      final failing = _MemoryKeyStore()..failReads = true;
      await expectLater(
        RelayIdentityService(keyStore: failing)
            .loadOrCreate(allowCreate: false),
        throwsA(anything),
      );

      await expectLater(
        RelayIdentityService(keyStore: _MemoryKeyStore())
            .loadOrCreate(allowCreate: false),
        throwsA(isA<RelayKeyStoreException>()),
      );

      final corrupt = _MemoryKeyStore()..seed = [1, 2, 3];
      await expectLater(
        RelayIdentityService(keyStore: corrupt)
            .loadOrCreate(allowCreate: false),
        throwsA(anything),
      );
      expect(corrupt.seed, [1, 2, 3]);
    },
  );

  test(
    'concurrent identity initialization converges on one stored key',
    () async {
      final store = _MemoryKeyStore();
      final identities = await Future.wait([
        RelayIdentityService(keyStore: store).loadOrCreate(allowCreate: true),
        RelayIdentityService(keyStore: store).loadOrCreate(allowCreate: true),
        RelayIdentityService(keyStore: store).loadOrCreate(allowCreate: true),
      ]);
      expect(
        identities.map((identity) => identity.keyId).toSet(),
        hasLength(1),
      );
      expect(store.seed, hasLength(32));
    },
  );
}
