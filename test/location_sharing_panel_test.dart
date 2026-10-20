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
  testWidgets(
    'location sharing starts off and requires an explicit recipient',
    (tester) async {
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
          home: Scaffold(
            body: LocationSharingPanel(
              sos: sos,
              coordinator: coordinator,
              transport: transport,
            ),
          ),
        ),
      );

      expect(find.text('Foreground location sharing'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Start sharing'), findsOneWidget);
      expect(
        find.text('Select a connected recipient to start sharing.'),
        findsNothing,
      );

      await coordinator.dispose();
      await database.close();
    },
  );
}
