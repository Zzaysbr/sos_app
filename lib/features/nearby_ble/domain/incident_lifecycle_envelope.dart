import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../data/ble_protocol.dart';
import 'relay_envelope.dart';
import '../data/relay_key_store.dart';

/// Origin-signed terminal state transition for an SOS incident.
///
/// The payload is immutable and can be retried through the existing BLE
/// outbox/inbox. Intermediate peers may store/forward it, but cannot alter the
/// incident, actor, status, or signature.
class IncidentLifecycleEnvelope {
  const IncidentLifecycleEnvelope({
    required this.eventId,
    required this.incidentId,
    required this.status,
    required this.originKeyId,
    required this.originPublicKey,
    required this.actorKeyId,
    required this.createdAt,
    required this.signature,
  });

  static const wireKind = 'sos.lifecycle.v1';
  static const schemaVersion = 1;
  static const maxIdLength = 128;

  final String eventId;
  final String incidentId;
  final String status;
  final String originKeyId;
  final String originPublicKey;
  final String actorKeyId;
  final DateTime createdAt;
  final String signature;

  Map<String, Object?> unsignedMap() => {
    'kind': wireKind,
    'schemaVersion': schemaVersion,
    'eventId': eventId,
    'incidentId': incidentId,
    'status': status,
    'originKeyId': originKeyId,
    'originPublicKey': originPublicKey,
    'actorKeyId': actorKeyId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toJson() => {...unsignedMap(), 'signature': signature};

  String toCanonicalWire() => relayCanonicalJson(toJson());

  BleMessage toBleMessage() => BleMessage(
    id: eventId,
    type: wireKind,
    createdAt: createdAt,
    payload: toJson(),
  );

  factory IncidentLifecycleEnvelope.fromBleMessage(BleMessage message) {
    if (message.type != wireKind || message.id != message.payload['eventId']) {
      throw const RelayProtocolException(
        'Lifecycle transport binding is invalid.',
      );
    }
    final envelope = IncidentLifecycleEnvelope.fromJson(message.payload);
    if (envelope.createdAt.toUtc() != message.createdAt.toUtc()) {
      throw const RelayProtocolException(
        'Lifecycle timestamp binding is invalid.',
      );
    }
    return envelope;
  }

  factory IncidentLifecycleEnvelope.fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty || value.length > maxIdLength) {
        throw RelayProtocolException('Invalid lifecycle $key.');
      }
      return value;
    }

    if (json['kind'] != wireKind || json['schemaVersion'] != schemaVersion) {
      throw const RelayProtocolException('Unsupported lifecycle envelope.');
    }
    final status = required('status');
    if (status != 'cancelled' && status != 'resolved') {
      throw const RelayProtocolException('Lifecycle status is not terminal.');
    }
    final createdAt = DateTime.tryParse(required('createdAt'))?.toUtc();
    if (createdAt == null) {
      throw const RelayProtocolException('Invalid lifecycle timestamp.');
    }
    final signature = required('signature');
    return IncidentLifecycleEnvelope(
      eventId: required('eventId'),
      incidentId: required('incidentId'),
      status: status,
      originKeyId: required('originKeyId'),
      originPublicKey: required('originPublicKey'),
      actorKeyId: required('actorKeyId'),
      createdAt: createdAt,
      signature: signature,
    );
  }

  Future<void> validate({DateTime? now}) async {
    if (eventId.isEmpty ||
        incidentId.isEmpty ||
        originKeyId.isEmpty ||
        eventId.length > maxIdLength ||
        incidentId.length > maxIdLength ||
        (status != 'cancelled' && status != 'resolved')) {
      throw const RelayProtocolException('Lifecycle identifiers are required.');
    }
    if (actorKeyId != originKeyId) {
      throw const RelayProtocolException('Lifecycle actor is not authorized.');
    }
    final timestamp = now?.toUtc();
    if (timestamp != null &&
        createdAt.isAfter(timestamp.add(const Duration(minutes: 5)))) {
      throw const RelayProtocolException(
        'Lifecycle timestamp is too far in the future.',
      );
    }
    final publicBytes = base64Url.decode(base64Url.normalize(originPublicKey));
    final signatureBytes = base64Url.decode(base64Url.normalize(signature));
    if (publicBytes.length != 32 || signatureBytes.length != 64) {
      throw const RelayProtocolException(
        'Lifecycle signature encoding is invalid.',
      );
    }
    final crypto = Ed25519();
    final digest = await Sha256().hash(publicBytes);
    if (base64UrlEncode(digest.bytes) != originKeyId) {
      throw const RelayProtocolException(
        'Lifecycle origin key binding is invalid.',
      );
    }
    final valid = await crypto.verify(
      utf8.encode(relayCanonicalJson(unsignedMap())),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!valid) {
      throw const RelayProtocolException('Lifecycle signature is invalid.');
    }
  }

  static Future<IncidentLifecycleEnvelope> sign({
    required String incidentId,
    required String status,
    required RelaySigningIdentity identity,
    DateTime? now,
  }) async {
    final createdAt = (now ?? DateTime.now()).toUtc();
    final eventId =
        'lifecycle:$incidentId:$status:${createdAt.microsecondsSinceEpoch}';
    final unsigned = IncidentLifecycleEnvelope(
      eventId: eventId,
      incidentId: incidentId,
      status: status,
      originKeyId: identity.keyId,
      originPublicKey: base64UrlEncode(identity.publicKey),
      actorKeyId: identity.keyId,
      createdAt: createdAt,
      signature: '',
    );
    final signature = await Ed25519().sign(
      utf8.encode(relayCanonicalJson(unsigned.unsignedMap())),
      keyPair: identity.keyPair,
    );
    return IncidentLifecycleEnvelope(
      eventId: eventId,
      incidentId: incidentId,
      status: status,
      originKeyId: identity.keyId,
      originPublicKey: base64UrlEncode(identity.publicKey),
      actorKeyId: identity.keyId,
      createdAt: createdAt,
      signature: base64UrlEncode(signature.bytes),
    );
  }
}
