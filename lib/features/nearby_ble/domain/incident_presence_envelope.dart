import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../data/ble_protocol.dart';
import '../data/relay_key_store.dart';
import 'relay_envelope.dart';

/// Short-lived, origin-signed contact evidence. Never changes SOS lifecycle.
class IncidentPresenceEnvelope {
  const IncidentPresenceEnvelope({
    required this.id,
    required this.incidentId,
    required this.keyId,
    required this.publicKey,
    required this.createdAt,
    required this.expiresAt,
    required this.signature,
    required this.path,
    this.direct = false,
  });
  static const wireKind = 'sos.presence.v1';
  static const lifetime = Duration(seconds: 45);
  static const interval = Duration(seconds: 10);
  final String id, incidentId, keyId, publicKey, signature;
  final DateTime createdAt, expiresAt;
  final List<String> path;
  final bool direct;

  Map<String, Object?> get body => {
    'kind': wireKind,
    'version': 1,
    'id': id,
    'incidentId': incidentId,
    'keyId': keyId,
    'publicKey': publicKey,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'maxHops': RelayProtocolLimits.maximumHops,
    'scope': direct ? 'direct' : 'public',
  };
  BleMessage toMessage() => BleMessage(
    id: id,
    type: wireKind,
    createdAt: createdAt,
    payload: {...body, 'signature': signature, 'path': path},
  );

  factory IncidentPresenceEnvelope.fromMessage(BleMessage message) {
    final p = message.payload;
    String text(String field, int limit) {
      final v = p[field];
      if (v is! String || v.isEmpty || v.length > limit) {
        throw const RelayProtocolException('Invalid presence field.');
      }
      return v;
    }

    if (message.type != wireKind ||
        p['kind'] != wireKind ||
        p['version'] != 1 ||
        p['maxHops'] != RelayProtocolLimits.maximumHops ||
        !const {'direct', 'public'}.contains(p['scope']) ||
        p.length != 12) {
      throw const RelayProtocolException('Invalid presence schema.');
    }
    final created = DateTime.tryParse(text('createdAt', 40));
    final expiry = DateTime.tryParse(text('expiresAt', 40));
    final path = p['path'];
    if (created == null ||
        expiry == null ||
        path is! List ||
        path.isEmpty ||
        path.length > RelayProtocolLimits.maximumHops ||
        path.any((key) => key is! String)) {
      throw const RelayProtocolException('Invalid presence path/time.');
    }
    final value = IncidentPresenceEnvelope(
      id: text('id', 128),
      incidentId: text('incidentId', 128),
      keyId: text('keyId', 64),
      publicKey: text('publicKey', 64),
      signature: text('signature', 96),
      createdAt: created.toUtc(),
      expiresAt: expiry.toUtc(),
      path: List<String>.from(path),
      direct: p['scope'] == 'direct',
    );
    if (message.id != value.id ||
        !RegExp(r'^presence:[A-Za-z0-9_-]{16}$').hasMatch(value.id) ||
        message.createdAt.toUtc() != value.createdAt ||
        value.path.first != value.keyId ||
        value.path.toSet().length != value.path.length) {
      throw const RelayProtocolException('Invalid presence transport binding.');
    }
    for (final key in value.path) {
      validateRelayKeyId(key);
    }
    if (value.direct && value.path.length != 1) {
      throw const RelayProtocolException('Direct presence cannot be relayed.');
    }
    return value;
  }

  Future<void> verify(DateTime now) async {
    if (!expiresAt.isAfter(now.toUtc()) ||
        createdAt.isAfter(now.toUtc().add(const Duration(seconds: 5))) ||
        expiresAt.difference(createdAt) != lifetime) {
      throw const RelayProtocolException('Presence is not fresh.');
    }
    final pub = base64Url.decode(base64Url.normalize(publicKey));
    final sig = base64Url.decode(base64Url.normalize(signature));
    if (pub.length != 32 ||
        sig.length != 64 ||
        base64UrlEncode((await Sha256().hash(pub)).bytes) != keyId ||
        !await Ed25519().verify(
          utf8.encode(relayCanonicalJson(body)),
          signature: Signature(
            sig,
            publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519),
          ),
        )) {
      throw const RelayProtocolException('Invalid presence signature.');
    }
  }

  IncidentPresenceEnvelope forwardedBy(String key) {
    if (direct ||
        path.contains(key) ||
        path.length >= RelayProtocolLimits.maximumHops) {
      throw const RelayProtocolException('Presence hop limit/loop.');
    }
    return IncidentPresenceEnvelope(
      id: id,
      incidentId: incidentId,
      keyId: keyId,
      publicKey: publicKey,
      createdAt: createdAt,
      expiresAt: expiresAt,
      signature: signature,
      path: [...path, key],
      direct: direct,
    );
  }

  static Future<IncidentPresenceEnvelope> sign(
    String incident,
    RelaySigningIdentity identity,
    DateTime now, {
    bool direct = false,
  }) async {
    if (incident.isEmpty || incident.length > 128) {
      throw const RelayProtocolException('Invalid presence incident.');
    }
    final random = Random.secure();
    final nonce = base64UrlEncode(
      List.generate(12, (_) => random.nextInt(256)),
    );
    final created = now.toUtc();
    final value = IncidentPresenceEnvelope(
      id: 'presence:$nonce',
      incidentId: incident,
      keyId: identity.keyId,
      publicKey: base64UrlEncode(identity.publicKey),
      createdAt: created,
      expiresAt: created.add(lifetime),
      signature: '',
      path: [identity.keyId],
      direct: direct,
    );
    final signature = await Ed25519().sign(
      utf8.encode(relayCanonicalJson(value.body)),
      keyPair: identity.keyPair,
    );
    return IncidentPresenceEnvelope(
      id: value.id,
      incidentId: incident,
      keyId: identity.keyId,
      publicKey: value.publicKey,
      createdAt: created,
      expiresAt: value.expiresAt,
      signature: base64UrlEncode(signature.bytes),
      path: value.path,
      direct: direct,
    );
  }
}
