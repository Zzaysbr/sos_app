import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/chat_relay_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 2);
  late AppDatabase database;
  late ChatRelayRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ChatRelayRepository(database, ownerId: 'owner-a');
  });

  tearDown(() => database.close());

  test('outbox and inbox are owner-scoped and idempotent', () async {
    final envelope = await _envelope();
    final first = await repository.enqueue(envelope, now: now);
    final second = await repository.enqueue(envelope, now: now);
    expect(second.messageId, first.messageId);
    expect(await repository.persistIncoming(envelope, now: now), isTrue);
    expect(await repository.persistIncoming(envelope, now: now), isFalse);
    final other = ChatRelayRepository(database, ownerId: 'owner-b');
    expect(await other.findOutbox(envelope.body.messageId), isNull);
  });

  test(
    'due rows expire by envelope validation and retain queued state',
    () async {
      final envelope = await _envelope();
      await repository.enqueue(envelope, now: now);
      final rows = await repository.due(now: now);
      expect(rows, hasLength(1));
      expect(rows.single.state, ChatRelayDeliveryState.queued.name);
      expect(rows.single.hopCount, 0);

      expect(await repository.due(now: envelope.body.expiresAt), isEmpty);
      expect(
        (await repository.findOutbox(envelope.body.messageId))!.state,
        ChatRelayDeliveryState.expired.name,
      );
    },
  );

  test('malformed signed payload cannot be decoded as a relay message', () {
    expect(
      () => repository.decode('{"kind":"chat.relay.v1"}'),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<ChatRelayEnvelope> _envelope() async {
  final pair = await Ed25519().newKeyPair();
  final public = (await pair.extractPublicKey()).bytes;
  final crypto = RelayCryptography();
  final now = DateTime.utc(2026, 11, 4, 2);
  final body = ChatRelayBody(
    messageId: 'chat-relay-1',
    incidentId: 'incident-1',
    senderKeyId: await crypto.publicKeyId(public),
    senderPublicKey: base64UrlEncode(public),
    recipientKeyId: 'recipient-key',
    recipientPublicKey: base64UrlEncode(List<int>.filled(32, 2)),
    originIncidentBinding: 'incident-1',
    text: 'hello',
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 10)),
  );
  return ChatRelayEnvelope(
    body: body,
    signature: await crypto.signChatRelay(body, pair),
  );
}
