import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

enum ChatDeliveryStatus { pending, sent, delivered, failed }

class EmergencyChatMessage {
  const EmergencyChatMessage({
    required this.id,
    required this.sosId,
    required this.senderId,
    this.recipientId,
    required this.text,
    required this.createdAt,
    required this.status,
    this.isMine = false,
    this.attachmentPath,
    this.attachmentMimeType,
    this.attachmentName,
  });

  final String id;
  final String sosId;
  final String senderId;
  final String? recipientId;
  final String text;
  final DateTime createdAt;
  final ChatDeliveryStatus status;
  final bool isMine;
  final String? attachmentPath;
  final String? attachmentMimeType;
  final String? attachmentName;
}

abstract interface class ChatRepository {
  Future<List<EmergencyChatMessage>> loadMessages(String sosId);

  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) =>
      Stream.fromFuture(loadMessages(sosId));

  Future<EmergencyChatMessage> insertMessage({
    required String sosId,
    required String text,
    String? messageId,
    String? recipientId,
    String messageType = 'text',
    String? attachmentPath,
    String? attachmentMimeType,
    String? attachmentName,
  });

  Future<void> updateDeliveryStatus(
    String messageId,
    ChatDeliveryStatus status,
  );

  Future<EmergencyChatMessage> insertIncomingMessage({
    required String messageId,
    required String sosId,
    required String senderId,
    String? recipientId,
    required String text,
    required DateTime createdAt,
  });
}

class PersistentChatRepository implements ChatRepository {
  PersistentChatRepository({
    required this._database,
    required String ownerId,
    String? senderId,
  }) : _ownerId = ownerId,
       _senderId = senderId ?? ownerId;

  final AppDatabase _database;
  final String _ownerId;
  final String _senderId;

  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async {
    await _requireAuthorizedSos(sosId);
    final rows =
        await (_database.select(_database.chatMessages)
              ..where(
                (table) =>
                    table.ownerId.equals(_ownerId) & table.sosId.equals(sosId),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get();
    return _messagesWithOrigin(rows);
  }

  @override
  Future<EmergencyChatMessage> insertMessage({
    required String sosId,
    required String text,
    String? messageId,
    String? recipientId,
    String messageType = 'text',
    String? attachmentPath,
    String? attachmentMimeType,
    String? attachmentName,
  }) async {
    await _requireAuthorizedSos(sosId);
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachmentPath == null) {
      throw const ChatRepositoryException('A chat message cannot be empty.');
    }
    final now = DateTime.now().toUtc();
    final stableMessageId = messageId ?? 'chat-${now.microsecondsSinceEpoch}';
    ChatMessage? stored;
    await _database.transaction(() async {
      await _database
          .into(_database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: stableMessageId,
              sosId: sosId,
              ownerId: _ownerId,
              senderId: _senderId,
              recipientId: Value(recipientId),
              messageType: messageType,
              textContent: Value(trimmed.isEmpty ? null : trimmed),
              createdAt: now,
              deliveryStatus: ChatDeliveryStatus.pending.name,
              attachmentPath: Value(attachmentPath),
              attachmentMimeType: Value(attachmentMimeType),
              attachmentName: Value(attachmentName),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final existing =
          await (_database.select(_database.chatMessages)
                ..where((table) => table.messageId.equals(stableMessageId)))
              .getSingleOrNull();
      if (existing == null ||
          existing.sosId != sosId ||
          existing.ownerId != _ownerId ||
          existing.senderId != _senderId ||
          existing.recipientId != recipientId ||
          existing.textContent != (trimmed.isEmpty ? null : trimmed)) {
        throw const ChatRepositoryException(
          'A chat message ID is already used for different content.',
        );
      }
      stored = existing;
    });
    return _toMessage(stored!, outgoing: true);
  }

  @override
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) {
    final query = _database.select(_database.chatMessages)
      ..where(
        (table) => table.ownerId.equals(_ownerId) & table.sosId.equals(sosId),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.watch().asyncMap(_messagesWithOrigin);
  }

  @override
  Future<void> updateDeliveryStatus(
    String messageId,
    ChatDeliveryStatus status,
  ) async {
    await _database.transaction(() async {
      final query = _database.select(_database.chatMessages)
        ..where(
          (t) => t.messageId.equals(messageId) & t.ownerId.equals(_ownerId),
        );
      final row = await query.getSingleOrNull();
      if (row == null) {
        throw const ChatRepositoryException('Chat message was not found.');
      }
      if (row.deliveryStatus == ChatDeliveryStatus.delivered.name) return;
      await (_database.update(_database.chatMessages)..where(
            (t) => t.messageId.equals(messageId) & t.ownerId.equals(_ownerId),
          ))
          .write(ChatMessagesCompanion(deliveryStatus: Value(status.name)));
    });
  }

  @override
  Future<EmergencyChatMessage> insertIncomingMessage({
    required String messageId,
    required String sosId,
    required String senderId,
    String? recipientId,
    required String text,
    required DateTime createdAt,
  }) async {
    await _requireAuthorizedSos(sosId);
    if (senderId.trim().isEmpty || text.trim().isEmpty) {
      throw const ChatRepositoryException('Invalid incoming chat message.');
    }
    final timestamp = createdAt.toUtc();
    await _database.transaction(() async {
      await _database
          .into(_database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: messageId,
              sosId: sosId,
              ownerId: _ownerId,
              senderId: senderId,
              recipientId: Value(recipientId ?? _ownerId),
              messageType: 'text',
              textContent: Value(text),
              createdAt: timestamp,
              deliveryStatus: ChatDeliveryStatus.delivered.name,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      final row = await (_database.select(
        _database.chatMessages,
      )..where((table) => table.messageId.equals(messageId))).getSingleOrNull();
      if (row == null ||
          row.sosId != sosId ||
          row.senderId != senderId ||
          row.recipientId != (recipientId ?? _ownerId) ||
          row.textContent != text) {
        throw const ChatRepositoryException(
          'A chat message ID is already used for different content.',
        );
      }
    });
    final row = await (_database.select(
      _database.chatMessages,
    )..where((table) => table.messageId.equals(messageId))).getSingle();
    return _toMessage(row);
  }

  Future<void> _requireAuthorizedSos(String sosId) async {
    final sos =
        await (_database.select(_database.sosMessages)..where(
              (table) =>
                  table.id.equals(sosId) & table.ownerId.equals(_ownerId),
            ))
            .getSingleOrNull();
    if (sos == null) {
      throw const ChatRepositoryException(
        'This SOS incident is not available to the current account.',
      );
    }
  }

  Future<List<EmergencyChatMessage>> _messagesWithOrigin(
    List<ChatMessage> rows,
  ) async {
    final outgoing = await (_database.select(
      _database.bleOutbox,
    )..where((t) => t.messageId.isIn(rows.map((r) => r.messageId)))).get();
    final ids = outgoing.map((r) => r.messageId).toSet();
    return rows
        .map((row) => _toMessage(row, outgoing: ids.contains(row.messageId)))
        .toList(growable: false);
  }

  EmergencyChatMessage _toMessage(ChatMessage row, {bool outgoing = false}) =>
      EmergencyChatMessage(
        id: row.messageId,
        sosId: row.sosId,
        senderId: row.senderId,
        recipientId: row.recipientId,
        text: row.textContent ?? '',
        createdAt: row.createdAt,
        status: _parseStatus(row.deliveryStatus),
        isMine: outgoing || row.senderId == _senderId,
        attachmentPath: row.attachmentPath,
        attachmentMimeType: row.attachmentMimeType,
        attachmentName: row.attachmentName,
      );

  ChatDeliveryStatus _parseStatus(String value) =>
      ChatDeliveryStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => ChatDeliveryStatus.pending,
      );
}

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);
  final String message;
  @override
  String toString() => 'ChatRepositoryException: $message';
}
