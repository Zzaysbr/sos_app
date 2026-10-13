import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/ble_delivery_state.dart';
import '../domain/sos_ble_envelope.dart';

class BleDeliveryRepository {
  BleDeliveryRepository(this._database);

  final AppDatabase _database;

  Future<BleOutboxData> enqueueOutbox(
    SosBleEnvelope envelope, {
    String? destinationId,
    DateTime? now,
  }) async {
    _requireDelivery(envelope);
    final payload = jsonEncode(envelope.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();

    return _database.transaction(() async {
      await _database
          .into(_database.bleOutbox)
          .insert(
            BleOutboxCompanion.insert(
              messageId: envelope.messageId,
              sosId: envelope.sosId,
              destinationId: Value(destinationId),
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

  Future<BleOutboxData?> lookupOutbox(String messageId) {
    return (_database.select(
      _database.bleOutbox,
    )..where((table) => table.messageId.equals(messageId))).getSingleOrNull();
  }

  Future<BleOutboxData> assignDestinationIfMissing(
    String messageId,
    String destinationId, {
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final changed =
        await (_database.update(_database.bleOutbox)..where(
              (table) =>
                  table.messageId.equals(messageId) &
                  table.destinationId.isNull(),
            ))
            .write(
              BleOutboxCompanion(
                destinationId: Value(destinationId),
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

  Future<List<BleOutboxData>> dueOutbox({DateTime? now, int limit = 50}) async {
    if (limit <= 0) return const [];
    final timestamp = (now ?? DateTime.now()).toUtc();
    return (_database.select(_database.bleOutbox)
          ..where(
            (table) =>
                table.state.equals(BleOutboxState.queued.wireValue) |
                (table.state.equals(BleOutboxState.failed.wireValue) &
                    table.nextRetryAt.isSmallerOrEqualValue(timestamp)),
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

  Future<BleOutboxData> recordAcknowledgement(
    SosBleEnvelope acknowledgement, {
    String? sourceDeviceId,
    DateTime? now,
  }) async {
    if (acknowledgement.kind != SosBleMessageKind.acknowledgement ||
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
      if (sourceDeviceId != null &&
          current.destinationId != null &&
          current.destinationId != sourceDeviceId) {
        throw const BleDeliveryStateException(
          'Acknowledgement came from an unexpected BLE peer.',
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

  /// Persists the inbox row and the SOS row in one transaction. This is the
  /// only operation the coordinator uses before emitting a positive ACK.
  Future<BleInboundPersistResult> persistIncomingDelivery(
    SosBleEnvelope envelope, {
    required String ownerId,
    DateTime? now,
  }) async {
    _requireDelivery(envelope);
    final payload = jsonEncode(envelope.toJson());
    final timestamp = (now ?? DateTime.now()).toUtc();

    return _database.transaction(() async {
      final existedInbox = await lookupInbox(envelope.messageId);
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
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return (_database.update(_database.bleOutbox)..where(
          (table) =>
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
