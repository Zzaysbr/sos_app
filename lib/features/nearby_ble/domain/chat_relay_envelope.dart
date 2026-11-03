import 'dart:convert';

import 'relay_envelope.dart';

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
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toCanonicalMap() => {
    'schemaVersion': schemaVersion,
    'kind': wireKind,
    'messageId': messageId,
    'incidentId': incidentId,
    'senderKeyId': senderKeyId,
    'senderPublicKey': senderPublicKey,
    'recipientKeyId': recipientKeyId,
    'recipientPublicKey': recipientPublicKey,
    'originIncidentBinding': originIncidentBinding,
    'text': text,
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
      createdAt: _date(json, 'createdAt'),
      expiresAt: _date(json, 'expiresAt'),
    );
    if (json['schemaVersion'] != schemaVersion || json['kind'] != wireKind) {
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
  });

  static const wireKind = 'chat.relay.transfer.v1';
  final String attemptId;
  final String wireEnvelope;
  final int hopCount;
  final int maxHops;

  Map<String, Object?> toJson() => {
    'kind': wireKind,
    'attemptId': attemptId,
    'wireEnvelope': wireEnvelope,
    'hopCount': hopCount,
    'maxHops': maxHops,
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
    );
    if (transfer.attemptId.trim().isEmpty ||
        transfer.hopCount < 0 ||
        transfer.maxHops < 1 ||
        transfer.hopCount >= transfer.maxHops) {
      throw const FormatException('Chat relay hop limit reached.');
    }
    return transfer;
  }
}
