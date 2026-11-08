import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';

Future<RelayOfferEnvelope> _offer({
  String originMessageId = 'origin-message-1',
  String incidentId = 'incident-1',
  String message = 'Need help',
  int maxHops = 3,
  Duration lifetime = const Duration(minutes: 30),
  DateTime? createdAt,
}) async {
  final algorithm = Ed25519();
  final keyPair = await algorithm.newKeyPairFromSeed(
    List<int>.generate(32, (index) => index + 1),
  );
  final publicKey = (await keyPair.extractPublicKey()).bytes;
  final crypto = RelayCryptography();
  final originCreatedAt = createdAt ?? DateTime.utc(2026, 10, 25, 12);
  final body = RelayOriginBody(
    originMessageId: originMessageId,
    incidentId: incidentId,
    originKeyId: await crypto.publicKeyId(publicKey),
    originPublicKey: base64UrlEncode(publicKey),
    emergencyType: 'emergency',
    emergencyMessage: message,
    includeLocation: false,
    createdAt: originCreatedAt,
    expiresAt: originCreatedAt.add(lifetime),
    maxHops: maxHops,
  );
  return RelayOfferEnvelope(
    body: body,
    originSignature: await crypto.signOriginBody(body, keyPair),
    hopCount: 0,
    pathKeyIds: [body.originKeyId],
    immediateSenderKeyId: body.originKeyId,
  );
}

Future<String> _keyId(int offset) async {
  final pair = await Ed25519().newKeyPairFromSeed(
    List<int>.generate(32, (index) => index + offset),
  );
  return RelayCryptography().publicKeyId((await pair.extractPublicKey()).bytes);
}

Future<RelayOfferEnvelope> _forwardedOffer(
  RelayOfferEnvelope origin,
  int hopCount,
) async {
  final crypto = RelayCryptography();
  final digest = await crypto.immutableDigest(origin.body);
  final path = <String>[origin.body.originKeyId];
  final attestations = <RelayHopAttestation>[];
  for (var hop = 1; hop <= hopCount; hop++) {
    final pair = await Ed25519().newKeyPairFromSeed(
      List<int>.generate(32, (index) => index + (hop * 40)),
    );
    final publicKey = (await pair.extractPublicKey()).bytes;
    final keyId = await crypto.publicKeyId(publicKey);
    path.add(keyId);
    final unsigned = RelayHopAttestation(
      originMessageId: origin.body.originMessageId,
      immutableDigest: digest,
      relayKeyId: keyId,
      relayPublicKey: base64UrlEncode(publicKey),
      hopCount: hop,
      pathKeyIds: List.unmodifiable(path),
      signature: '',
    );
    attestations.add(
      RelayHopAttestation(
        originMessageId: unsigned.originMessageId,
        immutableDigest: unsigned.immutableDigest,
        relayKeyId: unsigned.relayKeyId,
        relayPublicKey: unsigned.relayPublicKey,
        hopCount: unsigned.hopCount,
        pathKeyIds: unsigned.pathKeyIds,
        signature: await crypto.signHopAttestation(unsigned, pair),
      ),
    );
  }
  return RelayOfferEnvelope(
    body: origin.body,
    originSignature: origin.originSignature,
    hopCount: hopCount,
    pathKeyIds: List.unmodifiable(path),
    immediateSenderKeyId: path.last,
    hopAttestations: List.unmodifiable(attestations),
  );
}

Future<RelayReceiptEnvelope> _receipt(
  RelayOfferEnvelope offer,
  RelayReceiptType type, {
  int seedOffset = 120,
  String? receiptId,
  String correlationId = 'correlation-1',
  String attemptId = 'attempt-1',
  String finalAuthorizationId = 'final-authorization-1',
}) async {
  final keyPair = await Ed25519().newKeyPairFromSeed(
    List<int>.generate(32, (index) => index + seedOffset),
  );
  final publicKey = (await keyPair.extractPublicKey()).bytes;
  final crypto = RelayCryptography();
  final unsigned = RelayReceiptEnvelope(
    receiptId: receiptId ?? '${type.name}-receipt-1',
    type: type,
    originMessageId: offer.body.originMessageId,
    incidentId: offer.body.incidentId,
    immutableDigest: await crypto.immutableDigest(offer.body),
    signerKeyId: await crypto.publicKeyId(publicKey),
    signerPublicKey: base64UrlEncode(publicKey),
    status: 'persisted',
    createdAt: DateTime.utc(2026, 10, 25, 12, 2),
    expiresAt: offer.body.expiresAt,
    signature: '',
    correlationId: correlationId,
    attemptId: type == RelayReceiptType.hop ? attemptId : null,
    finalAuthorizationId: type == RelayReceiptType.finalRecipient
        ? finalAuthorizationId
        : null,
  );
  return RelayReceiptEnvelope(
    receiptId: unsigned.receiptId,
    type: unsigned.type,
    originMessageId: unsigned.originMessageId,
    incidentId: unsigned.incidentId,
    immutableDigest: unsigned.immutableDigest,
    signerKeyId: unsigned.signerKeyId,
    signerPublicKey: unsigned.signerPublicKey,
    status: unsigned.status,
    createdAt: unsigned.createdAt,
    expiresAt: unsigned.expiresAt,
    signature: await crypto.signReceipt(unsigned, keyPair),
    correlationId: unsigned.correlationId,
    attemptId: unsigned.attemptId,
    finalAuthorizationId: unsigned.finalAuthorizationId,
  );
}

Future<BleRelayAttempt> _markAwaitingReceipt(
  RelayRepository repository,
  BleRelayAttempt attempt,
  DateTime sentAt,
) async {
  await repository.markAttemptSending(
    originMessageId: attempt.originMessageId,
    attemptId: attempt.attemptId,
    now: sentAt,
  );
  return repository.markAttemptAwaitingHopReceipt(
    originMessageId: attempt.originMessageId,
    attemptId: attempt.attemptId,
    now: sentAt,
  );
}

void main() {
  late AppDatabase database;
  late RelayRepository repository;
  final acceptedAt = DateTime.utc(2026, 10, 25, 12, 1);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelayRepository(database: database);
  });

  tearDown(() async => database.close());

  test('schema 10 creates dedicated relay and rescue tables', () async {
    expect(database.schemaVersion, 10);
    expect(await database.select(database.bleRelayMessages).get(), isEmpty);
    expect(await database.select(database.bleRelayAttempts).get(), isEmpty);
    expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
    expect(await database.select(database.rescueInbox).get(), isEmpty);
    expect(await database.select(database.rescueResponseOutbox).get(), isEmpty);
    expect(await database.select(database.rescueResponseInbox).get(), isEmpty);
    expect(await database.select(database.rescueResponseJobs).get(), isEmpty);
    expect(await database.select(database.rescueResponseReplay).get(), isEmpty);
  });

  test(
    'inactive-origin cleanup never removes hop-only jobs from other peers',
    () async {
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'active-incident',
              ownerId: 'guest:test',
              type: 'emergency',
              status: 'active',
              syncState: 'localOnly',
              createdAt: acceptedAt,
              updatedAt: acceptedAt,
            ),
          );
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'cancelled-incident',
              ownerId: 'guest:test',
              type: 'emergency',
              status: 'cancelled',
              syncState: 'localOnly',
              createdAt: acceptedAt,
              updatedAt: acceptedAt,
            ),
          );
      await repository.persistOriginOffer(
        await _offer(
          originMessageId: 'origin-active',
          incidentId: 'active-incident',
        ),
        now: acceptedAt,
      );
      expect(
        await repository.hasForwardableLocalOrigin(now: acceptedAt),
        isTrue,
      );
      await repository.persistOriginOffer(
        await _offer(
          originMessageId: 'origin-cancelled',
          incidentId: 'cancelled-incident',
        ),
        now: acceptedAt,
      );
      await repository.acceptIncomingOffer(
        await _offer(
          originMessageId: 'received-hop-only',
          incidentId: 'missing-local-incident',
        ),
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );

      expect(await repository.removeInactiveLocalOrigins(), 1);
      expect(
        (await database.select(database.bleRelayMessages).get()).map(
          (row) => row.originMessageId,
        ),
        containsAll(<String>['origin-active', 'received-hop-only']),
      );

      expect(
        await repository.removeLocalOriginForIncident('active-incident'),
        1,
      );
      expect(
        await repository.hasForwardableLocalOrigin(now: acceptedAt),
        isFalse,
      );
      expect(
        (await database.select(database.bleRelayMessages).getSingle())
            .originMessageId,
        'received-hop-only',
      );
    },
  );

  test('attempt IDs are fixed length and bind exact UTF-8 input', () async {
    final nextHop = await _keyId(210);
    final ascii = await RelayRepository.attemptIdFor('a' * 4096, nextHop);
    final utf8Boundary = await RelayRepository.attemptIdFor(
      '${'a' * 4095}ก',
      nextHop,
    );
    final repeated = await RelayRepository.attemptIdFor('a' * 4096, nextHop);
    final otherHop = await RelayRepository.attemptIdFor(
      'a' * 4096,
      await _keyId(220),
    );

    expect(ascii, startsWith('r2:'));
    expect(ascii.length, 47);
    expect(utf8Boundary.length, ascii.length);
    expect(repeated, ascii);
    expect(utf8Boundary, isNot(ascii));
    expect(otherHop, isNot(ascii));
    expect(ascii, isNot(contains('a' * 32)));
  });

  test(
    'migrates schema 5 to relay tables without changing existing SOS',
    () async {
      final executor = NativeDatabase.memory(
        setup: (db) {
          db.execute('''
          CREATE TABLE sos_messages (
            id TEXT NOT NULL PRIMARY KEY, owner_id TEXT NOT NULL,
            type TEXT NOT NULL, message TEXT, latitude REAL, longitude REAL,
            status TEXT NOT NULL, sync_state TEXT NOT NULL,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
          )
        ''');
          db.execute('''
          CREATE TABLE sos_sync_queue (
            queue_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            sos_id TEXT NOT NULL, owner_id TEXT NOT NULL,
            operation TEXT NOT NULL, payload TEXT, created_at INTEGER NOT NULL
          )
        ''');
          db.execute('''
          CREATE TABLE ble_outbox (
            message_id TEXT NOT NULL PRIMARY KEY, sos_id TEXT NOT NULL,
            destination_id TEXT, schema_version INTEGER NOT NULL,
            payload TEXT NOT NULL, state TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0, next_retry_at INTEGER,
            last_attempt_at INTEGER, last_error TEXT,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
            acknowledged_at INTEGER
          )
        ''');
          db.execute('''
          CREATE TABLE ble_inbox (
            message_id TEXT NOT NULL PRIMARY KEY, sos_id TEXT NOT NULL,
            sender_device_id TEXT, schema_version INTEGER NOT NULL,
            payload TEXT NOT NULL, processing_state TEXT NOT NULL,
            received_at INTEGER NOT NULL, persisted_at INTEGER,
            acknowledgement_status TEXT
          )
        ''');
          db.execute('''
          CREATE TABLE chat_messages (
            message_id TEXT NOT NULL PRIMARY KEY, sos_id TEXT NOT NULL,
            owner_id TEXT NOT NULL, sender_id TEXT NOT NULL,
            recipient_id TEXT, message_type TEXT NOT NULL, text_content TEXT,
            created_at INTEGER NOT NULL, delivery_status TEXT NOT NULL,
            attachment_path TEXT, attachment_mime_type TEXT,
            attachment_name TEXT, remote_message_id TEXT,
            transport_metadata TEXT
          )
        ''');
          db.execute(
            "INSERT INTO sos_messages "
            "(id, owner_id, type, status, sync_state, created_at, updated_at) "
            "VALUES ('existing-v5', 'owner', 'emergency', 'active', 'local', 0, 0)",
          );
          db.execute(
            "INSERT INTO sos_sync_queue "
            "(queue_id, sos_id, owner_id, operation, payload, created_at) "
            "VALUES (7, 'existing-v5', 'owner', 'create', '{}', 0)",
          );
          db.execute(
            "INSERT INTO ble_outbox "
            "(message_id, sos_id, destination_id, schema_version, payload, state, retry_count, created_at, updated_at) "
            "VALUES ('outbox-v5', 'existing-v5', 'peer-b', 1, '{}', 'queued', 2, 0, 0)",
          );
          db.execute(
            "INSERT INTO ble_inbox "
            "(message_id, sos_id, sender_device_id, schema_version, payload, processing_state, received_at) "
            "VALUES ('inbox-v5', 'existing-v5', 'peer-a', 1, '{}', 'persisted', 0)",
          );
          db.execute(
            "INSERT INTO chat_messages "
            "(message_id, sos_id, owner_id, sender_id, recipient_id, message_type, text_content, created_at, delivery_status) "
            "VALUES ('chat-v5', 'existing-v5', 'owner', 'peer-a', 'peer-b', 'text', 'preserve me', 0, 'queued')",
          );
          db.execute('PRAGMA user_version = 5');
        },
      );
      final migrated = AppDatabase.forTesting(executor);
      expect(migrated.schemaVersion, 10);
      expect(
        (await migrated.select(migrated.sosMessages).getSingle()).id,
        'existing-v5',
      );
      expect(
        (await migrated.select(migrated.sosSyncQueue).getSingle()).queueId,
        7,
      );
      expect(
        (await migrated.select(migrated.bleOutbox).getSingle()).retryCount,
        2,
      );
      expect(
        (await migrated.select(migrated.bleInbox).getSingle()).senderDeviceId,
        'peer-a',
      );
      expect(
        (await migrated.select(migrated.chatMessages).getSingle()).textContent,
        'preserve me',
      );
      expect(await migrated.select(migrated.bleRelayMessages).get(), isEmpty);
      expect(await migrated.select(migrated.bleRelayAttempts).get(), isEmpty);
      expect(await migrated.select(migrated.bleRelayReceipts).get(), isEmpty);
      await migrated.close();
    },
  );

  test(
    'relay disabled fails before persistence and leaves direct tables alone',
    () async {
      await expectLater(
        repository.acceptIncomingOffer(
          await _offer(),
          sourceDeviceId: 'native-peer-a',
          relayEnabled: false,
          now: acceptedAt,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      expect(await database.select(database.bleRelayMessages).get(), isEmpty);
      expect(await database.select(database.sosMessages).get(), isEmpty);
      expect(await database.select(database.sosSyncQueue).get(), isEmpty);
      expect(await database.select(database.bleOutbox).get(), isEmpty);
    },
  );

  test(
    'valid offer is relay-only, durable, and duplicate-idempotent',
    () async {
      final offer = await _offer();
      final first = await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'native-peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final duplicate = await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'native-peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      expect(first.duplicate, isFalse);
      expect(duplicate.duplicate, isTrue);
      expect(first.row.originMessageId, offer.body.originMessageId);
      expect(first.row.incidentId, offer.body.incidentId);
      expect(
        await database.select(database.bleRelayMessages).get(),
        hasLength(1),
      );
      expect(await database.select(database.sosMessages).get(), isEmpty);
      expect(await database.select(database.sosSyncQueue).get(), isEmpty);
      expect(await database.select(database.bleOutbox).get(), isEmpty);
    },
  );

  for (final forwardedFirst in [false, true]) {
    test(
      'verified alternate SOS route is duplicate; forwardedFirst=$forwardedFirst',
      () async {
        final origin = await _offer();
        final forwarded = await _forwardedOffer(origin, 1);
        final first = await repository.acceptIncomingOffer(
          forwardedFirst ? forwarded : origin,
          sourceDeviceId: forwardedFirst ? 'peer-b' : 'peer-a',
          relayEnabled: true,
          now: acceptedAt,
        );
        final duplicate = await repository.acceptIncomingOffer(
          forwardedFirst ? origin : forwarded,
          sourceDeviceId: forwardedFirst ? 'peer-a' : 'peer-b',
          relayEnabled: true,
          now: acceptedAt.add(const Duration(seconds: 1)),
        );
        expect(duplicate.duplicate, isTrue);
        expect(duplicate.row.wireEnvelope, first.row.wireEnvelope);
        expect(duplicate.row.incomingPeerId, first.row.incomingPeerId);
        expect(duplicate.row.incomingPath, first.row.incomingPath);
        expect(duplicate.row.persistedAt, first.row.persistedAt);
        expect(duplicate.row.retentionDeadline, first.row.retentionDeadline);
        expect(duplicate.row.storageBytes, first.row.storageBytes);
        expect(
          await database.select(database.bleRelayMessages).get(),
          hasLength(1),
        );
        final verified = await repository.loadVerifiedOffer(
          origin.body.originMessageId,
          now: acceptedAt,
        );
        expect(verified.toCanonicalWire(), first.row.wireEnvelope);
        // A genuinely different signed body is still a conflicting replay,
        // even when it arrives with a valid new hop attestation.
        final changed = await _forwardedOffer(
          await _offer(message: 'Changed'),
          1,
        );
        await expectLater(
          repository.acceptIncomingOffer(
            changed,
            sourceDeviceId: 'peer-other',
            relayEnabled: true,
            now: acceptedAt,
          ),
          throwsA(isA<RelayPersistenceException>()),
        );
        final forged = RelayOfferEnvelope(
          body: forwarded.body,
          originSignature: forwarded.originSignature,
          hopCount: forwarded.hopCount,
          pathKeyIds: forwarded.pathKeyIds,
          immediateSenderKeyId: forwarded.immediateSenderKeyId,
          // A claimed alternate path without signed hops must not be re-ACKed.
        );
        await expectLater(
          repository.acceptIncomingOffer(
            forged,
            sourceDeviceId: 'peer-b',
            relayEnabled: true,
            now: acceptedAt,
          ),
          throwsA(isA<RelayProtocolException>()),
        );
      },
    );
  }

  test('relay-only queue survives a database process restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'relay-v2-restart-',
    );
    final file = File('${directory.path}/relay.sqlite');
    final offer = await _offer();
    try {
      final first = AppDatabase.forTesting(NativeDatabase(file));
      await RelayRepository(database: first).acceptIncomingOffer(
        offer,
        sourceDeviceId: 'native-peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      await first.close();

      final second = AppDatabase.forTesting(NativeDatabase(file));
      final recovered = await RelayRepository(database: second)
          .lookupMessage(offer.body.originMessageId);
      expect(recovered, isNotNull);
      expect(recovered!.incidentId, offer.body.incidentId);
      expect(recovered.processingState, RelayMessageState.queued.wireValue);
      expect(await second.select(second.sosMessages).get(), isEmpty);
      await second.close();
    } finally {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });

  test(
    'runtime subsecond timestamps remain forwardable after database round-trip',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'relay-v2-subsecond-',
      );
      final file = File('${directory.path}/relay.sqlite');
      final offer = await _offer();
      final runtimeNow = DateTime.utc(2026, 10, 25, 12, 0, 0, 123, 456);
      try {
        final first = AppDatabase.forTesting(NativeDatabase(file));
        await RelayRepository(database: first).acceptIncomingOffer(
          offer,
          sourceDeviceId: 'native-peer-a',
          relayEnabled: true,
          now: runtimeNow,
        );
        await first.close();

        final second = AppDatabase.forTesting(NativeDatabase(file));
        final recovered = await RelayRepository(database: second)
            .listForwardableMessages(
              now: runtimeNow.add(const Duration(seconds: 1)),
            );
        expect(recovered, hasLength(1));
        expect(recovered.single.originMessageId, offer.body.originMessageId);
        await second.close();
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  test('known pre-fix subsecond accounting is narrowly repaired after verification', () async {
    final offer = await _offer();
    final accepted = await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'native-peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    await (database.update(database.bleRelayMessages)..where(
          (table) => table.originMessageId.equals(accepted.row.originMessageId),
        ))
        .write(
          BleRelayMessagesCompanion(
            storageBytes: Value(accepted.row.storageBytes + 6),
          ),
        );

    final recovered = await repository.listForwardableMessages(
      now: acceptedAt.add(const Duration(seconds: 1)),
    );
    expect(recovered, hasLength(1));
    final repaired = await repository.lookupMessage(
      accepted.row.originMessageId,
    );
    expect(repaired!.storageBytes, accepted.row.storageBytes);
  });

  test('conflicting payload and forged signature are rejected', () async {
    final original = await _offer();
    await repository.acceptIncomingOffer(
      original,
      sourceDeviceId: 'native-peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final conflicting = await _offer(message: 'Different');
    await expectLater(
      repository.acceptIncomingOffer(
        conflicting,
        sourceDeviceId: 'native-peer-a',
        relayEnabled: true,
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    final forged = RelayOfferEnvelope(
      body: original.body,
      originSignature: base64UrlEncode(List<int>.filled(64, 7)),
      hopCount: original.hopCount,
      pathKeyIds: original.pathKeyIds,
      immediateSenderKeyId: original.immediateSenderKeyId,
    );
    await expectLater(
      repository.acceptIncomingOffer(
        forged,
        sourceDeviceId: 'native-peer-a',
        relayEnabled: true,
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    expect(
      await database.select(database.bleRelayMessages).get(),
      hasLength(1),
    );
  });

  test('job count and payload storage quotas fail closed', () async {
    final limited = RelayRepository(
      database: database,
      maximumJobs: 1,
      maximumPayloadBytes: 4096,
    );
    await limited.acceptIncomingOffer(
      await _offer(),
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    await expectLater(
      limited.acceptIncomingOffer(
        await _offer(
          originMessageId: 'origin-message-2',
          incidentId: 'incident-2',
        ),
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
  });

  test('expired relay data is removed and never becomes SOS history', () async {
    await repository.acceptIncomingOffer(
      await _offer(lifetime: const Duration(minutes: 1)),
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt.subtract(const Duration(seconds: 30)),
    );
    expect(
      await repository.cleanupExpired(now: DateTime.utc(2026, 10, 25, 12, 2)),
      1,
    );
    expect(await database.select(database.bleRelayMessages).get(), isEmpty);
    expect(await database.select(database.sosMessages).get(), isEmpty);
  });

  test(
    'expired relay data with stale accounting is deleted fail-closed',
    () async {
      final accepted = await repository.acceptIncomingOffer(
        await _offer(lifetime: const Duration(minutes: 1)),
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt.subtract(const Duration(seconds: 30)),
      );
      await (database.update(database.bleRelayMessages)..where(
            (table) =>
                table.originMessageId.equals(accepted.row.originMessageId),
          ))
          .write(const BleRelayMessagesCompanion(storageBytes: Value(1)));

      expect(
        await repository.cleanupExpired(now: DateTime.utc(2026, 10, 25, 12, 2)),
        1,
      );
      expect(await database.select(database.bleRelayMessages).get(), isEmpty);
      expect(await database.select(database.sosMessages).get(), isEmpty);
    },
  );

  test(
    'unexpired relay data with stale accounting still fails closed',
    () async {
      final accepted = await repository.acceptIncomingOffer(
        await _offer(),
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      await (database.update(database.bleRelayMessages)..where(
            (table) =>
                table.originMessageId.equals(accepted.row.originMessageId),
          ))
          .write(const BleRelayMessagesCompanion(storageBytes: Value(1)));

      await expectLater(
        repository.cleanupExpired(now: acceptedAt),
        throwsA(isA<RelayPersistenceException>()),
      );
      expect(
        await database.select(database.bleRelayMessages).get(),
        hasLength(1),
      );
    },
  );

  test('per-next-hop attempt excludes path/source and is idempotent', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final relayKey = await _keyId(50);
    final candidateKey = await _keyId(90);
    final attempt = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: candidateKey,
      nextHopDeviceId: 'native-peer-c',
      localRelayKeyId: relayKey,
      correlationId: 'correlation-1',
      now: acceptedAt,
    );
    final duplicate = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: candidateKey,
      nextHopDeviceId: 'native-peer-c',
      localRelayKeyId: relayKey,
      correlationId: 'correlation-1',
      now: acceptedAt,
    );
    expect(duplicate.attemptId, attempt.attemptId);
    expect(attempt.outgoingHopCount, 1);
    expect(
      await database.select(database.bleRelayAttempts).get(),
      hasLength(1),
    );
    await expectLater(
      repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: offer.body.originKeyId,
        nextHopDeviceId: 'peer-a',
        localRelayKeyId: relayKey,
        correlationId: 'correlation-1',
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
  });

  test(
    'failed attempt rebinds a rotated native address without changing identity',
    () async {
      final offer = await _offer();
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final relayKey = await _keyId(50);
      final candidateKey = await _keyId(90);
      final attempt = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: candidateKey,
        nextHopDeviceId: 'private-address-old',
        localRelayKeyId: relayKey,
        correlationId: 'stable-correlation',
        now: acceptedAt,
      );
      final claimed = await repository.claimAttemptForSending(
        originMessageId: offer.body.originMessageId,
        attemptId: attempt.attemptId,
        now: acceptedAt,
      );
      expect(claimed, isNotNull);
      await repository.markAttemptFailed(
        originMessageId: offer.body.originMessageId,
        attemptId: attempt.attemptId,
        error: 'address rotated',
        retryDelay: Duration.zero,
        now: acceptedAt,
      );

      final rebound = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: candidateKey,
        nextHopDeviceId: 'private-address-new',
        localRelayKeyId: relayKey,
        correlationId: 'stable-correlation',
        now: acceptedAt.add(const Duration(seconds: 1)),
      );

      expect(rebound.attemptId, attempt.attemptId);
      expect(rebound.nextHopKeyId, candidateKey);
      expect(rebound.correlationId, attempt.correlationId);
      expect(rebound.retryCount, 1);
      expect(rebound.nextHopDeviceId, 'private-address-new');
      expect(
        await repository.claimAttemptForSending(
          originMessageId: offer.body.originMessageId,
          attemptId: attempt.attemptId,
          now: acceptedAt.add(const Duration(seconds: 1)),
        ),
        isNotNull,
      );
    },
  );

  test(
    'in-flight attempt cannot rebind its native transport address',
    () async {
      final offer = await _offer();
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final relayKey = await _keyId(50);
      final candidateKey = await _keyId(90);
      final attempt = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: candidateKey,
        nextHopDeviceId: 'private-address-old',
        localRelayKeyId: relayKey,
        correlationId: 'stable-correlation',
        now: acceptedAt,
      );
      await repository.claimAttemptForSending(
        originMessageId: offer.body.originMessageId,
        attemptId: attempt.attemptId,
        now: acceptedAt,
      );

      final unchanged = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: candidateKey,
        nextHopDeviceId: 'private-address-new',
        localRelayKeyId: relayKey,
        correlationId: 'stable-correlation',
        now: acceptedAt.add(const Duration(seconds: 1)),
      );

      expect(unchanged.state, RelayAttemptState.sending.wireValue);
      expect(unchanged.nextHopDeviceId, 'private-address-old');
    },
  );

  test(
    'runtime subsecond attempt transitions retain valid quota accounting',
    () async {
      final offer = await _offer();
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final relayKey = await _keyId(50);
      final candidateKey = await _keyId(90);
      final runtimeNow = DateTime.utc(2026, 10, 25, 12, 1, 0, 123, 456);
      final attempt = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: candidateKey,
        nextHopDeviceId: 'native-peer-c',
        localRelayKeyId: relayKey,
        correlationId: 'runtime-correlation',
        now: runtimeNow,
      );
      expect(
        await repository.claimAttemptForSending(
          originMessageId: offer.body.originMessageId,
          attemptId: attempt.attemptId,
          now: runtimeNow.add(const Duration(milliseconds: 100)),
        ),
        isNotNull,
      );
      await repository.markAttemptAwaitingHopReceipt(
        originMessageId: offer.body.originMessageId,
        attemptId: attempt.attemptId,
        now: runtimeNow.add(const Duration(milliseconds: 200)),
      );

      await repository.acceptIncomingOffer(
        await _offer(
          originMessageId: 'origin-message-runtime-2',
          incidentId: 'incident-runtime-2',
        ),
        sourceDeviceId: 'peer-b',
        relayEnabled: true,
        now: runtimeNow.add(const Duration(seconds: 1)),
      );
      expect(
        await database.select(database.bleRelayMessages).get(),
        hasLength(2),
      );
    },
  );

  test('inclusive hop limit prevents forwarding beyond the boundary', () async {
    final offer = await _forwardedOffer(await _offer(maxHops: 1), 1);
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    await expectLater(
      repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: await _keyId(90),
        nextHopDeviceId: 'peer-c',
        localRelayKeyId: await _keyId(50),
        correlationId: 'correlation-1',
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
  });

  test('hop receipt persists only after the legal send lifecycle', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final hopReceipt = await _receipt(offer, RelayReceiptType.hop);
    final attempt = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: hopReceipt.signerKeyId,
      nextHopDeviceId: 'peer-c',
      localRelayKeyId: await _keyId(50),
      correlationId: hopReceipt.correlationId,
      now: acceptedAt,
    );
    final reboundHop = await _receipt(
      offer,
      RelayReceiptType.hop,
      correlationId: attempt.correlationId,
      attemptId: attempt.attemptId,
    );
    await _markAwaitingReceipt(repository, attempt, acceptedAt);
    final hop = await repository.persistReceipt(
      reboundHop,
      sourcePeerDeviceId: 'peer-c',
      now: DateTime.utc(2026, 10, 25, 12, 3),
    );
    expect(hop.receiptType, RelayReceiptType.hop.wireValue);
    expect(
      await database.select(database.bleRelayReceipts).get(),
      hasLength(1),
    );
    expect(await database.select(database.bleOutbox).get(), isEmpty);
  });

  test('forged receipt is rejected without receipt state', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final valid = await _receipt(offer, RelayReceiptType.hop);
    final forged = RelayReceiptEnvelope(
      receiptId: valid.receiptId,
      type: valid.type,
      originMessageId: valid.originMessageId,
      incidentId: valid.incidentId,
      immutableDigest: valid.immutableDigest,
      signerKeyId: valid.signerKeyId,
      signerPublicKey: valid.signerPublicKey,
      status: valid.status,
      createdAt: valid.createdAt,
      expiresAt: valid.expiresAt,
      signature: base64UrlEncode(List<int>.filled(64, 9)),
      correlationId: valid.correlationId,
      attemptId: valid.attemptId,
    );
    await expectLater(
      repository.persistReceipt(
        forged,
        sourcePeerDeviceId: 'peer-c',
        now: DateTime.utc(2026, 10, 25, 12, 3),
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
  });

  test(
    'full attestation chain survives restart and tampering fails closed',
    () async {
      final forwarded = await _forwardedOffer(await _offer(), 2);
      await repository.acceptIncomingOffer(
        forwarded,
        sourceDeviceId: 'peer-b',
        relayEnabled: true,
        now: acceptedAt,
      );
      final reconstructed = await repository.loadVerifiedOffer(
        forwarded.body.originMessageId,
        now: acceptedAt,
      );
      expect(reconstructed.toCanonicalWire(), forwarded.toCanonicalWire());
      expect(reconstructed.hopAttestations, hasLength(2));

      final row = await repository.lookupMessage(
        forwarded.body.originMessageId,
      );
      await (database.update(database.bleRelayMessages)..where(
            (table) =>
                table.originMessageId.equals(forwarded.body.originMessageId),
          ))
          .write(
            BleRelayMessagesCompanion(
              wireEnvelope: Value('${row!.wireEnvelope} '),
            ),
          );
      await expectLater(
        repository.loadVerifiedOffer(
          forwarded.body.originMessageId,
          now: acceptedAt,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
    },
  );

  final messageTamperCases =
      <
        ({
          String name,
          BleRelayMessagesCompanion Function(BleRelayMessage row) change,
        })
      >[
        (
          name: 'origin public key',
          change: (_) => BleRelayMessagesCompanion(
            originPublicKey: Value(base64UrlEncode(List<int>.filled(32, 9))),
          ),
        ),
        (
          name: 'immutable payload',
          change: (_) =>
              const BleRelayMessagesCompanion(immutablePayload: Value('{}')),
        ),
        (
          name: 'authorization scope',
          change: (_) => const BleRelayMessagesCompanion(
            authorizationScope: Value('private'),
          ),
        ),
        (
          name: 'emergency type',
          change: (_) =>
              const BleRelayMessagesCompanion(emergencyType: Value('tampered')),
        ),
        (
          name: 'creation timestamp',
          change: (row) => BleRelayMessagesCompanion(
            createdAt: Value(row.createdAt.add(const Duration(seconds: 1))),
          ),
        ),
        (
          name: 'expiry timestamp',
          change: (row) => BleRelayMessagesCompanion(
            expiresAt: Value(row.expiresAt.add(const Duration(seconds: 1))),
          ),
        ),
        (
          name: 'receiver deadline',
          change: (row) => BleRelayMessagesCompanion(
            retentionDeadline: Value(
              row.retentionDeadline.add(const Duration(seconds: 1)),
            ),
          ),
        ),
        (
          name: 'maximum hops',
          change: (row) =>
              BleRelayMessagesCompanion(maxHops: Value(row.maxHops - 1)),
        ),
        (
          name: 'incoming path',
          change: (_) => const BleRelayMessagesCompanion(
            incomingPath: Value('{"path":[]}'),
          ),
        ),
        (
          name: 'wire byte count',
          change: (row) => BleRelayMessagesCompanion(
            payloadBytes: Value(row.payloadBytes + 1),
          ),
        ),
        (
          name: 'logical storage byte count',
          change: (row) => BleRelayMessagesCompanion(
            storageBytes: Value(row.storageBytes + 1),
          ),
        ),
        (
          name: 'untrusted final authorization metadata',
          change: (_) => const BleRelayMessagesCompanion(
            finalAuthorizationId: Value('caller-supplied'),
          ),
        ),
      ];

  for (final tamperCase in messageTamperCases) {
    test(
      'tampered ${tamperCase.name} fails stored offer verification',
      () async {
        final offer = await _offer();
        await repository.acceptIncomingOffer(
          offer,
          sourceDeviceId: 'peer-a',
          relayEnabled: true,
          now: acceptedAt,
        );
        final row = (await repository.lookupMessage(
          offer.body.originMessageId,
        ))!;
        await (database.update(database.bleRelayMessages)..where(
              (table) =>
                  table.originMessageId.equals(offer.body.originMessageId),
            ))
            .write(tamperCase.change(row));

        await expectLater(
          repository.loadVerifiedOffer(
            offer.body.originMessageId,
            now: acceptedAt,
          ),
          throwsA(isA<RelayPersistenceException>()),
        );
      },
    );
  }

  test(
    'queued receipt is rejected but an exact in-flight receipt is accepted',
    () async {
      final offer = await _offer();
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final receipt = await _receipt(offer, RelayReceiptType.hop);
      final attempt = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: receipt.signerKeyId,
        nextHopDeviceId: 'peer-c',
        localRelayKeyId: await _keyId(50),
        correlationId: receipt.correlationId,
        now: acceptedAt,
      );
      final bound = await _receipt(
        offer,
        RelayReceiptType.hop,
        attemptId: attempt.attemptId,
        correlationId: attempt.correlationId,
      );
      await expectLater(
        repository.persistReceipt(
          bound,
          sourcePeerDeviceId: 'peer-c',
          now: DateTime.utc(2026, 10, 25, 12, 3),
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      await repository.markAttemptSending(
        originMessageId: attempt.originMessageId,
        attemptId: attempt.attemptId,
        now: acceptedAt,
      );
      final persisted = await repository.persistReceipt(
        bound,
        sourcePeerDeviceId: 'peer-c',
        now: DateTime.utc(2026, 10, 25, 12, 3),
      );
      expect(persisted.attemptId, attempt.attemptId);
      expect(
        (await database.select(database.bleRelayAttempts).get()).single.state,
        RelayAttemptState.acceptedByRelay.wireValue,
      );
      expect(
        await database.select(database.bleRelayReceipts).get(),
        hasLength(1),
      );
    },
  );

  test('receipt timestamp before the send attempt is rejected', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final receipt = await _receipt(offer, RelayReceiptType.hop);
    final attempt = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: receipt.signerKeyId,
      nextHopDeviceId: 'peer-c',
      localRelayKeyId: await _keyId(50),
      correlationId: receipt.correlationId,
      now: acceptedAt,
    );
    final bound = await _receipt(
      offer,
      RelayReceiptType.hop,
      attemptId: attempt.attemptId,
      correlationId: attempt.correlationId,
    );
    final sentAfterReceipt = bound.createdAt
        .add(RelayProtocolLimits.maximumClockSkew)
        .add(const Duration(seconds: 1));
    await _markAwaitingReceipt(repository, attempt, sentAfterReceipt);

    await expectLater(
      repository.persistReceipt(
        bound,
        sourcePeerDeviceId: 'peer-c',
        now: sentAfterReceipt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
  });

  test('attempt transitions are atomic and reject competing sends', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final attempt = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: await _keyId(90),
      nextHopDeviceId: 'peer-c',
      localRelayKeyId: await _keyId(50),
      correlationId: 'correlation-transition',
      now: acceptedAt,
    );
    final results = await Future.wait(
      List.generate(2, (_) async {
        try {
          await repository.markAttemptSending(
            originMessageId: attempt.originMessageId,
            attemptId: attempt.attemptId,
            now: acceptedAt,
          );
          return true;
        } on RelayPersistenceException {
          return false;
        }
      }),
    );
    expect(results.where((result) => result), hasLength(1));
    expect(
      (await database.select(database.bleRelayAttempts).getSingle()).state,
      RelayAttemptState.sending.wireValue,
    );
  });

  test('local receipt time and peer/attempt binding fail closed', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final receipt = await _receipt(offer, RelayReceiptType.hop);
    final attempt = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: receipt.signerKeyId,
      nextHopDeviceId: 'peer-c',
      localRelayKeyId: await _keyId(50),
      correlationId: receipt.correlationId,
      now: acceptedAt,
    );
    final bound = await _receipt(
      offer,
      RelayReceiptType.hop,
      attemptId: attempt.attemptId,
      correlationId: attempt.correlationId,
    );
    await _markAwaitingReceipt(repository, attempt, acceptedAt);
    await expectLater(
      repository.persistReceipt(
        bound,
        sourcePeerDeviceId: 'wrong-peer',
        now: DateTime.utc(2026, 10, 25, 12, 3),
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
  });

  test(
    'self-signed final receipt fails closed without a trust anchor',
    () async {
      final offer = await _offer();
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final receipt = await _receipt(
        offer,
        RelayReceiptType.finalRecipient,
        seedOffset: 160,
      );
      await expectLater(
        repository.persistReceipt(
          receipt,
          sourcePeerDeviceId: 'peer-final',
          now: DateTime.utc(2026, 10, 25, 12, 3),
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
    },
  );

  test(
    'semantic replay and immutable attempt conflicts are rejected',
    () async {
      final offer = await _offer();
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final firstReceipt = await _receipt(offer, RelayReceiptType.hop);
      final attempt = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: firstReceipt.signerKeyId,
        nextHopDeviceId: 'peer-c',
        localRelayKeyId: await _keyId(50),
        correlationId: firstReceipt.correlationId,
        now: acceptedAt,
      );
      await expectLater(
        repository.createNextHopAttempt(
          originMessageId: offer.body.originMessageId,
          nextHopKeyId: firstReceipt.signerKeyId,
          nextHopDeviceId: 'peer-c',
          localRelayKeyId: await _keyId(50),
          correlationId: 'different-correlation',
          now: acceptedAt,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      final accepted = await _receipt(
        offer,
        RelayReceiptType.hop,
        attemptId: attempt.attemptId,
        correlationId: attempt.correlationId,
      );
      await _markAwaitingReceipt(repository, attempt, acceptedAt);
      final firstPersisted = await repository.persistReceipt(
        accepted,
        sourcePeerDeviceId: 'peer-c',
        now: DateTime.utc(2026, 10, 25, 12, 3),
      );
      final exactReplay = await repository.persistReceipt(
        accepted,
        sourcePeerDeviceId: 'peer-c',
        now: DateTime.utc(2026, 10, 25, 12, 3),
      );
      expect(exactReplay.semanticKey, firstPersisted.semanticKey);
      final replay = await _receipt(
        offer,
        RelayReceiptType.hop,
        receiptId: 'different-receipt-id',
        attemptId: attempt.attemptId,
        correlationId: attempt.correlationId,
      );
      await expectLater(
        repository.persistReceipt(
          replay,
          sourcePeerDeviceId: 'peer-c',
          now: DateTime.utc(2026, 10, 25, 12, 3),
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
      expect(
        await database.select(database.bleRelayReceipts).get(),
        hasLength(1),
      );
    },
  );

  test(
    'foreign-key cascade removes attempts and receipts atomically',
    () async {
      final offer = await _offer(lifetime: const Duration(minutes: 3));
      await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt.subtract(const Duration(seconds: 30)),
      );
      final receipt = await _receipt(offer, RelayReceiptType.hop);
      final attempt = await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: receipt.signerKeyId,
        nextHopDeviceId: 'peer-c',
        localRelayKeyId: await _keyId(50),
        correlationId: receipt.correlationId,
        now: acceptedAt,
      );
      final bound = await _receipt(
        offer,
        RelayReceiptType.hop,
        attemptId: attempt.attemptId,
        correlationId: attempt.correlationId,
      );
      await _markAwaitingReceipt(repository, attempt, acceptedAt);
      await repository.persistReceipt(
        bound,
        sourcePeerDeviceId: 'peer-c',
        now: acceptedAt,
      );
      expect(
        await repository.cleanupExpired(now: DateTime.utc(2026, 10, 25, 12, 3)),
        1,
      );
      expect(await database.select(database.bleRelayAttempts).get(), isEmpty);
      expect(await database.select(database.bleRelayReceipts).get(), isEmpty);
    },
  );

  test(
    'concurrent accept preserves job quota without duplicate rows',
    () async {
      final limited = RelayRepository(
        database: database,
        maximumJobs: 1,
        maximumPayloadBytes: 1024 * 1024,
      );
      final results = await Future.wait(
        [
          _offer(originMessageId: 'concurrent-1', incidentId: 'incident-c1'),
          _offer(originMessageId: 'concurrent-2', incidentId: 'incident-c2'),
        ].map((future) async {
          final offer = await future;
          try {
            await limited.acceptIncomingOffer(
              offer,
              sourceDeviceId: 'peer-a',
              relayEnabled: true,
              now: acceptedAt,
            );
            return true;
          } on RelayPersistenceException {
            return false;
          }
        }),
      );
      expect(results.where((accepted) => accepted), hasLength(1));
      expect(
        await database.select(database.bleRelayMessages).get(),
        hasLength(1),
      );
    },
  );

  test(
    'receiver retention deadline cannot be extended by clock skew',
    () async {
      final offer = await _offer(
        createdAt: acceptedAt.add(const Duration(minutes: 2)),
      );
      final accepted = await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      expect(
        accepted.row.retentionDeadline.toUtc(),
        acceptedAt.add(RelayProtocolLimits.maximumLifetime),
      );
      expect(
        await repository.cleanupExpired(
          now: acceptedAt.add(RelayProtocolLimits.maximumLifetime),
        ),
        1,
      );
    },
  );

  test('per-message attempt quota is enforced transactionally', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final relayKey = await _keyId(50);
    for (
      var index = 0;
      index < RelayProtocolLimits.maximumAttemptsPerMessage;
      index++
    ) {
      await repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: await _keyId(100 + index),
        nextHopDeviceId: 'peer-$index',
        localRelayKeyId: relayKey,
        correlationId: 'correlation-$index',
        now: acceptedAt,
      );
    }
    await expectLater(
      repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: await _keyId(200),
        nextHopDeviceId: 'peer-overflow',
        localRelayKeyId: relayKey,
        correlationId: 'correlation-overflow',
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    expect(
      await database.select(database.bleRelayAttempts).get(),
      hasLength(RelayProtocolLimits.maximumAttemptsPerMessage),
    );
  });

  test(
    'global logical byte quota includes complete attempt metadata',
    () async {
      final offer = await _offer();
      final accepted = await repository.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final constrained = RelayRepository(
        database: database,
        maximumPayloadBytes: accepted.row.storageBytes + 1,
      );
      await expectLater(
        constrained.createNextHopAttempt(
          originMessageId: offer.body.originMessageId,
          nextHopKeyId: await _keyId(90),
          nextHopDeviceId: 'peer-c',
          localRelayKeyId: await _keyId(50),
          correlationId: 'quota-correlation',
          now: acceptedAt,
        ),
        throwsA(isA<RelayPersistenceException>()),
      );
    },
  );

  test(
    'logical storage quota accepts exact boundary and rejects one byte over',
    () async {
      final offer = await _offer();
      final nextHopKeyId = await _keyId(90);
      final localRelayKeyId = await _keyId(50);

      final referenceDb = AppDatabase.forTesting(NativeDatabase.memory());
      final reference = RelayRepository(database: referenceDb);
      final message = await reference.acceptIncomingOffer(
        offer,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt,
      );
      final attempt = await reference.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: nextHopKeyId,
        nextHopDeviceId: 'peer-c',
        localRelayKeyId: localRelayKeyId,
        correlationId: 'quota-exact',
        now: acceptedAt,
      );
      final exactBudget = message.row.storageBytes + attempt.storageBytes;
      await referenceDb.close();

      Future<bool> canInsertAttempt(int budget) async {
        final isolated = AppDatabase.forTesting(NativeDatabase.memory());
        try {
          final constrained = RelayRepository(
            database: isolated,
            maximumPayloadBytes: budget,
          );
          await constrained.acceptIncomingOffer(
            offer,
            sourceDeviceId: 'peer-a',
            relayEnabled: true,
            now: acceptedAt,
          );
          await constrained.createNextHopAttempt(
            originMessageId: offer.body.originMessageId,
            nextHopKeyId: nextHopKeyId,
            nextHopDeviceId: 'peer-c',
            localRelayKeyId: localRelayKeyId,
            correlationId: 'quota-exact',
            now: acceptedAt,
          );
          return true;
        } on RelayPersistenceException {
          return false;
        } finally {
          await isolated.close();
        }
      }

      expect(await canInsertAttempt(exactBudget), isTrue);
      expect(await canInsertAttempt(exactBudget - 1), isFalse);
    },
  );

  test('tampered stored byte count cannot bypass later quota checks', () async {
    final offer = await _offer();
    await repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: 'peer-a',
      relayEnabled: true,
      now: acceptedAt,
    );
    final attempt = await repository.createNextHopAttempt(
      originMessageId: offer.body.originMessageId,
      nextHopKeyId: await _keyId(90),
      nextHopDeviceId: 'peer-c',
      localRelayKeyId: await _keyId(50),
      correlationId: 'quota-tamper',
      now: acceptedAt,
    );
    await (database.update(
      database.bleRelayAttempts,
    )..where((table) => table.attemptId.equals(attempt.attemptId))).write(
      BleRelayAttemptsCompanion(storageBytes: Value(attempt.storageBytes - 1)),
    );

    await expectLater(
      repository.createNextHopAttempt(
        originMessageId: offer.body.originMessageId,
        nextHopKeyId: await _keyId(91),
        nextHopDeviceId: 'peer-d',
        localRelayKeyId: await _keyId(50),
        correlationId: 'quota-after-tamper',
        now: acceptedAt,
      ),
      throwsA(isA<RelayPersistenceException>()),
    );
    expect(await database.select(database.sosMessages).get(), isEmpty);
  });

  test(
    'expired relay cleanup frees budget without touching non-relay data',
    () async {
      await database
          .into(database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: 'direct-sos',
              ownerId: 'guest-owner',
              type: 'emergency',
              status: 'active',
              syncState: 'local',
              createdAt: acceptedAt,
              updatedAt: acceptedAt,
            ),
          );
      final expiring = await _offer(
        originMessageId: 'relay-old-0001',
        incidentId: 'incident-old-0001',
        lifetime: const Duration(minutes: 1),
      );
      final accepted = await repository.acceptIncomingOffer(
        expiring,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt.subtract(const Duration(seconds: 30)),
      );
      final constrained = RelayRepository(
        database: database,
        maximumPayloadBytes: accepted.row.storageBytes,
      );
      final replacement = await _offer(
        originMessageId: 'relay-new-0001',
        incidentId: 'incident-new-0001',
        createdAt: acceptedAt.add(const Duration(minutes: 1)),
        lifetime: const Duration(minutes: 1),
      );
      await constrained.acceptIncomingOffer(
        replacement,
        sourceDeviceId: 'peer-a',
        relayEnabled: true,
        now: acceptedAt.add(const Duration(minutes: 1)),
      );

      expect(
        await database.select(database.bleRelayMessages).get(),
        hasLength(1),
      );
      expect(
        (await database.select(database.sosMessages).getSingle()).id,
        'direct-sos',
      );
    },
  );
}
