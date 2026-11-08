import 'dart:io';

import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/chat_relay_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_receipt.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_relay_envelope.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';

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

  Future<void> tick(ThreeNodeSimulation s) async {
    s.clock.advance(const Duration(seconds: 6));
    for (final n in [s.a, s.b, s.c]) {
      await n.coordinator.processDue();
    }
    await s.network.pump();
  }

  Future<bool> delivered(ThreeNodeSimulation s) async =>
      (await s.a.chat.loadMessages('incident-1')).single.status ==
      ChatDeliveryStatus.delivered;
  test(
    'outgoing signed Chat alone keeps startup recovery ready during backoff',
    () async {
      final s = await ready();
      s.network.dropTypes.add(ChatRelayTransfer.wireKind);
      await s.a.send('startup-outgoing', 'synthetic', s.c);
      await s.network.pump();
      expect(await s.a.db.select(s.a.db.chatReceipts).get(), isEmpty);
      expect(await s.a.coordinator.hasPendingBleRecovery(), isTrue);
    },
  );
  test('receipt loss recovers with same receipt and no duplicate display; delayed forwarded cannot downgrade', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatReceipt.transferKind);
    await s.a.send('receipt-loss', 'synthetic', s.c);
    await s.network.until(
      () async => (await s.c.chat.loadMessages('incident-1')).isNotEmpty,
    );
    await s.network.pump();
    expect(await delivered(s), isFalse);
    final original =
        (await s.c.db.select(s.c.db.chatReceipts).getSingle()).receipt;
    expect(original, isNotNull);
    s.network.dropTypes.clear();
    await tick(s);
    await s.network.until(() => delivered(s));
    expect(
      (await s.c.db.select(s.c.db.chatReceipts).getSingle()).receipt,
      original,
    );
    expect(await s.c.chat.loadMessages('incident-1'), hasLength(1));
    final senderRepo = ChatRelayRepository(s.a.db, ownerId: 'A');
    await senderRepo.markForwarded('receipt-loss');
    await senderRepo.markFailed('receipt-loss', StateError('late'));
    expect((await senderRepo.findOutbox('receipt-loss'))!.state, 'delivered');
    await s.a.chat.updateDeliveryStatus(
      'receipt-loss',
      ChatDeliveryStatus.sent,
    );
    expect(await delivered(s), isTrue);
  });
  test('receipt exists only after durable application message, recover callback failure', () async {
    final s = await ready();
    await s.c.db.customStatement(
      "CREATE TRIGGER fail_chat BEFORE INSERT ON chat_messages BEGIN SELECT RAISE(ABORT,'injected persist failure'); END",
    );
    await s.a.send('persist-fail', 'synthetic', s.c);
    await s.network.until(
      () async => (await s.c.db.select(s.c.db.chatRelayInbox).get()).isNotEmpty,
    );
    await s.network.pump();
    expect(await s.c.chat.loadMessages('incident-1'), isEmpty);
    expect(
      (await s.c.db.select(s.c.db.chatReceipts).getSingle()).receipt,
      isNull,
    );
    expect(await delivered(s), isFalse);
    await s.c.db.customStatement('DROP TRIGGER fail_chat');
    await tick(s);
    await s.network.until(() => delivered(s));
  });
  test('wrong digest, incident, signer, timestamp, expiry and conflicting replay cannot acknowledge', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatReceipt.transferKind);
    await s.a.send('security', 'synthetic', s.c);
    await s.network.until(
      () async => (await s.c.db.select(s.c.db.chatReceipts).get()).any(
        (r) => r.receipt != null,
      ),
    );
    final stored = await s.c.db.select(s.c.db.chatReceipts).getSingle();
    final valid = ChatReceipt.fromWire(stored.receipt!);
    final envelope = ChatRelayEnvelope.fromCanonicalWire(
      (await ChatRelayRepository(s.a.db, ownerId: 'A').findOutbox('security'))!
          .payload,
    );
    await valid.verify(envelope, s.clock.now);
    for (final entry in <String, Object?>{
      'digest': 'wrong',
      'incidentId': 'other',
      'recipientKeyId': (await s.b.identity()).keyId,
      'persistedAt': envelope.body.expiresAt.toIso8601String(),
      'expiresAt': envelope.body.expiresAt
          .add(const Duration(days: 2))
          .toIso8601String(),
    }.entries) {
      final forged = ChatReceipt({
        ...valid.body,
        entry.key: entry.value,
      }, valid.signature);
      await expectLater(
        forged.verify(envelope, s.clock.now),
        throwsA(anything),
      );
    }
    final attacker = ChatReceipt(
      valid.body,
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==',
    );
    await expectLater(
      attacker.verify(envelope, s.clock.now),
      throwsA(anything),
    );
    await expectLater(
      valid.verify(envelope, valid.expiresAt),
      throwsA(anything),
    );
    expect(await delivered(s), isFalse);
  });
  test('durable reverse receipt survives intermediary restart without original SOS forwarding renewal', () async {
    final dir = await Directory.systemTemp.createTemp('receipt-restart-');
    final file = File('${dir.path}/b.sqlite');
    final s = ThreeNodeSimulation(relayFile: file);
    addTearDown(() async {
      await s.close();
      await dir.delete(recursive: true);
    });
    await s.start();
    await s.prepareIncident();
    s.network.dropMessage = (from, to, m) =>
        from == 'B' && to == 'A' && m.type == ChatReceipt.transferKind;
    await s.a.send('restart-receipt', 'synthetic', s.c);
    await s.network.until(
      () async => (await s.b.db.select(s.b.db.chatReceipts).get()).any(
        (r) => r.receipt != null,
      ),
    );
    final before =
        (await s.b.db.select(s.b.db.chatReceipts).getSingle()).receipt;
    expect(await s.b.coordinator.hasPendingBleRecovery(), isTrue);
    s.network.disconnect('A', 'B');
    s.network.disconnect('C', 'B');
    await s.network.pump();
    await s.b.close();
    s.b = SimNode('B', 2, s.network, file: file);
    await s.b.start();
    s.network.dropMessage = null;
    s.network.connect('A', 'B');
    await s.network.until(() => s.a.authenticated());
    await tick(s);
    await s.network.until(() => delivered(s));
    expect(
      (await s.b.db.select(s.b.db.chatReceipts).getSingle()).receipt,
      before,
    );
  });
  test('no receipt at legacy peer keeps sent; retry budget and expiry stay bounded', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatReceipt.transferKind);
    await s.a.send('bounded', 'synthetic', s.c);
    await s.network.until(
      () async => (await s.c.db.select(s.c.db.chatReceipts).get()).any(
        (r) => r.receipt != null,
      ),
    );
    for (var i = 0; i < 10; i++) {
      s.clock.advance(const Duration(seconds: 320));
      for (final n in [s.a, s.b, s.c]) {
        await n.coordinator.processDue();
      }
      await s.network.pump();
    }
    expect(await delivered(s), isFalse);
    final rows = await s.c.db.select(s.c.db.chatReceipts).get();
    expect(rows.single.retryCount, 8);
    expect(
      s.network.captures.where(
        (p) =>
            p.$1 == 'C' && p.$2 == 'B' && p.$3.type == ChatReceipt.transferKind,
      ),
      hasLength(8),
    );
    s.clock.advance(const Duration(hours: 1));
    await s.c.coordinator.processDue();
    expect(await s.c.db.select(s.c.db.chatReceipts).get(), isEmpty);
  });
  test('tampered receipt on a proven session is rejected before sender status update', () async {
    final s = await ready();
    s.network.dropTypes.add(ChatReceipt.transferKind);
    await s.a.send('injected-receipt', 'synthetic', s.c);
    await s.network.until(
      () async => s.network.captures.any(
        (p) =>
            p.$1 == 'C' && p.$2 == 'B' && p.$3.type == ChatReceipt.transferKind,
      ),
    );
    final packet = s.network.captures
        .lastWhere(
          (p) =>
              p.$1 == 'C' &&
              p.$2 == 'B' &&
              p.$3.type == ChatReceipt.transferKind,
        )
        .$3;
    final valid = ChatReceipt.fromWire(packet.payload['receipt'] as String);
    final forged = ChatReceipt({
      ...valid.body,
      'digest': 'other-message',
    }, valid.signature);
    s.network.dropTypes.clear();
    s.network.inject(
      'C',
      'B',
      BleMessage(
        id: packet.id,
        type: packet.type,
        createdAt: packet.createdAt,
        payload: {...packet.payload, 'receipt': forged.toWire()},
      ),
    );
    await s.network.pump();
    expect(await delivered(s), isFalse);
    expect(
      (await s.b.db.select(s.b.db.chatReceipts).getSingle()).receipt,
      isNull,
    );
    expect(
      s.b.logs.any((l) => l.contains('receipt') && l.contains('invalid')),
      isTrue,
    );
    await tick(s);
    await s.network.until(() => delivered(s));
  });
  test('late valid receipt within bounded grace acknowledges transport-expired Chat', () async {
    final s = await ready();
    s.network.dropMessage = (from, to, m) =>
        from == 'B' && to == 'A' && m.type == ChatReceipt.transferKind;
    await s.a.send('late-receipt', 'synthetic', s.c);
    await s.network.until(
      () async => (await s.b.db.select(s.b.db.chatReceipts).get()).any(
        (r) => r.receipt != null,
      ),
    );
    s.clock.advance(const Duration(minutes: 31));
    await s.a.coordinator.processDue();
    expect(
      (await ChatRelayRepository(
        s.a.db,
        ownerId: 'A',
      ).findOutbox('late-receipt'))!.state,
      'expired',
    );
    s.network.dropMessage = null;
    await s.b.coordinator.processDue();
    await s.network.pump();
    await s.network.until(() => delivered(s));
  });
}
