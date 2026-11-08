import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/chat_relay_envelope.dart';
import '../domain/chat_receipt.dart';

class ChatReceiptRepository {
  ChatReceiptRepository(this.db, this.owner);
  final AppDatabase db;
  final String owner;
  Future<ChatReceipt?> known(String id) async {
    final r = await route(id);
    return r?.receipt == null ? null : ChatReceipt.fromWire(r!.receipt!);
  }

  Future<ChatReceiptData?> route(String id) =>
      (db.select(db.chatReceipts)
            ..where((r) => r.ownerId.equals(owner) & r.messageId.equals(id)))
          .getSingleOrNull();
  Future<void> remember(ChatRelayTransfer t, DateTime now) async {
    final e = ChatRelayEnvelope.fromCanonicalWire(t.wireEnvelope);
    final existing = await route(e.body.messageId);
    if (existing != null) {
      final old = decode(existing.transfer);
      if (old.wireEnvelope != t.wireEnvelope) {
        throw const FormatException('Receipt route conflicts.');
      }
      return;
    }
    await (db.delete(db.chatReceipts)..where(
          (r) =>
              r.ownerId.equals(owner) & r.expiresAt.isSmallerOrEqualValue(now),
        ))
        .go();
    if (await (db.select(db.chatReceipts)
              ..where((r) => r.ownerId.equals(owner)))
            .get()
            .then((rows) => rows.length) >=
        256) {
      throw const FormatException('Chat receipt route quota full.');
    }
    await db
        .into(db.chatReceipts)
        .insert(
          ChatReceiptsCompanion.insert(
            ownerId: owner,
            messageId: e.body.messageId,
            incidentId: e.body.incidentId,
            transfer: jsonEncode(t.toJson()),
            previousKeyId: t.path.last,
            state: 'awaiting',
            receivedAt: now,
            expiresAt: e.body.expiresAt.add(ChatReceipt.grace),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  ChatRelayTransfer decode(String s) => ChatRelayTransfer.fromJson(
    Map<String, Object?>.from(jsonDecode(s) as Map),
  );
  Future<void> store(
    ChatReceipt receipt,
    ChatRelayEnvelope e, {
    required bool applied,
  }) async {
    await db.transaction(() async {
      final row = await route(e.body.messageId);
      if (row != null &&
          row.receipt != null &&
          row.receipt != receipt.toWire()) {
        throw const FormatException('Conflicting receipt replay.');
      }
      if (row != null) {
        await (db.update(db.chatReceipts)..where(
              (r) =>
                  r.ownerId.equals(owner) &
                  r.messageId.equals(e.body.messageId),
            ))
            .write(
              ChatReceiptsCompanion(
                receipt: Value(receipt.toWire()),
                state: Value(applied ? 'applied' : 'queued'),
              ),
            );
      }
      // Any validated recipient receipt terminates this node's forward job.
      await (db.update(db.chatRelayOutbox)..where(
            (r) =>
                r.ownerId.equals(owner) & r.messageId.equals(e.body.messageId),
          ))
          .write(const ChatRelayOutboxCompanion(state: Value('delivered')));
      if (applied) {
        final chat =
            await (db.select(db.chatMessages)..where(
                  (r) =>
                      r.ownerId.equals(owner) &
                      r.messageId.equals(e.body.messageId) &
                      r.sosId.equals(e.body.incidentId),
                ))
                .getSingleOrNull();
        if (chat == null || chat.textContent != e.body.text) {
          throw const FormatException('Receipt local message mismatch.');
        }
        await (db.update(db.chatMessages)..where(
              (r) =>
                  r.ownerId.equals(owner) &
                  r.messageId.equals(e.body.messageId),
            ))
            .write(
              const ChatMessagesCompanion(deliveryStatus: Value('delivered')),
            );
        // Sender outbox durably holds receipt for replay conflict checks, without
        // creating a fictitious inbound route at the sender.
        if (row == null) {
          final count = await (db.select(
            db.chatReceipts,
          )..where((r) => r.ownerId.equals(owner))).get();
          if (count.length >= 256) {
            throw const FormatException('Chat receipt quota full.');
          }
          await db
              .into(db.chatReceipts)
              .insert(
                ChatReceiptsCompanion.insert(
                  ownerId: owner,
                  messageId: e.body.messageId,
                  incidentId: e.body.incidentId,
                  transfer: e.toCanonicalWire(),
                  previousKeyId: '',
                  receipt: Value(receipt.toWire()),
                  state: 'applied',
                  receivedAt: DateTime.parse(
                    receipt.body['persistedAt'] as String,
                  ),
                  expiresAt: receipt.expiresAt,
                ),
              );
        }
      }
    });
  }

  Future<bool> hasLiveWork(DateTime now) async =>
      await (db.select(db.chatReceipts)
            ..where(
              (r) =>
                  r.ownerId.equals(owner) &
                  r.expiresAt.isBiggerThanValue(now) &
                  r.state.isNotIn(['applied']) &
                  r.retryCount.isSmallerThanValue(8),
            )
            ..limit(1))
          .getSingleOrNull() !=
      null;

  Future<List<ChatReceiptData>> pending(DateTime now) async {
    await (db.delete(db.chatReceipts)..where(
          (r) =>
              r.ownerId.equals(owner) & r.expiresAt.isSmallerOrEqualValue(now),
        ))
        .go();
    return (db.select(db.chatReceipts)..where(
          (r) =>
              r.ownerId.equals(owner) &
              r.state.isNotIn(['applied']) &
              r.retryCount.isSmallerThanValue(8) &
              (r.nextRetryAt.isNull() |
                  r.nextRetryAt.isSmallerOrEqualValue(now)),
        ))
        .get();
  }

  Future<void> attempted(String id, DateTime now) async {
    final row = await route(id);
    if (row == null) return;
    await (db.update(
      db.chatReceipts,
    )..where((r) => r.ownerId.equals(owner) & r.messageId.equals(id))).write(
      ChatReceiptsCompanion(
        retryCount: Value(row.retryCount + 1),
        nextRetryAt: Value(
          now.add(Duration(seconds: 5 * (1 << row.retryCount.clamp(0, 6)))),
        ),
      ),
    );
  }
}
