import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../data/relay_key_store.dart';

import 'relay_envelope.dart';
import 'media_manifest.dart';

/// Signed, immutable Chat payload for the Q-709 transport.
///
/// The text is authenticated but not end-to-end encrypted. Until an E2E key
/// agreement is added, relays can observe the payload; they cannot alter it or
/// rebind it to another incident/recipient without invalidating the signature.
class ChatRelayBody {
  ChatRelayBody({
    required this.messageId,
    required this.incidentId,
    required this.senderKeyId,
    required this.senderPublicKey,
    required this.recipientKeyId,
    required this.recipientPublicKey,
    required this.originIncidentBinding,
    required this.text,
    this.media,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) : createdAt = createdAt.toUtc(),
       expiresAt = expiresAt.toUtc() {
    validate();
  }

  static const schemaVersion = 1;
  static const wireKind = 'chat.relay.v1';
  static const maxTextLength = 4096;
  static const maxIdLength = 128;

  final String messageId;
  final String incidentId;
  final String senderKeyId;
  final String senderPublicKey;
  final String recipientKeyId;
  final String recipientPublicKey;
  final String originIncidentBinding;
  final String text;
  final MediaManifest? media;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toCanonicalMap() => {
    'schemaVersion': media == null ? schemaVersion : 2,
    'kind': wireKind,
    'messageId': messageId,
    'incidentId': incidentId,
    'senderKeyId': senderKeyId,
    'senderPublicKey': senderPublicKey,
    'recipientKeyId': recipientKeyId,
    'recipientPublicKey': recipientPublicKey,
    'originIncidentBinding': originIncidentBinding,
    'text': text,
    if (media != null) 'media': media!.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  String toCanonicalWire() => relayCanonicalJson(toCanonicalMap());

  factory ChatRelayBody.fromJson(Map<String, Object?> json) {
    final body = ChatRelayBody(
      messageId: _required(json, 'messageId'),
      incidentId: _required(json, 'incidentId'),
      senderKeyId: _required(json, 'senderKeyId'),
      senderPublicKey: _required(json, 'senderPublicKey'),
      recipientKeyId: _required(json, 'recipientKeyId'),
      recipientPublicKey: _required(json, 'recipientPublicKey'),
      originIncidentBinding: _required(json, 'originIncidentBinding'),
      text: _required(json, 'text'),
      media: json['schemaVersion'] == 2 && json['media'] is Map
          ? MediaManifest.fromJson(
              Map<String, Object?>.from(json['media'] as Map),
            )
          : null,
      createdAt: _date(json, 'createdAt'),
      expiresAt: _date(json, 'expiresAt'),
    );
    if ((json['schemaVersion'] != schemaVersion &&
            json['schemaVersion'] != 2) ||
        (json['schemaVersion'] == 2 && body.media == null) ||
        (json['schemaVersion'] == schemaVersion && json.containsKey('media')) ||
        json['kind'] != wireKind) {
      throw const FormatException('Unsupported Chat relay envelope version.');
    }
    return body;
  }

  void validate({DateTime? now, bool allowExpired = false}) {
    for (final value in [
      messageId,
      incidentId,
      senderKeyId,
      senderPublicKey,
      recipientKeyId,
      recipientPublicKey,
      originIncidentBinding,
    ]) {
      if (value.trim().isEmpty || value.length > maxIdLength * 4) {
        throw const FormatException('Invalid Chat relay identity field.');
      }
    }
    if (text.trim().isEmpty || text.length > maxTextLength) {
      throw const FormatException('Invalid Chat relay text.');
    }
    if (!expiresAt.isAfter(createdAt)) {
      throw const FormatException('Chat relay expiry must be after creation.');
    }
    if (expiresAt.difference(createdAt) > const Duration(minutes: 30)) {
      throw const FormatException('Chat relay lifetime is too long.');
    }
    if (!allowExpired && now != null && !expiresAt.isAfter(now.toUtc())) {
      throw const FormatException('Chat relay envelope has expired.');
    }
  }

  static String _required(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('Missing Chat field: $key');
    }
    return value;
  }

  static DateTime _date(Map<String, Object?> json, String key) {
    final value = _required(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid Chat date: $key');
    return parsed.toUtc();
  }
}

class ChatRelayEnvelope {
  ChatRelayEnvelope({required this.body, required this.signature}) {
    body.validate();
    if (base64Url.decode(base64Url.normalize(signature)).length != 64) {
      throw const FormatException('Invalid Chat relay signature.');
    }
  }

  final ChatRelayBody body;
  final String signature;

  Map<String, Object?> toJson() => {
    ...body.toCanonicalMap(),
    'signature': signature,
  };

  String toCanonicalWire() => relayCanonicalJson(toJson());

  factory ChatRelayEnvelope.fromCanonicalWire(String wire) {
    final decoded = jsonDecode(wire);
    if (decoded is! Map) {
      throw const FormatException('Chat envelope is not an object.');
    }
    final json = Map<String, Object?>.from(decoded);
    final signature = json['signature'];
    if (signature is! String) {
      throw const FormatException('Chat envelope signature is missing.');
    }
    json.remove('signature');
    return ChatRelayEnvelope(
      body: ChatRelayBody.fromJson(json),
      signature: signature,
    );
  }
}

class ChatRelayTransfer {
  ChatRelayTransfer({
    required this.attemptId,
    required this.wireEnvelope,
    required this.hopCount,
    this.maxHops = 3,
    this.hops = const [],
    this.wireRescueOffer,
    this.sessionBinding = '',
  });

  static const wireKind = 'chat.relay.transfer.v1';
  final String attemptId;
  final String wireEnvelope;
  final int hopCount;
  final int maxHops;
  final List<Map<String, Object?>> hops;
  final String? wireRescueOffer;
  final String sessionBinding;

  Map<String, Object?> toJson() => {
    'kind': wireKind,
    'attemptId': attemptId,
    'wireEnvelope': wireEnvelope,
    'hopCount': hopCount,
    'maxHops': maxHops,
    'hops': hops,
    'wireRescueOffer': wireRescueOffer,
    'sessionBinding': sessionBinding,
  };

  factory ChatRelayTransfer.fromJson(Map<String, Object?> json) {
    if (json['kind'] != wireKind ||
        json['attemptId'] is! String ||
        json['wireEnvelope'] is! String ||
        json['hopCount'] is! int ||
        json['maxHops'] is! int) {
      throw const FormatException('Invalid Chat relay transfer.');
    }
    final transfer = ChatRelayTransfer(
      attemptId: json['attemptId'] as String,
      wireEnvelope: json['wireEnvelope'] as String,
      hopCount: json['hopCount'] as int,
      maxHops: json['maxHops'] as int,
      hops: (json['hops'] as List? ?? const [])
          .map((h) => Map<String, Object?>.from(h as Map))
          .toList(),
      wireRescueOffer: json['wireRescueOffer'] as String?,
      sessionBinding: json['sessionBinding'] as String? ?? '',
    );
    if (transfer.attemptId.trim().isEmpty ||
        transfer.hopCount < 0 ||
        transfer.maxHops < 1 ||
        transfer.maxHops > 3 ||
        transfer.hopCount >= transfer.maxHops) {
      throw const FormatException('Chat relay hop limit reached.');
    }
    return transfer;
  }

  List<String> get path => hops.map((h) => h['senderKeyId'] as String).toList();

  Future<String> _chainDigest(List<Map<String, Object?>> prefix) async =>
      base64UrlEncode(
        (await Sha256().hash(
          utf8.encode(
            relayCanonicalJson({
              'domain': 'off-grid-sos/chat-hop-chain/v1',
              'wireEnvelope': wireEnvelope,
              'wireRescueOffer': wireRescueOffer,
              'maxHops': maxHops,
              'hops': prefix,
            }),
          ),
        )).bytes,
      );

  /// Append a signed hop without changing the original message or prior hops.
  Future<ChatRelayTransfer> forNextHop({
    required RelaySigningIdentity identity,
    required String nextHopKeyId,
    required String binding,
  }) async {
    if (hops.length >= maxHops ||
        path.contains(identity.keyId) ||
        path.contains(nextHopKeyId) ||
        identity.keyId == nextHopKeyId ||
        binding.isEmpty) {
      throw const FormatException('Chat relay path exhausted or looped.');
    }
    final unsigned = <String, Object?>{
      'kind': 'chat.relay.hop.v1',
      'senderKeyId': identity.keyId,
      'senderPublicKey': base64UrlEncode(identity.publicKey),
      'nextHopKeyId': nextHopKeyId,
      'sessionBinding': binding,
      'previousDigest': await _chainDigest(hops),
    };
    final signature = await Ed25519().sign(
      utf8.encode(relayCanonicalJson(unsigned)),
      keyPair: identity.keyPair,
    );
    return ChatRelayTransfer(
      attemptId:
          'chat:${ChatRelayEnvelope.fromCanonicalWire(wireEnvelope).body.messageId}:$nextHopKeyId',
      wireEnvelope: wireEnvelope,
      hopCount: hops.length,
      maxHops: maxHops,
      wireRescueOffer: wireRescueOffer,
      sessionBinding: binding,
      hops: [
        ...hops,
        {...unsigned, 'signature': base64UrlEncode(signature.bytes)},
      ],
    );
  }

  Future<bool> verifyPath({
    required String immediateKeyId,
    required String immediatePublicKey,
    required String localKeyId,
  }) async {
    if (hops.isEmpty ||
        hops.length != hopCount + 1 ||
        hops.length > maxHops ||
        maxHops > 3 ||
        wireRescueOffer == null ||
        sessionBinding.isEmpty) {
      return false;
    }
    final keys = path;
    final body = ChatRelayEnvelope.fromCanonicalWire(wireEnvelope).body;
    if (keys.first != body.senderKeyId ||
        keys.last != immediateKeyId ||
        keys.contains(localKeyId) ||
        keys.toSet().length != keys.length ||
        hops.last['senderPublicKey'] != immediatePublicKey ||
        hops.last['sessionBinding'] != sessionBinding) {
      return false;
    }
    for (var i = 0; i < hops.length; i++) {
      final h = Map<String, Object?>.from(hops[i]);
      final signature = h.remove('signature');
      if (h['kind'] != 'chat.relay.hop.v1' ||
          h['senderPublicKey'] is! String ||
          signature is! String ||
          h['sessionBinding'] is! String ||
          (h['sessionBinding'] as String).isEmpty ||
          h['nextHopKeyId'] !=
              (i + 1 < keys.length ? keys[i + 1] : localKeyId) ||
          h['previousDigest'] != await _chainDigest(hops.take(i).toList())) {
        return false;
      }
      final public = base64Url.decode(
        base64Url.normalize(h['senderPublicKey'] as String),
      );
      if (public.length != 32 ||
          await RelayCryptography().publicKeyId(public) != keys[i] ||
          !await Ed25519().verify(
            utf8.encode(relayCanonicalJson(h)),
            signature: Signature(
              base64Url.decode(base64Url.normalize(signature)),
              publicKey: SimplePublicKey(public, type: KeyPairType.ed25519),
            ),
          )) {
        return false;
      }
    }
    return true;
  }
}
