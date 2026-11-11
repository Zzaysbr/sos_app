import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/presentation/nearby_connection_status.dart';

class _Transport extends Mock implements BleTransportClient {}

void main() {
  testWidgets(
    'disconnect progress survives native callback and loss keeps model',
    (tester) async {
      final events = StreamController<BleEvent>.broadcast();
      final transport = _Transport();
      when(() => transport.events).thenAnswer((_) => events.stream);
      final finished = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyConnectionStatus(
              transport: transport,
              onDisconnect: (_) => finished.future,
              onConnect: (_) async {},
            ),
          ),
        ),
      );
      const peer = BleDevice(id: 'connected-only', model: 'SM-A536E');
      events.add(const BleEvent(type: 'connected', device: peer));
      await tester.pump();
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(find.text('Disconnecting…'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Disconnecting…'),
            )
            .onPressed,
        isNull,
      );
      events.add(const BleEvent(type: 'disconnected', device: peer));
      await tester.pump();
      expect(find.text('Disconnecting…'), findsOneWidget);
      finished.complete();
      await tester.pump();
      expect(find.text('Disconnecting…'), findsNothing);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('Samsung Galaxy A53'), findsOneWidget);
      // No discovery evidence: an out-of-range peer must not offer Connect.
      expect(find.text('Connect'), findsNothing);
      events.add(const BleEvent(type: 'deviceFound', device: peer));
      await tester.pump();
      expect(find.text('Connect'), findsOneWidget);
      events.add(const BleEvent(type: 'connected', device: peer));
      await tester.pump();
      await tester.pump();
      expect(find.text('Disconnected'), findsNothing);
      expect(find.text('Disconnect'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );

  testWidgets(
    'verified aliases share a model; identical models stay separate at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = StreamController<BleEvent>.broadcast();
      final transport = _Transport();
      when(() => transport.events).thenAnswer((_) => events.stream);
      final keys = {'incoming': 'verified-one', 'advertised': 'verified-one'};
      final disconnected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NearbyConnectionStatus(
                transport: transport,
                verifiedPeerKey: (peer) => keys[peer],
                onSearch: () async {},
                onConnect: (_) async {},
                onDisconnect: (peer) async => disconnected.add(peer),
              ),
            ),
          ),
        ),
      );
      events.add(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'incoming'),
          role: BleSessionRole.peripheral,
        ),
      );
      for (final id in ['advertised', 'same-model-other-device']) {
        events.add(
          BleEvent(
            type: 'deviceFound',
            device: BleDevice(
              id: id,
              model: 'SM-A536E',
              recoveryHint: '12345678',
            ),
          ),
        );
      }
      await tester.pump();
      expect(find.text('Samsung Galaxy A53'), findsNWidgets(2));
      expect(find.text('Unknown model'), findsNothing);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Unverified devices sharing even a model and public hint remain distinct.
      events.add(
        const BleEvent(
          type: 'deviceFound',
          device: BleDevice(
            id: 'third',
            model: 'SM-A536E',
            recoveryHint: '12345678',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Samsung Galaxy A53'), findsNWidgets(3));
      expect(tester.takeException(), isNull);
      events.add(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'advertised'),
          role: BleSessionRole.central,
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Disconnect'));
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(disconnected, containsAll(['incoming', 'advertised']));
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );

  testWidgets('empty search gives a next step without starting radio itself', (
    tester,
  ) async {
    final events = StreamController<BleEvent>.broadcast();
    final transport = _Transport();
    when(() => transport.events).thenAnswer((_) => events.stream);
    var searches = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyConnectionStatus(
            transport: transport,
            onSearch: () async {
              searches++;
            },
          ),
        ),
      ),
    );
    expect(find.textContaining('No devices found yet.'), findsNothing);
    await tester.tap(find.text('Find nearby devices'));
    await tester.pump();
    expect(searches, 1);
    expect(find.textContaining('No devices found yet.'), findsOneWidget);
    events.add(const BleEvent(type: 'centralState', state: 'poweredOff'));
    await tester.pump();
    expect(find.textContaining('Turn on Bluetooth'), findsOneWidget);
    expect(find.textContaining('No devices found yet.'), findsNothing);
    verifyNever(() => transport.startDiscovery());
    await tester.pumpWidget(const SizedBox.shrink());
    await events.close();
  });

  testWidgets(
    'banner shows only search and actions for nearby or connected peers',
    (tester) async {
      final events = StreamController<BleEvent>.broadcast();
      final transport = _Transport();
      when(() => transport.events).thenAnswer((_) => events.stream);
      final disconnected = <String>[];
      final selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NearbyConnectionStatus(
              transport: transport,
              onSearch: () async {},
              onConnect: (peer) async => selected.add(peer),
              onDisconnect: (peer) async => disconnected.add(peer),
            ),
          ),
        ),
      );
      expect(find.text('Find nearby devices'), findsOneWidget);
      expect(find.textContaining('Connected:'), findsNothing);
      expect(find.textContaining('Nearby:'), findsNothing);
      const peer = BleDevice(
        id: 'peer-1234',
        name: 'Personal phone',
        model: 'SM-A536E',
      );
      const iosPeer = BleDevice(id: 'random-ios-id', model: 'M:I15,5');
      const ipadPeer = BleDevice(id: 'random-ipad-id', model: 'M:P14,8');
      const unnamedPeer = BleDevice(id: 'random-unknown-id');
      events.add(const BleEvent(type: 'deviceFound', device: iosPeer));
      events.add(const BleEvent(type: 'deviceFound', device: ipadPeer));
      events.add(const BleEvent(type: 'deviceFound', device: unnamedPeer));
      events.add(const BleEvent(type: 'deviceFound', device: peer));
      await tester.pump();
      expect(find.text('Samsung Galaxy A53'), findsOneWidget);
      expect(find.text('iPhone 15 Plus'), findsOneWidget);
      expect(find.text('iPad Air (M2)'), findsOneWidget);
      expect(find.text('Unknown model'), findsOneWidget);
      expect(find.text('Personal phone'), findsNothing);
      expect(find.textContaining('random-unknown-id'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Samsung Galaxy A53'),
          matching: find.text('Connect'),
        ),
      );
      await tester.pump();
      expect(selected, ['peer-1234']);
      events.add(const BleEvent(type: 'connecting', device: peer));
      await tester.pump();
      final connecting = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Connecting…'),
      );
      expect(connecting.onPressed, isNull);
      events.add(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'peer-1234'),
          role: BleSessionRole.central,
          attempt: 2,
        ),
      );
      events.add(
        const BleEvent(
          type: 'connected',
          device: peer,
          role: BleSessionRole.peripheral,
          attempt: 3,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Samsung Galaxy A53'), findsOneWidget);
      events.add(
        const BleEvent(
          type: 'disconnected',
          device: peer,
          role: BleSessionRole.central,
          attempt: 1,
        ),
      );
      events.add(
        const BleEvent(
          type: 'disconnected',
          device: peer,
          role: BleSessionRole.peripheral,
          attempt: 3,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Disconnect'), findsOneWidget);
      await tester.tap(find.text('Disconnect'));
      await tester.pump();
      expect(disconnected, ['peer-1234']);
      events.add(
        const BleEvent(
          type: 'disconnected',
          device: peer,
          role: BleSessionRole.central,
          attempt: 2,
        ),
      );
      await tester.pump();
      expect(find.text('Disconnect'), findsNothing);
      expect(find.text('Connect'), findsNWidgets(4));
      events.add(const BleEvent(type: 'centralState', state: 'poweredOff'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Find nearby devices'), findsOneWidget);
      expect(find.text('Connect'), findsNothing);
      verifyNever(() => transport.startDiscovery());
      await tester.pumpWidget(const SizedBox.shrink());
      await events.close();
    },
  );
}
