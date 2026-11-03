import 'dart:collection';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'rescue_response_envelope.dart';
import 'chat_relay_envelope.dart';

enum RelayAuthorizationScope {
  publicEmergencyRelay('publicEmergencyRelay'),
  voluntaryRescue('voluntaryRescue');

  const RelayAuthorizationScope(this.wireValue);
  final String wireValue;

  static RelayAuthorizationScope parse(Object? value) {
    return values.firstWhere(
      (scope) => scope.wireValue == value,
      orElse: () => throw const RelayProtocolException(
        'Unsupported relay authorization scope.',
      ),
    );
  }
}

enum RelayReceiptType {
  hop('sos.relay.hop_ack.v2'),
  finalRecipient('sos.relay.final_ack.v2');

  const RelayReceiptType(this.wireValue);
  final String wireValue;

  static RelayReceiptType parse(Object? value) {
    return values.firstWhere(
      (kind) => kind.wireValue == value,
      orElse: () =>
          throw const RelayProtocolException('Unsupported relay receipt type.'),
    );
  }
}

/// Immutable, origin-signed public emergency data. It deliberately contains no
/// account ID, contact, Chat, Location-sharing stream, token, or cloud state.
class RelayOriginBody {
  const RelayOriginBody({
    required this.originMessageId,
    required this.incidentId,
    required this.originKeyId,
    required this.originPublicKey,
    required this.emergencyType,
    required this.emergencyMessage,
    required this.includeLocation,
    required this.createdAt,
    required this.expiresAt,
    this.latitude,
    this.longitude,
    this.maxHops = RelayProtocolLimits.maximumHops,
    this.scope = RelayAuthorizationScope.publicEmergencyRelay,
  });

  static const schemaVersion = 2;

  final RelayAuthorizationScope scope;
  final String originMessageId;
  final String incidentId;
  final String originKeyId;
  final String originPublicKey;
  final String emergencyType;
  final String emergencyMessage;
  final bool includeLocation;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int maxHops;

  Map<String, Object?> toCanonicalMap() => {
    'schemaVersion': schemaVersion,
    'scope': scope.wireValue,
    'originMessageId': originMessageId,
    'incidentId': incidentId,
    'originKeyId': originKeyId,
    'originPublicKey': originPublicKey,
    'emergencyType': emergencyType,
    'emergencyMessage': emergencyMessage,
    'includeLocation': includeLocation,
    if (includeLocation) 'latitude': latitude,
    if (includeLocation) 'longitude': longitude,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'maxHops': maxHops,
  };

  factory RelayOriginBody.fromJson(Map<String, Object?> json) {
    final includeLocation = _requiredBool(json, 'includeLocation');
    _requireExactKeys(json, {
      'schemaVersion',
      'scope',
      'originMessageId',
      'incidentId',
      'originKeyId',
      'originPublicKey',
      'emergencyType',
      'emergencyMessage',
      'includeLocation',
      if (includeLocation) 'latitude',
      if (includeLocation) 'longitude',
      'createdAt',
      'expiresAt',
      'maxHops',
    });
    if (json['schemaVersion'] != schemaVersion) {
      throw const RelayProtocolException('Unsupported relay schema version.');
    }
    return RelayOriginBody(
      scope: RelayAuthorizationScope.parse(json['scope']),
      originMessageId: _requiredString(json, 'originMessageId'),
      incidentId: _requiredString(json, 'incidentId'),
      originKeyId: _requiredString(json, 'originKeyId'),
      originPublicKey: _requiredString(json, 'originPublicKey'),
      emergencyType: _requiredString(json, 'emergencyType'),
      emergencyMessage: _requiredString(json, 'emergencyMessage'),
      includeLocation: includeLocation,
      latitude: _optionalDouble(json['latitude']),
      longitude: _optionalDouble(json['longitude']),
      createdAt: _requiredDate(json, 'createdAt'),
      expiresAt: _requiredDate(json, 'expiresAt'),
      maxHops: _requiredInt(json, 'maxHops'),
    );
  }

  void validate({DateTime? now, bool allowExpired = false}) {
    _boundedId(originMessageId, 'originMessageId');
    _boundedId(incidentId, 'incidentId');
    _boundedKeyId(originKeyId, 'originKeyId');
    _decodeExact(originPublicKey, 32, 'originPublicKey');
    _boundedText(emergencyType, 'emergencyType', 64);
    final messageBytes = utf8.encode(emergencyMessage).length;
    if (messageBytes == 0 ||
        messageBytes > RelayProtocolLimits.maximumEmergencyMessageBytes) {
      throw const RelayProtocolException(
        'Emergency message exceeds the relay byte limit.',
      );
    }
    if (!createdAt.isUtc || !expiresAt.isUtc || !expiresAt.isAfter(createdAt)) {
      throw const RelayProtocolException('Relay timestamps must be valid UTC.');
    }
    if (expiresAt.difference(createdAt) > RelayProtocolLimits.maximumLifetime) {
      throw const RelayProtocolException('Relay expiry exceeds 30 minutes.');
    }
    if (now != null) {
      final receiverNow = now.toUtc();
      if (createdAt.isAfter(
        receiverNow.add(RelayProtocolLimits.maximumClockSkew),
      )) {
        throw const RelayProtocolException(
          'Relay creation time exceeds the allowed clock skew.',
        );
      }
      if (!allowExpired && !expiresAt.isAfter(receiverNow)) {
        throw const RelayProtocolException('Relay SOS has expired.');
      }
    }
    if (maxHops < 1 || maxHops > RelayProtocolLimits.maximumHops) {
      throw const RelayProtocolException('Relay hop limit is invalid.');
    }
    if (!includeLocation && (latitude != null || longitude != null)) {
      throw const RelayProtocolException(
        'Location is present without per-incident consent.',
      );
    }
    if (includeLocation && !_validCoordinates(latitude, longitude)) {
      throw const RelayProtocolException('Relay location is invalid.');
    }
  }
}

class RelayOfferEnvelope {
  const RelayOfferEnvelope({
    required this.body,
    required this.originSignature,
    required this.hopCount,
    required this.pathKeyIds,
    required this.immediateSenderKeyId,
    this.hopAttestations = const [],
  });

  static const wireKind = 'sos.relay.offer.v2';

  final RelayOriginBody body;
  final String originSignature;
  final int hopCount;
  final List<String> pathKeyIds;
  final String immediateSenderKeyId;
  final List<RelayHopAttestation> hopAttestations;

  Map<String, Object?> toJson() => {
    'kind': wireKind,
    'body': body.toCanonicalMap(),
    'originSignature': originSignature,
    'relay': {
      'hopCount': hopCount,
      'pathKeyIds': pathKeyIds,
      'immediateSenderKeyId': immediateSenderKeyId,
      'hopAttestations': hopAttestations
          .map((attestation) => attestation.toJson())
          .toList(growable: false),
    },
  };

  String toCanonicalWire() => relayCanonicalJson(toJson());

  factory RelayOfferEnvelope.fromCanonicalWire(String wire) {
    final decoded = _decodeCanonicalObject(wire, 'relay offer');
    final offer = RelayOfferEnvelope.fromJson(decoded);
    if (offer.toCanonicalWire() != wire) {
      throw const RelayProtocolException('Relay offer is not canonical JSON.');
    }
    return offer;
  }

  factory RelayOfferEnvelope.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {'kind', 'body', 'originSignature', 'relay'});
    if (json['kind'] != wireKind ||
        json['body'] is! Map ||
        json['relay'] is! Map) {
      throw const RelayProtocolException('Invalid relay offer.');
    }
    final relay = Map<String, Object?>.from(json['relay']! as Map);
    _requireExactKeys(relay, {
      'hopCount',
      'pathKeyIds',
      'immediateSenderKeyId',
      'hopAttestations',
    });
    final path = relay['pathKeyIds'];
    final attestations = relay['hopAttestations'];
    if (path is! List || attestations is! List) {
      throw const RelayProtocolException('Invalid relay path.');
    }
    return RelayOfferEnvelope(
      body: RelayOriginBody.fromJson(
        Map<String, Object?>.from(json['body']! as Map),
      ),
      originSignature: _requiredString(json, 'originSignature'),
      hopCount: _requiredInt(relay, 'hopCount'),
      pathKeyIds: path
          .map((value) {
            if (value is! String) {
              throw const RelayProtocolException('Invalid relay path entry.');
            }
            return value;
          })
          .toList(growable: false),
      immediateSenderKeyId: _requiredString(relay, 'immediateSenderKeyId'),
      hopAttestations: attestations
          .map((value) {
            if (value is! Map) {
              throw const RelayProtocolException(
                'Invalid relay hop attestation.',
              );
            }
            return RelayHopAttestation.fromJson(
              Map<String, Object?>.from(value),
            );
          })
          .toList(growable: false),
    );
  }

  void validate({DateTime? now, bool allowExpired = false}) {
    body.validate(now: now, allowExpired: allowExpired);
    _decodeExact(originSignature, 64, 'originSignature');
    if (hopCount < 0 || hopCount > body.maxHops) {
      throw const RelayProtocolException('Relay hop count is exhausted.');
    }
    if (pathKeyIds.length != hopCount + 1 ||
        pathKeyIds.length > RelayProtocolLimits.maximumPathEntries) {
      throw const RelayProtocolException('Relay path length is invalid.');
    }
    final unique = pathKeyIds.toSet();
    if (unique.length != pathKeyIds.length) {
      throw const RelayProtocolException('Relay path contains a loop.');
    }
    for (final keyId in pathKeyIds) {
      _boundedKeyId(keyId, 'pathKeyId');
    }
    if (pathKeyIds.first != body.originKeyId ||
        pathKeyIds.last != immediateSenderKeyId) {
      throw const RelayProtocolException('Relay path identity is invalid.');
    }
    if (hopAttestations.length != hopCount) {
      throw const RelayProtocolException(
        'Relay hop attestation count is invalid.',
      );
    }
    for (var index = 0; index < hopAttestations.length; index++) {
      final expectedHop = index + 1;
      final attestation = hopAttestations[index];
      attestation.validate();
      if (attestation.hopCount != expectedHop ||
          attestation.relayKeyId != pathKeyIds[expectedHop] ||
          !_sameStrings(
            attestation.pathKeyIds,
            pathKeyIds.take(expectedHop + 1).toList(growable: false),
          )) {
        throw const RelayProtocolException(
          'Relay hop attestation does not match its path.',
        );
      }
    }
  }
}

class RelayHopAttestation {
  const RelayHopAttestation({
    required this.originMessageId,
    required this.immutableDigest,
    required this.relayKeyId,
    required this.relayPublicKey,
    required this.hopCount,
    required this.pathKeyIds,
    required this.signature,
  });

  final String originMessageId;
  final String immutableDigest;
  final String relayKeyId;
  final String relayPublicKey;
  final int hopCount;
  final List<String> pathKeyIds;
  final String signature;

  Map<String, Object?> unsignedMap() => {
    'originMessageId': originMessageId,
    'immutableDigest': immutableDigest,
    'relayKeyId': relayKeyId,
    'relayPublicKey': relayPublicKey,
    'hopCount': hopCount,
    'pathKeyIds': pathKeyIds,
  };

  Map<String, Object?> toJson() => {...unsignedMap(), 'signature': signature};

  factory RelayHopAttestation.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'originMessageId',
      'immutableDigest',
      'relayKeyId',
      'relayPublicKey',
      'hopCount',
      'pathKeyIds',
      'signature',
    });
    final path = json['pathKeyIds'];
    if (path is! List || path.any((value) => value is! String)) {
      throw const RelayProtocolException('Invalid attested relay path.');
    }
    return RelayHopAttestation(
      originMessageId: _requiredString(json, 'originMessageId'),
      immutableDigest: _requiredString(json, 'immutableDigest'),
      relayKeyId: _requiredString(json, 'relayKeyId'),
      relayPublicKey: _requiredString(json, 'relayPublicKey'),
      hopCount: _requiredInt(json, 'hopCount'),
      pathKeyIds: path.cast<String>().toList(growable: false),
      signature: _requiredString(json, 'signature'),
    );
  }

  void validate() {
    _boundedId(originMessageId, 'originMessageId');
    _decodeExact(immutableDigest, 32, 'immutableDigest');
    _boundedKeyId(relayKeyId, 'relayKeyId');
    _decodeExact(relayPublicKey, 32, 'relayPublicKey');
    _decodeExact(signature, 64, 'hopSignature');
    if (hopCount < 1 ||
        hopCount > RelayProtocolLimits.maximumHops ||
        pathKeyIds.length != hopCount + 1 ||
        pathKeyIds.last != relayKeyId ||
        pathKeyIds.toSet().length != pathKeyIds.length) {
      throw const RelayProtocolException('Invalid relay hop attestation.');
    }
  }
}

class RelayReceiptEnvelope {
  const RelayReceiptEnvelope({
    required this.receiptId,
    required this.type,
    required this.originMessageId,
    required this.incidentId,
    required this.immutableDigest,
    required this.signerKeyId,
    required this.signerPublicKey,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.signature,
    required this.correlationId,
    this.attemptId,
    this.finalAuthorizationId,
    this.sessionBinding,
  });

  final String receiptId;
  final RelayReceiptType type;
  final String originMessageId;
  final String incidentId;
  final String immutableDigest;
  final String signerKeyId;
  final String signerPublicKey;
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String signature;
  final String correlationId;
  final String? attemptId;
  final String? finalAuthorizationId;
  final String? sessionBinding;

  Map<String, Object?> unsignedMap() => {
    'kind': type.wireValue,
    'schemaVersion': RelayOriginBody.schemaVersion,
    'receiptId': receiptId,
    'originMessageId': originMessageId,
    'incidentId': incidentId,
    'immutableDigest': immutableDigest,
    'signerKeyId': signerKeyId,
    'signerPublicKey': signerPublicKey,
    'status': status,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'correlationId': correlationId,
    if (attemptId != null) 'attemptId': attemptId,
    if (finalAuthorizationId != null)
      'finalAuthorizationId': finalAuthorizationId,
    if (sessionBinding != null) 'sessionBinding': sessionBinding,
  };

  Map<String, Object?> toJson() => {...unsignedMap(), 'signature': signature};

  String toCanonicalWire() => relayCanonicalJson(toJson());

  factory RelayReceiptEnvelope.fromCanonicalWire(String wire) {
    final decoded = _decodeCanonicalObject(wire, 'relay receipt');
    final receipt = RelayReceiptEnvelope.fromJson(decoded);
    if (receipt.toCanonicalWire() != wire) {
      throw const RelayProtocolException(
        'Relay receipt is not canonical JSON.',
      );
    }
    return receipt;
  }

  factory RelayReceiptEnvelope.fromJson(Map<String, Object?> json) {
    final type = RelayReceiptType.parse(json['kind']);
    _requireExactKeys(json, {
      'kind',
      'schemaVersion',
      'receiptId',
      'originMessageId',
      'incidentId',
      'immutableDigest',
      'signerKeyId',
      'signerPublicKey',
      'status',
      'createdAt',
      'expiresAt',
      'correlationId',
      if (type == RelayReceiptType.hop) 'attemptId',
      if (type == RelayReceiptType.finalRecipient) 'finalAuthorizationId',
      if (json.containsKey('sessionBinding')) 'sessionBinding',
      'signature',
    });
    if (json['schemaVersion'] != RelayOriginBody.schemaVersion) {
      throw const RelayProtocolException('Unsupported relay schema version.');
    }
    return RelayReceiptEnvelope(
      receiptId: _requiredString(json, 'receiptId'),
      type: type,
      originMessageId: _requiredString(json, 'originMessageId'),
      incidentId: _requiredString(json, 'incidentId'),
      immutableDigest: _requiredString(json, 'immutableDigest'),
      signerKeyId: _requiredString(json, 'signerKeyId'),
      signerPublicKey: _requiredString(json, 'signerPublicKey'),
      status: _requiredString(json, 'status'),
      createdAt: _requiredDate(json, 'createdAt'),
      expiresAt: _requiredDate(json, 'expiresAt'),
      signature: _requiredString(json, 'signature'),
      correlationId: _requiredString(json, 'correlationId'),
      attemptId: _optionalString(json['attemptId']),
      finalAuthorizationId: _optionalString(json['finalAuthorizationId']),
      sessionBinding: _optionalString(json['sessionBinding']),
    );
  }

  void validate({DateTime? now, bool allowExpired = false}) {
    _boundedId(receiptId, 'receiptId');
    _boundedId(originMessageId, 'originMessageId');
    _boundedId(incidentId, 'incidentId');
    _decodeExact(immutableDigest, 32, 'immutableDigest');
    _boundedKeyId(signerKeyId, 'signerKeyId');
    _decodeExact(signerPublicKey, 32, 'signerPublicKey');
    _decodeExact(signature, 64, 'signature');
    _boundedId(correlationId, 'correlationId');
    if (sessionBinding != null) {
      _decodeExact(sessionBinding!, 32, 'sessionBinding');
    }
    switch (type) {
      case RelayReceiptType.hop:
        if (attemptId == null || finalAuthorizationId != null) {
          throw const RelayProtocolException(
            'Hop receipt correlation is invalid.',
          );
        }
        _boundedId(attemptId!, 'attemptId');
      case RelayReceiptType.finalRecipient:
        if (finalAuthorizationId == null || attemptId != null) {
          throw const RelayProtocolException(
            'Final receipt authorization is invalid.',
          );
        }
        _boundedId(finalAuthorizationId!, 'finalAuthorizationId');
    }
    if (status != 'persisted') {
      throw const RelayProtocolException('Unsupported relay receipt status.');
    }
    if (!createdAt.isUtc || !expiresAt.isUtc || !expiresAt.isAfter(createdAt)) {
      throw const RelayProtocolException('Invalid relay receipt timestamps.');
    }
    if (!allowExpired && now != null && !expiresAt.isAfter(now.toUtc())) {
      throw const RelayProtocolException('Relay receipt has expired.');
    }
    if (now != null &&
        createdAt.isAfter(
          now.toUtc().add(RelayProtocolLimits.maximumClockSkew),
        )) {
      throw const RelayProtocolException(
        'Relay receipt time exceeds the allowed clock skew.',
      );
    }
  }
}

class RelayProtocolLimits {
  static const maximumLifetime = Duration(minutes: 30);
  static const maximumHops = 3;
  static const maximumPathEntries = maximumHops + 1;
  static const maximumJobs = 50;
  static const maximumPayloadStorageBytes = 1024 * 1024;
  static const maximumEmergencyMessageBytes = 512;
  static const maximumClockSkew = Duration(minutes: 2);
  static const maximumAttemptsPerMessage = 5;
  static const maximumReceiptsPerMessage = maximumAttemptsPerMessage + 1;
}

class RelayCryptography {
  RelayCryptography({Ed25519? algorithm, Sha256? hash})
    : _algorithm = algorithm ?? Ed25519(),
      _hash = hash ?? Sha256();

  final Ed25519 _algorithm;
  final Sha256 _hash;

  Future<String> publicKeyId(List<int> publicKey) async {
    final digest = await _hash.hash(publicKey);
    return base64UrlEncode(digest.bytes);
  }

  Future<String> immutableDigest(RelayOriginBody body) async {
    final digest = await _hash.hash(
      utf8.encode(relayCanonicalJson(body.toCanonicalMap())),
    );
    return base64UrlEncode(digest.bytes);
  }

  Future<bool> publicKeyMatchesId(String encodedKey, String keyId) async {
    final publicKey = _decodeExact(encodedKey, 32, 'publicKey');
    return await publicKeyId(publicKey) == keyId;
  }

  Future<String> forwardCorrelationId({
    required String originMessageId,
    required String immutableDigest,
    required String nextHopKeyId,
  }) => _digestId({
    'kind': 'sos.relay.forward_correlation.v2',
    'originMessageId': originMessageId,
    'immutableDigest': immutableDigest,
    'nextHopKeyId': nextHopKeyId,
  });

  Future<String> hopReceiptId({
    required String originMessageId,
    required String attemptId,
    required String signerKeyId,
  }) => _digestId({
    'kind': 'sos.relay.hop_receipt_id.v2',
    'originMessageId': originMessageId,
    'attemptId': attemptId,
    'signerKeyId': signerKeyId,
  });

  Future<String> _digestId(Map<String, Object?> value) async {
    final digest = await _hash.hash(utf8.encode(relayCanonicalJson(value)));
    return base64UrlEncode(digest.bytes);
  }

  Future<String> signOriginBody(
    RelayOriginBody body,
    SimpleKeyPair keyPair,
  ) async {
    body.validate(allowExpired: true);
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(body.toCanonicalMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<bool> verifyOffer(
    RelayOfferEnvelope offer, {
    DateTime? now,
    bool allowExpired = false,
  }) async {
    offer.validate(now: now, allowExpired: allowExpired);
    final publicBytes = _decodeExact(
      offer.body.originPublicKey,
      32,
      'originPublicKey',
    );
    if (await publicKeyId(publicBytes) != offer.body.originKeyId) return false;
    final originValid = await _algorithm.verify(
      utf8.encode(relayCanonicalJson(offer.body.toCanonicalMap())),
      signature: Signature(
        _decodeExact(offer.originSignature, 64, 'originSignature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!originValid) return false;
    final digest = await immutableDigest(offer.body);
    for (final attestation in offer.hopAttestations) {
      if (attestation.originMessageId != offer.body.originMessageId ||
          attestation.immutableDigest != digest) {
        return false;
      }
      final relayPublicKey = _decodeExact(
        attestation.relayPublicKey,
        32,
        'relayPublicKey',
      );
      if (await publicKeyId(relayPublicKey) != attestation.relayKeyId) {
        return false;
      }
      final valid = await _algorithm.verify(
        utf8.encode(relayCanonicalJson(attestation.unsignedMap())),
        signature: Signature(
          _decodeExact(attestation.signature, 64, 'hopSignature'),
          publicKey: SimplePublicKey(relayPublicKey, type: KeyPairType.ed25519),
        ),
      );
      if (!valid) return false;
    }
    return true;
  }

  Future<String> signHopAttestation(
    RelayHopAttestation attestation,
    SimpleKeyPair keyPair,
  ) async {
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(attestation.unsignedMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<String> signReceipt(
    RelayReceiptEnvelope receipt,
    SimpleKeyPair keyPair,
  ) async {
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(receipt.unsignedMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<String> signRescueResponse(
    RescueResponseBody body,
    SimpleKeyPair keyPair,
  ) async {
    body.validate();
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(body.toCanonicalMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<String> signChatRelay(
    ChatRelayBody body,
    SimpleKeyPair keyPair,
  ) async {
    body.validate();
    final signature = await _algorithm.sign(
      utf8.encode(body.toCanonicalWire()),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<bool> verifyChatRelay(
    ChatRelayEnvelope envelope, {
    DateTime? now,
  }) async {
    envelope.body.validate(now: now);
    final publicBytes = _decodeExact(
      envelope.body.senderPublicKey,
      32,
      'chatSenderPublicKey',
    );
    if (await publicKeyId(publicBytes) != envelope.body.senderKeyId) {
      return false;
    }
    return _algorithm.verify(
      utf8.encode(envelope.body.toCanonicalWire()),
      signature: Signature(
        _decodeExact(envelope.signature, 64, 'chatSignature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  Future<bool> verifyRescueResponse(
    RescueResponseEnvelope envelope, {
    DateTime? now,
  }) async {
    envelope.validate(now: now);
    final publicBytes = _decodeExact(
      envelope.body.responderPublicKey,
      32,
      'responderPublicKey',
    );
    if (await publicKeyId(publicBytes) != envelope.body.responderKeyId) {
      return false;
    }
    return _algorithm.verify(
      utf8.encode(relayCanonicalJson(envelope.body.toCanonicalMap())),
      signature: Signature(
        _decodeExact(envelope.signature, 64, 'signature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  /// Verifies both the responder signature and its binding to the exact
  /// origin SOS. A relay may transport this envelope, but cannot rebind it to
  /// another incident or origin message.
  Future<bool> verifyRescueResponseForOrigin(
    RescueResponseEnvelope envelope,
    RelayOriginBody origin, {
    DateTime? now,
  }) async {
    if (envelope.body.incidentId != origin.incidentId ||
        envelope.body.originMessageId != origin.originMessageId ||
        envelope.body.originKeyId != origin.originKeyId) {
      return false;
    }
    if (envelope.body.expiresAt.isAfter(origin.expiresAt)) {
      return false;
    }
    if (envelope.body.originDigest != await immutableDigest(origin)) {
      return false;
    }
    return verifyRescueResponse(envelope, now: now);
  }

  Future<String> signRescueResponseAck(
    RescueResponseAckBody body,
    SimpleKeyPair keyPair,
  ) async {
    body.validate();
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(body.toCanonicalMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<bool> verifyRescueResponseAck(
    RescueResponseAckEnvelope envelope, {
    DateTime? now,
  }) async {
    envelope.validate(now: now);
    final publicBytes = _decodeExact(
      envelope.body.signerPublicKey,
      32,
      'signerPublicKey',
    );
    if (await publicKeyId(publicBytes) != envelope.body.signerKeyId) {
      return false;
    }
    return _algorithm.verify(
      utf8.encode(relayCanonicalJson(envelope.body.toCanonicalMap())),
      signature: Signature(
        _decodeExact(envelope.signature, 64, 'signature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  Future<bool> verifyRescueResponseAckForResponse(
    RescueResponseAckEnvelope ack,
    RescueResponseEnvelope response,
    RelayOriginBody origin, {
    DateTime? now,
  }) async {
    if (ack.body.responseMessageId != response.body.messageId ||
        ack.body.incidentId != origin.incidentId ||
        ack.body.originMessageId != origin.originMessageId ||
        ack.body.originKeyId != origin.originKeyId ||
        ack.body.recipientKeyId != response.body.responderKeyId ||
        ack.body.signerKeyId != origin.originKeyId) {
      return false;
    }
    final originPublic = _decodeExact(
      origin.originPublicKey,
      32,
      'originPublicKey',
    );
    if (ack.body.signerPublicKey != origin.originPublicKey ||
        await publicKeyId(originPublic) != origin.originKeyId) {
      return false;
    }
    return verifyRescueResponseAck(ack, now: now);
  }

  Future<bool> verifyReceipt(
    RelayReceiptEnvelope receipt, {
    DateTime? now,
  }) async {
    receipt.validate(now: now);
    final publicBytes = _decodeExact(
      receipt.signerPublicKey,
      32,
      'signerPublicKey',
    );
    if (await publicKeyId(publicBytes) != receipt.signerKeyId) return false;
    return _algorithm.verify(
      utf8.encode(relayCanonicalJson(receipt.unsignedMap())),
      signature: Signature(
        _decodeExact(receipt.signature, 64, 'signature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  Future<String> receiptSemanticKey(RelayReceiptEnvelope receipt) async {
    final digest = await _hash.hash(
      utf8.encode(
        relayCanonicalJson({
          'type': receipt.type.wireValue,
          'originMessageId': receipt.originMessageId,
          'immutableDigest': receipt.immutableDigest,
          'signerKeyId': receipt.signerKeyId,
          'correlationId': receipt.correlationId,
          'attemptId': receipt.attemptId,
          'finalAuthorizationId': receipt.finalAuthorizationId,
          'status': receipt.status,
          'sessionBinding': receipt.sessionBinding,
        }),
      ),
    );
    return base64UrlEncode(digest.bytes);
  }

  Future<String> signSessionChallenge(
    RelaySessionChallenge challenge,
    SimpleKeyPair keyPair,
  ) async {
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(challenge.unsignedMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<bool> verifySessionChallenge(RelaySessionChallenge challenge) async {
    challenge.validate();
    final publicBytes = _decodeExact(
      challenge.challengerPublicKey,
      32,
      'challengerPublicKey',
    );
    if (await publicKeyId(publicBytes) != challenge.challengerKeyId) {
      return false;
    }
    return _algorithm.verify(
      utf8.encode(relayCanonicalJson(challenge.unsignedMap())),
      signature: Signature(
        _decodeExact(challenge.signature, 64, 'sessionChallengeSignature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  Future<String> signSessionResponse(
    RelaySessionResponse response,
    SimpleKeyPair keyPair,
  ) async {
    final signature = await _algorithm.sign(
      utf8.encode(relayCanonicalJson(response.unsignedMap())),
      keyPair: keyPair,
    );
    return base64UrlEncode(signature.bytes);
  }

  Future<bool> verifySessionResponse(RelaySessionResponse response) async {
    response.validate();
    final publicBytes = _decodeExact(
      response.responderPublicKey,
      32,
      'responderPublicKey',
    );
    if (await publicKeyId(publicBytes) != response.responderKeyId) return false;
    return _algorithm.verify(
      utf8.encode(relayCanonicalJson(response.unsignedMap())),
      signature: Signature(
        _decodeExact(response.signature, 64, 'sessionResponseSignature'),
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
  }

  Future<String> relayAttemptId({
    required String originMessageId,
    required String nextHopKeyId,
  }) async {
    final digest = await _hash.hash(
      utf8.encode(
        relayCanonicalJson({
          'domain': 'off-grid-sos/relay-attempt-id/v1',
          'originMessageId': originMessageId,
          'nextHopKeyId': nextHopKeyId,
        }),
      ),
    );
    return 'r2:${base64UrlEncode(digest.bytes)}';
  }

  Future<String> relaySessionBinding(
    RelaySessionChallenge challenge,
    RelaySessionResponse response,
  ) async {
    final digest = await _hash.hash(
      utf8.encode(
        relayCanonicalJson({
          'domain': 'off-grid-sos/relay-session-binding/v1',
          'challenge': challenge.toJson(),
          'response': response.toJson(),
        }),
      ),
    );
    return base64UrlEncode(digest.bytes);
  }
}

/// Deterministic JSON: recursively sorts object keys and preserves list order.
/// Protocol golden vectors lock this representation before Relay v2 is used.
String relayCanonicalJson(Map<String, Object?> value) =>
    jsonEncode(_canonicalValue(value));

Object? _canonicalValue(Object? value) {
  if (value is Map) {
    final sorted = SplayTreeMap<String, Object?>();
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const RelayProtocolException(
          'Canonical map key is not a string.',
        );
      }
      sorted[entry.key as String] = _canonicalValue(entry.value);
    }
    return sorted;
  }
  if (value is List) return value.map(_canonicalValue).toList(growable: false);
  if (value is double) {
    if (!value.isFinite) {
      throw const RelayProtocolException(
        'Canonical JSON does not allow non-finite numbers.',
      );
    }
    if (value == 0) return 0;
    return value;
  }
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  throw const RelayProtocolException('Unsupported canonical value.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw RelayProtocolException('Missing or invalid $key.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.isEmpty) {
    throw const RelayProtocolException('Invalid optional string.');
  }
  return value;
}

Map<String, Object?> _decodeCanonicalObject(String wire, String name) {
  try {
    final decoded = jsonDecode(wire);
    if (decoded is! Map) {
      throw const RelayProtocolException(
        'Canonical JSON root is not an object.',
      );
    }
    return Map<String, Object?>.from(decoded);
  } on RelayProtocolException {
    rethrow;
  } on Object {
    throw RelayProtocolException('Malformed $name JSON.');
  }
}

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const RelayProtocolException(
      'Protocol object contains missing or unknown fields.',
    );
  }
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw RelayProtocolException('Missing or invalid $key.');
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw RelayProtocolException('Missing or invalid $key.');
  return value;
}

DateTime _requiredDate(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw RelayProtocolException('Missing or invalid $key.');
  }
  return parsed;
}

double? _optionalDouble(Object? value) => switch (value) {
  null => null,
  num number => number.toDouble(),
  _ => throw const RelayProtocolException('Invalid coordinate.'),
};

void _boundedId(String value, String name) => _boundedText(value, name, 128);

void _boundedKeyId(String value, String name) {
  _boundedText(value, name, 64);
  _decodeExact(value, 32, name);
}

void _boundedText(String value, String name, int maximum) {
  if (value.isEmpty || utf8.encode(value).length > maximum) {
    throw RelayProtocolException('$name is invalid.');
  }
}

List<int> _decodeExact(String value, int length, String name) {
  try {
    final decoded = base64Url.decode(base64Url.normalize(value));
    if (decoded.length != length) throw const FormatException();
    return decoded;
  } on FormatException {
    throw RelayProtocolException('$name has an invalid encoding.');
  }
}

bool _validCoordinates(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;

/// Validates the opaque SHA-256 installation-key fingerprint used for relay
/// routing without treating it as a verified human identity.
void validateRelayKeyId(String value, {String name = 'relayKeyId'}) {
  _boundedKeyId(value, name);
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class RelayProtocolCapabilities {
  static const relayV2 = 'sos.relay.v2';
}

const _relaySessionRoles = {'central', 'peripheral'};

/// Signed challenge for one active relay connection generation. Transport
/// identifiers route this packet but are intentionally not authenticated IDs.
class RelaySessionChallenge {
  const RelaySessionChallenge({
    required this.nonce,
    required this.challengerKeyId,
    required this.challengerPublicKey,
    required this.challengedKeyId,
    required this.challengerRole,
    required this.challengedRole,
    required this.challengerGeneration,
    required this.challengedGeneration,
    required this.challengerParticipating,
    required this.signature,
  });

  static const wireKind = 'sos.relay.session_challenge.v2';
  static const schemaVersion = 1;
  static const signatureDomain = 'off-grid-sos/relay-session-challenge/v1';

  final String nonce;
  final String challengerKeyId;
  final String challengerPublicKey;
  final String challengedKeyId;
  final String challengerRole;
  final String challengedRole;
  final int challengerGeneration;
  final int challengedGeneration;
  final bool challengerParticipating;
  final String signature;

  Map<String, Object?> unsignedMap() => {
    'domain': signatureDomain,
    'kind': wireKind,
    'schemaVersion': schemaVersion,
    'capability': RelayProtocolCapabilities.relayV2,
    'nonce': nonce,
    'challengerKeyId': challengerKeyId,
    'challengerPublicKey': challengerPublicKey,
    'challengedKeyId': challengedKeyId,
    'challengerRole': challengerRole,
    'challengedRole': challengedRole,
    'challengerGeneration': challengerGeneration,
    'challengedGeneration': challengedGeneration,
    'challengerParticipating': challengerParticipating,
  };

  Map<String, Object?> toJson() => {...unsignedMap(), 'signature': signature};

  factory RelaySessionChallenge.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'domain',
      'kind',
      'schemaVersion',
      'capability',
      'nonce',
      'challengerKeyId',
      'challengerPublicKey',
      'challengedKeyId',
      'challengerRole',
      'challengedRole',
      'challengerGeneration',
      'challengedGeneration',
      'challengerParticipating',
      'signature',
    });
    if (json['domain'] != signatureDomain ||
        json['kind'] != wireKind ||
        json['schemaVersion'] != schemaVersion ||
        json['capability'] != RelayProtocolCapabilities.relayV2) {
      throw const RelayProtocolException(
        'Unsupported relay session challenge.',
      );
    }
    final challenge = RelaySessionChallenge(
      nonce: _requiredString(json, 'nonce'),
      challengerKeyId: _requiredString(json, 'challengerKeyId'),
      challengerPublicKey: _requiredString(json, 'challengerPublicKey'),
      challengedKeyId: _requiredString(json, 'challengedKeyId'),
      challengerRole: _requiredString(json, 'challengerRole'),
      challengedRole: _requiredString(json, 'challengedRole'),
      challengerGeneration: _requiredInt(json, 'challengerGeneration'),
      challengedGeneration: _requiredInt(json, 'challengedGeneration'),
      challengerParticipating: _requiredBool(json, 'challengerParticipating'),
      signature: _requiredString(json, 'signature'),
    );
    challenge.validate();
    return challenge;
  }

  void validate() {
    _decodeExact(nonce, 32, 'sessionNonce');
    _boundedKeyId(challengerKeyId, 'challengerKeyId');
    _decodeExact(challengerPublicKey, 32, 'challengerPublicKey');
    _boundedKeyId(challengedKeyId, 'challengedKeyId');
    _decodeExact(signature, 64, 'sessionChallengeSignature');
    if (!_relaySessionRoles.contains(challengerRole) ||
        !_relaySessionRoles.contains(challengedRole) ||
        challengerRole == challengedRole ||
        challengerGeneration < 1 ||
        challengedGeneration < 1) {
      throw const RelayProtocolException('Invalid relay session challenge.');
    }
  }
}

/// Signed response that echoes the signed challenge and binds the responder's
/// installation key plus its local connection generation.
class RelaySessionResponse {
  const RelaySessionResponse({
    required this.challenge,
    required this.responderKeyId,
    required this.responderPublicKey,
    required this.responderGeneration,
    required this.responderParticipating,
    required this.signature,
  });

  static const wireKind = 'sos.relay.session_response.v2';
  static const schemaVersion = 1;
  static const signatureDomain = 'off-grid-sos/relay-session-response/v1';

  final RelaySessionChallenge challenge;
  final String responderKeyId;
  final String responderPublicKey;
  final int responderGeneration;
  final bool responderParticipating;
  final String signature;

  Map<String, Object?> unsignedMap() => {
    'domain': signatureDomain,
    'kind': wireKind,
    'schemaVersion': schemaVersion,
    'capability': RelayProtocolCapabilities.relayV2,
    'challenge': challenge.toJson(),
    'responderKeyId': responderKeyId,
    'responderPublicKey': responderPublicKey,
    'responderGeneration': responderGeneration,
    'responderParticipating': responderParticipating,
  };

  Map<String, Object?> toJson() => {...unsignedMap(), 'signature': signature};

  factory RelaySessionResponse.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'domain',
      'kind',
      'schemaVersion',
      'capability',
      'challenge',
      'responderKeyId',
      'responderPublicKey',
      'responderGeneration',
      'responderParticipating',
      'signature',
    });
    if (json['domain'] != signatureDomain ||
        json['kind'] != wireKind ||
        json['schemaVersion'] != schemaVersion ||
        json['capability'] != RelayProtocolCapabilities.relayV2 ||
        json['challenge'] is! Map) {
      throw const RelayProtocolException('Unsupported relay session response.');
    }
    final response = RelaySessionResponse(
      challenge: RelaySessionChallenge.fromJson(
        Map<String, Object?>.from(json['challenge']! as Map),
      ),
      responderKeyId: _requiredString(json, 'responderKeyId'),
      responderPublicKey: _requiredString(json, 'responderPublicKey'),
      responderGeneration: _requiredInt(json, 'responderGeneration'),
      responderParticipating: _requiredBool(json, 'responderParticipating'),
      signature: _requiredString(json, 'signature'),
    );
    response.validate();
    return response;
  }

  void validate() {
    challenge.validate();
    _boundedKeyId(responderKeyId, 'responderKeyId');
    _decodeExact(responderPublicKey, 32, 'responderPublicKey');
    _decodeExact(signature, 64, 'sessionResponseSignature');
    if (responderGeneration < 1 ||
        responderKeyId != challenge.challengedKeyId) {
      throw const RelayProtocolException('Invalid relay session response.');
    }
  }
}

/// Additive capability advertisement. It proves protocol support only; neither
/// the transport peer nor the declared key is an authorized person identity.
class RelayCapabilityAdvertisement {
  const RelayCapabilityAdvertisement({
    required this.capabilities,
    required this.participating,
    this.relayKeyId,
    this.relayPublicKey,
    this.sessionGeneration,
    this.sessionRole,
  });

  static const wireKind = 'sos.capabilities.v1';
  static const schemaVersion = 1;

  final List<String> capabilities;
  final bool participating;
  final String? relayKeyId;
  final String? relayPublicKey;
  final int? sessionGeneration;
  final String? sessionRole;

  Map<String, Object?> toJson() => {
    'kind': wireKind,
    'schemaVersion': schemaVersion,
    'capabilities': capabilities,
    'participating': participating,
    'relayKeyId': relayKeyId,
    'relayPublicKey': relayPublicKey,
    'sessionGeneration': sessionGeneration,
    'sessionRole': sessionRole,
  };

  factory RelayCapabilityAdvertisement.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'kind',
      'schemaVersion',
      'capabilities',
      'participating',
      'relayKeyId',
      'relayPublicKey',
      'sessionGeneration',
      'sessionRole',
    });
    final capabilities = json['capabilities'];
    if (json['kind'] != wireKind ||
        json['schemaVersion'] != schemaVersion ||
        capabilities is! List ||
        capabilities.any((value) => value is! String) ||
        capabilities.length > 16) {
      throw const RelayProtocolException('Invalid relay capabilities.');
    }
    final result = RelayCapabilityAdvertisement(
      capabilities: capabilities.cast<String>().toList(growable: false),
      participating: _requiredBool(json, 'participating'),
      relayKeyId: _optionalString(json['relayKeyId']),
      relayPublicKey: _optionalString(json['relayPublicKey']),
      sessionGeneration: json['sessionGeneration'] == null
          ? null
          : _requiredInt(json, 'sessionGeneration'),
      sessionRole: _optionalString(json['sessionRole']),
    );
    final supportsRelay = result.capabilities.contains(
      RelayProtocolCapabilities.relayV2,
    );
    if (!supportsRelay &&
        (result.participating ||
            result.relayKeyId != null ||
            result.relayPublicKey != null)) {
      throw const RelayProtocolException(
        'Relay metadata is present without the relay capability.',
      );
    }
    if (supportsRelay &&
        ((result.relayKeyId == null) != (result.relayPublicKey == null) ||
            (result.relayKeyId == null) != (result.sessionGeneration == null) ||
            (result.relayKeyId == null) != (result.sessionRole == null))) {
      throw const RelayProtocolException('Relay key metadata is incomplete.');
    }
    if (result.participating && result.relayKeyId == null) {
      throw const RelayProtocolException(
        'A participating relay must declare its key.',
      );
    }
    if (result.relayKeyId != null) {
      _boundedKeyId(result.relayKeyId!, 'relayKeyId');
      _decodeExact(result.relayPublicKey!, 32, 'relayPublicKey');
      if (result.sessionGeneration! < 1 ||
          !_relaySessionRoles.contains(result.sessionRole)) {
        throw const RelayProtocolException(
          'Relay session metadata is invalid.',
        );
      }
    }
    return result;
  }
}

/// Transport-only binding around the already signed relay offer. Attempt and
/// correlation identifiers are deterministic and are covered by the signed hop
/// receipt returned by the receiving relay.
class RelayOfferTransfer {
  const RelayOfferTransfer({
    required this.wireOffer,
    required this.attemptId,
    required this.correlationId,
  });

  static const wireKind = 'sos.relay.transfer.v2';
  static const schemaVersion = 1;

  final String wireOffer;
  final String attemptId;
  final String correlationId;

  Map<String, Object?> toJson() => {
    'kind': wireKind,
    'schemaVersion': schemaVersion,
    'wireOffer': wireOffer,
    'attemptId': attemptId,
    'correlationId': correlationId,
  };

  factory RelayOfferTransfer.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'kind',
      'schemaVersion',
      'wireOffer',
      'attemptId',
      'correlationId',
    });
    if (json['kind'] != wireKind || json['schemaVersion'] != schemaVersion) {
      throw const RelayProtocolException('Unsupported relay transfer.');
    }
    final transfer = RelayOfferTransfer(
      wireOffer: _requiredString(json, 'wireOffer'),
      attemptId: _requiredString(json, 'attemptId'),
      correlationId: _requiredString(json, 'correlationId'),
    );
    _boundedText(
      transfer.wireOffer,
      'wireOffer',
      BleRelayWireLimits.maximumOfferBytes,
    );
    _boundedId(transfer.attemptId, 'attemptId');
    _boundedId(transfer.correlationId, 'correlationId');
    return transfer;
  }
}

class BleRelayWireLimits {
  static const maximumOfferBytes = 48 * 1024;
}

class RelayProtocolException implements Exception {
  const RelayProtocolException(this.message);
  final String message;

  @override
  String toString() => 'RelayProtocolException: $message';
}
