import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
import 'package:sos_app/features/nearby_ble/domain/location_ble_envelope.dart';
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
  void Function()? onSend;
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
    onSend?.call();
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
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) =>
      Stream.value(const []);

  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async => [];

  @override
  Future<EmergencyChatMessage> insertMessage({
    required String sosId,
    required String text,
    String? messageId,
    String? recipientId,
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
    String? recipientId,
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
    'concurrent duplicate SOS waits for persistence then receives an ACK',
    () async {
      final delivery = SosBleEnvelope.fromSosMessage(
        _sos(),
        messageId: 'incoming-concurrent-duplicate',
        senderDeviceId: device.id,
      );
      final frames = BleMessageCodec.encode(delivery.toBleMessage());
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();

      expect(await database.select(database.sosMessages).get(), hasLength(1));
      expect(await database.select(database.bleInbox).get(), hasLength(1));
      expect(transport.sent.length, greaterThanOrEqualTo(2));
    },
  );

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

  test('concurrent SOS and chat drains keep outbox rows isolated', () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: _sos().id,
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final chat = await chatRepository.insertMessage(
      sosId: _sos().id,
      messageId: 'mixed-chat-1',
      text: 'Separate delivery',
      recipientId: device.id,
    );
    final sosRow = await coordinator.enqueueSos(
      _sos(),
      destinationId: device.id,
    );
    final chatRow = await coordinator.enqueueChat(chat);

    await Future.wait([coordinator.processDue(), coordinator.processDue()]);

    final storedSos = await coordinatorFor(database)
        .lookupOutbox(sosRow.messageId);
    final storedChat = await coordinatorFor(database)
        .lookupOutbox(chatRow.messageId);
    expect(storedSos!.sosId, _sos().id);
    expect(storedSos.destinationId, device.id);
    expect(storedChat!.messageId, chat.id);
    expect(storedChat.sosId, chat.sosId);
    expect(storedChat.destinationId, device.id);
    expect(storedSos.state, BleOutboxState.awaitingAcknowledgement.wireValue);
    expect(storedChat.state, BleOutboxState.awaitingAcknowledgement.wireValue);
    expect(transport.sentDeviceIds, everyElement(device.id));
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

  test(
    'default incoming SOS retains its observed peer for a chat reply',
    () async {
      final delivery = SosBleEnvelope.fromSosMessage(
        _sos(),
        messageId: 'default-reply-route',
      );
      expect(delivery.senderDeviceId, isNull);
      for (final frame in BleMessageCodec.encode(delivery.toBleMessage())) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
      final inbox = await coordinatorFor(database)
          .lookupInbox(delivery.messageId);
      expect(inbox, isNotNull);
      expect(inbox!.senderDeviceId, device.id);
      final chat = await chatRepository.insertMessage(
        sosId: _sos().id,
        messageId: 'default-route-reply',
        text: 'synthetic reply',
      );
      final row = await coordinator.enqueueChat(chat);
      expect(row.destinationId, device.id);
      expect(
        (await database.select(database.sosMessages).getSingle()).ownerId,
        'owner-1',
      );
      expect(await database.select(database.sosSyncQueue).get(), isEmpty);
      expect(delivery.toJson().containsKey('senderDeviceId'), isFalse);
    },
  );

  test('another peer cannot replay a default SOS and receive an ACK', () async {
    final delivery = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'bound-default-delivery',
    );
    final frames = BleMessageCodec.encode(delivery.toBleMessage());
    for (final frame in frames) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    await coordinatorFor(database).lookupInbox(delivery.messageId);
    await _settle();
    final before = transport.sent.length;
    expect(before, greaterThan(0));
    const other = BleDevice(id: 'other-peer');
    transport.emit(const BleEvent(type: 'connected', device: other));
    for (var replay = 0; replay < 2; replay++) {
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: other, payload: frame));
      }
    }
    await _settle();
    await coordinatorFor(database).lookupInbox(delivery.messageId);
    await _settle();
    expect(transport.sent.length, before);
    expect(await database.select(database.bleInbox).get(), hasLength(1));
    expect(await database.select(database.sosMessages).get(), hasLength(1));
  });

  test(
    'same peer can re-ACK a default SOS without duplicate records',
    () async {
      final delivery = SosBleEnvelope.fromSosMessage(
        _sos(),
        messageId: 'default-retry-delivery',
      );
      final frames = BleMessageCodec.encode(delivery.toBleMessage());
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
      await coordinatorFor(database).lookupInbox(delivery.messageId);
      await _settle();
      final firstAckFrameCount = transport.sent.length;
      expect(firstAckFrameCount, greaterThan(0));
      for (final frame in frames) {
        transport.emit(BleEvent(type: 'data', device: device, payload: frame));
      }
      await _settle();
      await coordinatorFor(database).lookupInbox(delivery.messageId);
      await _settle();
      expect(transport.sent.length, firstAckFrameCount * 2);
      final inbox = await database.select(database.bleInbox).getSingle();
      expect(inbox.messageId, delivery.messageId);
      expect(inbox.senderDeviceId, device.id);
      expect(await database.select(database.sosMessages).get(), hasLength(1));
      expect(await database.select(database.sosSyncQueue).get(), isEmpty);
    },
  );

  test('legacy unbound SOS is not rebound from a replay', () async {
    final delivery = SosBleEnvelope.fromSosMessage(
      _sos(),
      messageId: 'legacy-unbound-delivery',
    );
    final repository = coordinatorFor(database);
    await repository.persistIncomingDelivery(delivery, ownerId: 'owner-1');
    final before = await repository.lookupInbox(delivery.messageId);
    expect(before!.senderDeviceId, isNull);
    for (final frame in BleMessageCodec.encode(delivery.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    final after = await repository.lookupInbox(delivery.messageId);
    await _settle();
    expect(after!.senderDeviceId, isNull);
    expect(after.payload, before.payload);
    expect(await repository.lookupReplyDestination(_sos().id), isNull);
    expect(transport.sent, isEmpty);
    expect(await database.select(database.bleInbox).get(), hasLength(1));
    expect(
      (await database.select(database.sosMessages).getSingle()).ownerId,
      'owner-1',
    );
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

  test(
    'repeated asynchronous GATT failures consume the bounded retry budget',
    () async {
      await coordinator.stop();
      var clock = DateTime.utc(2026, 1, 1, 12);
      final retrying = SosBleCoordinator(
        database: database,
        ownerId: 'owner-1',
        transport: transport,
        chatRepository: chatRepository,
        now: () => clock,
        random: () => 0,
        maxRetryAttempts: 3,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(retrying.dispose);
      await retrying.start();
      final row = await retrying.enqueueSos(_sos(), destinationId: 'gatt-peer');
      final repository = coordinatorFor(database);
      for (var attempt = 1; attempt <= 3; attempt++) {
        await retrying.processDue();
        expect(
          transport.connectCalls.where((id) => id == 'gatt-peer'),
          hasLength(attempt),
        );
        // Native connect returns before its asynchronous failure callback.
        transport.emit(
          const BleEvent(
            type: 'error',
            device: BleDevice(id: 'gatt-peer'),
            error: 'status 133',
          ),
        );
        BleOutboxData? stored;
        for (var turn = 0; turn < 100; turn++) {
          await _settle();
          stored = await repository.lookupOutbox(row.messageId);
          if (stored?.retryCount == attempt &&
              (stored?.state == BleOutboxState.failed.wireValue ||
                  stored?.state == BleOutboxState.expired.wireValue)) {
            break;
          }
        }
        expect(stored!.retryCount, attempt);
        if (attempt < 3) {
          expect(stored.state, BleOutboxState.failed.wireValue);
          await retrying.processDue();
          expect(
            transport.connectCalls.where((id) => id == 'gatt-peer'),
            hasLength(attempt),
          );
          clock = stored.nextRetryAt!;
        } else {
          expect(stored.state, BleOutboxState.expired.wireValue);
        }
      }
      clock = clock.add(const Duration(hours: 1));
      await retrying.processDue();
      expect(
        transport.connectCalls.where((id) => id == 'gatt-peer'),
        hasLength(3),
      );
      expect(await repository.lookupOutbox(row.messageId), isNotNull);
    },
  );

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
    'process restart recovers the durable queue and sends the same message ID',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sos-coordinator-restart-',
      );
      final file = File('${directory.path}/database.sqlite');
      final queuedAt = DateTime.utc(2026, 1, 1, 12);
      const messageId = 'restart-process-message';
      try {
        final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
        await firstDatabase.into(firstDatabase.sosMessages).insert(_sos());
        final firstTransport = FakeBleTransport();
        final firstCoordinator = SosBleCoordinator(
          database: firstDatabase,
          ownerId: 'owner-1',
          transport: firstTransport,
          now: () => queuedAt,
          pollInterval: const Duration(hours: 1),
        );
        await firstCoordinator.enqueueSos(
          _sos(),
          destinationId: device.id,
          messageId: messageId,
        );
        await BleDeliveryRepository(firstDatabase).transitionOutboxState(
          messageId,
          BleOutboxState.sending,
          now: queuedAt,
        );
        await firstCoordinator.dispose();
        await firstTransport.controller.close();
        await firstDatabase.close();

        final secondDatabase = AppDatabase.forTesting(NativeDatabase(file));
        final secondTransport = FakeBleTransport();
        final secondCoordinator = SosBleCoordinator(
          database: secondDatabase,
          ownerId: 'owner-1',
          transport: secondTransport,
          now: () => queuedAt.add(const Duration(minutes: 1)),
          staleAfter: const Duration(seconds: 30),
          pollInterval: const Duration(hours: 1),
        );
        final starting = secondCoordinator.start();
        secondTransport.emit(const BleEvent(type: 'connected', device: device));
        await starting;

        expect(_decodeSent(secondTransport.sent).id, messageId);
        final recovered = await BleDeliveryRepository(secondDatabase)
            .lookupOutbox(messageId);
        expect(
          recovered!.state,
          BleOutboxState.awaitingAcknowledgement.wireValue,
        );
        expect(recovered.messageId, messageId);
        expect(
          await secondDatabase.select(secondDatabase.bleOutbox).get(),
          hasLength(1),
        );
        await secondCoordinator.dispose();
        await secondTransport.controller.close();
        await secondDatabase.close();
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

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

  test(
    'location sharing requires enablement and stops for cancelled SOS',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'sos-location',
              ownerId: 'owner-1',
              type: 'emergency',
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(
        () => coordinator.publishLocationUpdate(
          sosId: 'sos-location',
          messageId: 'location-before-enable',
          destinationId: device.id,
          latitude: 13.7,
          longitude: 100.5,
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );

      await coordinator.enableLocationSharing(
        sosId: 'sos-location',
        destinationId: device.id,
      );
      final queued = await coordinator.publishLocationUpdate(
        sosId: 'sos-location',
        messageId: 'location-enabled',
        destinationId: device.id,
        latitude: 13.7,
        longitude: 100.5,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      );
      expect(queued.destinationId, device.id);

      await coordinator.disableLocationSharing('sos-location');
      expect(
        () => coordinator.publishLocationUpdate(
          sosId: 'sos-location',
          messageId: 'location-after-stop',
          destinationId: device.id,
          latitude: 13.7,
          longitude: 100.5,
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );

      await coordinator.enableLocationSharing(
        sosId: 'sos-location',
        destinationId: device.id,
      );
      await (database.update(database.sosMessages)
            ..where((table) => table.id.equals('sos-location')))
          .write(const SosMessagesCompanion(status: Value('cancelled')));
      expect(
        () => coordinator.publishLocationUpdate(
          sosId: 'sos-location',
          messageId: 'location-after-cancel',
          destinationId: device.id,
          latitude: 13.7,
          longitude: 100.5,
          createdAt: now,
          expiresAt: now.add(const Duration(minutes: 1)),
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );
    },
  );

  test(
    'retries of a persisted location update receive a duplicate ACK',
    () async {
      transport.emit(
        const BleEvent(
          type: 'connected',
          device: device,
          role: BleSessionRole.peripheral,
        ),
      );
      await _settle();
      final update = LocationBleEnvelope.update(
        messageId: 'location-retry-same-id',
        sosId: 'sos-location-retry',
        senderDeviceId: device.id,
        recipientId: 'owner-1',
        latitude: 13.7,
        longitude: 100.5,
        createdAt: DateTime.utc(2026, 1, 1, 12),
        expiresAt: DateTime.utc(2026, 1, 1, 12, 1),
      );
      final frames = BleMessageCodec.encode(update.toBleMessage());

      Future<void> deliver() async {
        for (final frame in frames) {
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
      }

      await deliver();
      final firstAckCount = transport.sent.length;
      await deliver();

      final inbox = await database.select(database.bleInbox).get();
      expect(inbox, hasLength(1));
      expect(transport.sent.length, firstAckCount * 2);
      final ack = _decodeSent(transport.sent.sublist(firstAckCount));
      expect(ack.type, 'location.ack');
      expect(ack.payload['ackFor'], update.messageId);
      expect(ack.payload['ackStatus'], 'persisted');
    },
  );

  test(
    'authenticated BLE session only drains its owner and stops on auth change',
    () async {
      await coordinator.dispose();
      final delivery = BleDeliveryRepository(database);
      for (final owner in ['A', 'B', 'guest-local-device']) {
        final sos = _sos().copyWith(
          id: 'sos-$owner',
          ownerId: owner,
          syncState: 'synced',
        );
        await database.into(database.sosMessages).insert(sos.toCompanion(true));
        await delivery.enqueueOutbox(
          SosBleEnvelope.fromSosMessage(sos, messageId: 'message-$owner'),
          destinationId: device.id,
          now: DateTime.utc(2026, 1, 1, 12),
        );
      }
      final others = await (database.select(
        database.bleOutbox,
      )..where((t) => t.messageId.isNotValue('message-A'))).get();
      var sessionActive = true;
      coordinator = SosBleCoordinator(
        database: database,
        ownerId: 'A',
        transport: transport,
        isSessionCurrent: () => sessionActive,
        now: () => DateTime.utc(2026, 1, 1, 12),
        pollInterval: const Duration(hours: 1),
      );
      await coordinator.start();
      transport.emit(const BleEvent(type: 'connected', device: device));
      await _settle();
      await coordinator.processDue();
      expect(transport.sent, isNotEmpty);
      expect(_decodeSent(transport.sent).payload['sosId'], 'sos-A');
      expect(
        await (database.select(
          database.bleOutbox,
        )..where((t) => t.messageId.isNotValue('message-A'))).get(),
        others,
      );
      final before = await database.select(database.bleOutbox).get();
      sessionActive = false;
      await coordinator.processDue();
      transport.emit(const BleEvent(type: 'connected', device: device));
      await _settle();
      expect(await database.select(database.bleOutbox).get(), before);
    },
  );

  test(
    'auth changes between BLE frames stop the old session immediately',
    () async {
      await coordinator.dispose();
      var sessionActive = true;
      final sos = _sos().copyWith(
        message: Value('x' * 1000),
        syncState: 'synced',
      );
      await database.into(database.sosMessages).insert(sos.toCompanion(true));
      coordinator = SosBleCoordinator(
        database: database,
        ownerId: sos.ownerId,
        transport: transport,
        isSessionCurrent: () => sessionActive,
        now: () => DateTime.utc(2026, 1, 1, 12),
        pollInterval: const Duration(hours: 1),
      );
      await coordinator.enqueueSos(sos, destinationId: device.id);
      transport.onSend = () => sessionActive = false;
      await coordinator.start();
      transport.emit(const BleEvent(type: 'connected', device: device));
      await _settle();
      await coordinator.processDue();
      expect(transport.sent, hasLength(1));
      final row = await database.select(database.bleOutbox).getSingle();
      expect(row.messageId, 'sos:sos-1:delivery:v1');
      expect(row.state, BleOutboxState.sending.wireValue);
      expect(row.payload, contains('x' * 1000));
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
