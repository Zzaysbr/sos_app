import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/ble_delivery_state.dart';
import 'ble_protocol.dart';
import '../domain/sos_ble_envelope.dart';
import '../domain/location_ble_envelope.dart';

class BlePeerMismatchException extends BleDeliveryStateException {
  const BlePeerMismatchException()
    : super('SOS delivery does not match the recorded transport peer.');
}

class BleDeliveryRepository {
  BleDeliveryRepository(this._database);

  final AppDatabase _database;

  Future<BleOutboxData> enqueueOutbox(
    SosBleEnvelope envelope, {
    String? destinationId,
    DateTime? now,
  }) async {
    _requireOutbound(envelope);
    final payload = jsonEncode(envelope.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();
    final normalizedDestination = destinationId?.trim();
    final storedDestination =
        normalizedDestination == null || normalizedDestination.isEmpty
        ? null
        : normalizedDestination;

    return _database.transaction(() async {
      await _database
          .into(_database.bleOutbox)
          .insert(
            BleOutboxCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              destinationId: Value(storedDestination),
              schemaVersion: SosBleEnvelope.schemaVersion,
              payload: payload,
              state: BleOutboxState.queued.wireValue,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final row = await lookupOutbox(envelope.messageId);
      if (row == null) {
        throw const BleDeliveryStateException('Unable to enqueue BLE message.');
      }
      if (row.payload != payload || row.sosId != envelope.sosId) {
        throw const BleDeliveryStateException(
          'messageId is already used for a different SOS payload.',
        );
      }
      return row;
    });
  }

  /// Enqueues one explicit-recipient location update. Older queued location
  /// updates for the same SOS are discarded so stale fixes cannot grow the
  /// durable queue or be displayed as current.
  Future<BleOutboxData> enqueueLocationOutbox(
    LocationBleEnvelope envelope, {
    required String destinationId,
    String? expectedRecipientId,
    DateTime? now,
  }) async {
    final destination = destinationId.trim();
    if (destination.isEmpty ||
        (expectedRecipientId ?? destination) != envelope.recipientId) {
      throw const BleDeliveryStateException(
        'Location recipient and BLE destination must match.',
      );
    }
    final payload = jsonEncode(envelope.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();
    envelope.validate(now: timestamp);
    return _database.transaction(() async {
      final existing = await (_database.select(
        _database.bleOutbox,
      )..where((table) => table.sosId.equals(envelope.sosId))).get();
      for (final row in existing) {
        if (row.messageId == envelope.messageId ||
            !_isLocationUpdate(row.payload) ||
            !(row.state == BleOutboxState.queued.wireValue ||
                row.state == BleOutboxState.failed.wireValue)) {
          continue;
        }
        if (row.destinationId == destination) {
          await (_database.delete(
            _database.bleOutbox,
          )..where((table) => table.messageId.equals(row.messageId))).go();
        } else {
          await (_database.update(_database.bleOutbox)..where(
                (table) =>
                    table.messageId.equals(row.messageId) &
                    table.state.equals(row.state),
              ))
              .write(
                BleOutboxCompanion(
                  state: Value(BleOutboxState.expired.wireValue),
                  nextRetryAt: const Value(null),
                  lastError: const Value(
                    'Recipient changed; previous location update was stopped.',
                  ),
                  updatedAt: Value(timestamp),
                ),
              );
        }
      }
      await _database
          .into(_database.bleOutbox)
          .insert(
            BleOutboxCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              destinationId: Value(destination),
              schemaVersion: LocationBleEnvelope.schemaVersion,
              payload: payload,
              state: BleOutboxState.queued.wireValue,
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final row = await lookupOutbox(envelope.messageId);
      if (row == null ||
          row.payload != payload ||
          row.destinationId != destination) {
        throw const BleDeliveryStateException(
          'messageId is already used for a different location payload.',
        );
      }
      return row;
    });
  }

  Future<BleOutboxData?> lookupOutbox(String messageId) {
    return (_database.select(
      _database.bleOutbox,
    )..where((table) => table.messageId.equals(messageId))).getSingleOrNull();
  }

  /// Stops pending location updates for an SOS without touching SOS or Chat
  /// deliveries. A stopped share must not resume from a queued retry later.
  Future<int> expireLocationOutbox(
    String sosId, {
    String reason = 'Location sharing stopped.',
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      final rows = await (_database.select(
        _database.bleOutbox,
      )..where((table) => table.sosId.equals(sosId))).get();
      var changed = 0;
      for (final row in rows) {
        if (!_isLocationUpdate(row.payload)) continue;
        final state = BleOutboxState.parse(row.state);
        if (state == BleOutboxState.acknowledged ||
            state == BleOutboxState.expired) {
          continue;
        }
        changed +=
            await (_database.update(_database.bleOutbox)..where(
                  (table) =>
                      table.messageId.equals(row.messageId) &
                      table.state.equals(row.state),
                ))
                .write(
                  BleOutboxCompanion(
                    state: Value(BleOutboxState.expired.wireValue),
                    nextRetryAt: const Value(null),
                    lastError: Value(reason),
                    updatedAt: Value(timestamp),
                  ),
                );
      }
      return changed;
    });
  }

  /// Watches the persisted delivery row for an SOS. The delivery envelope has
  /// a stable message id, so this stream remains valid across app restarts.
  Stream<BleOutboxData?> watchDeliveryForSos(String sosId) {
    return (_database.select(_database.bleOutbox)
          ..where((table) => table.sosId.equals(sosId))
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// SOS identifiers that were durably received from a BLE peer.
  ///
  /// Callers must still intersect these IDs with the active repository owner
  /// scope. Inbox membership describes transport origin, not authorization.
  Stream<Set<String>> watchInboundSosIds() =>
      _database.select(_database.bleInbox).watch().map(_inboundSosIds);

  Future<Set<String>> listInboundSosIds() async =>
      _inboundSosIds(await _database.select(_database.bleInbox).get());

  Set<String> _inboundSosIds(List<BleInboxData> rows) {
    final ids = <String>{};
    for (final row in rows) {
      try {
        final value = jsonDecode(row.payload);
        if (value is Map<String, dynamic> &&
            value['kind'] == SosBleMessageKind.delivery.wireValue) {
          ids.add(row.sosId);
        }
      } on FormatException {
        // Ignore unrelated or malformed legacy inbox rows. The persisted SOS
        // owner scope remains the authorization boundary.
      }
    }
    return ids;
  }

  /// Watches the newest location update for an SOS without confusing it with
  /// the primary SOS delivery row.
  Stream<BleOutboxData?> watchLocationDeliveryForSos(String sosId) {
    return (_database.select(_database.bleOutbox)
          ..where((table) => table.sosId.equals(sosId))
          ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]))
        .watch()
        .map((rows) {
          for (final row in rows) {
            if (_isLocationUpdate(row.payload)) return row;
          }
          return null;
        });
  }

  /// Recreates the durable SOS delivery row when local SOS persistence
  /// succeeded but the BLE enqueue callback failed. A missing destination is
  /// intentionally retained as `queued`; routing must be assigned explicitly.
  /// The outbox primary key and insert-or-ignore semantics make repeated or
  /// concurrent reconciliation idempotent.
  Future<int> reconcileMissingSosOutbox({
    required String ownerId,
    DateTime? now,
    int batchSize = 100,
  }) async {
    if (batchSize <= 0) return 0;
    final timestamp = (now ?? DateTime.now()).toUtc();
    var recovered = 0;
    String? afterId;
    while (true) {
      final query = _database.select(_database.sosMessages)
        ..where((table) {
          final ownerAndStatus =
              table.ownerId.equals(ownerId) & table.status.equals('active');
          return afterId == null
              ? ownerAndStatus
              : ownerAndStatus & table.id.isBiggerThanValue(afterId);
        })
        ..orderBy([(table) => OrderingTerm.asc(table.id)])
        ..limit(batchSize);
      final sosRows = await query.get();
      if (sosRows.isEmpty) break;
      for (final sos in sosRows) {
        final existing = await (_database.select(
          _database.bleOutbox,
        )..where((table) => table.sosId.equals(sos.id))).get();
        var hasDelivery = false;
        for (final row in existing) {
          try {
            final decoded = jsonDecode(row.payload);
            if (decoded is Map &&
                SosBleEnvelope.fromJson(Map<String, Object?>.from(decoded))
                        .kind ==
                    SosBleMessageKind.delivery) {
              hasDelivery = true;
              break;
            }
          } on Object {
            // A malformed unrelated row must not prevent recovery of the SOS
            // delivery. Its existing state remains untouched for diagnosis.
          }
        }
        if (hasDelivery) continue;

        final envelope = SosBleEnvelope.fromSosMessage(
          sos,
          messageId: 'sos:${sos.id}:delivery:v1',
        );
        await enqueueOutbox(envelope, now: timestamp);
        recovered++;
      }
      afterId = sosRows.last.id;
      if (sosRows.length < batchSize) break;
    }
    return recovered;
  }

  /// Returns the last transport peer that delivered an SOS for this incident.
  ///
  /// This is a BLE device identifier used for reply routing only. It is not
  /// treated as an authenticated user identity and may become stale if the
  /// peer changes its platform identifier.
  Future<String?> lookupReplyDestination(String sosId) async {
    final rows =
        await (_database.select(_database.bleInbox)
              ..where(
                (t) => t.sosId.equals(sosId) & t.senderDeviceId.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .get();
    for (final row in rows) {
      if (_isSosDelivery(row.payload)) {
        final peer = row.senderDeviceId?.trim();
        if (peer != null && peer.isNotEmpty) return peer;
      }
    }
    return null;
  }

  Future<String?> lookupIncidentDestination(String sosId) async {
    final reply = await lookupReplyDestination(sosId);
    if (reply != null) return reply;
    final rows =
        await (_database.select(_database.bleOutbox)
              ..where(
                (t) => t.sosId.equals(sosId) & t.destinationId.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();
    for (final row in rows) {
      if (_isSosDelivery(row.payload)) {
        return row.destinationId;
      }
    }
    return null;
  }

  /// Returns the stable installation identity that was observed on a
  /// validated SOS delivery or its application ACK. Chat and Location rows
  /// cannot establish this association by themselves.
  Future<String?> lookupIncidentPeerIdentity(String sosId) async {
    final rows =
        await (_database.select(_database.bleInbox)
              ..where((t) => t.sosId.equals(sosId))
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .get();
    for (final row in rows) {
      try {
        final value = jsonDecode(row.payload);
        if (value is! Map ||
            (value['kind'] != SosBleMessageKind.delivery.wireValue &&
                value['kind'] != SosBleMessageKind.acknowledgement.wireValue)) {
          continue;
        }
        final identity = value['senderDeviceId'];
        if (identity is String && identity.trim().isNotEmpty) {
          return identity.trim();
        }
      } on Object {
        // Malformed historical rows are not an identity source.
      }
    }
    return null;
  }

  bool _isSosDelivery(String payload) {
    try {
      final value = jsonDecode(payload);
      return value is Map && value['kind'] == 'sos.delivery';
    } on FormatException {
      return false;
    }
  }

  /// Route established by SOS delivery/explicit SOS recipient only. Location
  /// packets must never be able to establish their own authorization route.
  Future<bool> isIncidentPeer(
    String sosId,
    String peer, {
    String? peerIdentity,
  }) async {
    final incoming =
        await (_database.select(_database.bleInbox)..where(
              (t) => t.sosId.equals(sosId) & t.senderDeviceId.equals(peer),
            ))
            .get();
    final outgoing =
        await (_database.select(_database.bleOutbox)..where(
              (t) => t.sosId.equals(sosId) & t.destinationId.equals(peer),
            ))
            .get();
    for (final payload in [
      ...incoming.map((r) => r.payload),
      ...outgoing.map((r) => r.payload),
    ]) {
      if (_isSosDelivery(payload)) return true;
    }
    final expectedIdentity = await lookupIncidentPeerIdentity(sosId);
    return expectedIdentity != null &&
        peerIdentity != null &&
        expectedIdentity == peerIdentity.trim();
  }

  /// Moves a pending row to a newly observed native route only after the
  /// coordinator has matched that route to the incident's persisted stable
  /// installation identity. Message identity and payload remain unchanged.
  Future<BleOutboxData> reassignPendingDestination(
    String messageId, {
    required String expectedDestinationId,
    required String destinationId,
    DateTime? now,
  }) async {
    final oldDestination = expectedDestinationId.trim();
    final newDestination = destinationId.trim();
    if (oldDestination.isEmpty || newDestination.isEmpty) {
      throw const BleDeliveryStateException(
        'BLE destinations must not be empty.',
      );
    }
    final timestamp = (now ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      final current = await lookupOutbox(messageId);
      if (current == null) {
        throw const BleDeliveryStateException('BLE outbox message not found.');
      }
      if (current.destinationId == newDestination) return current;
      final state = BleOutboxState.parse(current.state);
      if (current.destinationId != oldDestination ||
          (state != BleOutboxState.queued && state != BleOutboxState.failed)) {
        throw const BleDeliveryStateException(
          'Only the expected queued or failed BLE route can be reassigned.',
        );
      }
      final changed =
          await (_database.update(_database.bleOutbox)..where(
                (t) =>
                    t.messageId.equals(messageId) &
                    t.destinationId.equals(oldDestination) &
                    t.state.equals(current.state),
              ))
              .write(
                BleOutboxCompanion(
                  destinationId: Value(newDestination),
                  state: Value(BleOutboxState.queued.wireValue),
                  nextRetryAt: const Value(null),
                  lastError: const Value(null),
                  updatedAt: Value(timestamp),
                ),
              );
      if (changed != 1) {
        throw const BleDeliveryStateException(
          'BLE destination changed concurrently.',
        );
      }
      return (await lookupOutbox(messageId))!;
    });
  }

  Future<BleOutboxData> assignDestinationIfMissing(
    String messageId,
    String destinationId, {
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final normalizedDestination = destinationId.trim();
    if (normalizedDestination.isEmpty) {
      throw const BleDeliveryStateException(
        'A BLE destination must not be empty.',
      );
    }
    final changed =
        await (_database.update(_database.bleOutbox)..where(
              (table) =>
                  table.messageId.equals(messageId) &
                  (table.state.equals(BleOutboxState.queued.wireValue) |
                      table.state.equals(BleOutboxState.failed.wireValue)) &
                  (table.destinationId.isNull() |
                      table.destinationId.equals('')),
            ))
            .write(
              BleOutboxCompanion(
                destinationId: Value(normalizedDestination),
                updatedAt: Value(timestamp),
              ),
            );
    if (changed != 1) {
      final existing = await lookupOutbox(messageId);
      if (existing == null) {
        throw const BleDeliveryStateException('BLE outbox message not found.');
      }
      return existing;
    }
    return (await lookupOutbox(messageId))!;
  }

  Expression<bool> _outboxOwnerScope($BleOutboxTable table, String? ownerId) {
    if (ownerId == null) return const Constant(true);
    final incidents = _database.selectOnly(_database.sosMessages)
      ..addColumns([_database.sosMessages.id])
      ..where(_database.sosMessages.ownerId.equals(ownerId));
    final chats = _database.selectOnly(_database.chatMessages)
      ..addColumns([_database.chatMessages.messageId])
      ..where(_database.chatMessages.ownerId.equals(ownerId));
    return table.sosId.isInQuery(incidents) | table.messageId.isInQuery(chats);
  }

  Future<List<BleOutboxData>> dueOutbox({
    DateTime? now,
    int limit = 50,
    String? ownerId,
  }) async {
    if (limit <= 0) return const [];
    final timestamp = (now ?? DateTime.now()).toUtc();
    return (_database.select(_database.bleOutbox)
          ..where(
            (table) =>
                _outboxOwnerScope(table, ownerId) &
                table.destinationId.isNotNull() &
                table.destinationId.isNotValue('') &
                (table.state.equals(BleOutboxState.queued.wireValue) |
                    (table.state.equals(BleOutboxState.failed.wireValue) &
                        table.nextRetryAt.isSmallerOrEqualValue(timestamp))),
          )
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<BleOutboxData> transitionOutboxState(
    String messageId,
    BleOutboxState nextState, {
    DateTime? now,
    DateTime? nextRetryAt,
    String? error,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();

    return _database.transaction(() async {
      final current = await lookupOutbox(messageId);
      if (current == null) {
        throw const BleDeliveryStateException('BLE outbox message not found.');
      }
      final currentState = BleOutboxState.parse(current.state);
      if (!_legalTransitions[currentState]!.contains(nextState)) {
        throw BleDeliveryStateException(
          'Invalid BLE outbox transition: ${currentState.wireValue} '
          'to ${nextState.wireValue}.',
        );
      }

      final update = BleOutboxCompanion(
        state: Value(nextState.wireValue),
        retryCount: nextState == BleOutboxState.sending
            ? Value(current.retryCount + 1)
            : const Value.absent(),
        nextRetryAt: Value(nextRetryAt),
        lastAttemptAt: nextState == BleOutboxState.sending
            ? Value(timestamp)
            : const Value.absent(),
        lastError: Value(error),
        updatedAt: Value(timestamp),
        acknowledgedAt: nextState == BleOutboxState.acknowledged
            ? Value(timestamp)
            : const Value.absent(),
      );
      final changed =
          await (_database.update(_database.bleOutbox)..where(
                (table) =>
                    table.messageId.equals(messageId) &
                    table.state.equals(current.state),
              ))
              .write(update);
      if (changed != 1) {
        throw const BleDeliveryStateException(
          'BLE outbox state changed concurrently.',
        );
      }
      return (await lookupOutbox(messageId))!;
    });
  }

  /// Atomically claims a queued/retryable row for one transmission worker.
  /// A null result means another worker already claimed it or the retry is not
  /// due; callers must not mutate that row in that case.
  Future<BleOutboxData?> claimOutboxForSending(
    String messageId, {
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      final current = await lookupOutbox(messageId);
      if (current == null) return null;
      final state = BleOutboxState.parse(current.state);
      final retryDue =
          current.nextRetryAt == null ||
          !current.nextRetryAt!.toUtc().isAfter(timestamp);
      if ((state != BleOutboxState.queued && state != BleOutboxState.failed) ||
          !retryDue) {
        return null;
      }
      final changed =
          await (_database.update(_database.bleOutbox)..where(
                (table) =>
                    table.messageId.equals(messageId) &
                    table.state.equals(current.state),
              ))
              .write(
                BleOutboxCompanion(
                  state: Value(BleOutboxState.sending.wireValue),
                  retryCount: Value(current.retryCount + 1),
                  nextRetryAt: const Value(null),
                  lastAttemptAt: Value(timestamp),
                  lastError: const Value(null),
                  updatedAt: Value(timestamp),
                ),
              );
      if (changed != 1) return null;
      return lookupOutbox(messageId);
    });
  }

  Future<BleOutboxData> recordAcknowledgement(
    SosBleEnvelope acknowledgement, {
    String? sourceDeviceId,
    DateTime? now,
  }) async {
    if ((acknowledgement.kind != SosBleMessageKind.acknowledgement &&
            acknowledgement.kind != SosBleMessageKind.chatAcknowledgement) ||
        acknowledgement.ackFor == null ||
        acknowledgement.ackStatus == null) {
      throw const BleDeliveryStateException('Expected a valid BLE ACK.');
    }
    final timestamp = (now ?? DateTime.now()).toUtc();

    return _database.transaction(() async {
      final current = await lookupOutbox(acknowledgement.ackFor!);
      if (current == null || current.sosId != acknowledgement.sosId) {
        throw const BleDeliveryStateException(
          'Acknowledgement does not match a BLE outbox message.',
        );
      }
      if (sourceDeviceId != null) {
        final expectedPeer = current.destinationId?.trim();
        final actualPeer = sourceDeviceId.trim();
        if (expectedPeer == null ||
            expectedPeer.isEmpty ||
            actualPeer.isEmpty ||
            expectedPeer != actualPeer) {
          throw const BleDeliveryStateException(
            'Acknowledgement came from an unexpected BLE peer.',
          );
        }
      }
      final outboundKind = _decodeEnvelopeKind(current.payload);
      final isChatAck =
          acknowledgement.kind == SosBleMessageKind.chatAcknowledgement;
      final expectedOutboundKind = isChatAck
          ? SosBleMessageKind.chatMessage
          : SosBleMessageKind.delivery;
      if (outboundKind != expectedOutboundKind) {
        throw const BleDeliveryStateException(
          'Acknowledgement kind does not match the BLE outbox message.',
        );
      }
      final state = BleOutboxState.parse(current.state);
      if (state == BleOutboxState.acknowledged) return current;
      if (!_acknowledgementStates.contains(state)) {
        throw BleDeliveryStateException(
          'Cannot acknowledge BLE message in ${state.wireValue} state.',
        );
      }

      final persisted = acknowledgement.ackStatus == SosBleAckStatus.persisted;
      final next = persisted
          ? BleOutboxState.acknowledged
          : BleOutboxState.failed;
      final changed =
          await (_database.update(_database.bleOutbox)..where(
                (table) =>
                    table.messageId.equals(current.messageId) &
                    table.state.equals(current.state),
              ))
              .write(
                BleOutboxCompanion(
                  state: Value(next.wireValue),
                  lastError: Value(acknowledgement.error),
                  nextRetryAt: const Value(null),
                  acknowledgedAt: persisted
                      ? Value(timestamp)
                      : const Value.absent(),
                  updatedAt: Value(timestamp),
                ),
              );
      if (changed != 1) {
        throw const BleDeliveryStateException(
          'BLE acknowledgement raced with another state update.',
        );
      }
      return (await lookupOutbox(current.messageId))!;
    });
  }

  /// Retains the validated SOS ACK route so a later connection can be matched
  /// by installation identity even when the platform-native peer ID rotates.
  Future<BleInboxData> persistInboundSosAcknowledgement(
    SosBleEnvelope acknowledgement, {
    required String sourceDeviceId,
    DateTime? now,
  }) async {
    if (acknowledgement.kind != SosBleMessageKind.acknowledgement ||
        acknowledgement.senderDeviceId?.trim().isEmpty != false) {
      throw const BleDeliveryStateException(
        'A routed SOS acknowledgement requires a sender identity.',
      );
    }
    final source = sourceDeviceId.trim();
    if (source.isEmpty) {
      throw const BleDeliveryStateException(
        'A routed SOS acknowledgement requires a native source.',
      );
    }
    final payload = jsonEncode(acknowledgement.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      await _database
          .into(_database.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: acknowledgement.messageId,
              sosId: acknowledgement.sosId,
              senderDeviceId: Value(source),
              schemaVersion: SosBleEnvelope.schemaVersion,
              payload: payload,
              processingState: BleInboxState.persisted.wireValue,
              receivedAt: timestamp,
              persistedAt: Value(timestamp),
              acknowledgementStatus: Value(
                acknowledgement.ackStatus == SosBleAckStatus.persisted
                    ? BleAcknowledgementStatus.persisted.wireValue
                    : BleAcknowledgementStatus.rejected.wireValue,
              ),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final row = await lookupInbox(acknowledgement.messageId);
      if (row == null ||
          row.sosId != acknowledgement.sosId ||
          row.senderDeviceId != source ||
          row.payload != payload) {
        throw const BleDeliveryStateException(
          'SOS acknowledgement route conflicts with persisted data.',
        );
      }
      return row;
    });
  }

  /// Native write completion may race an application ACK. Terminal state wins.
  Future<BleOutboxData> finishWriting(
    String messageId, {
    DateTime? now,
  }) => _database.transaction(() async {
    final row = await lookupOutbox(messageId);
    if (row == null) throw const BleDeliveryStateException('Missing outbox.');
    if (row.state == BleOutboxState.sending.wireValue ||
        row.state == BleOutboxState.writeAccepted.wireValue) {
      await (_database.update(_database.bleOutbox)..where(
            (t) => t.messageId.equals(messageId) & t.state.equals(row.state),
          ))
          .write(
            BleOutboxCompanion(
              state: Value(BleOutboxState.awaitingAcknowledgement.wireValue),
              updatedAt: Value((now ?? DateTime.now()).toUtc()),
            ),
          );
    }
    return (await lookupOutbox(messageId))!;
  });

  Future<BleOutboxData> recordLocationAcknowledgement(
    LocationBleEnvelope acknowledgement, {
    String? sourceDeviceId,
    DateTime? now,
  }) async {
    acknowledgement.validate();
    if (acknowledgement.kind != 'location.ack') {
      throw const BleDeliveryStateException('Expected a location ACK.');
    }
    final timestamp = (now ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      final current = await lookupOutbox(acknowledgement.ackFor!);
      if (current == null ||
          !_isLocationUpdate(current.payload) ||
          current.sosId != acknowledgement.sosId) {
        throw const BleDeliveryStateException(
          'Location ACK does not match a location outbox message.',
        );
      }
      final expected = current.destinationId?.trim();
      if (sourceDeviceId != null &&
          (expected == null ||
              expected.isEmpty ||
              expected != sourceDeviceId.trim())) {
        throw const BleDeliveryStateException(
          'Location ACK came from an unexpected BLE peer.',
        );
      }
      final state = BleOutboxState.parse(current.state);
      if (state == BleOutboxState.acknowledged) return current;
      if (!_acknowledgementStates.contains(state)) {
        throw BleDeliveryStateException(
          'Cannot acknowledge location in ${state.wireValue} state.',
        );
      }
      final persisted = acknowledgement.ackStatus == 'persisted';
      final next = persisted
          ? BleOutboxState.acknowledged
          : BleOutboxState.failed;
      final changed =
          await (_database.update(_database.bleOutbox)..where(
                (table) =>
                    table.messageId.equals(current.messageId) &
                    table.state.equals(current.state),
              ))
              .write(
                BleOutboxCompanion(
                  state: Value(next.wireValue),
                  lastError: Value(acknowledgement.error),
                  nextRetryAt: const Value(null),
                  acknowledgedAt: persisted
                      ? Value(timestamp)
                      : const Value.absent(),
                  updatedAt: Value(timestamp),
                ),
              );
      if (changed != 1) {
        throw const BleDeliveryStateException(
          'Location ACK raced with another update.',
        );
      }
      return (await lookupOutbox(current.messageId))!;
    });
  }

  Future<BleInboxInsertResult> insertInboxDelivery(
    SosBleEnvelope envelope, {
    DateTime? now,
  }) async {
    _requireDelivery(envelope);
    final payload = jsonEncode(envelope.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();

    return _database.transaction(() async {
      // The insert is still protected by the primary-key conflict rule. The
      // read only reports whether this transaction found an existing row; it
      // is not used as a check-then-insert uniqueness mechanism.
      final existed = await lookupInbox(envelope.messageId);
      await _database
          .into(_database.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              senderDeviceId: Value(envelope.senderDeviceId),
              schemaVersion: SosBleEnvelope.schemaVersion,
              payload: payload,
              processingState: BleInboxState.received.wireValue,
              receivedAt: timestamp,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final row = await lookupInbox(envelope.messageId);
      if (row == null) {
        throw const BleDeliveryStateException('Unable to persist BLE inbox.');
      }
      if (row.payload != payload || row.sosId != envelope.sosId) {
        throw const BleDeliveryStateException(
          'Duplicate messageId contains a different payload.',
        );
      }
      return BleInboxInsertResult(row: row, inserted: existed == null);
    });
  }

  Future<BleInboxInsertResult> persistIncomingLocation(
    LocationBleEnvelope envelope, {
    required String expectedRecipientId,
    String? sourceDeviceId,
    String? expectedSenderId,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    envelope.validate(now: timestamp);
    if (envelope.recipientId != expectedRecipientId) {
      throw const BleDeliveryStateException(
        'Location update has the wrong recipient.',
      );
    }
    if (sourceDeviceId != null &&
        envelope.senderDeviceId != null &&
        envelope.senderDeviceId!.trim() !=
            (expectedSenderId ?? sourceDeviceId.trim())) {
      throw const BleDeliveryStateException(
        'Location update sender does not match the BLE peer.',
      );
    }
    final payload = jsonEncode(envelope.toJson());
    return _database.transaction(() async {
      final existed = await lookupInbox(envelope.messageId);
      if (existed != null &&
          sourceDeviceId != null &&
          existed.senderDeviceId != sourceDeviceId) {
        throw const BlePeerMismatchException();
      }
      if (existed == null) {
        final history = await (_database.select(
          _database.bleInbox,
        )..where((table) => table.sosId.equals(envelope.sosId))).get();
        for (final row in history) {
          try {
            final value = jsonDecode(row.payload);
            if (value is Map && value['kind'] == 'location.update') {
              final created = DateTime.parse(value['createdAt'] as String);
              if (!envelope.createdAt.isAfter(created.toUtc())) {
                throw const BleDeliveryStateException(
                  'Location update is older than the latest persisted update.',
                );
              }
            }
          } on BleDeliveryStateException {
            rethrow;
          } on Object {
            // Malformed historical rows are ignored; they are not a source
            // of truth for rejecting a newly validated update.
          }
        }
      }
      await _database
          .into(_database.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              senderDeviceId: Value(sourceDeviceId ?? envelope.senderDeviceId),
              schemaVersion: LocationBleEnvelope.schemaVersion,
              payload: payload,
              processingState: BleInboxState.persisted.wireValue,
              receivedAt: timestamp,
              persistedAt: Value(timestamp),
              acknowledgementStatus: Value(
                BleAcknowledgementStatus.persisted.wireValue,
              ),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final row = await lookupInbox(envelope.messageId);
      if (row == null ||
          row.payload != payload ||
          row.sosId != envelope.sosId) {
        throw const BleDeliveryStateException(
          'Duplicate location messageId has a different payload.',
        );
      }
      return BleInboxInsertResult(row: row, inserted: existed == null);
    });
  }

  /// Persists the inbox row and the SOS row in one transaction. This is the
  /// only operation the coordinator uses before emitting a positive ACK.
  Future<BleInboundPersistResult> persistIncomingDelivery(
    SosBleEnvelope envelope, {
    required String ownerId,
    String? sourceDeviceId,
    String? expectedSenderId,
    DateTime? now,
  }) async {
    _requireDelivery(envelope);
    final source = sourceDeviceId?.trim();
    final declaredSender = envelope.senderDeviceId?.trim();
    if (source != null &&
        (source.isEmpty ||
            (declaredSender != null &&
                declaredSender != (expectedSenderId ?? source)))) {
      throw const BlePeerMismatchException();
    }
    final payload = jsonEncode(envelope.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();

    return _database.transaction(() async {
      final existedInbox = await lookupInbox(envelope.messageId);
      // Bind new inbox rows to the observed radio route, not account ownership
      // or an optional envelope field. Never infer a missing legacy binding
      // from a replay: its original transport peer is unknown.
      if (existedInbox != null &&
          source != null &&
          existedInbox.senderDeviceId?.trim() != source) {
        throw const BlePeerMismatchException();
      }
      await _database
          .into(_database.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              senderDeviceId: Value(source ?? envelope.senderDeviceId),
              schemaVersion: SosBleEnvelope.schemaVersion,
              payload: payload,
              processingState: BleInboxState.received.wireValue,
              receivedAt: timestamp,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      final inbox = await lookupInbox(envelope.messageId);
      if (inbox == null) {
        throw const BleDeliveryStateException('Unable to persist BLE inbox.');
      }
      if (inbox.payload != payload || inbox.sosId != envelope.sosId) {
        throw const BleDeliveryStateException(
          'Duplicate messageId contains a different payload.',
        );
      }

      final existingSos = await (_database.select(
        _database.sosMessages,
      )..where((table) => table.id.equals(envelope.sosId))).getSingleOrNull();
      if (existingSos != null) {
        if (!_sameSos(envelope, existingSos) ||
            existingSos.ownerId != ownerId) {
          throw const BleDeliveryStateException(
            'sosId is already used for a different SOS.',
          );
        }
      } else {
        await _database
            .into(_database.sosMessages)
            .insert(envelope.toSosCompanion(ownerId: ownerId));
      }

      if (inbox.processingState == BleInboxState.received.wireValue) {
        final changed =
            await (_database.update(_database.bleInbox)..where(
                  (table) =>
                      table.messageId.equals(envelope.messageId) &
                      table.processingState.equals(
                        BleInboxState.received.wireValue,
                      ),
                ))
                .write(
                  BleInboxCompanion(
                    processingState: Value(BleInboxState.persisted.wireValue),
                    persistedAt: Value(timestamp),
                  ),
                );
        if (changed != 1) {
          throw const BleDeliveryStateException(
            'BLE inbox state changed concurrently.',
          );
        }
      }

      return BleInboundPersistResult(
        inbox: (await lookupInbox(envelope.messageId))!,
        sos: existingSos ?? (await _lookupSos(envelope.sosId))!,
        duplicate: existedInbox != null || existingSos != null,
      );
    });
  }

  Future<int> recoverStaleOutbox({
    required DateTime olderThan,
    required DateTime nextRetryAt,
    String error = 'Recovered after an interrupted BLE attempt.',
    String? ownerId,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return (_database.update(_database.bleOutbox)..where(
          (table) =>
              _outboxOwnerScope(table, ownerId) &
              table.updatedAt.isSmallerOrEqualValue(olderThan) &
              (table.state.equals(BleOutboxState.sending.wireValue) |
                  table.state.equals(BleOutboxState.writeAccepted.wireValue) |
                  table.state.equals(
                    BleOutboxState.awaitingAcknowledgement.wireValue,
                  )),
        ))
        .write(
          BleOutboxCompanion(
            state: Value(BleOutboxState.failed.wireValue),
            nextRetryAt: Value(nextRetryAt),
            lastError: Value(error),
            updatedAt: Value(timestamp),
          ),
        );
  }

  Future<BleInboxData> markInboxAcknowledgement(
    String messageId,
    BleAcknowledgementStatus status,
  ) async {
    final changed =
        await (_database.update(
          _database.bleInbox,
        )..where((table) => table.messageId.equals(messageId))).write(
          BleInboxCompanion(acknowledgementStatus: Value(status.wireValue)),
        );
    if (changed != 1) {
      throw const BleDeliveryStateException('BLE inbox message not found.');
    }
    return (await lookupInbox(messageId))!;
  }

  Future<BleInboxData?> lookupInbox(String messageId) {
    return (_database.select(
      _database.bleInbox,
    )..where((table) => table.messageId.equals(messageId))).getSingleOrNull();
  }

  /// Returns the newest non-expired inbound location for an SOS. Expired or
  /// malformed historical updates are never exposed as the current position.
  Future<LocationBleEnvelope?> latestIncomingLocation(
    String sosId, {
    String? requiredSenderDeviceId,
    String? requiredSenderIdentity,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final expectedSender = requiredSenderDeviceId?.trim();
    final expectedIdentity = requiredSenderIdentity?.trim();
    final rows =
        await (_database.select(_database.bleInbox)
              ..where((table) => table.sosId.equals(sosId))
              ..orderBy([(table) => OrderingTerm.desc(table.receivedAt)]))
            .get();
    for (final row in rows) {
      try {
        final value = jsonDecode(row.payload);
        if (value is! Map || value['kind'] != 'location.update') continue;
        final map = Map<String, Object?>.from(value);
        final createdAt = DateTime.parse(map['createdAt'] as String).toUtc();
        final envelope = LocationBleEnvelope.fromBleMessage(
          BleMessage(
            id: map['messageId'] as String,
            type: 'location.update',
            createdAt: createdAt,
            payload: map,
          ),
        );
        if (expectedSender != null &&
            (row.senderDeviceId?.trim() != expectedSender)) {
          continue;
        }
        if (expectedIdentity != null &&
            envelope.senderDeviceId?.trim() != expectedIdentity) {
          continue;
        }
        envelope.validate(now: timestamp);
        return envelope;
      } on Object {
        // Ignore malformed/expired history and continue to the next candidate.
      }
    }
    return null;
  }

  /// Emits the newest valid location whenever the inbox changes. The sender
  /// filter is deliberate: a nearby BLE peer is not automatically the
  /// incident participant, so callers must provide the peer identity they
  /// have already established for this incident.
  Stream<LocationBleEnvelope?> watchIncomingLocation(
    String sosId, {
    String? requiredSenderDeviceId,
    String? requiredSenderIdentity,
  }) =>
      (_database.select(
        _database.bleInbox,
      )..where((table) => table.sosId.equals(sosId))).watch().asyncMap(
        (_) => latestIncomingLocation(
          sosId,
          requiredSenderDeviceId: requiredSenderDeviceId,
          requiredSenderIdentity: requiredSenderIdentity,
        ),
      );

  static bool _isLocationUpdate(String payload) {
    try {
      final value = jsonDecode(payload);
      return value is Map && value['kind'] == 'location.update';
    } on Object {
      return false;
    }
  }

  Future<BleInboxData> transitionInboxState(
    String messageId,
    BleInboxState nextState, {
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return _database.transaction(() async {
      final current = await lookupInbox(messageId);
      if (current == null) {
        throw const BleDeliveryStateException('BLE inbox message not found.');
      }
      final state = BleInboxState.parse(current.processingState);
      if (!_legalInboxTransitions[state]!.contains(nextState)) {
        throw BleDeliveryStateException(
          'Invalid BLE inbox transition: ${state.wireValue} '
          'to ${nextState.wireValue}.',
        );
      }
      final changed =
          await (_database.update(_database.bleInbox)..where(
                (table) =>
                    table.messageId.equals(messageId) &
                    table.processingState.equals(current.processingState),
              ))
              .write(
                BleInboxCompanion(
                  processingState: Value(nextState.wireValue),
                  persistedAt: nextState == BleInboxState.persisted
                      ? Value(timestamp)
                      : const Value.absent(),
                  acknowledgementStatus: Value(
                    nextState == BleInboxState.persisted
                        ? BleAcknowledgementStatus.persisted.wireValue
                        : nextState == BleInboxState.rejected
                        ? BleAcknowledgementStatus.rejected.wireValue
                        : null,
                  ),
                ),
              );
      if (changed != 1) {
        throw const BleDeliveryStateException(
          'BLE inbox state changed concurrently.',
        );
      }
      return (await lookupInbox(messageId))!;
    });
  }

  static const _acknowledgementStates = {
    BleOutboxState.failed,
    BleOutboxState.sending,
    BleOutboxState.writeAccepted,
    BleOutboxState.awaitingAcknowledgement,
  };

  static const _legalTransitions = <BleOutboxState, Set<BleOutboxState>>{
    BleOutboxState.queued: {
      BleOutboxState.sending,
      BleOutboxState.failed,
      BleOutboxState.expired,
    },
    BleOutboxState.sending: {
      BleOutboxState.writeAccepted,
      BleOutboxState.acknowledged,
      BleOutboxState.failed,
      BleOutboxState.expired,
    },
    BleOutboxState.writeAccepted: {
      BleOutboxState.awaitingAcknowledgement,
      BleOutboxState.acknowledged,
      BleOutboxState.failed,
    },
    BleOutboxState.awaitingAcknowledgement: {
      BleOutboxState.acknowledged,
      BleOutboxState.failed,
    },
    BleOutboxState.failed: {BleOutboxState.sending, BleOutboxState.expired},
    BleOutboxState.acknowledged: <BleOutboxState>{},
    BleOutboxState.expired: <BleOutboxState>{},
  };

  static const _legalInboxTransitions = <BleInboxState, Set<BleInboxState>>{
    BleInboxState.received: {BleInboxState.persisted, BleInboxState.rejected},
    BleInboxState.persisted: <BleInboxState>{},
    BleInboxState.rejected: <BleInboxState>{},
  };

  void _requireDelivery(SosBleEnvelope envelope) {
    if (envelope.kind != SosBleMessageKind.delivery) {
      throw const BleDeliveryStateException(
        'Only SOS delivery envelopes belong in BLE delivery state.',
      );
    }
  }

  void _requireOutbound(SosBleEnvelope envelope) {
    if (envelope.kind != SosBleMessageKind.delivery &&
        envelope.kind != SosBleMessageKind.chatMessage) {
      throw const BleDeliveryStateException(
        'Only outbound SOS or chat messages can enter BLE outbox.',
      );
    }
  }

  SosBleMessageKind _decodeEnvelopeKind(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        throw const FormatException();
      }
      return SosBleEnvelope.fromJson(Map<String, Object?>.from(decoded)).kind;
    } on Object {
      throw const BleDeliveryStateException(
        'Stored BLE outbox payload is invalid.',
      );
    }
  }

  Future<SosMessage?> _lookupSos(String id) {
    return (_database.select(
      _database.sosMessages,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  bool _sameSos(SosBleEnvelope envelope, SosMessage sos) =>
      envelope.sosType == sos.type &&
      envelope.status == sos.status &&
      envelope.message == sos.message &&
      envelope.latitude == sos.latitude &&
      envelope.longitude == sos.longitude &&
      envelope.createdAt.toUtc() == sos.createdAt.toUtc() &&
      envelope.updatedAt?.toUtc() == sos.updatedAt.toUtc();
}

class BleInboxInsertResult {
  const BleInboxInsertResult({required this.row, required this.inserted});

  final BleInboxData row;
  final bool inserted;
}

class BleInboundPersistResult {
  const BleInboundPersistResult({
    required this.inbox,
    required this.sos,
    required this.duplicate,
  });

  final BleInboxData inbox;
  final SosMessage sos;
  final bool duplicate;
}
