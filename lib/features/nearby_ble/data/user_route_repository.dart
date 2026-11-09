import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/relay_envelope.dart';
import '../domain/chat_receipt.dart';
import '../domain/chat_relay_envelope.dart';
import 'chat_relay_repository.dart';
import 'relay_repository.dart';

enum UserRouteStage {
  saved,
  queued,
  sending,
  relayed,
  received,
  confirmed,
  failed,
  expired,
  cancelled,
  resolved,
}

enum UserRouteExtent { thisDevice, nextDevice, endpointsOnly }

class UserRouteNode {
  const UserRouteNode(this.keyId, {this.local = false});
  final String? keyId;
  final bool local;
}

class UserRoute {
  const UserRoute({
    required this.nodes,
    required this.stage,
    required this.extent,
  });
  final List<UserRouteNode> nodes;
  final UserRouteStage stage;
  final UserRouteExtent extent;
  // Hops are radio legs; intermediary devices exclude both endpoints.
  int? get intermediateCount =>
      extent == UserRouteExtent.endpointsOnly ? null : nodes.length - 2;
  int? get hopCount =>
      extent == UserRouteExtent.endpointsOnly ? null : nodes.length - 1;
}

class UserRoutesSnapshot {
  const UserRoutesSnapshot({this.sos = const [], this.chat = const {}});
  final List<UserRoute> sos;
  final Map<String, UserRoute> chat;
}

String shortRouteDeviceCode(String key) {
  try {
    validateRelayKeyId(key);
    return base64Url
        .decode(key)
        .take(3)
        .map((n) => n.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  } on Object {
    return '—';
  }
}

/// Read-only owner-scoped projection of protocol-accepted durable records.
/// Does not infer a complete route from a receipt or count radio discoveries.
class UserRouteRepository {
  UserRouteRepository(this.db, {required this.ownerId, this.readLocalKeyId});
  final AppDatabase db;
  final String ownerId;
  final Future<String?> Function()? readLocalKeyId;
  final _receiptChecks = <String, Future<bool>>{};

  Future<bool> _confirmedReceipt(
    ChatReceiptData row,
    ChatRelayEnvelope envelope,
  ) {
    final wire = row.receipt;
    if (row.state != 'applied' || wire == null) return Future.value(false);
    final cacheKey = '$wire:${envelope.toCanonicalWire()}';
    if (_receiptChecks.length >= 256 && !_receiptChecks.containsKey(cacheKey)) {
      _receiptChecks.remove(_receiptChecks.keys.first);
    }
    return _receiptChecks.putIfAbsent(cacheKey, () async {
      try {
        final receipt = ChatReceipt.fromWire(wire);
        final persisted = DateTime.parse(receipt.body['persistedAt'] as String);
        // History remains meaningful after delivery expiry. Verify at the
        // signed persistence time, without renewing any delivery/retry TTL.
        await receipt.verify(envelope, persisted);
        return true;
      } on Object {
        return false;
      }
    });
  }

  Stream<UserRoutesSnapshot> watch(String incident) {
    late StreamController<UserRoutesSnapshot> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    var reading = false, again = false, cancelled = false;
    Future<void> emit() async {
      if (cancelled) return;
      if (reading) {
        again = true;
        return;
      }
      reading = true;
      do {
        again = false;
        try {
          final value = await read(incident);
          if (!cancelled && !controller.isClosed) controller.add(value);
        } on Object catch (error, stack) {
          if (!cancelled && !controller.isClosed) {
            controller.addError(error, stack);
          }
        }
      } while (again && !cancelled && !controller.isClosed);
      reading = false;
    }

    controller = StreamController<UserRoutesSnapshot>(
      onListen: () {
        // One coalesced projection per page, not one DB subscription per bubble.
        for (final stream in <Stream<Object?>>[
          (db.select(db.sosMessages)..where(
                (r) => r.ownerId.equals(ownerId) & r.id.equals(incident),
              ))
              .watch(),
          (db.select(db.rescueInbox)..where(
                (r) =>
                    r.ownerId.equals(ownerId) & r.incidentId.equals(incident),
              ))
              .watch(),
          (db.select(db.chatMessages)..where(
                (r) => r.ownerId.equals(ownerId) & r.sosId.equals(incident),
              ))
              .watch(),
          (db.select(db.chatRelayOutbox)..where(
                (r) =>
                    r.ownerId.equals(ownerId) & r.incidentId.equals(incident),
              ))
              .watch(),
          (db.select(db.chatReceipts)..where(
                (r) =>
                    r.ownerId.equals(ownerId) & r.incidentId.equals(incident),
              ))
              .watch(),
          (db.select(
            db.bleRelayMessages,
          )..where((r) => r.incidentId.equals(incident))).watch(),
          (db.select(db.bleRelayAttempts).join([
            innerJoin(
              db.bleRelayMessages,
              db.bleRelayMessages.originMessageId.equalsExp(
                db.bleRelayAttempts.originMessageId,
              ),
            ),
          ])..where(db.bleRelayMessages.incidentId.equals(incident))).watch(),
        ]) {
          subscriptions.add(
            stream.listen(
              (_) => unawaited(emit()),
              onError: controller.addError,
            ),
          );
        }
        unawaited(emit());
      },
      onCancel: () async {
        cancelled = true;
        again = false;
        await Future.wait(subscriptions.map((s) => s.cancel()));
      },
    );
    return controller.stream;
  }

  List<String>? _path(String wire, String origin, int hops) {
    try {
      final decoded = jsonDecode(wire);
      final path = List<String>.from(
        decoded is Map ? decoded['path'] as List : decoded as List,
      );
      if (hops < 0 ||
          hops > 3 ||
          path.length != hops + 1 ||
          path.first != origin ||
          path.toSet().length != path.length) {
        return null;
      }
      for (final key in path) {
        validateRelayKeyId(key);
      }
      return path;
    } on Object {
      return null;
    }
  }

  UserRouteStage _attemptStage(String state) => switch (state) {
    'acceptedByRelay' => UserRouteStage.relayed,
    'sending' || 'awaitingHopReceipt' => UserRouteStage.sending,
    'failed' => UserRouteStage.failed,
    'expired' => UserRouteStage.expired,
    _ => UserRouteStage.queued,
  };

  Future<UserRoutesSnapshot> read(String incident) async {
    final own =
        await (db.select(db.sosMessages)
              ..where((r) => r.ownerId.equals(ownerId) & r.id.equals(incident)))
            .getSingleOrNull();
    final candidates =
        await (db.select(db.rescueInbox)..where(
              (r) => r.ownerId.equals(ownerId) & r.incidentId.equals(incident),
            ))
            .get();
    if (own == null && candidates.isEmpty) return const UserRoutesSnapshot();
    final localOrigins = own == null
        ? const <BleRelayMessage>[]
        : await (db.select(db.bleRelayMessages)..where(
                (r) =>
                    r.incidentId.equals(incident) &
                    r.incomingPeerId.equals(RelayRepository.localOriginPeerId),
              ))
              .get();
    final receipts =
        await (db.select(db.chatReceipts)..where(
              (r) => r.ownerId.equals(ownerId) & r.incidentId.equals(incident),
            ))
            .get();
    final outbox =
        await (db.select(db.chatRelayOutbox)..where(
              (r) => r.ownerId.equals(ownerId) & r.incidentId.equals(incident),
            ))
            .get();
    if (candidates.isEmpty &&
        localOrigins.isEmpty &&
        receipts.isEmpty &&
        outbox.isEmpty) {
      return const UserRoutesSnapshot();
    }
    final local = await readLocalKeyId?.call();
    final sosRoutes = <UserRoute>[];
    for (final c in candidates) {
      final path = _path(c.incomingPath, c.originKeyId, c.incomingHopCount);
      if (path == null || (local != null && path.contains(local))) continue;
      final stage = switch (c.state) {
        'cancelled' => UserRouteStage.cancelled,
        'resolved' => UserRouteStage.resolved,
        _ => UserRouteStage.received,
      };
      sosRoutes.add(
        UserRoute(
          nodes: [
            ...path.map((k) => UserRouteNode(k)),
            UserRouteNode(local, local: true),
          ],
          stage: stage,
          extent: UserRouteExtent.thisDevice,
        ),
      );
    }
    if (candidates.isEmpty && own != null) {
      for (final message in localOrigins) {
        // Only this installation's origin job, never another account's global relay row.
        if (local == null || message.originKeyId != local) continue;
        final attempts =
            await (db.select(db.bleRelayAttempts)..where(
                  (r) => r.originMessageId.equals(message.originMessageId),
                ))
                .get();
        for (final a in attempts) {
          final path = _path(
            a.outgoingPath,
            message.originKeyId,
            a.outgoingHopCount,
          );
          if (path == null || path.contains(a.nextHopKeyId)) continue;
          try {
            validateRelayKeyId(a.nextHopKeyId);
          } on Object {
            continue;
          }
          sosRoutes.add(
            UserRoute(
              nodes: [
                ...path.map((k) => UserRouteNode(k, local: k == local)),
                UserRouteNode(a.nextHopKeyId),
              ],
              stage: own.status == 'cancelled'
                  ? UserRouteStage.cancelled
                  : own.status == 'resolved'
                  ? UserRouteStage.resolved
                  : _attemptStage(a.state),
              extent: UserRouteExtent.nextDevice,
            ),
          );
        }
        if (attempts.isEmpty) {
          sosRoutes.add(
            UserRoute(
              nodes: [UserRouteNode(local, local: true)],
              stage: UserRouteStage.saved,
              extent: UserRouteExtent.endpointsOnly,
            ),
          );
        }
      }
    }
    final chat = <String, UserRoute>{};
    final messages =
        await (db.select(db.chatMessages)..where(
              (r) => r.ownerId.equals(ownerId) & r.sosId.equals(incident),
            ))
            .get();
    for (final message in messages) {
      try {
        final receipt = receipts
            .where((r) => r.messageId == message.messageId)
            .firstOrNull;
        final outgoing = outbox
            .where((r) => r.messageId == message.messageId)
            .firstOrNull;
        final transfer = receipt == null
            ? null
            : ChatRelayRepository(
                db,
                ownerId: ownerId,
              ).storedTransfer(receipt.transfer);
        final payload =
            transfer?.wireEnvelope ?? outgoing?.payload ?? receipt?.transfer;
        if (payload == null) continue;
        final envelope = ChatRelayRepository(
          db,
          ownerId: ownerId,
        ).decode(payload);
        final body = envelope.body;
        if (body.messageId != message.messageId ||
            body.incidentId != incident) {
          continue;
        }
        if (transfer != null) {
          final path = _path(
            jsonEncode(transfer.path),
            body.senderKeyId,
            transfer.hopCount,
          );
          if (path == null ||
              path.contains(body.recipientKeyId) ||
              (local != null && body.recipientKeyId != local)) {
            continue;
          }
          // A durable recipient Chat row is required, not just a transport inbox.
          if (message.senderId != body.senderKeyId) continue;
          chat[message.messageId] = UserRoute(
            nodes: [
              ...path.map((k) => UserRouteNode(k)),
              UserRouteNode(body.recipientKeyId, local: true),
            ],
            stage: UserRouteStage.received,
            extent: UserRouteExtent.thisDevice,
          );
        } else {
          if (local == null || body.senderKeyId != local) continue;
          final confirmed =
              receipt != null &&
              message.deliveryStatus == 'delivered' &&
              await _confirmedReceipt(receipt, envelope);
          final stage = confirmed
              ? UserRouteStage.confirmed
              : switch (outgoing?.state) {
                  'forwarded' || 'delivered' => UserRouteStage.relayed,
                  'failed' => UserRouteStage.failed,
                  'expired' => UserRouteStage.expired,
                  _ => UserRouteStage.queued,
                };
          chat[message.messageId] = UserRoute(
            nodes: [
              UserRouteNode(body.senderKeyId, local: true),
              UserRouteNode(body.recipientKeyId),
            ],
            stage: stage,
            extent: UserRouteExtent.endpointsOnly,
          );
        }
      } on Object {
        /* Malformed/unavailable history has unknown route, never guessed hops. */
      }
    }
    return UserRoutesSnapshot(
      sos: List.unmodifiable(sosRoutes),
      chat: Map.unmodifiable(chat),
    );
  }
}
