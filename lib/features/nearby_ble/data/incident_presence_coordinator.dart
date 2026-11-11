import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../domain/ble_models.dart';
import '../domain/incident_presence_envelope.dart';
import 'ble_protocol.dart';
import 'hop_relay_coordinator.dart';
import 'incident_lifecycle_repository.dart';
import 'relay_repository.dart';

class _Contact {
  _Contact(this.pulse);
  IncidentPresenceEnvelope pulse;
  final paths = <String, ({DateTime expiresAt, bool Function() current})>{};
}

/// Ephemeral visibility only. Acceptance, SOS, Chat and history stay in SQLite.
class IncidentPresenceCoordinator {
  IncidentPresenceCoordinator({
    required this.database,
    required this.ownerId,
    required this.relay,
    required this.now,
    required this.isCurrent,
    this.directDestinationKey,
    this.directOrigin,
  });
  final AppDatabase database;
  final String ownerId;
  final HopRelayCoordinator relay;
  final DateTime Function() now;
  final bool Function() isCurrent;
  final Future<String?> Function(String incident)? directDestinationKey;
  final Future<({String keyId, DateTime createdAt})?> Function(
    String incident,
    String peer,
  )?
  directOrigin;
  final reachable = ValueNotifier<Set<String>>({});
  final _contacts = <String, _Contact>{};
  final _forwarded = <String, DateTime>{};
  final _freshness = <String, ({DateTime expiresAt, DateTime retainUntil})>{};
  final _lastSent = <String, DateTime>{};
  Future<void>? _ticking;

  void refresh() {
    final time = now().toUtc();
    _contacts.removeWhere(
      (_, contact) => !contact.pulse.expiresAt.isAfter(time),
    );
    for (final contact in _contacts.values) {
      contact.paths.removeWhere(
        (_, path) => !path.expiresAt.isAfter(time) || !path.current(),
      );
    }
    _forwarded.removeWhere((_, expiry) => !expiry.isAfter(time));
    _freshness.removeWhere((_, entry) => !entry.retainUntil.isAfter(time));
    final visible = isCurrent()
        ? {
            for (final entry in _contacts.entries)
              if (entry.value.paths.values.any((path) => path.current()))
                entry.key,
          }
        : <String>{};
    if (!setEquals(visible, reachable.value)) {
      reachable.value = Set.unmodifiable(visible);
    }
  }

  void clear() {
    _contacts.clear();
    _forwarded.clear();
    _freshness.clear();
    _lastSent.clear();
    refresh();
  }

  Future<void> tick() =>
      _ticking ??= _tick().whenComplete(() => _ticking = null);
  Future<void> _tick() async {
    refresh();
    if (!isCurrent() || relay.currentAuthenticatedRoutes().isEmpty) return;
    final identity = await relay.signingIdentity();
    final origins =
        await (database.select(database.bleRelayMessages)..where(
              (row) =>
                  row.incomingPeerId.equals(RelayRepository.localOriginPeerId) &
                  row.originKeyId.equals(identity.keyId),
            ))
            .get();
    final publicIds = origins.map((row) => row.incidentId).toSet();
    final owned =
        await (database.select(database.sosMessages)..where(
              (row) =>
                  row.ownerId.equals(ownerId) & row.status.equals('active'),
            ))
            .get();
    for (final local in owned) {
      if (!isCurrent()) return;
      final time = now().toUtc();
      if (_lastSent[local.id]
              ?.add(IncidentPresenceEnvelope.interval)
              .isAfter(time) ==
          true) {
        continue;
      }
      final public = publicIds.contains(local.id);
      final directKey = public
          ? null
          : await directDestinationKey?.call(local.id);
      if (!public && directKey == null) continue;
      final pulse = await IncidentPresenceEnvelope.sign(
        local.id,
        identity,
        time,
        direct: !public,
      );
      // Check again after signing; cancellation must stop new contact evidence.
      final current =
          await (database.select(database.sosMessages)..where(
                (row) =>
                    row.ownerId.equals(ownerId) &
                    row.id.equals(local.id) &
                    row.status.equals('active'),
              ))
              .getSingleOrNull();
      if (current == null || !isCurrent()) continue;
      _lastSent[local.id] = time;
      await _broadcast(pulse, onlyKey: directKey);
    }
    final liveIds = owned.map((row) => row.id).toSet();
    _lastSent.removeWhere((id, _) => !liveIds.contains(id));
  }

  Future<void> receive(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    if (!isCurrent()) return;
    final routes = relay.currentAuthenticatedRoutes();
    final sender = routes.entries
        .where(
          (entry) =>
              entry.value.deviceId == peer &&
              entry.value.role == role &&
              entry.value.isCurrent(),
        )
        .firstOrNull;
    if (sender == null) return;
    final pulse = IncidentPresenceEnvelope.fromMessage(message);
    if (pulse.path.last != sender.key) return;
    await pulse.verify(now());
    var evidence = await IncidentLifecycleRepository(
      database,
      ownerId: ownerId,
    ).trustedOriginForPresence(pulse.incidentId, now());
    if (evidence == null && pulse.direct) {
      evidence = await directOrigin?.call(pulse.incidentId, peer);
    }
    if (evidence == null ||
        evidence.keyId != pulse.keyId ||
        pulse.createdAt.isBefore(evidence.createdAt)) {
      return;
    }
    final candidate =
        await (database.select(database.rescueInbox)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.incidentId.equals(pulse.incidentId),
            ))
            .get();
    if (candidate.any(
      (row) => const {
        'cancelled',
        'resolved',
        'archivedLocally',
      }.contains(row.state),
    )) {
      return;
    }
    final incident =
        await (database.select(database.sosMessages)..where(
              (row) =>
                  row.ownerId.equals(ownerId) & row.id.equals(pulse.incidentId),
            ))
            .getSingleOrNull();
    if (incident != null && incident.status != 'active') return;
    if (!isCurrent() || !sender.value.isCurrent()) return;
    refresh();
    final pulseKey = '${pulse.keyId}|${pulse.incidentId}|${pulse.id}';
    var freshness = _freshness[pulseKey];
    if (freshness == null) {
      if (_freshness.length >= 512) return;
      final localLimit = now().toUtc().add(IncidentPresenceEnvelope.lifetime);
      freshness = (
        expiresAt: pulse.expiresAt.isBefore(localLimit)
            ? pulse.expiresAt
            : localLimit,
        retainUntil: pulse.expiresAt,
      );
      _freshness[pulseKey] = freshness;
    }
    if (!freshness.expiresAt.isAfter(now().toUtc())) return;
    var contact = _contacts[pulse.incidentId];
    if (contact == null) {
      if (_contacts.length >= 128) return;
      contact = _Contact(pulse);
      _contacts[pulse.incidentId] = contact;
    }
    if (pulse.createdAt.isAfter(contact.pulse.createdAt)) contact.pulse = pulse;
    final token = '$peer|${role.wireValue}';
    if (!contact.paths.containsKey(token) && contact.paths.length >= 16) return;
    final expiry = freshness.expiresAt;
    if (contact.paths[token]?.expiresAt.isAfter(expiry) != true) {
      contact.paths[token] = (
        expiresAt: expiry,
        current: sender.value.isCurrent,
      );
    }
    refresh();
    if (_forwarded.containsKey(pulseKey) ||
        _forwarded.length >= 512 ||
        !relay.participationEnabled ||
        pulse.direct) {
      return;
    }
    _forwarded[pulseKey] = pulse.expiresAt;
    final identity = await relay.signingIdentity();
    if (pulse.path.contains(identity.keyId) || pulse.path.length >= 3) return;
    await _broadcast(pulse.forwardedBy(identity.keyId));
  }

  Future<void> _broadcast(
    IncidentPresenceEnvelope pulse, {
    String? onlyKey,
  }) async {
    for (final peer in relay.currentAuthenticatedRoutes().entries) {
      if (!isCurrent() || !pulse.expiresAt.isAfter(now().toUtc())) return;
      if (pulse.path.contains(peer.key)) continue;
      if (onlyKey != null && peer.key != onlyKey) continue;
      try {
        await relay.sendPresence(peer.key, pulse.toMessage());
      } on Object {
        /* A short-lived pulse is replaced on the next tick. */
      }
    }
  }
}
