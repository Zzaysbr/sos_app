import '../data/ble_protocol.dart';

/// Location sharing messages carried by the existing framed BLE transport.
/// This is a separate envelope so SOS and Chat ACK validation cannot cross over.
class LocationBleEnvelope {
  const LocationBleEnvelope.update({
    required this.messageId,
    required this.sosId,
    required this.senderDeviceId,
    required this.recipientId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.expiresAt,
    this.accuracyMeters,
  }) : kind = 'location.update',
       ackFor = null,
       ackStatus = null,
       error = null;

  const LocationBleEnvelope.ack({
    required this.messageId,
    required this.sosId,
    required this.ackFor,
    required this.ackStatus,
    required this.createdAt,
    this.senderDeviceId,
    this.error,
  }) : kind = 'location.ack',
       recipientId = null,
       latitude = null,
       longitude = null,
       accuracyMeters = null,
       expiresAt = null;

  final String kind;
  final String messageId;
  final String sosId;
  final String? senderDeviceId;
  final String? recipientId;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? ackFor;
  final String? ackStatus;
  final String? error;

  static const schemaVersion = 1;
  static const maxIdLength = 128;

  BleMessage toBleMessage() {
    validate();
    return BleMessage(
      id: messageId,
      type: kind,
      createdAt: createdAt,
      payload: toJson(),
    );
  }

  Map<String, Object?> toJson() {
    validate();
    final json = <String, Object?>{
      'schemaVersion': schemaVersion,
      'kind': kind,
      'messageId': messageId,
      'sosId': sosId,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
    if (senderDeviceId != null) json['senderDeviceId'] = senderDeviceId;
    if (kind == 'location.update') {
      json.addAll({
        'recipientId': recipientId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'expiresAt': expiresAt!.toUtc().toIso8601String(),
      });
    } else {
      json.addAll({'ackFor': ackFor, 'ackStatus': ackStatus});
      if (error != null) json['error'] = error;
    }
    return json;
  }

  factory LocationBleEnvelope.fromBleMessage(BleMessage message) {
    if (message.type != message.payload['kind'] ||
        message.payload['kind'] != 'location.update' &&
            message.payload['kind'] != 'location.ack') {
      throw const LocationBleEnvelopeException(
        'Invalid location message kind.',
      );
    }
    final json = message.payload;
    if (json['schemaVersion'] != schemaVersion ||
        json['messageId'] != message.id ||
        _date(json['createdAt']) != message.createdAt.toUtc()) {
      throw const LocationBleEnvelopeException('Invalid location metadata.');
    }
    final envelope = json['kind'] == 'location.update'
        ? LocationBleEnvelope.update(
            messageId: _requiredString(json, 'messageId'),
            sosId: _requiredString(json, 'sosId'),
            senderDeviceId: _optionalString(json, 'senderDeviceId'),
            recipientId: _requiredString(json, 'recipientId'),
            latitude: _requiredDouble(json, 'latitude'),
            longitude: _requiredDouble(json, 'longitude'),
            accuracyMeters: _optionalDouble(json, 'accuracyMeters'),
            createdAt: _date(json['createdAt']),
            expiresAt: _date(json['expiresAt']),
          )
        : LocationBleEnvelope.ack(
            messageId: _requiredString(json, 'messageId'),
            sosId: _requiredString(json, 'sosId'),
            senderDeviceId: _optionalString(json, 'senderDeviceId'),
            ackFor: _requiredString(json, 'ackFor'),
            ackStatus: _requiredString(json, 'ackStatus'),
            createdAt: _date(json['createdAt']),
            error: _optionalString(json, 'error'),
          );
    return envelope;
  }

  void validate({DateTime? now}) {
    _bounded(messageId, 'messageId');
    _bounded(sosId, 'sosId');
    _optionalBounded(senderDeviceId, 'senderDeviceId');
    if (!createdAt.isUtc) {
      throw const LocationBleEnvelopeException('createdAt must be UTC.');
    }
    if (kind == 'location.update') {
      _bounded(recipientId, 'recipientId');
      if (latitude == null ||
          longitude == null ||
          !latitude!.isFinite ||
          !longitude!.isFinite ||
          latitude! < -90 ||
          latitude! > 90 ||
          longitude! < -180 ||
          longitude! > 180 ||
          (latitude == 0 && longitude == 0)) {
        throw const LocationBleEnvelopeException(
          'Invalid location coordinates.',
        );
      }
      if (accuracyMeters != null &&
          (!accuracyMeters!.isFinite || accuracyMeters! < 0)) {
        throw const LocationBleEnvelopeException('Invalid location accuracy.');
      }
      if (expiresAt == null ||
          !expiresAt!.isUtc ||
          !expiresAt!.isAfter(createdAt)) {
        throw const LocationBleEnvelopeException(
          'Invalid location expiration.',
        );
      }
      if (now != null && !expiresAt!.isAfter(now.toUtc())) {
        throw const LocationBleEnvelopeException(
          'Location update has expired.',
        );
      }
    } else {
      _bounded(ackFor, 'ackFor');
      if (ackStatus != 'persisted' && ackStatus != 'rejected') {
        throw const LocationBleEnvelopeException(
          'Invalid location ACK status.',
        );
      }
    }
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw LocationBleEnvelopeException('Missing or invalid $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw LocationBleEnvelopeException('Invalid $key.');
    return value;
  }

  static double _requiredDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num || !value.toDouble().isFinite) {
      throw LocationBleEnvelopeException('Missing or invalid $key.');
    }
    return value.toDouble();
  }

  static double? _optionalDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num || !value.toDouble().isFinite) {
      throw LocationBleEnvelopeException('Invalid $key.');
    }
    return value.toDouble();
  }

  static DateTime _date(Object? value) {
    if (value is! String) {
      throw const LocationBleEnvelopeException('Invalid timestamp.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc) {
      throw const LocationBleEnvelopeException('Invalid timestamp.');
    }
    return parsed;
  }

  static void _bounded(String? value, String key) {
    if (value == null || value.isEmpty || value.length > maxIdLength) {
      throw LocationBleEnvelopeException('Invalid $key.');
    }
  }

  static void _optionalBounded(String? value, String key) {
    if (value != null && (value.isEmpty || value.length > maxIdLength)) {
      throw LocationBleEnvelopeException('Invalid $key.');
    }
  }
}

class LocationBleEnvelopeException implements Exception {
  const LocationBleEnvelopeException(this.message);
  final String message;
  @override
  String toString() => 'LocationBleEnvelopeException: $message';
}
