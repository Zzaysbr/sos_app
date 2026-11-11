import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/database/app_database.dart';
import 'relay_repository.dart';
import 'ble_delivery_repository.dart';

enum AutomaticLocationState {
  idle,
  starting,
  sharing,
  permissionRequired,
  unavailable,
}

abstract interface class IncidentLocationFeed {
  Future<void> prepare({required bool mayRequestPermission});
  Stream<Position> positions();
}

class GeolocatorIncidentLocationFeed implements IncidentLocationFeed {
  @override
  Future<void> prepare({required bool mayRequestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location Services unavailable');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && mayRequestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationPermissionRequired();
    }
  }

  @override
  Stream<Position> positions() {
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Emergency',
          notificationText: 'กำลังแชร์ตำแหน่งสำหรับเหตุ SOS ที่ใช้งานอยู่',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high);
    }
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

class LocationPermissionRequired implements Exception {
  const LocationPermissionRequired();
}

typedef IncidentLocationPublish = Future<void> Function(
  String incidentId,
  String role,
  Position fix,
  DateTime createdAt,
  int sequence,
);

/// Owner/session-scoped location work. It has no dependency on a page being
/// mounted. A route change only changes the authenticated next hops at publish.
class AutomaticIncidentLocation with WidgetsBindingObserver {
  AutomaticIncidentLocation({
    required this.database,
    required this.ownerId,
    required this.localDeviceId,
    required this.publish,
    required this.isCurrent,
    this.feed,
    this.onLocationFix,
    this.allowVictimLocation,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final AppDatabase database;
  final String ownerId;
  final String localDeviceId;
  final IncidentLocationPublish publish;
  final bool Function() isCurrent;
  final IncidentLocationFeed? feed;
  final Future<void> Function()? onLocationFix;
  final Future<bool> Function()? allowVictimLocation;
  final DateTime Function() now;
  final state = ValueNotifier(AutomaticLocationState.idle);
  late final _feed = feed ?? GeolocatorIncidentLocationFeed();
  StreamSubscription<dynamic>? _changes;
  StreamSubscription<Position>? _positions;
  Timer? _timer;
  Position? _latest;
  final _lastSent = <String, DateTime>{};
  Future<void>? _work;
  bool _requested = false;
  bool _disposed = false;
  int _generation = 0;
  int _sequence = 0;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  void start() {
    if (_disposed || _changes != null) return;
    WidgetsBinding.instance.addObserver(this);
    _changes = database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            database.sosMessages,
            database.rescueInbox,
            database.bleOutbox,
            database.bleRelayMessages,
            database.bleInbox,
          },
        )
        .watch()
        .listen((_) => unawaited(refresh()));
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// No name/address/nearby row establishes ownership. A locally sent SOS or a
  /// locally persisted origin is required; cloud-restored active rows alone do not.
  Future<Map<String, String>> activeTargets() async {
    final result = <String, String>{};
    final victimAllowed = await allowVictimLocation?.call() ?? true;
    final own =
        await (database.select(database.sosMessages)..where(
              (r) => r.ownerId.equals(ownerId) & r.status.equals('active'),
            ))
            .get();
    for (final sos in own) {
      if (!victimAllowed) continue;
      final origin =
          await (database.select(database.bleRelayMessages)
                ..where((r) => r.originMessageId.equals('relay:${sos.id}')))
              .getSingleOrNull();
      if (origin != null) {
        if (origin.incomingPeerId == RelayRepository.localOriginPeerId) {
          result[sos.id] = 'victim';
        }
        continue;
      }
      final outgoing = await (database.select(
        database.bleOutbox,
      )..where((r) => r.sosId.equals(sos.id))).get();
      for (final row in outgoing) {
        try {
          final json = jsonDecode(row.payload);
          if (json is Map &&
              json['kind'] == 'sos.delivery' &&
              json['senderDeviceId'] == localDeviceId) {
            result[sos.id] = 'victim';
            break;
          }
        } on FormatException {
          /* historical malformed rows cannot authorize GPS */
        }
      }
    }
    final accepted =
        await (database.select(database.rescueInbox)..where(
              (r) =>
                  r.ownerId.equals(ownerId) & r.state.equals('locallyAccepted'),
            ))
            .get();
    for (final candidate in accepted) {
      final local =
          await (database.select(database.sosMessages)..where(
                (r) =>
                    r.id.equals(candidate.incidentId) &
                    r.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (local == null || local.status == 'active') {
        result.putIfAbsent(candidate.incidentId, () => 'rescue');
      }
    }
    final localAcceptances =
        await (database.select(database.bleInbox)..where(
              (r) =>
                  r.processingState.equals('local_location_acceptance') &
                  r.acknowledgementStatus.equals('location-owner:$ownerId'),
            ))
            .get();
    for (final accepted in localAcceptances) {
      final local =
          await (database.select(database.sosMessages)..where(
                (r) =>
                    r.id.equals(accepted.sosId) &
                    r.ownerId.equals(ownerId) &
                    r.status.equals('active'),
              ))
              .getSingleOrNull();
      if (local != null &&
          await BleDeliveryRepository(database)
                  .lookupReplyDestination(local.id) !=
              null) {
        result.putIfAbsent(local.id, () => 'rescue');
      }
    }
    return result;
  }

  static Future<void> acceptDirectIncident(
    AppDatabase database,
    String ownerId,
    String incident,
  ) async {
    final id =
        'location-accept:${base64UrlEncode(utf8.encode(ownerId))}:$incident';
    await database
        .into(database.bleInbox)
        .insert(
          BleInboxCompanion.insert(
            messageId: id,
            sosId: incident,
            schemaVersion: 1,
            payload: jsonEncode({'ownerId': ownerId, 'incidentId': incident}),
            processingState: 'local_location_acceptance',
            acknowledgementStatus: Value('location-owner:$ownerId'),
            receivedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    _requested = true;
    return _work ??= _refresh().whenComplete(() => _work = null);
  }

  Future<void> _refresh() async {
    while (_requested && !_disposed) {
      _requested = false;
      try {
        final targets = isCurrent()
            ? await activeTargets()
            : <String, String>{};
        if (_disposed) return;
        _lastSent.removeWhere((id, _) => !targets.containsKey(id));
        if (targets.isEmpty) {
          _generation++;
          await _positions?.cancel();
          _positions = null;
          _latest = null;
          state.value = AutomaticLocationState.idle;
          continue;
        }
        if (_positions == null) {
          // Android's location FGS must be started while an activity is visible.
          // Resume automatically retries if permission/start was unavailable.
          if (!_foreground) continue;
          state.value = AutomaticLocationState.starting;
          await _feed.prepare(mayRequestPermission: _foreground);
          if (_disposed || !isCurrent()) continue;
          final generation = ++_generation;
          _positions = _feed.positions().listen(
            (fix) {
              if (_disposed || generation != _generation || !isCurrent()) {
                return;
              }
              _latest = fix;
              unawaited(onLocationFix?.call().catchError((Object _) {}));
              unawaited(refresh());
            },
            onError: (Object error) {
              unawaited(_positions?.cancel());
              _positions = null;
              if (!_disposed) state.value = AutomaticLocationState.unavailable;
            },
            onDone: () {
              _positions = null;
            },
          );
        }
        final fix = _latest;
        final time = now().toUtc();
        if (fix == null ||
            time.difference(fix.timestamp.toUtc()).abs() >
                const Duration(seconds: 30) ||
            !fix.latitude.isFinite ||
            !fix.longitude.isFinite ||
            fix.latitude.abs() > 90 ||
            fix.longitude.abs() > 180 ||
            (fix.latitude == 0 && fix.longitude == 0)) {
          if (fix != null) state.value = AutomaticLocationState.unavailable;
          continue;
        }
        for (final entry in targets.entries) {
          if (_disposed || !isCurrent()) return;
          if (_lastSent[entry.key]
                  ?.add(const Duration(seconds: 10))
                  .isAfter(time) ==
              true) {
            continue;
          }
          // Recheck after asynchronous permission/GPS work and each preceding send.
          if ((await activeTargets())[entry.key] != entry.value) continue;
          _sequence = (_sequence + 1).clamp(
            time.microsecondsSinceEpoch,
            9007199254740991,
          );
          await publish(entry.key, entry.value, fix, time, _sequence);
          if (_disposed) return;
          _lastSent[entry.key] = time;
          state.value = AutomaticLocationState.sharing;
        }
      } on LocationPermissionRequired {
        if (!_disposed) state.value = AutomaticLocationState.permissionRequired;
      } on Object {
        if (!_disposed) state.value = AutomaticLocationState.unavailable;
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    await _changes?.cancel();
    await _positions?.cancel();
    await _work;
    state.dispose();
  }
}
