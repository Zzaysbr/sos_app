import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/chat_relay_envelope.dart';

import 'dart:convert';

enum ChatRelayDeliveryState { queued, forwarded, delivered, expired, failed }

class ChatRelayRepository {
  ChatRelayRepository(this.database, {required this.ownerId});

  final AppDatabase database;
  final String ownerId;
  static const maximumAttempts = 8;

  Future<ChatRelayOutboxData?> findOutbox(String messageId) =>
      (database.select(database.chatRelayOutbox)..where(
            (r) => r.ownerId.equals(ownerId) & r.messageId.equals(messageId),
          ))
          .getSingleOrNull();

  Future<ChatRelayOutboxData> enqueue(
    ChatRelayEnvelope envelope, {
    DateTime? now,
    int hopCount = 0,
    ChatRelayTransfer? receivedTransfer,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    envelope.body.validate(now: timestamp);
    final existing = await findOutbox(envelope.body.messageId);
    if (existing != null) {
      if (decode(existing.payload).toCanonicalWire() !=
          envelope.toCanonicalWire()) {
        throw const FormatException('Conflicting Chat message replay.');
      }
      return existing;
    }
    await database
        .into(database.chatRelayOutbox)
        .insert(
          ChatRelayOutboxCompanion.insert(
            ownerId: ownerId,
            messageId: envelope.body.messageId,
            incidentId: envelope.body.incidentId,
            senderKeyId: envelope.body.senderKeyId,
            recipientKeyId: envelope.body.recipientKeyId,
            payload: receivedTransfer == null
                ? envelope.toCanonicalWire()
                : relayTransferWire(receivedTransfer),
            state: ChatRelayDeliveryState.queued.name,
            hopCount: Value(hopCount),
            expiresAt: envelope.body.expiresAt,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await findOutbox(envelope.body.messageId))!;
  }

  Future<List<ChatRelayOutboxData>> due({DateTime? now}) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    await (database.update(database.chatRelayOutbox)..where(
          (r) =>
              r.ownerId.equals(ownerId) &
              r.expiresAt.isSmallerOrEqualValue(timestamp) &
              r.state.isNotIn(const ['delivered', 'expired']),
        ))
        .write(const ChatRelayOutboxCompanion(state: Value('expired')));
    return (database.select(database.chatRelayOutbox)
          ..where(
            (r) =>
                r.ownerId.equals(ownerId) &
                r.expiresAt.isBiggerThanValue(timestamp) &
                r.state.isNotIn(const ['delivered', 'expired']) &
                r.retryCount.isSmallerThanValue(maximumAttempts) &
                (r.nextRetryAt.isNull() |
                    r.nextRetryAt.isSmallerOrEqualValue(timestamp)),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.updatedAt)]))
        .get();
  }

  Future<bool> persistIncoming(
    ChatRelayEnvelope envelope, {
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final existing =
        await (database.select(database.chatRelayInbox)..where(
              (r) =>
                  r.ownerId.equals(ownerId) &
                  r.messageId.equals(envelope.body.messageId),
            ))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.payload != envelope.toCanonicalWire()) {
        throw const FormatException('Conflicting incoming Chat replay.');
      }
      return false;
    }
    final inserted = await database
        .into(database.chatRelayInbox)
        .insert(
          ChatRelayInboxCompanion.insert(
            ownerId: ownerId,
            messageId: envelope.body.messageId,
            incidentId: envelope.body.incidentId,
            senderKeyId: envelope.body.senderKeyId,
            recipientKeyId: envelope.body.recipientKeyId,
            payload: envelope.toCanonicalWire(),
            state: 'verified',
            receivedAt: timestamp,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted > 0;
  }

  Future<void> markForwarded(String messageId, {DateTime? now}) async {
    final row = await findOutbox(messageId);
    if (row == null || row.state == 'delivered') return;
    await (database.update(database.chatRelayOutbox)..where(
          (r) => r.ownerId.equals(ownerId) & r.messageId.equals(messageId),
        ))
        .write(
          ChatRelayOutboxCompanion(
            state: const Value('forwarded'),
            retryCount: Value(row.retryCount + 1),
            nextRetryAt: Value(
              (now ?? DateTime.now()).toUtc().add(_retry(row.retryCount)),
            ),
            updatedAt: Value((now ?? DateTime.now()).toUtc()),
          ),
        );
  }

  Future<void> markFailed(
    String messageId,
    Object error, {
    DateTime? now,
  }) async {
    final row = await findOutbox(messageId);
    if (row == null || row.state == 'delivered') return;
    final reason = error.toString().replaceAll(RegExp(r'\s+'), ' ');
    await (database.update(database.chatRelayOutbox)..where(
          (r) => r.ownerId.equals(ownerId) & r.messageId.equals(messageId),
        ))
        .write(
          ChatRelayOutboxCompanion(
            state: const Value('failed'),
            lastError: Value(reason.substring(0, reason.length.clamp(0, 256))),
            retryCount: Value(row.retryCount + 1),
            nextRetryAt: Value(
              (now ?? DateTime.now()).toUtc().add(_retry(row.retryCount)),
            ),
            updatedAt: Value((now ?? DateTime.now()).toUtc()),
          ),
        );
  }

  Duration _retry(int attempts) =>
      Duration(seconds: 5 * (1 << attempts.clamp(0, 6)));

  static String relayTransferWire(ChatRelayTransfer transfer) =>
      jsonEncode(transfer.toJson());
  ChatRelayTransfer? storedTransfer(String payload) {
    final json = jsonDecode(payload);
    if (json is Map && json['kind'] == ChatRelayTransfer.wireKind) {
      return ChatRelayTransfer.fromJson(Map<String, Object?>.from(json));
    }
    return null;
  }

  ChatRelayEnvelope decode(String payload) =>
      ChatRelayEnvelope.fromCanonicalWire(
        storedTransfer(payload)?.wireEnvelope ?? payload,
      );
}
