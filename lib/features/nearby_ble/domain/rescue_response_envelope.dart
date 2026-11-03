import 'dart:convert';

import 'relay_envelope.dart';

/// Versioned, responder-authenticated response to one voluntary-rescue SOS.
///
/// This is deliberately separate from [RelayOfferEnvelope]. Relays may append
/// hop attestations to the transport wrapper, but cannot alter this signed
/// response body or turn a hop receipt into a final-recipient receipt.
class RescueResponseBody {
  const RescueResponseBody({
    required this.messageId,
    required this.incidentId,
    required this.originMessageId,
    required this.originKeyId,
    required this.originDigest,
    required this.responderKeyId,
    required this.responderPublicKey,
    required this.sessionBinding,
    required this.createdAt,
    required this.expiresAt,
    this.hopCount = 0,
    this.maxHops = 3,
    this.status = 'offer',
  });

  static const schemaVersion = 1;
  static const wireKind = 'rescue.offer';

  final String messageId;
  final String incidentId;
  final String originMessageId;
  final String originKeyId;
  final String originDigest;
  final String responderKeyId;
  final String responderPublicKey;
  final String sessionBinding;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int hopCount;
  final int maxHops;
  final String status;

  Map<String, Object?> toCanonicalMap() => {
    'schemaVersion': schemaVersion,
    'kind': wireKind,
    'messageId': messageId,
    'incidentId': incidentId,
    'originMessageId': originMessageId,
    'originKeyId': originKeyId,
    'originDigest': originDigest,
    'responderKeyId': responderKeyId,
    'responderPublicKey': responderPublicKey,
    'sessionBinding': sessionBinding,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'hopCount': hopCount,
    'maxHops': maxHops,
    'status': status,
  };

  factory RescueResponseBody.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'schemaVersion',
      'kind',
      'messageId',
      'incidentId',
      'originMessageId',
      'originKeyId',
      'originDigest',
      'responderKeyId',
      'responderPublicKey',
      'sessionBinding',
      'createdAt',
      'expiresAt',
      'hopCount',
      'maxHops',
      'status',
    });
    if (json['schemaVersion'] != schemaVersion || json['kind'] != wireKind) {
      throw const RelayProtocolException('Unsupported rescue response schema.');
    }
    return RescueResponseBody(
      messageId: _string(json, 'messageId'),
      incidentId: _string(json, 'incidentId'),
      originMessageId: _string(json, 'originMessageId'),
      originKeyId: _string(json, 'originKeyId'),
      originDigest: _string(json, 'originDigest'),
      responderKeyId: _string(json, 'responderKeyId'),
      responderPublicKey: _string(json, 'responderPublicKey'),
      sessionBinding: _string(json, 'sessionBinding'),
      createdAt: _date(json, 'createdAt'),
      expiresAt: _date(json, 'expiresAt'),
      hopCount: _int(json, 'hopCount'),
      maxHops: _int(json, 'maxHops'),
      status: _string(json, 'status'),
    );
  }

  void validate({DateTime? now}) {
    _boundedId(messageId, 'messageId');
    _boundedId(incidentId, 'incidentId');
    _boundedId(originMessageId, 'originMessageId');
    _boundedId(originKeyId, 'originKeyId');
    _boundedId(responderKeyId, 'responderKeyId');
    _boundedText(originDigest, 'originDigest', 128);
    _boundedText(sessionBinding, 'sessionBinding', 256);
    _decodeExact(responderPublicKey, 32, 'responderPublicKey');
    if (!createdAt.isUtc || !expiresAt.isUtc || !expiresAt.isAfter(createdAt)) {
      throw const RelayProtocolException(
        'Rescue response timestamps are invalid.',
      );
    }
    if (expiresAt.difference(createdAt) > RelayProtocolLimits.maximumLifetime) {
      throw const RelayProtocolException('Rescue response TTL is too long.');
    }
    if (now != null && !expiresAt.isAfter(now.toUtc())) {
      throw const RelayProtocolException('Rescue response has expired.');
    }
    if (hopCount < 0 ||
        maxHops < 1 ||
        maxHops > RelayProtocolLimits.maximumHops ||
        hopCount > maxHops) {
      throw const RelayProtocolException(
        'Rescue response hop limit is invalid.',
      );
    }
    if (status != 'offer') {
      throw const RelayProtocolException('Unsupported rescue response status.');
    }
  }
}

class RescueResponseEnvelope {
  const RescueResponseEnvelope({required this.body, required this.signature});

  final RescueResponseBody body;
  final String signature;

  Map<String, Object?> toJson() => {
    'body': body.toCanonicalMap(),
    'signature': signature,
  };

  String toCanonicalWire() => relayCanonicalJson(toJson());

  factory RescueResponseEnvelope.fromCanonicalWire(String wire) {
    final decoded = jsonDecode(wire);
    if (decoded is! Map) {
      throw const RelayProtocolException('Rescue response is not an object.');
    }
    return RescueResponseEnvelope.fromJson(Map<String, Object?>.from(decoded));
  }

  factory RescueResponseEnvelope.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {'body', 'signature'});
    final rawBody = json['body'];
    if (rawBody is! Map) {
      throw const RelayProtocolException('Rescue response body is invalid.');
    }
    return RescueResponseEnvelope(
      body: RescueResponseBody.fromJson(Map<String, Object?>.from(rawBody)),
      signature: _string(json, 'signature'),
    );
  }

  void validate({DateTime? now}) {
    body.validate(now: now);
    _decodeExact(signature, 64, 'signature');
  }
}

/// Final-recipient acknowledgement signed by the SOS origin. A relay hop ACK
/// is a different Relay v2 message and cannot satisfy this contract.
class RescueResponseAckBody {
  const RescueResponseAckBody({
    required this.ackId,
    required this.responseMessageId,
    required this.incidentId,
    required this.originMessageId,
    required this.originKeyId,
    required this.signerKeyId,
    required this.signerPublicKey,
    required this.recipientKeyId,
    required this.sessionBinding,
    required this.createdAt,
    required this.expiresAt,
    this.hopCount = 0,
    this.maxHops = 3,
    this.status = 'final_received',
  });

  static const schemaVersion = 1;
  static const wireKind = 'rescue.offer_ack';

  final String ackId;
  final String responseMessageId;
  final String incidentId;
  final String originMessageId;
  final String originKeyId;
  final String signerKeyId;
  final String signerPublicKey;
  final String recipientKeyId;
  final String sessionBinding;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int hopCount;
  final int maxHops;
  final String status;

  Map<String, Object?> toCanonicalMap() => {
    'schemaVersion': schemaVersion,
    'kind': wireKind,
    'ackId': ackId,
    'responseMessageId': responseMessageId,
    'incidentId': incidentId,
    'originMessageId': originMessageId,
    'originKeyId': originKeyId,
    'signerKeyId': signerKeyId,
    'signerPublicKey': signerPublicKey,
    'recipientKeyId': recipientKeyId,
    'sessionBinding': sessionBinding,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'hopCount': hopCount,
    'maxHops': maxHops,
    'status': status,
  };

  factory RescueResponseAckBody.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'schemaVersion',
      'kind',
      'ackId',
      'responseMessageId',
      'incidentId',
      'originMessageId',
      'originKeyId',
      'signerKeyId',
      'signerPublicKey',
      'recipientKeyId',
      'sessionBinding',
      'createdAt',
      'expiresAt',
      'hopCount',
      'maxHops',
      'status',
    });
    if (json['schemaVersion'] != schemaVersion || json['kind'] != wireKind) {
      throw const RelayProtocolException('Unsupported rescue ACK schema.');
    }
    return RescueResponseAckBody(
      ackId: _string(json, 'ackId'),
      responseMessageId: _string(json, 'responseMessageId'),
      incidentId: _string(json, 'incidentId'),
      originMessageId: _string(json, 'originMessageId'),
      originKeyId: _string(json, 'originKeyId'),
      signerKeyId: _string(json, 'signerKeyId'),
      signerPublicKey: _string(json, 'signerPublicKey'),
      recipientKeyId: _string(json, 'recipientKeyId'),
      sessionBinding: _string(json, 'sessionBinding'),
      createdAt: _date(json, 'createdAt'),
      expiresAt: _date(json, 'expiresAt'),
      hopCount: _int(json, 'hopCount'),
      maxHops: _int(json, 'maxHops'),
      status: _string(json, 'status'),
    );
  }

  void validate({DateTime? now}) {
    for (final entry in <String, String>{
      'ackId': ackId,
      'responseMessageId': responseMessageId,
      'incidentId': incidentId,
      'originMessageId': originMessageId,
      'originKeyId': originKeyId,
      'signerKeyId': signerKeyId,
      'recipientKeyId': recipientKeyId,
    }.entries) {
      _boundedId(entry.value, entry.key);
    }
    _boundedText(sessionBinding, 'sessionBinding', 256);
    _decodeExact(signerPublicKey, 32, 'signerPublicKey');
    if (!createdAt.isUtc || !expiresAt.isUtc || !expiresAt.isAfter(createdAt)) {
      throw const RelayProtocolException('Rescue ACK timestamps are invalid.');
    }
    if (expiresAt.difference(createdAt) > RelayProtocolLimits.maximumLifetime ||
        (now != null && !expiresAt.isAfter(now.toUtc()))) {
      throw const RelayProtocolException('Rescue ACK is expired or too long.');
    }
    if (hopCount < 0 ||
        maxHops < 1 ||
        maxHops > RelayProtocolLimits.maximumHops ||
        hopCount > maxHops) {
      throw const RelayProtocolException('Rescue ACK hop limit is invalid.');
    }
    if (status != 'final_received') {
      throw const RelayProtocolException('Unsupported rescue ACK status.');
    }
  }
}

class RescueResponseAckEnvelope {
  const RescueResponseAckEnvelope({
    required this.body,
    required this.signature,
  });

  final RescueResponseAckBody body;
  final String signature;

  Map<String, Object?> toJson() => {
    'body': body.toCanonicalMap(),
    'signature': signature,
  };

  String toCanonicalWire() => relayCanonicalJson(toJson());

  factory RescueResponseAckEnvelope.fromCanonicalWire(String wire) {
    final decoded = jsonDecode(wire);
    if (decoded is! Map) {
      throw const RelayProtocolException('Rescue ACK is invalid.');
    }
    return RescueResponseAckEnvelope.fromJson(
      Map<String, Object?>.from(decoded),
    );
  }

  factory RescueResponseAckEnvelope.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {'body', 'signature'});
    final rawBody = json['body'];
    if (rawBody is! Map) {
      throw const RelayProtocolException('Rescue ACK body is invalid.');
    }
    return RescueResponseAckEnvelope(
      body: RescueResponseAckBody.fromJson(Map<String, Object?>.from(rawBody)),
      signature: _string(json, 'signature'),
    );
  }

  void validate({DateTime? now}) {
    body.validate(now: now);
    _decodeExact(signature, 64, 'signature');
  }
}

/// Additive BLE transport wrapper for response and final-ACK envelopes.
/// The signed inner envelope remains immutable across every hop.
class RescueResponseTransfer {
  const RescueResponseTransfer({
    required this.attemptId,
    required this.correlationId,
    required this.sessionBinding,
    required this.wireEnvelope,
    required this.hopCount,
    required this.maxHops,
    required this.isAck,
  });

  static const wireKind = 'rescue.response.transfer.v1';

  final String attemptId;
  final String correlationId;
  final String sessionBinding;
  final String wireEnvelope;
  final int hopCount;
  final int maxHops;
  final bool isAck;

  Map<String, Object?> toJson() => {
    'kind': wireKind,
    'attemptId': attemptId,
    'correlationId': correlationId,
    'sessionBinding': sessionBinding,
    'wireEnvelope': wireEnvelope,
    'hopCount': hopCount,
    'maxHops': maxHops,
    'isAck': isAck,
  };

  factory RescueResponseTransfer.fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, {
      'kind',
      'attemptId',
      'correlationId',
      'sessionBinding',
      'wireEnvelope',
      'hopCount',
      'maxHops',
      'isAck',
    });
    if (json['kind'] != wireKind) {
      throw const RelayProtocolException('Unsupported rescue transfer kind.');
    }
    final isAck = json['isAck'];
    if (isAck is! bool) {
      throw const RelayProtocolException(
        'Rescue transfer ACK flag is invalid.',
      );
    }
    return RescueResponseTransfer(
      attemptId: _string(json, 'attemptId'),
      correlationId: _string(json, 'correlationId'),
      sessionBinding: _string(json, 'sessionBinding'),
      wireEnvelope: _string(json, 'wireEnvelope'),
      hopCount: _int(json, 'hopCount'),
      maxHops: _int(json, 'maxHops'),
      isAck: isAck,
    );
  }

  void validate() {
    _boundedId(attemptId, 'attemptId');
    _boundedId(correlationId, 'correlationId');
    _boundedText(sessionBinding, 'sessionBinding', 256);
    _boundedText(wireEnvelope, 'wireEnvelope', 128 * 1024);
    if (hopCount < 0 ||
        maxHops < 1 ||
        maxHops > RelayProtocolLimits.maximumHops ||
        hopCount > maxHops) {
      throw const RelayProtocolException(
        'Rescue transfer hop limit is invalid.',
      );
    }
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw RelayProtocolException('Missing or invalid $key.');
  }
  return value;
}

DateTime _date(Map<String, Object?> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null) throw RelayProtocolException('Missing or invalid $key.');
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw RelayProtocolException('Missing or invalid $key.');
  return value;
}

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (!Set<String>.from(json.keys).containsAll(expected) ||
      json.keys.length != expected.length) {
    throw const RelayProtocolException('Unexpected rescue response fields.');
  }
}

void _boundedId(String value, String field) {
  if (value.length > 256) throw RelayProtocolException('$field is too long.');
}

void _boundedText(String value, String field, int max) {
  if (value.isEmpty || value.length > max) {
    throw RelayProtocolException('$field is invalid.');
  }
}

List<int> _decodeExact(String encoded, int length, String field) {
  try {
    final bytes = base64Url.decode(base64Url.normalize(encoded));
    if (bytes.length != length) throw const FormatException();
    return bytes;
  } on FormatException {
    throw RelayProtocolException('$field has invalid encoding.');
  }
}
