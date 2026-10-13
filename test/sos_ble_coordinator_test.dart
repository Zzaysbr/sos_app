import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_delivery_state.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';

class FakeBleTransport implements BleTransportClient {
  final controller = StreamController<BleEvent>.broadcast();
  final sent = <List<int>>[];
  final sentRoles = <BleSessionRole?>[];
  final connectCalls = <String>[];
  bool initialized = false;
  bool disposed = false;
  bool failWrites = false;
  bool failConnect = false;

  @override
  Stream<BleEvent> get events => controller.stream;

  @override
  Future<void> initialize() async => initialized = true;

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
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    if (failConnect) {
      throw const BleTransportException('connect failed');
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {
    if (failWrites) throw const BleTransportException('write failed');
    sent.add(List<int>.from(frame));
    sentRoles.add(role);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }

  void emit(BleEvent event) => controller.add(event);
}

SosMessage _sos() => SosMessage(
  id: 'sos-1',
  ownerId: 'owner-1',
  type: 'emergency',
  message: 'Help',
  latitude: 13.7,
  longitude: 100.5,
  status: 'active',
  syncState: 'pending',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
);

const device = BleDevice(id: 'peer-1', name: 'Peer');

BleMessage _decodeSent(List<List<int>> frames) =>
    BleMessageCodec.decode(frames);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase database;
  late FakeBleTransport transport;
  late SosBleCoordinator coordinator;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    transport = FakeBleTransport();
    coordinator = SosBleCoordinator(
      database: database,
      ownerId: 'owner-1',
      transport: transport,
      now: () => DateTime.utc(2026, 1, 1, 12),
      random: () => 0,
      pollInterval: const Duration(hours: 1),
    );
    await coordinator.start();
    transport.emit(const BleEvent(type: 'connected', device: device));
    await _settle();
  });

  tearDown(() async {
    await coordinator.dispose();
    await database.close();
  });

  test(
    'sends an SOS with a stable messageId and records a persisted ACK',
    () async {
      final row = await coordinator.enqueueSos(
        _sos(),
        destinationId: device.id,
      );
      await coordinator.processDue();

      expect(row.messageId, 'sos:sos-1:delivery:v1');
      final sent = _decodeSent(transport.sent);
      expect(sent.id, row.messageId);
      expect(sent.type, SosBleMessageKind.delivery.wireValue);
      expect(
        transport.sent.every(
          (frame) => frame.length <= BleMessageCodec.transportSafeFrameBytes,
        ),
        isTrue,
      );

      final ack = SosBleEnvelope.acknowledgement(
        messageId: 'ack:${row.messageId}',
        sosId: 'sos-1',
        ackFor: row.messageId,
        ackStatus: SosBleAckStatus.persisted,
        createdAt: DateTime.utc(2026, 1, 1, 12),
      );
      for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
      await coordinator.processDue();

      expect(
        transport.sent.every(
          (frame) => frame.length <= BleMessageCodec.transportSafeFrameBytes,
        ),
        isTrue,
      );

      final stored = await coordinatorFor(database).lookupOutbox(row.messageId);
      expect(stored!.state, BleOutboxState.acknowledged.wireValue);
    },
  );

  test('persists inbound SOS before sending positive ACK and deduplicates delivery', () async {
    final delivery = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'incoming-1',
      senderDeviceId: device.id,
    );
    final frames = BleMessageCodec.encode(delivery.toBleMessage());
    for (final frame in frames) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    final sentAfterFirst = transport.sent.length;

    for (final frame in frames) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();

    expect(await database.select(database.sosMessages).get(), hasLength(1));
    expect(await database.select(database.bleInbox).get(), hasLength(1));
    expect(transport.sent.length, greaterThanOrEqualTo(sentAfterFirst));
    final ackMessage = _decodeSent(transport.sent);
    expect(ackMessage.type, SosBleMessageKind.acknowledgement.wireValue);
  });

  test(
    'routes an inbound peripheral delivery ACK through the peripheral session',
    () async {
      transport.emit(
        const BleEvent(
          type: 'connected',
          device: device,
          role: BleSessionRole.peripheral,
        ),
      );
      await _settle();
      final delivery = SosBleEnvelope.fromSosMessage(
        _sos(),
        messageId: 'peripheral-incoming-1',
        senderDeviceId: device.id,
      );
      for (final frame in BleMessageCodec.encode(delivery.toBleMessage())) {
        transport.emit(
          BleEvent(
            type: 'data',
            device: device,
            payload: frame,
            role: BleSessionRole.peripheral,
          ),
        );
      }
      await _settle();
      expect(transport.sentRoles, contains(BleSessionRole.peripheral));
    },
  );

  test('unknown ACK does not acknowledge an unrelated outbox row', () async {
    final row = await coordinator.enqueueSos(_sos(), destinationId: device.id);
    await coordinator.processDue();
    final ack = SosBleEnvelope.acknowledgement(
      messageId: 'ack-unknown',
      sosId: 'different-sos',
      ackFor: 'unknown-message',
      ackStatus: SosBleAckStatus.persisted,
      createdAt: DateTime.utc(2026),
    );
    for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();

    final stored = await coordinatorFor(database).lookupOutbox(row.messageId);
    expect(stored!.state, BleOutboxState.awaitingAcknowledgement.wireValue);
  });

  test('ACK from an unexpected peer does not update the outbox', () async {
    final row = await coordinator.enqueueSos(_sos(), destinationId: device.id);
    await coordinator.processDue();
    final ack = SosBleEnvelope.acknowledgement(
      messageId: 'ack-unexpected-peer',
      sosId: _sos().id,
      ackFor: row.messageId,
      ackStatus: SosBleAckStatus.persisted,
      createdAt: DateTime.utc(2026),
    );
    const otherPeer = BleDevice(id: 'other-peer');
    for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: otherPeer, payload: frame));
    }
    await _settle();
    final stored = await coordinatorFor(database).lookupOutbox(row.messageId);
    expect(stored!.state, BleOutboxState.awaitingAcknowledgement.wireValue);
  });

  test('disconnect prevents sends and requests a reconnect', () async {
    transport.emit(const BleEvent(type: 'disconnected', device: device));
    await _settle();
    await coordinator.enqueueSos(_sos(), destinationId: device.id);
    await coordinator.processDue();

    expect(transport.sent, isEmpty);
    expect(transport.connectCalls, contains(device.id));
  });

  test('failed connection attempts advance durable retry count', () async {
    transport.failConnect = true;
    transport.emit(const BleEvent(type: 'disconnected', device: device));
    await _settle();
    final row = await coordinator.enqueueSos(_sos(), destinationId: device.id);
    await coordinator.processDue();

    final stored = await coordinatorFor(database).lookupOutbox(row.messageId);
    expect(stored!.state, BleOutboxState.failed.wireValue);
    expect(stored.retryCount, 1);
    expect(stored.nextRetryAt, isNotNull);
  });

  test('disconnect clears partial assembly state before reconnect', () async {
    final delivery = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'session-reset-delivery',
      senderDeviceId: device.id,
    );
    final frames = BleMessageCodec.encode(delivery.toBleMessage());
    transport.emit(
      BleEvent(type: 'data', device: device, payload: frames.first),
    );
    await _settle();
    transport.emit(const BleEvent(type: 'disconnected', device: device));
    transport.emit(const BleEvent(type: 'connected', device: device));
    await _settle();

    for (final frame in frames.skip(1)) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    expect(await database.select(database.bleInbox).get(), isEmpty);

    for (final frame in frames) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    expect(await database.select(database.bleInbox).get(), hasLength(1));
  });

  test(
    'send failure keeps the outbox item retryable and unacknowledged',
    () async {
      transport.failWrites = true;
      final row = await coordinator.enqueueSos(
        _sos(),
        destinationId: device.id,
      );
      await coordinator.processDue();

      final stored = await coordinatorFor(database).lookupOutbox(row.messageId);
      expect(stored!.state, BleOutboxState.failed.wireValue);
      expect(stored.acknowledgedAt, isNull);
      expect(stored.messageId, row.messageId);
    },
  );

  test('exposes the injected transport for shared debug clients', () {
    expect(coordinator.transport, same(transport));
  });

  test(
    'diagnostic logger failures do not affect coordinator lifecycle',
    () async {
      final diagnosticDatabase = AppDatabase.forTesting(
        NativeDatabase.memory(),
      );
      final diagnosticTransport = FakeBleTransport();
      final diagnosticCoordinator = SosBleCoordinator(
        database: diagnosticDatabase,
        ownerId: 'owner-1',
        transport: diagnosticTransport,
        onLog: (_) => throw StateError('diagnostic sink failed'),
        pollInterval: const Duration(hours: 1),
      );
      await diagnosticCoordinator.start();
      diagnosticTransport.emit(
        const BleEvent(type: 'connected', device: device),
      );
      await _settle();

      expect(diagnosticCoordinator.isStarted, isTrue);
      await diagnosticCoordinator.dispose();
      await diagnosticDatabase.close();
    },
  );

  test('stop unsubscribes and dispose is idempotent', () async {
    await coordinator.stop();
    transport.emit(const BleEvent(type: 'connected', device: device));
    await _settle();
    expect(coordinator.isStarted, isFalse);
    await coordinator.dispose();
    expect(transport.disposed, isFalse);
  });
}

BleDeliveryRepository coordinatorFor(AppDatabase database) =>
    BleDeliveryRepository(database);
