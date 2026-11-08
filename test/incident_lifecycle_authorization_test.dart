import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/incident_lifecycle_repository.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/domain/incident_lifecycle_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';

import 'sos_ble_coordinator_test.dart' show FakeBleTransport;

class _Keys implements RelayPrivateKeyStore {
  _Keys(this.seed);
  final int seed;
  @override
  Future<List<int>?> readSeed() async => List.filled(32, seed);
  @override
  Future<void> writeSeed(List<int> seed) async {}
}

class _Auth extends Mock implements FirebaseAuth {}

class _Cloud extends Mock implements SosCloudService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 11, 6, 0, 5);
  final created = now.subtract(const Duration(minutes: 1));
  late AppDatabase db;
  late RelaySigningIdentity origin;
  late RelaySigningIdentity attacker;
  late IncidentLifecycleRepository lifecycle;
  late RescueInboxRepository inbox;

  Future<RelayOfferEnvelope> offer({
    String id = 'incident',
    RelaySigningIdentity? signer,
  }) async {
    final identity = signer ?? origin;
    final body = RelayOriginBody(
      originMessageId: 'relay:$id',
      incidentId: id,
      originKeyId: identity.keyId,
      originPublicKey: base64UrlEncode(identity.publicKey),
      emergencyType: 'emergency',
      emergencyMessage: 'test',
      includeLocation: true,
      latitude: 13.7,
      longitude: 100.5,
      createdAt: created,
      expiresAt: created.add(const Duration(minutes: 30)),
      scope: RelayAuthorizationScope.voluntaryRescue,
    );
    return RelayOfferEnvelope(
      body: body,
      originSignature: await RelayCryptography().signOriginBody(
        body,
        identity.keyPair,
      ),
      hopCount: 0,
      pathKeyIds: [identity.keyId],
      immediateSenderKeyId: identity.keyId,
    );
  }

  Future<void> trusted({bool candidate = true}) async {
    final signed = await offer();
    await RelayRepository(database: db).persistOriginOffer(signed, now: now);
    if (candidate) {
      await inbox.insertCandidate(
        signed,
        immutableDigest: await RelayCryptography().immutableDigest(signed.body),
        now: now,
      );
    }
  }

  Future<void> sos({String owner = 'owner-a', String state = 'active'}) async {
    await db
        .into(db.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'incident',
            ownerId: owner,
            type: 'emergency',
            message: const Value('keep'),
            status: state,
            syncState: 'deviceOnly',
            createdAt: created,
            updatedAt: now,
            latitude: const Value(13.7),
            longitude: const Value(100.5),
          ),
        );
  }

  Future<IncidentLifecycleEnvelope> event({
    RelaySigningIdentity? signer,
    String status = 'resolved',
    String id = 'incident',
    DateTime? at,
  }) => IncidentLifecycleEnvelope.sign(
    incidentId: id,
    status: status,
    identity: signer ?? origin,
    now: at ?? now,
  );
  Future<String> status() async =>
      (await db.select(db.sosMessages).getSingle()).status;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    origin = await RelayIdentityService(keyStore: _Keys(1))
        .loadOrCreate(allowCreate: true);
    attacker = await RelayIdentityService(keyStore: _Keys(2))
        .loadOrCreate(allowCreate: true);
    lifecycle = IncidentLifecycleRepository(db, ownerId: 'owner-a');
    inbox = RescueInboxRepository(db, ownerId: 'owner-a');
  });
  tearDown(() => db.close());

  for (final terminal in ['cancelled', 'resolved']) {
    test(
      'rejects valid self-signed unauthorized $terminal through native frame dispatch',
      () async {
        await trusted();
        await sos();
        final transport = FakeBleTransport();
        final logs = <String>[];
        final coordinator = SosBleCoordinator(
          database: db,
          ownerId: 'owner-a',
          transport: transport,
          now: () => now,
          onLog: logs.add,
          pollInterval: const Duration(days: 1),
        );
        await coordinator.start();
        addTearDown(() async {
          await coordinator.dispose();
          await transport.dispose();
        });
        final forged = await event(signer: attacker, status: terminal);
        // Its cryptographic signature is valid, but that key does not own this SOS.
        await forged.validate(now: now);
        for (final frame in BleMessageCodec.encode(forged.toBleMessage())) {
          transport.emit(
            BleEvent(
              type: 'data',
              device: const BleDevice(id: 'relay-peer'),
              role: BleSessionRole.peripheral,
              payload: frame,
            ),
          );
        }
        for (
          var i = 0;
          i < 100 && !logs.any((s) => s.contains('lifecycle_rejected'));
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(logs.any((s) => s.contains('lifecycle_rejected')), isTrue);
        expect(await status(), 'active');
        expect((await inbox.find('relay:incident'))!.state, 'pending');
        expect(await lifecycle.authorizedEvents(), isEmpty);
      },
    );
  }

  test(
    'authorized origin closes SOS and Rescue Inbox without deleting history',
    () async {
      await trusted();
      await sos();
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: 'chat-keep',
              sosId: 'incident',
              ownerId: 'owner-a',
              senderId: 'sender',
              messageType: 'text',
              textContent: const Value('keep chat'),
              createdAt: created,
              deliveryStatus: 'received',
            ),
          );
      final result = await lifecycle.receive(
        await event(),
        sourcePeer: 'relay',
        now: now,
      );
      expect(result, LifecycleAuthorization.authorized);
      expect(await status(), 'resolved');
      expect((await inbox.find('relay:incident'))!.state, 'resolved');
      expect(
        (await db.select(db.chatMessages).get()).single.textContent,
        'keep chat',
      );
      final row = await db.select(db.sosMessages).getSingle();
      expect(row.latitude, 13.7);
      expect(row.message, 'keep');
      expect(
        await inbox.acceptLocally('relay:incident'),
        isA<RescueInboxData>(),
      );
      expect((await inbox.find('relay:incident'))!.state, 'resolved');
    },
  );

  test('unknown origin defers without applying or forwarding', () async {
    await sos();
    expect(
      await lifecycle.receive(await event(), sourcePeer: 'relay', now: now),
      LifecycleAuthorization.deferred,
    );
    expect(await status(), 'active');
    expect(await lifecycle.authorizedEvents(), isEmpty);
    final rows = await db.select(db.bleInbox).get();
    expect(rows.single.processingState, 'lifecycle_deferred');
  });

  test(
    'lifecycle before SOS is applied on candidate and incident materialization',
    () async {
      expect(
        await lifecycle.receive(await event(), sourcePeer: 'relay', now: now),
        LifecycleAuthorization.deferred,
      );
      final signed = await offer();
      await inbox.insertCandidate(
        signed,
        immutableDigest: await RelayCryptography().immutableDigest(signed.body),
        now: now,
      );
      expect((await inbox.find('relay:incident'))!.state, 'resolved');
      final auth = _Auth();
      when(() => auth.currentUser).thenReturn(null);
      final repository = SosRepository(
        database: db,
        cloudService: _Cloud(),
        firebaseAuth: auth,
        localOwnerId: 'owner-a',
      );
      final incident = await repository.ensureReceivedIncident(
        id: 'incident',
        type: 'emergency',
        createdAt: created,
      );
      expect(incident.status, 'resolved');
      expect(
        (await repository.ensureReceivedIncident(
          id: 'incident',
          type: 'emergency',
          createdAt: created,
        )).status,
        'resolved',
      );
      expect(await db.select(db.sosMessages).get(), hasLength(1));
      expect(await db.select(db.sosSyncQueue).get(), isEmpty);
    },
  );

  test('deferred attacker is rejected once genuine SOS arrives', () async {
    await lifecycle.receive(
      await event(signer: attacker),
      sourcePeer: 'relay',
      now: now,
    );
    await trusted();
    expect((await inbox.find('relay:incident'))!.state, 'pending');
    expect(await lifecycle.authorizedEvents(), isEmpty);
    expect(
      (await db.select(db.bleInbox).getSingle()).processingState,
      'lifecycle_rejected',
    );
  });

  test('local archive survives SOS replay and still accepts authorized terminal evidence', () async {
    await trusted();
    await sos();
    await (db.update(db.rescueInbox)
          ..where((r) => r.originMessageId.equals('relay:incident')))
        .write(const RescueInboxCompanion(state: Value('locallyAccepted')));
    await inbox.stopFollowing('relay:incident');
    expect((await inbox.find('relay:incident'))!.state, 'archivedLocally');
    final repeated = await offer();
    await inbox.insertCandidate(
      repeated,
      immutableDigest: await RelayCryptography().immutableDigest(repeated.body),
      now: now,
    );
    expect((await inbox.find('relay:incident'))!.state, 'archivedLocally');
    expect((await db.select(db.sosMessages).getSingle()).status, 'active');
    await lifecycle.receive(
      await event(status: 'cancelled'),
      sourcePeer: 'peer',
      now: now,
    );
    expect((await inbox.find('relay:incident'))!.state, 'cancelled');
    expect((await db.select(db.sosMessages).getSingle()).status, 'cancelled');
    expect(await inbox.watchCandidates().first, hasLength(1));
    expect(await db.select(db.bleOutbox).get(), isEmpty);
  });

  test('duplicates and older cancellation cannot downgrade resolved', () async {
    await trusted();
    await sos();
    final resolved = await event();
    await lifecycle.receive(resolved, sourcePeer: 'relay', now: now);
    await lifecycle.receive(resolved, sourcePeer: 'another-relay', now: now);
    await lifecycle.receive(
      await event(
        status: 'cancelled',
        at: now.subtract(const Duration(seconds: 10)),
      ),
      sourcePeer: 'relay',
      now: now,
    );
    expect(await status(), 'resolved');
    expect((await inbox.find('relay:incident'))!.state, 'resolved');
    expect(await db.select(db.bleInbox).get(), hasLength(2));
  });

  test('cancel then resolve advances terminal status and preserves local acceptance', () async {
    await trusted();
    await sos();
    await (db.update(db.rescueInbox)).write(
      const RescueInboxCompanion(
        state: Value('locallyAccepted'),
        acceptanceId: Value('acceptance'),
      ),
    );
    await lifecycle.receive(
      await event(status: 'cancelled'),
      sourcePeer: 'relay',
      now: now,
    );
    await lifecycle.receive(
      await event(at: now.add(const Duration(seconds: 1))),
      sourcePeer: 'relay',
      now: now,
    );
    expect(await status(), 'resolved');
    final candidate = (await inbox.find('relay:incident'))!;
    expect(candidate.state, 'resolved');
    expect(candidate.acceptanceId, 'acceptance');
  });

  test(
    'owner scopes neither consume nor modify another owners records',
    () async {
      await trusted();
      await sos(owner: 'owner-b');
      final other = IncidentLifecycleRepository(db, ownerId: 'owner-b');
      final terminal = await event();
      await lifecycle.receive(terminal, sourcePeer: 'relay', now: now);
      expect(await status(), 'active');
      expect(await other.authorizedEvents(), isEmpty);
      await other.receive(terminal, sourcePeer: 'relay', now: now);
      expect(await status(), 'resolved');
      expect(await db.select(db.bleInbox).get(), hasLength(2));
    },
  );

  test(
    'wrong incident and pre-SOS event cannot close the trusted SOS',
    () async {
      await trusted();
      await sos();
      expect(
        await lifecycle.receive(
          await event(id: 'wrong'),
          sourcePeer: 'relay',
          now: now,
        ),
        LifecycleAuthorization.deferred,
      );
      expect(
        await lifecycle.receive(
          await event(at: created.subtract(const Duration(seconds: 1))),
          sourcePeer: 'relay',
          now: now,
        ),
        LifecycleAuthorization.rejected,
      );
      expect(await status(), 'active');
    },
  );

  test('same event ID with a different signed body is rejected', () async {
    await trusted();
    await sos();
    final original = await event();
    await lifecycle.receive(original, sourcePeer: 'relay', now: now);
    final other = await event(status: 'cancelled');
    final unsigned = IncidentLifecycleEnvelope(
      eventId: original.eventId,
      incidentId: other.incidentId,
      status: other.status,
      originKeyId: other.originKeyId,
      originPublicKey: other.originPublicKey,
      actorKeyId: other.actorKeyId,
      createdAt: other.createdAt,
      signature: other.signature,
    );
    final signature = await Ed25519().sign(
      utf8.encode(relayCanonicalJson(unsigned.unsignedMap())),
      keyPair: origin.keyPair,
    );
    final changed = IncidentLifecycleEnvelope.fromJson({
      ...unsigned.toJson(),
      'signature': base64UrlEncode(signature.bytes),
    });
    // Even a valid origin signature cannot reuse an event ID for another body.
    await changed.validate(now: now);
    await expectLater(
      lifecycle.receive(changed, sourcePeer: 'relay', now: now),
      throwsA(isA<RelayProtocolException>()),
    );
    expect(await status(), 'resolved');
  });

  test('forged signature and corrupt persisted origin fail closed', () async {
    await trusted();
    await sos();
    final signed = await event();
    final bad = IncidentLifecycleEnvelope.fromJson({
      ...signed.toJson(),
      'signature': base64UrlEncode(List.filled(64, 0)),
    });
    await expectLater(
      lifecycle.receive(bad, sourcePeer: 'relay', now: now),
      throwsA(isA<RelayProtocolException>()),
    );
    await db
        .update(db.bleRelayMessages)
        .write(
          const BleRelayMessagesCompanion(immutableDigest: Value('corrupted')),
        );
    await expectLater(
      lifecycle.receive(signed, sourcePeer: 'relay', now: now),
      throwsA(isA<RelayProtocolException>()),
    );
    expect(await status(), 'active');
    expect(await db.select(db.bleInbox).get(), isEmpty);
  });

  test(
    'expired relay cache still authenticates the historical origin',
    () async {
      await trusted(candidate: false);
      await sos();
      final later = now.add(const Duration(hours: 1));
      expect(
        await lifecycle.receive(
          await event(at: later),
          sourcePeer: 'relay',
          now: later,
        ),
        LifecycleAuthorization.authorized,
      );
      expect(await status(), 'resolved');
    },
  );

  test(
    'legacy unscoped lifecycle rows are never replayed as authorized',
    () async {
      await trusted();
      await sos();
      final untrusted = await event(signer: attacker);
      await db
          .into(db.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: untrusted.eventId,
              sosId: 'incident',
              schemaVersion: 1,
              payload: untrusted.toCanonicalWire(),
              processingState: 'persisted',
              receivedAt: now,
            ),
          );
      await lifecycle.reconcilePending(now: now);
      expect(await status(), 'active');
      expect(await lifecycle.authorizedEvents(), isEmpty);
    },
  );

  test(
    'deferred evidence survives database restart and verifies after SOS',
    () async {
      final dir = await Directory.systemTemp.createTemp('lifecycle-restart-');
      final file = File('${dir.path}/test.sqlite');
      var disk = AppDatabase.forTesting(NativeDatabase(file));
      await IncidentLifecycleRepository(
        disk,
        ownerId: 'owner-a',
      ).receive(await event(), sourcePeer: 'relay', now: now);
      await disk.close();
      disk = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final signed = await offer();
        final candidateRepo = RescueInboxRepository(disk, ownerId: 'owner-a');
        await candidateRepo.insertCandidate(
          signed,
          immutableDigest: await RelayCryptography().immutableDigest(
            signed.body,
          ),
          now: now,
        );
        expect((await candidateRepo.find('relay:incident'))!.state, 'resolved');
      } finally {
        await disk.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('candidate retains trusted origin after relay cache cleanup', () async {
    await trusted();
    await sos();
    await db.delete(db.bleRelayMessages).go();
    expect(
      await lifecycle.receive(await event(), sourcePeer: 'relay', now: now),
      LifecycleAuthorization.authorized,
    );
    expect(await status(), 'resolved');
  });

  test(
    'corrupt deferred signature cannot activate when genuine SOS arrives',
    () async {
      await lifecycle.receive(await event(), sourcePeer: 'relay', now: now);
      final stored = await db.select(db.bleInbox).getSingle();
      final json = Map<String, Object?>.from(jsonDecode(stored.payload) as Map);
      json['signature'] = base64UrlEncode(List.filled(64, 0));
      await db
          .update(db.bleInbox)
          .write(BleInboxCompanion(payload: Value(relayCanonicalJson(json))));
      await trusted();
      expect((await inbox.find('relay:incident'))!.state, 'pending');
      expect(await lifecycle.authorizedEvents(), isEmpty);
      expect(
        (await db.select(db.bleInbox).getSingle()).processingState,
        'lifecycle_rejected',
      );
    },
  );

  test(
    'unverified candidate cannot establish a trusted lifecycle origin',
    () async {
      final valid = await offer(signer: attacker);
      final forged = RelayOfferEnvelope(
        body: valid.body,
        originSignature: base64UrlEncode(List.filled(64, 0)),
        hopCount: 0,
        pathKeyIds: valid.pathKeyIds,
        immediateSenderKeyId: valid.immediateSenderKeyId,
      );
      await expectLater(
        inbox.insertCandidate(
          forged,
          immutableDigest: await RelayCryptography().immutableDigest(
            forged.body,
          ),
          now: now,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      expect(
        await lifecycle.receive(
          await event(signer: attacker),
          sourcePeer: 'relay',
          now: now,
        ),
        LifecycleAuthorization.deferred,
      );
      expect(await inbox.watchCandidates().first, isEmpty);
    },
  );
}
