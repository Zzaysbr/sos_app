import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/relay_envelope.dart';
import '../domain/rescue_response_envelope.dart';
import 'relay_repository.dart';
import 'relay_key_store.dart';

enum RescueResponseDeliveryState {
  queued,
  forwarded,
  delivered,
  failed,
  expired,
}

/// Durable, owner-scoped persistence for reverse rescue responses.
///
/// This repository intentionally does not pick a BLE peer. A job is created
/// only after the caller has a validated key/session binding; the coordinator
/// remains responsible for proving that the peer is currently reachable.
class RescueResponseRepository {
  RescueResponseRepository(this.database, {required this.ownerId, this.onLog});

  static const maximumAttempts = 5;
  static const retryBase = Duration(seconds: 30);

  final AppDatabase database;
  final String ownerId;
  final void Function(String message)? onLog;

  Future<RescueResponseOutboxData?> findOutbox(String messageId) {
    return (database.select(database.rescueResponseOutbox)..where(
          (row) =>
              row.ownerId.equals(ownerId) & row.messageId.equals(messageId),
        ))
        .getSingleOrNull();
  }

  Future<List<RescueResponseOutboxData>> listDueOutbox({DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return (database.select(database.rescueResponseOutbox)
          ..where(
            (row) =>
                row.ownerId.equals(ownerId) &
                row.expiresAt.isBiggerThanValue(timestamp) &
                row.state.isNotIn(const ['delivered', 'expired']) &
                row.retryCount.isSmallerThanValue(maximumAttempts) &
                (row.nextRetryAt.isNull() |
                    row.nextRetryAt.isSmallerOrEqualValue(timestamp)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.updatedAt)]))
        .get();
  }

  Future<RescueResponseInboxData?> findInbox(String messageId) {
    return (database.select(database.rescueResponseInbox)..where(
          (row) =>
              row.ownerId.equals(ownerId) & row.messageId.equals(messageId),
        ))
        .getSingleOrNull();
  }

  Future<RescueResponseOutboxData> enqueueAck({
    required RescueResponseAckEnvelope ack,
    required RescueResponseEnvelope response,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final existing = await findOutbox(ack.body.ackId);
    if (existing != null) return existing;
    ack.validate(now: timestamp);
    await database
        .into(database.rescueResponseOutbox)
        .insert(
          RescueResponseOutboxCompanion.insert(
            ownerId: ownerId,
            messageId: ack.body.ackId,
            incidentId: ack.body.incidentId,
            originMessageId: ack.body.originMessageId,
            originKeyId: ack.body.originKeyId,
            responderKeyId: ack.body.recipientKeyId,
            payload: ack.toCanonicalWire(),
            state: RescueResponseDeliveryState.queued.name,
            expiresAt: ack.body.expiresAt,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final row = (await findOutbox(ack.body.ackId))!;
    onLog?.call(
      'rescue_ack_enqueued incident=${ack.body.incidentId} '
      'response=${ack.body.responseMessageId}',
    );
    return row;
  }

  /// Signs and durably queues one response. The caller must provide a
  /// previously authenticated route binding; this method never derives trust
  /// from a BLE address or display name.
  Future<RescueResponseOutboxData> signAndEnqueueOffer({
    required RelayOriginBody origin,
    required RelaySigningIdentity responder,
    required String sessionBinding,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final crypto = RelayCryptography();
    final responseBody = RescueResponseBody(
      messageId: 'rescue:${origin.originMessageId}:${responder.keyId}',
      incidentId: origin.incidentId,
      originMessageId: origin.originMessageId,
      originKeyId: origin.originKeyId,
      originDigest: await crypto.immutableDigest(origin),
      responderKeyId: responder.keyId,
      responderPublicKey: base64UrlEncode(responder.publicKey),
      sessionBinding: sessionBinding,
      createdAt: timestamp,
      expiresAt:
          timestamp.add(const Duration(minutes: 15)).isBefore(origin.expiresAt)
          ? timestamp.add(const Duration(minutes: 15))
          : origin.expiresAt,
    );
    final envelope = RescueResponseEnvelope(
      body: responseBody,
      signature: await crypto.signRescueResponse(
        responseBody,
        responder.keyPair,
      ),
    );
    final row = await enqueueOffer(
      envelope: envelope,
      origin: origin,
      now: timestamp,
    );
    onLog?.call(
      'rescue_offer_enqueued incident=${origin.incidentId} '
      'response=${row.messageId} hop=0',
    );
    return row;
  }

  Stream<List<RescueResponseInboxData>> watchVerifiedOffersForIncident(
    String incidentId,
  ) {
    return (database.select(database.rescueResponseInbox)
          ..where(
            (row) =>
                row.ownerId.equals(ownerId) &
                row.incidentId.equals(incidentId) &
                row.state.equals('verified'),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.receivedAt)]))
        .watch();
  }

  Future<({String keyId, String publicKey})?>
  verifiedResponderBindingForIncident(String incidentId) async {
    final row =
        await (database.select(database.rescueResponseInbox)
              ..where(
                (table) =>
                    table.ownerId.equals(ownerId) &
                    table.incidentId.equals(incidentId) &
                    table.state.equals('verified'),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.receivedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    final envelope = RescueResponseEnvelope.fromCanonicalWire(row.payload);
    return (
      keyId: envelope.body.responderKeyId,
      publicKey: envelope.body.responderPublicKey,
    );
  }

  Stream<List<RescueResponseOutboxData>> watchOutboxForIncident(
    String incidentId,
  ) {
    return (database.select(database.rescueResponseOutbox)
          ..where(
            (row) =>
                row.ownerId.equals(ownerId) & row.incidentId.equals(incidentId),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
        .watch();
  }

  Future<RescueResponseOutboxData> enqueueOffer({
    required RescueResponseEnvelope envelope,
    required RelayOriginBody origin,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    if (!await RelayCryptography().verifyRescueResponseForOrigin(
      envelope,
      origin,
      now: timestamp,
    )) {
      throw const RelayPersistenceException(
        'Rescue response failed origin binding or signature validation.',
      );
    }
    final existing = await findOutbox(envelope.body.messageId);
    if (existing != null) return existing;
    await database
        .into(database.rescueResponseOutbox)
        .insert(
          RescueResponseOutboxCompanion.insert(
            ownerId: ownerId,
            messageId: envelope.body.messageId,
            incidentId: envelope.body.incidentId,
            originMessageId: envelope.body.originMessageId,
            originKeyId: envelope.body.originKeyId,
            responderKeyId: envelope.body.responderKeyId,
            payload: envelope.toCanonicalWire(),
            state: RescueResponseDeliveryState.queued.name,
            expiresAt: envelope.body.expiresAt,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await findOutbox(envelope.body.messageId))!;
  }

  Future<bool> queueAttempt({
    required String messageId,
    required String nextHopKeyId,
    required String nextHopDeviceId,
    required String sessionBinding,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return database.transaction(() async {
      final outbox = await findOutbox(messageId);
      if (outbox == null) {
        throw const RelayPersistenceException('Unknown response.');
      }
      if (outbox.state == 'delivered' ||
          outbox.state == 'expired' ||
          !outbox.expiresAt.isAfter(timestamp) ||
          outbox.retryCount >= maximumAttempts ||
          (outbox.nextRetryAt?.isAfter(timestamp) ?? false)) {
        return false;
      }
      final claimed =
          await (database.update(database.rescueResponseOutbox)..where(
                (row) =>
                    row.ownerId.equals(ownerId) &
                    row.messageId.equals(messageId) &
                    row.retryCount.equals(outbox.retryCount) &
                    row.state.isNotIn(const ['delivered', 'expired']),
              ))
              .write(
                RescueResponseOutboxCompanion(
                  retryCount: Value(outbox.retryCount + 1),
                  nextRetryAt: Value(
                    timestamp.add(_retryDelay(outbox.retryCount + 1)),
                  ),
                  updatedAt: Value(timestamp),
                ),
              );
      if (claimed != 1) return false;
      await database
          .into(database.rescueResponseJobs)
          .insert(
            RescueResponseJobsCompanion.insert(
              ownerId: ownerId,
              responseMessageId: messageId,
              nextHopKeyId: nextHopKeyId,
              nextHopDeviceId: nextHopDeviceId,
              sessionBinding: sessionBinding,
              state: RescueResponseDeliveryState.queued.name,
              retryCount: Value(outbox.retryCount + 1),
              nextRetryAt: Value(
                timestamp.add(_retryDelay(outbox.retryCount + 1)),
              ),
              lastAttemptAt: Value(timestamp),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
            mode: InsertMode.insertOrReplace,
          );
      return true;
    });
  }

  Duration _retryDelay(int attempts) => Duration(
    seconds: retryBase.inSeconds * (1 << (attempts - 1).clamp(0, 4)),
  );

  Future<bool> recordIncoming({
    required RescueResponseEnvelope envelope,
    required RelayOriginBody origin,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    if (!await RelayCryptography().verifyRescueResponseForOrigin(
      envelope,
      origin,
      now: timestamp,
    )) {
      return false;
    }
    final existing =
        await (database.select(database.rescueResponseInbox)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.messageId.equals(envelope.body.messageId),
            ))
            .getSingleOrNull();
    if (existing != null) return false;
    final digest = await RelayCryptography().immutableDigest(origin);
    final inserted = await database
        .into(database.rescueResponseInbox)
        .insert(
          RescueResponseInboxCompanion.insert(
            ownerId: ownerId,
            messageId: envelope.body.messageId,
            incidentId: envelope.body.incidentId,
            originMessageId: envelope.body.originMessageId,
            responderKeyId: envelope.body.responderKeyId,
            immutableDigest: digest,
            payload: envelope.toCanonicalWire(),
            state: 'verified',
            receivedAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted > 0;
  }

  Future<bool> markReplaySeen({
    required String messageId,
    required String immutableDigest,
    required DateTime expiresAt,
    DateTime? now,
  }) async {
    final existing =
        await (database.select(database.rescueResponseReplay)..where(
              (row) =>
                  row.ownerId.equals(ownerId) & row.messageId.equals(messageId),
            ))
            .getSingleOrNull();
    if (existing != null) return false;
    final inserted = await database
        .into(database.rescueResponseReplay)
        .insert(
          RescueResponseReplayCompanion.insert(
            ownerId: ownerId,
            messageId: messageId,
            immutableDigest: immutableDigest,
            firstSeenAt: (now ?? DateTime.now()).toUtc(),
            expiresAt: expiresAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted > 0;
  }

  Future<bool> applyFinalAck({
    required RescueResponseAckEnvelope ack,
    required RescueResponseEnvelope response,
    required RelayOriginBody origin,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    if (!await RelayCryptography().verifyRescueResponseAckForResponse(
      ack,
      response,
      origin,
      now: timestamp,
    )) {
      return false;
    }
    final updated =
        await (database.update(database.rescueResponseOutbox)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.messageId.equals(response.body.messageId) &
                  row.expiresAt.isBiggerThanValue(timestamp),
            ))
            .write(
              RescueResponseOutboxCompanion(
                state: Value(RescueResponseDeliveryState.delivered.name),
                finalAckAt: Value(timestamp),
                updatedAt: Value(timestamp),
              ),
            );
    return updated == 1;
  }

  Future<bool> markState(
    String messageId,
    RescueResponseDeliveryState state, {
    DateTime? now,
    String? error,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final existing = await findOutbox(messageId);
    if (existing == null) return false;
    final updated =
        await (database.update(database.rescueResponseOutbox)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.messageId.equals(messageId) &
                  row.state.isNotIn(const ['delivered', 'expired']),
            ))
            .write(
              RescueResponseOutboxCompanion(
                state: Value(state.name),
                updatedAt: Value(timestamp),
                nextRetryAt: Value(
                  timestamp.add(
                    _retryDelay(existing.retryCount.clamp(1, maximumAttempts)),
                  ),
                ),
                lastError: Value(error),
              ),
            );
    return updated == 1;
  }
}
