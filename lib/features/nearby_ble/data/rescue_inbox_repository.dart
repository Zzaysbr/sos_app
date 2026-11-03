import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/relay_envelope.dart';
import 'relay_repository.dart';

enum RescueCandidateState { pending, viewed, locallyAccepted, expired }

class RescueInboxRepository {
  RescueInboxRepository(this.database, {required this.ownerId});

  final AppDatabase database;
  final String ownerId;

  Stream<List<RescueInboxData>> watchCandidates() {
    return (database.select(database.rescueInbox)
          ..where((row) => row.ownerId.equals(ownerId))
          ..orderBy([(row) => OrderingTerm.desc(row.receivedAt)]))
        .watch();
  }

  Future<RescueInboxData?> find(String originMessageId) {
    return (database.select(database.rescueInbox)..where(
          (row) =>
              row.ownerId.equals(ownerId) &
              row.originMessageId.equals(originMessageId),
        ))
        .getSingleOrNull();
  }

  Future<RescueInboxData> insertCandidate(
    RelayOfferEnvelope offer, {
    required String immutableDigest,
    DateTime? now,
  }) async {
    if (offer.body.scope != RelayAuthorizationScope.voluntaryRescue) {
      throw const RelayPersistenceException(
        'Relay offer is not authorized for voluntary rescue.',
      );
    }
    final timestamp = (now ?? DateTime.now()).toUtc();
    offer.body.validate(now: timestamp);
    final existing = await find(offer.body.originMessageId);
    if (existing != null) {
      if (existing.immutableDigest != immutableDigest) {
        throw const RelayPersistenceException(
          'Rescue candidate identity conflicts with stored data.',
        );
      }
      return existing;
    }
    await database
        .into(database.rescueInbox)
        .insert(
          RescueInboxCompanion.insert(
            ownerId: ownerId,
            originMessageId: offer.body.originMessageId,
            incidentId: offer.body.incidentId,
            originKeyId: offer.body.originKeyId,
            immutableDigest: immutableDigest,
            emergencyType: offer.body.emergencyType,
            emergencyMessage: offer.body.emergencyMessage,
            includeLocation: offer.body.includeLocation,
            latitude: Value(offer.body.latitude),
            longitude: Value(offer.body.longitude),
            incomingHopCount: offer.hopCount,
            incomingPath: jsonEncode(offer.pathKeyIds),
            createdAt: offer.body.createdAt,
            expiresAt: offer.body.expiresAt,
            receivedAt: timestamp,
            state: RescueCandidateState.pending.name,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return (await find(offer.body.originMessageId))!;
  }

  Future<RescueInboxData?> acceptLocally(String originMessageId) async {
    final row = await find(originMessageId);
    if (row == null) return null;
    if (!row.expiresAt.isAfter(DateTime.now().toUtc())) {
      await (database.update(database.rescueInbox)..where(
            (item) =>
                item.ownerId.equals(ownerId) &
                item.originMessageId.equals(originMessageId),
          ))
          .write(const RescueInboxCompanion(state: Value('expired')));
      return find(originMessageId);
    }
    if (row.state == RescueCandidateState.locallyAccepted.name) return row;
    final acceptanceId = 'accept:$ownerId:$originMessageId';
    await (database.update(database.rescueInbox)..where(
          (item) =>
              item.ownerId.equals(ownerId) &
              item.originMessageId.equals(originMessageId),
        ))
        .write(
          RescueInboxCompanion(
            state: const Value('locallyAccepted'),
            acceptanceId: Value(acceptanceId),
            acceptedAt: Value(DateTime.now().toUtc()),
          ),
        );
    return find(originMessageId);
  }
}
