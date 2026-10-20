import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/sos/presentation/location_sharing_panel.dart';

class _Transport implements BleTransportClient {
  final _events = StreamController<BleEvent>.broadcast();
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
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String deviceId) async {}
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

void main() {
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
}
