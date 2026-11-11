import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/user_route_repository.dart';
import 'package:sos_app/features/nearby_ble/data/route_device_names.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_receipt.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_response_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/rescue_response_envelope.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<ThreeNodeSimulation> ready() async {
    final s = ThreeNodeSimulation();
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    return s;
  }

  UserRouteRepository repo(SimNode n) => UserRouteRepository(
    n.db,
    ownerId: n.id,
    readLocalKeyId: () async => (await n.identity()).keyId,
  );

  test(
    'accepted direct incident refreshes its signed route through a new relay',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      s.clock.now = DateTime.now().toUtc();
      s.network.allowedLinks.clear();
      s.network.allow('A', 'C');
      for (final n in [s.a, s.b, s.c]) {
        await n.start();
      }
      s.network.connect('A', 'C');
      await s.network.until(
        () async => await s.a.authenticated() && await s.c.authenticated(),
      );
      const incident = 'route-transition';
      await s.a.materialize(incident);
      final sos = await s.a.db.select(s.a.db.sosMessages).getSingle();
      await s.a.coordinator.enqueuePublicRelay(
        sos,
        includeLocation: false,
        scope: RelayAuthorizationScope.voluntaryRescue,
      );
      final candidates = RescueInboxRepository(s.c.db, ownerId: s.c.id);
      await s.network.until(
        () async => (await candidates.watchCandidates().first).isNotEmpty,
      );
      final received = (await candidates.watchCandidates().first).single;
      final accepted = (await candidates.acceptLocally(
        received.originMessageId,
      ))!;
      final stored = (await RelayRepository(database: s.c.db)
          .lookupMessage(received.originMessageId))!;
      await RescueResponseRepository(
        s.c.db,
        ownerId: s.c.id,
      ).signAndEnqueueOffer(
        origin: RelayOfferEnvelope.fromCanonicalWire(stored.wireEnvelope)
            .responseOrigin,
        responder: await s.c.identity(),
        sessionBinding: 'initial',
        receivedSos: accepted,
        now: s.clock.now,
      );
      await s.c.coordinator.processDue();
      await s.network.until(
        () async =>
            (await s.a.db.select(s.a.db.rescueResponseInbox).get()).isNotEmpty,
      );
      final originalResponse = await s.a.db
          .select(s.a.db.rescueResponseInbox)
          .getSingle();
      expect((await repo(s.a).read(incident)).sos.single.hopCount, 1);
      s.clock.advance(const Duration(seconds: 2));
      s.network.disconnect('A', 'C');
      s.network.allowedLinks.clear();
      s.network.allow('A', 'B');
      s.network.allow('B', 'C');
      s.network.connect('B', 'C');
      s.network.connect('A', 'B');
      await s.network.until(
        () async =>
            (await candidates.find(received.originMessageId))
                ?.incomingHopCount ==
            1,
      );
      await s.network.until(
        () async =>
            (await s.a.db.select(s.a.db.rescueResponseInbox).get()).length == 2,
      );
      final latest = (await candidates.find(received.originMessageId))!;
      expect(latest.state, 'locallyAccepted');
      expect(latest.acceptanceId, accepted.acceptanceId);
      expect(latest.acceptedAt, accepted.acceptedAt);
      final keys = [
        (await s.a.identity()).keyId,
        (await s.b.identity()).keyId,
        (await s.c.identity()).keyId,
      ];
      for (final n in [s.a, s.b, s.c]) {
        final route = (await repo(n).read(incident)).sos.single;
        expect(route.nodes.map((n) => n.keyId), keys);
        expect(route.hopCount, 2);
      }
      // Delayed arrival/replay of older signed feedback cannot supersede the new path.
      await (s.a.db.update(
        s.a.db.rescueResponseInbox,
      )..where((r) => r.messageId.equals(originalResponse.messageId))).write(
        RescueResponseInboxCompanion(
          receivedAt: Value(s.clock.now.add(const Duration(seconds: 30))),
        ),
      );
      expect((await repo(s.a).read(incident)).sos.single.hopCount, 2);
      // Same-path duplicate reception must not ask for help or enqueue another report.
      await s.a.coordinator.processDue();
      await s.b.coordinator.processDue();
      await s.c.coordinator.processDue();
      await s.network.pump();
      expect(
        (await s.c.db.select(s.c.db.rescueResponseOutbox).get())
            .where((r) => r.messageId.startsWith('route:'))
            .length,
        1,
      );
      // Reproduce an upgrade: newer verified relay storage, old UI candidate.
      // Runtime reconciliation must repair it without another SOS/Help tap.
      final crypto = RelayCryptography();
      final base = RelayOfferEnvelope.fromCanonicalWire(stored.wireEnvelope);
      s.clock.now = base.body.expiresAt.add(const Duration(seconds: 1));
      final middle = await s.b.identity();
      final source = await s.a.identity();
      final digest = await crypto.immutableDigest(base.body);
      final attestation = RelayHopAttestation(
        originMessageId: base.body.originMessageId,
        immutableDigest: digest,
        relayKeyId: middle.keyId,
        relayPublicKey: base64UrlEncode(middle.publicKey),
        hopCount: 1,
        pathKeyIds: keys.take(2).toList(),
        signature: '',
      );
      final renewed = RelayOfferEnvelope(
        body: base.body,
        originSignature: base.originSignature,
        hopCount: 1,
        pathKeyIds: attestation.pathKeyIds,
        immediateSenderKeyId: middle.keyId,
        lease: await crypto.signOriginLease(
          base.body,
          s.clock.now,
          source.keyPair,
        ),
        hopAttestations: [
          RelayHopAttestation(
            originMessageId: attestation.originMessageId,
            immutableDigest: digest,
            relayKeyId: middle.keyId,
            relayPublicKey: attestation.relayPublicKey,
            hopCount: 1,
            pathKeyIds: attestation.pathKeyIds,
            signature: await crypto.signHopAttestation(
              attestation,
              middle.keyPair,
            ),
          ),
        ],
      );
      await RelayRepository(database: s.c.db).acceptIncomingOffer(
        renewed,
        sourceDeviceId: 'B',
        relayEnabled: true,
        now: s.clock.now,
      );
      await s.c.db
          .update(s.c.db.rescueInbox)
          .write(
            RescueInboxCompanion(
              incomingHopCount: const Value(0),
              incomingPath: Value(jsonEncode([keys.first])),
              receivedAt: Value(accepted.receivedAt),
            ),
          );
      await s.c.coordinator.processDue();
      expect(s.c.logs, contains(contains('acceptedSosRouteReconciled')));
      final repaired = (await candidates.find(received.originMessageId))!;
      expect(repaired.incomingHopCount, 1);
      expect(repaired.acceptanceId, accepted.acceptanceId);
      expect((await repo(s.c).read(incident)).sos.single.hopCount, 2);
      // Removing or expiring the renewal must still reject the same old origin.
      await expectLater(
        candidates.insertCandidate(
          base,
          immutableDigest: digest,
          now: s.clock.now,
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      await expectLater(
        candidates.insertCandidate(
          renewed,
          immutableDigest: digest,
          now: renewed.expiresAt.add(const Duration(seconds: 1)),
        ),
        throwsA(isA<RelayProtocolException>()),
      );
      expect(
        (await candidates.find(received.originMessageId))!.acceptanceId,
        accepted.acceptanceId,
      );
    },
  );

  test(
    'candidate route refresh rejects tampering and preserves archived state',
    () async {
      final s = await ready();
      final inbox = RescueInboxRepository(s.c.db, ownerId: s.c.id);
      final crypto = RelayCryptography();
      final identity = await s.b.identity();
      final digest = await crypto.immutableDigest(s.sos.body);
      final path = [s.sos.body.originKeyId, identity.keyId];
      final unsigned = RelayHopAttestation(
        originMessageId: s.sos.body.originMessageId,
        immutableDigest: digest,
        relayKeyId: identity.keyId,
        relayPublicKey: base64UrlEncode(identity.publicKey),
        hopCount: 1,
        pathKeyIds: path,
        signature: '',
      );
      final forwarded = RelayOfferEnvelope(
        body: s.sos.body,
        originSignature: s.sos.originSignature,
        hopCount: 1,
        pathKeyIds: path,
        immediateSenderKeyId: identity.keyId,
        hopAttestations: [
          RelayHopAttestation(
            originMessageId: unsigned.originMessageId,
            immutableDigest: digest,
            relayKeyId: identity.keyId,
            relayPublicKey: unsigned.relayPublicKey,
            hopCount: 1,
            pathKeyIds: path,
            signature: await crypto.signHopAttestation(
              unsigned,
              identity.keyPair,
            ),
          ),
        ],
      );
      final refreshed = await inbox.insertCandidate(
        forwarded,
        immutableDigest: digest,
        now: s.clock.now,
      );
      expect(refreshed.incomingHopCount, 1);
      expect(refreshed.state, 'pending');
      final forged = RelayOfferEnvelope(
        body: s.sos.body,
        originSignature: base64UrlEncode(List.filled(64, 0)),
        hopCount: 0,
        pathKeyIds: s.sos.pathKeyIds,
        immediateSenderKeyId: s.sos.immediateSenderKeyId,
      );
      await expectLater(
        inbox.insertCandidate(
          forged,
          immutableDigest: digest,
          now: s.clock.now,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      expect(
        (await inbox.find(s.sos.body.originMessageId))!.incomingHopCount,
        1,
      );
      await s.c.db
          .update(s.c.db.rescueInbox)
          .write(const RescueInboxCompanion(state: Value('archivedLocally')));
      final archived = await inbox.insertCandidate(
        s.sos,
        immutableDigest: digest,
        now: s.clock.now,
      );
      expect(archived.state, 'archivedLocally');
      expect(archived.incomingHopCount, 1);
      final wrongOwner = UserRouteRepository(
        s.b.db,
        ownerId: 'another-user',
        readLocalKeyId: () async => (await s.b.identity()).keyId,
      );
      expect((await wrongOwner.read('incident-1')).sos, isEmpty);
    },
  );

  test(
    'stored incoming SOS path counts intermediaries separately from radio legs',
    () async {
      final s = await ready();
      // The fixture's SOS is seeded as direct, despite the simulation's A-B-C
      // radio graph. A projection must not infer hops from nearby connections.
      var route = (await repo(s.c).read('incident-1')).sos.single;
      expect(route.intermediateCount, 0);
      expect(route.hopCount, 1);
      final a = (await s.a.identity()).keyId, b = (await s.b.identity()).keyId;
      await s.c.db
          .update(s.c.db.rescueInbox)
          .write(
            RescueInboxCompanion(
              incomingHopCount: const Value(1),
              incomingPath: Value(jsonEncode([a, b])),
            ),
          );
      route = (await repo(s.c).read('incident-1')).sos.single;
      expect(route.intermediateCount, 1);
      expect(route.hopCount, 2);
      expect(route.nodes.map((n) => n.keyId), [
        a,
        b,
        (await s.c.identity()).keyId,
      ]);
      expect(route.stage, UserRouteStage.received);
    },
  );

  test(
    'signed Help Offer returns the actual two-hop SOS path to its origin',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      s.clock.now = DateTime.now().toUtc();
      await s.start();
      const incident = 'live-route';
      await s.a.materialize(incident);
      final sos = await s.a.db.select(s.a.db.sosMessages).getSingle();
      final originRoutes = repo(s.a);
      final candidates = RescueInboxRepository(s.c.db, ownerId: s.c.id);
      await s.a.coordinator.enqueuePublicRelay(
        sos,
        includeLocation: false,
        scope: RelayAuthorizationScope.voluntaryRescue,
      );
      await s.network.until(
        () async => (await candidates.watchCandidates().first).isNotEmpty,
      );
      final inbound = (await candidates.watchCandidates().first).single;
      expect(inbound.incomingHopCount, 1);
      expect((await originRoutes.read(incident)).sos.first.hopCount, 1);
      final update = originRoutes
          .watch(incident)
          .firstWhere(
            (snapshot) => snapshot.sos.any(
              (route) => route.extent == UserRouteExtent.confirmedSos,
            ),
          );
      final accepted = await candidates.acceptLocally(inbound.originMessageId);
      expect(accepted?.state, 'locallyAccepted');
      final stored = (await RelayRepository(database: s.c.db)
          .lookupMessage(inbound.originMessageId))!;
      final origin = RelayOfferEnvelope.fromCanonicalWire(stored.wireEnvelope)
          .body;
      final responder = await s.c.identity();
      await RescueResponseRepository(
        s.c.db,
        ownerId: s.c.id,
      ).signAndEnqueueOffer(
        origin: origin,
        responder: responder,
        sessionBinding: 'legacy-binding',
        receivedSos: accepted,
        now: s.clock.now,
      );
      await s.c.coordinator.processDue();
      await s.network.until(
        () async =>
            (await s.a.db.select(s.a.db.rescueResponseInbox).get()).isNotEmpty,
      );
      final route = (await update).sos.single;
      expect(route.nodes.map((node) => node.keyId), [
        (await s.a.identity()).keyId,
        (await s.b.identity()).keyId,
        responder.keyId,
      ]);
      expect(route.hopCount, 2);
      expect(route.stage, UserRouteStage.confirmed);

      final row = await s.a.db.select(s.a.db.rescueResponseInbox).getSingle();
      final response = RescueResponseEnvelope.fromCanonicalWire(row.payload);
      final forged = RescueResponseEnvelope(
        body: response.body,
        signature: base64UrlEncode(List.filled(64, 0)),
      );
      await s.a.db
          .update(s.a.db.rescueResponseInbox)
          .write(
            RescueResponseInboxCompanion(
              payload: Value(forged.toCanonicalWire()),
            ),
          );
      expect(
        (await originRoutes.read(incident)).sos.first.extent,
        UserRouteExtent.nextDevice,
      );
    },
  );

  test(
    'malformed, looped and inconsistent SOS paths never become a route',
    () async {
      final s = await ready();
      final a = (await s.a.identity()).keyId;
      for (final path in [
        'not-json',
        jsonEncode([a, a]),
        jsonEncode(['unknown-key']),
      ]) {
        await s.c.db
            .update(s.c.db.rescueInbox)
            .write(
              RescueInboxCompanion(
                incomingHopCount: const Value(1),
                incomingPath: Value(path),
              ),
            );
        expect((await repo(s.c).read('incident-1')).sos, isEmpty);
      }
    },
  );

  test('real signed Chat route shows receiver path but never invents sender intermediaries', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatReceipt.transferKind);
    final origin = repo(s.a), receiver = repo(s.c);
    final update = receiver
        .watch('incident-1')
        .firstWhere((v) => v.chat.containsKey('route-message'));
    await s.a.send('route-message', 'test', s.c);
    await s.network.until(
      () async => (await s.c.chat.loadMessages('incident-1')).isNotEmpty,
    );
    final received = (await update).chat['route-message']!;
    expect(received.intermediateCount, 1);
    expect(received.hopCount, 2);
    expect(received.nodes.map((n) => n.keyId), [
      (await s.a.identity()).keyId,
      (await s.b.identity()).keyId,
      (await s.c.identity()).keyId,
    ]);
    var sent = (await origin.read('incident-1')).chat['route-message']!;
    expect(sent.stage, isNot(UserRouteStage.confirmed));
    expect(sent.extent, UserRouteExtent.endpointsOnly);
    expect(sent.intermediateCount, isNull);
    s.network.dropTypes.remove(ChatReceipt.transferKind);
    for (var i = 0; i < 5; i++) {
      s.clock.advance(const Duration(seconds: 6));
      for (final n in [s.a, s.b, s.c]) {
        await n.coordinator.processDue();
      }
      await s.network.pump();
    }
    sent = (await origin.read('incident-1')).chat['route-message']!;
    expect(sent.stage, UserRouteStage.confirmed);
    expect(
      sent.hopCount,
      isNull,
      reason: 'Final storage receipt carries no full forward path.',
    );
    // A forged/malformed local receipt cannot upgrade the UI confirmation.
    final row = await s.a.db.select(s.a.db.chatReceipts).getSingle();
    final receipt = ChatReceipt.fromWire(row.receipt!);
    final forged = ChatReceipt(
      receipt.body,
      base64UrlEncode(List.filled(64, 0)),
    );
    await s.a.db
        .update(s.a.db.chatReceipts)
        .write(ChatReceiptsCompanion(receipt: Value(forged.toWire())));
    expect(
      (await origin.read('incident-1')).chat['route-message']!.stage,
      isNot(UserRouteStage.confirmed),
    );
  });

  test(
    'owner without an authorized incident sees no route or Chat identities',
    () async {
      final s = await ready();
      await s.a.send('private-message', 'test', s.c);
      await s.network.pump();
      final snapshot = await UserRouteRepository(
        s.c.db,
        ownerId: 'another-owner',
      ).read('incident-1');
      expect(snapshot.sos, isEmpty);
      expect(snapshot.chat, isEmpty);
    },
  );

  test('nicknames persist per owner, remain local and reset to code', () async {
    final root = await Directory.systemTemp.createTemp('route-labels-');
    addTearDown(() => root.delete(recursive: true));
    final key = base64UrlEncode(List.filled(32, 1));
    final names = RouteDeviceNames(ownerId: 'one', directory: root);
    await names.save(key, 'มือถือแม่');
    expect(
      (await RouteDeviceNames(ownerId: 'one', directory: root).load())[key],
      'มือถือแม่',
    );
    expect(
      await RouteDeviceNames(ownerId: 'two', directory: root).load(),
      isEmpty,
    );
    expect(shortRouteDeviceCode(key), '010101');
    await names.save(key, '');
    expect(await names.load(), isEmpty);
    await expectLater(
      names.save(key, 'fake\u202ephone'),
      throwsFormatException,
    );
    await expectLater(
      names.save('not-a-key', 'Phone'),
      throwsA(isA<Exception>()),
    );
  });
}
