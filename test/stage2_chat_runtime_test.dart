import 'package:sos_app/features/nearby_ble/domain/chat_receipt.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/chat_relay_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_relay_envelope.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<bool> received(SimNode n, String id) async =>
      (await n.chat.loadMessages('incident-1')).any((m) => m.id == id);
  Future<ThreeNodeSimulation> ready() async {
    final s = ThreeNodeSimulation();
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    return s;
  }

  Future<void> retry(ThreeNodeSimulation s) async {
    s.clock.advance(const Duration(seconds: 6));
    for (final n in [s.a, s.b, s.c]) {
      await n.coordinator.processDue();
    }
  }

  test('real Session Proof and production Chat A-B-C then C-B-A', () async {
    final sim = ThreeNodeSimulation();
    addTearDown(sim.close);
    await sim.start();
    await sim.prepareIncident();
    await sim.a.send('m1', 'A to C', sim.c);
    await sim.network.until(
      () async =>
          (await sim.c.chat.loadMessages('incident-1'))
              .any((m) => m.id == 'm1'),
    );
    await sim.c.send('m2', 'C to A', sim.a);
    await sim.network.until(
      () async =>
          (await sim.a.chat.loadMessages('incident-1'))
              .any((m) => m.id == 'm2'),
    );
    expect(
      sim.network.allowedLinks.contains(sim.network.pair('A', 'C')),
      isFalse,
    );
    final transfers = sim.network.captures
        .where((p) => p.$3.type == ChatRelayTransfer.wireKind)
        .toList();
    expect(
      transfers.map((p) => '${p.$1}->${p.$2}'),
      containsAll(['A->B', 'B->C', 'C->B', 'B->A']),
    );
    final finalHop = transfers.firstWhere((p) => p.$1 == 'B' && p.$2 == 'C');
    final body = ChatRelayTransfer.fromJson(finalHop.$3.payload);
    expect(body.path, [
      (await sim.a.identity()).keyId,
      (await sim.b.identity()).keyId,
    ]);
    expect(
      ChatRelayEnvelope.fromCanonicalWire(body.wireEnvelope).body.senderKeyId,
      (await sim.a.identity()).keyId,
    );
    expect(await sim.b.db.select(sim.b.db.chatRelayInbox).get(), hasLength(2));
    expect(
      (await sim.c.chat.loadMessages('incident-1')).where((m) => m.id == 'm1'),
      hasLength(1),
    );
  });

  test(
    'urgent SOS-author text reaches C through B before a help offer',
    () async {
      final s = await ready();
      for (final n in [s.a, s.b, s.c]) {
        await n.db.delete(n.db.rescueResponseInbox).go();
        await n.db.delete(n.db.rescueResponseOutbox).go();
      }
      await s.a.send('before-accept', 'Urgent: trapped on second floor', s.c);
      await s.network.until(() => received(s.c, 'before-accept'));
      await s.network.pump();
      expect(
        (await s.c.chat.loadMessages('incident-1'))
            .where((m) => m.id == 'before-accept'),
        hasLength(1),
      );
      for (final n in [s.a, s.b, s.c]) {
        expect(await n.db.select(n.db.rescueResponseInbox).get(), isEmpty);
        expect(await n.db.select(n.db.rescueResponseOutbox).get(), isEmpty);
      }
      expect(
        s.network.allowedLinks.contains(s.network.pair('A', 'C')),
        isFalse,
      );
    },
  );

  test('20 alternating messages keep incident, original identity and exactly one bubble', () async {
    final s = await ready();
    final clock = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      final from = i.isEven ? s.a : s.c, to = i.isEven ? s.c : s.a;
      await from.send('conversation-$i', 'text-$i', to);
      try {
        await s.network.until(() => received(to, 'conversation-$i'));
      } catch (error) {
        throw StateError(
          'Conversation message $i: $error; logs: ${[
            for (final n in [s.a, s.b, s.c]) '${n.id}: ${n.logs.skip(n.logs.length > 15 ? n.logs.length - 15 : 0).join(' | ')}',
          ]}',
        );
      }
      s.clock.advance(const Duration(milliseconds: 1));
    }
    await s.network.until(
      () async =>
          (await s.a.chat.loadMessages('incident-1'))
              .where((m) => m.isMine)
              .every((m) => m.status == ChatDeliveryStatus.delivered) &&
          (await s.c.chat.loadMessages('incident-1'))
              .where((m) => m.isMine)
              .every((m) => m.status == ChatDeliveryStatus.delivered),
    );
    for (final node in [s.a, s.c]) {
      final messages = await node.chat.loadMessages('incident-1');
      expect(messages, hasLength(20));
      expect(messages.map((m) => m.id).toSet(), hasLength(20));
      expect(messages.map((m) => m.text), [
        for (var i = 0; i < 20; i++) 'text-$i',
      ]);
      for (var i = 0; i < 20; i++) {
        final message = messages[i];
        expect(message.sosId, 'incident-1');
        expect(message.createdAt.toUtc(), DateTime.utc(2026, 11, 6, 12));
        if (!message.isMine) {
          expect(
            message.senderId,
            (await (i.isEven ? s.a : s.c).identity()).keyId,
          );
        }
      }
      expect(
        messages
            .where((m) => m.isMine)
            .every((m) => m.status == ChatDeliveryStatus.delivered),
        isTrue,
      );
    }
    expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), hasLength(20));
    expect(await s.b.db.select(s.b.db.chatRelayOutbox).get(), hasLength(20));
    final texts = s.network.captures
        .where((p) => p.$3.type == ChatRelayTransfer.wireKind)
        .toList();
    expect(
      texts.length,
      40,
    ); // Exactly two radio hops per message, no A-C link.
    for (var i = 0; i < 20; i++) {
      final envelope = ChatRelayEnvelope.fromCanonicalWire(
        ChatRelayTransfer.fromJson(
          texts
              .firstWhere(
                (p) =>
                    ChatRelayEnvelope.fromCanonicalWire(
                      ChatRelayTransfer.fromJson(p.$3.payload).wireEnvelope,
                    ).body.messageId ==
                    'conversation-$i',
              )
              .$3
              .payload,
        ).wireEnvelope,
      );
      expect(
        envelope.body.createdAt,
        DateTime.utc(2026, 11, 6, 12).add(Duration(milliseconds: i)),
      );
    }
    // Drift v9 stores display timestamps at second resolution; immutable wire
    // timestamps retain millisecond ordering metadata without a migration.
    // Simulation counters only: not device FPS, radio speed or battery data.
    // ignore: avoid_print
    print(
      'SIMULATION 20 texts: ${s.network.frameWrites} frames, ${clock.elapsedMilliseconds}ms host test time; SQL (includes setup/assertions) ${[
        for (final n in [s.a, s.b, s.c]) '${n.id}: ${n.sql.snapshot}',
      ]}',
    );
  });

  test('B-C disconnected: B durably queues, then forwards after real reauthentication', () async {
    final s = await ready();
    s.network.disconnect('B', 'C');
    await s.network.pump();
    await s.a.send('offline', 'pending relay', s.c);
    await s.network.until(
      () async =>
          (await s.b.db.select(s.b.db.chatRelayOutbox).get()).isNotEmpty,
    );
    expect(await received(s.c, 'offline'), isFalse);
    s.network.connect('C', 'B');
    await s.network.until(() => received(s.c, 'offline'));
    expect(s.c.logs.any((l) => l.contains('session_authenticated')), isTrue);
  });

  test('packet loss retries without a false final Delivered state', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatRelayTransfer.wireKind);
    await s.a.send('loss', 'loss test', s.c);
    await s.network.pump();
    expect(await received(s.c, 'loss'), isFalse);
    final row = await ChatRelayRepository(
      s.a.db,
      ownerId: 'A',
    ).findOutbox('loss');
    expect(
      row!.state,
      'forwarded',
    ); // Local write alone cannot prove reception.
    s.network.dropTypes.clear();
    await retry(s);
    await s.network.until(() => received(s.c, 'loss'));
    expect(
      (await s.a.chat.loadMessages('incident-1')).single.status,
      isNot(ChatDeliveryStatus.delivered),
    );
  });

  test(
    'duplicate and reordered raw frames do not duplicate messages',
    () async {
      final s = await ready();
      s.network.reversePackets = true;
      s.network.duplicatePackets = true;
      await s.c.send('duplicates', 'once', s.a);
      await s.network.until(() => received(s.a, 'duplicates'));
      await s.network.pump();
      expect(
        (await s.a.chat.loadMessages('incident-1'))
            .where((m) => m.id == 'duplicates'),
        hasLength(1),
      );
      expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), hasLength(1));
    },
  );

  test(
    'latency and receiver persistence precede any claimed end-to-end receipt',
    () async {
      final s = await ready();
      s.network.latency = const Duration(seconds: 1);
      s.network.dropTypes.add(ChatReceipt.transferKind);
      await s.a.send('delay', 'delayed', s.c);
      await s.network.pump();
      expect(await received(s.c, 'delay'), isFalse);
      for (var i = 0; i < 5; i++) {
        s.clock.advance(const Duration(seconds: 1));
        await s.network.pump();
      }
      expect(await received(s.c, 'delay'), isTrue);
      expect(
        (await ChatRelayRepository(s.a.db, ownerId: 'A').findOutbox('delay'))!
            .state,
        isNot('delivered'),
      );
      s.network.dropTypes.remove(ChatReceipt.transferKind);
      await retry(s);
      for (var i = 0; i < 12; i++) {
        s.clock.advance(const Duration(seconds: 1));
        await s.network.pump();
      }
      expect(
        (await s.a.chat.loadMessages('incident-1')).single.status,
        ChatDeliveryStatus.delivered,
      );
    },
  );

  test('native write interruption remains durable and retries', () async {
    final s = await ready();
    s.network.failMessageTypeOnce = ChatRelayTransfer.wireKind;
    await s.a.send('write-failure', 'retry', s.c);
    await s.network.pump();
    final row = await ChatRelayRepository(
      s.a.db,
      ownerId: 'A',
    ).findOutbox('write-failure');
    expect(row!.state, 'failed');
    expect(row.retryCount, 1);
    await retry(s);
    await s.network.until(() => received(s.c, 'write-failure'));
  });

  test('expired queued Chat stops retrying and remains expired', () async {
    final s = await ready();
    s.network.disconnect('B', 'C');
    await s.network.pump();
    await s.a.send('expire', 'expires', s.c);
    await s.network.pump();
    s.clock.advance(const Duration(minutes: 31));
    await s.b.coordinator.processDue();
    final row = await ChatRelayRepository(
      s.b.db,
      ownerId: 'B',
    ).findOutbox('expire');
    expect(row!.state, 'expired');
    expect(
      await ChatRelayRepository(s.b.db, ownerId: 'B').due(now: s.clock.now),
      isEmpty,
    );
    expect(await received(s.c, 'expire'), isFalse);
  });

  test('retry budget is bounded when all text transfers are lost', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatRelayTransfer.wireKind);
    await s.a.send('bounded', 'bounded', s.c);
    await s.network.pump();
    for (var i = 0; i < ChatRelayRepository.maximumAttempts; i++) {
      s.clock.advance(Duration(seconds: 6 * (1 << i.clamp(0, 6))));
      await s.a.coordinator.processDue();
      await s.network.pump();
    }
    final row = await ChatRelayRepository(
      s.a.db,
      ownerId: 'A',
    ).findOutbox('bounded');
    expect(row!.retryCount, ChatRelayRepository.maximumAttempts);
    expect(await received(s.c, 'bounded'), isFalse);
    expect(
      await ChatRelayRepository(s.a.db, ownerId: 'A').due(now: s.clock.now),
      isEmpty,
    );
  });

  test(
    'coordinator restart and disk reopen retain pending B Chat and signed path',
    () async {
      final dir = await Directory.systemTemp.createTemp('stage2-chat-restart-');
      final file = File('${dir.path}/relay.sqlite');
      final s = ThreeNodeSimulation(relayFile: file);
      addTearDown(() async {
        await s.close();
        await dir.delete(recursive: true);
      });
      await s.start();
      await s.prepareIncident();
      s.network.disconnect('B', 'C');
      await s.network.pump();
      await s.a.send('restart', 'persisted pending', s.c);
      await s.network.until(
        () async =>
            (await s.b.db.select(s.b.db.chatRelayOutbox).get()).isNotEmpty,
      );
      s.network.disconnect('A', 'B');
      await s.network.pump();
      await s.b.close();
      s.b = SimNode('B', 2, s.network, file: file);
      await s.b.start();
      s.network.connect('C', 'B');
      await s.network.until(() => received(s.c, 'restart'));
      expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), hasLength(1));
    },
  );

  test(
    'proof response loss, virtual proof expiry and reauthentication',
    () async {
      final s = ThreeNodeSimulation();
      addTearDown(s.close);
      s.network.dropTypes.add(RelaySessionResponse.wireKind);
      for (final n in [s.a, s.b, s.c]) {
        await n.start();
      }
      s.network.connect('A', 'B');
      s.network.connect('C', 'B');
      await s.network.pump(rounds: 1000);
      expect(await s.c.authenticated(), isFalse);
      s.clock.advance(const Duration(minutes: 3));
      await s.network.pump();
      expect(s.c.logs.any((l) => l.contains('proof_timeout')), isTrue);
      s.network.dropTypes.clear();
      s.clock.advance(const Duration(seconds: 20));
      for (final n in [s.a, s.b, s.c]) {
        await n.coordinator.processDue();
      }
      await s.network.until(
        () async => await s.c.authenticated() && await s.a.authenticated(),
      );
      await s.prepareIncident();
      await s.a.send('after-proof', 'recovered', s.c);
      await s.network.until(() => received(s.c, 'after-proof'));
    },
  );

  test(
    'peer opt-out blocks forwarding; opt-in requires renewed proof',
    () async {
      final s = await ready();
      await s.b.coordinator.setRelayParticipationEnabled(false);
      await s.network.pump();
      await s.a.send('eligibility', 'wait for consent', s.c);
      await s.network.pump();
      expect(await received(s.c, 'eligibility'), isFalse);
      await s.b.coordinator.setRelayParticipationEnabled(true);
      await retry(s);
      await s.network.until(() => received(s.c, 'eligibility'));
    },
  );

  test(
    'personal Chat does not silently require origin or recipient relay opt-in',
    () async {
      final s = await ready();
      await s.a.coordinator.setRelayParticipationEnabled(false);
      await s.c.coordinator.setRelayParticipationEnabled(false);
      await s.network.pump(rounds: 1000);
      await s.a.send('personal', 'authorized participants', s.c);
      await s.network.until(() => received(s.c, 'personal'));
      await s.c.send('personal-reply', 'reply', s.a);
      await s.network.until(() => received(s.a, 'personal-reply'));
      expect(s.a.coordinator.relayParticipationEnabled, isFalse);
      expect(s.c.coordinator.relayParticipationEnabled, isFalse);
    },
  );

  test('old-session delayed packets are discarded after reconnect', () async {
    final s = await ready();
    s.network.holdPackets = true;
    await s.a.send('stale-packets', 'fresh session required', s.c);
    await s.network.pump();
    s.network.disconnect('A', 'B');
    await s.network.pump();
    s.network.holdPackets = false;
    s.network.releaseHeld();
    s.network.connect('A', 'B');
    await s.network.until(() async => await s.a.authenticated());
    expect(s.network.staleFramesDropped, greaterThan(0));
    expect(await received(s.c, 'stale-packets'), isFalse);
    await retry(s);
    await s.network.until(() => received(s.c, 'stale-packets'));
  });
  test(
    'disconnect during B-C frame transfer preserves the job until a new proof',
    () async {
      final s = await ready();
      s.network.afterFrameWrite = (from, to) {
        if (from == 'B' && to == 'C') {
          s.network.afterFrameWrite = null;
          s.network.disconnect('B', 'C');
        }
      };
      await s.a.send('mid-transfer', 'survives a partial transfer', s.c);
      await s.network.until(() async => !s.network.linked('B', 'C'));
      await s.network.pump();
      expect(await received(s.c, 'mid-transfer'), isFalse);
      final pending = await ChatRelayRepository(
        s.b.db,
        ownerId: 'B',
      ).findOutbox('mid-transfer');
      expect(pending, isNotNull);
      expect(pending!.state, 'failed');
      s.network.connect('C', 'B');
      await s.network.until(() => s.c.authenticated());
      await retry(s);
      await s.network.until(() => received(s.c, 'mid-transfer'));
      expect(
        (await s.c.chat.loadMessages('incident-1'))
            .where((m) => m.id == 'mid-transfer'),
        hasLength(1),
      );
    },
  );

  test('a lost raw frame is recovered by a bounded durable retry', () async {
    final s = await ready();
    s.network.dropLastFrameTypeOnce = ChatRelayTransfer.wireKind;
    await s.a.send('frame-loss', 'reassemble on retry', s.c);
    await s.network.pump();
    expect(await received(s.c, 'frame-loss'), isFalse);
    await retry(s);
    await s.network.until(() => received(s.c, 'frame-loss'));
  });

  test('direct authenticated Chat uses the same participant and persistence checks', () async {
    final s = await ready();
    s.network.disconnect('A', 'B');
    s.network.disconnect('B', 'C');
    await s.network.pump();
    s.network.allow('A', 'C');
    s.network.connect('A', 'C');
    await s.network.until(
      () async => await s.a.authenticated() && await s.c.authenticated(),
    );
    final captureStart = s.network.captures.length;
    await s.a.send('direct', 'one hop', s.c);
    await s.network.until(() => received(s.c, 'direct'));
    await s.c.send('direct-reply', 'one hop back', s.a);
    await s.network.until(() => received(s.a, 'direct-reply'));
    final transfers = s.network.captures
        .skip(captureStart)
        .where((p) => p.$3.type == ChatRelayTransfer.wireKind);
    expect(transfers.map((p) => '${p.$1}->${p.$2}'), ['A->C', 'C->A']);
    expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), isEmpty);
  });

  test('missing Chat receipts leave forwarded state and delayed duplicates stay idempotent', () async {
    final s = await ready();
    s.network.dropTypes.addAll([
      RelayReceiptType.hop.wireValue,
      RelayReceiptType.finalRecipient.wireValue,
      ChatReceipt.transferKind,
    ]);
    await s.a.send('no-receipt', 'receiver has persisted', s.c);
    await s.network.until(() => received(s.c, 'no-receipt'));
    await s.network.pump();
    final initial = await ChatRelayRepository(
      s.a.db,
      ownerId: 'A',
    ).findOutbox('no-receipt');
    expect(initial!.state, 'forwarded');
    // Explicitly drop signed Chat receipts; writes and SOS receipts cannot
    // substitute for final recipient persistence evidence.
    final old = s.network.captures
        .firstWhere(
          (p) =>
              p.$1 == 'B' &&
              p.$2 == 'C' &&
              p.$3.type == ChatRelayTransfer.wireKind,
        )
        .$3;
    s.clock.advance(const Duration(seconds: 20));
    s.network.inject('B', 'C', old);
    await s.network.pump();
    expect(
      (await s.c.chat.loadMessages('incident-1'))
          .where((m) => m.id == 'no-receipt'),
      hasLength(1),
    );
    expect(
      (await ChatRelayRepository(
        s.a.db,
        ownerId: 'A',
      ).findOutbox('no-receipt'))!.state,
      'forwarded',
    );
  });
  test('new Chat arriving during a retry drain forwards without waiting for polling', () async {
    final s = await ready();
    for (var i = 0; i < 20; i++) {
      final from = i.isEven ? s.a : s.c, to = i.isEven ? s.c : s.a;
      await from.send('overlap-$i', 'overlap-$i', to);
      await s.network.until(() => received(to, 'overlap-$i'));
      // Cross the 5-second retry deadline while new jobs are being enqueued.
      // No explicit scheduler polling is allowed to rescue a lost arrival.
      s.clock.advance(const Duration(seconds: 1));
    }
    for (final node in [s.a, s.c]) {
      final messages = await node.chat.loadMessages('incident-1');
      expect(messages, hasLength(20));
      expect(messages.map((m) => m.id).toSet(), hasLength(20));
      for (var i = 0; i < 20; i++) {
        final message = messages.singleWhere((m) => m.id == 'overlap-$i');
        expect(
          message.createdAt.toUtc(),
          DateTime.utc(2026, 11, 6, 12).add(Duration(seconds: i)),
        );
        expect(message.text, 'overlap-$i');
      }
    }
  });
}
