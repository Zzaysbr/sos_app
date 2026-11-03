import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_range_diagnostic.dart';
import 'package:sos_app/features/nearby_ble/presentation/ble_test_page.dart';
import 'package:sos_app/features/nearby_ble/presentation/ble_recipient_picker_page.dart';

class FakeBleTransport implements BleTransportClient {
  final controller = StreamController<BleEvent>.broadcast();
  final calls = <String>[];
  bool disposed = false;
  final sentFrames = <List<int>>[];

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
  }) async {
    calls.add('send:$deviceId');
    sentFrames.add(List<int>.from(frame));
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

class SnapshotBleTransport extends FakeBleTransport {
  SnapshotBleTransport(this.snapshot);

  final List<BleEvent> snapshot;

  @override
  Stream<BleEvent> get events async* {
    for (final event in snapshot) {
      yield event;
    }
    yield* controller.stream;
  }
}

void main() {
  testWidgets('recipient picker cleans up shared scan resources on dispose', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(
      MaterialApp(home: BleRecipientPickerPage(transport: fake)),
    );
    await tester.pumpAndSettle();
    expect(fake.calls, contains('scan'));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(fake.calls, contains('stopScan'));
    expect(fake.disposed, isFalse);

    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'stale-peer'),
      ),
    );
    await tester.pump();
  });

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

  testWidgets('deduplicates a device and refreshes its latest advertisement', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'AA:BB', name: 'Phone A', rssi: -80),
      ),
    );
    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'aa:bb', name: 'Phone A Updated', rssi: -42),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Phone A Updated'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Phone A Updated'), findsOneWidget);
    expect(find.text('Phone A'), findsNothing);
    expect(find.textContaining('RSSI -42'), findsOneWidget);
  });

  testWidgets('keeps same-name devices with different identifiers separate', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    for (final id in ['AA:BB', 'CC:DD']) {
      fake.controller.add(
        BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: id, name: 'Same name'),
        ),
      );
    }
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Same name'), findsNWidgets(2));
  });

  testWidgets('does not create a device row from an unknown connection event', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();

    fake.controller.add(
      const BleEvent(
        type: 'connecting',
        device: BleDevice(id: '7C:9C:0A:74:4F:2E'),
        attempt: 4,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unnamed device'), findsNothing);
  });

  testWidgets('connection callbacks update the existing scan row', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'AA:BB', name: 'Phone A'),
      ),
    );
    await tester.pumpAndSettle();
    fake.controller.add(
      const BleEvent(
        type: 'connecting',
        device: BleDevice(id: 'aa:bb', name: 'Phone A'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Phone A'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('AA:BB'), findsOneWidget);
    expect(find.textContaining('State: connecting'), findsOneWidget);
  });

  testWidgets('peripheral disconnect does not overwrite central connected', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    const peer = BleDevice(id: 'peer-role');
    fake.controller
      ..add(const BleEvent(type: 'connected', device: peer))
      ..add(const BleEvent(
        type: 'disconnected',
        device: peer,
        role: BleSessionRole.peripheral,
      ));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: connected'), findsOneWidget);
  });

  testWidgets('central disconnect does not overwrite peripheral connected', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    const peer = BleDevice(id: 'peer-role');
    fake.controller
      ..add(const BleEvent(
        type: 'connected',
        device: peer,
        role: BleSessionRole.peripheral,
      ))
      ..add(const BleEvent(
        type: 'disconnected',
        device: peer,
        role: BleSessionRole.central,
      ));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: connected'), findsOneWidget);
  });

  testWidgets('both active roles are shown without an ambiguous state', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    const peer = BleDevice(id: 'peer-role');
    fake.controller
      ..add(const BleEvent(
        type: 'connected',
        device: peer,
        role: BleSessionRole.central,
      ))
      ..add(const BleEvent(
        type: 'connected',
        device: peer,
        role: BleSessionRole.peripheral,
      ));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: connected (central + peripheral)'),
        findsOneWidget);

    fake.controller.add(const BleEvent(
      type: 'disconnected',
      device: peer,
      role: BleSessionRole.central,
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: connected'), findsOneWidget);
    expect(find.textContaining('central + peripheral'), findsNothing);
  });

  testWidgets('both role disconnects produce disconnected state', (tester) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    const peer = BleDevice(id: 'peer-role');
    fake.controller
      ..add(const BleEvent(
        type: 'connected',
        device: peer,
        role: BleSessionRole.central,
      ))
      ..add(const BleEvent(
        type: 'connected',
        device: peer,
        role: BleSessionRole.peripheral,
      ))
      ..add(const BleEvent(
        type: 'disconnected',
        device: peer,
        role: BleSessionRole.central,
      ))
      ..add(const BleEvent(
        type: 'disconnected',
        device: peer,
        role: BleSessionRole.peripheral,
      ));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: disconnected'), findsOneWidget);
  });

  testWidgets('connected role snapshot restores after navigation', (tester) async {
    const peer = BleDevice(id: 'peer-snapshot');
    final transport = SnapshotBleTransport([
      const BleEvent(
        type: 'connected',
        device: peer,
        role: BleSessionRole.peripheral,
      ),
    ]);
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: transport)));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: connected'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: transport)));
    await tester.pumpAndSettle();
    expect(find.textContaining('State: connected'), findsOneWidget);
  });

  testWidgets('does not start duplicate scan operations in one session', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    expect(fake.calls.where((call) => call == 'scan'), hasLength(1));
  });

  testWidgets(
    'new scan session clears old devices and ignores stopped events',
    (tester) async {
      final fake = FakeBleTransport();
      await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();
      fake.controller.add(
        const BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: 'AA:BB', name: 'Old device'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop Scan'));
      await tester.pumpAndSettle();
      fake.controller.add(
        const BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: 'CC:DD', name: 'Stale device'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stale device'), findsNothing);
      await tester.tap(find.text('Start Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Old device'), findsNothing);
    },
  );

  testWidgets('ignores scan events without a usable identifier', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
    fake.controller.add(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: '', name: 'Unnamed'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Unnamed'), findsNothing);
  });

  testWidgets('connects and sends only after connected event', (tester) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.tap(find.text('Start Scan'));
    await tester.pumpAndSettle();
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

  testWidgets('range ping receives a real application ACK on the same route', (
    tester,
  ) async {
    final fake = FakeBleTransport();
    await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
    await tester.pump();
    const peer = BleDevice(id: 'peer-a');
    final ping = BleRangeDiagnosticMessage.ping(
      runId: 'run-widget',
      sequence: 1,
      sentAt: DateTime.utc(2026),
    );
    for (final frame in BleMessageCodec.encode(ping)) {
      fake.controller.add(
        BleEvent(
          type: 'data',
          device: peer,
          payload: frame,
          role: BleSessionRole.peripheral,
        ),
      );
    }
    await tester.pumpAndSettle();

    final ack = BleMessageCodec.decode(fake.sentFrames);
    expect(ack.type, bleRangeAckType);
    expect(BleRangeDiagnosticMessage.acknowledgedMessageId(ack), ping.id);
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

  testWidgets(
    'permission grant after the initial denial retries initialization',
    (tester) async {
      final fake = GrantAfterDenialTransport();
      await tester.pumpWidget(MaterialApp(home: BleTestPage(transport: fake)));
      await tester.pump();
      await tester.tap(find.text('Permissions'));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('initialize'));
      await tester.scrollUntilVisible(
        find.textContaining('Transport initialized'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Transport initialized'), findsOneWidget);
    },
  );

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

    expect(fake.calls, ['permissions']);
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

class GrantAfterDenialTransport extends FakeBleTransport {
  var permissionAttempts = 0;

  @override
  Future<void> requestPermissions() async {
    calls.add('permissions');
    if (permissionAttempts++ == 0) {
      throw const BleTransportException('permissions denied');
    }
  }
}
