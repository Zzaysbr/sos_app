import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/hop_relay_coordinator.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

class _MemoryKeyStore implements RelayPrivateKeyStore {
  List<int>? seed;
  bool failReads = false;

  @override
  Future<List<int>?> readSeed() async {
    if (failReads) {
      throw const RelayKeyStoreException('secure storage unavailable');
    }
    return seed == null ? null : List<int>.from(seed!);
  }

  @override
  Future<void> writeSeed(List<int> seed) async {
    this.seed = List<int>.from(seed);
  }
}

class _FailingHopRelayCoordinator extends Mock implements HopRelayCoordinator {}

class _LinkedTransport implements BleTransportClient {
  _LinkedTransport(this.id);

  final String id;
  final controller = StreamController<BleEvent>.broadcast();
  final outboundAssemblers = <String, BleMessageAssembler>{};
  final dropMessageTypes = <String>{};
  final sentMessages = <BleMessage>[];
  final remotes = <_LinkedTransport>[];
  Future<void> Function()? beforeFrameSend;
  Future<void> Function(BleMessage message)? beforeMessageDelivery;
  Future<void> Function(BleMessage message)? afterMessageDelivery;
  bool deferCapabilityUntilChallenge = false;
  BleMessage? _deferredCapability;
  Completer<void>? advertisingStarted;
  Future<void>? advertisingBlock;
  bool advertising = false;
  bool discovering = false;
  bool failConnections = false;
  int connectCount = 0;
  final connectedPeers = <String>[];
  final disconnectedPeers = <String>[];

  void link(_LinkedTransport other) {
    if (!remotes.contains(other)) remotes.add(other);
    if (!other.remotes.contains(this)) other.remotes.add(this);
  }

  _LinkedTransport? _remote(String deviceId) {
    for (final candidate in remotes) {
      if (candidate.id == deviceId) return candidate;
    }
    return null;
  }

  @override
  Stream<BleEvent> get events => controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> startAdvertising({String? name}) async {
    if (!(advertisingStarted?.isCompleted ?? true)) {
      advertisingStarted!.complete();
    }
    await advertisingBlock;
    advertising = true;
    for (final other in remotes.where((candidate) => candidate.discovering)) {
      other.controller.add(
        BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: id, name: name),
        ),
      );
    }
  }

  @override
  Future<void> stopAdvertising() async => advertising = false;

  @override
  Future<void> startDiscovery() async {
    discovering = true;
    for (final other in remotes.where((candidate) => candidate.advertising)) {
      controller.add(
        BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: other.id, name: 'Relay peer'),
        ),
      );
    }
  }

  @override
  Future<void> stopDiscovery() async => discovering = false;

  @override
  Future<void> connect(String deviceId) async {
    final other = _remote(deviceId);
    if (other == null) {
      throw const BleTransportException('Unknown linked peer.');
    }
    connectCount++;
    connectedPeers.add(deviceId);
    if (failConnections) {
      throw const BleTransportException('Simulated connection failure.');
    }
    controller.add(
      BleEvent(
        type: 'connected',
        device: BleDevice(id: other.id),
        role: BleSessionRole.central,
      ),
    );
    other.controller.add(
      BleEvent(
        type: 'connected',
        device: BleDevice(id: id),
        role: BleSessionRole.peripheral,
      ),
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectedPeers.add(deviceId);
    final other = _remote(deviceId);
    controller.add(
      BleEvent(
        type: 'disconnected',
        device: BleDevice(id: deviceId),
      ),
    );
    if (other != null) {
      other.controller.add(
        BleEvent(
          type: 'disconnected',
          device: BleDevice(id: id),
        ),
      );
    }
  }

  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {
    final beforeSend = beforeFrameSend;
    if (beforeSend != null) await beforeSend();
    final other = _remote(deviceId);
    if (other == null) {
      throw const BleTransportException('Unknown linked peer.');
    }
    final assemblerKey = '$deviceId|${role?.wireValue ?? 'central'}';
    final message = outboundAssemblers
        .putIfAbsent(
          assemblerKey,
          () => BleMessageAssembler(dropDuplicateMessages: false),
        )
        .accept(frame);
    if (message == null) return;
    final beforeDelivery = beforeMessageDelivery;
    if (beforeDelivery != null) await beforeDelivery(message);
    sentMessages.add(message);
    if (dropMessageTypes.contains(message.type)) return;
    if (deferCapabilityUntilChallenge &&
        message.type == RelayCapabilityAdvertisement.wireKind) {
      _deferredCapability = message;
      return;
    }
    await _deliverMessage(other, message, role);
    final afterDelivery = afterMessageDelivery;
    if (afterDelivery != null) await afterDelivery(message);
    if (deferCapabilityUntilChallenge &&
        message.type == RelaySessionChallenge.wireKind) {
      final deferred = _deferredCapability;
      _deferredCapability = null;
      if (deferred != null) await _deliverMessage(other, deferred, role);
    }
  }

  Future<void> _deliverMessage(
    _LinkedTransport other,
    BleMessage message,
    BleSessionRole? role,
  ) async {
    final receiverRole = role == BleSessionRole.central
        ? BleSessionRole.peripheral
        : BleSessionRole.central;
    for (final deliveredFrame in BleMessageCodec.encode(message)) {
      other.controller.add(
        BleEvent(
          type: 'data',
          device: BleDevice(id: id),
          payload: deliveredFrame,
          role: receiverRole,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async => controller.close();
}

class _RelayNode {
  _RelayNode({
    required this.database,
    required this.transport,
    required this.now,
    RelayPrivateKeyStore? keyStore,
    Duration proofTimeout = const Duration(seconds: 15),
  }) {
    coordinator = HopRelayCoordinator(
      database: database,
      transport: transport,
      identityService: RelayIdentityService(
        keyStore: keyStore ?? _MemoryKeyStore(),
      ),
      now: now,
      ackTimeout: const Duration(seconds: 30),
      retryBase: Duration.zero,
      proofTimeout: proofTimeout,
      onLog: logs.add,
    );
  }

  final AppDatabase database;
  final _LinkedTransport transport;
  final DateTime Function() now;
  late final HopRelayCoordinator coordinator;
  final assemblers = <String, BleMessageAssembler>{};
  final errors = <Object>[];
  final logs = <String>[];
  StreamSubscription<BleEvent>? subscription;

  Future<void> start() async {
    subscription = transport.events.listen((event) async {
      try {
        await coordinator.onEvent(event);
        final payload = event.payload;
        final peer = event.device?.id;
        if (event.type != 'data' || payload == null || peer == null) return;
        final key = '$peer|${event.role?.wireValue ?? 'central'}';
        final assembler = assemblers.putIfAbsent(
          key,
          () => BleMessageAssembler(dropDuplicateMessages: false),
        );
        final message = assembler.accept(payload, now: now());
        if (message != null) {
          await coordinator.handleMessage(
            peer,
            event.role ?? BleSessionRole.central,
            message,
          );
        }
      } on Object catch (error) {
        errors.add(error);
      }
    });
    await coordinator.start();
  }

  Future<void> close() async {
    await coordinator.stop();
    await subscription?.cancel();
    await transport.dispose();
    await database.close();
  }
}

SosMessage _sos(String id, DateTime now) => SosMessage(
  id: id,
  ownerId: 'guest:test',
  type: 'emergency',
  message: 'Test emergency',
  latitude: 13.7,
  longitude: 100.5,
  status: 'active',
  syncState: 'localOnly',
  createdAt: now,
  updatedAt: now,
);

Future<void> _eventually(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for relay condition.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default proof window covers measured physical BLE response time', () {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final transport = _LinkedTransport('device-a');
    final coordinator = HopRelayCoordinator(
      database: database,
      transport: transport,
      identityService: RelayIdentityService(keyStore: _MemoryKeyStore()),
    );
    addTearDown(coordinator.stop);
    addTearDown(transport.dispose);
    addTearDown(database.close);

    expect(coordinator.proofTimeout, const Duration(minutes: 2));
  });

  test(
    'startup advertises recovered relay work on a pre-existing connection',
    () async {
      final clock = DateTime.utc(2026, 11, 1, 15);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final keyStore = _MemoryKeyStore();
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'recovered-before-start',
              ownerId: 'guest:test',
              type: 'emergency',
              status: 'active',
              syncState: 'localOnly',
              createdAt: clock,
              updatedAt: clock,
            ),
          );
      final seeder = HopRelayCoordinator(
        database: database,
        transport: transportA,
        identityService: RelayIdentityService(keyStore: keyStore),
        now: () => clock,
      );
      await seeder.queuePublicEmergency(
        _sos('recovered-before-start', clock),
        includeLocation: false,
      );

      final recovered = HopRelayCoordinator(
        database: database,
        transport: transportA,
        identityService: RelayIdentityService(keyStore: keyStore),
        now: () => clock,
      );
      addTearDown(recovered.stop);
      addTearDown(transportA.dispose);
      addTearDown(transportB.dispose);
      addTearDown(database.close);

      await recovered.onEvent(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );
      expect(
        transportA.sentMessages.where(
          (message) => message.type == RelayCapabilityAdvertisement.wireKind,
        ),
        isEmpty,
      );

      await recovered.start();

      expect(
        transportA.sentMessages.where(
          (message) => message.type == RelayCapabilityAdvertisement.wireKind,
        ),
        hasLength(1),
      );
      expect(recovered.hasPendingLocalOrigin(), completion(isTrue));
    },
  );

  test(
    'session proof timeout starts after the multi-frame challenge write',
    () async {
      final clock = DateTime.utc(2026, 10, 26, 11);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      var delayedChallenge = false;
      final releaseChallenge = Completer<void>();
      transportA.beforeMessageDelivery = (message) async {
        if (!delayedChallenge &&
            message.type == RelaySessionChallenge.wireKind) {
          delayedChallenge = true;
          await releaseChallenge.future;
        }
      };
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
        proofTimeout: const Duration(milliseconds: 100),
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
        proofTimeout: const Duration(seconds: 2),
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeA.start();
      await nodeB.start();
      await transportA.connect('device-b');

      await _eventually(() async => delayedChallenge);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(nodeA.logs, isNot(contains('relaySessionProofTimedOut')));
      releaseChallenge.complete();

      await _eventually(
        () async => nodeA.logs.contains('relaySessionProofEstablished'),
        timeout: const Duration(seconds: 3),
      );
      expect(nodeA.logs, isNot(contains('relaySessionProofTimedOut')));
      expect(nodeA.errors, isEmpty);
    },
  );

  test(
    'relay control messages stay ordered when capability write overlaps proof',
    () async {
      final clock = DateTime.utc(2026, 10, 29, 11);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      var delayedCapability = false;
      transportA.beforeMessageDelivery = (message) async {
        if (!delayedCapability &&
            message.type == RelayCapabilityAdvertisement.wireKind) {
          delayedCapability = true;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      };
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeA.start();
      await nodeB.start();
      await transportA.connect('device-b');

      await _eventually(
        () async =>
            nodeA.logs.contains('relaySessionProofEstablished') &&
            nodeB.logs.contains('relaySessionProofEstablished'),
        timeout: const Duration(seconds: 3),
      );
      final capabilityIndex = transportA.sentMessages.indexWhere(
        (message) => message.type == RelayCapabilityAdvertisement.wireKind,
      );
      final challengeIndex = transportA.sentMessages.indexWhere(
        (message) => message.type == RelaySessionChallenge.wireKind,
      );
      expect(capabilityIndex, greaterThanOrEqualTo(0));
      expect(challengeIndex, greaterThan(capabilityIndex));
      expect(nodeA.errors, isEmpty);
      expect(nodeB.errors, isEmpty);
    },
  );

  test(
    'challenge arriving before capability is deferred then verified',
    () async {
      final clock = DateTime.utc(2026, 10, 29, 12);
      final transportA = _LinkedTransport('device-a')
        ..deferCapabilityUntilChallenge = true;
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeA.start();
      await nodeB.start();
      await transportA.connect('device-b');

      await _eventually(
        () async =>
            nodeA.logs.contains('relaySessionProofEstablished') &&
            nodeB.logs.contains('relaySessionProofEstablished'),
        timeout: const Duration(seconds: 3),
      );
      expect(nodeB.logs, contains('relaySessionChallengeDeferred'));
      expect(nodeA.errors, isEmpty);
      expect(nodeB.errors, isEmpty);
    },
  );

  test(
    'opted-in peer persists relay-only offer and returns hop receipt',
    () async {
      var clock = DateTime.utc(2026, 10, 26, 12);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeB.start();
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-hop', clock),
        includeLocation: false,
      );

      await _eventually(() async {
        final attempts = await nodeA.database
            .select(nodeA.database.bleRelayAttempts)
            .get();
        return attempts.length == 1 &&
            attempts.single.state ==
                RelayAttemptState.acceptedByRelay.wireValue;
      });

      final relayed = await nodeB.database
          .select(nodeB.database.bleRelayMessages)
          .get();
      expect(relayed, hasLength(1));
      expect(relayed.single.incidentId, 'incident-hop');
      expect(
        (await RelayRepository(database: nodeB.database).loadVerifiedOffer(
          relayed.single.originMessageId,
          now: clock,
        )).body.includeLocation,
        isFalse,
      );
      expect(
        await nodeB.database.select(nodeB.database.sosMessages).get(),
        isEmpty,
      );
      expect(
        await nodeB.database.select(nodeB.database.chatMessages).get(),
        isEmpty,
      );
      expect(
        await nodeB.database.select(nodeB.database.sosSyncQueue).get(),
        isEmpty,
      );
      expect(nodeA.errors, isEmpty);
      expect(nodeB.errors, isEmpty);
      expect(transportA.connectCount, 1);
      expect(
        transportA.sentMessages.where(
          (message) => message.type == RelaySessionChallenge.wireKind,
        ),
        isNotEmpty,
      );
      expect(
        transportB.sentMessages.where(
          (message) => message.type == RelaySessionResponse.wireKind,
        ),
        isNotEmpty,
      );

      final capturedChallenge = transportA.sentMessages.lastWhere(
        (message) => message.type == RelaySessionChallenge.wireKind,
      );
      final capturedResponse = transportB.sentMessages.lastWhere(
        (message) => message.type == RelaySessionResponse.wireKind,
      );
      await expectLater(
        nodeB.coordinator.handleMessage(
          'device-a',
          BleSessionRole.peripheral,
          capturedChallenge,
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      await expectLater(
        nodeA.coordinator.handleMessage(
          'device-b',
          BleSessionRole.central,
          capturedResponse,
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      await expectLater(
        nodeA.coordinator.handleMessage(
          'wrong-peer',
          BleSessionRole.central,
          capturedResponse,
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      await expectLater(
        nodeA.coordinator.handleMessage(
          'device-b',
          BleSessionRole.peripheral,
          capturedResponse,
        ),
        throwsA(isA<RelayProtocolException>()),
      );

      final capturedReceipt = transportB.sentMessages.lastWhere(
        (message) => message.type == RelayReceiptType.hop.wireValue,
      );
      await transportA.disconnect('device-b');
      await transportA.connect('device-b');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await expectLater(
        nodeA.coordinator.handleMessage(
          'device-b',
          BleSessionRole.central,
          capturedReceipt,
        ),
        throwsA(isA<RelayProtocolException>()),
      );
    },
  );

  test(
    'signed hop receipt can win the final native write completion race',
    () async {
      final clock = DateTime.utc(2026, 10, 26, 12);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      transportA.afterMessageDelivery = (message) async {
        if (message.type != RelayOfferTransfer.wireKind) return;
        // Hold the sender's final native-send future open while the receiver
        // persists the offer and returns its signed hop receipt.
        await _eventually(() async {
          final attempts = await nodeA.database
              .select(nodeA.database.bleRelayAttempts)
              .get();
          return attempts.length == 1 &&
              attempts.single.state ==
                  RelayAttemptState.acceptedByRelay.wireValue;
        });
      };

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeB.start();
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-native-race', clock),
        includeLocation: false,
      );

      await _eventually(
        () async =>
            nodeA.logs.contains('relayOfferAcceptedDuringNativeCompletion'),
      );
      final attempts = await nodeA.database
          .select(nodeA.database.bleRelayAttempts)
          .get();
      expect(
        attempts.single.state,
        RelayAttemptState.acceptedByRelay.wireValue,
      );
      expect(
        await nodeA.database.select(nodeA.database.bleRelayReceipts).get(),
        hasLength(1),
      );
      expect(nodeA.errors, isEmpty);
      expect(nodeB.errors, isEmpty);
    },
  );

  test('offer and receipt are rejected before active-session proof', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final transportA = _LinkedTransport('device-a');
    final transportB = _LinkedTransport('device-b');
    transportA.link(transportB);
    final coordinator = HopRelayCoordinator(
      database: database,
      transport: transportA,
      identityService: RelayIdentityService(keyStore: _MemoryKeyStore()),
    );
    addTearDown(() async {
      await coordinator.stop();
      await transportA.dispose();
      await transportB.dispose();
      await database.close();
    });
    await coordinator.setParticipationEnabled(true);
    await coordinator.start();
    await coordinator.onEvent(
      const BleEvent(
        type: 'connected',
        device: BleDevice(id: 'device-b'),
        role: BleSessionRole.central,
      ),
    );

    final createdAt = DateTime.utc(2026, 10, 26);
    for (final type in [
      RelayOfferTransfer.wireKind,
      RelayReceiptType.hop.wireValue,
    ]) {
      await expectLater(
        coordinator.handleMessage(
          'device-b',
          BleSessionRole.central,
          BleMessage(
            id: 'unproven',
            type: type,
            payload: const <String, Object?>{},
            createdAt: createdAt,
          ),
        ),
        throwsA(isA<RelayProtocolException>()),
      );
    }
  });

  test(
    'capability key substitution, wrong role, and copied peer fail closed',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final coordinator = HopRelayCoordinator(
        database: database,
        transport: transportA,
        identityService: RelayIdentityService(keyStore: _MemoryKeyStore()),
      );
      addTearDown(() async {
        await coordinator.stop();
        await transportA.dispose();
        await transportB.dispose();
        await database.close();
      });
      await coordinator.setParticipationEnabled(true);
      await coordinator.start();
      await coordinator.onEvent(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );

      final crypto = RelayCryptography();
      final firstPair = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 20),
      );
      final firstPublic = (await firstPair.extractPublicKey()).bytes;
      final firstKeyId = await crypto.publicKeyId(firstPublic);
      final secondPair = await Ed25519().newKeyPairFromSeed(
        List<int>.generate(32, (index) => index + 60),
      );
      final secondPublic = (await secondPair.extractPublicKey()).bytes;
      final secondKeyId = await crypto.publicKeyId(secondPublic);
      BleMessage capability({
        required String keyId,
        required List<int> publicKey,
        String role = 'peripheral',
      }) => BleMessage(
        id: 'relay-capabilities-v1',
        type: RelayCapabilityAdvertisement.wireKind,
        payload: RelayCapabilityAdvertisement(
          capabilities: const [RelayProtocolCapabilities.relayV2],
          participating: true,
          relayKeyId: keyId,
          relayPublicKey: base64UrlEncode(publicKey),
          sessionGeneration: 7,
          sessionRole: role,
        ).toJson(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      final validCapability = capability(
        keyId: firstKeyId,
        publicKey: firstPublic,
      );
      await coordinator.handleMessage(
        'device-b',
        BleSessionRole.central,
        validCapability,
      );
      await expectLater(
        coordinator.handleMessage(
          'device-b',
          BleSessionRole.central,
          capability(keyId: secondKeyId, publicKey: secondPublic),
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      await expectLater(
        coordinator.handleMessage(
          'wrong-peer',
          BleSessionRole.central,
          validCapability,
        ),
        throwsA(isA<RelayProtocolException>()),
      );

      await coordinator.onEvent(
        const BleEvent(
          type: 'disconnected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );
      await coordinator.onEvent(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );
      await expectLater(
        coordinator.handleMessage(
          'device-b',
          BleSessionRole.central,
          capability(keyId: firstKeyId, publicKey: secondPublic),
        ),
        throwsA(isA<RelayProtocolException>()),
      );

      await coordinator.onEvent(
        const BleEvent(
          type: 'disconnected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );
      await coordinator.onEvent(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );
      await expectLater(
        coordinator.handleMessage(
          'device-b',
          BleSessionRole.central,
          capability(
            keyId: firstKeyId,
            publicKey: firstPublic,
            role: 'central',
          ),
        ),
        throwsA(isA<RelayProtocolException>()),
      );
    },
  );

  test(
    'lost hop receipt retries the same attempt and duplicate stays one row',
    () async {
      var clock = DateTime.utc(2026, 10, 26, 13);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b')
        ..dropMessageTypes.add(RelayReceiptType.hop.wireValue);
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeB.start();
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-retry', clock),
        includeLocation: true,
      );
      await _eventually(() async {
        final messages = await nodeB.database
            .select(nodeB.database.bleRelayMessages)
            .get();
        return messages.length == 1;
      });

      var attempts = await nodeA.database
          .select(nodeA.database.bleRelayAttempts)
          .get();
      expect(attempts, hasLength(1));
      expect(
        attempts.single.state,
        RelayAttemptState.awaitingHopReceipt.wireValue,
      );

      transportB.dropMessageTypes.clear();
      clock = clock.add(const Duration(seconds: 31));
      await nodeA.coordinator.processDue();
      clock = clock.add(const Duration(seconds: 5));
      await nodeA.coordinator.processDue();
      await _eventually(() async {
        attempts = await nodeA.database
            .select(nodeA.database.bleRelayAttempts)
            .get();
        return attempts.single.state ==
            RelayAttemptState.acceptedByRelay.wireValue;
      });

      expect(
        await nodeB.database.select(nodeB.database.bleRelayMessages).get(),
        hasLength(1),
      );
      expect(attempts.single.retryCount, 1);
      expect(nodeA.errors, isEmpty);
      expect(nodeB.errors, isEmpty);
    },
  );

  test(
    'hop receipt timeout starts after a slow multi-frame offer write',
    () async {
      var clock = DateTime.utc(2026, 10, 26, 13);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b')
        ..dropMessageTypes.add(RelayReceiptType.hop.wireValue);
      transportA.link(transportB);
      var delayedOffer = false;
      transportA.beforeMessageDelivery = (message) async {
        if (!delayedOffer && message.type == RelayOfferTransfer.wireKind) {
          delayedOffer = true;
          clock = clock.add(const Duration(seconds: 31));
        }
      };
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeB.start();
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-slow-offer', clock),
        includeLocation: false,
      );
      await _eventually(() async {
        final attempts = await nodeA.database
            .select(nodeA.database.bleRelayAttempts)
            .get();
        return attempts.length == 1 &&
            attempts.single.state ==
                RelayAttemptState.awaitingHopReceipt.wireValue;
      });

      await nodeA.coordinator.processDue();
      final attempt = (await nodeA.database
          .select(nodeA.database.bleRelayAttempts)
          .getSingle());
      expect(attempt.state, RelayAttemptState.awaitingHopReceipt.wireValue);
      expect(attempt.retryCount, 0);
      expect(attempt.updatedAt.toUtc(), clock);
      expect(nodeA.errors, isEmpty);
      expect(nodeB.errors, isEmpty);
    },
  );

  test('A to B to C appends one hop and returns only hop receipts', () async {
    final clock = DateTime.utc(2026, 10, 26, 14);
    final transportA = _LinkedTransport('device-a');
    final transportB = _LinkedTransport('device-b');
    final transportC = _LinkedTransport('device-c');
    transportA.link(transportB);
    transportB.link(transportC);
    final nodeA = _RelayNode(
      database: AppDatabase.forTesting(NativeDatabase.memory()),
      transport: transportA,
      now: () => clock,
    );
    final nodeB = _RelayNode(
      database: AppDatabase.forTesting(NativeDatabase.memory()),
      transport: transportB,
      now: () => clock,
    );
    final nodeC = _RelayNode(
      database: AppDatabase.forTesting(NativeDatabase.memory()),
      transport: transportC,
      now: () => clock,
    );
    addTearDown(nodeA.close);
    addTearDown(nodeB.close);
    addTearDown(nodeC.close);

    await nodeA.coordinator.setParticipationEnabled(true);
    await nodeB.coordinator.setParticipationEnabled(true);
    await nodeC.coordinator.setParticipationEnabled(true);
    await nodeB.start();
    await nodeC.start();
    await nodeA.start();
    await nodeA.coordinator.queuePublicEmergency(
      _sos('incident-three-hop', clock),
      includeLocation: false,
    );

    await _eventually(() async {
      final messages = await nodeC.database
          .select(nodeC.database.bleRelayMessages)
          .get();
      final attempts = await nodeB.database
          .select(nodeB.database.bleRelayAttempts)
          .get();
      return messages.length == 1 &&
          attempts.length == 1 &&
          attempts.single.state == RelayAttemptState.acceptedByRelay.wireValue;
    });

    final atB = await nodeB.database
        .select(nodeB.database.bleRelayMessages)
        .getSingle();
    final atC = await nodeC.database
        .select(nodeC.database.bleRelayMessages)
        .getSingle();
    final offerAtB = await RelayRepository(database: nodeB.database)
        .loadVerifiedOffer(atB.originMessageId, now: clock);
    final offerAtC = await RelayRepository(database: nodeC.database)
        .loadVerifiedOffer(atC.originMessageId, now: clock);
    expect(offerAtB.hopCount, 0);
    expect(offerAtC.hopCount, 1);
    expect(offerAtC.pathKeyIds, hasLength(2));
    expect(offerAtC.hopAttestations, hasLength(1));
    expect(
      await nodeC.database.select(nodeC.database.sosMessages).get(),
      isEmpty,
    );
    expect(
      await nodeA.database.select(nodeA.database.bleRelayReceipts).get(),
      hasLength(1),
    );
    expect(
      await nodeB.database.select(nodeB.database.bleRelayReceipts).get(),
      hasLength(1),
    );
    expect(nodeA.errors, isEmpty);
    expect(nodeB.errors, isEmpty);
    expect(nodeC.errors, isEmpty);
  });

  test(
    'rotating native address cannot open two sessions for one relay identity',
    () async {
      final clock = DateTime.utc(2026, 10, 29, 15);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      final rotatedTransportB = _LinkedTransport('device-b-rotated');
      transportA.link(transportB);
      transportA.link(rotatedTransportB);
      transportB.dropMessageTypes.add(RelayReceiptType.hop.wireValue);
      final sharedBKeyStore = _MemoryKeyStore()
        ..seed = List<int>.generate(32, (index) => index + 1);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        keyStore: sharedBKeyStore,
        now: () => clock,
      );
      final rotatedNodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: rotatedTransportB,
        keyStore: sharedBKeyStore,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);
      addTearDown(rotatedNodeB.close);

      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeB.start();
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-private-address-rotation', clock),
        includeLocation: false,
      );
      await _eventually(
        () async =>
            (await nodeA.database.select(nodeA.database.bleRelayAttempts).get())
                .isNotEmpty,
      );

      await rotatedNodeB.coordinator.setParticipationEnabled(true);
      await rotatedNodeB.start();
      await _eventually(
        () async => transportA.disconnectedPeers.contains('device-b-rotated'),
      );

      expect(nodeA.logs, contains('relayDuplicateInstallationSessionRejected'));
      expect(
        transportA.sentMessages.where(
          (message) => message.type == RelayOfferTransfer.wireKind,
        ),
        hasLength(1),
      );
      expect(nodeA.errors, isEmpty);
    },
  );

  test(
    'a second central candidate waits for the active identity proof',
    () async {
      final clock = DateTime.utc(2026, 11, 1, 13);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      final transportC = _LinkedTransport('device-c');
      transportA.link(transportB);
      transportA.link(transportC);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      addTearDown(nodeA.close);

      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-serialized-central-proof', clock),
        includeLocation: false,
      );
      await nodeA.start();
      await nodeA.coordinator.onEvent(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'device-b'),
          role: BleSessionRole.central,
        ),
      );

      await nodeA.coordinator.onEvent(
        const BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: 'device-c'),
        ),
      );

      expect(transportA.connectedPeers, isNot(contains('device-c')));
      expect(nodeA.errors, isEmpty);
    },
  );

  test(
    'simultaneous connections converge on one complementary session role',
    () async {
      final clock = DateTime.utc(2026, 11, 1, 14);
      final localSeed = List<int>.generate(32, (index) => index + 3);
      final remoteSeed = List<int>.generate(32, (index) => index + 83);
      final crypto = RelayCryptography();
      final localPair = await Ed25519().newKeyPairFromSeed(localSeed);
      final remotePair = await Ed25519().newKeyPairFromSeed(remoteSeed);
      final localPublic = (await localPair.extractPublicKey()).bytes;
      final remotePublic = (await remotePair.extractPublicKey()).bytes;
      final localKeyId = await crypto.publicKeyId(localPublic);
      final remoteKeyId = await crypto.publicKeyId(remotePublic);
      final preferredRole = localKeyId.compareTo(remoteKeyId) < 0
          ? BleSessionRole.central
          : BleSessionRole.peripheral;
      final rejectedRole = preferredRole == BleSessionRole.central
          ? BleSessionRole.peripheral
          : BleSessionRole.central;
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        keyStore: _MemoryKeyStore()..seed = localSeed,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(transportB.dispose);

      await nodeA.start();
      for (final role in [rejectedRole, preferredRole]) {
        await nodeA.coordinator.onEvent(
          BleEvent(
            type: 'connected',
            device: const BleDevice(id: 'device-b'),
            role: role,
          ),
        );
      }

      BleMessage capability(BleSessionRole localRole) => BleMessage(
        id: 'relay-capabilities-v1',
        type: RelayCapabilityAdvertisement.wireKind,
        payload: RelayCapabilityAdvertisement(
          capabilities: const [RelayProtocolCapabilities.relayV2],
          participating: true,
          relayKeyId: remoteKeyId,
          relayPublicKey: base64UrlEncode(remotePublic),
          sessionGeneration: 11,
          sessionRole: localRole == BleSessionRole.central
              ? BleSessionRole.peripheral.wireValue
              : BleSessionRole.central.wireValue,
        ).toJson(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

      await nodeA.coordinator.handleMessage(
        'device-b',
        rejectedRole,
        capability(rejectedRole),
      );
      await nodeA.coordinator.handleMessage(
        'device-b',
        preferredRole,
        capability(preferredRole),
      );

      expect(nodeA.logs, contains('relayDuplicateInstallationSessionRebound'));
      await expectLater(
        nodeA.coordinator.handleMessage(
          'device-b',
          rejectedRole,
          capability(rejectedRole),
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      await nodeA.coordinator.handleMessage(
        'device-b',
        preferredRole,
        capability(preferredRole),
      );
      expect(nodeA.errors, isEmpty);
    },
  );

  test(
    'per-incident consent sends local-origin work while participation is OFF',
    () async {
      final clock = DateTime.utc(2026, 10, 26, 15);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);

      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeB.start();
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('paused-local-origin', clock),
        includeLocation: false,
      );
      await nodeA.coordinator.processDue();

      expect(
        await nodeA.database.select(nodeA.database.bleRelayMessages).get(),
        hasLength(1),
      );
      await _eventually(
        () async =>
            (await nodeB.database.select(nodeB.database.bleRelayMessages).get())
                .length ==
            1,
      );
      expect(
        await nodeB.database.select(nodeB.database.bleRelayMessages).get(),
        hasLength(1),
      );
      expect(nodeA.coordinator.participationEnabled, isFalse);
      expect(
        await nodeA.database.select(nodeA.database.bleRelayReceipts).get(),
        hasLength(1),
      );
    },
  );

  test(
    'explicit OFF ON resets exhausted transient connection budget',
    () async {
      final clock = DateTime.utc(2026, 10, 29, 13);
      final transportA = _LinkedTransport('device-a')..failConnections = true;
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(() async {
        await transportB.dispose();
      });

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeA.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('incident-reset-connect-budget', clock),
        includeLocation: false,
      );
      final found = BleEvent(
        type: 'deviceFound',
        device: const BleDevice(id: 'device-b'),
      );
      await nodeA.coordinator.onEvent(found);
      await nodeA.coordinator.onEvent(found);
      await nodeA.coordinator.onEvent(found);
      expect(transportA.connectCount, 2);

      await nodeA.coordinator.setParticipationEnabled(false);
      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeA.coordinator.onEvent(found);

      expect(transportA.connectCount, 3);
    },
  );

  test(
    'participation OFF pauses retained third-party work without deletion',
    () async {
      final clock = DateTime.utc(2026, 10, 26, 16);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      final transportC = _LinkedTransport('device-c');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      final nodeC = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportC,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);
      addTearDown(nodeC.close);

      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeA.start();
      await nodeB.start();
      await nodeA.coordinator.queuePublicEmergency(
        _sos('paused-third-party', clock),
        includeLocation: false,
      );
      await _eventually(
        () async =>
            (await nodeB.database.select(nodeB.database.bleRelayMessages).get())
                .length ==
            1,
      );

      await nodeB.coordinator.setParticipationEnabled(false);
      transportB.link(transportC);
      await nodeC.coordinator.setParticipationEnabled(true);
      await nodeC.start();
      await nodeB.coordinator.processDue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        await nodeB.database.select(nodeB.database.bleRelayMessages).get(),
        hasLength(1),
      );
      expect(
        await nodeC.database.select(nodeC.database.bleRelayMessages).get(),
        isEmpty,
      );

      await nodeB.coordinator.setParticipationEnabled(true);
      await _eventually(
        () async =>
            (await nodeC.database.select(nodeC.database.bleRelayMessages).get())
                .length ==
            1,
      );
      expect(
        await nodeC.database.select(nodeC.database.bleRelayMessages).get(),
        hasLength(1),
      );
    },
  );

  test(
    'opt-out during a queued send prevents a complete relay offer',
    () async {
      final clock = DateTime.utc(2026, 10, 26, 17);
      final transportA = _LinkedTransport('device-a');
      final transportB = _LinkedTransport('device-b');
      transportA.link(transportB);
      final nodeA = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportA,
        now: () => clock,
      );
      final nodeB = _RelayNode(
        database: AppDatabase.forTesting(NativeDatabase.memory()),
        transport: transportB,
        now: () => clock,
      );
      addTearDown(nodeA.close);
      addTearDown(nodeB.close);
      await nodeA.coordinator.setParticipationEnabled(true);
      await nodeB.coordinator.setParticipationEnabled(true);
      await nodeA.start();
      await nodeB.start();

      var stopped = false;
      transportA.beforeFrameSend = () async {
        if (stopped) return;
        stopped = true;
        transportA.beforeFrameSend = null;
        await nodeA.coordinator.setParticipationEnabled(false);
      };
      await nodeA.coordinator.queuePublicEmergency(
        _sos('opt-out-before-send', clock),
        includeLocation: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(nodeA.coordinator.participationEnabled, isFalse);
      expect(
        await nodeB.database.select(nodeB.database.bleRelayMessages).get(),
        isEmpty,
      );
    },
  );

  test('secure-key failure keeps relay participation disabled', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final transport = _LinkedTransport('device-a');
    final keyStore = _MemoryKeyStore()..failReads = true;
    final coordinator = HopRelayCoordinator(
      database: database,
      transport: transport,
      identityService: RelayIdentityService(keyStore: keyStore),
    );
    addTearDown(database.close);
    addTearDown(transport.dispose);

    await expectLater(
      coordinator.setParticipationEnabled(true),
      throwsA(isA<RelayKeyStoreException>()),
    );
    expect(coordinator.participationEnabled, isFalse);
    expect(transport.advertising, isFalse);
  });

  test('toggle OFF racing advertising startup remains hard-disabled', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final transport = _LinkedTransport('device-a');
    final started = Completer<void>();
    final unblock = Completer<void>();
    transport
      ..advertisingStarted = started
      ..advertisingBlock = unblock.future;
    final coordinator = HopRelayCoordinator(
      database: database,
      transport: transport,
      identityService: RelayIdentityService(keyStore: _MemoryKeyStore()),
    );
    addTearDown(() async {
      await coordinator.stop();
      await transport.dispose();
      await database.close();
    });
    await coordinator.start();

    final enabling = coordinator.setParticipationEnabled(true);
    await started.future;
    final disabling = coordinator.setParticipationEnabled(false);
    unblock.complete();
    await Future.wait([enabling, disabling]);

    expect(coordinator.participationEnabled, isFalse);
    expect(transport.advertising, isFalse);
  });

  test('relay startup failure does not disable Direct SOS v1', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final transport = _LinkedTransport('device-a');
    final relay = _FailingHopRelayCoordinator();
    when(() => relay.start())
        .thenThrow(const RelayKeyStoreException('secure storage unavailable'));
    when(() => relay.stop()).thenAnswer((_) async {});
    when(() => relay.processDue()).thenAnswer((_) async {});
    final coordinator = SosBleCoordinator(
      database: database,
      ownerId: 'guest:test',
      transport: transport,
      hopRelayCoordinator: relay,
      pollInterval: const Duration(hours: 1),
    );
    addTearDown(() async {
      await coordinator.dispose();
      await transport.dispose();
      await database.close();
    });

    await coordinator.start();
    expect(coordinator.isStarted, isTrue);
    final row = await coordinator.enqueueSos(
      _sos('direct-still-works', DateTime.utc(2026, 10, 26, 15)),
    );
    expect(row.messageId, 'sos:direct-still-works:delivery:v1');
    expect(await database.select(database.bleOutbox).get(), hasLength(1));
    verify(() => relay.start()).called(1);
  });
}
