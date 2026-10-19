enum BleTransportState {
  unsupported,
  unauthorized,
  poweredOff,
  idle,
  advertising,
  discovering,
  connecting,
  connected,
  error,
}

enum BleSessionRole {
  central('central'),
  peripheral('peripheral');

  const BleSessionRole(this.wireValue);

  final String wireValue;

  static BleSessionRole? fromWire(Object? value) {
    for (final role in values) {
      if (role.wireValue == value) return role;
    }
    return null;
  }
}

class BleDevice {
  const BleDevice({required this.id, this.name, this.rssi});
  final String id;
  final String? name;
  final int? rssi;

  factory BleDevice.fromMap(Map<Object?, Object?> map) => BleDevice(
    id: map['id'] is String ? map['id'] as String : '',
    name: map['name'] is String ? map['name'] as String : null,
    rssi: map['rssi'] is num ? (map['rssi'] as num).toInt() : null,
  );
}

class BleEvent {
  const BleEvent({
    required this.type,
    this.device,
    this.payload,
    this.error,
    this.state,
    this.role,
    this.scanSession,
    this.attempt,
  });
  final String type;
  final BleDevice? device;
  final List<int>? payload;
  final String? error;
  final String? state;
  final BleSessionRole? role;
  final int? scanSession;
  final int? attempt;

  factory BleEvent.fromMap(Map<Object?, Object?> map) => BleEvent(
    type: map['type'] is String ? map['type'] as String : 'unknown',
    device: map['device'] is Map
        ? BleDevice.fromMap(Map<Object?, Object?>.from(map['device'] as Map))
        : null,
    payload: _payloadFrom(map['payload']),
    error: map['error'] is String ? map['error'] as String : null,
    state: map['state'] is String ? map['state'] as String : null,
    role: BleSessionRole.fromWire(map['role']),
    scanSession: _intFrom(map['scanSession']),
    attempt: _intFrom(map['attempt']),
  );

  static int? _intFrom(Object? value) => value is num ? value.toInt() : null;

  static List<int>? _payloadFrom(Object? value) {
    if (value is! List || value.any((item) => item is! num)) return null;
    return value.map((item) => (item as num).toInt()).toList(growable: false);
  }
}

class BleTransportException implements Exception {
  const BleTransportException(this.message);
  final String message;
  @override
  String toString() => 'BleTransportException: $message';
}
