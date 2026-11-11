import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../nearby_ble/data/incident_lifecycle_repository.dart';
import 'cloud_archive_service.dart';
import 'media_attachment_store.dart';
import 'sos_cloud_service.dart';

bool isValidSosCoordinatePair(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (!latitude.isFinite || !longitude.isFinite) return false;
  if (latitude == 0 && longitude == 0) return false;
  return latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}

// Stable namespace in the persistent device database; not an authentication ID.
// Keep this value compatible with existing installations.
const guestDeviceOwnerId = 'guest-local-device';

class SosRepository {
  SosRepository({
    required this._database,
    required this._cloudService,
    FirebaseAuth? firebaseAuth,
    this.localOwnerId,
    this._onSosCreated,
    this._cloudArchiveService,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _sessionOwnerId = _firebaseAuth.currentUser?.uid ?? localOwnerId;
  }

  final AppDatabase _database;
  final SosCloudService _cloudService;
  final FirebaseAuth _firebaseAuth;
  final CloudArchiveService? _cloudArchiveService;
  final String? localOwnerId;
  late final String? _sessionOwnerId;
  final Future<void> Function(SosMessage sos, {String? destinationId})?
  _onSosCreated;

  bool _isSyncing = false;

  AppDatabase get database => _database;

  String? get currentOwnerId => _ownerId;

  String? get _ownerId =>
      _sessionOwnerId != null && _isOwnerCurrent(_sessionOwnerId)
      ? _sessionOwnerId
      : null;

  bool get isGuest => _firebaseAuth.currentUser == null && localOwnerId != null;

  bool _isOwnerCurrent(String ownerId) =>
      _firebaseAuth.currentUser?.uid == ownerId ||
      (_firebaseAuth.currentUser == null && localOwnerId == ownerId);

  Stream<List<SosMessage>> watchAll() {
    final ownerId = _ownerId;
    if (ownerId == null) return Stream.value(const []);

    // Invalidate retained subscriptions immediately on logout/account change.
    return Stream<List<SosMessage>>.multi((controller) {
      final rows =
          (_database.select(_database.sosMessages)
                ..where((t) => t.ownerId.equals(ownerId))
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
              .watch()
              .listen(
                (rows) =>
                    controller.add(_isOwnerCurrent(ownerId) ? rows : const []),
                onError: controller.addError,
              );
      final auth = _firebaseAuth.authStateChanges().listen((_) {
        if (!_isOwnerCurrent(ownerId)) controller.add(const []);
      }, onError: controller.addError);
      controller.onCancel = () async {
        await rows.cancel();
        await auth.cancel();
      };
    });
  }

  // Explicit read-only scope: guest records only, never other account caches.
  Stream<List<SosMessage>> watchDeviceHistory() =>
      (_database.select(_database.sosMessages)
            ..where((t) => t.ownerId.equals(guestDeviceOwnerId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<bool> hasActiveIncident() async {
    return (await listActiveIncidents()).isNotEmpty;
  }

  Future<List<SosMessage>> listActiveIncidents() async {
    final ownerId = _ownerId;
    if (ownerId == null) return const [];
    final rows =
        await (_database.select(_database.sosMessages)..where(
              (t) => t.ownerId.equals(ownerId) & t.status.equals('active'),
            ))
            .get();
    return _isOwnerCurrent(ownerId) ? rows : const [];
  }

  Future<SosMessage?> findById(String id) async {
    final ownerId = _ownerId;
    if (ownerId == null) return null;

    final row =
        await (_database.select(_database.sosMessages)
              ..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId)))
            .getSingleOrNull();
    return _isOwnerCurrent(ownerId) ? row : null;
  }

  Future<void> create({
    required String id,
    required String type,
    String? message,
    double? latitude,
    double? longitude,
    String? destinationId,
  }) async {
    final ownerId = _requireOwner();
    final now = DateTime.now();
    final location = _normalizedLocation(latitude, longitude);

    final payload = <String, dynamic>{
      'id': id,
      'ownerId': ownerId,
      'type': type,
      'message': message,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'status': 'active',
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _database.transaction(() async {
      // Do not save a new record if the authenticated account changed.
      if (!_isOwnerCurrent(ownerId)) {
        throw const SosRepositoryException(
          'Account changed. Please try again.',
        );
      }

      await _database
          .into(_database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: id,
              ownerId: ownerId,
              type: type,
              message: Value(message),
              latitude: Value(location.latitude),
              longitude: Value(location.longitude),
              status: 'active',
              syncState: 'pending',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _enqueue(
        sosId: id,
        ownerId: ownerId,
        operation: 'create',
        payload: payload,
      );
    });

    final created = await findById(id);
    if (created != null && _onSosCreated != null) {
      try {
        await _onSosCreated(created, destinationId: destinationId);
      } catch (error, stackTrace) {
        // BLE delivery is durable and independent from local SOS creation and
        // Firestore sync. A queueing failure must not report local SOS failure.
        if (kDebugMode) {
          debugPrint('BLE SOS enqueue failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }

    if (_isOwnerCurrent(ownerId)) {
      await syncPending();
    }
  }

  /// Materializes a verified rescue candidate in the local incident scope so
  /// the existing incident Chat authorization can be reused. This is local
  /// device state only; it never enqueues a cloud sync operation and does not
  /// claim that the origin received anything.
  Future<SosMessage> ensureReceivedIncident({
    required String id,
    required String type,
    String? message,
    double? latitude,
    double? longitude,
    required DateTime createdAt,
  }) => _database.transaction(() async {
    final ownerId = _requireOwner();
    final existing = await findById(id);
    if (existing != null) {
      await IncidentLifecycleRepository(
        _database,
        ownerId: ownerId,
      ).reconcileIncident(id, now: DateTime.now().toUtc());
      return (await findById(id))!;
    }
    final now = DateTime.now().toUtc();
    final location = _normalizedLocation(latitude, longitude);
    await _database
        .into(_database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: id,
            ownerId: ownerId,
            type: type,
            message: Value(message),
            latitude: Value(location.latitude),
            longitude: Value(location.longitude),
            status: 'active',
            syncState: 'deviceOnly',
            createdAt: createdAt.toUtc(),
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await IncidentLifecycleRepository(
      _database,
      ownerId: ownerId,
    ).reconcileIncident(id, now: now);
    return (await findById(id))!;
  });

  Future<void> update({
    required String id,
    required String type,
    String? message,
    double? latitude,
    double? longitude,
    required String status,
  }) async {
    final ownerId = _requireOwner();
    final existing = await findById(id);

    if (!_isOwnerCurrent(ownerId)) {
      throw const SosRepositoryException('Account changed. Please try again.');
    }

    if (existing == null || existing.ownerId != ownerId) {
      throw const SosRepositoryException('SOS not found.');
    }

    if (!{'active', 'resolved', 'cancelled'}.contains(status)) {
      throw const SosRepositoryException('Invalid SOS status.');
    }

    final now = DateTime.now();
    // An incident location is a creation-time snapshot. Never replace a valid
    // snapshot during a status/message update; only legacy records without a
    // snapshot may be populated by an explicit valid coordinate.
    final location = _normalizedLocation(latitude, longitude);
    final existingLocation = _normalizedLocation(
      existing.latitude,
      existing.longitude,
    );
    final latitudeToStore = existingLocation.hasValue
        ? existingLocation.latitude
        : location.latitude;
    final longitudeToStore = existingLocation.hasValue
        ? existingLocation.longitude
        : location.longitude;

    final payload = <String, dynamic>{
      'id': id,
      'ownerId': ownerId,
      'type': type,
      'message': message,
      'latitude': latitudeToStore,
      'longitude': longitudeToStore,
      'status': status,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _database.transaction(() async {
      if (!_isOwnerCurrent(ownerId)) {
        throw const SosRepositoryException(
          'Account changed. Please try again.',
        );
      }

      await (_database.update(
        _database.sosMessages,
      )..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId))).write(
        SosMessagesCompanion(
          type: Value(type),
          message: Value(message),
          latitude: Value(latitudeToStore),
          longitude: Value(longitudeToStore),
          status: Value(status),
          syncState: const Value('pending'),
          updatedAt: Value(now),
        ),
      );

      await _enqueue(
        sosId: id,
        ownerId: ownerId,
        operation: 'update',
        payload: payload,
      );
    });

    if (_isOwnerCurrent(ownerId)) {
      await syncPending();
    }
  }

  Future<void> delete(String id) async {
    final ownerId = _requireOwner();
    final existing = await findById(id);

    if (!_isOwnerCurrent(ownerId)) {
      throw const SosRepositoryException('Account changed. Please try again.');
    }

    if (existing == null || existing.ownerId != ownerId) return;

    await _database.transaction(() async {
      if (!_isOwnerCurrent(ownerId)) {
        throw const SosRepositoryException(
          'Account changed. Please try again.',
        );
      }

      // Deletion supersedes queued edits; an old failed create must not block it.
      await (_database.delete(
        _database.sosSyncQueue,
      )..where((t) => t.sosId.equals(id) & t.ownerId.equals(ownerId))).go();
      // Keep the delete command after removing the local row.
      await _enqueue(sosId: id, ownerId: ownerId, operation: 'delete');

      await (_database.delete(
        _database.sosMessages,
      )..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId))).go();
    });

    if (_isOwnerCurrent(ownerId)) {
      await syncPending();
    }
  }

  Future<void> syncPending() async {
    // Guest records are intentionally local-only. Firestore security rules
    // continue to require an authenticated Firebase owner.
    if (_firebaseAuth.currentUser == null) return;
    final ownerId = _ownerId;
    if (ownerId == null || ownerId == guestDeviceOwnerId || _isSyncing) return;

    _isSyncing = true;

    try {
      await _enqueueLegacyPending(ownerId);

      if (!_isOwnerCurrent(ownerId)) return;

      final queue =
          await (_database.select(_database.sosSyncQueue)
                ..where(
                  (t) =>
                      t.ownerId.equals(ownerId) &
                      t.operation.equals('deleteConfirmed').not(),
                )
                ..orderBy([(t) => OrderingTerm.asc(t.queueId)]))
              .get();

      final failedSosIds = <String>{};

      for (final item in queue) {
        // Stop processing as soon as the active account changes.
        if (!_isOwnerCurrent(ownerId)) break;

        if (failedSosIds.contains(item.sosId)) continue;

        try {
          switch (item.operation) {
            case 'create':
              final data = _decodePayload(item.payload);

              await _cloudService.create(
                id: item.sosId,
                ownerId: item.ownerId,
                type: _string(data, 'type'),
                message: data['message'] as String?,
                latitude: _doubleOrNull(data['latitude']),
                longitude: _doubleOrNull(data['longitude']),
                status: _string(data, 'status'),
                createdAt: _date(data, 'createdAt'),
                updatedAt: _date(data, 'updatedAt'),
              );
              break;

            case 'update':
              final data = _decodePayload(item.payload);

              await _cloudService.update(
                id: item.sosId,
                type: _string(data, 'type'),
                message: data['message'] as String?,
                latitude: _doubleOrNull(data['latitude']),
                longitude: _doubleOrNull(data['longitude']),
                status: _string(data, 'status'),
                updatedAt: _date(data, 'updatedAt'),
              );
              break;

            case 'delete':
              await _cloudArchiveService?.deleteIncident(
                ownerId: ownerId,
                incidentId: item.sosId,
              );
              if (!_isOwnerCurrent(ownerId)) break;
              await _cloudService.delete(item.sosId);
              break;

            default:
              throw StateError(
                'Unsupported SOS sync operation: ${item.operation}',
              );
          }

          // Never acknowledge an operation after the account has changed.
          if (!_isOwnerCurrent(ownerId)) break;

          if (item.operation == 'delete') {
            // Retain local intent even after cloud acknowledgement: an archive
            // read begun before deletion may still finish with the old record.
            await (_database.update(
              _database.sosSyncQueue,
            )..where((t) => t.queueId.equals(item.queueId))).write(
              const SosSyncQueueCompanion(operation: Value('deleteConfirmed')),
            );
          } else {
            await (_database.delete(
              _database.sosSyncQueue,
            )..where((t) => t.queueId.equals(item.queueId))).go();
          }

          if (item.operation != 'delete') {
            final remaining =
                await (_database.select(_database.sosSyncQueue)..where(
                      (t) =>
                          t.ownerId.equals(ownerId) &
                          t.sosId.equals(item.sosId),
                    ))
                    .get();

            if (!_isOwnerCurrent(ownerId)) break;

            if (remaining.isEmpty) {
              await _setSyncState(item.sosId, ownerId, 'synced');
            }
          }
        } catch (error) {
          // Keep failed commands for a later retry.
          failedSosIds.add(item.sosId);
        }
      }

      // Firestore is also the recovery source for authenticated owners. This
      // is intentionally after the durable upload queue so local edits win.
      if (_isOwnerCurrent(ownerId)) {
        await _cloudArchiveService?.reconcile(
          ownerId: ownerId,
          database: _database,
          attachments: MediaAttachmentStore(ownerId: ownerId),
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _enqueueLegacyPending(String ownerId) async {
    // Convert pending rows from the previous implementation into queue items.
    final pending =
        await (_database.select(_database.sosMessages)..where(
              (t) => t.ownerId.equals(ownerId) & t.syncState.equals('pending'),
            ))
            .get();

    for (final sos in pending) {
      if (!_isOwnerCurrent(ownerId)) return;

      final existingQueue =
          await (_database.select(_database.sosSyncQueue)..where(
                (t) => t.ownerId.equals(ownerId) & t.sosId.equals(sos.id),
              ))
              .get();

      if (existingQueue.isNotEmpty) continue;

      final payload = _rowPayload(sos);

      try {
        final cloudExists = await _cloudService.exists(sos.id);

        if (!_isOwnerCurrent(ownerId)) return;

        if (cloudExists) {
          await _enqueue(
            sosId: sos.id,
            ownerId: ownerId,
            operation: 'update',
            payload: payload,
          );
        } else if (sos.status == 'active') {
          await _enqueue(
            sosId: sos.id,
            ownerId: ownerId,
            operation: 'create',
            payload: payload,
          );
        } else {
          // Firestore requires a new SOS to be created as active first.
          final createPayload = Map<String, dynamic>.from(payload)
            ..['status'] = 'active';

          await _enqueue(
            sosId: sos.id,
            ownerId: ownerId,
            operation: 'create',
            payload: createPayload,
          );

          await _enqueue(
            sosId: sos.id,
            ownerId: ownerId,
            operation: 'update',
            payload: payload,
          );
        }
      } catch (_) {
        // Preserve the local row; retry discovery on a later sync.
      }
    }
  }

  Map<String, dynamic> _rowPayload(SosMessage sos) => {
    'id': sos.id,
    'ownerId': sos.ownerId,
    'type': sos.type,
    'message': sos.message,
    'latitude': sos.latitude,
    'longitude': sos.longitude,
    'status': sos.status,
    'createdAt': sos.createdAt.toIso8601String(),
    'updatedAt': sos.updatedAt.toIso8601String(),
  };

  Future<void> _enqueue({
    required String sosId,
    required String ownerId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    await _database
        .into(_database.sosSyncQueue)
        .insert(
          SosSyncQueueCompanion.insert(
            sosId: sosId,
            ownerId: ownerId,
            operation: operation,
            payload: Value(payload == null ? null : jsonEncode(payload)),
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<void> _setSyncState(String id, String ownerId, String state) async {
    // updatedAt is a business timestamp and must not change during sync.
    await (_database.update(_database.sosMessages)
          ..where((t) => t.id.equals(id) & t.ownerId.equals(ownerId)))
        .write(SosMessagesCompanion(syncState: Value(state)));
  }

  String _requireOwner() {
    final ownerId = _ownerId;

    if (ownerId == null) {
      throw const SosRepositoryException('User is not authenticated.');
    }

    return ownerId;
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null) {
      throw const FormatException('Missing SOS sync payload.');
    }

    final decoded = jsonDecode(payload);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid SOS sync payload.');
    }

    return decoded;
  }

  String _string(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid SOS field: $key');
    }

    return value;
  }

  double? _doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    throw const FormatException('Invalid SOS coordinate.');
  }

  DateTime _date(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value is! String) {
      throw FormatException('Invalid SOS date: $key');
    }

    return DateTime.parse(value);
  }

  _SosLocation _normalizedLocation(double? latitude, double? longitude) {
    if (!isValidSosCoordinatePair(latitude, longitude)) {
      return const _SosLocation.empty();
    }
    return _SosLocation(latitude: latitude, longitude: longitude);
  }
}

class _SosLocation {
  const _SosLocation({required this.latitude, required this.longitude})
    : hasValue = true;
  const _SosLocation.empty()
    : latitude = null,
      longitude = null,
      hasValue = false;

  final double? latitude;
  final double? longitude;
  final bool hasValue;
}

class SosRepositoryException implements Exception {
  const SosRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
