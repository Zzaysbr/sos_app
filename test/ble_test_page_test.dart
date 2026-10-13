import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/presentation/ble_test_page.dart';

class FakeBleTransport implements BleTransportClient {
  final controller = StreamController<BleEvent>.broadcast();
  final calls = <String>[];
  bool disposed = false;

  @override
  Stream<BleEvent> get events => controller.stream;
  @override
  Future<void> initialize() async => calls.add('initialize');
  @override
  Future<void> requestPermissions() async => calls.add('permissions');
  @override
  Future<void> startAdvertising({String? name}) async => calls.add('advertise');
  @override
  Future<void> stopAdvertising() async => calls.add('stopAdvertise');
  @override
  Future<void> startDiscovery() async => calls.add('scan');
  @override
  Future<void> stopDiscovery() async => calls.add('stopScan');
  @override
  Future<void> connect(String deviceId) async => calls.add('connect:$deviceId');
  @override
  Future<void> disconnect(String deviceId) async =>
      calls.add('disconnect:$deviceId');
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async => calls.add('send:$deviceId');
  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

void main() {
  testWidgets('starts and stops scanning and renders discovered device', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('scan'));

    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'AA:BB', name: 'Phone A', rssi: -45),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Phone A'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Phone A'), findsOneWidget);
    expect(find.textContaining('AA:BB'), findsOneWidget);

    await tester.tap(find.text('Stop Scan'));
    await tester.pump();
    expect(fake.calls, contains('stopScan'));
    await tester.pumpWidget(const SizedBox());
    expect(fake.disposed, isFalse);
  });

  testWidgets('connects and sends only after connected event', (tester) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'AA:BB', name: 'Phone A'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Connect'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Connect'));
    await tester.pump();
    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(fake.calls, contains('connect:AA:BB'));
    expect(find.text('Send'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.text('Send'));
    expect(fake.calls.where((call) => call.startsWith('send:')), isEmpty);

    fake.controller.add(
      const BleEvent(
        type: 'connected',
        device: BleDevice(id: 'AA:BB', name: 'Phone A'),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send'),
    );
    expect(sendButton.onPressed, isNotNull);
    await tester.ensureVisible(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'hello');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'hello',
    );
    sendButton.onPressed!();
    await tester.pumpAndSettle();
    expect(fake.calls, contains('send:AA:BB'));
  });

  testWidgets('renders a complete received protocol message', (tester) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    final frames = _testFrames();
    for (final frame in frames) {
      fake.controller.add(BleEvent(type: 'data', payload: frame));
    }
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Received messages'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Received messages'), findsOneWidget);
    expect(find.textContaining('hello from phone'), findsOneWidget);
  });

  testWidgets('permission errors are written to diagnostics', (tester) async {
    final fake = FakeBleTransportWithError();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    await tester.tap(find.text('Permissions'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('permissions failed'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('permissions failed'), findsOneWidget);
  });

  testWidgets('native scan errors are written to diagnostics', (tester) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    fake.controller.add(const BleEvent(type: 'error', error: 'scan failed'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.textContaining('Native error: scan failed'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Native error: scan failed'), findsOneWidget);
  });

  testWidgets('does not start an operation after the page is unmounted', (
    tester,
  ) async {
    final fake = DelayedInitializationTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    fake.initialization.complete();
    await tester.pumpAndSettle();

    expect(fake.calls, isEmpty);
    expect(fake.disposed, isFalse);
  });
}

List<List<int>> _testFrames() {
  final message = BleMessage(
    id: 'ui-test-message',
    type: 'test',
    createdAt: DateTime.utc(2026),
    payload: const {'text': 'hello from phone'},
  );
  return BleMessageCodec.encode(message, maxFrameBytes: 30);
}

class FakeBleTransportWithError extends FakeBleTransport {
  @override
  Future<void> requestPermissions() =>
      Future<void>.error(const BleTransportException('permissions denied'));
}

class DelayedInitializationTransport extends FakeBleTransport {
  final initialization = Completer<void>();

  @override
  Future<void> initialize() => initialization.future;
}
