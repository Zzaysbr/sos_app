import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/relay_envelope.dart';
import 'relay_key_store.dart';
import 'relay_storage_accounting.dart';

enum RelayMessageState {
  queued('queued'),
  expired('expired'),
  finalDelivered('finalDelivered');

  const RelayMessageState(this.wireValue);
  final String wireValue;
}

enum RelayAttemptState {
  queued('queued'),
  sending('sending'),
  awaitingHopReceipt('awaitingHopReceipt'),
  acceptedByRelay('acceptedByRelay'),
  failed('failed'),
  expired('expired');

  const RelayAttemptState(this.wireValue);
  final String wireValue;
}

class RelayAcceptanceResult {
  const RelayAcceptanceResult({required this.row, required this.duplicate});
  final BleRelayMessage row;
  final bool duplicate;
}

/// Stage-1 relay-only persistence. It never writes normal SOS, direct BLE, or
/// cloud-sync tables and performs no scanning or forwarding by itself.
class RelayRepository {
  RelayRepository({
    required this.database,
    RelayCryptography? cryptography,
    this.maximumJobs = RelayProtocolLimits.maximumJobs,
    this.maximumPayloadBytes = RelayProtocolLimits.maximumPayloadStorageBytes,
  }) : _cryptography = cryptography ?? RelayCryptography();

  final AppDatabase database;
  final RelayCryptography _cryptography;
  final int maximumJobs;
  final int maximumPayloadBytes;

  static const maximumRetriesPerPeer = 3;
  static const nativeRelayWriteFailure = 'Native relay write failed.';
  static const localOriginPeerId = 'local-origin';

  static Future<String> attemptIdFor(
    String originMessageId,
    String nextHopKeyId,
  ) => RelayCryptography().relayAttemptId(
    originMessageId: originMessageId,
    nextHopKeyId: nextHopKeyId,
  );

  Future<RelayAcceptanceResult> persistOriginOffer(
    RelayOfferEnvelope offer, {
    DateTime? now,
  }) async {
    if (offer.hopCount != 0 ||
        offer.hopAttestations.isNotEmpty ||
        offer.pathKeyIds.length != 1 ||
        offer.pathKeyIds.single != offer.body.originKeyId ||
        offer.immediateSenderKeyId != offer.body.originKeyId) {
      throw const RelayPersistenceException(
        'Invalid local relay origin offer.',
      );
    }
    return acceptIncomingOffer(
      offer,
      sourceDeviceId: localOriginPeerId,
      relayEnabled: true,
      now: now,
    );
  }

  Future<RelayAcceptanceResult> acceptIncomingOffer(
    RelayOfferEnvelope offer, {
    required String sourceDeviceId,
    required bool relayEnabled,
    bool Function()? participationStillEnabled,
    DateTime? now,
  }) async {
    if (!relayEnabled) {
      throw const RelayPersistenceException('Relay participation is disabled.');
    }
    final timestamp = _databaseTime(now ?? DateTime.now());
    if (!await _cryptography.verifyOffer(offer, now: timestamp)) {
      throw const RelayPersistenceException('Relay offer verification failed.');
    }
    final source = sourceDeviceId.trim();
    if (source.isEmpty) {
      throw const RelayPersistenceException('Relay source peer is required.');
    }
    final immutablePayload = relayCanonicalJson(offer.body.toCanonicalMap());
    final immutableDigest = await _cryptography.immutableDigest(offer.body);
    final wireEnvelope = offer.toCanonicalWire();
    final payloadBytes = utf8.encode(wireEnvelope).length;
    final expiresAt = _databaseTime(offer.expiresAt);
    final retentionDeadline = _databaseTime(
      _minimumTime(
        offer.expiresAt,
        timestamp.add(RelayProtocolLimits.maximumLifetime),
      ),
    );
    final messageFields = _messageFields(
      originMessageId: offer.body.originMessageId,
      incidentId: offer.body.incidentId,
      originKeyId: offer.body.originKeyId,
      originPublicKey: offer.body.originPublicKey,
      immutablePayload: immutablePayload,
      wireEnvelope: wireEnvelope,
      immutableDigest: immutableDigest,
      originSignature: offer.originSignature,
      authorizationScope: offer.body.scope.wireValue,
      emergencyType: offer.body.emergencyType,
      createdAt: offer.body.createdAt,
      expiresAt: expiresAt,
      retentionDeadline: retentionDeadline,
      maxHops: offer.body.maxHops,
      incomingHopCount: offer.hopCount,
      incomingPath: relayCanonicalJson({'path': offer.pathKeyIds}),
      incomingPeerId: source,
      previousHopKeyId: offer.immediateSenderKeyId,
      processingState: RelayMessageState.queued.wireValue,
      payloadBytes: payloadBytes,
      receivedAt: timestamp,
      persistedAt: timestamp,
    );
    final storageBytes = relayLogicalRecordBytes(
      'ble_relay_messages',
      messageFields,
    );

    return database.transaction(() async {
      await _cleanupExpiredInTransaction(timestamp);
      if (participationStillEnabled != null && !participationStillEnabled()) {
        throw const RelayPersistenceException(
          'Relay participation changed before persistence.',
        );
      }
      final existing = await lookupMessage(offer.body.originMessageId);
      if (source == localOriginPeerId && offer.lease != null) {
        final active =
            await (database.select(database.sosMessages)..where(
                  (s) =>
                      s.id.equals(offer.body.incidentId) &
                      s.status.equals('active'),
                ))
                .getSingleOrNull();
        if (active == null || existing?.incomingPeerId != localOriginPeerId) {
          throw const RelayPersistenceException(
            'Only an active local SOS can be renewed.',
          );
        }
      }
      if (existing != null) {
        // An already verified origin can arrive through another authenticated
        // route. Deduplicate the immutable signed origin, not its mutable hop
        // envelope/native address; retain the first durable route unchanged.
        // Locally originated records still reject returning relay loops.
        final renewingLocal =
            source == localOriginPeerId && offer.lease != null;
        if ((existing.incomingPeerId == localOriginPeerId && !renewingLocal) ||
            existing.immutablePayload != immutablePayload ||
            existing.immutableDigest != immutableDigest ||
            existing.originSignature != offer.originSignature) {
          throw const RelayPersistenceException(
            'Conflicting relay offer reuses a stored identity.',
          );
        }
        await _loadVerifiedOffer(existing, timestamp, allowExpired: true);
        if (offer.lease == null ||
            !offer.expiresAt.isAfter(existing.expiresAt)) {
          return RelayAcceptanceResult(row: existing, duplicate: true);
        }
        // Relay attempts and hop receipts belong to the previous lease.
        // Foreign keys remove them atomically; incident/history IDs stay put.
        await (database.delete(
              database.bleRelayMessages,
            )..where((r) => r.originMessageId.equals(existing.originMessageId)))
            .go();
      }
      await _enforceGlobalQuota(deltaBytes: storageBytes);
      if (participationStillEnabled != null && !participationStillEnabled()) {
        throw const RelayPersistenceException(
          'Relay participation changed before persistence.',
        );
      }
      final count = await database.bleRelayMessages.count().getSingle();
      if (count >= maximumJobs) {
        throw const RelayPersistenceException('Relay job quota is full.');
      }
      await database
          .into(database.bleRelayMessages)
          .insert(
            BleRelayMessagesCompanion.insert(
              originMessageId: offer.body.originMessageId,
              incidentId: offer.body.incidentId,
              originKeyId: offer.body.originKeyId,
              originPublicKey: offer.body.originPublicKey,
              immutablePayload: immutablePayload,
              wireEnvelope: wireEnvelope,
              immutableDigest: immutableDigest,
              originSignature: offer.originSignature,
              authorizationScope: offer.body.scope.wireValue,
              emergencyType: offer.body.emergencyType,
              createdAt: offer.body.createdAt,
              expiresAt: expiresAt,
              retentionDeadline: retentionDeadline,
              maxHops: offer.body.maxHops,
              incomingHopCount: offer.hopCount,
              incomingPath: relayCanonicalJson({'path': offer.pathKeyIds}),
              incomingPeerId: source,
              previousHopKeyId: offer.immediateSenderKeyId,
              processingState: RelayMessageState.queued.wireValue,
              payloadBytes: payloadBytes,
              storageBytes: storageBytes,
              receivedAt: timestamp,
              persistedAt: timestamp,
            ),
          );
      return RelayAcceptanceResult(
        row: (await lookupMessage(offer.body.originMessageId))!,
        duplicate: false,
      );
    });
  }

  Future<RelayOfferEnvelope> loadVerifiedOffer(
    String originMessageId, {
    DateTime? now,
  }) async {
    final row = await lookupMessage(originMessageId);
    if (row == null) {
      throw const RelayPersistenceException('Relay message was not found.');
    }
    return _loadVerifiedOffer(row, (now ?? DateTime.now()).toUtc());
  }

  Future<RelayOfferEnvelope> _loadVerifiedOffer(
    BleRelayMessage row,
    DateTime timestamp, {
    bool allowExpired = false,
  }) async {
    if (!allowExpired && !row.retentionDeadline.toUtc().isAfter(timestamp)) {
      throw const RelayPersistenceException(
        'Relay message has expired locally.',
      );
    }
    try {
      final offer = RelayOfferEnvelope.fromCanonicalWire(row.wireEnvelope);
      final immutablePayload = relayCanonicalJson(offer.body.toCanonicalMap());
      final immutableDigest = await _cryptography.immutableDigest(offer.body);
      final incomingPath = relayCanonicalJson({'path': offer.pathKeyIds});
      final payloadBytes = utf8.encode(row.wireEnvelope).length;
      final expectedDeadline = _databaseTime(
        _minimumTime(
          offer.expiresAt,
          row.receivedAt.toUtc().add(RelayProtocolLimits.maximumLifetime),
        ),
      );
      final expectedStorageBytes = relayLogicalRecordBytes(
        'ble_relay_messages',
        _messageFieldsFromRow(row),
      );
      // Older lease builds counted the signed subsecond expiry before SQLite
      // truncated its local projection. Reconstruct that exact accounting;
      // signature and all projected fields are still verified below.
      final legacyLeaseFields = {
        ..._messageFieldsFromRow(row),
        'expiresAt': _wireTime(offer.expiresAt),
        'retentionDeadline': _wireTime(
          _minimumTime(
            offer.expiresAt,
            row.receivedAt.toUtc().add(RelayProtocolLimits.maximumLifetime),
          ),
        ),
      };
      final legacySubsecondAccounting =
          _hasLegacySubsecondAccounting(row, expectedStorageBytes) ||
          (offer.lease != null &&
              row.storageBytes ==
                  relayLogicalRecordBytes(
                    'ble_relay_messages',
                    legacyLeaseFields,
                  ) &&
              row.storageBytes != expectedStorageBytes);
      if (!await _cryptography.verifyOffer(
            offer,
            now: timestamp,
            allowExpired: allowExpired,
          ) ||
          offer.body.originMessageId != row.originMessageId ||
          offer.body.incidentId != row.incidentId ||
          offer.body.originKeyId != row.originKeyId ||
          offer.body.originPublicKey != row.originPublicKey ||
          immutablePayload != row.immutablePayload ||
          offer.body.scope.wireValue != row.authorizationScope ||
          offer.body.emergencyType != row.emergencyType ||
          !_sameTime(offer.body.createdAt, row.createdAt) ||
          !_sameTime(_databaseTime(offer.expiresAt), row.expiresAt) ||
          !_sameTime(expectedDeadline, row.retentionDeadline) ||
          offer.body.maxHops != row.maxHops ||
          offer.originSignature != row.originSignature ||
          offer.hopCount != row.incomingHopCount ||
          incomingPath != row.incomingPath ||
          offer.immediateSenderKeyId != row.previousHopKeyId ||
          immutableDigest != row.immutableDigest ||
          payloadBytes != row.payloadBytes ||
          (expectedStorageBytes != row.storageBytes &&
              !legacySubsecondAccounting) ||
          row.incomingPeerId.trim().isEmpty ||
          !_sameTime(row.receivedAt, row.persistedAt) ||
          !RelayMessageState.values.any(
            (state) => state.wireValue == row.processingState,
          ) ||
          !_validFinalBinding(row)) {
        throw const RelayPersistenceException(
          'Stored relay offer failed integrity verification.',
        );
      }
      if (legacySubsecondAccounting) {
        final repaired =
            await (database.update(database.bleRelayMessages)..where(
                  (table) =>
                      table.originMessageId.equals(row.originMessageId) &
                      table.storageBytes.equals(row.storageBytes),
                ))
                .write(
                  BleRelayMessagesCompanion(
                    storageBytes: Value(expectedStorageBytes),
                  ),
                );
        if (repaired != 1) {
          throw const RelayPersistenceException(
            'Stored relay accounting changed during verification.',
          );
        }
      }
      return offer;
    } on RelayPersistenceException {
      rethrow;
    } on Object {
      throw const RelayPersistenceException(
        'Stored relay offer could not be reconstructed.',
      );
    }
  }

  Future<BleRelayAttempt> createNextHopAttempt({
    required String originMessageId,
    required String nextHopKeyId,
    required String nextHopDeviceId,
    required String localRelayKeyId,
    required String correlationId,
    DateTime? now,
  }) async {
    final timestamp = _databaseTime(now ?? DateTime.now());
    final candidateKey = nextHopKeyId.trim();
    final device = nextHopDeviceId.trim();
    final correlation = correlationId.trim();
    validateRelayKeyId(candidateKey, name: 'nextHopKeyId');
    validateRelayKeyId(localRelayKeyId, name: 'localRelayKeyId');
    if (device.isEmpty || correlation.isEmpty || correlation.length > 128) {
      throw const RelayPersistenceException('Next-hop binding is invalid.');
    }
    return database.transaction(() async {
      await _cleanupExpiredInTransaction(timestamp);
      final message = await lookupMessage(originMessageId);
      if (message == null ||
          message.processingState != RelayMessageState.queued.wireValue) {
        throw const RelayPersistenceException('Relay message is not eligible.');
      }
      final offer = await _loadVerifiedOffer(message, timestamp);
      if (offer.pathKeyIds.contains(candidateKey) ||
          candidateKey == offer.immediateSenderKeyId) {
        throw const RelayPersistenceException('Next hop would create a loop.');
      }
      final localIsOrigin =
          offer.hopCount == 0 &&
          offer.pathKeyIds.length == 1 &&
          offer.pathKeyIds.single == localRelayKeyId &&
          offer.body.originKeyId == localRelayKeyId;
      if (!localIsOrigin && offer.pathKeyIds.contains(localRelayKeyId)) {
        throw const RelayPersistenceException('Next hop would create a loop.');
      }
      final outgoingHopCount = localIsOrigin
          ? offer.hopCount
          : offer.hopCount + 1;
      if (outgoingHopCount > offer.body.maxHops) {
        throw const RelayPersistenceException('Relay hop limit is exhausted.');
      }
      final outgoingPath = localIsOrigin
          ? offer.pathKeyIds
          : [...offer.pathKeyIds, localRelayKeyId];
      final attemptId = await attemptIdFor(originMessageId, candidateKey);
      final outgoingPathWire = relayCanonicalJson({'path': outgoingPath});
      final attemptFields = _attemptFields(
        originMessageId: originMessageId,
        nextHopKeyId: candidateKey,
        attemptId: attemptId,
        correlationId: correlation,
        nextHopDeviceId: device,
        outgoingHopCount: outgoingHopCount,
        outgoingPath: outgoingPathWire,
        state: RelayAttemptState.queued.wireValue,
        retryCount: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final storageBytes = relayLogicalRecordBytes(
        'ble_relay_attempts',
        attemptFields,
      );
      final existing =
          await (database.select(database.bleRelayAttempts)..where(
                (table) =>
                    table.originMessageId.equals(originMessageId) &
                    table.nextHopKeyId.equals(candidateKey),
              ))
              .getSingleOrNull();
      if (existing != null) {
        if (existing.attemptId != attemptId ||
            existing.correlationId != correlation ||
            existing.outgoingHopCount != outgoingHopCount ||
            existing.outgoingPath != outgoingPathWire) {
          throw const RelayPersistenceException(
            'Next-hop attempt conflicts with stored immutable fields.',
          );
        }
        if (existing.nextHopDeviceId != device) {
          final state = RelayAttemptState.values.firstWhere(
            (candidate) => candidate.wireValue == existing.state,
            orElse: () => RelayAttemptState.expired,
          );
          final retryReady =
              state == RelayAttemptState.failed &&
              existing.retryCount < maximumRetriesPerPeer &&
              (existing.nextRetryAt == null ||
                  !existing.nextRetryAt!.toUtc().isAfter(timestamp));
          // A BLE address is a session-scoped transport locator, not the
          // authenticated next-hop identity. iOS privacy addresses can rotate
          // between retries. Rebind only while no write/receipt is in flight;
          // the signed key id, deterministic attempt id and correlation stay
          // immutable.
          if (state == RelayAttemptState.queued || retryReady) {
            final reboundFields = _attemptFieldsFromRow(
              existing,
              nextHopDeviceId: device,
              updatedAt: timestamp,
            );
            final reboundBytes = relayLogicalRecordBytes(
              'ble_relay_attempts',
              reboundFields,
            );
            await _enforceGlobalQuota(
              deltaBytes: reboundBytes - existing.storageBytes,
            );
            final updated =
                await (database.update(database.bleRelayAttempts)..where(
                      (table) =>
                          table.originMessageId.equals(originMessageId) &
                          table.nextHopKeyId.equals(candidateKey) &
                          table.nextHopDeviceId.equals(
                            existing.nextHopDeviceId,
                          ) &
                          table.state.equals(existing.state),
                    ))
                    .write(
                      BleRelayAttemptsCompanion(
                        nextHopDeviceId: Value(device),
                        updatedAt: Value(timestamp),
                        storageBytes: Value(reboundBytes),
                      ),
                    );
            if (updated != 1) {
              throw const RelayPersistenceException(
                'Next-hop transport locator changed concurrently.',
              );
            }
            return (database.select(database.bleRelayAttempts)..where(
                  (table) =>
                      table.originMessageId.equals(originMessageId) &
                      table.nextHopKeyId.equals(candidateKey),
                ))
                .getSingle();
          }
        }
        return existing;
      }
      final attemptCountExpression = database.bleRelayAttempts.attemptId
          .count();
      final attemptCountRow =
          await (database.selectOnly(database.bleRelayAttempts)
                ..addColumns([attemptCountExpression])
                ..where(
                  database.bleRelayAttempts.originMessageId.equals(
                    originMessageId,
                  ),
                ))
              .getSingle();
      final attemptCount = attemptCountRow.read(attemptCountExpression) ?? 0;
      if (attemptCount >= RelayProtocolLimits.maximumAttemptsPerMessage) {
        throw const RelayPersistenceException('Relay attempt quota is full.');
      }
      await _enforceGlobalQuota(deltaBytes: storageBytes);
      await database
          .into(database.bleRelayAttempts)
          .insert(
            BleRelayAttemptsCompanion.insert(
              originMessageId: originMessageId,
              nextHopKeyId: candidateKey,
              attemptId: attemptId,
              correlationId: correlation,
              nextHopDeviceId: device,
              outgoingHopCount: outgoingHopCount,
              outgoingPath: outgoingPathWire,
              storageBytes: storageBytes,
              state: RelayAttemptState.queued.wireValue,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      return (database.select(database.bleRelayAttempts)..where(
            (table) =>
                table.originMessageId.equals(originMessageId) &
                table.nextHopKeyId.equals(candidateKey),
          ))
          .getSingle();
    });
  }

  Future<RelayOfferEnvelope> prepareOutgoingOffer({
    required String originMessageId,
    required RelaySigningIdentity identity,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final offer = await loadVerifiedOffer(originMessageId, now: timestamp);
    final localIsOrigin =
        offer.hopCount == 0 &&
        offer.pathKeyIds.length == 1 &&
        offer.pathKeyIds.single == identity.keyId &&
        offer.body.originKeyId == identity.keyId;
    if (localIsOrigin) return offer;
    if (offer.pathKeyIds.contains(identity.keyId) ||
        offer.hopCount + 1 > offer.body.maxHops) {
      throw const RelayPersistenceException(
        'Relay offer cannot be forwarded by this installation.',
      );
    }
    final digest = await _cryptography.immutableDigest(offer.body);
    final unsigned = RelayHopAttestation(
      originMessageId: offer.body.originMessageId,
      immutableDigest: digest,
      relayKeyId: identity.keyId,
      relayPublicKey: base64UrlEncode(identity.publicKey),
      hopCount: offer.hopCount + 1,
      pathKeyIds: [...offer.pathKeyIds, identity.keyId],
      signature: base64UrlEncode(List<int>.filled(64, 0)),
    );
    final attestation = RelayHopAttestation(
      originMessageId: unsigned.originMessageId,
      immutableDigest: unsigned.immutableDigest,
      relayKeyId: unsigned.relayKeyId,
      relayPublicKey: unsigned.relayPublicKey,
      hopCount: unsigned.hopCount,
      pathKeyIds: unsigned.pathKeyIds,
      signature: await _cryptography.signHopAttestation(
        unsigned,
        identity.keyPair,
      ),
    );
    final outgoing = RelayOfferEnvelope(
      body: offer.body,
      originSignature: offer.originSignature,
      hopCount: offer.hopCount + 1,
      pathKeyIds: [...offer.pathKeyIds, identity.keyId],
      immediateSenderKeyId: identity.keyId,
      hopAttestations: [...offer.hopAttestations, attestation],
      lease: offer.lease,
    );
    if (!await _cryptography.verifyOffer(outgoing, now: timestamp)) {
      throw const RelayPersistenceException(
        'Prepared relay offer failed verification.',
      );
    }
    return outgoing;
  }

  /// Records the transport lifecycle without claiming peer authentication.
  /// Stage 2 must call these methods only after the corresponding native send
  /// event. They deliberately cannot register final-recipient authorization.
  Future<BleRelayAttempt> markAttemptSending({
    required String originMessageId,
    required String attemptId,
    DateTime? now,
  }) => _transitionAttempt(
    originMessageId: originMessageId,
    attemptId: attemptId,
    expectedState: RelayAttemptState.queued,
    nextState: RelayAttemptState.sending,
    markAttempted: true,
    now: now,
  );

  Future<BleRelayAttempt> markAttemptAwaitingHopReceipt({
    required String originMessageId,
    required String attemptId,
    DateTime? now,
  }) async {
    final timestamp = _databaseTime(now ?? DateTime.now());
    return database.transaction(() async {
      await _cleanupExpiredInTransaction(timestamp);
      final message = await lookupMessage(originMessageId);
      if (message == null) {
        throw const RelayPersistenceException('Relay message was not found.');
      }
      await _loadVerifiedOffer(message, timestamp);
      final attempt =
          await (database.select(database.bleRelayAttempts)..where(
                (table) =>
                    table.originMessageId.equals(originMessageId) &
                    table.attemptId.equals(attemptId),
              ))
              .getSingleOrNull();
      if (attempt == null) {
        throw const RelayPersistenceException('Relay attempt was not found.');
      }
      // A fast peer can persist the offer and return its signed hop receipt
      // before Android reports completion for the final GATT write. Receipt
      // persistence atomically moves this exact attempt to acceptedByRelay.
      // Treat that terminal success as an idempotent completion rather than
      // regressing it or mislabelling the native write as failed.
      if (attempt.state == RelayAttemptState.acceptedByRelay.wireValue) {
        return attempt;
      }
      if (attempt.state != RelayAttemptState.sending.wireValue) {
        throw RelayPersistenceException(
          'Illegal relay attempt transition from ${attempt.state} to '
          '${RelayAttemptState.awaitingHopReceipt.wireValue}.',
        );
      }
      final nextFields = _attemptFieldsFromRow(
        attempt,
        state: RelayAttemptState.awaitingHopReceipt.wireValue,
        updatedAt: timestamp,
      );
      final nextBytes = relayLogicalRecordBytes(
        'ble_relay_attempts',
        nextFields,
      );
      await _enforceGlobalQuota(deltaBytes: nextBytes - attempt.storageBytes);
      final updated =
          await (database.update(database.bleRelayAttempts)..where(
                (table) =>
                    table.attemptId.equals(attemptId) &
                    table.state.equals(RelayAttemptState.sending.wireValue),
              ))
              .write(
                BleRelayAttemptsCompanion(
                  state: Value(RelayAttemptState.awaitingHopReceipt.wireValue),
                  updatedAt: Value(timestamp),
                  storageBytes: Value(nextBytes),
                ),
              );
      if (updated != 1) {
        final raced = await (database.select(
          database.bleRelayAttempts,
        )..where((table) => table.attemptId.equals(attemptId))).getSingle();
        if (raced.state == RelayAttemptState.acceptedByRelay.wireValue) {
          return raced;
        }
        throw const RelayPersistenceException(
          'Relay attempt changed during receipt transition.',
        );
      }
      return (database.select(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attemptId))).getSingle();
    });
  }

  Future<BleRelayAttempt> _transitionAttempt({
    required String originMessageId,
    required String attemptId,
    required RelayAttemptState expectedState,
    required RelayAttemptState nextState,
    required bool markAttempted,
    DateTime? now,
  }) {
    final timestamp = _databaseTime(now ?? DateTime.now());
    return database.transaction(() async {
      await _cleanupExpiredInTransaction(timestamp);
      final message = await lookupMessage(originMessageId);
      if (message == null) {
        throw const RelayPersistenceException('Relay message was not found.');
      }
      await _loadVerifiedOffer(message, timestamp);
      final attempt =
          await (database.select(database.bleRelayAttempts)..where(
                (table) =>
                    table.originMessageId.equals(originMessageId) &
                    table.attemptId.equals(attemptId),
              ))
              .getSingleOrNull();
      if (attempt == null || attempt.state != expectedState.wireValue) {
        throw RelayPersistenceException(
          'Illegal relay attempt transition from ${attempt?.state ?? 'missing'} '
          'to ${nextState.wireValue}.',
        );
      }
      final nextFields = _attemptFieldsFromRow(
        attempt,
        state: nextState.wireValue,
        updatedAt: timestamp,
        lastAttemptAt: markAttempted ? timestamp : attempt.lastAttemptAt,
      );
      final nextBytes = relayLogicalRecordBytes(
        'ble_relay_attempts',
        nextFields,
      );
      await _enforceGlobalQuota(deltaBytes: nextBytes - attempt.storageBytes);
      await (database.update(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attemptId))).write(
        BleRelayAttemptsCompanion(
          state: Value(nextState.wireValue),
          lastAttemptAt: markAttempted
              ? Value(timestamp)
              : const Value.absent(),
          updatedAt: Value(timestamp),
          storageBytes: Value(nextBytes),
        ),
      );
      return (database.select(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attemptId))).getSingle();
    });
  }

  Future<BleRelayAttempt?> claimAttemptForSending({
    required String originMessageId,
    required String attemptId,
    ({String deviceId, DateTime connectedAt})? provenLink,
    DateTime? now,
  }) async {
    final timestamp = _databaseTime(now ?? DateTime.now());
    return database.transaction(() async {
      await _cleanupExpiredInTransaction(timestamp);
      final message = await lookupMessage(originMessageId);
      if (message == null) return null;
      await _loadVerifiedOffer(message, timestamp);
      final attempt =
          await (database.select(database.bleRelayAttempts)..where(
                (table) =>
                    table.originMessageId.equals(originMessageId) &
                    table.attemptId.equals(attemptId),
              ))
              .getSingleOrNull();
      if (attempt == null) return null;
      final state = RelayAttemptState.values.firstWhere(
        (candidate) => candidate.wireValue == attempt.state,
        orElse: () => RelayAttemptState.expired,
      );
      final retryReady =
          state == RelayAttemptState.failed &&
          attempt.retryCount < maximumRetriesPerPeer &&
          (attempt.nextRetryAt == null ||
              !attempt.nextRetryAt!.toUtc().isAfter(timestamp));
      // Reserve one additional send for a newer, proven native connection.
      // Retain the retry counter so a second reconnect cannot renew the budget.
      final recovered =
          provenLink != null &&
          state == RelayAttemptState.failed &&
          attempt.retryCount == maximumRetriesPerPeer &&
          attempt.lastError == nativeRelayWriteFailure &&
          _databaseTime(provenLink.connectedAt).isAfter(attempt.updatedAt);
      if (state != RelayAttemptState.queued && !retryReady && !recovered) {
        return null;
      }
      final device = recovered ? provenLink.deviceId : attempt.nextHopDeviceId;
      final nextFields = _attemptFieldsFromRow(
        attempt,
        nextHopDeviceId: device,
        state: RelayAttemptState.sending.wireValue,
        updatedAt: timestamp,
        lastAttemptAt: timestamp,
        nextRetryAt: null,
        replaceNextRetryAt: true,
        lastError: null,
        replaceLastError: true,
      );
      final nextBytes = relayLogicalRecordBytes(
        'ble_relay_attempts',
        nextFields,
      );
      await _enforceGlobalQuota(deltaBytes: nextBytes - attempt.storageBytes);
      final updated =
          await (database.update(database.bleRelayAttempts)..where(
                (table) =>
                    table.originMessageId.equals(originMessageId) &
                    table.attemptId.equals(attemptId) &
                    table.state.equals(attempt.state),
              ))
              .write(
                BleRelayAttemptsCompanion(
                  nextHopDeviceId: Value(device),
                  state: Value(RelayAttemptState.sending.wireValue),
                  lastAttemptAt: Value(timestamp),
                  nextRetryAt: const Value(null),
                  lastError: const Value(null),
                  updatedAt: Value(timestamp),
                  storageBytes: Value(nextBytes),
                ),
              );
      if (updated != 1) return null;
      return (database.select(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attemptId))).getSingle();
    });
  }

  Future<BleRelayAttempt> markAttemptFailed({
    required String originMessageId,
    required String attemptId,
    required String error,
    Duration retryDelay = const Duration(seconds: 5),
    DateTime? now,
  }) async {
    final timestamp = _databaseTime(now ?? DateTime.now());
    final safeError = error.trim().isEmpty
        ? 'Relay send failed.'
        : error.trim().substring(0, error.trim().length.clamp(0, 256));
    return database.transaction(() async {
      final attempt =
          await (database.select(database.bleRelayAttempts)..where(
                (table) =>
                    table.originMessageId.equals(originMessageId) &
                    table.attemptId.equals(attemptId),
              ))
              .getSingleOrNull();
      if (attempt == null ||
          (attempt.state != RelayAttemptState.sending.wireValue &&
              attempt.state !=
                  RelayAttemptState.awaitingHopReceipt.wireValue)) {
        throw const RelayPersistenceException(
          'Only an active relay attempt can fail.',
        );
      }
      final retryCount = attempt.retryCount + 1;
      final retryAt = retryCount < maximumRetriesPerPeer
          ? timestamp.add(retryDelay)
          : null;
      final nextFields = _attemptFieldsFromRow(
        attempt,
        state: RelayAttemptState.failed.wireValue,
        retryCount: retryCount,
        nextRetryAt: retryAt,
        replaceNextRetryAt: true,
        lastError: safeError,
        replaceLastError: true,
        updatedAt: timestamp,
      );
      final nextBytes = relayLogicalRecordBytes(
        'ble_relay_attempts',
        nextFields,
      );
      await _enforceGlobalQuota(deltaBytes: nextBytes - attempt.storageBytes);
      await (database.update(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attemptId))).write(
        BleRelayAttemptsCompanion(
          state: Value(RelayAttemptState.failed.wireValue),
          retryCount: Value(retryCount),
          nextRetryAt: Value(retryAt),
          lastError: Value(safeError),
          updatedAt: Value(timestamp),
          storageBytes: Value(nextBytes),
        ),
      );
      return (database.select(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attemptId))).getSingle();
    });
  }

  Future<int> recoverStaleAttempts({
    required DateTime olderThan,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final stale =
        await (database.select(database.bleRelayAttempts)..where(
              (table) =>
                  table.updatedAt.isSmallerOrEqualValue(olderThan.toUtc()) &
                  (table.state.equals(RelayAttemptState.sending.wireValue) |
                      table.state.equals(
                        RelayAttemptState.awaitingHopReceipt.wireValue,
                      )),
            ))
            .get();
    var changed = 0;
    for (final attempt in stale) {
      try {
        await markAttemptFailed(
          originMessageId: attempt.originMessageId,
          attemptId: attempt.attemptId,
          error: 'Relay attempt timed out before a signed hop receipt.',
          now: timestamp,
        );
        changed++;
      } on RelayPersistenceException {
        // A concurrent receipt or retry won the state transition.
      }
    }
    return changed;
  }

  Future<List<BleRelayMessage>> listForwardableMessages({DateTime? now}) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    await cleanupExpired(now: timestamp);
    final rows =
        await (database.select(database.bleRelayMessages)..where(
              (table) =>
                  table.processingState.equals(
                    RelayMessageState.queued.wireValue,
                  ) &
                  table.retentionDeadline.isBiggerThanValue(timestamp) &
                  table.expiresAt.isBiggerThanValue(timestamp),
            ))
            .get();
    final verified = <BleRelayMessage>[];
    for (final row in rows) {
      await _loadVerifiedOffer(row, timestamp);
      verified.add(row);
    }
    return verified;
  }

  Future<List<BleRelayAttempt>> listAttempts(String originMessageId) =>
      (database.select(
        database.bleRelayAttempts,
      )..where((table) => table.originMessageId.equals(originMessageId))).get();

  Stream<List<BleRelayMessage>> watchMessagesForIncident(String incidentId) =>
      (database.select(
        database.bleRelayMessages,
      )..where((table) => table.incidentId.equals(incidentId))).watch();

  Stream<List<BleRelayAttempt>> watchAttemptsForIncident(String incidentId) {
    final query = database.select(database.bleRelayAttempts).join([
      innerJoin(
        database.bleRelayMessages,
        database.bleRelayMessages.originMessageId.equalsExp(
          database.bleRelayAttempts.originMessageId,
        ),
      ),
    ])..where(database.bleRelayMessages.incidentId.equals(incidentId));
    return query.watch().map(
      (rows) => rows
          .map((row) => row.readTable(database.bleRelayAttempts))
          .toList(growable: false),
    );
  }

  /// Removes only this installation's origin job for one incident.
  ///
  /// Relay copies received from other installations remain isolated and are
  /// retained until their signed expiry. This is not a network recall; it
  /// only prevents this installation from forwarding its local SOS again.
  Future<int> removeLocalOriginForIncident(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      throw const RelayPersistenceException('Relay incident ID is required.');
    }
    return (database.delete(database.bleRelayMessages)..where(
          (table) =>
              table.incidentId.equals(id) &
              table.incomingPeerId.equals(localOriginPeerId),
        ))
        .go();
  }

  /// Cleans origin jobs orphaned by cancel, resolve, or delete in an older
  /// app run. Never apply this to hop-only jobs received from another peer:
  /// those intentionally have no row in normal SOS history.
  Future<int> removeInactiveLocalOrigins() => database.transaction(() async {
    final origins = await (database.select(
      database.bleRelayMessages,
    )..where((table) => table.incomingPeerId.equals(localOriginPeerId))).get();
    var removed = 0;
    for (final origin in origins) {
      final sos =
          await (database.select(database.sosMessages)
                ..where((table) => table.id.equals(origin.incidentId)))
              .getSingleOrNull();
      if (sos != null && sos.status == 'active') continue;
      removed +=
          await (database.delete(database.bleRelayMessages)..where(
                (table) =>
                    table.originMessageId.equals(origin.originMessageId) &
                    table.incomingPeerId.equals(localOriginPeerId),
              ))
              .go();
    }
    return removed;
  });

  Future<List<BleRelayMessage>> localOriginsForRenewal(
    String ownerId,
    DateTime dueBy,
  ) async {
    final origins = database.bleRelayMessages;
    final sos = database.sosMessages;
    final rows =
        await (database.select(origins).join([
              innerJoin(sos, sos.id.equalsExp(origins.incidentId)),
            ])..where(
              sos.ownerId.equals(ownerId) &
                  sos.status.equals('active') &
                  origins.incomingPeerId.equals(localOriginPeerId) &
                  origins.expiresAt.isSmallerOrEqualValue(dueBy),
            ))
            .get();
    return rows.map((row) => row.readTable(origins)).toList();
  }

  Future<bool> hasForwardableLocalOrigin({DateTime? now}) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    await removeInactiveLocalOrigins();
    await cleanupExpired(now: timestamp);
    final rows =
        await (database.select(database.bleRelayMessages)..where(
              (table) =>
                  table.incomingPeerId.equals(localOriginPeerId) &
                  table.processingState.equals(
                    RelayMessageState.queued.wireValue,
                  ),
            ))
            .get();
    for (final row in rows) {
      await _loadVerifiedOffer(row, timestamp);
    }
    return rows.isNotEmpty;
  }

  Future<BleRelayReceipt> persistReceipt(
    RelayReceiptEnvelope receipt, {
    required String sourcePeerDeviceId,
    DateTime? now,
  }) async {
    final timestamp = _databaseTime(now ?? DateTime.now());
    final source = sourcePeerDeviceId.trim();
    if (source.isEmpty ||
        !await _cryptography.verifyReceipt(receipt, now: timestamp)) {
      throw const RelayPersistenceException(
        'Relay receipt verification failed.',
      );
    }
    return database.transaction(() async {
      await _cleanupExpiredInTransaction(timestamp);
      final message = await lookupMessage(receipt.originMessageId);
      if (message == null) {
        throw const RelayPersistenceException(
          'Relay receipt does not match a retained message.',
        );
      }
      await _loadVerifiedOffer(message, timestamp);
      if (message.incidentId != receipt.incidentId ||
          message.immutableDigest != receipt.immutableDigest ||
          receipt.createdAt
              .add(RelayProtocolLimits.maximumClockSkew)
              .isBefore(message.createdAt) ||
          receipt.createdAt.isAfter(message.retentionDeadline) ||
          receipt.expiresAt.isAfter(message.retentionDeadline) ||
          (message.expiresAt.isAfter(
                message.createdAt.add(RelayProtocolLimits.maximumLifetime),
              ) &&
              receipt.expiresAt
                  .add(RelayProtocolLimits.maximumClockSkew)
                  .isBefore(message.retentionDeadline))) {
        throw const RelayPersistenceException(
          'Relay receipt does not match the retained message window.',
        );
      }
      String? previousHopKeyId;
      String? previousHopDeviceId;
      BleRelayAttempt? boundAttempt;
      if (receipt.type == RelayReceiptType.hop) {
        boundAttempt =
            await (database.select(
                  database.bleRelayAttempts,
                )..where((table) => table.attemptId.equals(receipt.attemptId!)))
                .getSingleOrNull();
        if (boundAttempt == null ||
            boundAttempt.originMessageId != receipt.originMessageId ||
            boundAttempt.correlationId != receipt.correlationId ||
            boundAttempt.nextHopKeyId != receipt.signerKeyId ||
            boundAttempt.nextHopDeviceId != source) {
          throw const RelayPersistenceException(
            'Hop receipt is not bound to the selected attempt and peer.',
          );
        }
        _verifyAttemptStorage(boundAttempt);
        previousHopKeyId = boundAttempt.nextHopKeyId;
        previousHopDeviceId = boundAttempt.nextHopDeviceId;
      } else {
        throw const RelayPersistenceException(
          'Final receipt authorization is unavailable without a trusted '
          'principal and authenticated peer proof.',
        );
      }
      final attempt = boundAttempt;
      final semanticKey = await _cryptography.receiptSemanticKey(receipt);
      final payload = receipt.toCanonicalWire();
      final bySemantic =
          await (database.select(database.bleRelayReceipts)
                ..where((table) => table.semanticKey.equals(semanticKey)))
              .getSingleOrNull();
      if (bySemantic != null) {
        _verifyReceiptStorage(bySemantic);
        if (bySemantic.receiptId != receipt.receiptId ||
            bySemantic.payload != payload ||
            bySemantic.signature != receipt.signature ||
            bySemantic.sourcePeerDeviceId != source ||
            attempt.state != RelayAttemptState.acceptedByRelay.wireValue) {
          throw const RelayPersistenceException(
            'Conflicting replay reuses a receipt semantic identity.',
          );
        }
        return bySemantic;
      }
      final byId =
          await (database.select(database.bleRelayReceipts)
                ..where((table) => table.receiptId.equals(receipt.receiptId)))
              .getSingleOrNull();
      if (byId != null) {
        throw const RelayPersistenceException(
          'Conflicting relay receipt reuses receiptId.',
        );
      }
      if ((attempt.state != RelayAttemptState.sending.wireValue &&
              attempt.state !=
                  RelayAttemptState.awaitingHopReceipt.wireValue) ||
          attempt.lastAttemptAt == null ||
          receipt.createdAt
              .add(RelayProtocolLimits.maximumClockSkew)
              .isBefore(attempt.lastAttemptAt!)) {
        throw const RelayPersistenceException(
          'Hop receipt arrived before the selected attempt was awaiting it.',
        );
      }
      final receiptCountExpression = database.bleRelayReceipts.semanticKey
          .count();
      final receiptCountRow =
          await (database.selectOnly(database.bleRelayReceipts)
                ..addColumns([receiptCountExpression])
                ..where(
                  database.bleRelayReceipts.originMessageId.equals(
                    receipt.originMessageId,
                  ),
                ))
              .getSingle();
      final receiptCount = receiptCountRow.read(receiptCountExpression) ?? 0;
      if (receiptCount >= RelayProtocolLimits.maximumReceiptsPerMessage) {
        throw const RelayPersistenceException('Relay receipt quota is full.');
      }
      const receiptState = 'persisted';
      final receiptFields = _receiptFields(
        semanticKey: semanticKey,
        receiptId: receipt.receiptId,
        receiptType: receipt.type.wireValue,
        originMessageId: receipt.originMessageId,
        incidentId: receipt.incidentId,
        immutableDigest: receipt.immutableDigest,
        signerKeyId: receipt.signerKeyId,
        signerPublicKey: receipt.signerPublicKey,
        correlationId: receipt.correlationId,
        attemptId: receipt.attemptId,
        finalAuthorizationId: receipt.finalAuthorizationId,
        sourcePeerDeviceId: source,
        previousHopKeyId: previousHopKeyId,
        previousHopDeviceId: previousHopDeviceId,
        payload: payload,
        signature: receipt.signature,
        state: receiptState,
        createdAt: receipt.createdAt,
        expiresAt: receipt.expiresAt,
        updatedAt: timestamp,
      );
      final storageBytes = relayLogicalRecordBytes(
        'ble_relay_receipts',
        receiptFields,
      );
      final acceptedAttemptFields = _attemptFieldsFromRow(
        attempt,
        state: RelayAttemptState.acceptedByRelay.wireValue,
        acceptedAt: timestamp,
        updatedAt: timestamp,
      );
      final acceptedAttemptBytes = relayLogicalRecordBytes(
        'ble_relay_attempts',
        acceptedAttemptFields,
      );
      await _enforceGlobalQuota(
        deltaBytes: storageBytes + acceptedAttemptBytes - attempt.storageBytes,
      );
      await database
          .into(database.bleRelayReceipts)
          .insert(
            BleRelayReceiptsCompanion.insert(
              semanticKey: semanticKey,
              receiptId: receipt.receiptId,
              receiptType: receipt.type.wireValue,
              originMessageId: receipt.originMessageId,
              incidentId: receipt.incidentId,
              immutableDigest: receipt.immutableDigest,
              signerKeyId: receipt.signerKeyId,
              signerPublicKey: receipt.signerPublicKey,
              correlationId: receipt.correlationId,
              attemptId: Value(receipt.attemptId),
              finalAuthorizationId: Value(receipt.finalAuthorizationId),
              sourcePeerDeviceId: source,
              previousHopKeyId: Value(previousHopKeyId),
              previousHopDeviceId: Value(previousHopDeviceId),
              payload: payload,
              signature: receipt.signature,
              storageBytes: storageBytes,
              state: receiptState,
              createdAt: receipt.createdAt,
              expiresAt: receipt.expiresAt,
              updatedAt: timestamp,
            ),
          );
      await (database.update(
        database.bleRelayAttempts,
      )..where((table) => table.attemptId.equals(attempt.attemptId))).write(
        BleRelayAttemptsCompanion(
          state: Value(RelayAttemptState.acceptedByRelay.wireValue),
          acceptedAt: Value(timestamp),
          updatedAt: Value(timestamp),
          storageBytes: Value(acceptedAttemptBytes),
        ),
      );
      return (database.select(
        database.bleRelayReceipts,
      )..where((table) => table.semanticKey.equals(semanticKey))).getSingle();
    });
  }

  Future<int> cleanupExpired({DateTime? now}) => database.transaction(
    () => _cleanupExpiredInTransaction((now ?? DateTime.now()).toUtc()),
  );

  Future<int> _cleanupExpiredInTransaction(DateTime timestamp) async {
    final rows = await database.select(database.bleRelayMessages).get();
    var deleted = 0;
    for (final row in rows) {
      // Transport-expired records normally disappear without reconstruction,
      // so corrupt legacy accounting cannot prevent startup forever. A live
      // Chat reference may retain verified authorization evidence below;
      // it never changes the signed lifetime or the forwarding deadline.
      if (!row.retentionDeadline.toUtc().isAfter(timestamp)) {
        // Transport expiry must not erase the signed authorization needed by
        // an established conversation or a still-live Chat job. Retained rows
        // keep their original deadlines/accounting and cannot be forwarded.
        if (await _hasChatReference(row, timestamp) ||
            (row.incomingPeerId == localOriginPeerId &&
                await (database.select(database.sosMessages)..where(
                          (s) =>
                              s.id.equals(row.incidentId) &
                              s.status.equals('active'),
                        ))
                        .getSingleOrNull() !=
                    null)) {
          try {
            await _loadVerifiedOffer(row, timestamp, allowExpired: true);
            continue;
          } on RelayPersistenceException {
            // Expired, corrupt evidence is still purged fail-closed.
          }
        }
        deleted +=
            await (database.delete(database.bleRelayMessages)..where(
                  (table) => table.originMessageId.equals(row.originMessageId),
                ))
                .go();
        continue;
      }
      final offer = await _loadVerifiedOffer(
        row,
        timestamp,
        allowExpired: true,
      );
      final deadline = _minimumTime(
        offer.expiresAt,
        row.receivedAt.toUtc().add(RelayProtocolLimits.maximumLifetime),
      );
      if (!deadline.isAfter(timestamp)) {
        deleted +=
            await (database.delete(database.bleRelayMessages)..where(
                  (table) => table.originMessageId.equals(row.originMessageId),
                ))
                .go();
      }
    }
    return deleted;
  }

  Future<bool> _hasChatReference(BleRelayMessage origin, DateTime now) async {
    final pending =
        await (database.select(database.chatRelayOutbox)
              ..where(
                (r) =>
                    r.incidentId.equals(origin.incidentId) &
                    r.expiresAt.isBiggerThanValue(now) &
                    r.state.isNotIn(const ['delivered', 'expired']),
              )
              ..limit(1))
            .getSingleOrNull();
    if (pending != null) return true;
    final receiptRoute =
        await (database.select(database.chatReceipts)
              ..where(
                (r) =>
                    r.incidentId.equals(origin.incidentId) &
                    r.expiresAt.isBiggerThanValue(now),
              )
              ..limit(1))
            .getSingleOrNull();
    if (receiptRoute != null) return true;

    final active =
        await (database.select(database.sosMessages)..where(
              (r) => r.id.equals(origin.incidentId) & r.status.equals('active'),
            ))
            .get();
    for (final incident in active) {
      final incoming =
          await (database.select(database.rescueResponseInbox)
                ..where(
                  (r) =>
                      r.ownerId.equals(incident.ownerId) &
                      r.originMessageId.equals(origin.originMessageId) &
                      r.state.equals('verified'),
                )
                ..limit(1))
              .getSingleOrNull();
      if (incoming != null) return true;
      final outgoing =
          await (database.select(database.rescueResponseOutbox)
                ..where(
                  (r) =>
                      r.ownerId.equals(incident.ownerId) &
                      r.originMessageId.equals(origin.originMessageId),
                )
                ..limit(1))
              .getSingleOrNull();
      if (outgoing != null) return true;
    }
    return false;
  }

  Future<void> _enforceGlobalQuota({required int deltaBytes}) async {
    if (deltaBytes > maximumPayloadBytes) {
      throw const RelayPersistenceException('Relay storage quota is full.');
    }
    var currentBytes = 0;
    for (final row in await database.select(database.bleRelayMessages).get()) {
      final expected = relayLogicalRecordBytes(
        'ble_relay_messages',
        _messageFieldsFromRow(row),
      );
      if (expected != row.storageBytes) {
        throw const RelayPersistenceException(
          'Stored relay message accounting failed integrity verification.',
        );
      }
      currentBytes += expected;
    }
    for (final row in await database.select(database.bleRelayAttempts).get()) {
      currentBytes += _verifyAttemptStorage(row);
    }
    for (final row in await database.select(database.bleRelayReceipts).get()) {
      currentBytes += _verifyReceiptStorage(row);
    }
    if (currentBytes + deltaBytes < 0 ||
        currentBytes + deltaBytes > maximumPayloadBytes) {
      throw const RelayPersistenceException('Relay storage quota is full.');
    }
  }

  Future<BleRelayMessage?> lookupMessage(String originMessageId) =>
      (database.select(database.bleRelayMessages)
            ..where((table) => table.originMessageId.equals(originMessageId)))
          .getSingleOrNull();
}

DateTime _minimumTime(DateTime left, DateTime right) =>
    left.isBefore(right) ? left.toUtc() : right.toUtc();

bool _sameTime(DateTime left, DateTime right) =>
    left.toUtc().microsecondsSinceEpoch == right.toUtc().microsecondsSinceEpoch;

DateTime _databaseTime(DateTime value) {
  final utc = value.toUtc();
  return DateTime.fromMillisecondsSinceEpoch(
    (utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond) *
        Duration.millisecondsPerSecond,
    isUtc: true,
  );
}

bool _hasLegacySubsecondAccounting(
  BleRelayMessage row,
  int expectedStorageBytes,
) {
  // Drift's default SQLite DateTime mapping persists whole seconds. Builds
  // before this fix accounted the two local timestamps before that precision
  // conversion. A timestamp with microseconds uses three more ISO-8601 bytes
  // than its database round-trip value, so the paired fields differ by six.
  // Only this exact, derivable legacy shape is repairable; every other storage
  // mismatch remains a fail-closed integrity error.
  return row.receivedAt.toUtc().microsecondsSinceEpoch %
              Duration.microsecondsPerSecond ==
          0 &&
      row.persistedAt.toUtc().microsecondsSinceEpoch %
              Duration.microsecondsPerSecond ==
          0 &&
      row.storageBytes == expectedStorageBytes + 6;
}

String _wireTime(DateTime value) => value.toUtc().toIso8601String();

bool _validFinalBinding(BleRelayMessage row) {
  final values = [
    row.finalRecipientKeyId,
    row.finalAuthorizationId,
    row.finalReceiptCorrelationId,
    row.finalRoutePeerDeviceId,
  ];
  // Stage 1.6 has no trusted principal or authenticated transport binding.
  // Any populated final binding is therefore unauthorized and fails closed.
  return values.every((value) => value == null) &&
      row.finalReceiptState == null;
}

Map<String, Object?> _messageFields({
  required String originMessageId,
  required String incidentId,
  required String originKeyId,
  required String originPublicKey,
  required String immutablePayload,
  required String wireEnvelope,
  required String immutableDigest,
  required String originSignature,
  required String authorizationScope,
  required String emergencyType,
  required DateTime createdAt,
  required DateTime expiresAt,
  required DateTime retentionDeadline,
  required int maxHops,
  required int incomingHopCount,
  required String incomingPath,
  required String incomingPeerId,
  required String previousHopKeyId,
  required String processingState,
  required int payloadBytes,
  required DateTime receivedAt,
  required DateTime persistedAt,
  String? finalReceiptState,
  String? finalRecipientKeyId,
  String? finalAuthorizationId,
  String? finalReceiptCorrelationId,
  String? finalRoutePeerDeviceId,
  String? lastError,
}) => {
  'originMessageId': originMessageId,
  'incidentId': incidentId,
  'originKeyId': originKeyId,
  'originPublicKey': originPublicKey,
  'immutablePayload': immutablePayload,
  'wireEnvelope': wireEnvelope,
  'immutableDigest': immutableDigest,
  'originSignature': originSignature,
  'authorizationScope': authorizationScope,
  'emergencyType': emergencyType,
  'createdAt': _wireTime(createdAt),
  'expiresAt': _wireTime(expiresAt),
  'retentionDeadline': _wireTime(retentionDeadline),
  'maxHops': maxHops,
  'incomingHopCount': incomingHopCount,
  'incomingPath': incomingPath,
  'incomingPeerId': incomingPeerId,
  'previousHopKeyId': previousHopKeyId,
  'processingState': processingState,
  'payloadBytes': payloadBytes,
  'receivedAt': _wireTime(receivedAt),
  'persistedAt': _wireTime(persistedAt),
  'finalReceiptState': finalReceiptState,
  'finalRecipientKeyId': finalRecipientKeyId,
  'finalAuthorizationId': finalAuthorizationId,
  'finalReceiptCorrelationId': finalReceiptCorrelationId,
  'finalRoutePeerDeviceId': finalRoutePeerDeviceId,
  'lastError': lastError,
};

Map<String, Object?> _messageFieldsFromRow(BleRelayMessage row) =>
    _messageFields(
      originMessageId: row.originMessageId,
      incidentId: row.incidentId,
      originKeyId: row.originKeyId,
      originPublicKey: row.originPublicKey,
      immutablePayload: row.immutablePayload,
      wireEnvelope: row.wireEnvelope,
      immutableDigest: row.immutableDigest,
      originSignature: row.originSignature,
      authorizationScope: row.authorizationScope,
      emergencyType: row.emergencyType,
      createdAt: row.createdAt,
      expiresAt: row.expiresAt,
      retentionDeadline: row.retentionDeadline,
      maxHops: row.maxHops,
      incomingHopCount: row.incomingHopCount,
      incomingPath: row.incomingPath,
      incomingPeerId: row.incomingPeerId,
      previousHopKeyId: row.previousHopKeyId,
      processingState: row.processingState,
      payloadBytes: row.payloadBytes,
      receivedAt: row.receivedAt,
      persistedAt: row.persistedAt,
      finalReceiptState: row.finalReceiptState,
      finalRecipientKeyId: row.finalRecipientKeyId,
      finalAuthorizationId: row.finalAuthorizationId,
      finalReceiptCorrelationId: row.finalReceiptCorrelationId,
      finalRoutePeerDeviceId: row.finalRoutePeerDeviceId,
      lastError: row.lastError,
    );

Map<String, Object?> _attemptFields({
  required String originMessageId,
  required String nextHopKeyId,
  required String attemptId,
  required String correlationId,
  required String nextHopDeviceId,
  required int outgoingHopCount,
  required String outgoingPath,
  required String state,
  required int retryCount,
  required DateTime createdAt,
  required DateTime updatedAt,
  DateTime? nextRetryAt,
  DateTime? lastAttemptAt,
  String? lastError,
  DateTime? acceptedAt,
}) => {
  'originMessageId': originMessageId,
  'nextHopKeyId': nextHopKeyId,
  'attemptId': attemptId,
  'correlationId': correlationId,
  'nextHopDeviceId': nextHopDeviceId,
  'outgoingHopCount': outgoingHopCount,
  'outgoingPath': outgoingPath,
  'state': state,
  'retryCount': retryCount,
  'nextRetryAt': nextRetryAt == null ? null : _wireTime(nextRetryAt),
  'lastAttemptAt': lastAttemptAt == null ? null : _wireTime(lastAttemptAt),
  'lastError': lastError,
  'createdAt': _wireTime(createdAt),
  'updatedAt': _wireTime(updatedAt),
  'acceptedAt': acceptedAt == null ? null : _wireTime(acceptedAt),
};

Map<String, Object?> _attemptFieldsFromRow(
  BleRelayAttempt row, {
  String? nextHopDeviceId,
  String? state,
  DateTime? updatedAt,
  DateTime? lastAttemptAt,
  DateTime? acceptedAt,
  int? retryCount,
  DateTime? nextRetryAt,
  bool replaceNextRetryAt = false,
  String? lastError,
  bool replaceLastError = false,
}) => _attemptFields(
  originMessageId: row.originMessageId,
  nextHopKeyId: row.nextHopKeyId,
  attemptId: row.attemptId,
  correlationId: row.correlationId,
  nextHopDeviceId: nextHopDeviceId ?? row.nextHopDeviceId,
  outgoingHopCount: row.outgoingHopCount,
  outgoingPath: row.outgoingPath,
  state: state ?? row.state,
  retryCount: retryCount ?? row.retryCount,
  nextRetryAt: replaceNextRetryAt ? nextRetryAt : row.nextRetryAt,
  lastAttemptAt: lastAttemptAt ?? row.lastAttemptAt,
  lastError: replaceLastError ? lastError : row.lastError,
  createdAt: row.createdAt,
  updatedAt: updatedAt ?? row.updatedAt,
  acceptedAt: acceptedAt ?? row.acceptedAt,
);

int _verifyAttemptStorage(BleRelayAttempt row) {
  final expected = relayLogicalRecordBytes(
    'ble_relay_attempts',
    _attemptFieldsFromRow(row),
  );
  if (expected != row.storageBytes) {
    throw const RelayPersistenceException(
      'Stored relay attempt accounting failed integrity verification.',
    );
  }
  return expected;
}

Map<String, Object?> _receiptFields({
  required String semanticKey,
  required String receiptId,
  required String receiptType,
  required String originMessageId,
  required String incidentId,
  required String immutableDigest,
  required String signerKeyId,
  required String signerPublicKey,
  required String correlationId,
  required String? attemptId,
  required String? finalAuthorizationId,
  required String sourcePeerDeviceId,
  required String? previousHopKeyId,
  required String? previousHopDeviceId,
  required String payload,
  required String signature,
  required String state,
  required DateTime createdAt,
  required DateTime expiresAt,
  required DateTime updatedAt,
}) => {
  'semanticKey': semanticKey,
  'receiptId': receiptId,
  'receiptType': receiptType,
  'originMessageId': originMessageId,
  'incidentId': incidentId,
  'immutableDigest': immutableDigest,
  'signerKeyId': signerKeyId,
  'signerPublicKey': signerPublicKey,
  'correlationId': correlationId,
  'attemptId': attemptId,
  'finalAuthorizationId': finalAuthorizationId,
  'sourcePeerDeviceId': sourcePeerDeviceId,
  'previousHopKeyId': previousHopKeyId,
  'previousHopDeviceId': previousHopDeviceId,
  'payload': payload,
  'signature': signature,
  'state': state,
  'createdAt': _wireTime(createdAt),
  'expiresAt': _wireTime(expiresAt),
  'updatedAt': _wireTime(updatedAt),
};

Map<String, Object?> _receiptFieldsFromRow(BleRelayReceipt row) =>
    _receiptFields(
      semanticKey: row.semanticKey,
      receiptId: row.receiptId,
      receiptType: row.receiptType,
      originMessageId: row.originMessageId,
      incidentId: row.incidentId,
      immutableDigest: row.immutableDigest,
      signerKeyId: row.signerKeyId,
      signerPublicKey: row.signerPublicKey,
      correlationId: row.correlationId,
      attemptId: row.attemptId,
      finalAuthorizationId: row.finalAuthorizationId,
      sourcePeerDeviceId: row.sourcePeerDeviceId,
      previousHopKeyId: row.previousHopKeyId,
      previousHopDeviceId: row.previousHopDeviceId,
      payload: row.payload,
      signature: row.signature,
      state: row.state,
      createdAt: row.createdAt,
      expiresAt: row.expiresAt,
      updatedAt: row.updatedAt,
    );

int _verifyReceiptStorage(BleRelayReceipt row) {
  final expected = relayLogicalRecordBytes(
    'ble_relay_receipts',
    _receiptFieldsFromRow(row),
  );
  if (expected != row.storageBytes) {
    throw const RelayPersistenceException(
      'Stored relay receipt accounting failed integrity verification.',
    );
  }
  return expected;
}

class RelayPersistenceException implements Exception {
  const RelayPersistenceException(this.message);
  final String message;

  @override
  String toString() => 'RelayPersistenceException: $message';
}
