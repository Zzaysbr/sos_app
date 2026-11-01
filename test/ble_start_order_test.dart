import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/emergency_consent_store.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';
import 'package:sos_app/features/sos/presentation/sos_page.dart';
import 'package:sos_app/features/role/data/role_preference_store.dart';
import 'package:sos_app/features/role/domain/app_role.dart';

import 'sos_ble_coordinator_test.dart' show FakeBleTransport;

class _Repository extends Mock implements SosRepository {}

void main() {
  Future<void> open(
    WidgetTester tester,
    FakeBleTransport transport,
    Future<void> Function() start,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _Repository();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    when(() => repository.database).thenReturn(database);
    when(() => repository.watchAll())
        .thenAnswer((_) => Stream.value(<SosMessage>[]));
    when(() => repository.listActiveIncidents()).thenAnswer((_) async => []);
    when(
      () => repository.create(
        id: any(named: 'id'),
        type: any(named: 'type'),
        message: any(named: 'message'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        destinationId: any(named: 'destinationId'),
      ),
    ).thenAnswer((_) async {});
    when(() => repository.findById(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      return SosMessage(
        id: id,
        ownerId: guestDeviceOwnerId,
        type: 'emergency',
        message: 'Emergency SOS',
        status: 'active',
        syncState: 'pending',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SosPage(
          repository: repository,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          bleTransport: transport,
          isGuest: true,
          emergencyConsentStore: MemoryEmergencyConsentStore(),
          onBleStartRequested: start,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'debug BLE screen waits for coordinator listener before native initialization',
    (tester) async {
      final transport = FakeBleTransport();
      final ready = Completer<void>();
      var started = false;
      await open(tester, transport, () async {
        started = true;
        await ready.future;
      });
      await tester.tap(find.text('ตั้งค่า'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('BLE Test (Debug)'));
      await tester.tap(find.text('BLE Test (Debug)'));
      await tester.pump();
      expect(started, isTrue);
      expect(transport.lifecycleCalls, isEmpty);
      ready.complete();
      await tester.pumpAndSettle();
      expect(transport.lifecycleCalls, contains('initialize'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await transport.controller.close();
    },
  );

  testWidgets(
    'one-tap SOS opens Chat without relay options or recipient picker',
    (tester) async {
      final transport = FakeBleTransport();
      final ready = Completer<void>();
      var started = false;
      await open(tester, transport, () async {
        started = true;
        await ready.future;
      });
      await tester.tap(find.text('ประวัติ'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Send SOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send SOS'));
      await tester.pumpAndSettle();
      expect(started, isTrue);
      expect(transport.lifecycleCalls, isEmpty);
      expect(find.text('SOS relay options'), findsNothing);
      expect(find.text('Choose BLE recipient'), findsNothing);
      expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await transport.controller.close();
    },
  );
}
