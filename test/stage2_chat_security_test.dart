import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';
import 'package:sos_app/features/nearby_ble/data/chat_relay_authorization.dart';
import 'package:sos_app/features/nearby_ble/data/chat_relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/relay_key_store.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ThreeNodeSimulation s;
  setUp(() async {
    s = ThreeNodeSimulation();
    await s.start();
    await s.prepareIncident();
  });
  tearDown(() => s.close());

  Future<ChatRelayTransfer> input({
    String id = 'attack',
    String incident = 'incident-1',
    String binding = 'incident-1',
    RelaySigningIdentity? signer,
    RelaySigningIdentity? recipient,
    String? offer,
  }) async {
    final a = await s.a.identity(),
        c = recipient ?? await s.c.identity(),
        author = signer ?? a;
    final body = ChatRelayBody(
      messageId: id,
      incidentId: incident,
      senderKeyId: author.keyId,
      senderPublicKey: base64UrlEncode(author.publicKey),
      recipientKeyId: c.keyId,
      recipientPublicKey: base64UrlEncode(c.publicKey),
      originIncidentBinding: binding,
      text: 'security test',
      createdAt: s.clock.now,
      expiresAt: s.clock.now.add(const Duration(minutes: 30)),
    );
    final envelope = ChatRelayEnvelope(
      body: body,
      signature: await RelayCryptography().signChatRelay(body, author.keyPair),
    );
    var base = ChatRelayTransfer(
      attemptId: '',
      wireEnvelope: envelope.toCanonicalWire(),
      hopCount: 0,
      wireRescueOffer: offer ?? s.offer.toCanonicalWire(),
    );
    if (author.keyId != a.keyId) {
      base = await base.forNextHop(
        identity: author,
        nextHopKeyId: a.keyId,
        binding: 'outside-session',
      );
    }
    return base.forNextHop(
      identity: a,
      nextHopKeyId: (await s.b.identity()).keyId,
      binding: await s.network.binding('A', 'B'),
    );
  }

  test(
    'emergency text rejects a non-origin signer and reverse reply',
    () async {
      final binding =
          'emergency-text:${s.sos.body.originMessageId}:'
          '${await RelayCryptography().immutableDigest(s.sos.body)}';
      final wrong = await input(
        binding: binding,
        signer: await s.c.identity(),
        recipient: await s.a.identity(),
      );
      await expectLater(
        ChatRelayAuthorization(s.b.db, ownerId: s.b.id).authorize(
          ChatRelayEnvelope.fromCanonicalWire(wrong.wireEnvelope),
          suppliedOffer: binding,
        ),
        throwsA(isA<FormatException>()),
      );
    },
  );

  Future<void> inject(
    ChatRelayTransfer transfer, {
    Map<String, Object?>? json,
  }) async {
    s.network.inject(
      'A',
      'B',
      BleMessage(
        id: transfer.attemptId,
        type: ChatRelayTransfer.wireKind,
        payload: json ?? transfer.toJson(),
        createdAt: s.clock.now,
      ),
    );
    await s.network.pump(rounds: 600);
  }

  Future<void> rejected() async {
    expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), isEmpty);
    expect(await s.c.db.select(s.c.db.chatRelayInbox).get(), isEmpty);
    expect(
      s.b.logs.any((l) => l.contains('BLE inbound processing failed')),
      isTrue,
    );
  }

  test(
    'valid original sender and authenticated hop are checked independently',
    () async {
      final transfer = await input(id: 'valid');
      await inject(transfer);
      expect(await s.c.db.select(s.c.db.chatRelayInbox).get(), hasLength(1));
      final last = s.network.captures.lastWhere(
        (p) =>
            p.$1 == 'B' &&
            p.$2 == 'C' &&
            p.$3.type == ChatRelayTransfer.wireKind,
      );
      final forwarded = ChatRelayTransfer.fromJson(last.$3.payload);
      expect(forwarded.path.last, (await s.b.identity()).keyId);
      expect(
        ChatRelayEnvelope.fromCanonicalWire(forwarded.wireEnvelope)
            .body
            .senderKeyId,
        (await s.a.identity()).keyId,
      );
    },
  );
  test(
    'arbitrary correctly signed sender is not an authorized participant',
    () async {
      final outsider = await RelayIdentityService(keyStore: SimulationKeys(9))
          .loadOrCreate(allowCreate: true);
      await inject(await input(signer: outsider));
      await rejected();
    },
  );
  test('unrelated recipient identity is rejected', () async {
    final outsider = await RelayIdentityService(keyStore: SimulationKeys(9))
        .loadOrCreate(allowCreate: true);
    await inject(await input(recipient: outsider));
    await rejected();
  });
  test('wrong incident cannot reuse a verified offer', () async {
    await inject(await input(incident: 'other-incident'));
    await rejected();
  });
  test('wrong immutable incident binding is rejected', () async {
    await inject(await input(binding: 'untrusted-digest'));
    await rejected();
  });
  test('forged original signature is rejected even with a valid immediate hop signature', () async {
    final good = await input();
    final json = ChatRelayEnvelope.fromCanonicalWire(good.wireEnvelope)
        .toJson();
    json['signature'] = base64UrlEncode(List.filled(64, 0));
    final base = ChatRelayTransfer(
      attemptId: '',
      wireEnvelope: relayCanonicalJson(json),
      hopCount: 0,
      wireRescueOffer: good.wireRescueOffer,
    );
    final bad = await base.forNextHop(
      identity: await s.a.identity(),
      nextHopKeyId: (await s.b.identity()).keyId,
      binding: await s.network.binding('A', 'B'),
    );
    await inject(bad);
    await rejected();
  });
  test('forged signed offer cannot authorize a participant', () async {
    final json = s.offer.toJson();
    json['signature'] = base64UrlEncode(List.filled(64, 0));
    await inject(await input(offer: relayCanonicalJson(json)));
    await rejected();
  });
  test('missing path evidence fails closed', () async {
    final good = await input();
    await inject(good, json: {...good.toJson(), 'hops': []});
    await rejected();
  });
  test('hop signature tamper is rejected', () async {
    final good = await input();
    await inject(
      good,
      json: {
        ...good.toJson(),
        'hops': [
          {
            ...good.hops.first,
            'signature': base64UrlEncode(List.filled(64, 0)),
          },
        ],
      },
    );
    await rejected();
  });
  test('wrong session binding is rejected', () async {
    final good = await input();
    await inject(
      good,
      json: {...good.toJson(), 'sessionBinding': 'retired-session'},
    );
    await rejected();
  });
  test('hop-limit extension cannot bypass the fixed protocol bound', () async {
    final good = await input();
    await inject(good, json: {...good.toJson(), 'maxHops': 1000});
    await rejected();
  });
  test('signed path cannot be truncated or routed into a loop', () async {
    final good = await input();
    await expectLater(
      good.forNextHop(
        identity: await s.b.identity(),
        nextHopKeyId: (await s.a.identity()).keyId,
        binding: 'binding',
      ),
      throwsFormatException,
    );
    await inject(good, json: {...good.toJson(), 'hopCount': 1});
    await rejected();
  });
  test(
    'replay is idempotent at relay, destination and visible conversation',
    () async {
      final good = await input(id: 'once');
      await inject(good);
      await inject(good);
      expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), hasLength(1));
      expect(await s.c.chat.loadMessages('incident-1'), hasLength(1));
    },
  );
  test(
    'same ID with a different signed text cannot overwrite the first message',
    () async {
      final first = await input(id: 'collision');
      await inject(first);
      s.clock.advance(
        const Duration(seconds: 1),
      ); // Different signed creation time.
      final second = await input(id: 'collision');
      await inject(second);
      expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), hasLength(1));
      expect(await s.c.chat.loadMessages('incident-1'), hasLength(1));
      expect(
        s.b.logs.any((l) => l.contains('Conflicting incoming Chat replay')),
        isTrue,
      );
    },
  );
  test(
    'retired session proof cannot be reused on a new physical link',
    () async {
      final old = await input();
      s.network.disconnect('A', 'B');
      await s.network.pump();
      s.network.connect('A', 'B');
      await s.network.until(() => s.a.authenticated());
      await inject(old);
      await rejected();
    },
  );
  test(
    'owner-scoped outbox and offer lookup do not leak to another account',
    () async {
      await s.a.send('private-owner', 'scoped', s.c);
      await s.network.pump();
      expect(
        await ChatRelayRepository(
          s.a.db,
          ownerId: 'other',
        ).findOutbox('private-owner'),
        isNull,
      );
      final good = await input();
      await expectLater(
        ChatRelayAuthorization(
          s.a.db,
          ownerId: 'other',
        ).authorize(ChatRelayEnvelope.fromCanonicalWire(good.wireEnvelope)),
        throwsFormatException,
      );
    },
  );
  test('unauthenticated link cannot inject valid signed text', () async {
    final old = await input();
    s.network.disconnect('A', 'B');
    await s.network.pump();
    s.network.dropTypes.add(RelaySessionResponse.wireKind);
    s.network.connect('A', 'B');
    await s.network.pump(rounds: 600);
    expect(await s.a.authenticated(), isFalse);
    await inject(old);
    // An in-flight nonce proof may defer rejection, but never authorizes
    // persistence. Its bounded timeout must release the waiting payload.
    expect(await s.b.db.select(s.b.db.chatRelayInbox).get(), isEmpty);
    expect(await s.c.db.select(s.c.db.chatRelayInbox).get(), isEmpty);
    s.clock.advance(const Duration(minutes: 2));
    await s.network.pump(rounds: 600);
    expect(await s.a.authenticated(), isFalse);
    await rejected();
  });
  test('expired signed text is rejected at the receive boundary', () async {
    final old = await input();
    s.clock.advance(const Duration(minutes: 31));
    await inject(old);
    await rejected();
  });
}
