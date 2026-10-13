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
    id: map['id'] as String? ?? '',
    name: map['name'] as String?,
    rssi: (map['rssi'] as num?)?.toInt(),
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
  });
  final String type;
  final BleDevice? device;
  final List<int>? payload;
  final String? error;
  final String? state;
  final BleSessionRole? role;

  factory BleEvent.fromMap(Map<Object?, Object?> map) => BleEvent(
    type: map['type'] as String? ?? 'unknown',
    device: map['device'] is Map
        ? BleDevice.fromMap(Map<Object?, Object?>.from(map['device'] as Map))
        : null,
    payload: map['payload'] is List
        ? List<int>.from(
            (map['payload'] as List).map((e) => (e as num).toInt()),
          )
        : null,
    error: map['error'] as String?,
    state: map['state'] as String?,
    role: BleSessionRole.fromWire(map['role']),
  );
}

class BleTransportException implements Exception {
  const BleTransportException(this.message);
  final String message;
  @override
  String toString() => 'BleTransportException: $message';
}
