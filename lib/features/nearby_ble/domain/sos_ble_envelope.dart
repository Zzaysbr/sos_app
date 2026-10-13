import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../data/ble_protocol.dart';

/// Logical messages carried by the existing BLE transport.
enum SosBleMessageKind {
  delivery('sos.delivery'),
  acknowledgement('sos.ack'),
  chatMessage('chat.message'),
  chatAcknowledgement('chat.ack');

  const SosBleMessageKind(this.wireValue);

  final String wireValue;

  static SosBleMessageKind parse(Object? value) {
    for (final kind in values) {
      if (kind.wireValue == value) return kind;
    }
    throw const SosBleEnvelopeException('Unsupported SOS message kind.');
  }
}

enum SosBleAckStatus {
  persisted('persisted'),
  rejected('rejected');

  const SosBleAckStatus(this.wireValue);

  final String wireValue;

  static SosBleAckStatus parse(Object? value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    throw const SosBleEnvelopeException('Unsupported acknowledgement status.');
  }
}

/// Versioned SOS application envelope carried inside the existing BleMessage.
///
/// `messageId` identifies one logical transport message and must be reused for
/// retries. `sosId` identifies the SOS record/event itself. `senderDeviceId`
/// is informational only; it is not an authenticated identity.
class SosBleEnvelope {
  SosBleEnvelope.delivery({
    required this.messageId,
    required this.sosId,
    required this.sosType,
    required this.status,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.message,
    this.latitude,
    this.longitude,
    this.senderDeviceId,
  }) : kind = SosBleMessageKind.delivery,
       ackFor = null,
       ackStatus = null,
       error = null,
       chatSenderId = null,
       chatText = null,
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    validate();
  }

  SosBleEnvelope.acknowledgement({
    required this.messageId,
    required this.sosId,
    required this.ackFor,
    required this.ackStatus,
    required DateTime createdAt,
    this.senderDeviceId,
    this.error,
  }) : kind = SosBleMessageKind.acknowledgement,
       chatSenderId = null,
       chatText = null,
       sosType = null,
       status = null,
       message = null,
       latitude = null,
       longitude = null,
       updatedAt = null,
       createdAt = createdAt.toUtc() {
    validate();
  }

  SosBleEnvelope.chatMessage({
    required this.messageId,
    required this.sosId,
    required this.senderDeviceId,
    required this.chatSenderId,
    required this.chatText,
    required DateTime createdAt,
  }) : kind = SosBleMessageKind.chatMessage,
       ackFor = null,
       ackStatus = null,
       error = null,
       sosType = null,
       status = null,
       message = null,
       latitude = null,
       longitude = null,
       updatedAt = null,
       createdAt = createdAt.toUtc() {
    validate();
  }

  SosBleEnvelope.chatAcknowledgement({
    required this.messageId,
    required this.sosId,
    required this.ackFor,
    required this.ackStatus,
    required DateTime createdAt,
    this.senderDeviceId,
    this.error,
  }) : kind = SosBleMessageKind.chatAcknowledgement,
       chatSenderId = null,
       chatText = null,
       sosType = null,
       status = null,
       message = null,
       latitude = null,
       longitude = null,
       updatedAt = null,
       createdAt = createdAt.toUtc() {
    validate();
  }

  static const schemaVersion = 1;
  static const maxPayloadBytes = 16 * 1024;
  static const maxIdLength = 128;
  static const maxTypeLength = 64;
  static const maxStatusLength = 32;
  static const maxMessageLength = 4096;

  final SosBleMessageKind kind;
  final String messageId;
  final String sosId;
  final String? senderDeviceId;
  final String? sosType;
  final String? status;
  final String? message;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? ackFor;
  final SosBleAckStatus? ackStatus;
  final String? error;
  final String? chatSenderId;
  final String? chatText;

  factory SosBleEnvelope.fromSosMessage(
    SosMessage sos, {
    required String messageId,
    String? senderDeviceId,
  }) {
    return SosBleEnvelope.delivery(
      messageId: messageId,
      sosId: sos.id,
      senderDeviceId: senderDeviceId,
      sosType: sos.type,
      status: sos.status,
      message: sos.message,
      latitude: sos.latitude,
      longitude: sos.longitude,
      createdAt: sos.createdAt,
      updatedAt: sos.updatedAt,
    );
  }

  /// Maps a delivery to the existing Drift schema for a future receiver.
  /// Transport metadata such as messageId is intentionally not persisted here;
  /// a delivery table will own that state in a later phase.
  SosMessagesCompanion toSosCompanion({
    required String ownerId,
    String syncState = 'pending',
  }) {
    _requireKind(SosBleMessageKind.delivery);
    return SosMessagesCompanion.insert(
      id: sosId,
      ownerId: ownerId,
      type: sosType!,
      message: Value(message),
      latitude: Value(latitude),
      longitude: Value(longitude),
      status: status!,
      syncState: syncState,
      createdAt: createdAt,
      updatedAt: updatedAt!,
    );
  }

  BleMessage toBleMessage() {
    validate();
    return BleMessage(
      id: messageId,
      type: kind.wireValue,
      createdAt: createdAt,
      payload: toJson(),
    );
  }

  factory SosBleEnvelope.fromBleMessage(BleMessage message) {
    if (message.type != message.payload['kind']) {
      throw const SosBleEnvelopeException('Message kind does not match type.');
    }
    final envelope = SosBleEnvelope.fromJson(message.payload);
    if (envelope.messageId != message.id ||
        envelope.createdAt.toUtc() != message.createdAt.toUtc()) {
      throw const SosBleEnvelopeException('Transport metadata does not match.');
    }
    return envelope;
  }

  factory SosBleEnvelope.fromJsonString(String json) {
    try {
      final value = jsonDecode(json);
      if (value is! Map) {
        throw const SosBleEnvelopeException('SOS envelope must be an object.');
      }
      return SosBleEnvelope.fromJson(Map<String, Object?>.from(value));
    } on SosBleEnvelopeException {
      rethrow;
    } on FormatException catch (error) {
      throw SosBleEnvelopeException('Invalid SOS envelope JSON: $error');
    } on TypeError catch (error) {
      throw SosBleEnvelopeException('Invalid SOS envelope fields: $error');
    }
  }

  factory SosBleEnvelope.fromJson(Map<String, Object?> json) {
    try {
      if (json['schemaVersion'] != schemaVersion) {
        throw const SosBleEnvelopeException('Unsupported SOS schema version.');
      }
      final kind = SosBleMessageKind.parse(json['kind']);
      final envelope = switch (kind) {
        SosBleMessageKind.delivery => SosBleEnvelope.delivery(
          messageId: _requiredString(json, 'messageId'),
          sosId: _requiredString(json, 'sosId'),
          senderDeviceId: _optionalString(json, 'senderDeviceId'),
          sosType: _requiredString(json, 'type'),
          status: _requiredString(json, 'status'),
          message: _optionalString(json, 'message'),
          latitude: _optionalDouble(json, 'latitude'),
          longitude: _optionalDouble(json, 'longitude'),
          createdAt: _requiredDate(json, 'createdAt'),
          updatedAt: _requiredDate(json, 'updatedAt'),
        ),
        SosBleMessageKind.acknowledgement => SosBleEnvelope.acknowledgement(
          messageId: _requiredString(json, 'messageId'),
          sosId: _requiredString(json, 'sosId'),
          senderDeviceId: _optionalString(json, 'senderDeviceId'),
          ackFor: _requiredString(json, 'ackFor'),
          ackStatus: SosBleAckStatus.parse(json['ackStatus']),
          error: _optionalString(json, 'error'),
          createdAt: _requiredDate(json, 'createdAt'),
        ),
        SosBleMessageKind.chatMessage => SosBleEnvelope.chatMessage(
          messageId: _requiredString(json, 'messageId'),
          sosId: _requiredString(json, 'sosId'),
          senderDeviceId: _requiredString(json, 'senderDeviceId'),
          chatSenderId: _requiredString(json, 'senderId'),
          chatText: _requiredString(json, 'text'),
          createdAt: _requiredDate(json, 'createdAt'),
        ),
        SosBleMessageKind.chatAcknowledgement =>
          SosBleEnvelope.chatAcknowledgement(
            messageId: _requiredString(json, 'messageId'),
            sosId: _requiredString(json, 'sosId'),
            senderDeviceId: _optionalString(json, 'senderDeviceId'),
            ackFor: _requiredString(json, 'ackFor'),
            ackStatus: SosBleAckStatus.parse(json['ackStatus']),
            error: _optionalString(json, 'error'),
            createdAt: _requiredDate(json, 'createdAt'),
          ),
      };
      return envelope;
    } on SosBleEnvelopeException {
      rethrow;
    } on FormatException catch (error) {
      throw SosBleEnvelopeException('Invalid SOS envelope: $error');
    } on TypeError catch (error) {
      throw SosBleEnvelopeException('Invalid SOS envelope fields: $error');
    }
  }

  Map<String, Object?> toJson() {
    validate();
    final json = <String, Object?>{
      'schemaVersion': schemaVersion,
      'kind': kind.wireValue,
      'messageId': messageId,
      'sosId': sosId,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
    if (senderDeviceId != null) json['senderDeviceId'] = senderDeviceId;
    if (kind == SosBleMessageKind.delivery) {
      json.addAll({
        'type': sosType,
        'status': status,
        'message': message,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': updatedAt!.toUtc().toIso8601String(),
      });
    } else if (kind == SosBleMessageKind.acknowledgement ||
        kind == SosBleMessageKind.chatAcknowledgement) {
      json['ackFor'] = ackFor;
      json['ackStatus'] = ackStatus!.wireValue;
      if (error != null) json['error'] = error;
    } else {
      json.addAll({'senderId': chatSenderId, 'text': chatText});
    }
    final bytes = utf8.encode(jsonEncode(json));
    if (bytes.length > maxPayloadBytes) {
      throw const SosBleEnvelopeException('SOS envelope payload is too large.');
    }
    return json;
  }

  void validate() {
    _nonEmptyBounded(messageId, 'messageId', maxIdLength);
    _nonEmptyBounded(sosId, 'sosId', maxIdLength);
    _optionalBounded(senderDeviceId, 'senderDeviceId', maxIdLength);
    _validDate(createdAt, 'createdAt');
    if (kind == SosBleMessageKind.delivery) {
      _nonEmptyBounded(sosType, 'type', maxTypeLength);
      _nonEmptyBounded(status, 'status', maxStatusLength);
      if (!{'active', 'resolved', 'cancelled'}.contains(status)) {
        throw const SosBleEnvelopeException('Unsupported SOS status.');
      }
      if (message != null && message!.length > maxMessageLength) {
        throw const SosBleEnvelopeException('SOS message is too long.');
      }
      _coordinates(latitude, longitude);
      if (updatedAt == null) {
        throw const SosBleEnvelopeException('Missing updatedAt.');
      }
      _validDate(updatedAt!, 'updatedAt');
    } else if (kind == SosBleMessageKind.acknowledgement ||
        kind == SosBleMessageKind.chatAcknowledgement) {
      _nonEmptyBounded(ackFor, 'ackFor', maxIdLength);
      if (ackStatus == null) {
        throw const SosBleEnvelopeException('Missing acknowledgement status.');
      }
      if (error != null && error!.length > maxMessageLength) {
        throw const SosBleEnvelopeException(
          'Acknowledgement error is too long.',
        );
      }
    } else {
      _nonEmptyBounded(chatSenderId, 'senderId', maxIdLength);
      if (chatText == null ||
          chatText!.isEmpty ||
          chatText!.length > maxMessageLength) {
        throw const SosBleEnvelopeException('Invalid chat text.');
      }
    }
  }

  void _requireKind(SosBleMessageKind expected) {
    if (kind != expected) {
      throw const SosBleEnvelopeException(
        'Only SOS deliveries map to SOS rows.',
      );
    }
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw SosBleEnvelopeException('Missing or invalid $key.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw SosBleEnvelopeException('Invalid $key.');
    return value;
  }

  static double? _optionalDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! num) throw SosBleEnvelopeException('Invalid $key.');
    final result = value.toDouble();
    if (!result.isFinite) throw SosBleEnvelopeException('Invalid $key.');
    return result;
  }

  static DateTime _requiredDate(Map<String, Object?> json, String key) {
    final value = _requiredString(json, key);
    try {
      return DateTime.parse(value).toUtc();
    } on FormatException {
      throw SosBleEnvelopeException('Invalid $key.');
    }
  }

  static void _nonEmptyBounded(String? value, String key, int maxLength) {
    if (value == null || value.isEmpty || value.length > maxLength) {
      throw SosBleEnvelopeException('Invalid $key.');
    }
  }

  static void _optionalBounded(String? value, String key, int maxLength) {
    if (value != null && (value.isEmpty || value.length > maxLength)) {
      throw SosBleEnvelopeException('Invalid $key.');
    }
  }

  static void _validDate(DateTime value, String key) {
    if (!value.isUtc) {
      throw SosBleEnvelopeException('$key must be UTC.');
    }
  }

  static void _coordinates(double? latitude, double? longitude) {
    if ((latitude == null) != (longitude == null)) {
      throw const SosBleEnvelopeException(
        'Latitude and longitude must be provided together.',
      );
    }
    if (latitude != null &&
        (!latitude.isFinite || latitude < -90 || latitude > 90)) {
      throw const SosBleEnvelopeException('Invalid latitude.');
    }
    if (longitude != null &&
        (!longitude.isFinite || longitude < -180 || longitude > 180)) {
      throw const SosBleEnvelopeException('Invalid longitude.');
    }
  }
}

class SosBleEnvelopeException implements Exception {
  const SosBleEnvelopeException(this.message);

  final String message;

  @override
  String toString() => 'SosBleEnvelopeException: $message';
}
