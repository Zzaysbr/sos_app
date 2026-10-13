enum BleOutboxState {
  queued('queued'),
  sending('sending'),
  writeAccepted('writeAccepted'),
  awaitingAcknowledgement('awaitingAcknowledgement'),
  acknowledged('acknowledged'),
  failed('failed'),
  expired('expired');

  const BleOutboxState(this.wireValue);

  final String wireValue;

  static BleOutboxState parse(String value) => values.firstWhere(
    (state) => state.wireValue == value,
    orElse: () => throw ArgumentError('Unknown BLE outbox state: $value'),
  );
}

enum BleInboxState {
  received('received'),
  persisted('persisted'),
  rejected('rejected');

  const BleInboxState(this.wireValue);

  final String wireValue;

  static BleInboxState parse(String value) => values.firstWhere(
    (state) => state.wireValue == value,
    orElse: () => throw ArgumentError('Unknown BLE inbox state: $value'),
  );
}

/// A write accepted by GATT is deliberately distinct from remote persistence.
enum BleAcknowledgementStatus {
  persisted('persisted'),
  rejected('rejected');

  const BleAcknowledgementStatus(this.wireValue);

  final String wireValue;
}

class BleDeliveryStateException implements Exception {
  const BleDeliveryStateException(this.message);

  final String message;

  @override
  String toString() => 'BleDeliveryStateException: $message';
}
