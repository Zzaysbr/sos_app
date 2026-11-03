import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/chat_relay_envelope.dart';

enum ChatRelayDeliveryState { queued, forwarded, delivered, expired, failed }

class ChatRelayRepository {
  ChatRelayRepository(this.database, {required this.ownerId});

  final AppDatabase database;
  final String ownerId;

  Future<ChatRelayOutboxData?> findOutbox(String messageId) =>
      (database.select(database.chatRelayOutbox)..where(
            (r) => r.ownerId.equals(ownerId) & r.messageId.equals(messageId),
          ))
          .getSingleOrNull();

  Future<ChatRelayOutboxData> enqueue(
    ChatRelayEnvelope envelope, {
    DateTime? now,
    int hopCount = 0,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();
    envelope.body.validate(now: timestamp);
    await database
        .into(database.chatRelayOutbox)
        .insert(
          ChatRelayOutboxCompanion.insert(
            ownerId: ownerId,
            messageId: envelope.body.messageId,
            incidentId: envelope.body.incidentId,
            senderKeyId: envelope.body.senderKeyId,
            recipientKeyId: envelope.body.recipientKeyId,
            payload: envelope.toCanonicalWire(),
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

  Future<List<ChatRelayOutboxData>> due({DateTime? now}) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return (database.select(database.chatRelayOutbox)
          ..where(
            (r) =>
                r.ownerId.equals(ownerId) &
                r.expiresAt.isBiggerThanValue(timestamp) &
                r.state.isNotIn(const ['delivered', 'expired']) &
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
    if (existing != null) return false;
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
    await (database.update(database.chatRelayOutbox)..where(
          (r) => r.ownerId.equals(ownerId) & r.messageId.equals(messageId),
        ))
        .write(
          ChatRelayOutboxCompanion(
            state: const Value('forwarded'),
            updatedAt: Value((now ?? DateTime.now()).toUtc()),
          ),
        );
  }

  Future<void> markFailed(
    String messageId,
    Object error, {
    DateTime? now,
  }) async {
    await (database.update(database.chatRelayOutbox)..where(
          (r) => r.ownerId.equals(ownerId) & r.messageId.equals(messageId),
        ))
        .write(
          ChatRelayOutboxCompanion(
            state: const Value('failed'),
            lastError: Value(
              error
                  .toString()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .substring(0, error.toString().length.clamp(0, 256)),
            ),
            retryCount: const Value.absent(),
            nextRetryAt: Value(
              (now ?? DateTime.now()).toUtc().add(const Duration(seconds: 5)),
            ),
            updatedAt: Value((now ?? DateTime.now()).toUtc()),
          ),
        );
  }

  ChatRelayEnvelope decode(String payload) =>
      ChatRelayEnvelope.fromCanonicalWire(payload);
}
