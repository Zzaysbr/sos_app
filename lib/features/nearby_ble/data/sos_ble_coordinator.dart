import 'dart:async';

import '../../../core/notifications/chat_notifications.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/database/app_database.dart';
import '../../sos/data/chat_repository.dart';
import '../../sos/data/media_attachment_store.dart';
import '../../sos/data/media_content_validator.dart';
import '../domain/ble_delivery_state.dart';
import '../domain/ble_models.dart';
import '../domain/ble_connection_events.dart';
import '../domain/sos_ble_envelope.dart';
import '../domain/location_ble_envelope.dart';
import '../domain/live_location_envelope.dart';
import '../domain/chat_relay_envelope.dart';
import '../domain/relay_envelope.dart';
import '../domain/incident_lifecycle_envelope.dart';
import '../domain/rescue_response_envelope.dart';
import 'ble_delivery_repository.dart';
import 'ble_protocol.dart';
import 'ble_transport.dart';
import 'incident_presence_coordinator.dart';
import 'automatic_incident_location.dart';
import 'hop_relay_coordinator.dart';
import 'relay_repository.dart';
import 'incident_lifecycle_repository.dart';
import 'relay_diagnostics_repository.dart';
import 'rescue_inbox_repository.dart';
import 'rescue_response_repository.dart';
import 'chat_relay_repository.dart';
import 'chat_receipt_repository.dart';
import 'relay_key_store.dart';
import '../domain/selected_peer_recovery.dart';

typedef SosBleNow = DateTime Function();
typedef SosBleRandom = double Function();
typedef SosBlePeriodicTimer = Timer Function(
  Duration interval,
  void Function(Timer) callback,
);

class _LifecycleForwardLink {
  _LifecycleForwardLink(this.attempt);
  final int? attempt;
  final sentEventIds = <String>{};
  bool failed = false;
  bool replayRequested = false;
  Future<void>? replay;
}

/// Coordinates durable SOS delivery state with the existing BLE transport.
///
/// This class does not own SOS cloud sync and does not claim that a native
/// write is a remote persistence acknowledgement. It is intentionally
/// foreground/best-effort; durable state is retained for a later run.
class SosBleCoordinator with WidgetsBindingObserver {
  SosBleCoordinator({
    required AppDatabase database,
    required this.ownerId,
    this.isSessionCurrent,
    this.requirePeerBinding = false,
    this.manualPeerSelection = false,
    this.automaticLocationEnabled = false,
    this.automaticLocationFeed,
    this.allowAutomaticVictimLocation,
    String? localDeviceId,
    BleTransportClient? transport,
    BleDeliveryRepository? deliveryRepository,
    HopRelayCoordinator? hopRelayCoordinator,
    RelayIdentityService? relayIdentityService,
    RelayProofTimer? relayProofTimer,
    RelayNonceSource? relayNonceSource,
    SosBlePeriodicTimer? periodicTimer,
    this.chatRepository,
    MediaAttachmentStore? attachmentStore,
    this.rescueModeEnabled,
    this.onLog,
    SosBleNow? now,
    SosBleRandom? random,
    this.retryBase = const Duration(seconds: 2),
    this.retryMax = const Duration(minutes: 5),
    this.maxRetryAttempts = 8,
    this.staleAfter = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 5),
  }) : _database = database,
       _localDeviceId = localDeviceId ?? ownerId,
       _transport = transport ?? BleTransport(),
       _ownsTransport = transport == null,
       _deliveryRepository =
           deliveryRepository ?? BleDeliveryRepository(database),
       _now = now ?? DateTime.now,
       _random = random ?? math.Random().nextDouble,
       _periodicTimer = periodicTimer ?? Timer.periodic,
       assert(maxRetryAttempts > 0) {
    _presence = BlePresenceManager.sharedFor(_transport);
    mediaStore = attachmentStore ?? MediaAttachmentStore(ownerId: ownerId);
    _writes = BleMessageWriteQueue.sharedFor(_transport);
    _relayDiagnostics = RelayDiagnosticsRepository(database);
    _hopRelay =
        hopRelayCoordinator ??
        HopRelayCoordinator(
          database: database,
          transport: _transport,
          identityService: relayIdentityService,
          proofTimer: relayProofTimer,
          nonceSource: relayNonceSource,
          now: _now,
          onLog: (message) => _log('relay=$message'),
          rescueModeEnabled: () => isRescueModeEnabled,
          canInitiateConnection: _canInitiateConnection,
          selectedPeers: manualPeerSelection
              ? () => _peerRecovery.connectionCandidates
              : null,
          peerKeyAllowed: _peerRecovery.mayAuthenticate,
          onPeerAuthenticated: _onPeerAuthenticated,
          onRecoveryPeerRejected: _peerRecovery.reject,
          rescueInbox: RescueInboxRepository(database, ownerId: ownerId),
          responseOwnerId: ownerId,
          chatRelayRepository: ChatRelayRepository(database, ownerId: ownerId),
          onChatRelayReceived: _persistRelayedChat,
          onChatRelayForwarded: _markChatRelayForwarded,
          mediaStore: mediaStore,
        );
  }

  final String ownerId;
  late final MediaAttachmentStore mediaStore;
  final bool requirePeerBinding;
  final bool manualPeerSelection;
  final bool automaticLocationEnabled;
  final IncidentLocationFeed? automaticLocationFeed;
  final Future<bool> Function()? allowAutomaticVictimLocation;
  final automaticLocationState = ValueNotifier(AutomaticLocationState.idle);
  AutomaticIncidentLocation? _automaticLocation;
  ValueListenable<AutomaticLocationState>? get automaticLocationStatus =>
      automaticLocationEnabled ? automaticLocationState : null;

  void _locationStateChanged() {
    automaticLocationState.value = _automaticLocation!.state.value;
  }

  Future<void> _publishAutomaticLocation(
    String incident,
    String role,
    Position fix,
    DateTime time,
    int sequence,
  ) async {
    if (!_started || _disposed || !_sessionActive) return;
    final envelope = await createLiveLocationEnvelope(
      sosId: incident,
      participantId: _localDeviceId,
      participantRole: role,
      sequence: sequence,
      latitude: fix.latitude,
      longitude: fix.longitude,
      accuracyMeters: fix.accuracy.isFinite && fix.accuracy >= 0
          ? fix.accuracy
          : null,
      createdAt: time,
      expiresAt: time.add(const Duration(minutes: 2)),
    );
    if ((await _automaticLocation?.activeTargets())?[incident] != role) return;
    // Live state is coalesced, never appended to the durable Chat/media queue.
    // A disconnected route gets the next fresh fix instead of stale GPS backlog.
    for (final route in _hopRelay.currentAuthenticatedRoutes().values) {
      if (!route.isCurrent() || !_started || _disposed || !_sessionActive) {
        continue;
      }
      if ((await _automaticLocation?.activeTargets())?[incident] != role) {
        return;
      }
      try {
        await _writes.sendFrames(
          route.deviceId,
          BleMessageCodec.encode(
            envelope.toBleMessage(),
            maxFrameBytes: await negotiatedBleFrameBytes(
              _transport,
              route.deviceId,
              route.role,
            ),
          ),
          role: route.role,
          canSend: () =>
              route.isCurrent() && _started && !_disposed && _sessionActive,
        );
      } on Object {
        // A failed neighbor must not prevent fresh state reaching another path.
        _log('automaticLocationNextHopUnavailable');
      }
    }
  }

  final _peerRecovery = SelectedPeerRecovery();

  /// Presentation-only alias grouping; never infer identity from model or hint.
  String? verifiedPeerKey(String peer) => _hopRelay.verifiedKeyForLocator(peer);

  bool _canInitiateConnection(String peer) =>
      !manualPeerSelection ||
      _peerRecovery.mayInitiate(
        peer,
        hasProvenRoute: _hopRelay.hasProvenLinkForKey,
      );

  Future<void> connectSelectedPeer(String peer) async {
    _ensureUsable();
    if (peer.trim().isEmpty || !_sessionActive) return;
    final known = _hopRelay.verifiedKeyForLocator(peer);
    if (known != null && _hopRelay.hasProvenLinkForLocator(peer)) {
      _peerRecovery.selectProven(peer, known);
      final route = _hopRelay.authenticatedRouteForKey(known);
      if (route != null) {
        _peerRecovery.selectProven(route.deviceId, known);
        final link =
            _lifecycleLinks['${route.deviceId}|${route.role.wireValue}'];
        if (link != null) {
          unawaited(
            _activateDirectConnection(
              route.deviceId,
              route.role,
              link,
            ).catchError((Object _) {
              _log('recoveryDirectActivationFailed');
            }),
          );
        }
      }
      return;
    }
    _peerRecovery.select(peer);
    await _transport.connect(peer);
  }

  Future<void> disconnectSelectedPeer(String peer) async {
    _ensureUsable();
    if (peer.trim().isEmpty || !_sessionActive) return;
    _peerRecovery.forget(peer);
    await _transport.disconnect(peer);
  }

  final bool Function()? isSessionCurrent;
  bool get _sessionActive => isSessionCurrent?.call() ?? true;
  final AppDatabase _database;
  final String _localDeviceId;
  final BleTransportClient _transport;
  late final BlePresenceManager _presence;
  late final BleMessageWriteQueue _writes;
  late final RelayDiagnosticsRepository _relayDiagnostics;
  final bool _ownsTransport;
  final BleDeliveryRepository _deliveryRepository;
  final ChatRepository? chatRepository;
  final bool Function()? rescueModeEnabled;
  bool _localRescueModeEnabled = false;

  void setRescueModeEnabled(bool enabled) {
    _localRescueModeEnabled = enabled;
  }

  bool get isRescueModeEnabled =>
      rescueModeEnabled?.call() ?? _localRescueModeEnabled;
  final void Function(String message)? onLog;
  final SosBleNow _now;
  final SosBleRandom _random;
  final SosBlePeriodicTimer _periodicTimer;
  late final HopRelayCoordinator _hopRelay;
  late final _incidentPresence = IncidentPresenceCoordinator(
    database: _database,
    ownerId: ownerId,
    relay: _hopRelay,
    now: _now,
    isCurrent: () =>
        _started && !_disposed && _sessionActive && !_adapterUnavailable,
    directDestinationKey: _directPresenceDestination,
    directOrigin: _directPresenceOrigin,
  );
  ValueListenable<Set<String>>? get reachableIncidents =>
      _incidentPresence.reachable;

  Future<String?> _directPresenceDestination(String incident) async {
    if (await _deliveryRepository.lookupReplyDestination(incident) != null) {
      return null;
    }
    final peer = await _deliveryRepository.lookupIncidentDestination(incident);
    final key = peer == null ? null : _hopRelay.verifiedKeyForLocator(peer);
    final route = key == null ? null : _hopRelay.authenticatedRouteForKey(key);
    return route == null || !_peerBindings.containsKey(route.deviceId)
        ? null
        : key;
  }

  Future<({String keyId, DateTime createdAt})?> _directPresenceOrigin(
    String incident,
    String peer,
  ) async {
    if (await _deliveryRepository.lookupReplyDestination(incident) == null) {
      return null;
    }
    final sender = await _deliveryRepository.lookupIncidentPeerIdentity(
      incident,
    );
    if (sender == null || _peerBindings[peer] != sender) return null;
    final key = _hopRelay.verifiedKeyForLocator(peer);
    final row =
        await (_database.select(_database.sosMessages)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.id.equals(incident) &
                  row.status.equals('active'),
            ))
            .getSingleOrNull();
    return key == null || row == null
        ? null
        : (keyId: key, createdAt: row.createdAt);
  }

  final Duration retryBase;
  final Duration retryMax;

  /// Failed rows remain in the outbox, but are expired after this many
  /// attempts so an unreachable destination cannot monopolize the drain.
  final int maxRetryAttempts;
  final Duration staleAfter;
  final Duration pollInterval;

  Future<void> _persistRelayedChat(ChatRelayEnvelope envelope) async {
    final repository = chatRepository;
    if (repository == null) return;
    // Incoming emergency text may precede the Rescue user's opening or
    // accepting the candidate. Materialize its verified incident for local
    // Chat storage without creating a help offer or changing Helping state.
    final origin = await RelayRepository(database: _database)
        .lookupMessage('relay:${envelope.body.incidentId}');
    if (origin != null) {
      final body = RelayOfferEnvelope.fromCanonicalWire(origin.wireEnvelope)
          .body;
      await _database
          .into(_database.sosMessages)
          .insert(
            SosMessagesCompanion.insert(
              id: body.incidentId,
              ownerId: ownerId,
              type: body.emergencyType,
              message: Value(body.emergencyMessage),
              latitude: Value(body.latitude),
              longitude: Value(body.longitude),
              status: 'active',
              syncState: 'deviceOnly',
              createdAt: body.createdAt,
              updatedAt: body.createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    if (envelope.body.media != null) {
      final file = await mediaStore.find(envelope.body.messageId);
      if (file == null || !file.complete || !await file.file.exists()) return;
      if (repository is! PersistentChatRepository) {
        throw const RelayProtocolException('Media repository unavailable');
      }
      await validateChatMediaFile(file.file, file.manifest.mime);
      if (_disposed || !_sessionActive) return;
      await repository.insertIncomingMessage(
        messageId: envelope.body.messageId,
        sosId: envelope.body.incidentId,
        senderId: envelope.body.senderKeyId,
        recipientId: ownerId,
        text: envelope.body.text,
        createdAt: envelope.body.createdAt,
        attachmentPath: file.file.path,
        attachmentMimeType: file.manifest.mime,
        attachmentName: file.manifest.mime.startsWith('image/')
            ? 'Photo'
            : 'Video',
      );
      return;
    }
    await repository.insertIncomingMessage(
      messageId: envelope.body.messageId,
      sosId: envelope.body.incidentId,
      senderId: envelope.body.senderKeyId,
      recipientId: ownerId,
      text: envelope.body.text,
      createdAt: envelope.body.createdAt,
    );
    _log(
      'chat_destination_persisted messageId=${envelope.body.messageId} '
      'incident=${envelope.body.incidentId}',
    );
  }

  Future<void> _markChatRelayForwarded(String messageId) async {
    final repository = chatRepository;
    if (repository == null) return;
    // This callback means a native write to an authenticated next hop only.
    // A separate verified recipient receipt marks delivered; the repository
    // keeps that state monotonic if this write callback finishes later.
    final timer = _chatTimers[messageId];
    _log(
      'chat_relay_forwarded messageId=$messageId'
      '${timer == null ? '' : ' elapsedMs=${timer.elapsedMilliseconds}'}',
    );
    try {
      await repository.updateDeliveryStatus(messageId, ChatDeliveryStatus.sent);
    } on Object {
      // Relay-only copies on an intermediate device do not have a local Chat
      // row. Their durable relay state remains authoritative and must not be
      // turned into a failed transport job because the UI row is absent.
    }
  }

  final _bindingRetries = <String, Timer>{};
  final _chatTimers = <String, Stopwatch>{};
  final _peerBindings = <String, String>{};
  final _peerChallenges = <String, String>{};
  final _bindingWaiters = <String, Completer<void>>{};

  final _assemblers = <String, BleMessageAssembler>{};
  final _connectionEvents = BleConnectionEvents();
  final _connected = <String, Set<BleSessionRole>>{};
  final _lifecycleLinks = <String, _LifecycleForwardLink>{};
  final _connecting = <String>{};
  final _inflightDeliveries = <String, Future<bool>>{};
  final _sendingMessages = <String>{};
  final _pendingConnectionMessages = <String, Set<String>>{};
  final _locationSharing = <String, String>{};
  StreamSubscription<BleEvent>? _eventsSubscription;
  Timer? _pollTimer;
  Future<void>? _drainFuture;
  Future<void>? _disposeFuture;
  Future<void>? _startFuture;
  bool _started = false;
  bool _disposed = false;
  bool _drainRequested = false;
  bool _adapterUnavailable = false;

  bool get isStarted => _started;

  RelayDiagnosticsDataSource get relayDiagnosticsDataSource =>
      _relayDiagnostics;

  RelayRuntimeDiagnosticsDataSource get relayRuntimeDiagnosticsDataSource =>
      _hopRelay.runtimeDiagnostics;

  Stream<BleOutboxData?> watchLocationDeliveryForSos(String sosId) =>
      _deliveryRepository.watchLocationDeliveryForSos(sosId);

  /// Returns only a location update from the peer that established the
  /// incident reply route. Without that route, presenting a nearby peer's
  /// coordinates would be unsafe and ambiguous.
  Future<LocationBleEnvelope?> latestIncomingLocation(String sosId) async {
    final identity = await _deliveryRepository.lookupIncidentPeerIdentity(
      sosId,
    );
    if (identity != null) {
      return _deliveryRepository.latestIncomingLocation(
        sosId,
        requiredSenderIdentity: identity,
      );
    }
    final sender = await _deliveryRepository.lookupIncidentDestination(sosId);
    if (sender == null) return null;
    return _deliveryRepository.latestIncomingLocation(
      sosId,
      requiredSenderDeviceId: sender,
    );
  }

  Stream<LocationBleEnvelope?> watchIncomingLocation(String sosId) async* {
    final identity = await _deliveryRepository.lookupIncidentPeerIdentity(
      sosId,
    );
    if (identity != null) {
      yield* _deliveryRepository.watchIncomingLocation(
        sosId,
        requiredSenderIdentity: identity,
      );
      return;
    }
    final sender = await _deliveryRepository.lookupIncidentDestination(sosId);
    if (sender == null) {
      yield null;
      return;
    }
    yield* _deliveryRepository.watchIncomingLocation(
      sosId,
      requiredSenderDeviceId: sender,
    );
  }

  Stream<LiveLocationEnvelope?> watchLiveLocation(String sosId) =>
      (_database.select(
        _database.bleInbox,
      )..where((r) => r.sosId.equals(sosId))).watch().asyncMap((rows) async {
        final origin = await IncidentLifecycleRepository(
          _database,
          ownerId: ownerId,
        ).trustedOriginForPresence(sosId, _now());
        final responses =
            await (_database.select(_database.rescueResponseInbox)..where(
                  (r) =>
                      r.ownerId.equals(ownerId) &
                      r.incidentId.equals(sosId) &
                      r.state.equals('verified'),
                ))
                .get();
        final directPeer = origin == null
            ? await _deliveryRepository.lookupIncidentDestination(sosId)
            : null;
        final directKey = directPeer == null
            ? null
            : _hopRelay.verifiedKeyForLocator(directPeer);
        final directVictim = directPeer == null
            ? null
            : await _directPresenceOrigin(sosId, directPeer);
        final localKey = await existingRelayKeyId();
        LiveLocationEnvelope? newest;
        for (final row in rows) {
          try {
            final live = LiveLocationEnvelope.fromJson(
              Map<String, Object?>.from(jsonDecode(row.payload) as Map),
            );
            if (live.originKeyId == localKey ||
                live.createdAt.isAfter(
                  _now().toUtc().add(const Duration(seconds: 30)),
                )) {
              continue;
            }
            final bound = live.participantRole == 'victim'
                ? (origin?.keyId ?? directVictim?.keyId) == live.originKeyId
                : responses.any((r) => r.responderKeyId == live.originKeyId) ||
                      (origin == null &&
                          directVictim == null &&
                          directKey != null &&
                          directKey == live.originKeyId);
            if (!bound ||
                !await _hopRelay.verifyLiveLocation(live, allowExpired: true)) {
              continue;
            }
            if (newest == null ||
                live.createdAt.isAfter(newest.createdAt) ||
                (live.createdAt == newest.createdAt &&
                    live.sequence > newest.sequence)) {
              newest = live;
            }
          } on Object {
            /* Unrelated/invalid history cannot create a participant. */
          }
        }
        return newest;
      });

  /// The shared transport owned by this coordinator.
  ///
  /// Debug/test screens may subscribe to this client, but they must not
  /// dispose it while the coordinator is active.
  BleTransportClient get transport => _transport;

  bool get relayParticipationEnabled => _hopRelay.participationEnabled;

  Future<bool> hasPendingPublicRelay() => _hopRelay.hasPendingLocalOrigin();

  Future<void> setRelayParticipationEnabled(bool enabled) =>
      _hopRelay.setParticipationEnabled(enabled);

  Future<void> enqueuePublicRelay(
    SosMessage sos, {
    required bool includeLocation,
    RelayAuthorizationScope scope =
        RelayAuthorizationScope.publicEmergencyRelay,
  }) async {
    _ensureUsable();
    await _hopRelay.queuePublicEmergency(
      sos,
      includeLocation: includeLocation,
      scope: scope,
    );
    if (_started) unawaited(processDue());
  }

  Future<void> cancelPublicRelay(String sosId) async {
    _ensureUsable();
    await _hopRelay.cancelPublicEmergency(sosId);
    if (_started) unawaited(processDue());
  }

  /// Publishes an origin-signed terminal lifecycle event through the durable
  /// BLE outbox. Local repository state is updated by the caller first; this
  /// method only handles authenticated transport propagation.
  Future<void> enqueueIncidentLifecycle({
    required String sosId,
    required String status,
    String? destinationId,
  }) async {
    _ensureUsable();
    final identity = await _hopRelay.signingIdentity();
    final envelope = await IncidentLifecycleEnvelope.sign(
      incidentId: sosId,
      status: status,
      identity: identity,
      now: _now(),
    );
    await envelope.validate(now: _now());
    var destination = destinationId?.trim();
    destination ??= await _deliveryRepository.lookupIncidentDestination(sosId);
    if ((destination == null || destination.isEmpty) &&
        _peerBindings.isNotEmpty) {
      final eligible = _peerBindings.keys.where(
        (peer) => _connected[peer]?.isNotEmpty == true,
      );
      destination = eligible.isEmpty ? null : eligible.first;
    }
    await _deliveryRepository.enqueueRaw(
      envelope.toBleMessage(),
      sosId: sosId,
      destinationId: destination,
      now: _now(),
    );
    if (_started) unawaited(processDue());
    _log('lifecycle_enqueued incident=$sosId status=$status');
  }

  Future<String?> existingRelayKeyId() => _hopRelay.existingSigningKeyId();

  Future<LiveLocationEnvelope> createLiveLocationEnvelope({
    required String sosId,
    required String participantId,
    required String participantRole,
    required int sequence,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
    required DateTime expiresAt,
    double? accuracyMeters,
  }) async {
    _ensureUsable();
    final identity = await _hopRelay.signingIdentity();
    final unsigned = LiveLocationEnvelope(
      messageId: 'live-location:$sosId:$participantId:$sequence',
      sosId: sosId,
      participantId: participantId,
      participantRole: participantRole,
      originKeyId: identity.keyId,
      originPublicKey: base64UrlEncode(identity.publicKey),
      originSignature: 'pending',
      sequence: sequence,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      createdAt: createdAt.toUtc(),
      expiresAt: expiresAt.toUtc(),
    );
    final signature = await RelayCryptography().signLiveLocationBody(
      unsigned.bodyMap(),
      identity.keyPair,
    );
    return LiveLocationEnvelope(
      messageId: unsigned.messageId,
      sosId: unsigned.sosId,
      participantId: unsigned.participantId,
      participantRole: unsigned.participantRole,
      originKeyId: unsigned.originKeyId,
      originPublicKey: unsigned.originPublicKey,
      originSignature: signature,
      sequence: unsigned.sequence,
      latitude: unsigned.latitude,
      longitude: unsigned.longitude,
      accuracyMeters: unsigned.accuracyMeters,
      createdAt: unsigned.createdAt,
      expiresAt: unsigned.expiresAt,
    );
  }

  Future<void> enqueueLiveLocation({
    required LiveLocationEnvelope envelope,
    required String destinationId,
  }) async {
    _ensureUsable();
    envelope.validate(now: _now());
    await _deliveryRepository.enqueueRaw(
      envelope.toBleMessage(),
      sosId: envelope.sosId,
      destinationId: destinationId,
      now: _now(),
    );
    if (_started) unawaited(processDue());
  }

  Stream<RelayStatusSnapshot> watchRelayStatus(String incidentId) =>
      _hopRelay.watchStatus(incidentId);

  Future<void> start() {
    if (_disposed) throw StateError('A disposed BLE coordinator cannot start.');
    return _startFuture ??= _start().whenComplete(() => _startFuture = null);
  }

  Future<void> _start() async {
    if (_disposed) throw StateError('A disposed BLE coordinator cannot start.');
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _eventsSubscription = _transport.events.listen(
      _onEvent,
      onError: (Object error, StackTrace stack) =>
          _log('BLE stream error: $error'),
    );
    try {
      _log('requesting BLE permissions');
      await _transport.requestPermissions();
      if (_disposed || !_sessionActive) return;
      unawaited(const ChatNotifications().requestPermission());
      _log('BLE permissions granted');
      await _transport.initialize();
      if (_disposed || !_sessionActive) return;
      _log('BLE transport initialized');
      try {
        await _hopRelay.start();
      } catch (error) {
        // A persisted relay job may be unreadable when secure key storage is
        // temporarily unavailable after restart. Disable relay processing for
        // this coordinator run, but keep Direct SOS v1 available.
        _log('relayStartupDisabled reason=$error');
        try {
          await _hopRelay.stop();
        } on Object {
          _log('relayStartupCleanupFailed');
        }
      }
      final now = _now().toUtc();
      await IncidentLifecycleRepository(
        _database,
        ownerId: ownerId,
      ).reconcilePending(now: now);
      await _deliveryRepository.recoverStaleOutbox(
        ownerId: isSessionCurrent == null ? null : ownerId,
        olderThan: now.subtract(staleAfter),
        nextRetryAt: now,
        now: now,
      );
      _pollTimer = _periodicTimer(pollInterval, (_) => unawaited(processDue()));
      if (automaticLocationEnabled) {
        _automaticLocation = AutomaticIncidentLocation(
          database: _database,
          ownerId: ownerId,
          localDeviceId: _localDeviceId,
          publish: _publishAutomaticLocation,
          feed: automaticLocationFeed,
          allowVictimLocation: allowAutomaticVictimLocation,
          isCurrent: () => _started && !_disposed && _sessionActive,
          onLocationFix: processDue,
          now: _now,
        )..state.addListener(_locationStateChanged);
        _automaticLocation!.start();
      }
      await processDue();
    } catch (_) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _drainRequested = false;
    _adapterUnavailable = false;
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pollTimer = null;
    final location = _automaticLocation;
    _automaticLocation = null;
    location?.state.removeListener(_locationStateChanged);
    await location?.dispose();
    automaticLocationState.value = AutomaticLocationState.idle;
    await _hopRelay.stop();
    _incidentPresence.clear();
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _connected.clear();
    _lifecycleLinks.clear();
    _connectionEvents.clear();
    _connecting.clear();
    _pendingConnectionMessages.clear();
    _assemblers.clear();
    for (final timer in _bindingRetries.values) {
      timer.cancel();
    }
    _bindingRetries.clear();
    _peerBindings.clear();
    _peerChallenges.clear();
    for (final waiter in _bindingWaiters.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _bindingWaiters.clear();
    final sharingSosIds = _locationSharing.keys.toList(growable: false);
    _locationSharing.clear();
    for (final sosId in sharingSosIds) {
      await _deliveryRepository.expireLocationOutbox(
        sosId,
        reason: 'Location sharing stopped with BLE coordinator.',
      );
    }
    await _drainFuture;
  }

  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    _disposed = true;
    await stop();
    if (_ownsTransport) await _transport.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(const ChatNotifications().requestPermission());
    }
    unawaited(_applyExecutionState(state == AppLifecycleState.resumed));
  }

  Future<void> _applyExecutionState(bool foreground) async {
    try {
      await _presence.setForeground(foreground);
      final transport = _transport is BleBackgroundExecution
          ? _transport as BleBackgroundExecution
          : null;
      final allowed =
          foreground || (transport?.backgroundExecutionEnabled ?? false);
      await _hopRelay.setForeground(allowed);
      if (allowed && _started && !_disposed && _sessionActive) {
        await processDue();
      }
    } on Object {
      _log('blePresenceLifecycleReconcileFailed');
    }
  }

  Future<BleOutboxData> enqueueSos(
    SosMessage sos, {
    String? destinationId,
    String? messageId,
  }) async {
    _ensureUsable();
    final envelope = SosBleEnvelope.fromSosMessage(
      sos,
      messageId: messageId ?? 'sos:${sos.id}:delivery:v1',
      senderDeviceId: requirePeerBinding ? _localDeviceId : null,
    );
    final row = await _deliveryRepository.enqueueOutbox(
      envelope,
      destinationId: destinationId,
      now: _now(),
    );
    _log(
      'enqueue sosId=${envelope.sosId} messageId=${row.messageId} '
      'state=${row.state}',
    );
    if (_started) unawaited(processDue());
    return row;
  }

  Stream<BleOutboxData?> watchDeliveryForSos(String sosId) {
    return _deliveryRepository.watchDeliveryForSos(sosId);
  }

  Future<BleOutboxData> assignSosDestination(
    String sosId,
    String destinationId,
  ) async {
    _ensureUsable();
    final messageId = 'sos:$sosId:delivery:v1';
    var row = await _deliveryRepository.lookupOutbox(messageId);
    if (row == null) {
      await _deliveryRepository.reconcileMissingSosOutbox(
        ownerId: ownerId,
        now: _now(),
      );
      row = await _deliveryRepository.lookupOutbox(messageId);
    }
    if (row == null) {
      throw const BleDeliveryStateException(
        'No durable BLE delivery exists for this SOS.',
      );
    }
    final assigned = await _deliveryRepository.assignDestinationIfMissing(
      messageId,
      destinationId,
      now: _now(),
    );
    if (_started) unawaited(processDue());
    _log('assigned destination sosId=$sosId peer=${assigned.destinationId}');
    return assigned;
  }

  Future<BleOutboxData> enqueueChat(
    EmergencyChatMessage chat, {
    String? destinationId,
    String? senderDeviceId,
  }) async {
    _ensureUsable();
    final resolvedDestination =
        destinationId ??
        chat.recipientId ??
        await _deliveryRepository.lookupIncidentDestination(chat.sosId);
    final envelope = SosBleEnvelope.chatMessage(
      messageId: chat.id,
      sosId: chat.sosId,
      senderDeviceId: senderDeviceId ?? _localDeviceId,
      chatSenderId: chat.senderId,
      chatText: chat.text,
      createdAt: chat.createdAt,
    );
    final row = await _deliveryRepository.enqueueOutbox(
      envelope,
      destinationId: resolvedDestination,
      now: _now(),
    );
    _log(
      'enqueue chat sosId=${chat.sosId} messageId=${chat.id} state=${row.state}',
    );
    if (_started) unawaited(processDue());
    return row;
  }

  /// Queues an authenticated, durable multi-hop Chat message. The final
  /// recipient key must come from an already verified rescue binding; this
  /// method intentionally does not derive trust from a BLE address/name.
  Future<void> enqueueChatThroughRelay({
    required EmergencyChatMessage chat,
    required String recipientKeyId,
    required String recipientPublicKey,
  }) async {
    _ensureUsable();
    final timer = Stopwatch()..start();
    _chatTimers[chat.id] = timer;
    _log('chat_send_started messageId=${chat.id} incident=${chat.sosId}');
    final media = chat.attachmentPath == null
        ? null
        : await mediaStore.find(chat.id);
    if (chat.attachmentPath != null && (media == null || !media.complete)) {
      throw const BleDeliveryStateException('Media file unavailable');
    }
    await _hopRelay.signAndEnqueueChatRelay(
      messageId: chat.id,
      incidentId: chat.sosId,
      recipientKeyId: recipientKeyId,
      recipientPublicKey: recipientPublicKey,
      text: chat.text,
      createdAt: chat.createdAt,
      media: media?.manifest,
    );
    _log(
      'chat_relay_enqueued messageId=${chat.id} incident=${chat.sosId} '
      'elapsedMs=${timer.elapsedMilliseconds}',
    );
  }

  /// Returns only a cryptographically bound incident participant. The value
  /// never comes from a BLE address, display name, or picker row.
  Future<({String keyId, String publicKey})?> resolveVerifiedChatParticipant(
    String incidentId,
  ) async {
    _ensureUsable();
    final responseBinding = await RescueResponseRepository(
      _database,
      ownerId: ownerId,
    ).verifiedResponderBindingForIncident(incidentId);
    if (responseBinding != null) return responseBinding;
    final origin = await RelayRepository(database: _database)
        .lookupMessage('relay:$incidentId');
    if (origin == null) return null;
    final body = RelayOfferEnvelope.fromCanonicalWire(origin.wireEnvelope).body;
    final localIdentity = await _hopRelay.signingIdentity();
    if (body.originKeyId == localIdentity.keyId) {
      final receipts =
          await (_database.select(_database.bleRelayReceipts)
                ..where((r) => r.incidentId.equals(incidentId))
                ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
              .get();
      for (final row in receipts) {
        final receipt = RelayReceiptEnvelope.fromJson(
          Map<String, Object?>.from(jsonDecode(row.payload) as Map),
        );
        if (receipt.originMessageId != body.originMessageId ||
            receipt.immutableDigest !=
                await RelayCryptography().immutableDigest(body) ||
            !await RelayCryptography().verifyReceipt(receipt)) {
          continue;
        }
        return (keyId: receipt.signerKeyId, publicKey: receipt.signerPublicKey);
      }
      // The victim's own signed SOS proves its identity, not the rescuer's.
      // Stop here rather than routing its reply to itself or falling back to
      // an unrelated direct BLE destination in the Chat send callback.
      throw const BleDeliveryStateException(
        'Waiting for a device to confirm receiving this SOS.',
      );
    }
    return (keyId: body.originKeyId, publicKey: body.originPublicKey);
  }

  Future<bool> canSendMedia(String incidentId) async {
    if (_disposed || !_sessionActive) return false;
    final row =
        await (_database.select(_database.sosMessages)..where(
              (r) => r.ownerId.equals(ownerId) & r.id.equals(incidentId),
            ))
            .getSingleOrNull();
    if (row == null || row.status != 'active') return false;
    try {
      final ownOrigin = await RelayRepository(database: _database)
          .lookupMessage('relay:$incidentId');
      if (ownOrigin != null &&
          ownOrigin.originKeyId == (await _hopRelay.signingIdentity()).keyId &&
          await RescueResponseRepository(
                _database,
                ownerId: ownerId,
              ).verifiedResponderBindingForIncident(incidentId) ==
              null) {
        return false;
      }
      return await resolveVerifiedChatParticipant(incidentId) != null;
    } on Object {
      return false;
    }
  }

  Future<int> assignPendingChatDestination(
    String sosId,
    String destinationId,
  ) async {
    _ensureUsable();
    final assigned = await _deliveryRepository.assignUnroutedChatDestination(
      ownerId: ownerId,
      sosId: sosId,
      destinationId: destinationId,
      now: _now(),
    );
    if (assigned > 0 && _started) unawaited(processDue());
    _log(
      'assigned pending Chat destination sosId=$sosId '
      'peer=${destinationId.trim()} count=$assigned',
    );
    return assigned;
  }

  /// Enables explicit-recipient sharing for one active SOS. This phase only
  /// publishes caller-supplied fixes; it does not start GPS polling.
  Future<void> enableLocationSharing({
    required String sosId,
    required String destinationId,
  }) async {
    _ensureUsable();
    final destination = destinationId.trim();
    if (destination.isEmpty) {
      throw const BleDeliveryStateException(
        'A location recipient is required.',
      );
    }
    final sos =
        await (_database.select(_database.sosMessages)..where(
              (table) => table.id.equals(sosId) & table.ownerId.equals(ownerId),
            ))
            .getSingleOrNull();
    if (sos == null || sos.status != 'active') {
      throw const BleDeliveryStateException(
        'Location sharing requires an active SOS.',
      );
    }
    _locationSharing[sosId] = destination;
    _log('locationSharingEnabled sosId=$sosId peer=$destination');
  }

  Future<void> disableLocationSharing(String sosId) async {
    _locationSharing.remove(sosId);
    await _deliveryRepository.expireLocationOutbox(sosId);
    _log('locationSharingDisabled sosId=$sosId');
  }

  Future<BleOutboxData> publishLocationUpdate({
    required String sosId,
    required String messageId,
    required String destinationId,
    required double latitude,
    required double longitude,
    required DateTime expiresAt,
    double? accuracyMeters,
    String? senderDeviceId,
    DateTime? createdAt,
  }) async {
    _ensureUsable();
    final destination = destinationId.trim();
    if (_locationSharing[sosId] != destination) {
      throw const BleDeliveryStateException(
        'Location sharing is not enabled for this recipient.',
      );
    }
    final sos =
        await (_database.select(_database.sosMessages)..where(
              (table) => table.id.equals(sosId) & table.ownerId.equals(ownerId),
            ))
            .getSingleOrNull();
    if (sos == null || sos.status != 'active') {
      await disableLocationSharing(sosId);
      throw const BleDeliveryStateException('SOS is no longer active.');
    }
    if (requirePeerBinding) await _waitForPeerBinding(destination);
    final envelope = LocationBleEnvelope.update(
      messageId: messageId,
      sosId: sosId,
      senderDeviceId: senderDeviceId ?? _localDeviceId,
      recipientId: requirePeerBinding
          ? _peerBindings[destination]!
          : destination,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      createdAt: (createdAt ?? _now()).toUtc(),
      expiresAt: expiresAt.toUtc(),
    );
    final row = await _deliveryRepository.enqueueLocationOutbox(
      envelope,
      destinationId: destination,
      now: _now(),
      expectedRecipientId: requirePeerBinding
          ? _peerBindings[destination]
          : null,
    );
    if (_started) unawaited(processDue());
    _log('locationQueued sosId=$sosId messageId=$messageId peer=$destination');
    return row;
  }

  /// Resume an origin-owned terminal job without opting into public relaying
  /// or requiring the user to create another SOS just to repair an old route.
  Future<bool> hasPendingBleRecovery() async {
    if (_disposed || !_sessionActive) return false;
    if (await hasPendingLifecycleRecovery() ||
        await ChatReceiptRepository(_database, ownerId).hasLiveWork(_now())) {
      return true;
    }
    // The sender's media file is already complete, so incomplete-file and
    // inbound-receipt checks alone miss an outgoing job after process restart.
    // Include live backoff, but never revive expired/exhausted/superseded work.
    final outgoing =
        await (_database.select(_database.chatRelayOutbox)
              ..where(
                (r) =>
                    r.ownerId.equals(ownerId) &
                    r.expiresAt.isBiggerThanValue(_now()) &
                    r.state.isNotIn(const ['delivered', 'expired']) &
                    r.retryCount.isSmallerThanValue(
                      ChatRelayRepository.maximumAttempts,
                    ),
              )
              ..limit(1))
            .getSingleOrNull();
    return outgoing != null || (await mediaStore.pending(_now())).isNotEmpty;
  }

  Future<bool> hasPendingLifecycleRecovery() async {
    if (_disposed || !_sessionActive) return false;
    final row = await _database
        .customSelect(
          """
      SELECT 1 FROM ble_outbox o JOIN sos_messages s ON s.id = o.sos_id
      WHERE s.owner_id = ? AND s.status IN ('cancelled', 'resolved')
        AND ((o.state IN ('queued', 'failed') AND o.retry_count < ?)
          OR (s.status = 'cancelled' AND o.state = 'expired'
            AND o.last_error LIKE 'retry limit reached: Bluetooth adapter state is %'))
        AND o.payload LIKE '%"kind":"sos.lifecycle.v1"%'
        AND EXISTS (SELECT 1 FROM rescue_response_inbox r
          WHERE r.owner_id = s.owner_id AND r.incident_id = s.id AND r.state = 'verified')
      LIMIT 1
    """,
          variables: [
            Variable<String>(ownerId),
            Variable<int>(maxRetryAttempts),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<void> processDue() async {
    if (!_started || _disposed || !_sessionActive) return;
    await _recoverMediaEnqueue();
    _hopRelay.setPendingLocalControlWork(await hasPendingLifecycleRecovery());
    await _hopRelay.processDue();
    unawaited(
      _incidentPresence.tick().catchError((Object _) {
        _log('incidentPresenceTickUnavailable');
      }),
    );
    _drainRequested = true;
    if (_drainFuture != null) return _drainFuture!;
    final future = _drain();
    _drainFuture = future;
    await future;
  }

  bool _recoveringMedia = false;
  Future<void> _recoverMediaEnqueue() async {
    if (_recoveringMedia) return;
    _recoveringMedia = true;
    try {
      final pending =
          await (_database.select(_database.chatMessages)
                ..where(
                  (r) =>
                      r.ownerId.equals(ownerId) &
                      r.deliveryStatus.equals('pending'),
                )
                ..limit(2))
              .get();
      for (final row in pending) {
        if (!_started || _disposed || !_sessionActive) return;
        if (await ChatRelayRepository(
              _database,
              ownerId: ownerId,
            ).findOutbox(row.messageId) !=
            null) {
          continue;
        }
        if (!row.createdAt.add(const Duration(minutes: 30)).isAfter(_now())) {
          continue;
        }
        if (row.messageType == 'media' && !await canSendMedia(row.sosId)) {
          continue;
        }
        ({String keyId, String publicKey})? recipient;
        try {
          recipient = await resolveVerifiedChatParticipant(row.sosId);
        } on BleDeliveryStateException {
          continue;
        }
        if (recipient == null) continue;
        await enqueueChatThroughRelay(
          chat: EmergencyChatMessage(
            id: row.messageId,
            sosId: row.sosId,
            senderId: row.senderId,
            text: row.textContent ?? 'Attachment',
            createdAt: row.createdAt,
            status: ChatDeliveryStatus.pending,
            isMine: true,
            attachmentPath: row.attachmentPath,
            attachmentMimeType: row.attachmentMimeType,
            attachmentName: row.attachmentName,
          ),
          recipientKeyId: recipient.keyId,
          recipientPublicKey: recipient.publicKey,
        );
      }
    } on Object {
      // Keep the same persisted message identity for the next bounded retry.
    } finally {
      _recoveringMedia = false;
    }
  }

  Future<void> _drain() async {
    try {
      while (_drainRequested && _started && !_disposed) {
        _drainRequested = false;
        final now = _now().toUtc();
        if (!_adapterUnavailable && _sessionActive) {
          await _recoverAdapterExpiredCancellations(now);
        }
        await _deliveryRepository.recoverStaleOutbox(
          ownerId: isSessionCurrent == null ? null : ownerId,
          olderThan: now.subtract(staleAfter),
          nextRetryAt: now,
          now: now,
        );
        try {
          final recovered = await _deliveryRepository.reconcileMissingSosOutbox(
            ownerId: ownerId,
            now: now,
          );
          if (recovered > 0) {
            _log('reconciledMissingBleOutbox count=$recovered');
          }
        } catch (error) {
          // A transient database failure is retried on the next drain; it
          // must not turn a locally persisted SOS into a lost delivery.
          _log('BLE outbox reconciliation failed: $error');
        }
        final rows = await _deliveryRepository.dueOutbox(
          now: now,
          ownerId: isSessionCurrent == null ? null : ownerId,
        );
        for (final row in rows) {
          if (!_started || _disposed || !_sessionActive) break;
          await _trySend(row);
        }
        try {
          await _hopRelay.processDue();
        } on Object {
          // Relay v2 is additive. Corrupt relay-only persistence or a relay
          // transport failure must not escape through the Direct v1 drain.
          _log('relayDrainFailed');
        }
      }
    } finally {
      _drainFuture = null;
      if (_drainRequested && _started && !_disposed) unawaited(processDue());
    }
  }

  Future<AuthenticatedRelayRoute?> _recoverLifecycleRoute(
    BleOutboxData row,
  ) async {
    final event = _decodeLifecycleEnvelope(row.payload);
    if (event == null) return null;
    try {
      await event.validate(now: _now());
      final incident =
          await (_database.select(_database.sosMessages)..where(
                (s) => s.id.equals(row.sosId) & s.ownerId.equals(ownerId),
              ))
              .getSingleOrNull();
      if (incident == null ||
          incident.status != event.status ||
          event.incidentId != incident.id ||
          event.createdAt.isBefore(incident.createdAt)) {
        return null;
      }
      final offers =
          await (_database.select(_database.rescueResponseInbox)..where(
                (r) =>
                    r.ownerId.equals(ownerId) &
                    r.incidentId.equals(incident.id) &
                    r.state.equals('verified'),
              ))
              .get();
      for (final record in offers) {
        final offer = RescueResponseEnvelope.fromCanonicalWire(record.payload);
        // Historical Help Offer identity can route a terminal event after the
        // offer's delivery TTL. This does not resend/renew that expired offer.
        if (offer.body.messageId != record.messageId ||
            offer.body.incidentId != incident.id ||
            offer.body.originMessageId != record.originMessageId ||
            offer.body.originKeyId != event.originKeyId ||
            offer.body.responderKeyId != record.responderKeyId ||
            !await RelayCryptography().verifyRescueResponse(
              offer,
              now: offer.body.createdAt,
            )) {
          continue;
        }
        final route = _hopRelay.authenticatedRouteForKey(
          offer.body.responderKeyId,
        );
        if (route != null &&
            (_connected[route.deviceId]?.contains(route.role) ?? false) &&
            (!requirePeerBinding ||
                _peerBindings.containsKey(route.deviceId))) {
          return route;
        }
      }
    } on Object {
      _log('lifecycleRouteRecoveryUnavailable');
    }
    return null;
  }

  Future<void> _recoverAdapterExpiredCancellations(DateTime now) async {
    final outbox = _database.bleOutbox;
    final incidents = _database.sosMessages;
    final rows =
        await (_database.select(outbox).join([
              innerJoin(incidents, incidents.id.equalsExp(outbox.sosId)),
            ])..where(
              incidents.ownerId.equals(ownerId) &
                  incidents.status.equals('cancelled') &
                  outbox.state.equals(BleOutboxState.expired.wireValue) &
                  outbox.messageId.like('lifecycle:%') &
                  outbox.lastError.like(
                    'retry limit reached: Bluetooth adapter state is %',
                  ),
            ))
            .get();
    for (final result in rows) {
      final row = result.readTable(outbox);
      final event = _decodeLifecycleEnvelope(row.payload);
      if (event == null ||
          event.status != 'cancelled' ||
          event.eventId != row.messageId ||
          event.incidentId != row.sosId) {
        continue;
      }
      try {
        await event.validate(now: now);
      } on Object {
        continue;
      }
      if (!_sessionActive || _disposed || _adapterUnavailable) return;
      await (_database.update(outbox)..where(
            (r) =>
                r.messageId.equals(row.messageId) & r.state.equals(row.state),
          ))
          .write(
            BleOutboxCompanion(
              state: Value(BleOutboxState.queued.wireValue),
              retryCount: const Value(0),
              nextRetryAt: const Value(null),
              lastError: const Value(null),
              updatedAt: Value(now),
            ),
          );
    }
  }

  Future<void> _trySend(BleOutboxData row) async {
    if (!_sessionActive || _disposed) return;
    if (_adapterUnavailable) {
      _log(
        'deliveryWaiting messageId=${row.messageId} '
        'reason=bluetooth adapter unavailable',
      );
      return;
    }
    if (_sendingMessages.contains(row.messageId)) {
      return;
    }
    // A missing destination is intentionally left unsent. Selecting the first
    // connected peer can deliver an SOS or chat message to the wrong person.
    // Callers that know the intended recipient must persist destinationId.
    var activeRow = row;
    final destination = activeRow.destinationId?.isNotEmpty == true
        ? row.destinationId
        : null;
    if (destination == null) {
      _log(
        'deliveryWaiting messageId=${row.messageId} '
        'sosId=${row.sosId} reason=destinationId is required',
      );
      return;
    }
    var deviceId = destination;
    var roles = _connected[deviceId];
    // A native link can remain ready while no longer being the useful route
    // to this incident's responder. Prefer the existing signed Help Offer +
    // current Session Proof even when the stored next hop still looks alive.
    final recoveredLifecycleRoute = await _recoverLifecycleRoute(activeRow);
    if (recoveredLifecycleRoute != null &&
        recoveredLifecycleRoute.deviceId != deviceId) {
      activeRow = await _deliveryRepository.reassignPendingDestination(
        activeRow.messageId,
        expectedDestinationId: deviceId,
        destinationId: recoveredLifecycleRoute.deviceId,
        now: _now(),
      );
      deviceId = recoveredLifecycleRoute.deviceId;
      roles = _connected[deviceId];
      _log('lifecycleRouteRecoveredByVerifiedResponder');
    }
    var identityRoutedPayload = false;
    try {
      final stored = jsonDecode(activeRow.payload);
      identityRoutedPayload =
          stored is Map &&
          (stored['kind'] == SosBleMessageKind.chatMessage.wireValue ||
              stored['kind'] == 'location.update' ||
              stored['kind'] == LiveLocationEnvelope.wireKind);
    } on Object {
      // Malformed payloads are expired by the normal decode path below.
    }
    if (requirePeerBinding &&
        identityRoutedPayload &&
        (roles == null || roles.isEmpty)) {
      final expectedIdentity = await _deliveryRepository
          .lookupIncidentPeerIdentity(activeRow.sosId);
      if (expectedIdentity != null) {
        final matches = _peerBindings.entries
            .where(
              (entry) =>
                  entry.value == expectedIdentity &&
                  (_connected[entry.key]?.isNotEmpty ?? false),
            )
            .map((entry) => entry.key)
            .toList(growable: false);
        if (matches.length == 1 && matches.single != deviceId) {
          activeRow = await _deliveryRepository.reassignPendingDestination(
            activeRow.messageId,
            expectedDestinationId: deviceId,
            destinationId: matches.single,
            now: _now(),
          );
          deviceId = matches.single;
          roles = _connected[deviceId];
          _log('deliveryRouteReboundByIdentity');
        }
      }
    }
    if (roles == null || roles.isEmpty) {
      if (!_canInitiateConnection(deviceId)) return;
      _pendingConnectionMessages
          .putIfAbsent(deviceId, () => <String>{})
          .add(activeRow.messageId);
      if (_connecting.add(deviceId)) {
        try {
          _log(
            'connect sosId=${activeRow.sosId} messageId=${activeRow.messageId} '
            'peer=$deviceId',
          );
          await _transport.connect(deviceId);
        } catch (error) {
          _connecting.remove(deviceId);
          _pendingConnectionMessages[deviceId]?.remove(activeRow.messageId);
          final reason = 'connect failed: $error';
          try {
            // Count connection attempts in the durable outbox as well as
            // write attempts, otherwise an unreachable fixed peer can retry
            // forever with retryCount stuck at zero.
            final attempted = await _deliveryRepository.transitionOutboxState(
              activeRow.messageId,
              BleOutboxState.sending,
              now: _now(),
            );
            await _markFailed(attempted, reason);
          } catch (transitionError) {
            _log('Unable to record BLE connect attempt: $transitionError');
            await _markFailed(activeRow, reason);
          }
        }
      }
      return;
    }

    _sendingMessages.add(activeRow.messageId);
    try {
      final stored = jsonDecode(activeRow.payload);
      if (requirePeerBinding &&
          stored is Map &&
          (stored['kind'] == 'chat.message' ||
              stored['kind'] == 'location.update' ||
              stored['kind'] == LiveLocationEnvelope.wireKind) &&
          !_peerBindings.containsKey(deviceId)) {
        // Capability negotiation must not block urgent SOS behind a Chat row
        // or count an unsent payload as a failed native delivery attempt.
        _log('deliveryWaitingForPeerBinding');
        return;
      }
      final sending = await _deliveryRepository.claimOutboxForSending(
        activeRow.messageId,
        now: _now(),
      );
      if (sending == null || !_sessionActive || _disposed) return;
      final locationEnvelope = _decodeLocationEnvelope(
        sending.payload,
        now: _now(),
      );
      final liveLocationEnvelope = _decodeLiveLocationEnvelope(
        sending.payload,
        now: _now(),
      );
      SosBleEnvelope? envelope;
      IncidentLifecycleEnvelope? lifecycle;
      if (locationEnvelope == null && liveLocationEnvelope == null) {
        final rawKind = stored is Map ? stored['kind'] : null;
        if (rawKind == IncidentLifecycleEnvelope.wireKind) {
          lifecycle = _decodeLifecycleEnvelope(sending.payload);
          if (lifecycle == null) {
            throw const RelayProtocolException(
              'Invalid stored lifecycle envelope.',
            );
          }
        } else {
          envelope = _decodeEnvelope(sending.payload);
        }
      }
      final role = recoveredLifecycleRoute?.role ?? _sendRoleFor(deviceId);
      final frames = BleMessageCodec.encode(
        (liveLocationEnvelope?.toBleMessage() ??
            locationEnvelope?.toBleMessage() ??
            envelope?.toBleMessage() ??
            lifecycle!.toBleMessage()),
        maxFrameBytes: await negotiatedBleFrameBytes(
          _transport,
          deviceId,
          role,
        ),
      );
      _log(
        'send sosId=${sending.sosId} messageId=${sending.messageId} '
        'peer=$deviceId role=${role.wireValue} frames=${frames.length}',
      );
      final writeCompleted = await _writes.sendFrames(
        deviceId,
        frames,
        role: role,
        canSend: () =>
            _sessionActive &&
            !_disposed &&
            (recoveredLifecycleRoute?.isCurrent() ?? true),
      );
      if (!writeCompleted) return;
      if (!_sessionActive || _disposed) return;
      final completed = await _deliveryRepository.finishWriting(
        activeRow.messageId,
        now: _now(),
      );
      await _updateChatStatus(
        activeRow,
        completed.state == BleOutboxState.acknowledged.wireValue
            ? ChatDeliveryStatus.delivered
            : ChatDeliveryStatus.sent,
      );
      _log(
        'writeAccepted sosId=${sending.sosId} messageId=${activeRow.messageId} '
        'state=${BleOutboxState.awaitingAcknowledgement.wireValue}',
      );
    } on SosBleEnvelopeException catch (error) {
      await _expire(activeRow.messageId, 'invalid stored envelope: $error');
    } on LocationBleEnvelopeException catch (error) {
      await _expire(
        activeRow.messageId,
        'invalid stored location envelope: $error',
      );
    } on LiveLocationEnvelopeException catch (error) {
      await _expire(
        activeRow.messageId,
        'invalid stored live location envelope: $error',
      );
    } on RelayProtocolException catch (error) {
      await _expire(
        activeRow.messageId,
        'invalid stored lifecycle envelope: $error',
      );
    } catch (error) {
      await _markFailed(activeRow, 'send failed: $error');
    } finally {
      _sendingMessages.remove(activeRow.messageId);
    }
  }

  Future<void> _onEvent(BleEvent event) async {
    if (!_started || _disposed || !_sessionActive) return;
    for (final current in _connectionEvents.accept(event)) {
      final peer = current.device?.id;
      if (manualPeerSelection &&
          current.type == 'deviceFound' &&
          peer != null) {
        _peerRecovery.observe(
          peer,
          current.device?.recoveryHint,
          hasProvenRoute: _hopRelay.hasProvenLinkForKey,
        );
      }
      _LifecycleForwardLink? link;
      if (peer != null) {
        final role = current.role ?? BleSessionRole.central;
        final key = '$peer|${role.wireValue}';
        if (current.type == 'connected') {
          final existing = _lifecycleLinks[key];
          link = existing != null && existing.attempt == current.attempt
              ? existing
              : _LifecycleForwardLink(current.attempt);
          _lifecycleLinks[key] = link;
        } else if (current.type == 'disconnected') {
          _lifecycleLinks.removeWhere(
            (k, _) => current.role == null ? k.startsWith('$peer|') : k == key,
          );
        }
      }
      await _onCurrentEvent(current, connectionLink: link);
    }
  }

  Future<void> _onCurrentEvent(
    BleEvent event, {
    _LifecycleForwardLink? connectionLink,
  }) async {
    if (!_started || _disposed || !_sessionActive) return;
    final deviceId = event.device?.id;
    _log(
      'event=${event.type} peer=${deviceId ?? 'unknown'} '
      'role=${event.role?.wireValue ?? 'unknown'} '
      'state=${event.state ?? 'n/a'}${event.error == null ? '' : ' error=${event.error}'}',
    );
    try {
      await _hopRelay.onEvent(event);
      _incidentPresence.refresh();
    } catch (error) {
      // Relay v2 is additive. A key-store, capability, or relay-frame failure
      // must fail closed for relay without interrupting Direct SOS v1.
      _log('relayEventRejected type=${event.type} reason=$error');
    }
    switch (event.type) {
      case 'state':
      case 'centralState':
      case 'peripheralState':
        if (event.state == 'poweredOn') {
          _adapterUnavailable = false;
          unawaited(_retryPresence());
          unawaited(processDue());
        } else if (event.state == 'poweredOff' ||
            event.state == 'unauthorized' ||
            event.state == 'unsupported' ||
            event.state == 'resetting') {
          _adapterUnavailable = true;
          unawaited(
            _invalidateAdapterSessions(
              'BLE adapter state is ${event.state}; session invalidated.',
            ),
          );
          unawaited(_markPresenceLost());
        }
        return;
      case 'connected':
        if (deviceId != null) {
          if (_adapterUnavailable) {
            _log('ignoredConnectedWhileAdapterUnavailable peer=$deviceId');
            return;
          }
          final role = event.role ?? BleSessionRole.central;
          if (connectionLink == null ||
              !identical(
                _lifecycleLinks['$deviceId|${role.wireValue}'],
                connectionLink,
              )) {
            _log('ignoredConnectedAfterSessionRetired');
            return;
          }
          if (_peerRecovery.quarantined(deviceId)) {
            _log('recoveryPeerAwaitingProof');
            return;
          }
          await _activateDirectConnection(deviceId, role, connectionLink);
        }
        return;
      case 'disconnected':
        if (deviceId != null) {
          final role = event.role;
          _bindingRetries.remove(deviceId)?.cancel();
          _peerBindings.remove(deviceId);
          _peerChallenges.remove(deviceId);
          _bindingWaiters.remove(deviceId)?.complete();
          if (role == null) {
            _connected.remove(deviceId);
          } else {
            final roles = _connected[deviceId];
            roles?.remove(role);
            if (roles == null || roles.isEmpty) _connected.remove(deviceId);
          }
          _connecting.remove(deviceId);
          await _failPendingConnections(
            deviceId,
            event.error ?? 'BLE connection failed before delivery started',
          );
          // Do not complete a message with frames left over from a previous
          // GATT session for this peer.
          _assemblers.removeWhere((key, _) => key.startsWith('$deviceId|'));
          _log(
            'BLE disconnected: $deviceId${event.error == null ? '' : ' (${event.error})'}',
          );
        }
        return;
      case 'data':
        await _onFrame(
          deviceId ?? 'unknown',
          event.payload,
          event.role ?? BleSessionRole.central,
        );
        return;
      case 'error':
        if (deviceId != null) {
          _connecting.remove(deviceId);
          await _failPendingConnections(
            deviceId,
            event.error ?? 'BLE connection error before delivery started',
          );
        }
        _log('BLE native error: ${event.error ?? 'unknown'}');
        return;
    }
  }

  Future<void> _onPeerAuthenticated(
    String peer,
    BleSessionRole role,
    String key,
  ) async {
    if (!_started ||
        _disposed ||
        !_sessionActive ||
        !_peerRecovery.mayAuthenticate(peer, key)) {
      return;
    }
    final recovering = _peerRecovery.quarantined(peer);
    _peerRecovery.authenticated(peer, key);
    if (!recovering || _peerRecovery.quarantined(peer)) return;
    final route = _hopRelay.authenticatedRouteForKey(key);
    final link = _lifecycleLinks['$peer|${role.wireValue}'];
    if (route == null ||
        route.deviceId != peer ||
        route.role != role ||
        link == null) {
      return;
    }
    _log('selectedInstallationRecovered');
    unawaited(
      _activateDirectConnection(peer, role, link).catchError((Object error) {
        _log('recoveryDirectActivationFailed');
      }),
    );
  }

  Future<void> _activateDirectConnection(
    String peer,
    BleSessionRole role,
    _LifecycleForwardLink link,
  ) async {
    if (!_started ||
        _disposed ||
        !_sessionActive ||
        !identical(_lifecycleLinks['$peer|${role.wireValue}'], link)) {
      return;
    }
    _connected.putIfAbsent(peer, () => <BleSessionRole>{}).add(role);
    _connecting.remove(peer);
    _pendingConnectionMessages.remove(peer);
    _log('BLE connected: $peer');
    if (requirePeerBinding) {
      unawaited(_beginPeerBinding(peer, role));
    } else {
      await _assignPendingLifecycleDestination(peer);
      await _forwardPendingLifecycles(peer);
    }
    unawaited(processDue());
  }

  Future<void> _retryPresence() async {
    try {
      await _presence.retry();
    } on Object {
      _log('blePresencePowerRestoreFailed');
    }
  }

  Future<void> _markPresenceLost() async {
    try {
      await _presence.notifyNativePresenceLost();
    } on Object {
      _log('blePresencePowerLossReconcileFailed');
    }
  }

  // Additive capability exchange: old peers ignore this message type. No
  // account ownership or historical route is learned from the exchange.
  Future<void> _beginPeerBinding(String peer, BleSessionRole role) async {
    if (_peerChallenges.containsKey(peer)) return;
    final nonce = List.generate(
      16,
      (_) => math.Random.secure().nextInt(256),
    ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    _peerChallenges[peer] = nonce;
    _bindingWaiters.putIfAbsent(peer, Completer<void>.new);
    try {
      await _sendBinding(peer, role, nonce, null);
      if (!_disposed &&
          _peerChallenges[peer] == nonce &&
          !_peerBindings.containsKey(peer)) {
        var attempts = 1;
        _bindingRetries[peer] = _periodicTimer(const Duration(seconds: 2), (
          timer,
        ) {
          if (++attempts >= 3 ||
              _disposed ||
              _peerChallenges[peer] != nonce ||
              _peerBindings.containsKey(peer)) {
            timer.cancel();
            _bindingRetries.remove(peer);
          }
          if (attempts <= 3 && !_disposed && !_peerBindings.containsKey(peer)) {
            unawaited(
              _sendBinding(peer, role, nonce, null).catchError((Object error) {
                _log('peerBindingRetryFailed');
              }),
            );
          }
        });
      }
    } catch (error) {
      _log('peerBindingSendFailed: $error');
    }
  }

  Future<void> _sendBinding(
    String peer,
    BleSessionRole role,
    String nonce,
    String? responseTo,
  ) async {
    final message = BleMessage(
      id: 'binding:${responseTo == null ? 'h' : 'r'}:$nonce',
      type: 'peer.binding.v1',
      // Session nonce supplies freshness; immutable metadata keeps hello retries
      // byte-identical even when native frame writes overlap.
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      payload: {
        'identity': _localDeviceId,
        'nonce': nonce,
        'responseTo': ?responseTo,
      },
    );
    await _writes.sendFrames(
      peer,
      BleMessageCodec.encode(
        message,
        maxFrameBytes: await negotiatedBleFrameBytes(_transport, peer, role),
      ),
      role: role,
      canSend: () =>
          _sessionActive &&
          !_disposed &&
          (_connected[peer]?.contains(role) ?? false),
    );
  }

  Future<void> _handlePeerBinding(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    if (!requirePeerBinding || !(_connected[peer]?.contains(role) ?? false)) {
      return;
    }
    final identity = message.payload['identity'];
    final nonce = message.payload['nonce'];
    final response = message.payload['responseTo'];
    if (identity is! String ||
        identity.isEmpty ||
        identity.length > 128 ||
        nonce is! String ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(nonce)) {
      return;
    }
    final challenge = _peerChallenges[peer];
    if (challenge == null) return;
    if (response == null) {
      await _sendBinding(peer, role, challenge, nonce);
      return;
    }
    if (response != challenge) return;
    final bound = _peerBindings[peer];
    if (bound != null && bound != identity) return;
    // A logical identity cannot silently move to a different connected peer.
    if (_peerBindings.entries.any(
      (e) => e.key != peer && e.value == identity,
    )) {
      return;
    }
    _peerBindings[peer] = identity;
    _bindingRetries.remove(peer)?.cancel();
    final waiter = _bindingWaiters.remove(peer);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    _log('peerSessionBound');
    if (bound == null) await _sendBinding(peer, role, challenge, nonce);
    await _assignPendingLifecycleDestination(peer);
    await _forwardPendingLifecycles(peer);
    unawaited(processDue());
  }

  Future<void> _waitForPeerBinding(String peer) async {
    if (_peerBindings.containsKey(peer)) return;
    final waiter = _bindingWaiters[peer];
    if (waiter == null) {
      throw const BleDeliveryStateException('Connect the selected peer first.');
    }
    await waiter.future.timeout(const Duration(seconds: 40));
    if (!_sessionActive || _disposed || !_peerBindings.containsKey(peer)) {
      throw const BleDeliveryStateException(
        'Peer session binding was interrupted.',
      );
    }
  }

  Future<void> _onFrame(
    String deviceId,
    List<int>? frame,
    BleSessionRole role,
  ) async {
    if (frame == null) return;
    final assemblerKey = '$deviceId|${role.wireValue}';
    if (frame.length >= BleMessageCodec.headerBytes) {
      final index = (frame[10] << 8) | frame[11];
      final count = (frame[12] << 8) | frame[13];
      _log(
        'frame peer=$deviceId role=${role.wireValue} bytes=${frame.length} '
        'index=$index/$count',
      );
    } else {
      _log(
        'frame peer=$deviceId role=${role.wireValue} bytes=${frame.length} '
        'index=invalid',
      );
    }
    final assembler = _assemblers.putIfAbsent(
      assemblerKey,
      // Durable inbox rows are idempotent, but a retry whose ACK was lost
      // still needs a fresh positive ACK. Let the coordinator see duplicate
      // complete messages so it can persist/ACK them again.
      () => BleMessageAssembler(dropDuplicateMessages: false),
    );
    try {
      final message = assembler.accept(frame);
      _hopRelay.observeLinkTraffic(deviceId, role);
      if (message == null) return;
      if (_peerRecovery.quarantined(deviceId) &&
          !{
            RelayCapabilityAdvertisement.wireKind,
            RelaySessionChallenge.wireKind,
            RelaySessionResponse.wireKind,
          }.contains(message.type)) {
        _log('recoveryPeerDataBlocked');
        return;
      }
      _log(
        'assemblyComplete peer=$deviceId role=${role.wireValue} '
        'messageId=${message.id}',
      );
      if (message.type == 'peer.binding.v1') {
        await _handlePeerBinding(deviceId, role, message);
        return;
      }
      if (message.type == IncidentLifecycleEnvelope.wireKind) {
        await _handleIncidentLifecycle(deviceId, role, message);
        return;
      }
      if (message.type == 'sos.presence.v1') {
        await _incidentPresence.receive(deviceId, role, message);
        return;
      }
      if (await _hopRelay.handleMessage(deviceId, role, message)) return;
      if (message.type == LiveLocationEnvelope.wireKind) {
        final live = LiveLocationEnvelope.fromJson(message.payload);
        final verified = await _hopRelay.verifyLiveLocation(live);
        if (!verified) {
          _log('liveLocationRejected reason=signature');
          return;
        }
        if (live.originKeyId == (await _hopRelay.signingIdentity()).keyId ||
            !_hopRelay.currentAuthenticatedRoutes().values.any(
              (r) => r.deviceId == deviceId && r.role == role && r.isCurrent(),
            )) {
          return;
        }
        final stored = await _deliveryRepository.persistIncomingLiveLocation(
          live,
          sourceDeviceId: deviceId,
          now: _now(),
        );
        if (stored.inserted && relayParticipationEnabled) {
          await _forwardLiveLocation(deviceId, role, live);
        }
        _log(
          'liveLocationPersisted sosId=${live.sosId} '
          'participant=${live.participantId} sequence=${live.sequence}',
        );
        return;
      }
      if (message.type == 'location.update' || message.type == 'location.ack') {
        final location = LocationBleEnvelope.fromBleMessage(message);
        if (requirePeerBinding &&
            (!_peerBindings.containsKey(deviceId) ||
                _peerBindings[deviceId] != location.senderDeviceId)) {
          throw const BleDeliveryStateException(
            'Location sender has no matching session binding.',
          );
        }
        if (location.kind == 'location.ack') {
          await _handleLocationAcknowledgement(deviceId, location);
        } else {
          await _handleLocationUpdate(deviceId, role, location);
        }
        return;
      }
      if (!SosBleMessageKind.values.any(
        (kind) => kind.wireValue == message.type,
      )) {
        _log(
          'ignoredNonSosMessage peer=$deviceId role=${role.wireValue} '
          'messageId=${message.id} type=${message.type}',
        );
        return;
      }
      final envelope = SosBleEnvelope.fromBleMessage(message);
      if (requirePeerBinding &&
          (envelope.kind == SosBleMessageKind.chatMessage ||
              envelope.kind == SosBleMessageKind.chatAcknowledgement) &&
          !_peerBindings.containsKey(deviceId)) {
        throw const SosBleEnvelopeException('Peer session is not bound.');
      }
      final declaredSender = envelope.senderDeviceId?.trim();
      if (declaredSender != null &&
          declaredSender.isNotEmpty &&
          declaredSender != (_peerBindings[deviceId] ?? deviceId)) {
        throw const SosBleEnvelopeException(
          'BLE envelope sender does not match the transport peer.',
        );
      }
      _log(
        'validated kind=${envelope.kind.wireValue} sosId=${envelope.sosId} '
        'messageId=${envelope.messageId} peer=$deviceId role=${role.wireValue}',
      );
      if (envelope.kind == SosBleMessageKind.acknowledgement ||
          envelope.kind == SosBleMessageKind.chatAcknowledgement) {
        await _handleAcknowledgement(deviceId, envelope);
      } else if (envelope.kind == SosBleMessageKind.delivery) {
        await _handleDelivery(deviceId, role, envelope);
      } else {
        await _handleChatDelivery(deviceId, role, envelope);
      }
    } on BleProtocolException catch (error) {
      _log(
        'assemblyRejected peer=$deviceId role=${role.wireValue} '
        'reason=$error',
      );
    } on SosBleEnvelopeException catch (error) {
      _log('Rejected BLE SOS envelope from $deviceId: $error');
    } catch (error) {
      _log('BLE inbound processing failed: $error');
    }
  }

  Future<void> _forwardLiveLocation(
    String sourceDeviceId,
    BleSessionRole sourceRole,
    LiveLocationEnvelope envelope,
  ) async {
    final identity = await _hopRelay.signingIdentity();
    // The origin receives the update back as a final confirmation, but never
    // creates another relay fan-out. This keeps a broadcast-style incident
    // location bounded without inventing a separate route-discovery round.
    if (envelope.originKeyId == identity.keyId ||
        envelope.hopCount >= RelayProtocolLimits.maximumHops) {
      return;
    }
    final forwarded = envelope.copyWithHop(
      relayKeyId: identity.keyId,
      nextHop: envelope.hopCount + 1,
    );
    for (final peer in _connected.keys.toList(growable: false)) {
      if (peer == sourceDeviceId || _connected[peer]?.isEmpty != false) {
        continue;
      }
      final peerKey = _peerBindings[peer];
      if (peerKey != null && forwarded.pathKeyIds.contains(peerKey)) continue;
      final peerRole = _sendRoleFor(peer);
      try {
        await _writes.sendFrames(
          peer,
          BleMessageCodec.encode(
            forwarded.toBleMessage(),
            maxFrameBytes: await negotiatedBleFrameBytes(
              _transport,
              peer,
              peerRole,
            ),
          ),
          role: peerRole,
          canSend: () => _sessionActive && !_disposed,
        );
        _log(
          'liveLocationForwarded sosId=${envelope.sosId} '
          'from=$sourceDeviceId to=$peer hop=${forwarded.hopCount}',
        );
      } on Object catch (error) {
        _log('liveLocationForwardFailed peer=$peer reason=$error');
      }
    }
  }

  Future<void> _handleIncidentLifecycle(
    String deviceId,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final lifecycle = IncidentLifecycleEnvelope.fromBleMessage(message);
    await lifecycle.validate(now: _now());
    if (requirePeerBinding && !_peerBindings.containsKey(deviceId)) {
      throw const RelayProtocolException(
        'Lifecycle relay session is not bound.',
      );
    }
    final authorization = await IncidentLifecycleRepository(
      _database,
      ownerId: ownerId,
    ).receive(lifecycle, sourcePeer: deviceId, now: _now());
    if (authorization != LifecycleAuthorization.authorized) {
      _log('lifecycle_${authorization.name} incident=${lifecycle.incidentId}');
      return;
    }
    _hopRelay.stopForwardingTerminalSos(lifecycle.incidentId);
    _log(
      'lifecycle_persisted incident=${lifecycle.incidentId} status=${lifecycle.status}',
    );
    await _forwardLifecycle(lifecycle.eventId, excludePeer: deviceId);
  }

  Future<void> _forwardLifecycle(String eventId, {String? excludePeer}) async {
    final records = await IncidentLifecycleRepository(
      _database,
      ownerId: ownerId,
    ).authorizedEvents();
    final matches = records.where(
      (r) => _decodeLifecycleEnvelope(r.payload)?.eventId == eventId,
    );
    final row = matches.isEmpty ? null : matches.first;
    if (row == null) return;
    final lifecycle = _decodeLifecycleEnvelope(row.payload);
    if (lifecycle == null) return;
    for (final peer in _peerBindings.keys.toList(growable: false)) {
      if (peer == excludePeer || _connected[peer]?.isNotEmpty != true) continue;
      await _forwardPendingLifecycles(peer);
    }
  }

  Future<void> _assignPendingLifecycleDestination(String peer) async {
    if (_peerBindings[peer] == null || _connected[peer]?.isNotEmpty != true) {
      return;
    }
    final rows =
        await (_database.select(_database.bleOutbox)..where(
              (table) =>
                  table.destinationId.isNull() &
                  table.payload.like(
                    '%"kind":"${IncidentLifecycleEnvelope.wireKind}"%',
                  ),
            ))
            .get();
    for (final row in rows) {
      await _deliveryRepository.assignDestinationIfMissing(
        row.messageId,
        peer,
        now: _now(),
      );
    }
  }

  Future<void> _forwardPendingLifecycles(String peer) async {
    if ((requirePeerBinding && _peerBindings[peer] == null) ||
        _connected[peer]?.isNotEmpty != true) {
      return;
    }
    final role = _sendRoleFor(peer);
    final key = '$peer|${role.wireValue}';
    final link = _lifecycleLinks[key];
    if (link == null || link.failed) return;
    link.replayRequested = true;
    if (link.replay != null) return link.replay!;
    bool current() =>
        _started &&
        !_disposed &&
        _sessionActive &&
        !link.failed &&
        identical(_lifecycleLinks[key], link) &&
        (_connected[peer]?.contains(role) ?? false) &&
        (!requirePeerBinding || _peerBindings.containsKey(peer));
    final replay = _drainLifecycleReplay(peer, role, link, current);
    link.replay = replay;
    try {
      await replay;
    } finally {
      link.replay = null;
    }
  }

  Future<void> _drainLifecycleReplay(
    String peer,
    BleSessionRole role,
    _LifecycleForwardLink link,
    bool Function() current,
  ) async {
    do {
      link.replayRequested = false;
      if (!current()) return;
      final lifecycleRepository = IncidentLifecycleRepository(
        _database,
        ownerId: ownerId,
      );
      await lifecycleRepository.reconcilePending(now: _now());
      final rows = await lifecycleRepository.authorizedEvents();
      for (final row in rows) {
        if (!current()) return;
        if (row.senderDeviceId == peer) continue;
        final lifecycle = _decodeLifecycleEnvelope(row.payload);
        if (lifecycle == null) continue;
        if (link.sentEventIds.contains(lifecycle.eventId)) continue;
        try {
          final completed = await _writes.sendFrames(
            peer,
            BleMessageCodec.encode(
              lifecycle.toBleMessage(),
              maxFrameBytes: await negotiatedBleFrameBytes(
                _transport,
                peer,
                role,
              ),
            ),
            role: role,
            canSend: current,
            isConnectionCurrent: () =>
                _started &&
                !_disposed &&
                identical(_lifecycleLinks['$peer|${role.wireValue}'], link),
          );
          if (!completed || !current()) return;
          // Native completion only suppresses redundant replay on this live
          // connection. Durable lifecycle rows remain available after reconnect.
          link.sentEventIds.add(lifecycle.eventId);
        } on Object catch (error) {
          link.failed = true;
          _log(
            'lifecycle_retry_failed incident=${lifecycle.incidentId} '
            'reason=$error',
          );
          return;
        }
      }
    } while (link.replayRequested && current());
  }

  IncidentLifecycleEnvelope? _decodeLifecycleEnvelope(String payload) {
    try {
      final value = jsonDecode(payload);
      if (value is! Map ||
          value['kind'] != IncidentLifecycleEnvelope.wireKind) {
        return null;
      }
      return IncidentLifecycleEnvelope.fromJson(
        Map<String, Object?>.from(value),
      );
    } on Object {
      return null;
    }
  }

  Future<void> _handleAcknowledgement(
    String deviceId,
    SosBleEnvelope envelope,
  ) async {
    try {
      final recorded = await _deliveryRepository.recordAcknowledgement(
        envelope,
        sourceDeviceId: deviceId,
        now: _now(),
      );
      if (envelope.kind == SosBleMessageKind.chatAcknowledgement) {
        await chatRepository?.updateDeliveryStatus(
          envelope.ackFor!,
          recorded.state == BleOutboxState.acknowledged.wireValue
              ? ChatDeliveryStatus.delivered
              : ChatDeliveryStatus.failed,
        );
      }
      if (envelope.kind == SosBleMessageKind.acknowledgement &&
          envelope.senderDeviceId?.trim().isNotEmpty == true) {
        try {
          await _deliveryRepository.persistInboundSosAcknowledgement(
            envelope,
            sourceDeviceId: deviceId,
            now: _now(),
          );
        } on BleDeliveryStateException catch (error) {
          _log('ackRoutePersistRejected reason=$error');
        }
      }
      _log(
        'acknowledged sosId=${envelope.sosId} messageId=${envelope.ackFor} '
        'ackId=${envelope.messageId} status=${envelope.ackStatus!.wireValue} '
        'peer=$deviceId',
      );
    } on BleDeliveryStateException catch (error) {
      _log(
        'ackRejected sosId=${envelope.sosId} messageId=${envelope.ackFor} '
        'peer=$deviceId reason=$error',
      );
    }
  }

  Future<void> _handleLocationAcknowledgement(
    String deviceId,
    LocationBleEnvelope envelope,
  ) async {
    try {
      await _deliveryRepository.recordLocationAcknowledgement(
        envelope,
        sourceDeviceId: deviceId,
        now: _now(),
      );
      _log(
        'locationAcknowledged sosId=${envelope.sosId} '
        'messageId=${envelope.ackFor} ackId=${envelope.messageId} peer=$deviceId',
      );
    } on BleDeliveryStateException catch (error) {
      _log(
        'locationAckRejected sosId=${envelope.sosId} '
        'messageId=${envelope.ackFor} peer=$deviceId reason=$error',
      );
    }
  }

  Future<void> _handleLocationUpdate(
    String deviceId,
    BleSessionRole role,
    LocationBleEnvelope envelope,
  ) async {
    if (requirePeerBinding &&
        (envelope.recipientId != _localDeviceId ||
            !await _deliveryRepository.isIncidentPeer(
              envelope.sosId,
              deviceId,
              peerIdentity: _peerBindings[deviceId],
            ))) {
      _log('locationPeerOrRecipientRejected');
      return;
    }
    try {
      await _deliveryRepository.persistIncomingLocation(
        envelope,
        expectedRecipientId: _localDeviceId,
        sourceDeviceId: deviceId,
        expectedSenderId: requirePeerBinding ? _peerBindings[deviceId] : null,
        now: _now(),
      );
      await _sendLocationAcknowledgement(deviceId, role, envelope, 'persisted');
      _log(
        'locationPersisted sosId=${envelope.sosId} '
        'messageId=${envelope.messageId} peer=$deviceId',
      );
    } on Object catch (error) {
      _log(
        'locationPersistRejected sosId=${envelope.sosId} '
        'messageId=${envelope.messageId} reason=$error',
      );
      await _sendLocationAcknowledgement(
        deviceId,
        role,
        envelope,
        'rejected',
        error: error.toString(),
      );
    }
  }

  Future<void> _sendLocationAcknowledgement(
    String deviceId,
    BleSessionRole role,
    LocationBleEnvelope update,
    String status, {
    String? error,
  }) async {
    if (!(_connected[deviceId]?.contains(role) ?? false)) return;
    final acknowledgement = LocationBleEnvelope.ack(
      messageId: 'location-ack:${update.messageId}',
      sosId: update.sosId,
      ackFor: update.messageId,
      ackStatus: status,
      senderDeviceId: _localDeviceId,
      error: error,
      createdAt: _now().toUtc(),
    );
    try {
      final writeCompleted = await _writes.sendFrames(
        deviceId,
        BleMessageCodec.encode(
          acknowledgement.toBleMessage(),
          maxFrameBytes: await negotiatedBleFrameBytes(
            _transport,
            deviceId,
            role,
          ),
        ),
        role: role,
        canSend: () => _sessionActive && !_disposed,
      );
      if (!writeCompleted) return;
      _log(
        'locationAckSent sosId=${update.sosId} messageId=${update.messageId} '
        'status=$status peer=$deviceId',
      );
    } on Object catch (sendError) {
      _log(
        'locationAckSendFailed messageId=${update.messageId} reason=$sendError',
      );
    }
  }

  Future<void> _handleDelivery(
    String deviceId,
    BleSessionRole role,
    SosBleEnvelope envelope,
  ) async {
    final key = '${envelope.kind.wireValue}:${envelope.messageId}:$deviceId';
    final existing = _inflightDeliveries[key];
    if (existing != null) {
      final persisted = await existing;
      final inbox = await _deliveryRepository.lookupInbox(envelope.messageId);
      if (inbox != null &&
          (inbox.senderDeviceId?.trim() != deviceId ||
              inbox.payload != jsonEncode(envelope.toJson()))) {
        return;
      }
      await _sendAcknowledgement(
        deviceId,
        role,
        envelope,
        persisted ? SosBleAckStatus.persisted : SosBleAckStatus.rejected,
        persisted ? null : 'The original delivery attempt was rejected.',
      );
      return;
    }
    final completion = Completer<bool>();
    _inflightDeliveries[key] = completion.future;
    var persisted = false;
    try {
      try {
        final result = await _deliveryRepository.persistIncomingDelivery(
          envelope,
          ownerId: ownerId,
          sourceDeviceId: deviceId,
          expectedSenderId: requirePeerBinding ? _peerBindings[deviceId] : null,
          now: _now(),
        );
        _log(
          'persisted sosId=${envelope.sosId} messageId=${envelope.messageId} '
          'duplicate=${result.duplicate} peer=$deviceId',
        );
        persisted = true;
      } on BlePeerMismatchException catch (error) {
        // A replay from another (or historically unbound) peer must neither
        // learn a reply route nor receive an application ACK.
        _log('persistPeerRejected messageId=${envelope.messageId}: $error');
        return;
      } catch (error) {
        _log(
          'persistRejected sosId=${envelope.sosId} '
          'messageId=${envelope.messageId} reason=$error',
        );
        await _sendAcknowledgement(
          deviceId,
          role,
          envelope,
          SosBleAckStatus.rejected,
          error.toString(),
        );
        return;
      }
      await _sendAcknowledgement(
        deviceId,
        role,
        envelope,
        SosBleAckStatus.persisted,
        null,
      );
    } finally {
      if (!completion.isCompleted) completion.complete(persisted);
      _inflightDeliveries.remove(key);
    }
  }

  Future<void> _handleChatDelivery(
    String deviceId,
    BleSessionRole role,
    SosBleEnvelope envelope,
  ) async {
    if (requirePeerBinding &&
        (envelope.chatSenderId != _peerBindings[deviceId] ||
            !await _deliveryRepository.isIncidentPeer(
              envelope.sosId,
              deviceId,
              peerIdentity: _peerBindings[deviceId],
            ))) {
      _log('chatIncidentPeerRejected');
      return;
    }
    final chatRepository = this.chatRepository;
    if (chatRepository == null ||
        envelope.chatSenderId == null ||
        envelope.chatText == null) {
      _log(
        'chatRejected messageId=${envelope.messageId} reason=chat repository unavailable',
      );
      return;
    }
    final key = '${envelope.kind.wireValue}:${envelope.messageId}:$deviceId';
    final existing = _inflightDeliveries[key];
    if (existing != null) {
      final persisted = await existing;
      if (persisted) {
        try {
          await chatRepository.insertIncomingMessage(
            messageId: envelope.messageId,
            sosId: envelope.sosId,
            senderId: envelope.chatSenderId!,
            recipientId: ownerId,
            text: envelope.chatText!,
            createdAt: envelope.createdAt,
          );
        } on Object {
          _log('chatDuplicateContentRejected');
          return;
        }
      }
      await _sendChatAcknowledgement(
        deviceId,
        role,
        envelope,
        persisted ? SosBleAckStatus.persisted : SosBleAckStatus.rejected,
        persisted ? null : 'The original chat delivery attempt was rejected.',
      );
      return;
    }
    final completion = Completer<bool>();
    _inflightDeliveries[key] = completion.future;
    var persisted = false;
    try {
      try {
        await chatRepository.insertIncomingMessage(
          messageId: envelope.messageId,
          sosId: envelope.sosId,
          senderId: envelope.chatSenderId!,
          recipientId: ownerId,
          text: envelope.chatText!,
          createdAt: envelope.createdAt,
        );
        _log(
          'chatPersisted sosId=${envelope.sosId} messageId=${envelope.messageId} peer=$deviceId',
        );
        persisted = true;
      } catch (error) {
        _log(
          'chatPersistRejected messageId=${envelope.messageId} reason=$error',
        );
        await _sendChatAcknowledgement(
          deviceId,
          role,
          envelope,
          SosBleAckStatus.rejected,
          error.toString(),
        );
        return;
      }
      await _sendChatAcknowledgement(
        deviceId,
        role,
        envelope,
        SosBleAckStatus.persisted,
        null,
      );
    } finally {
      if (!completion.isCompleted) completion.complete(persisted);
      _inflightDeliveries.remove(key);
    }
  }

  Future<void> _sendAcknowledgement(
    String deviceId,
    BleSessionRole role,
    SosBleEnvelope delivery,
    SosBleAckStatus status,
    String? error,
  ) async {
    if (!(_connected[deviceId]?.contains(role) ?? false)) {
      _log('Cannot send ${status.wireValue} ACK; $deviceId is disconnected');
      return;
    }
    final acknowledgement = SosBleEnvelope.acknowledgement(
      messageId: 'ack:${delivery.messageId}',
      sosId: delivery.sosId,
      ackFor: delivery.messageId,
      ackStatus: status,
      senderDeviceId: _localDeviceId,
      error: error,
      createdAt: _now(),
    );
    try {
      final writeCompleted = await _writes.sendFrames(
        deviceId,
        BleMessageCodec.encode(
          acknowledgement.toBleMessage(),
          maxFrameBytes: await negotiatedBleFrameBytes(
            _transport,
            deviceId,
            role,
          ),
        ),
        role: role,
        canSend: () => _sessionActive && !_disposed,
      );
      if (!writeCompleted) return;
      if (!_sessionActive || _disposed) return;
      await _deliveryRepository.markInboxAcknowledgement(
        delivery.messageId,
        status == SosBleAckStatus.persisted
            ? BleAcknowledgementStatus.persisted
            : BleAcknowledgementStatus.rejected,
      );
      _log(
        'ackSent sosId=${delivery.sosId} messageId=${delivery.messageId} '
        'ackId=ack:${delivery.messageId} status=${status.wireValue} '
        'peer=$deviceId role=${role.wireValue}',
      );
    } catch (error) {
      _log(
        'ackSendFailed sosId=${delivery.sosId} '
        'messageId=${delivery.messageId} reason=$error',
      );
    }
  }

  Future<void> _sendChatAcknowledgement(
    String deviceId,
    BleSessionRole role,
    SosBleEnvelope delivery,
    SosBleAckStatus status,
    String? error,
  ) async {
    if (!(_connected[deviceId]?.contains(role) ?? false)) return;
    final acknowledgement = SosBleEnvelope.chatAcknowledgement(
      messageId: 'ack:${delivery.messageId}',
      sosId: delivery.sosId,
      ackFor: delivery.messageId,
      ackStatus: status,
      senderDeviceId: _localDeviceId,
      error: error,
      createdAt: _now(),
    );
    try {
      final writeCompleted = await _writes.sendFrames(
        deviceId,
        BleMessageCodec.encode(
          acknowledgement.toBleMessage(),
          maxFrameBytes: await negotiatedBleFrameBytes(
            _transport,
            deviceId,
            role,
          ),
        ),
        role: role,
        canSend: () => _sessionActive && !_disposed,
      );
      if (!writeCompleted) return;
      _log(
        'chatAckSent sosId=${delivery.sosId} messageId=${delivery.messageId} status=${status.wireValue} peer=$deviceId',
      );
    } catch (error) {
      _log('chatAckSendFailed messageId=${delivery.messageId} reason=$error');
    }
  }

  BleSessionRole _sendRoleFor(String deviceId) {
    final roles = _connected[deviceId];
    if (roles?.contains(BleSessionRole.central) == true) {
      return BleSessionRole.central;
    }
    return BleSessionRole.peripheral;
  }

  SosBleEnvelope _decodeEnvelope(String payload) {
    final value = jsonDecode(payload);
    if (value is! Map) {
      throw const SosBleEnvelopeException('Stored payload is not an object.');
    }
    return SosBleEnvelope.fromJson(Map<String, Object?>.from(value));
  }

  LocationBleEnvelope? _decodeLocationEnvelope(
    String payload, {
    DateTime? now,
  }) {
    final value = jsonDecode(payload);
    if (value is! Map ||
        (value['kind'] != 'location.update' &&
            value['kind'] != 'location.ack')) {
      return null;
    }
    final map = Map<String, Object?>.from(value);
    final createdAt = DateTime.parse(map['createdAt'] as String).toUtc();
    final envelope = LocationBleEnvelope.fromBleMessage(
      BleMessage(
        id: map['messageId'] as String,
        type: map['kind'] as String,
        createdAt: createdAt,
        payload: map,
      ),
    );
    envelope.validate(now: now);
    return envelope;
  }

  LiveLocationEnvelope? _decodeLiveLocationEnvelope(
    String payload, {
    DateTime? now,
  }) {
    final value = jsonDecode(payload);
    if (value is! Map || value['kind'] != LiveLocationEnvelope.wireKind) {
      return null;
    }
    final envelope = LiveLocationEnvelope.fromJson(
      Map<String, Object?>.from(value),
    );
    envelope.validate(now: now);
    return envelope;
  }

  Future<void> _markFailed(BleOutboxData row, String error) async {
    _log(
      'deliveryFailed sosId=${row.sosId} messageId=${row.messageId} '
      'reason=$error',
    );
    final current = await _deliveryRepository.lookupOutbox(row.messageId);
    if (current == null ||
        current.state == BleOutboxState.acknowledged.wireValue ||
        current.state == BleOutboxState.expired.wireValue) {
      return;
    }
    final attempts = math.max(1, current.retryCount);
    if (attempts >= maxRetryAttempts) {
      await _expire(row.messageId, 'retry limit reached: $error');
      return;
    }
    final exponent = math.min(attempts - 1, 8);
    final baseMillis = retryBase.inMilliseconds * (1 << exponent);
    final boundedMillis = math.min(baseMillis, retryMax.inMilliseconds);
    final jitter = (_random().clamp(0, 1) * (boundedMillis * 0.2)).round();
    try {
      await _deliveryRepository.transitionOutboxState(
        row.messageId,
        BleOutboxState.failed,
        now: _now(),
        nextRetryAt: _now().toUtc().add(
          Duration(milliseconds: boundedMillis + jitter),
        ),
        error: error,
      );
      await _updateChatStatus(row, ChatDeliveryStatus.failed);
    } catch (transitionError) {
      _log(
        'Unable to persist BLE failure for ${row.messageId}: $transitionError',
      );
    }
  }

  Future<void> _failPendingConnections(String deviceId, String reason) async {
    final messageIds = _pendingConnectionMessages.remove(deviceId);
    if (messageIds == null || messageIds.isEmpty) return;
    for (final messageId in messageIds) {
      final row = await _deliveryRepository.lookupOutbox(messageId);
      if (_adapterUnavailable &&
          row != null &&
          _decodeLifecycleEnvelope(row.payload) != null) {
        continue;
      }
      // A due retry remains failed while connect() waits for the native
      // callback. Count that attempt too; otherwise asynchronous GATT errors
      // leave retryCount frozen after the first failure and retry forever.
      if (row == null ||
          (row.state != BleOutboxState.queued.wireValue &&
              row.state != BleOutboxState.failed.wireValue)) {
        continue;
      }
      try {
        final attempted = await _deliveryRepository.transitionOutboxState(
          messageId,
          BleOutboxState.sending,
          now: _now(),
        );
        await _markFailed(attempted, reason);
      } catch (error) {
        _log(
          'Unable to record BLE connection failure messageId=$messageId '
          'peer=$deviceId reason=$error',
        );
      }
    }
  }

  Future<void> _invalidateAdapterSessions(String reason) async {
    final peers = <String>{
      ..._connected.keys,
      ..._connecting,
      ..._pendingConnectionMessages.keys,
    };
    _connected.clear();
    _lifecycleLinks.clear();
    _connectionEvents.clear();
    _connecting.clear();
    _peerBindings.clear();
    _peerChallenges.clear();
    for (final timer in _bindingRetries.values) {
      timer.cancel();
    }
    _bindingRetries.clear();
    for (final waiter in _bindingWaiters.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _bindingWaiters.clear();
    _assemblers.clear();
    for (final peer in peers) {
      await _failPendingConnections(peer, reason);
    }
  }

  Future<void> _expire(String messageId, String error) async {
    _log('deliveryExpired messageId=$messageId reason=$error');
    try {
      await _deliveryRepository.transitionOutboxState(
        messageId,
        BleOutboxState.expired,
        now: _now(),
        error: error,
      );
      final row = await _deliveryRepository.lookupOutbox(messageId);
      if (row != null) {
        await _updateChatStatus(row, ChatDeliveryStatus.failed);
      }
    } catch (transitionError) {
      _log('Unable to expire BLE message $messageId: $transitionError');
    }
  }

  Future<void> _updateChatStatus(
    BleOutboxData row,
    ChatDeliveryStatus status,
  ) async {
    final repository = chatRepository;
    if (repository == null) return;
    try {
      final envelope = _decodeEnvelope(row.payload);
      if (envelope.kind == SosBleMessageKind.chatMessage) {
        await repository.updateDeliveryStatus(row.messageId, status);
      }
    } catch (error) {
      _log('Unable to update chat status for ${row.messageId}: $error');
    }
  }

  void _ensureUsable() {
    if (_disposed) throw StateError('BLE coordinator was disposed.');
  }

  void _log(String message) {
    try {
      onLog?.call(message);
    } catch (_) {
      // Diagnostics must never change delivery behavior.
    }
  }
}
