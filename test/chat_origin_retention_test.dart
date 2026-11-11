import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_response_repository.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThreeNodeSimulation> ready() async {
    final s = ThreeNodeSimulation();
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    await s.network.pump();
    return s;
  }

  // Repository-expiry assertions must not run the active origin's renewal
  // scheduler while moving the clock. Runtime renewal is exercised explicitly.
  void elapse(ThreeNodeSimulation s, Duration duration) {
    s.clock.now = s.clock.now.add(duration);
  }

  Future<void> suspend(ThreeNodeSimulation s) async {
    s.network.disconnect('A', 'B');
    s.network.disconnect('B', 'C');
    for (final n in [s.a, s.b, s.c]) {
      await n.coordinator.stop();
    }
  }

  Future<void> resume(ThreeNodeSimulation s) async {
    for (final n in [s.a, s.b, s.c]) {
      await n.start();
    }
    s.network.connect('A', 'B');
    s.network.connect('B', 'C');
    await s.network.until(
      () async => await s.a.authenticated() && await s.c.authenticated(),
    );
  }

  Future<void> cleanup(ThreeNodeSimulation s) async {
    for (final node in [s.a, s.b, s.c]) {
      final repository = RelayRepository(database: node.db);
      await repository.cleanupExpired(now: s.clock.now);
      expect(
        await repository.listForwardableMessages(now: s.clock.now),
        isEmpty,
      );
    }
  }

  test('established active Chat keeps presence past SOS TTL; closing it releases presence', () async {
    final s = await ready();
    await s.a.coordinator.setRelayParticipationEnabled(false);
    elapse(s, const Duration(minutes: 31));
    await s.a.coordinator.processDue();
    expect(s.a.transport.discovering, isTrue);
    expect(s.a.transport.advertising, isTrue);
    // Receipt/participation consent stays false: Chat presence is not an opt-in
    // to accepting third-party public SOS.
    await (s.a.db.update(s.a.db.sosMessages)
          ..where((r) => r.id.equals('incident-1')))
        .write(const SosMessagesCompanion(status: Value('cancelled')));
    await s.a.coordinator.cancelPublicRelay('incident-1');
    await s.a.coordinator.processDue();
    expect(s.a.transport.discovering, isFalse);
    expect(s.a.transport.advertising, isFalse);
  });

  for (final otherOwner in [false, true]) {
    test(
      'local active SOS is retained; foreign copies require owner-matched Chat; otherOwner=$otherOwner',
      () async {
        final s = await ready();
        for (final node in [s.a, s.b, s.c]) {
          if (otherOwner) {
            await node.db
                .update(node.db.rescueResponseInbox)
                .write(
                  const RescueResponseInboxCompanion(
                    ownerId: Value('other-owner'),
                  ),
                );
          } else {
            await node.db.delete(node.db.rescueResponseInbox).go();
          }
          await node.db.delete(node.db.rescueResponseOutbox).go();
        }
        elapse(s, const Duration(minutes: 31));
        await cleanup(s);
        expect(
          await RelayRepository(database: s.a.db)
              .lookupMessage(s.sos.body.originMessageId),
          isNotNull,
        );
        for (final node in [s.b, s.c]) {
          expect(
            await RelayRepository(database: node.db)
                .lookupMessage(s.sos.body.originMessageId),
            isNull,
          );
        }
        await s.a.db
            .update(s.a.db.sosMessages)
            .write(const SosMessagesCompanion(status: Value('cancelled')));
        await RelayRepository(database: s.a.db)
            .cleanupExpired(now: s.clock.now);
        expect(
          await RelayRepository(database: s.a.db)
              .lookupMessage(s.sos.body.originMessageId),
          isNull,
        );
      },
    );
  }

  test(
    'expired corrupt origin is purged even with an active Chat reference',
    () async {
      final s = await ready();
      await s.a.db
          .update(s.a.db.bleRelayMessages)
          .write(const BleRelayMessagesCompanion(wireEnvelope: Value('{}')));
      elapse(s, const Duration(minutes: 31));
      final repository = RelayRepository(database: s.a.db);
      expect(await repository.cleanupExpired(now: s.clock.now), 1);
      expect(
        await repository.lookupMessage(s.sos.body.originMessageId),
        isNull,
      );
    },
  );

  test(
    'queued Chat survives source downtime and active SOS renews on resume',
    () async {
      final s = await ready();
      await suspend(s);
      elapse(s, const Duration(minutes: 29));
      s.network.disconnect('A', 'B');
      await s.network.pump();
      await s.a.send(
        'cross-origin-expiry',
        'queued before origin expires',
        s.c,
      );
      await s.network.pump();
      elapse(s, const Duration(minutes: 2));
      await cleanup(s);
      final repository = RelayRepository(database: s.a.db);
      expect(
        await repository.lookupMessage(s.sos.body.originMessageId),
        isNotNull,
      );
      await expectLater(
        repository.loadVerifiedOffer(
          s.sos.body.originMessageId,
          now: s.clock.now,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      final captured = s.network.captures.length;
      await resume(s);
      await s.network.until(
        () async => await s.a.authenticated() && await s.b.authenticated(),
      );
      for (final node in [s.a, s.b, s.c]) {
        await node.coordinator.processDue();
      }
      await s.network.until(
        () async =>
            (await s.c.chat.loadMessages('incident-1'))
                .any((m) => m.id == 'cross-origin-expiry'),
      );
      expect(
        (await s.c.chat.loadMessages('incident-1'))
            .where((m) => m.id == 'cross-origin-expiry'),
        hasLength(1),
      );
      final renewed = await repository.loadVerifiedOffer(
        s.sos.body.originMessageId,
        now: s.clock.now,
      );
      expect(renewed.body.originMessageId, s.sos.body.originMessageId);
      expect(renewed.expiresAt.isAfter(s.clock.now), isTrue);
      expect(s.network.captures.skip(captured), isNotEmpty);
    },
  );

  test('active verified conversation can send both ways after SOS transport expires', () async {
    final s = await ready();
    await suspend(s);
    // A rescuer has its own signed outbox offer, not the origin's received
    // responder binding. Exercise that reference and the UI's resolver too.
    await s.c.db.delete(s.c.db.rescueResponseInbox).go();
    await RescueResponseRepository(
      s.c.db,
      ownerId: 'C',
    ).enqueueOffer(envelope: s.offer, origin: s.sos.body, now: s.clock.now);
    elapse(s, const Duration(minutes: 31));
    await cleanup(s);
    expect(
      (await s.a.coordinator.resolveVerifiedChatParticipant('incident-1'))
          ?.keyId,
      (await s.c.identity()).keyId,
    );
    expect(
      (await s.c.coordinator.resolveVerifiedChatParticipant('incident-1'))
          ?.keyId,
      (await s.a.identity()).keyId,
    );
    expect(
      await RelayRepository(database: s.a.db)
          .lookupMessage(s.sos.body.originMessageId),
      isNotNull,
    );
    await resume(s);
    await s.a.send('late-forward', 'active conversation forward', s.c);
    await s.network.until(
      () async =>
          (await s.c.chat.loadMessages('incident-1'))
              .any((m) => m.id == 'late-forward'),
    );
    await s.c.send('late-reply', 'active conversation reply', s.a);
    await s.network.until(
      () async =>
          (await s.a.chat.loadMessages('incident-1'))
              .any((m) => m.id == 'late-reply'),
    );
  });

  test('expired evidence is released after incident closes and pending Chat expires', () async {
    final s = await ready();
    await suspend(s);
    elapse(s, const Duration(minutes: 29));
    s.network.disconnect('A', 'B');
    await s.network.pump();
    await s.a.send('pending-on-close', 'pending signed Chat', s.c);
    await s.network.pump();
    for (final node in [s.a, s.b, s.c]) {
      await node.db
          .update(node.db.sosMessages)
          .write(const SosMessagesCompanion(status: Value('cancelled')));
    }
    elapse(s, const Duration(minutes: 2));
    await cleanup(s);
    expect(
      await RelayRepository(database: s.a.db)
          .lookupMessage(s.sos.body.originMessageId),
      isNotNull,
    );
    elapse(s, const Duration(minutes: 30));
    await cleanup(s);
    expect(
      await RelayRepository(database: s.a.db)
          .lookupMessage(s.sos.body.originMessageId),
      isNull,
    );
  });
}
