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
import 'package:sos_app/features/sos/data/chat_repository.dart';

class FakeBleTransport implements BleTransportClient {
  final controller = StreamController<BleEvent>.broadcast();
  final sent = <List<int>>[];
  final sentDeviceIds = <String>[];
  final sentRoles = <BleSessionRole?>[];
  final connectCalls = <String>[];
  final lifecycleCalls = <String>[];
  bool initialized = false;
  bool disposed = false;
  bool failWrites = false;
  bool failConnect = false;

  @override
  Stream<BleEvent> get events => controller.stream;

  @override
  Future<void> initialize() async {
    lifecycleCalls.add('initialize');
    initialized = true;
  }

  @override
  Future<void> requestPermissions() async => lifecycleCalls.add('permissions');

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
    sentDeviceIds.add(deviceId);
    sentRoles.add(role);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }

  void emit(BleEvent event) => controller.add(event);
}

class FailingChatRepository implements ChatRepository {
  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async => [];

  @override
  Future<EmergencyChatMessage> insertMessage({
    required String sosId,
    required String text,
    String? messageId,
    String messageType = 'text',
    String? attachmentPath,
    String? attachmentMimeType,
    String? attachmentName,
  }) => throw StateError('not used');

  @override
  Future<void> updateDeliveryStatus(
    String messageId,
    ChatDeliveryStatus status,
  ) => throw StateError('not used');

  @override
  Future<EmergencyChatMessage> insertIncomingMessage({
    required String messageId,
    required String sosId,
    required String senderId,
    required String text,
    required DateTime createdAt,
  }) => Future.error(const ChatRepositoryException('persistence failed'));
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
  late PersistentChatRepository chatRepository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    transport = FakeBleTransport();
    chatRepository = PersistentChatRepository(
      database: database,
      ownerId: 'owner-1',
    );
    coordinator = SosBleCoordinator(
      database: database,
      ownerId: 'owner-1',
      transport: transport,
      chatRepository: chatRepository,
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

  test('requests permission before native initialization', () {
    expect(transport.lifecycleCalls, ['permissions', 'initialize']);
  });

  test(
    'ignores BLE test messages without applying SOS envelope validation',
    () async {
      final message = BleMessage(
        id: 'ble-test-message',
        type: 'test',
        createdAt: DateTime.utc(2026, 1, 1),
        payload: const {'text': 'debug only'},
      );
      for (final frame in BleMessageCodec.encode(message)) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();

      expect(await database.select(database.bleInbox).get(), isEmpty);
      expect(await database.select(database.sosMessages).get(), isEmpty);
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
    'enqueues chat, frames it, and delivers only after matching chat ACK',
    () async {
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'chat-sos',
              ownerId: 'owner-1',
              type: 'emergency',
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final chat = await chatRepository.insertMessage(
        sosId: 'chat-sos',
        messageId: 'chat-1',
        text: 'Need assistance',
      );
      final row = await coordinator.enqueueChat(chat, destinationId: device.id);
      await coordinator.processDue();
      expect(
        _decodeSent(transport.sent).type,
        SosBleMessageKind.chatMessage.wireValue,
      );
      expect(
        (await chatRepository.loadMessages('chat-sos')).single.status,
        ChatDeliveryStatus.sent,
      );

      final ack = SosBleEnvelope.chatAcknowledgement(
        messageId: 'ack:chat-1',
        sosId: 'chat-sos',
        ackFor: row.messageId,
        ackStatus: SosBleAckStatus.persisted,
        createdAt: now,
      );
      for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
      expect(
        (await chatRepository.loadMessages('chat-sos')).single.status,
        ChatDeliveryStatus.delivered,
      );
    },
  );

  test('chat ACK from the wrong peer does not deliver the message', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'chat-sos-wrong-peer',
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final chat = await chatRepository.insertMessage(
      sosId: 'chat-sos-wrong-peer',
      messageId: 'chat-wrong-peer',
      text: 'Still waiting',
    );
    final row = await coordinator.enqueueChat(chat, destinationId: device.id);
    await coordinator.processDue();
    final ack = SosBleEnvelope.chatAcknowledgement(
      messageId: 'ack:chat-wrong-peer',
      sosId: chat.sosId,
      ackFor: row.messageId,
      ackStatus: SosBleAckStatus.persisted,
      createdAt: now,
    );
    for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
      transport.emit(
        BleEvent(
          type: 'data',
          device: const BleDevice(id: 'other-peer'),
          payload: frame,
        ),
      );
    }
    await _settle();
    expect(
      (await chatRepository.loadMessages(chat.sosId)).single.status,
      ChatDeliveryStatus.sent,
    );
  });

  test(
    'does not route an undirected chat to the first connected peer',
    () async {
      transport.emit(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'peer-2'),
        ),
      );
      await _settle();
      final now = DateTime.utc(2026, 1, 1);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'undirected-chat-sos',
              ownerId: 'owner-1',
              type: 'emergency',
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final chat = await chatRepository.insertMessage(
        sosId: 'undirected-chat-sos',
        messageId: 'undirected-chat-1',
        text: 'Must not guess recipient',
      );
      final row = await coordinator.enqueueChat(chat);
      await coordinator.processDue();
      expect(transport.sent, isEmpty);
      expect(row.destinationId, isNull);
    },
  );

  test('routes a destination-specific message only to that peer', () async {
    const peerA = BleDevice(id: 'peer-a');
    const peerB = BleDevice(id: 'peer-b');
    transport.emit(const BleEvent(type: 'connected', device: peerA));
    transport.emit(const BleEvent(type: 'connected', device: peerB));
    await _settle();
    final row = await coordinator.enqueueSos(_sos(), destinationId: peerA.id);
    await coordinator.processDue();
    expect(transport.sentDeviceIds, isNotEmpty);
    expect(transport.sentDeviceIds, everyElement(peerA.id));
    expect(transport.connectCalls, isNot(contains(peerB.id)));
    expect(row.destinationId, peerA.id);
  });

  test('a chat ACK cannot acknowledge an SOS outbox row', () async {
    final row = await coordinator.enqueueSos(_sos(), destinationId: device.id);
    await coordinator.processDue();
    final ack = SosBleEnvelope.chatAcknowledgement(
      messageId: 'chat-ack-for-sos',
      sosId: row.sosId,
      ackFor: row.messageId,
      ackStatus: SosBleAckStatus.persisted,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    expect(
      (await coordinatorFor(database).lookupOutbox(row.messageId))!.state,
      BleOutboxState.awaitingAcknowledgement.wireValue,
    );
  });

  test('duplicate chat ACKs are idempotent', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'duplicate-chat-ack-sos',
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final chat = await chatRepository.insertMessage(
      sosId: 'duplicate-chat-ack-sos',
      messageId: 'duplicate-chat-ack',
      text: 'One delivery',
    );
    final row = await coordinator.enqueueChat(chat, destinationId: device.id);
    await coordinator.processDue();
    final ack = SosBleEnvelope.chatAcknowledgement(
      messageId: 'ack:duplicate-chat-ack',
      sosId: chat.sosId,
      ackFor: row.messageId,
      ackStatus: SosBleAckStatus.persisted,
      createdAt: now,
    );
    final frames = BleMessageCodec.encode(ack.toBleMessage());
    for (var repeat = 0; repeat < 2; repeat++) {
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
    }
    expect(
      (await chatRepository.loadMessages(chat.sosId)).single.status,
      ChatDeliveryStatus.delivered,
    );
    expect(
      (await coordinatorFor(database).lookupOutbox(row.messageId))!.state,
      BleOutboxState.acknowledged.wireValue,
    );
  });

  test('chat persistence failure sends no positive ACK', () async {
    final failingTransport = FakeBleTransport();
    final failingCoordinator = SosBleCoordinator(
      database: database,
      ownerId: 'owner-1',
      transport: failingTransport,
      chatRepository: FailingChatRepository(),
      now: () => DateTime.utc(2026, 1, 1, 12),
      pollInterval: const Duration(hours: 1),
    );
    await failingCoordinator.start();
    failingTransport.emit(
      const BleEvent(
        type: 'connected',
        device: device,
        role: BleSessionRole.central,
      ),
    );
    final message = SosBleEnvelope.chatMessage(
      messageId: 'incoming-chat-failure',
      sosId: 'incoming-chat-failure-sos',
      senderDeviceId: device.id,
      chatSenderId: 'remote-user',
      chatText: 'Should be rejected',
      createdAt: DateTime.utc(2026, 1, 1),
    );
    final before = failingTransport.sent.length;
    for (final frame in BleMessageCodec.encode(message.toBleMessage())) {
      failingTransport.emit(
        BleEvent(type: 'data', device: device, payload: frame),
      );
    }
    await _settle();
    final ack = _decodeSent(failingTransport.sent.skip(before).toList());
    final envelope = SosBleEnvelope.fromBleMessage(ack);
    expect(envelope.kind, SosBleMessageKind.chatAcknowledgement);
    expect(envelope.ackStatus, SosBleAckStatus.rejected);
    await failingCoordinator.dispose();
    await failingTransport.dispose();
  });

  test('incoming chat is persisted before a positive chat ACK', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'incoming-chat-sos',
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final message = SosBleEnvelope.chatMessage(
      messageId: 'incoming-chat-1',
      sosId: 'incoming-chat-sos',
      senderDeviceId: device.id,
      chatSenderId: 'remote-user',
      chatText: 'I am safe',
      createdAt: now,
    );
    for (final frame in BleMessageCodec.encode(message.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    expect(
      (await chatRepository.loadMessages('incoming-chat-sos')).single.text,
      'I am safe',
    );
    expect(
      _decodeSent(transport.sent).type,
      SosBleMessageKind.chatAcknowledgement.wireValue,
    );
  });

  test('duplicate incoming chat delivery creates one chat record', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'duplicate-incoming-chat-sos',
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final message = SosBleEnvelope.chatMessage(
      messageId: 'duplicate-incoming-chat',
      sosId: 'duplicate-incoming-chat-sos',
      senderDeviceId: device.id,
      chatSenderId: 'remote-user',
      chatText: 'Exactly once locally',
      createdAt: now,
    );
    final frames = BleMessageCodec.encode(message.toBleMessage());
    for (var repeat = 0; repeat < 2; repeat++) {
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
    }
    expect(
      await chatRepository.loadMessages('duplicate-incoming-chat-sos'),
      hasLength(1),
    );
  });

  test('incoming SOS sender is used only as an explicit reply route', () async {
    final delivery = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'reply-route-delivery',
      senderDeviceId: device.id,
    );
    for (final frame in BleMessageCodec.encode(delivery.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    final chat = await chatRepository.insertMessage(
      sosId: _sos().id,
      messageId: 'reply-route-chat',
      text: 'Reply to the sender',
    );
    final before = transport.sent.length;
    final row = await coordinator.enqueueChat(chat);
    await coordinator.processDue();
    expect(row.destinationId, device.id);
    expect(transport.sentDeviceIds.skip(before), everyElement(device.id));
    expect(
      (await coordinatorFor(database).lookupOutbox(row.messageId))!
          .destinationId,
      device.id,
    );
    // The device identifier is only a BLE route; it is not treated as a user
    // identity or copied into the authenticated sender fields.
  });

  test('disconnect during chat delivery keeps the row retryable', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'disconnect-chat-sos',
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final chat = await chatRepository.insertMessage(
      sosId: 'disconnect-chat-sos',
      messageId: 'disconnect-chat',
      text: 'Retry after reconnect',
    );
    transport.emit(const BleEvent(type: 'disconnected', device: device));
    await _settle();
    final row = await coordinator.enqueueChat(chat, destinationId: device.id);
    await coordinator.processDue();
    expect(transport.sent, isEmpty);
    expect(transport.connectCalls, contains(device.id));
    expect(
      (await coordinatorFor(database).lookupOutbox(row.messageId))!.state,
      BleOutboxState.queued.wireValue,
    );
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

  test('GATT connection failure marks pending delivery retryable', () async {
    await coordinator.stop();
    final reconnectingCoordinator = SosBleCoordinator(
      database: database,
      ownerId: 'owner-1',
      transport: transport,
      chatRepository: chatRepository,
      now: () => DateTime.utc(2026, 1, 1, 12),
      pollInterval: const Duration(hours: 1),
    );
    await reconnectingCoordinator.start();
    final row = await reconnectingCoordinator.enqueueSos(
      _sos(),
      destinationId: 'unavailable-peer',
    );
    await reconnectingCoordinator.processDue();
    transport.emit(
      const BleEvent(
        type: 'error',
        device: BleDevice(id: 'unavailable-peer'),
        error: 'status 133',
      ),
    );
    await _settle();
    final stored = await coordinatorFor(database).lookupOutbox(row.messageId);
    expect(stored!.state, BleOutboxState.failed.wireValue);
    expect(stored.retryCount, 1);
    await reconnectingCoordinator.dispose();
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
