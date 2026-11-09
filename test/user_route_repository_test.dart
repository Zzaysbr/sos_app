import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/user_route_repository.dart';
import 'package:sos_app/features/nearby_ble/data/route_device_names.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_receipt.dart';

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
