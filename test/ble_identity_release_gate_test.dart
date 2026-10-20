// Release-gate reproducers asserting required two-endpoint behavior.
// Uses the production capability exchange over two independent fake radios.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/location_ble_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';

import 'sos_ble_coordinator_test.dart' show FakeBleTransport;

class PairedRadio extends FakeBleTransport {
  PairedRadio(this.source);
  final String source;
  late PairedRadio other;
  bool forward = true;
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {
    await super.send(deviceId, frame, role: role);
    if (forward) {
      other.emit(
        BleEvent(
          type: 'data',
          device: BleDevice(id: source),
          payload: frame,
          role: role,
        ),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase senderDb;
  late AppDatabase receiverDb;
  late PairedRadio senderRadio;
  late PairedRadio receiverRadio;
  late SosBleCoordinator sender;
  late SosBleCoordinator receiver;
  late PersistentChatRepository senderChat;
  late PersistentChatRepository receiverChat;
  late List<String> receiverLogs;
  final now = DateTime.now().toUtc();
  const receiverRoute = 'synthetic-radio-B';
  const senderRoute = 'synthetic-radio-A';

  setUp(() async {
    senderDb = AppDatabase.forTesting(NativeDatabase.memory());
    receiverDb = AppDatabase.forTesting(NativeDatabase.memory());
    senderRadio = PairedRadio(senderRoute);
    receiverRadio = PairedRadio(receiverRoute);
    senderRadio.other = receiverRadio;
    receiverRadio.other = senderRadio;
    receiverLogs = [];
    senderChat = PersistentChatRepository(
      database: senderDb,
      ownerId: 'test-account-A',
      senderId: 'install-A',
    );
    receiverChat = PersistentChatRepository(
      database: receiverDb,
      ownerId: 'test-account-B',
      senderId: 'install-B',
    );
    sender = SosBleCoordinator(
      database: senderDb,
      ownerId: 'test-account-A',
      localDeviceId: 'install-A',
      requirePeerBinding: true,
      transport: senderRadio,
      chatRepository: senderChat,
      now: () => now,
      pollInterval: const Duration(hours: 1),
    );
    receiver = SosBleCoordinator(
      database: receiverDb,
      ownerId: 'test-account-B',
      localDeviceId: 'install-B',
      requirePeerBinding: true,
      transport: receiverRadio,
      chatRepository: receiverChat,
      now: () => now,
      pollInterval: const Duration(hours: 1),
      onLog: receiverLogs.add,
    );
    for (final pair in [
      (senderDb, 'test-account-A'),
      (receiverDb, 'test-account-B'),
    ]) {
      await pair.$1
          .into(pair.$1.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'synthetic-incident',
              ownerId: pair.$2,
              type: 'emergency',
              status: 'active',
              syncState: 'synced',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await sender.start();
    await receiver.start();
    senderRadio.emit(
      const BleEvent(
        type: 'connected',
        device: BleDevice(id: receiverRoute),
      ),
    );
    receiverRadio.emit(
      const BleEvent(
        type: 'connected',
        device: BleDevice(id: senderRoute),
      ),
    );
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(Duration.zero);
      if (receiverLogs.contains('peerSessionBound')) break;
    }
    expect(receiverLogs, contains('peerSessionBound'));
    senderRadio.forward = false;
    await BleDeliveryRepository(receiverDb).assignDestinationIfMissing(
      'sos:synthetic-incident:delivery:v1',
      senderRoute,
    );
    await receiver.processDue();
  });

  tearDown(() async {
    await sender.dispose();
    await receiver.dispose();
    await senderRadio.controller.close();
    await receiverRadio.controller.close();
    await senderDb.close();
    await receiverDb.close();
  });

  Future<void> feedReceiver(
    BleMessage message,
    Future<bool> Function() settled, {
    String source = senderRoute,
  }) async {
    for (final frame in BleMessageCodec.encode(message)) {
      receiverRadio.emit(
        BleEvent(
          type: 'data',
          device: BleDevice(id: source),
          payload: frame,
        ),
      );
    }
    // Flush asynchronous SQL and ACK handling; the condition also detects a
    // deterministic rejection rather than depending on a fixed wall-clock wait.
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(Duration.zero);
      if (await settled()) return;
    }
  }

  test('release gate: default outgoing Chat must persist on a distinct transport peer', () async {
    final chat = await senderChat.insertMessage(
      sosId: 'synthetic-incident',
      text: 'synthetic test only',
      messageId: 'synthetic-chat',
    );
    final queued = await sender.enqueueChat(chat, destinationId: receiverRoute);
    final envelope = SosBleEnvelope.fromBleMessage(
      BleMessage(
        id: queued.messageId,
        type: 'chat.message',
        payload: Map<String, Object?>.from(jsonDecode(queued.payload) as Map),
        createdAt: chat.createdAt,
      ),
    );
    await feedReceiver(
      envelope.toBleMessage(),
      () async => receiverLogs.any(
        (line) =>
            line.contains('Rejected BLE SOS envelope') ||
            line.contains('chatPersisted'),
      ),
    );
    final received = await receiverChat.loadMessages('synthetic-incident');
    final reason = receiverLogs
        .where((line) => line.contains('Rejected BLE SOS envelope'))
        .join('\n');
    expect(received, hasLength(1), reason: reason);
  });

  test('release gate: default outgoing Location must persist on a distinct recipient', () async {
    await sender.enableLocationSharing(
      sosId: 'synthetic-incident',
      destinationId: receiverRoute,
    );
    final queued = await sender.publishLocationUpdate(
      sosId: 'synthetic-incident',
      messageId: 'synthetic-location',
      destinationId: receiverRoute,
      latitude: 1,
      longitude: 1,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    );
    final envelope = LocationBleEnvelope.fromBleMessage(
      BleMessage(
        id: queued.messageId,
        type: 'location.update',
        payload: Map<String, Object?>.from(jsonDecode(queued.payload) as Map),
        createdAt: now,
      ),
    );
    await feedReceiver(
      envelope.toBleMessage(),
      () async => receiverLogs.any(
        (line) =>
            line.contains('locationPersistRejected') ||
            line.contains('locationPersisted'),
      ),
    );
    final received = await receiverDb.select(receiverDb.bleInbox).get();
    final reason = receiverLogs
        .where((line) => line.contains('locationPersistRejected'))
        .join('\n');
    expect(received, hasLength(1), reason: reason);
  });
  SosBleEnvelope chatEnvelope({
    String id = 'chat-negative',
    String senderId = 'install-A',
    String sosId = 'synthetic-incident',
    String text = 'test',
  }) => SosBleEnvelope.chatMessage(
    messageId: id,
    sosId: sosId,
    senderDeviceId: senderId,
    chatSenderId: senderId,
    chatText: text,
    createdAt: now,
  );

  LocationBleEnvelope locationEnvelope({
    String id = 'location-negative',
    String senderId = 'install-A',
    String recipient = 'install-B',
    String sosId = 'synthetic-incident',
  }) => LocationBleEnvelope.update(
    messageId: id,
    sosId: sosId,
    senderDeviceId: senderId,
    recipientId: recipient,
    latitude: 1,
    longitude: 1,
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 5)),
  );

  Future<void> feed(BleMessage message, {String source = senderRoute}) =>
      feedReceiver(message, () async => false, source: source);

  test(
    'bound Chat from a different native peer is not persisted or ACKed',
    () async {
      final before = receiverRadio.sent.length;
      await feed(chatEnvelope().toBleMessage(), source: 'wrong-radio');
      expect(await receiverChat.loadMessages('synthetic-incident'), isEmpty);
      expect(receiverRadio.sent.length, before);
    },
  );

  test('bound peer cannot claim a different logical Chat sender', () async {
    final before = receiverRadio.sent.length;
    await feed(chatEnvelope(senderId: 'install-forged').toBleMessage());
    expect(await receiverChat.loadMessages('synthetic-incident'), isEmpty);
    expect(receiverRadio.sent.length, before);
  });

  test('bound Chat for an unrelated incident is not accepted', () async {
    final before = receiverRadio.sent.length;
    await feed(chatEnvelope(sosId: 'unrelated').toBleMessage());
    expect(await receiverDb.select(receiverDb.chatMessages).get(), isEmpty);
    expect(receiverRadio.sent.length, before);
  });

  test('same-peer Chat retry persists once and emits another ACK', () async {
    final message = chatEnvelope().toBleMessage();
    await feed(message);
    final afterFirst = receiverRadio.sent.length;
    await feed(message);
    expect(await receiverChat.loadMessages('synthetic-incident'), hasLength(1));
    expect(receiverRadio.sent.length, greaterThan(afterFirst));
  });

  test(
    'Location with a different recipient is neither persisted nor ACKed',
    () async {
      final before = receiverRadio.sent.length;
      await feed(locationEnvelope(recipient: 'install-C').toBleMessage());
      expect(await receiverDb.select(receiverDb.bleInbox).get(), isEmpty);
      expect(receiverRadio.sent.length, before);
    },
  );

  test(
    'Location from wrong native peer is neither persisted nor ACKed',
    () async {
      final before = receiverRadio.sent.length;
      await feed(locationEnvelope().toBleMessage(), source: 'wrong-radio');
      expect(await receiverDb.select(receiverDb.bleInbox).get(), isEmpty);
      expect(receiverRadio.sent.length, before);
    },
  );

  test(
    'same-peer Location retry retains one row and sends another ACK',
    () async {
      final message = locationEnvelope().toBleMessage();
      await feed(message);
      final afterFirst = receiverRadio.sent.length;
      await feed(message);
      expect(await receiverDb.select(receiverDb.bleInbox).get(), hasLength(1));
      expect(receiverRadio.sent.length, greaterThan(afterFirst));
    },
  );

  test('disconnect invalidates the logical-to-native Chat binding', () async {
    receiverRadio.emit(
      const BleEvent(
        type: 'disconnected',
        device: BleDevice(id: senderRoute),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    final before = receiverRadio.sent.length;
    await feed(chatEnvelope().toBleMessage());
    expect(await receiverChat.loadMessages('synthetic-incident'), isEmpty);
    expect(receiverRadio.sent.length, before);
  });

  test('stale binding response cannot replace a current identity', () async {
    await feed(
      BleMessage(
        id: 'stale-binding',
        type: 'peer.binding.v1',
        createdAt: now,
        payload: {
          'identity': 'forged',
          'nonce': 'a' * 32,
          'responseTo': 'b' * 32,
        },
      ),
    );
    await feed(chatEnvelope().toBleMessage());
    expect(await receiverChat.loadMessages('synthetic-incident'), hasLength(1));
  });

  test(
    'bound Location completes full persistence and application ACK path',
    () async {
      await sender.enableLocationSharing(
        sosId: 'synthetic-incident',
        destinationId: receiverRoute,
      );
      senderRadio.forward = true;
      await sender.publishLocationUpdate(
        sosId: 'synthetic-incident',
        messageId: 'full-path-location',
        destinationId: receiverRoute,
        latitude: 1,
        longitude: 1,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      await sender.processDue();
      final delivery = BleDeliveryRepository(senderDb);
      for (var i = 0; i < 300; i++) {
        if ((await delivery.lookupOutbox('full-path-location'))?.state ==
            'acknowledged') {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        (await delivery.lookupOutbox('full-path-location'))?.state,
        'acknowledged',
      );
      expect(await receiverDb.select(receiverDb.bleInbox).get(), hasLength(1));
    },
  );

  test('concurrent same-ID different Chat content never gets a positive duplicate ACK', () async {
    receiverRadio.sent.clear();
    await Future.wait([
      feed(chatEnvelope(text: 'original').toBleMessage()),
      feed(chatEnvelope(text: 'changed').toBleMessage()),
    ]);
    final rows = await receiverChat.loadMessages('synthetic-incident');
    expect(rows, hasLength(1));
    expect(rows.single.text, 'original');
    final assembler = BleMessageAssembler(dropDuplicateMessages: false);
    final acks = receiverRadio.sent
        .map(assembler.accept)
        .whereType<BleMessage>()
        .where((m) => m.type == 'chat.ack')
        .map(SosBleEnvelope.fromBleMessage)
        .toList();
    expect(
      acks.where((a) => a.ackStatus == SosBleAckStatus.persisted),
      hasLength(1),
    );
  });
  test(
    'asymmetric readiness still binds both peers and confirms full Chat path',
    () async {
      senderRadio.emit(
        const BleEvent(
          type: 'disconnected',
          device: BleDevice(id: receiverRoute),
        ),
      );
      receiverRadio.emit(
        const BleEvent(
          type: 'disconnected',
          device: BleDevice(id: senderRoute),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      senderRadio.forward = true;
      receiverRadio.forward = false;
      senderRadio.emit(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: receiverRoute),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      receiverRadio.forward = true;
      receiverRadio.emit(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: senderRoute),
        ),
      );
      for (var i = 0; i < 200; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final chat = await senderChat.insertMessage(
        sosId: 'synthetic-incident',
        text: 'full chat',
        messageId: 'full-path-chat',
      );
      await sender.enqueueChat(chat, destinationId: receiverRoute);
      await sender.processDue();
      final delivery = BleDeliveryRepository(senderDb);
      for (var i = 0; i < 300; i++) {
        if ((await delivery.lookupOutbox(chat.id))?.state == 'acknowledged') {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }
      expect((await delivery.lookupOutbox(chat.id))?.state, 'acknowledged');
      expect(
        (await senderChat.loadMessages(chat.sosId)).single.status,
        ChatDeliveryStatus.delivered,
      );
      expect(await receiverChat.loadMessages(chat.sosId), hasLength(1));
    },
  );
  test(
    'bound radio cannot impersonate the local Chat author identity',
    () async {
      final before = receiverRadio.sent.length;
      final forged = SosBleEnvelope.chatMessage(
        messageId: 'forged-author',
        sosId: 'synthetic-incident',
        senderDeviceId: 'install-A',
        chatSenderId: 'install-B',
        chatText: 'forged',
        createdAt: now,
      );
      await feed(forged.toBleMessage());
      expect(await receiverChat.loadMessages('synthetic-incident'), isEmpty);
      expect(receiverRadio.sent.length, before);
    },
  );
  test('unbound Chat does not block SOS or consume retry attempts with an old peer', () async {
    senderRadio.emit(
      const BleEvent(
        type: 'disconnected',
        device: BleDevice(id: receiverRoute),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    receiverRadio.forward = false;
    senderRadio.forward = true;
    senderRadio.emit(
      const BleEvent(
        type: 'connected',
        device: BleDevice(id: receiverRoute),
      ),
    );
    final chat = await senderChat.insertMessage(
      sosId: 'synthetic-incident',
      messageId: 'unbound-chat',
      text: 'waiting for compatible peer',
    );
    await sender.enqueueChat(chat, destinationId: receiverRoute);
    await sender.assignSosDestination('synthetic-incident', receiverRoute);
    await sender.processDue();
    final repository = BleDeliveryRepository(senderDb);
    final queued = (await repository.lookupOutbox(chat.id))!;
    expect(queued.state, 'queued');
    expect(queued.retryCount, 0);
    final assembler = BleMessageAssembler(dropDuplicateMessages: false);
    final messages = senderRadio.sent
        .map(assembler.accept)
        .whereType<BleMessage>();
    expect(messages.any((m) => m.type == 'sos.delivery'), isTrue);
    expect(messages.any((m) => m.type == 'chat.message'), isFalse);
  });
  test(
    'SOS author can reply through its explicitly selected incident destination',
    () async {
      await senderDb.delete(senderDb.bleInbox).go();
      expect(
        await BleDeliveryRepository(senderDb)
            .lookupReplyDestination('synthetic-incident'),
        isNull,
      );
      await sender.assignSosDestination('synthetic-incident', receiverRoute);
      await sender.processDue();
      final chat = await senderChat.insertMessage(
        sosId: 'synthetic-incident',
        text: 'reply without another picker',
        messageId: 'incident-route-chat',
      );
      final queued = await sender.enqueueChat(chat);
      expect(queued.destinationId, receiverRoute);
      expect(queued.messageId, chat.id);
      expect(queued.payload, contains('install-A'));
    },
  );
  test(
    'late Location without a logical sender cannot persist after disconnect',
    () async {
      receiverRadio.emit(
        const BleEvent(
          type: 'disconnected',
          device: BleDevice(id: senderRoute),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final original = locationEnvelope().toBleMessage();
      final payload = Map<String, Object?>.from(original.payload)
        ..remove('senderDeviceId');
      await feed(
        BleMessage(
          id: original.id,
          type: original.type,
          createdAt: original.createdAt,
          payload: payload,
        ),
      );
      expect(await receiverDb.select(receiverDb.bleInbox).get(), isEmpty);
    },
  );

  test(
    'unbound Location ACK without a logical sender cannot confirm delivery',
    () async {
      receiverRadio.forward = false;
      await receiver.enableLocationSharing(
        sosId: 'synthetic-incident',
        destinationId: senderRoute,
      );
      await receiver.publishLocationUpdate(
        sosId: 'synthetic-incident',
        messageId: 'unbound-ack-location',
        destinationId: senderRoute,
        latitude: 1,
        longitude: 1,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      await receiver.processDue();
      receiverRadio.emit(
        const BleEvent(
          type: 'disconnected',
          device: BleDevice(id: senderRoute),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final ack = LocationBleEnvelope.ack(
        messageId: 'missing-sender-ack',
        sosId: 'synthetic-incident',
        ackFor: 'unbound-ack-location',
        ackStatus: 'persisted',
        createdAt: now,
      );
      await feed(ack.toBleMessage());
      expect(
        (await BleDeliveryRepository(receiverDb)
                .lookupOutbox('unbound-ack-location'))!
            .state,
        isNot('acknowledged'),
      );
    },
  );
}
