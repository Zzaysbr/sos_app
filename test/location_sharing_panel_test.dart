import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_delivery_state.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/sos/presentation/location_sharing_panel.dart';

class _Transport implements BleTransportClient {
  final _events = StreamController<BleEvent>.broadcast();
  void emit(BleEvent event) => _events.add(event);
  @override
  Stream<BleEvent> get events => _events.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> startAdvertising({String? name}) async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> startDiscovery() async {
    emit(
      const BleEvent(
        type: 'deviceFound',
        device: BleDevice(id: 'peer', name: 'Test peer'),
      ),
    );
  }

  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String deviceId) async {
    emit(
      BleEvent(
        type: 'connected',
        device: BleDevice(id: deviceId, name: 'Test peer'),
      ),
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {}
  @override
  Future<void> dispose() async => _events.close();
}

Position _position(DateTime timestamp) => Position(
  longitude: 100.5,
  latitude: 13.7,
  timestamp: timestamp,
  accuracy: 8,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
  floor: null,
  isMocked: true,
);

void main() {
  test('Location failed status only promises a retry when scheduled', () {
    final now = DateTime.utc(2026, 1, 1);
    BleOutboxData failed({DateTime? nextRetryAt}) => BleOutboxData(
      messageId: 'location-status',
      sosId: 'sos-location-status',
      destinationId: 'peer',
      schemaVersion: 1,
      payload: '{}',
      state: 'failed',
      retryCount: 1,
      nextRetryAt: nextRetryAt,
      lastError: 'receiver rejected persistence',
      createdAt: now,
      updatedAt: now,
    );

    expect(locationDeliveryStatusText(failed()), 'Failed; retry not scheduled');
    expect(
      locationDeliveryStatusText(
        failed(nextRetryAt: now.add(const Duration(seconds: 2))),
      ),
      'Failed; retry scheduled',
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'location sharing at text scale $scale waits for readiness and explicit recipient',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final ready = Completer<void>();
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        final now = DateTime.utc(2026, 1, 1);
        await database
            .into(database.sosMessages)
            .insert(
              SosMessagesCompanion.insert(
                id: 'sos-ui',
                ownerId: 'owner',
                type: 'emergency',
                status: 'active',
                syncState: 'synced',
                createdAt: now,
                updatedAt: now,
              ),
            );
        final transport = _Transport();
        final coordinator = SosBleCoordinator(
          database: database,
          ownerId: 'owner',
          transport: transport,
        );
        final sos = await (database.select(
          database.sosMessages,
        )..where((table) => table.id.equals('sos-ui'))).getSingle();

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: LocationSharingPanel(
                sos: sos,
                coordinator: coordinator,
                transport: transport,
                onBleStartRequested: () => ready.future,
              ),
            ),
          ),
        );

        expect(find.text('Foreground location sharing'), findsOneWidget);
        expect(find.text('Off'), findsOneWidget);
        expect(find.text('Start sharing'), findsOneWidget);
        expect(
          tester
              .getSize(find.widgetWithText(FilledButton, 'Start sharing'))
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(find.bySemanticsLabel('Location delivery: Off'), findsOneWidget);
        expect(
          find.text('Select a connected recipient to start sharing.'),
          findsNothing,
        );

        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Start sharing'));
        await tester.pump();
        expect(find.text('Choose BLE recipient'), findsNothing);
        ready.complete();
        await tester.pumpAndSettle();
        expect(find.text('Choose BLE recipient'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Off'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        semantics.dispose();
        await tester.runAsync(() async {
          await coordinator.dispose();
          await database.close();
        });
      },
    );
  }

  testWidgets(
    'a denied current location attempt cannot inherit a previous Delivered state',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final base = DateTime.utc(2026, 1, 1);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'sos-current-attempt',
              ownerId: 'owner',
              type: 'emergency',
              status: 'active',
              syncState: 'synced',
              createdAt: base,
              updatedAt: base,
            ),
          );
      final transport = _Transport();
      var coordinatorTick = 0;
      final coordinator = SosBleCoordinator(
        database: database,
        ownerId: 'owner',
        transport: transport,
        now: () => base.add(Duration(seconds: coordinatorTick++)),
      );
      final sos = await (database.select(
        database.sosMessages,
      )..where((table) => table.id.equals('sos-current-attempt'))).getSingle();
      var locationCalls = 0;
      var clockTick = 0;
      Future<Position?> loadLocation() async {
        locationCalls++;
        if (locationCalls == 2) {
          throw const BleDeliveryStateException(
            'Location permission was denied.',
          );
        }
        return _position(base.add(Duration(seconds: locationCalls)));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationSharingPanel(
              sos: sos,
              coordinator: coordinator,
              transport: transport,
              locationLoader: loadLocation,
              now: () => base.add(Duration(minutes: clockTick++)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Choose BLE recipient'), findsOneWidget);
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      var rows = await database.select(database.bleOutbox).get();
      expect(
        rows,
        hasLength(1),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .whereType<String>()
            .join(' | '),
      );
      final firstMessageId = rows.single.messageId;
      final firstAckAt = base.add(const Duration(minutes: 1));
      await (database.update(
        database.bleOutbox,
      )..where((table) => table.messageId.equals(firstMessageId))).write(
        BleOutboxCompanion(
          state: Value(BleOutboxState.acknowledged.wireValue),
          updatedAt: Value(firstAckAt),
          acknowledgedAt: Value(firstAckAt),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Location delivery: Delivered'),
        findsOneWidget,
      );

      await tester.tap(find.text('Send location'));
      await tester.pumpAndSettle();
      expect(find.text('Location permission was denied.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Location delivery: Failed'),
        findsOneWidget,
      );
      expect(find.text('Previous delivery: Delivered'), findsOneWidget);

      await (database.update(
        database.bleOutbox,
      )..where((table) => table.messageId.equals(firstMessageId))).write(
        BleOutboxCompanion(
          state: Value(BleOutboxState.acknowledged.wireValue),
          updatedAt: Value(base.add(const Duration(minutes: 2))),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Location delivery: Failed'),
        findsOneWidget,
      );
      expect(find.text('Previous delivery: Delivered'), findsOneWidget);

      await tester.tap(find.text('Send location'));
      await tester.pumpAndSettle();
      rows = await (database.select(
        database.bleOutbox,
      )..orderBy([(table) => OrderingTerm.desc(table.createdAt)])).get();
      expect(rows, hasLength(2));
      final current = rows.singleWhere(
        (row) => row.messageId != firstMessageId,
      );
      expect(current.messageId, isNot(firstMessageId));
      final currentAckAt = base.add(const Duration(minutes: 3));
      await (database.update(
        database.bleOutbox,
      )..where((table) => table.messageId.equals(current.messageId))).write(
        BleOutboxCompanion(
          state: Value(BleOutboxState.acknowledged.wireValue),
          updatedAt: Value(currentAckAt),
          acknowledgedAt: Value(currentAckAt),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Location delivery: Delivered'),
        findsOneWidget,
      );
      expect(find.text('Location permission was denied.'), findsNothing);

      await tester.tap(find.text('Stop sharing'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Location delivery: Off'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        await coordinator.dispose();
        await transport.dispose();
        await database.close();
      });
    },
  );
}
