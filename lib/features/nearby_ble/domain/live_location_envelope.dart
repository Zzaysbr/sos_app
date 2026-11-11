import 'dart:convert';

import 'relay_envelope.dart';
import '../data/ble_protocol.dart';

/// Signed participant location carried by the off-grid relay. The immutable
/// body is signed by the participant; relay hops only extend path metadata.
class LiveLocationEnvelope {
  const LiveLocationEnvelope({
    required this.messageId,
    required this.sosId,
    required this.participantId,
    required this.participantRole,
    required this.originKeyId,
    required this.originPublicKey,
    required this.originSignature,
    required this.sequence,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.expiresAt,
    this.accuracyMeters,
    this.hopCount = 0,
    this.pathKeyIds = const <String>[],
  });

  static const wireKind = 'location.live.v1';
  static const schemaVersion = 1;
  static const maxIdLength = 128;

  final String messageId;
  final String sosId;
  final String participantId;
  final String participantRole;
  final String originKeyId;
  final String originPublicKey;
  final String originSignature;
  final int sequence;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int hopCount;
  final List<String> pathKeyIds;

  Map<String, Object?> bodyMap() => {
    'schemaVersion': schemaVersion,
    'kind': wireKind,
    'sosId': sosId,
    'participantId': participantId,
    'participantRole': participantRole,
    'originKeyId': originKeyId,
    'originPublicKey': originPublicKey,
    'sequence': sequence,
    'latitude': latitude,
    'longitude': longitude,
    if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };

  Map<String, Object?> toJson() => {
    ...bodyMap(),
    'messageId': messageId,
    'originSignature': originSignature,
    'hopCount': hopCount,
    'pathKeyIds': pathKeyIds,
  };

  BleMessage toBleMessage() {
    validate();
    return BleMessage(
      id: messageId,
      type: wireKind,
      createdAt: createdAt,
      payload: toJson(),
    );
  }

  LiveLocationEnvelope copyWithHop({
    required String relayKeyId,
    required int nextHop,
  }) => LiveLocationEnvelope(
    messageId: messageId,
    sosId: sosId,
    participantId: participantId,
    participantRole: participantRole,
    originKeyId: originKeyId,
    originPublicKey: originPublicKey,
    originSignature: originSignature,
    sequence: sequence,
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: accuracyMeters,
    createdAt: createdAt,
    expiresAt: expiresAt,
    hopCount: nextHop,
    pathKeyIds: [...pathKeyIds, relayKeyId],
  );

  void validate({DateTime? now}) {
    _bounded(messageId, 'messageId');
    _bounded(sosId, 'sosId');
    _bounded(participantId, 'participantId');
    _bounded(participantRole, 'participantRole');
    _bounded(originKeyId, 'originKeyId');
    if (originPublicKey.isEmpty || originSignature.isEmpty) {
      throw const LiveLocationEnvelopeException('Missing location signature.');
    }
    if (!const {'victim', 'rescue'}.contains(participantRole)) {
      throw const LiveLocationEnvelopeException('Invalid participant role.');
    }
    if (now != null &&
        createdAt.isAfter(now.toUtc().add(const Duration(seconds: 30)))) {
      throw const LiveLocationEnvelopeException(
        'Location timestamp is in the future.',
      );
    }
    if (sequence < 0) {
      throw const LiveLocationEnvelopeException('Invalid location sequence.');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (latitude == 0 && longitude == 0)) {
      throw const LiveLocationEnvelopeException(
        'Invalid location coordinates.',
      );
    }
    if (accuracyMeters != null &&
        (!accuracyMeters!.isFinite || accuracyMeters! < 0)) {
      throw const LiveLocationEnvelopeException('Invalid location accuracy.');
    }
    if (!createdAt.isUtc || !expiresAt.isUtc || !expiresAt.isAfter(createdAt)) {
      throw const LiveLocationEnvelopeException('Invalid location timestamps.');
    }
    if (expiresAt.difference(createdAt) > RelayProtocolLimits.maximumLifetime) {
      throw const LiveLocationEnvelopeException('Location TTL is too long.');
    }
    if (now != null && !expiresAt.isAfter(now.toUtc())) {
      throw const LiveLocationEnvelopeException('Location update expired.');
    }
    if (hopCount < 0 ||
        hopCount > RelayProtocolLimits.maximumHops ||
        pathKeyIds.length != hopCount ||
        pathKeyIds.toSet().length != pathKeyIds.length) {
      throw const LiveLocationEnvelopeException('Invalid relay path.');
    }
  }

  factory LiveLocationEnvelope.fromJson(Map<String, Object?> json) {
    final value = LiveLocationEnvelope(
      messageId: _string(json, 'messageId'),
      sosId: _string(json, 'sosId'),
      participantId: _string(json, 'participantId'),
      participantRole: _string(json, 'participantRole'),
      originKeyId: _string(json, 'originKeyId'),
      originPublicKey: _string(json, 'originPublicKey'),
      originSignature: _string(json, 'originSignature'),
      sequence: _int(json, 'sequence'),
      latitude: _double(json, 'latitude'),
      longitude: _double(json, 'longitude'),
      accuracyMeters: json['accuracyMeters'] == null
          ? null
          : _double(json, 'accuracyMeters'),
      createdAt: _date(json, 'createdAt'),
      expiresAt: _date(json, 'expiresAt'),
      hopCount: _int(json, 'hopCount'),
      pathKeyIds:
          (json['pathKeyIds'] as List?)?.whereType<String>().toList() ??
          const <String>[],
    );
    if (json['schemaVersion'] != schemaVersion || json['kind'] != wireKind) {
      throw const LiveLocationEnvelopeException('Unsupported location schema.');
    }
    value.validate();
    return value;
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw LiveLocationEnvelopeException('Invalid $key.');
    }
    return value;
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw LiveLocationEnvelopeException('Invalid $key.');
    return value;
  }

  static double _double(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw LiveLocationEnvelopeException('Invalid $key.');
    }
    return value.toDouble();
  }

  static DateTime _date(Map<String, Object?> json, String key) {
    final value = json[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null || !parsed.isUtc) {
      throw LiveLocationEnvelopeException('Invalid $key.');
    }
    return parsed;
  }

  static void _bounded(String value, String key) {
    if (value.isEmpty || value.length > maxIdLength) {
      throw LiveLocationEnvelopeException('Invalid $key.');
    }
  }

  @override
  String toString() => jsonEncode(toJson());
}

class LiveLocationEnvelopeException implements Exception {
  const LiveLocationEnvelopeException(this.message);
  final String message;
  @override
  String toString() => 'LiveLocationEnvelopeException: $message';
}
