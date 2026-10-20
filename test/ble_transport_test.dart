import 'dart:async';

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

  test('dispose waits for an in-flight send before native disposal', () async {
    const methods = MethodChannel('ble_transport_inflight/methods');
    const events = EventChannel('ble_transport_inflight/events');
    final sendDone = Completer<void>();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          calls.add(call.method);
          if (call.method == 'send') await sendDone.future;
          return null;
        });

    final transport = BleTransport(methods: methods, events: events);
    final send = transport.send('peer', <int>[1, 2, 3]);
    await Future<void>.delayed(Duration.zero);
    final disposing = transport.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['send']);
    sendDone.complete();
    await send;
    await disposing;
    expect(calls, ['send', 'dispose']);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, null);
  });

  test('initialize can retry after a permission failure', () async {
    const methods = MethodChannel('ble_transport_retry/methods');
    const events = EventChannel('ble_transport_retry/events');
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'initialize' && attempts++ == 0) {
            throw PlatformException(
              code: 'unauthorized',
              message: 'permission denied',
            );
          }
          return null;
        });

    final transport = BleTransport(methods: methods, events: events);
    await expectLater(
      transport.initialize(),
      throwsA(isA<BleTransportException>()),
    );
    await transport.initialize();
    expect(attempts, 2);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, null);
  });

  test(
    'repeated initialization failures do not poison later retries',
    () async {
      const methods = MethodChannel('ble_transport_retry_twice/methods');
      const events = EventChannel('ble_transport_retry_twice/events');
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, (call) async {
            if (call.method == 'initialize') {
              attempts++;
              if (attempts < 3) {
                throw PlatformException(
                  code: 'unauthorized',
                  message: 'permission denied',
                );
              }
            }
            return null;
          });

      final transport = BleTransport(methods: methods, events: events);
      await expectLater(
        transport.initialize(),
        throwsA(isA<BleTransportException>()),
      );
      await expectLater(
        transport.initialize(),
        throwsA(isA<BleTransportException>()),
      );
      await transport.initialize();
      expect(attempts, 3);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methods, null);
    },
  );

  test('coalesces concurrent initialize calls', () async {
    const methods = MethodChannel('ble_transport_once/methods');
    const events = EventChannel('ble_transport_once/events');
    final gate = Completer<void>();
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, (call) async {
          if (call.method == 'initialize') {
            calls++;
            await gate.future;
          }
          return null;
        });

    final transport = BleTransport(methods: methods, events: events);
    final first = transport.initialize();
    final second = transport.initialize();
    expect(identical(first, second), isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls, 1);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methods, null);
  });
}
