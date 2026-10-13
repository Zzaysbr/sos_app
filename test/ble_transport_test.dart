import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dispose is idempotent and rejects operations afterwards', () async {
    const methods = MethodChannel('ble_transport_test/methods');
    const events = EventChannel('ble_transport_test/events');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call.method);
          return null;
        });

    final transport = BleTransport(methods: methods, events: events);
    await transport.dispose();
    await transport.dispose();

    expect(calls, ['dispose']);
    await expectLater(
      transport.startDiscovery(),
      throwsA(isA<BleTransportException>()),
    );
    expect(() => transport.initialize(), throwsA(isA<BleTransportException>()));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, null);
  });
}
