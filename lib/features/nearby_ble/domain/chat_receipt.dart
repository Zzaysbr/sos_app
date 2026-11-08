import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../data/relay_key_store.dart';
import 'chat_relay_envelope.dart';
import 'relay_envelope.dart';

/// Durable machine persistence evidence, not a read/human acceptance receipt.
class ChatReceipt {
  ChatReceipt(this.body, this.signature);
  static const wireKind = 'chat.receipt.v1';
  static const transferKind = 'chat.receipt.transfer.v1';
  static const grace = Duration(minutes: 30);
  final Map<String, Object?> body;
  final String signature;
  String get messageId => body['messageId'] as String;
  DateTime get expiresAt => DateTime.parse(body['expiresAt'] as String).toUtc();
  Map<String, Object?> toJson() => {'body': body, 'signature': signature};
  String toWire() => relayCanonicalJson(toJson());
  factory ChatReceipt.fromWire(String wire) {
    final j = jsonDecode(wire) as Map<String, dynamic>;
    if (j.length != 2 || j['body'] is! Map || j['signature'] is! String) {
      throw const FormatException('Invalid Chat receipt.');
    }
    return ChatReceipt(
      Map<String, Object?>.from(j['body'] as Map),
      j['signature'] as String,
    );
  }
  static Future<String> digest(ChatRelayEnvelope e) async => base64UrlEncode(
    (await Sha256().hash(utf8.encode(e.toCanonicalWire()))).bytes,
  );
  static Future<ChatReceipt> sign(
    ChatRelayEnvelope e,
    RelaySigningIdentity identity,
    DateTime persistedAt,
  ) async {
    if (identity.keyId != e.body.recipientKeyId) {
      throw const FormatException('Receipt signer is not recipient.');
    }
    final body = <String, Object?>{
      'kind': wireKind,
      'version': 1,
      'messageId': e.body.messageId,
      'incidentId': e.body.incidentId,
      'digest': await digest(e),
      'senderKeyId': e.body.senderKeyId,
      'recipientKeyId': identity.keyId,
      'persistedAt': persistedAt.toUtc().toIso8601String(),
      'expiresAt': e.body.expiresAt.add(grace).toIso8601String(),
    };
    final signature = await Ed25519().sign(
      utf8.encode(relayCanonicalJson(body)),
      keyPair: identity.keyPair,
    );
    return ChatReceipt(body, base64UrlEncode(signature.bytes));
  }

  Future<void> verify(ChatRelayEnvelope e, DateTime now) async {
    final expected = {
      'kind',
      'version',
      'messageId',
      'incidentId',
      'digest',
      'senderKeyId',
      'recipientKeyId',
      'persistedAt',
      'expiresAt',
    };
    if (body.length != expected.length ||
        !body.keys.toSet().containsAll(expected) ||
        body['kind'] != wireKind ||
        body['version'] != 1 ||
        messageId != e.body.messageId ||
        body['incidentId'] != e.body.incidentId ||
        body['digest'] != await digest(e) ||
        body['senderKeyId'] != e.body.senderKeyId ||
        body['recipientKeyId'] != e.body.recipientKeyId ||
        expiresAt != e.body.expiresAt.add(grace) ||
        !expiresAt.isAfter(now.toUtc())) {
      throw const FormatException('Chat receipt binding/expiry invalid.');
    }
    final persisted = DateTime.parse(body['persistedAt'] as String).toUtc();
    if (persisted.isBefore(
          e.body.createdAt.subtract(const Duration(minutes: 2)),
        ) ||
        !persisted.isBefore(e.body.expiresAt) ||
        persisted.isAfter(now.toUtc().add(const Duration(minutes: 2)))) {
      throw const FormatException('Chat receipt persistence time invalid.');
    }
    final crypto = RelayCryptography();
    if (!await crypto.verifyChatRelay(e, now: e.body.createdAt) ||
        !await crypto.publicKeyMatchesId(
          e.body.recipientPublicKey,
          e.body.recipientKeyId,
        ) ||
        !await Ed25519().verify(
          utf8.encode(relayCanonicalJson(body)),
          signature: Signature(
            base64Url.decode(base64Url.normalize(signature)),
            publicKey: SimplePublicKey(
              base64Url.decode(base64Url.normalize(e.body.recipientPublicKey)),
              type: KeyPairType.ed25519,
            ),
          ),
        )) {
      throw const FormatException('Chat receipt signature invalid.');
    }
  }
}
