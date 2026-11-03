import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

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
    'Chat participant resolver uses the verified SOS origin binding',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final offer = await _offer();
      await RelayRepository(database: database)
          .persistOriginOffer(offer, now: DateTime.utc(2026, 11, 4, 2));
      final coordinator = SosBleCoordinator(
        database: database,
        ownerId: 'owner-c',
        transport: _Transport(),
      );
      final binding = await coordinator.resolveVerifiedChatParticipant(
        'incident-1',
      );
      expect(binding?.keyId, offer.body.originKeyId);
      expect(binding?.publicKey, offer.body.originPublicKey);
    },
  );

  test(
    'Chat participant resolver fails closed without a verified binding',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final coordinator = SosBleCoordinator(
        database: database,
        ownerId: 'owner-a',
        transport: _Transport(),
      );
      expect(
        await coordinator.resolveVerifiedChatParticipant('unknown-incident'),
        isNull,
      );
    },
  );
}

Future<RelayOfferEnvelope> _offer() async {
  final pair = await Ed25519().newKeyPair();
  final public = (await pair.extractPublicKey()).bytes;
  final crypto = RelayCryptography();
  final created = DateTime.utc(2026, 11, 4, 2);
  final body = RelayOriginBody(
    originMessageId: 'relay:incident-1',
    incidentId: 'incident-1',
    originKeyId: await crypto.publicKeyId(public),
    originPublicKey: base64UrlEncode(public),
    emergencyType: 'emergency',
    emergencyMessage: 'help',
    includeLocation: false,
    createdAt: created,
    expiresAt: created.add(const Duration(minutes: 10)),
  );
  return RelayOfferEnvelope(
    body: body,
    originSignature: await crypto.signOriginBody(body, pair),
    hopCount: 0,
    pathKeyIds: [body.originKeyId],
    immediateSenderKeyId: body.originKeyId,
  );
}
