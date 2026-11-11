import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'media_attachment_store.dart';

/// Account-scoped backup/restore for data that cannot be recovered from the
/// local-first database after an app reinstall. Guests never call this class.
class CloudArchiveService {
  CloudArchiveService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sos(String ownerId) =>
      _firestore.collection('accounts').doc(ownerId).collection('archiveSos');

  Future<void> deleteIncident({
    required String ownerId,
    required String incidentId,
  }) async {
    if (ownerId.isEmpty || ownerId == 'guest-local-device') return;
    await _sos(ownerId).doc(incidentId).delete();
  }

  Future<bool> _deleted(
    AppDatabase database,
    String ownerId,
    String id,
  ) async =>
      (await (database.select(database.sosSyncQueue)..where(
                (row) =>
                    row.ownerId.equals(ownerId) &
                    row.sosId.equals(id) &
                    (row.operation.equals('delete') |
                        row.operation.equals('deleteConfirmed')),
              ))
              .get())
          .isNotEmpty;

  Future<void> reconcile({
    required String ownerId,
    required AppDatabase database,
    required MediaAttachmentStore attachments,
  }) async {
    if (ownerId.isEmpty || ownerId == 'guest-local-device') return;

    final localSos = await database.select(database.sosMessages).get();
    for (final row in localSos.where((row) => row.ownerId == ownerId)) {
      if (await _deleted(database, ownerId, row.id)) continue;
      await _sos(ownerId)
          .doc(row.id)
          .set(_sosData(row), SetOptions(merge: true));
    }

    final localChats = await database.select(database.chatMessages).get();
    for (final row in localChats.where((row) => row.ownerId == ownerId)) {
      if (await _deleted(database, ownerId, row.sosId)) continue;
      await _uploadChat(ownerId: ownerId, row: row, attachments: attachments);
    }

    final remoteSos = await _sos(ownerId).get();
    for (final document in remoteSos.docs) {
      if (!await _restoreSos(database, ownerId, document)) continue;
      final chats = await document.reference.collection('chat').get();
      for (final chat in chats.docs) {
        await _restoreChat(
          database: database,
          ownerId: ownerId,
          document: chat,
          attachments: attachments,
        );
      }
    }
  }

  Map<String, Object?> _sosData(SosMessage row) => {
    'id': row.id,
    'ownerId': row.ownerId,
    'type': row.type,
    'message': row.message,
    'latitude': row.latitude,
    'longitude': row.longitude,
    'status': row.status,
    'createdAt': Timestamp.fromDate(row.createdAt),
    'updatedAt': Timestamp.fromDate(row.updatedAt),
  };

  Future<void> _uploadChat({
    required String ownerId,
    required ChatMessage row,
    required MediaAttachmentStore attachments,
  }) async {
    // No-cost mode archives metadata only. Media bytes remain local and can
    // be re-transferred over the existing BLE path when the peer is present.
    final data = <String, Object?>{
      'messageId': row.messageId,
      'sosId': row.sosId,
      'ownerId': row.ownerId,
      'senderId': row.senderId,
      'recipientId': row.recipientId,
      'messageType': row.messageType,
      'textContent': row.textContent,
      'createdAt': Timestamp.fromDate(row.createdAt),
      'deliveryStatus': row.deliveryStatus,
      'attachmentMimeType': row.attachmentMimeType,
      'attachmentName': row.attachmentName,
    };
    await _sos(ownerId)
        .doc(row.sosId)
        .collection('chat')
        .doc(row.messageId)
        .set(data, SetOptions(merge: true));
  }

  Future<bool> _restoreSos(
    AppDatabase database,
    String ownerId,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final data = document.data();
    if (data['id'] != document.id ||
        data['ownerId'] != ownerId ||
        data['type'] is! String ||
        data['status'] is! String ||
        data['createdAt'] is! Timestamp ||
        data['updatedAt'] is! Timestamp) {
      return false;
    }
    return database.transaction(() async {
      if (await _deleted(database, ownerId, document.id)) return false;
      await database
          .into(database.sosMessages)
          .insertOnConflictUpdate(
            SosMessagesCompanion.insert(
              id: data['id'] as String,
              ownerId: ownerId,
              type: data['type'] as String,
              message: Value(data['message'] as String?),
              latitude: Value((data['latitude'] as num?)?.toDouble()),
              longitude: Value((data['longitude'] as num?)?.toDouble()),
              status: data['status'] as String,
              syncState: 'synced',
              createdAt: (data['createdAt'] as Timestamp).toDate(),
              updatedAt: (data['updatedAt'] as Timestamp).toDate(),
            ),
          );
      return true;
    });
  }

  Future<void> _restoreChat({
    required AppDatabase database,
    required String ownerId,
    required QueryDocumentSnapshot<Map<String, dynamic>> document,
    required MediaAttachmentStore attachments,
  }) async {
    final data = document.data();
    if (data['messageId'] is! String ||
        data['sosId'] is! String ||
        data['ownerId'] != ownerId ||
        data['senderId'] is! String ||
        data['createdAt'] is! Timestamp) {
      return;
    }
    final mime = data['attachmentMimeType'] as String?;
    await database.transaction(() async {
      if (await _deleted(database, ownerId, data['sosId'] as String)) return;
      await database
          .into(database.chatMessages)
          .insertOnConflictUpdate(
            ChatMessagesCompanion.insert(
              messageId: data['messageId'] as String,
              sosId: data['sosId'] as String,
              ownerId: ownerId,
              senderId: data['senderId'] as String,
              recipientId: Value(data['recipientId'] as String?),
              messageType: data['messageType'] as String? ?? 'text',
              textContent: Value(data['textContent'] as String?),
              createdAt: (data['createdAt'] as Timestamp).toDate(),
              deliveryStatus: data['deliveryStatus'] as String? ?? 'delivered',
              attachmentPath: const Value(null),
              attachmentMimeType: Value(mime),
              attachmentName: Value(data['attachmentName'] as String?),
            ),
          );
    });
  }
}
