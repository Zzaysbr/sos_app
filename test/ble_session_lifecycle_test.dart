import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

import 'sos_ble_coordinator_test.dart' show FakeBleTransport;

SosMessage _lifecycleSos() => SosMessage(
  id: 'lifecycle-sos',
  ownerId: 'owner-1',
  type: 'emergency',
  message: 'Controlled lifecycle test',
  latitude: null,
  longitude: null,
  status: 'active',
  syncState: 'pending',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

class DelayedPermissionsRadio extends FakeBleTransport {
  final permission = Completer<void>();
  @override
  Future<void> requestPermissions() async {
    lifecycleCalls.add('permissions');
    await permission.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent startup awaits the same permissions and readiness operation',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final radio = DelayedPermissionsRadio();
      final coordinator = SosBleCoordinator(
        database: db,
        ownerId: 'guest',
        transport: radio,
      );
      var completed = 0;
      final first = coordinator.start().then((_) => completed++);
      final second = coordinator.start().then((_) => completed++);
      await Future<void>.delayed(Duration.zero);
      expect(completed, 0);
      expect(radio.lifecycleCalls, ['permissions']);
      expect(radio.controller.hasListener, isTrue);
      radio.permission.complete();
      await Future.wait([first, second]);
      expect(radio.lifecycleCalls, ['permissions', 'initialize']);
      await coordinator.dispose();
      expect(radio.controller.hasListener, isFalse);
      await radio.controller.close();
      await db.close();
    },
  );

  test('poweredOff invalidates the peer and poweredOn permits a fresh route', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final radio = FakeBleTransport();
    final coordinator = SosBleCoordinator(
      database: db,
      ownerId: 'owner-1',
      transport: radio,
      pollInterval: const Duration(hours: 1),
    );
    await db.into(db.sosMessages).insert(_lifecycleSos());
    await coordinator.start();
    radio.emit(const BleEvent(type: 'connected', device: BleDevice(id: 'peer')));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    radio.emit(const BleEvent(type: 'centralState', state: 'poweredOff'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await coordinator.enqueueSos(_lifecycleSos(), destinationId: 'peer');
    await coordinator.assignSosDestination('lifecycle-sos', 'peer');
    await coordinator.processDue();
    expect(radio.connectCalls, isEmpty);
    radio.emit(const BleEvent(type: 'centralState', state: 'poweredOn'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await coordinator.processDue();
    expect(radio.connectCalls, ['peer']);
    await coordinator.dispose();
    await db.close();
  });

  test('repeated adapter events do not duplicate subscriptions or stale reconnects', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final radio = FakeBleTransport();
    final coordinator = SosBleCoordinator(
      database: db,
      ownerId: 'owner-1',
      transport: radio,
      pollInterval: const Duration(hours: 1),
    );
    await db.into(db.sosMessages).insert(_lifecycleSos());
    await coordinator.start();
    for (var i = 0; i < 3; i++) {
      radio.emit(const BleEvent(type: 'centralState', state: 'poweredOff'));
      radio.emit(const BleEvent(type: 'centralState', state: 'poweredOn'));
    }
    await Future<void>.delayed(Duration.zero);
    await coordinator.enqueueSos(_lifecycleSos(), destinationId: 'peer');
    await coordinator.assignSosDestination('lifecycle-sos', 'peer');
    await coordinator.processDue();
    expect(radio.connectCalls, ['peer']);
    await coordinator.dispose();
    await db.close();
  });

  test('stale connected callback after poweredOff cannot restore a session', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final radio = FakeBleTransport();
    final coordinator = SosBleCoordinator(
      database: db,
      ownerId: 'owner-1',
      transport: radio,
      pollInterval: const Duration(hours: 1),
    );
    await db.into(db.sosMessages).insert(_lifecycleSos());
    await coordinator.start();
    radio.emit(const BleEvent(type: 'centralState', state: 'poweredOff'));
    radio.emit(const BleEvent(type: 'connected', device: BleDevice(id: 'peer')));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await coordinator.enqueueSos(_lifecycleSos(), destinationId: 'peer');
    await coordinator.assignSosDestination('lifecycle-sos', 'peer');
    await coordinator.processDue();
    expect(radio.connectCalls, isEmpty);
    await coordinator.dispose();
    await db.close();
  });

  test('unauthorized and resetting adapter states block connection attempts', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final radio = FakeBleTransport();
    final coordinator = SosBleCoordinator(
      database: db,
      ownerId: 'owner-1',
      transport: radio,
      pollInterval: const Duration(hours: 1),
    );
    await db.into(db.sosMessages).insert(_lifecycleSos());
    await coordinator.start();
    for (final state in ['unauthorized', 'resetting', 'unsupported']) {
      radio.emit(BleEvent(type: 'centralState', state: state));
      await Future<void>.delayed(Duration.zero);
      await coordinator.enqueueSos(_lifecycleSos(), destinationId: 'peer');
      await coordinator.assignSosDestination('lifecycle-sos', 'peer');
      await coordinator.processDue();
    }
    expect(radio.connectCalls, isEmpty);
    await coordinator.dispose();
    await db.close();
  });

  test(
    'retired startup cannot initialize native BLE after permission completes',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final radio = DelayedPermissionsRadio();
      final coordinator = SosBleCoordinator(
        database: db,
        ownerId: 'guest',
        transport: radio,
      );
      final starting = coordinator.start();
      await coordinator.dispose();
      radio.permission.complete();
      await starting;
      expect(radio.lifecycleCalls, ['permissions']);
      expect(radio.controller.hasListener, isFalse);
      expect(coordinator.isStarted, isFalse);
      await radio.controller.close();
      await db.close();
    },
  );
}
