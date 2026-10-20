import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';

import 'sos_ble_coordinator_test.dart' show FakeBleTransport;

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
