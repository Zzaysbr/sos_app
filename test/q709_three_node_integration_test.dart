import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/chat_relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/hop_relay_coordinator.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

class _SeedStore implements RelayPrivateKeyStore {
  _SeedStore(this.seed);
  final List<int> seed;
  @override
  Future<List<int>?> readSeed() async => seed;
  @override
  Future<void> writeSeed(List<int> seed) async {}
}

class _Transport implements BleTransportClient {
  @override
  Stream<BleEvent> get events => const Stream.empty();
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
  Future<void> dispose() async {}
}

void main() {
  test(
    'three-node signed Chat integration persists A↔B↔C exactly once',
    () async {
      final dbA = AppDatabase.forTesting(NativeDatabase.memory());
      final dbB = AppDatabase.forTesting(NativeDatabase.memory());
      final dbC = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() async {
        await dbA.close();
        await dbB.close();
        await dbC.close();
      });
      final now = DateTime.now().toUtc();
      final identityA = await RelayIdentityService(
        keyStore: _SeedStore(List<int>.filled(32, 1)),
      ).loadOrCreate(allowCreate: true);
      final identityC = await RelayIdentityService(
        keyStore: _SeedStore(List<int>.filled(32, 3)),
      ).loadOrCreate(allowCreate: true);
      final repoA = ChatRelayRepository(dbA, ownerId: 'A');
      final repoB = ChatRelayRepository(dbB, ownerId: 'B');
      final repoC = ChatRelayRepository(dbC, ownerId: 'C');
      final coordinatorC = HopRelayCoordinator(
        database: dbC,
        transport: _Transport(),
        identityService: RelayIdentityService(
          keyStore: _SeedStore(List<int>.filled(32, 3)),
        ),
        chatRelayRepository: repoC,
      );
      final coordinatorA = HopRelayCoordinator(
        database: dbA,
        transport: _Transport(),
        identityService: RelayIdentityService(
          keyStore: _SeedStore(List<int>.filled(32, 1)),
        ),
        chatRelayRepository: repoA,
      );
      final m1 = await coordinatorC.signAndEnqueueChatRelay(
        messageId: 'm1',
        incidentId: 'incident-1',
        recipientKeyId: identityA.keyId,
        recipientPublicKey: base64UrlEncode(identityA.publicKey),
        text: 'M1',
        createdAt: now,
      );
      expect(await repoB.persistIncoming(m1), isTrue);
      await repoB.enqueue(m1, hopCount: 1, now: now);
      expect(await repoA.persistIncoming(m1), isTrue);
      expect(await repoA.persistIncoming(m1), isFalse);
      expect((await dbB.select(dbB.chatRelayInbox).get()), hasLength(1));
      expect((await dbA.select(dbA.chatRelayInbox).get()), hasLength(1));
      final m2 = await coordinatorA.signAndEnqueueChatRelay(
        messageId: 'm2',
        incidentId: 'incident-1',
        recipientKeyId: identityC.keyId,
        recipientPublicKey: base64UrlEncode(identityC.publicKey),
        text: 'M2',
        createdAt: now,
      );
      expect(await repoB.persistIncoming(m2), isTrue);
      await repoB.enqueue(m2, hopCount: 1, now: now);
      expect(await repoC.persistIncoming(m2), isTrue);
      expect(await repoC.persistIncoming(m2), isFalse);
      expect((await dbC.select(dbC.chatRelayInbox).get()), hasLength(1));
      expect(m1.body.incidentId, m2.body.incidentId);
      expect(await RelayCryptography().verifyChatRelay(m1), isTrue);
      expect(await RelayCryptography().verifyChatRelay(m2), isTrue);
    },
  );
}
