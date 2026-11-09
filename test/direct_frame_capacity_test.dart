import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';

import 'sos_ble_coordinator_test.dart' show FakeBleTransport;

class CapacityTransport extends FakeBleTransport implements BleFrameCapacity {
  final capacities = <BleSessionRole, int>{
    BleSessionRole.central: 247,
    BleSessionRole.peripheral: 512,
  };
  @override
  Future<int> maxFrameBytes(String deviceId, BleSessionRole role) async =>
      capacities[role]!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final role in BleSessionRole.values) {
    test(
      'binding and persisted SOS ACK use negotiated ${role.name} frames',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final transport = CapacityTransport();
        final coordinator = SosBleCoordinator(
          database: db,
          ownerId: 'test',
          localDeviceId: 'local',
          transport: transport,
          requirePeerBinding: true,
          pollInterval: const Duration(days: 1),
          now: () => DateTime.utc(2026, 11, 9),
        );
        addTearDown(() async {
          await coordinator.dispose();
          await db.close();
        });
        await coordinator.start();
        const device = BleDevice(id: 'peer');
        transport.emit(BleEvent(type: 'connected', device: device, role: role));
        for (var i = 0; i < 100 && transport.sent.isEmpty; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        // Drain all frames from the async native capability query/write queue.
        for (var i = 0; i < 30; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        final hello = BleMessageCodec.decode(transport.sent);
        expect(hello.type, 'peer.binding.v1');
        expect(transport.sent.any((f) => f.length > 20), isTrue);
        expect(
          transport.sent.every((f) => f.length <= transport.capacities[role]!),
          isTrue,
        );
        final compactCount = transport.sent.length;
        expect(
          compactCount,
          lessThan(BleMessageCodec.encode(hello, maxFrameBytes: 20).length),
        );
        transport.sent.clear();
        // Legacy SOS is allowed without application binding; only persistence
        // creates the positive ACK. Its bytes/protocol remain unchanged.
        final envelope = SosBleEnvelope.fromSosMessage(
          SosMessage(
            id: 'sos',
            ownerId: 'peer',
            type: 'emergency',
            message: 'test',
            status: 'active',
            syncState: 'deviceOnly',
            createdAt: DateTime.utc(2026, 11, 9),
            updatedAt: DateTime.utc(2026, 11, 9),
            latitude: null,
            longitude: null,
          ),
          messageId: 'delivery',
          senderDeviceId: 'peer',
        );
        for (final frame in BleMessageCodec.encode(envelope.toBleMessage())) {
          transport.emit(
            BleEvent(type: 'data', device: device, role: role, payload: frame),
          );
        }
        for (var i = 0; i < 100; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        final ack = SosBleEnvelope.fromBleMessage(
          BleMessageCodec.decode(transport.sent),
        );
        expect(ack.ackStatus, SosBleAckStatus.persisted);
        expect(await db.select(db.sosMessages).get(), hasLength(1));
        expect(transport.sent.any((f) => f.length > 20), isTrue);
        expect(
          transport.sent.every((f) => f.length <= transport.capacities[role]!),
          isTrue,
        );
      },
    );
  }
}
