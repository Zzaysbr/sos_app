import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Source contracts complement native compilation. They do not simulate ATT
// confirmation, firmware behavior or radio delivery; those need device tests.
void main() {
  final android = File(
    'android/app/src/main/kotlin/com/n1cxltine/sosapp/BleTransportBridge.kt',
  ).readAsStringSync();
  final ios = File('ios/Runner/BleTransport.swift').readAsStringSync();
  String androidMethod(String start, String end) =>
      android.split(start).last.split(end).first;

  test('both clients prefer the same additive confirmed TX UUID', () {
    const uuid = '8b7f0004-6d3a-4c8b-9d21-5a7f2e110001';
    expect(android.toLowerCase(), contains(uuid));
    expect(ios.toLowerCase(), contains(uuid));
    expect(
      android,
      contains(
        'service?.getCharacteristic(CONFIRMED_TX) ?: service?.getCharacteristic(TX)',
      ),
    );
    final selection = ios
        .split('didDiscoverCharacteristicsFor service:')
        .last
        .split(
          'func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor',
        )
        .first;
    expect(
      selection.indexOf(r'$0.uuid == Self.confirmedTx'),
      lessThan(selection.indexOf(r'$0.uuid == Self.tx')),
    );
    expect(selection, contains('tx.properties.contains(.indicate)'));
    expect(selection, contains('tx.properties.contains(.notify)'));
    expect(android, contains('service.addCharacteristic(tx)'));
    expect(android, contains('service.addCharacteristic(confirmedTx)'));
    final confirmed = android
        .split('val confirmedTx = BluetoothGattCharacteristic(')
        .last
        .split('confirmedTx.addDescriptor')
        .first;
    expect(confirmed, contains('PROPERTY_INDICATE'));
    expect(confirmed, isNot(contains('PROPERTY_NOTIFY')));
  });

  test('Android negotiates indication CCCD and requests confirmation in both native APIs', () {
    expect(
      android,
      contains('descriptor.value = if (tx.uuid == CONFIRMED_TX)'),
    );
    expect(
      android,
      contains(
        'BluetoothGattDescriptor.ENABLE_INDICATION_VALUE else BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE',
      ),
    );
    final flush = androidMethod(
      'private fun flushPeripheralNotifications(',
      'private fun modelForAdvertising',
    );
    expect(flush, contains('val confirmed = confirmedClients.contains(id)'));
    expect(
      flush,
      contains(
        'if (confirmed) serverConfirmedTxCharacteristic else serverTxCharacteristic',
      ),
    );
    expect(
      flush,
      contains('device,\n                tx,\n                confirmed,'),
    );
    expect(
      flush,
      contains('notifyCharacteristicChanged(device, tx, confirmed)'),
    );
    expect(flush, contains('notificationInFlight.contains(id)'));
    expect(flush, isNot(contains('pending.result.success')));
    expect(
      android,
      contains('"confirmed_indications" else "legacy_notifications"'),
    );
    expect(ios, contains('"confirmed_indications" : "legacy_notifications"'));
  });

  test('ATT replies precede app data/readiness and confirmed mode retires with its subscription', () {
    final write = androidMethod(
      'override fun onCharacteristicWriteRequest(',
      'override fun onDescriptorWriteRequest(',
    );
    expect(
      write.indexOf('server?.sendResponse('),
      lessThan(write.indexOf('"type" to "data"')),
    );
    expect(write, contains(r'accepted=$accepted supported=$supported'));
    final descriptor = androidMethod(
      'override fun onDescriptorWriteRequest(',
      'override fun onConnectionStateChange(device:',
    );
    expect(
      descriptor.indexOf('server?.sendResponse('),
      lessThan(descriptor.indexOf('"type" to "connected"')),
    );
    expect(
      descriptor,
      contains('confirmedClients.contains(device.address) == confirmed'),
    );
    final clear = android.split('private fun clearNotificationSession(').last;
    expect(clear, contains('confirmedClients.remove(id)'));
    expect(
      ios.split('didUpdateValueFor characteristic:').last,
      contains('characteristic.uuid == txCharacteristics[p.identifier]?.uuid'),
    );
  });
}
