import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/incident_lifecycle_envelope.dart';
import '../domain/relay_envelope.dart';

enum LifecycleAuthorization { deferred, authorized, rejected }

/// Owner-scoped lifecycle evidence in the existing inbox (schema v9).
/// A self-consistent signature is not an incident authorization. Only a
/// previously verified SOS/candidate can establish the trusted origin.
class IncidentLifecycleRepository {
  IncidentLifecycleRepository(this.database, {required this.ownerId});

  final AppDatabase database;
  final String ownerId;
  String get _ownerTag =>
      'lifecycle-owner:${base64UrlEncode(utf8.encode(ownerId))}';
  String _storageId(String eventId) => '$_ownerTag:$eventId';

  Future<LifecycleAuthorization> receive(
    IncidentLifecycleEnvelope event, {
    required String sourcePeer,
    required DateTime now,
  }) async {
    await event.validate(now: now);
    final payload = event.toCanonicalWire();
    return database.transaction(() async {
      final existing =
          await (database.select(database.bleInbox)
                ..where((r) => r.messageId.equals(_storageId(event.eventId))))
              .getSingleOrNull();
      if (existing != null && existing.payload != payload) {
        throw const RelayProtocolException(
          'Lifecycle replay payload conflicts.',
        );
      }
      await database
          .into(database.bleInbox)
          .insert(
            BleInboxCompanion.insert(
              messageId: _storageId(event.eventId),
              sosId: event.incidentId,
              senderDeviceId: Value(sourcePeer),
              schemaVersion: IncidentLifecycleEnvelope.schemaVersion,
              payload: payload,
              processingState: 'lifecycle_deferred',
              acknowledgementStatus: Value(_ownerTag),
              receivedAt: now.toUtc(),
              persistedAt: Value(now.toUtc()),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await reconcileIncident(event.incidentId, now: now);
      final row =
          await (database.select(database.bleInbox)
                ..where((r) => r.messageId.equals(_storageId(event.eventId))))
              .getSingle();
      return switch (row.processingState) {
        'lifecycle_authorized' => LifecycleAuthorization.authorized,
        'lifecycle_rejected' => LifecycleAuthorization.rejected,
        _ => LifecycleAuthorization.deferred,
      };
    });
  }

  Future<List<BleInboxData>> authorizedEvents({String? incidentId}) =>
      (database.select(database.bleInbox)..where(
            (r) =>
                r.acknowledgementStatus.equals(_ownerTag) &
                r.processingState.equals('lifecycle_authorized') &
                (incidentId == null
                    ? const Constant(true)
                    : r.sosId.equals(incidentId)),
          ))
          .get();

  Future<void> reconcilePending({required DateTime now}) async {
    final rows =
        await (database.select(database.bleInbox)..where(
              (r) =>
                  r.acknowledgementStatus.equals(_ownerTag) &
                  r.processingState.equals('lifecycle_deferred'),
            ))
            .get();
    for (final incident in rows.map((r) => r.sosId).toSet()) {
      await reconcileIncident(incident, now: now);
    }
  }

  Future<void> reconcileIncident(
    String incidentId, {
    required DateTime now,
  }) => database.transaction(() async {
    final rows =
        await (database.select(database.bleInbox)..where(
              (r) =>
                  r.acknowledgementStatus.equals(_ownerTag) &
                  r.sosId.equals(incidentId),
            ))
            .get();
    if (rows.isEmpty) return;
    final origin = await _trustedOrigin(incidentId, now);
    if (origin == null) return;
    final valid = <IncidentLifecycleEnvelope>[];
    for (final row in rows) {
      var authorized = false;
      IncidentLifecycleEnvelope? event;
      try {
        event = IncidentLifecycleEnvelope.fromJson(
          Map<String, Object?>.from(jsonDecode(row.payload) as Map),
        );
        await event.validate(now: now);
        authorized =
            row.messageId == _storageId(event.eventId) &&
            event.incidentId == incidentId &&
            event.originKeyId == origin.keyId &&
            !event.createdAt.isBefore(origin.createdAt);
      } on Object {
        authorized = false;
      }
      await (database.update(
        database.bleInbox,
      )..where((r) => r.messageId.equals(row.messageId))).write(
        BleInboxCompanion(
          processingState: Value(
            authorized ? 'lifecycle_authorized' : 'lifecycle_rejected',
          ),
        ),
      );
      if (authorized) valid.add(event!);
    }
    if (valid.isEmpty) return;
    // Terminal states never reopen. A resolved event dominates cancelled;
    // delivery order/duplicates cannot downgrade resolution to cancellation.
    valid.sort((a, b) {
      final terminal = (a.status == 'resolved' ? 1 : 0).compareTo(
        b.status == 'resolved' ? 1 : 0,
      );
      return terminal != 0 ? terminal : a.createdAt.compareTo(b.createdAt);
    });
    final latest = valid.last;
    final sos =
        await (database.select(database.sosMessages)..where(
              (r) => r.id.equals(incidentId) & r.ownerId.equals(ownerId),
            ))
            .getSingleOrNull();
    if (sos != null && _canAdvance(sos.status, latest.status)) {
      await (database.update(database.sosMessages)
            ..where((r) => r.id.equals(incidentId) & r.ownerId.equals(ownerId)))
          .write(
            SosMessagesCompanion(
              status: Value(latest.status),
              syncState: const Value('deviceOnly'),
              updatedAt: Value(
                latest.createdAt.isAfter(sos.updatedAt)
                    ? latest.createdAt
                    : sos.updatedAt,
              ),
            ),
          );
    }
    final candidates =
        await (database.select(database.rescueInbox)..where(
              (r) =>
                  r.incidentId.equals(incidentId) & r.ownerId.equals(ownerId),
            ))
            .get();
    for (final candidate in candidates) {
      if (candidate.originKeyId != origin.keyId ||
          !_canAdvance(candidate.state, latest.status)) {
        continue;
      }
      await (database.update(database.rescueInbox)..where(
            (r) =>
                r.ownerId.equals(ownerId) &
                r.originMessageId.equals(candidate.originMessageId),
          ))
          .write(RescueInboxCompanion(state: Value(latest.status)));
    }
  });

  bool _canAdvance(String current, String next) =>
      current != 'resolved' && (current != 'cancelled' || next == 'resolved');

  /// Read-only origin binding for short-lived signed contact evidence too.
  Future<({String keyId, DateTime createdAt})?> trustedOriginForPresence(
    String incidentId,
    DateTime now,
  ) => _trustedOrigin(incidentId, now);

  Future<({String keyId, DateTime createdAt})?> _trustedOrigin(
    String incidentId,
    DateTime now,
  ) async {
    final candidates =
        await (database.select(database.rescueInbox)..where(
              (r) =>
                  r.ownerId.equals(ownerId) & r.incidentId.equals(incidentId),
            ))
            .get();
    final relay =
        await (database.select(database.bleRelayMessages)
              ..where((r) => r.originMessageId.equals('relay:$incidentId')))
            .getSingleOrNull();
    ({String keyId, DateTime createdAt})? trusted;
    if (relay != null) {
      // Relay TTL limits forwarding, not the validity of its original signer
      // as historical lifecycle evidence. Still verify signatures and binding.
      final offer = RelayOfferEnvelope.fromCanonicalWire(relay.wireEnvelope);
      final crypto = RelayCryptography();
      if (!await crypto.verifyOffer(offer, now: now, allowExpired: true) ||
          offer.body.incidentId != incidentId ||
          offer.body.originMessageId != relay.originMessageId ||
          offer.body.originKeyId != relay.originKeyId ||
          offer.body.originPublicKey != relay.originPublicKey ||
          await crypto.immutableDigest(offer.body) != relay.immutableDigest) {
        throw const RelayProtocolException(
          'Stored lifecycle origin is invalid.',
        );
      }
      trusted = (
        keyId: offer.body.originKeyId,
        createdAt: offer.body.createdAt,
      );
    }
    for (final candidate in candidates) {
      // Rescue Inbox is populated only by the verified reception path, and
      // retains origin binding after relay cache retention expires.
      if (trusted != null && trusted.keyId != candidate.originKeyId) {
        throw const RelayProtocolException(
          'Conflicting lifecycle origin bindings.',
        );
      }
      trusted ??= (
        keyId: candidate.originKeyId,
        createdAt: candidate.createdAt,
      );
    }
    return trusted;
  }
}
