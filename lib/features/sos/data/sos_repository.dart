import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/database/app_database.dart';
import 'sos_cloud_service.dart';

class SosRepository {
  SosRepository({
    required this._database,
    required this._cloudService,
    FirebaseAuth? firebaseAuth,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final AppDatabase _database;
  final SosCloudService _cloudService;
  final FirebaseAuth _firebaseAuth;

  Stream<List<SosMessage>> watchAll() {
    return (_database.select(_database.sosMessages)..orderBy([
          (table) => OrderingTerm(
            expression: table.createdAt,
            mode: OrderingMode.desc,
          ),
        ]))
        .watch();
  }

  Future<SosMessage?> findById(String id) {
    return (_database.select(
      _database.sosMessages,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
  }

  Future<void> create({
    required String id,
    required String type,
    String? message,
    double? latitude,
    double? longitude,
  }) async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw const SosRepositoryException('User is not authenticated.');
    }

    final now = DateTime.now();

    // Local-first: the SOS must exist locally even when offline.
    await _database
        .into(_database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: id,
            ownerId: user.uid,
            type: type,
            message: Value(message),
            latitude: Value(latitude),
            longitude: Value(longitude),
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );

    try {
      await _cloudService.create(
        id: id,
        ownerId: user.uid,
        type: type,
        message: message,
        latitude: latitude,
        longitude: longitude,
        status: 'active',
        createdAt: now,
        updatedAt: now,
      );

      await _setSyncState(id, 'synced');
    } catch (_) {
      // Keep pending so a future sync can retry.
      await _setSyncState(id, 'pending');
    }
  }

  Future<void> update({
    required String id,
    required String type,
    String? message,
    double? latitude,
    double? longitude,
    required String status,
  }) async {
    final existing = await findById(id);

    if (existing == null) {
      throw const SosRepositoryException('SOS not found.');
    }

    final now = DateTime.now();

    await (_database.update(
      _database.sosMessages,
    )..where((table) => table.id.equals(id))).write(
      SosMessagesCompanion(
        type: Value(type),
        message: Value(message),
        latitude: Value(latitude),
        longitude: Value(longitude),
        status: Value(status),
        syncState: const Value('pending'),
        updatedAt: Value(now),
      ),
    );

    try {
      await _cloudService.update(
        id: id,
        type: type,
        message: message,
        latitude: latitude,
        longitude: longitude,
        status: status,
        updatedAt: now,
      );

      await _setSyncState(id, 'synced');
    } catch (_) {
      await _setSyncState(id, 'pending');
    }
  }

  Future<void> delete(String id) async {
    final existing = await findById(id);

    if (existing == null) {
      return;
    }

    try {
      await _cloudService.delete(id);
    } catch (_) {
      // Local delete still succeeds.
      // A production version should enqueue a delete operation.
    }

    await (_database.delete(
      _database.sosMessages,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<void> syncPending() async {
    final pending = await (_database.select(
      _database.sosMessages,
    )..where((table) => table.syncState.equals('pending'))).get();

    for (final sos in pending) {
      try {
        await _cloudService.create(
          id: sos.id,
          ownerId: sos.ownerId,
          type: sos.type,
          message: sos.message,
          latitude: sos.latitude,
          longitude: sos.longitude,
          status: sos.status,
          createdAt: sos.createdAt,
          updatedAt: sos.updatedAt,
        );

        await _setSyncState(sos.id, 'synced');
      } catch (_) {
        // Keep pending for the next retry.
      }
    }
  }

  Future<void> _setSyncState(String id, String state) async {
    await (_database.update(
      _database.sosMessages,
    )..where((table) => table.id.equals(id))).write(
      SosMessagesCompanion(
        syncState: Value(state),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

class SosRepositoryException implements Exception {
  const SosRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
