import 'dart:async';

import 'package:drift/drift.dart' show Variable, BooleanExpressionOperators;

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import '../../../core/database/app_database.dart';
import '../../sos/data/sos_repository.dart';
import '../../sos/data/media_attachment_store.dart';
import '../domain/media_manifest.dart';
import '../domain/ble_models.dart';
import '../domain/ble_connection_events.dart';
import '../domain/relay_envelope.dart';
import '../domain/rescue_response_envelope.dart';
import '../domain/chat_relay_envelope.dart';
import 'ble_protocol.dart';
import 'ble_transport.dart';
import 'relay_key_store.dart';
import 'relay_repository.dart';
import 'incident_lifecycle_repository.dart';
import 'rescue_inbox_repository.dart';
import 'rescue_response_repository.dart';
import 'chat_relay_repository.dart';
import 'chat_receipt_repository.dart';
import '../domain/chat_receipt.dart';
import 'chat_relay_authorization.dart';
import 'relay_diagnostics_repository.dart';

typedef RelayNow = DateTime Function();
typedef RelayNonceSource = List<int> Function();
typedef RelayProofTimer = Timer Function(
  Duration duration,
  void Function() callback,
);

List<int> _secureNonce() {
  final random = math.Random.secure();
  return List<int>.generate(32, (_) => random.nextInt(256), growable: false);
}

class RelayStatusSnapshot {
  const RelayStatusSnapshot({
    required this.hasRelayJob,
    required this.acceptedRelayCount,
    required this.pendingAttemptCount,
    required this.failedAttemptCount,
    required this.expiresAt,
  });

  final bool hasRelayJob;
  final int acceptedRelayCount;
  final int pendingAttemptCount;
  final int failedAttemptCount;
  final DateTime? expiresAt;
}

/// A route backed by the current signed Session Proof, never a BLE address
/// or a capability declaration alone. Callers recheck it before each frame.
class AuthenticatedRelayRoute {
  const AuthenticatedRelayRoute({
    required this.deviceId,
    required this.role,
    required this.isCurrent,
  });
  final String deviceId;
  final BleSessionRole role;
  final bool Function() isCurrent;
}

class _RelayPeer {
  const _RelayPeer({
    required this.keyId,
    required this.publicKey,
    required this.participating,
    required this.sessionGeneration,
    required this.sessionRole,
    this.mediaSupported = false,
  });

  final String keyId;
  final String publicKey;
  final bool participating;
  final int sessionGeneration;
  final String sessionRole;
  final bool mediaSupported;
}

class _RelaySession {
  _RelaySession({
    required this.generation,
    required this.role,
    this.nativeAttempt,
  });

  final int? nativeAttempt;

  final int generation;
  final BleSessionRole role;
  int? verifiedPeerGeneration;
  _RelayPeer? declaredPeer;
  RelaySessionChallenge? pendingChallenge;
  Object? challengeIssuing;
  Completer<void>? proofReady;
  RelaySessionChallenge? deferredPeerChallenge;
  bool proofComplete = false;
  String? outboundBinding;
  String? inboundBinding;
  final Set<String> seenChallengeNonces = <String>{};
  final Set<String> respondingChallengeNonces = <String>{};
  final Map<String, Completer<void>> pendingInboundBindings = {};
  Timer? proofTimeout;
  DateTime? proofRetryAt;
  int proofRecoveryAttempts = 0;

  void resetProof() {
    for (final completion in pendingInboundBindings.values) {
      if (!completion.isCompleted) completion.complete();
    }
    pendingInboundBindings.clear();
    proofTimeout?.cancel();
    proofTimeout = null;
    proofRetryAt = null;
    proofRecoveryAttempts = 0;
    pendingChallenge = null;
    challengeIssuing = null;
    if (proofReady != null && !proofReady!.isCompleted) proofReady!.complete();
    proofReady = null;
    deferredPeerChallenge = null;
    proofComplete = false;
    outboundBinding = null;
    inboundBinding = null;
    seenChallengeNonces.clear();
    respondingChallengeNonces.clear();
  }

  void invalidate() {
    resetProof();
    declaredPeer = null;
  }
}

class _ProvenRoute {
  const _ProvenRoute({required this.role, required this.peer});
  final BleSessionRole role;
  final _RelayPeer peer;
}

class _ActiveInstallationSession {
  const _ActiveInstallationSession({required this.peer, required this.session});

  final String peer;
  final _RelaySession session;
}

/// Model C coordinator, runnable while a native background execution lease
/// is available; otherwise foreground-only. It shares the existing BLE transport
/// and delegates persistence and cryptographic validation to RelayRepository.
/// A hop receipt means only that the next relay persisted the signed offer.
class HopRelayCoordinator {
  static const maximumConnectionCandidates =
      RelayProtocolLimits.maximumAttemptsPerMessage;

  HopRelayCoordinator({
    required AppDatabase database,
    required BleTransportClient transport,
    BlePresenceManager? presenceManager,
    RelayRepository? repository,
    RelayIdentityService? identityService,
    RelayCryptography? cryptography,
    RelayNow? now,
    RelayNonceSource? nonceSource,
    RelayProofTimer? proofTimer,
    this.onLog,
    this.rescueModeEnabled,
    this.rescueInbox,
    String? responseOwnerId,
    RescueResponseRepository? rescueResponseRepository,
    this.chatRelayRepository,
    this.onChatRelayReceived,
    this.onChatRelayForwarded,
    this.mediaStore,
    this.ackTimeout = const Duration(seconds: 30),
    this.retryBase = const Duration(seconds: 5),
    // A signed response embeds the signed challenge and can span hundreds of
    // 20-byte BLE frames on physical devices. Android <-> iOS full-duplex
    // traffic can serialize those frames slowly enough for a valid response
    // to take more than 45 seconds after the challenge write completes. Keep
    // the application-proof window above that measured transfer time; native
    // write completion is still not treated as proof or delivery.
    this.proofTimeout = const Duration(minutes: 2),
  }) : _database = database,
       _transport = transport,
       _presence = presenceManager ?? BlePresenceManager.sharedFor(transport),
       _repository = repository ?? RelayRepository(database: database),
       _cryptography = cryptography ?? RelayCryptography(),
       _writes = BleMessageWriteQueue.sharedFor(transport),
       _rescueResponseRepository =
           rescueResponseRepository ??
           RescueResponseRepository(
             database,
             ownerId: responseOwnerId ?? RelayRepository.localOriginPeerId,
             onLog: onLog,
           ),
       _identityService =
           identityService ??
           RelayIdentityService(keyStore: PlatformRelayPrivateKeyStore()),
       _now = now ?? DateTime.now,
       _proofTimer = proofTimer ?? Timer.new,
       _nonceSource = nonceSource ?? _secureNonce;

  ChatReceiptRepository get _chatReceipts =>
      ChatReceiptRepository(_database, chatRelayRepository!.ownerId);
  final AppDatabase _database;
  final BleTransportClient _transport;
  final BlePresenceManager _presence;
  final RelayRepository _repository;
  final RelayCryptography _cryptography;
  final BleMessageWriteQueue _writes;
  final RelayIdentityService _identityService;
  final RelayNow _now;
  final RelayProofTimer _proofTimer;
  final RelayNonceSource _nonceSource;
  final void Function(String message)? onLog;
  final bool Function()? rescueModeEnabled;
  final RescueInboxRepository? rescueInbox;
  final RescueResponseRepository _rescueResponseRepository;
  final ChatRelayRepository? chatRelayRepository;
  final MediaAttachmentStore? mediaStore;
  final Future<void> Function(ChatRelayEnvelope envelope)? onChatRelayReceived;
  final Future<void> Function(String messageId)? onChatRelayForwarded;
  final Duration ackTimeout;
  final Duration retryBase;
  final Duration proofTimeout;

  final _connectionEvents = BleConnectionEvents();
  final _connected = <String, Set<BleSessionRole>>{};
  final _sessions = <String, _RelaySession>{};
  final _connecting = <String>{};
  final _connectionAttempts = <String, int>{};
  final _connectionAttemptWindows = <String, DateTime>{};
  final _cancelledOriginMessageIds = <String>{};
  final _sendTails = <String, Future<void>>{};
  final _timers = <String, Stopwatch>{};
  final RelayRuntimeDiagnosticsController runtimeDiagnostics =
      RelayRuntimeDiagnosticsController();
  final Stopwatch _diagnosticClock = Stopwatch()..start();
  final List<String> _runtimeEvents = <String>[];
  DateTime? _lastSchedulerExecution;
  int _runtimeDueJobs = 0;
  String? _runtimeSelectedPeer;
  String? _runtimeSkipReason;
  String? _runtimeForwardAttempt;
  String? _runtimeDurableReceipt;
  Future<void>? _processing;
  bool _chatArrivedDuringDrain = false;
  RelaySigningIdentity? _identity;
  bool _started = false;
  bool _foreground = true;
  bool _participating = false;
  final Object _advertisingLease = Object();
  final Object _discoveryLease = Object();
  bool _advertisingLeaseHeld = false;
  bool _discoveryLeaseHeld = false;
  bool _hasPendingWork = false;
  bool _pendingLocalControlWork = false;

  void setPendingLocalControlWork(bool pending) {
    _pendingLocalControlWork = pending;
  }

  int _nextSessionGeneration = 0;
  int _participationGeneration = 0;

  bool get participationEnabled => _participating;

  /// Shared installation identity for additive, origin-authenticated
  /// application messages. It is the same identity used by Relay v2.
  Future<RelaySigningIdentity> signingIdentity() => _ensureIdentity();

  Future<bool> hasPendingLocalOrigin() =>
      _repository.hasForwardableLocalOrigin(now: _now());

  Future<void> start() async {
    _started = true;
    try {
      await _repository.removeInactiveLocalOrigins();
      if (_participating && _foreground) await _startAdvertising();
      await processDue();
    } on Object {
      _participating = false;
      _participationGeneration++;
      _invalidateAllProofs();
      await _stopPresence().catchError((_) {});
      rethrow;
    }
  }

  Future<void> stop() async {
    _started = false;
    _pendingLocalControlWork = false;
    await _stopPresence();
    _connected.clear();
    _connectionEvents.clear();
    for (final session in _sessions.values) {
      session.invalidate();
    }
    _sessions.clear();
    _connecting.clear();
    _connectionAttempts.clear();
    _connectionAttemptWindows.clear();
    await _processing;
  }

  Future<void> setForeground(bool foreground) async {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!_started) return;
    if (!foreground) {
      // A foreground loss can interrupt a multi-frame capability, challenge,
      // response, offer or receipt while the native GATT connection itself
      // remains alive. Never retain proof established around that partial
      // write as an active session proof.
      _invalidateAllProofs();
      await _stopPresence();
      return;
    }
    if (_participating) await _startAdvertising();
    // Android and iOS may keep an existing GATT connection across a brief
    // inactive state (for example, opening the notification shade). No new
    // `connected` callback is guaranteed on resume, so explicitly restart the
    // authenticated exchange for every retained connection.
    await _broadcastCapabilities();
    await _challengeDeclaredPeers();
    await processDue();
  }

  Future<void> setParticipationEnabled(bool enabled) async {
    if (!enabled) {
      _participating = false;
      _participationGeneration++;
      _invalidateAllProofs();
      // An explicit OFF/ON cycle is also the user's safe recovery action for
      // a peer whose transient connection budget was exhausted. Retained
      // relay jobs stay durable; only ephemeral discovery state is reset.
      _connecting.clear();
      _connectionAttempts.clear();
      _connectionAttemptWindows.clear();
      if (_started && _foreground) {
        await _broadcastCapabilities();
        await _challengeDeclaredPeers();
        await _stopAdvertising();
        // Per-incident Public Relay consent authorizes forwarding this
        // installation's own SOS. Opting out of carrying other people's SOS
        // must not pause that independently authorized origin job.
        await processDue();
      } else {
        await _stopAdvertising();
      }
      return;
    }
    if (_participating) return;
    final generation = ++_participationGeneration;
    try {
      await _ensureIdentity();
      if (generation != _participationGeneration) return;
      if (_started && _foreground) await _startAdvertising();
      if (generation != _participationGeneration) {
        await _stopPresence();
        return;
      }
      _participating = true;
      _invalidateAllProofs();
      if (_started && _foreground) {
        await _broadcastCapabilities();
        // Existing GATT sessions survive an opt-out. Re-prove those sessions
        // immediately after opt-in instead of waiting for a peer to repeat an
        // otherwise unchanged capability advertisement.
        await _challengeDeclaredPeers();
        await processDue();
      }
    } on Object {
      if (generation == _participationGeneration) {
        _participating = false;
        _participationGeneration++;
        _invalidateAllProofs();
        await _stopPresence().catchError((_) {});
      }
      rethrow;
    }
  }

  Future<void> queuePublicEmergency(
    SosMessage sos, {
    required bool includeLocation,
    RelayAuthorizationScope scope =
        RelayAuthorizationScope.publicEmergencyRelay,
  }) async {
    if (!_hasPendingWork) {
      _connectionAttempts.clear();
      _connectionAttemptWindows.clear();
    }
    final identity = await _ensureIdentity();
    final createdAt = sos.createdAt.toUtc();
    final expiresAt = createdAt.add(RelayProtocolLimits.maximumLifetime);
    final hasLocation = isValidSosCoordinatePair(sos.latitude, sos.longitude);
    final body = RelayOriginBody(
      originMessageId: 'relay:${sos.id}',
      incidentId: sos.id,
      originKeyId: identity.keyId,
      originPublicKey: base64UrlEncode(identity.publicKey),
      emergencyType: sos.type,
      emergencyMessage: sos.message?.trim().isNotEmpty == true
          ? sos.message!.trim()
          : 'Emergency SOS',
      includeLocation: includeLocation && hasLocation,
      latitude: includeLocation && hasLocation ? sos.latitude : null,
      longitude: includeLocation && hasLocation ? sos.longitude : null,
      createdAt: createdAt,
      expiresAt: expiresAt,
      scope: scope,
    );
    _cancelledOriginMessageIds.remove(body.originMessageId);
    final unsigned = RelayOfferEnvelope(
      body: body,
      originSignature: base64UrlEncode(List<int>.filled(64, 0)),
      hopCount: 0,
      pathKeyIds: [identity.keyId],
      immediateSenderKeyId: identity.keyId,
    );
    final offer = RelayOfferEnvelope(
      body: body,
      originSignature: await _cryptography.signOriginBody(
        body,
        identity.keyPair,
      ),
      hopCount: unsigned.hopCount,
      pathKeyIds: unsigned.pathKeyIds,
      immediateSenderKeyId: unsigned.immediateSenderKeyId,
    );
    await _repository.persistOriginOffer(offer, now: _now());
    _timers[body.originMessageId] = Stopwatch()..start();
    _timing('relay_enqueued', body.originMessageId, hop: 0);
    _hasPendingWork = true;
    if (_started && _foreground) {
      await _ensureDiscovery();
      await _broadcastCapabilities();
      await processDue();
    }
  }

  Future<void> cancelPublicEmergency(String incidentId) async {
    final id = incidentId.trim();
    if (id.isEmpty) {
      throw const RelayPersistenceException('Relay incident ID is required.');
    }
    _cancelledOriginMessageIds.add('relay:$id');
    await _repository.removeLocalOriginForIncident(id);
    if (_started && _foreground) await processDue();
  }

  Stream<RelayStatusSnapshot> watchStatus(String incidentId) {
    late StreamController<RelayStatusSnapshot> controller;
    StreamSubscription<Object?>? messageSubscription;
    StreamSubscription<Object?>? attemptSubscription;
    Future<void> emit() async {
      final messages = await (_database.select(
        _database.bleRelayMessages,
      )..where((table) => table.incidentId.equals(incidentId))).get();
      if (messages.isEmpty) {
        if (!controller.isClosed) {
          controller.add(
            const RelayStatusSnapshot(
              hasRelayJob: false,
              acceptedRelayCount: 0,
              pendingAttemptCount: 0,
              failedAttemptCount: 0,
              expiresAt: null,
            ),
          );
        }
        return;
      }
      final ids = messages.map((message) => message.originMessageId).toSet();
      final attempts = await _database.select(_database.bleRelayAttempts).get();
      final matching = attempts
          .where((attempt) => ids.contains(attempt.originMessageId))
          .toList(growable: false);
      if (!controller.isClosed) {
        controller.add(
          RelayStatusSnapshot(
            hasRelayJob: true,
            acceptedRelayCount: matching
                .where(
                  (attempt) =>
                      attempt.state ==
                      RelayAttemptState.acceptedByRelay.wireValue,
                )
                .length,
            pendingAttemptCount: matching
                .where(
                  (attempt) =>
                      attempt.state == RelayAttemptState.queued.wireValue ||
                      attempt.state == RelayAttemptState.sending.wireValue ||
                      attempt.state ==
                          RelayAttemptState.awaitingHopReceipt.wireValue,
                )
                .length,
            failedAttemptCount: matching
                .where(
                  (attempt) =>
                      attempt.state == RelayAttemptState.failed.wireValue ||
                      attempt.state == RelayAttemptState.expired.wireValue,
                )
                .length,
            expiresAt: messages
                .map((message) => message.retentionDeadline)
                .reduce((left, right) => left.isBefore(right) ? left : right),
          ),
        );
      }
    }

    controller = StreamController<RelayStatusSnapshot>(
      onListen: () {
        messageSubscription = _repository
            .watchMessagesForIncident(incidentId)
            .listen((_) => unawaited(emit()), onError: controller.addError);
        attemptSubscription = _repository
            .watchAttemptsForIncident(incidentId)
            .listen((_) => unawaited(emit()), onError: controller.addError);
        unawaited(emit());
      },
      onCancel: () async {
        await messageSubscription?.cancel();
        await attemptSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> onEvent(BleEvent event) async {
    for (final current in _connectionEvents.accept(event)) {
      await _onCurrentEvent(current);
    }
  }

  Future<void> _onCurrentEvent(BleEvent event) async {
    if ((event.type == 'state' ||
            event.type == 'centralState' ||
            event.type == 'peripheralState') &&
        const [
          'poweredOff',
          'unauthorized',
          'unsupported',
          'resetting',
        ].contains(event.state)) {
      for (final session in _sessions.values) {
        session.invalidate();
      }
      _sessions.clear();
      _connected.clear();
      _connecting.clear();
      _connectionEvents.clear();
      _connectionAttempts.clear();
      _connectionAttemptWindows.clear();
      return;
    }
    final peer = event.device?.id.trim();
    final role = event.role ?? BleSessionRole.central;
    if (peer != null && peer.isNotEmpty) {
      switch (event.type) {
        case 'deviceFound':
          _authTrace('peer_discovered', peer: peer, role: event.role);
          break;
        case 'connecting':
          _authTrace(
            'connection_attempt_started',
            peer: peer,
            role: role,
            attempt: event.attempt,
          );
          break;
        case 'discoveringServices':
        case 'serviceDiscovered':
          _authTrace(
            'services_discovered',
            peer: peer,
            role: role,
            attempt: event.attempt,
          );
          break;
        case 'characteristicsDiscovered':
          _authTrace(
            'characteristics_discovered',
            peer: peer,
            role: role,
            attempt: event.attempt,
          );
          break;
        case 'connected':
          // Native bridges emit connected only after the TX notification
          // subscription is ready. Record both boundaries explicitly so a
          // physical trace can distinguish a raw link from an app-ready GATT
          // session without exposing packet contents.
          _authTrace(
            'native_connected',
            peer: peer,
            role: role,
            attempt: event.attempt,
          );
          _authTrace(
            'notifications_ready',
            peer: peer,
            role: role,
            attempt: event.attempt,
          );
          break;
        case 'disconnected':
          _authTrace(
            'native_disconnected',
            peer: peer,
            role: event.role,
            attempt: event.attempt,
            reason: _nativeFailureCategory(event.error),
          );
          break;
        case 'error':
          _authTrace(
            'native_error',
            peer: peer,
            role: event.role,
            attempt: event.attempt,
            reason: _nativeFailureCategory(event.error),
          );
          break;
      }
    }
    switch (event.type) {
      case 'deviceFound':
        if (peer != null && peer.isNotEmpty) {
          _log('relay_peer_discovered peer=${_safeCorrelation(peer)}');
          await _maybeConnect(peer);
        }
        return;
      case 'connected':
        if (peer == null || peer.isEmpty) return;
        final previous = _sessions[_sessionKey(peer, role)];
        final newNativeAttempt =
            event.attempt != null &&
            previous != null &&
            event.attempt != previous.nativeAttempt;
        if (!_connected.putIfAbsent(peer, () => <BleSessionRole>{}).add(role) &&
            !newNativeAttempt) {
          // Repeated readiness for the same active role is not a new
          // connection. Replacing it cancels an in-flight capability/proof
          // write and leaves a healthy GATT link unauthenticated.
          _log(
            'relayDuplicateConnectedIgnored peer=${_safeCorrelation(peer)} '
            'role=${role.wireValue}',
          );
          return;
        }
        _replaceSession(peer, role, nativeAttempt: event.attempt);
        _authTrace(
          'session_created',
          peer: peer,
          role: role,
          attempt: event.attempt,
          session: _sessions[_sessionKey(peer, role)],
        );
        _connecting.remove(peer);
        // A non-participating origin still needs to declare its installation
        // key and session role so an opted-in next hop can authenticate the
        // per-incident-authorized offer. This does not authorize this device
        // to accept or forward anyone else's SOS.
        if (_participating || _hasPendingWork) {
          try {
            await _sendCapabilities(peer, role);
          } on Object catch (error) {
            _authTrace(
              'session_failed',
              peer: peer,
              role: role,
              session: _sessions[_sessionKey(peer, role)],
              reason: _authenticationFailureCategory(error),
            );
            rethrow;
          }
        }
        await processDue();
        return;
      case 'disconnected':
        if (peer == null || peer.isEmpty) return;
        if (event.role == null) {
          _connected.remove(peer);
          _invalidatePeerSessions(peer);
        } else {
          _connected[peer]?.remove(event.role);
          if (_connected[peer]?.isEmpty ?? false) _connected.remove(peer);
          _invalidateSession(peer, event.role!);
        }
        _authTrace(
          'peer_removed',
          peer: peer,
          role: event.role,
          reason: _nativeFailureCategory(event.error),
        );
        _connecting.remove(peer);
        return;
      default:
        return;
    }
  }

  Future<bool> handleMessage(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    if (message.type == RelayCapabilityAdvertisement.wireKind) {
      _authTrace(
        'capability_received',
        peer: peer,
        role: role,
        session: _sessions[_sessionKey(peer, role)],
      );
      try {
        await _handleCapabilities(peer, role, message);
      } on Object catch (error) {
        _authTrace(
          'session_failed',
          peer: peer,
          role: role,
          session: _sessions[_sessionKey(peer, role)],
          reason: _authenticationFailureCategory(error),
        );
        rethrow;
      }
      return true;
    }
    if (message.type == RelaySessionChallenge.wireKind) {
      _authTrace(
        'session_challenge_received',
        peer: peer,
        role: role,
        session: _sessions[_sessionKey(peer, role)],
      );
      try {
        await _handleSessionChallenge(peer, role, message);
      } on Object catch (error) {
        _authTrace(
          'session_failed',
          peer: peer,
          role: role,
          session: _sessions[_sessionKey(peer, role)],
          reason: _authenticationFailureCategory(error),
        );
        rethrow;
      }
      return true;
    }
    if (message.type == RelaySessionResponse.wireKind) {
      _authTrace(
        'session_response_received',
        peer: peer,
        role: role,
        session: _sessions[_sessionKey(peer, role)],
      );
      try {
        await _handleSessionResponse(peer, role, message);
      } on Object catch (error) {
        _authTrace(
          'session_failed',
          peer: peer,
          role: role,
          session: _sessions[_sessionKey(peer, role)],
          reason: _authenticationFailureCategory(error),
        );
        rethrow;
      }
      return true;
    }
    if (message.type == RelayOfferTransfer.wireKind) {
      await _handleIncomingOffer(peer, role, message);
      return true;
    }
    if (message.type == RescueResponseTransfer.wireKind) {
      await _handleIncomingRescueTransfer(peer, role, message);
      return true;
    }
    if (message.type == ChatReceipt.transferKind) {
      await _handleChatReceipt(peer, role, message);
      return true;
    }
    if (message.type == ChatRelayTransfer.wireKind) {
      await _handleIncomingChatRelay(peer, role, message);
      return true;
    }
    if (message.type == 'chat.media.request.v1' ||
        message.type == 'chat.media.chunk.v1') {
      await _handleMediaPacket(peer, role, message);
      return true;
    }
    if (message.type == RelayReceiptType.hop.wireValue ||
        message.type == RelayReceiptType.finalRecipient.wireValue) {
      await _handleIncomingReceipt(peer, role, message);
      return true;
    }
    return false;
  }

  Future<void> _handleIncomingChatRelay(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final active = _requireSession(peer, role);
    final transfer = ChatRelayTransfer.fromJson(message.payload);
    await active.pendingInboundBindings[transfer.sessionBinding]?.future;
    await _waitForActiveProof(peer, role, active);
    final session = _requireProvenSession(peer, role);
    final repository = chatRelayRepository;
    if (repository == null) return;
    final identity = await _ensureIdentity();
    final declared = session.declaredPeer!;
    if (!identical(active, session) ||
        (transfer.sessionBinding != session.inboundBinding &&
            transfer.sessionBinding != session.outboundBinding) ||
        message.id != transfer.attemptId) {
      throw const RelayProtocolException(
        'Chat relay transfer binding is invalid.',
      );
    }
    final envelope = repository.decode(transfer.wireEnvelope);
    envelope.body.validate(now: _now());
    if (transfer.attemptId !=
            'chat:${envelope.body.messageId}:${identity.keyId}' ||
        !await transfer.verifyPath(
          immediateKeyId: declared.keyId,
          immediatePublicKey: declared.publicKey,
          localKeyId: identity.keyId,
        ) ||
        !await _cryptography.publicKeyMatchesId(
          envelope.body.recipientPublicKey,
          envelope.body.recipientKeyId,
        ) ||
        !await _cryptography.verifyChatRelay(envelope, now: _now())) {
      throw const RelayProtocolException('Chat relay authentication failed.');
    }
    await ChatRelayAuthorization(
      _database,
      ownerId: repository.ownerId,
    ).authorize(envelope, suppliedOffer: transfer.wireRescueOffer);
    if (!identical(_sessions[_sessionKey(peer, role)], session) ||
        !session.proofComplete) {
      throw const RelayProtocolException('Chat relay session changed.');
    }
    final isRecipient = identity.keyId == envelope.body.recipientKeyId;
    if (declared.keyId != envelope.body.senderKeyId &&
        !declared.participating) {
      throw const RelayProtocolException('Immediate Chat relay opted out.');
    }
    if (!isRecipient && !_participating) {
      throw const RelayProtocolException('Chat relay participation disabled.');
    }
    if (envelope.body.media != null) {
      await _authorizeMedia(envelope, transfer.wireRescueOffer);
      final store = mediaStore;
      if (store == null) {
        throw const RelayProtocolException('Media is not supported');
      }
      await store.bind(
        id: envelope.body.messageId,
        incident: envelope.body.incidentId,
        manifest: envelope.body.media!,
        envelope: envelope.toCanonicalWire(),
        expires: envelope.body.expiresAt,
        transfer: jsonEncode(transfer.toJson()),
        previousKey: declared.keyId,
      );
    }
    await _database.transaction(() async {
      await repository.persistIncoming(envelope, now: _now());
      await _chatReceipts.remember(transfer, _now());
      if (!isRecipient) {
        await repository.enqueue(
          envelope,
          now: _now(),
          hopCount: transfer.hopCount + 1,
          receivedTransfer: transfer,
        );
      }
    });
    if (isRecipient) {
      if (envelope.body.media == null ||
          (await mediaStore!.find(envelope.body.messageId))!.complete) {
        await onChatRelayReceived?.call(envelope);
        await _prepareRecipientReceipt(envelope);
      }
      _chatArrivedDuringDrain = true;
      unawaited(processDue());
      _log(
        'chat_relay_received incident=${envelope.body.incidentId} message=${envelope.body.messageId}',
      );
      return;
    }
    _hasPendingWork = true;
    _chatArrivedDuringDrain = true;
    unawaited(processDue());
    _log(
      'chat_relay_persisted incident=${envelope.body.incidentId} message=${envelope.body.messageId} hop=${transfer.hopCount}',
    );
  }

  Future<void> _handleIncomingRescueTransfer(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final transfer = RescueResponseTransfer.fromJson(message.payload);
    transfer.validate();
    final activeSession = _requireSession(peer, role);
    // A peer can receive our final proof-response frame before the native
    // write-completion callback lets us commit the derived inbound binding.
    // Wait only for that exact, cryptographically derived binding; arbitrary
    // or retired-session bindings still fail closed below.
    await activeSession.pendingInboundBindings[transfer.sessionBinding]?.future;
    await _waitForActiveProof(peer, role, activeSession);
    final session = _requireProvenSession(peer, role);
    if (!identical(session, activeSession)) {
      throw const RelayProtocolException('Rescue response session changed.');
    }
    _log(
      'response_transfer_received peer=${session.declaredPeer?.keyId} '
      'hop=${transfer.hopCount} ack=${transfer.isAck}',
    );
    if (transfer.sessionBinding != session.inboundBinding &&
        transfer.sessionBinding != session.outboundBinding) {
      throw const RelayProtocolException(
        'Rescue response session binding is invalid.',
      );
    }
    if (transfer.hopCount >= transfer.maxHops) {
      throw const RelayProtocolException('Rescue response hop limit reached.');
    }
    final inner = transfer.isAck
        ? RescueResponseAckEnvelope.fromCanonicalWire(transfer.wireEnvelope)
        : RescueResponseEnvelope.fromCanonicalWire(transfer.wireEnvelope);
    final originMessageId = transfer.isAck
        ? (inner as RescueResponseAckEnvelope).body.originMessageId
        : (inner as RescueResponseEnvelope).body.originMessageId;
    final stored = await _repository.lookupMessage(originMessageId);
    if (stored == null) {
      throw const RelayProtocolException(
        'Origin relay envelope is unavailable.',
      );
    }
    final origin = RelayOfferEnvelope.fromCanonicalWire(stored.wireEnvelope)
        .body;
    final response = transfer.isAck ? null : inner as RescueResponseEnvelope;
    if (response != null) {
      final accepted = await _rescueResponseRepository.recordIncoming(
        envelope: response,
        origin: origin,
        now: _now(),
      );
      if (!accepted) {
        _log('rescueResponseDuplicate');
      }
      _log(
        'response_origin_persisted incident=${origin.incidentId} '
        'response=${response.body.messageId}',
      );
      _log(
        'response_origin_verified incident=${origin.incidentId} '
        'response=${response.body.messageId} hop=${transfer.hopCount}',
      );
      final identity = await _ensureIdentity();
      if (identity.keyId == origin.originKeyId) {
        final ackBody = RescueResponseAckBody(
          ackId: 'ack:${response.body.messageId}:${identity.keyId}',
          responseMessageId: response.body.messageId,
          incidentId: origin.incidentId,
          originMessageId: origin.originMessageId,
          originKeyId: origin.originKeyId,
          signerKeyId: identity.keyId,
          signerPublicKey: base64UrlEncode(identity.publicKey),
          recipientKeyId: response.body.responderKeyId,
          sessionBinding: session.inboundBinding ?? session.outboundBinding!,
          createdAt: _now().toUtc(),
          expiresAt: _now().toUtc().add(const Duration(minutes: 10)),
        );
        final ack = RescueResponseAckEnvelope(
          body: ackBody,
          signature: await _cryptography.signRescueResponseAck(
            ackBody,
            identity.keyPair,
          ),
        );
        await _rescueResponseRepository.enqueueAck(
          ack: ack,
          response: response,
          now: _now(),
        );
        _log(
          'rescue_ack_enqueued incident=${origin.incidentId} '
          'response=${response.body.messageId}',
        );
        unawaited(processDue());
      } else {
        // A non-origin node stores the signed response and lets the normal
        // due-job drain choose another authenticated session opportunistically.
        await _rescueResponseRepository.enqueueOffer(
          envelope: response,
          origin: origin,
          now: _now(),
        );
        _log(
          'response_relay_persisted incident=${origin.incidentId} '
          'response=${response.body.messageId} hop=${transfer.hopCount}',
        );
        await processDue();
      }
    } else {
      final ack = inner as RescueResponseAckEnvelope;
      final outbox = await _rescueResponseRepository.findOutbox(
        ack.body.responseMessageId,
      );
      if (outbox != null) {
        final responseEnvelope = RescueResponseEnvelope.fromCanonicalWire(
          outbox.payload,
        );
        final identity = await _ensureIdentity();
        if (identity.keyId == ack.body.recipientKeyId) {
          final applied = await _rescueResponseRepository.applyFinalAck(
            ack: ack,
            response: responseEnvelope,
            origin: origin,
            now: _now(),
          );
          if (!applied) {
            throw const RelayProtocolException(
              'Rescue ACK could not be applied.',
            );
          }
          _log(
            'rescue_offer_delivered incident=${origin.incidentId} '
            'response=${ack.body.responseMessageId}',
          );
          _log(
            'rescue_ack_verified incident=${origin.incidentId} '
            'response=${ack.body.responseMessageId}',
          );
        } else {
          await _rescueResponseRepository.enqueueAck(
            ack: ack,
            response: responseEnvelope,
            now: _now(),
          );
          await processDue();
          _log(
            'rescue_ack_relayed incident=${origin.incidentId} '
            'response=${ack.body.responseMessageId}',
          );
        }
      }
    }
    _log('rescueResponsePersisted');
  }

  Future<void> processDue() async {
    if (!_started || !_foreground) return;
    final active = _processing;
    if (active != null) return active;
    final operation = _drainChatArrivals();
    _processing = operation;
    try {
      await operation;
    } finally {
      if (identical(_processing, operation)) _processing = null;
    }
  }

  // A newly persisted Chat may arrive after the active drain took its SQL
  // snapshot. Remember that arrival so coalescing processDue calls cannot
  // strand the job until the next periodic poll. Only Chat arrivals request
  // another pass; ordinary scheduler callbacks keep their existing behavior.
  Future<void> _drainChatArrivals() async {
    do {
      _chatArrivedDuringDrain = false;
      await _processDue();
    } while (_chatArrivedDuringDrain && _started && _foreground);
  }

  Future<void> enqueueChatRelay(ChatRelayEnvelope envelope) async {
    final repository = chatRelayRepository;
    if (repository == null) {
      throw const RelayPersistenceException(
        'Chat relay storage is unavailable.',
      );
    }
    await repository.enqueue(envelope, now: _now());
    _chatArrivedDuringDrain = true;
    _hasPendingWork = true;
    if (_started && _foreground) unawaited(processDue());
  }

  Future<ChatRelayEnvelope> signAndEnqueueChatRelay({
    required String messageId,
    required String incidentId,
    required String recipientKeyId,
    required String recipientPublicKey,
    required String text,
    required DateTime createdAt,
    String? originIncidentBinding,
    MediaManifest? media,
  }) async {
    final identity = await _ensureIdentity();
    if (recipientKeyId == identity.keyId) {
      throw const RelayProtocolException(
        'Outgoing relay Chat requires a remote participant.',
      );
    }
    final body = ChatRelayBody(
      messageId: messageId,
      incidentId: incidentId,
      senderKeyId: identity.keyId,
      senderPublicKey: base64UrlEncode(identity.publicKey),
      recipientKeyId: recipientKeyId,
      recipientPublicKey: recipientPublicKey,
      originIncidentBinding: originIncidentBinding ?? incidentId,
      text: text,
      media: media,
      createdAt: createdAt,
      expiresAt: createdAt.toUtc().add(const Duration(minutes: 30)),
    );
    final envelope = ChatRelayEnvelope(
      body: body,
      signature: await _cryptography.signChatRelay(body, identity.keyPair),
    );
    if (media != null) {
      final store = mediaStore;
      final file = await store?.find(messageId);
      if (file == null || !file.complete) {
        throw const RelayProtocolException('Media file is not ready');
      }
      await store!.bind(
        id: messageId,
        incident: incidentId,
        manifest: media,
        envelope: envelope.toCanonicalWire(),
        expires: body.expiresAt,
      );
    }
    await enqueueChatRelay(envelope);
    return envelope;
  }

  Future<bool> _hasActiveConversation() async {
    // Retain radio presence for an established, owner-scoped conversation even
    // when its send queue is empty and the original SOS transport TTL elapsed.
    // This does not opt the device into relaying anyone else's SOS.
    final row = await _database
        .customSelect(
          """
      SELECT 1 FROM sos_messages s
      WHERE s.owner_id = ? AND s.status = 'active' AND (
        EXISTS (SELECT 1 FROM rescue_response_inbox r
          WHERE r.owner_id = s.owner_id AND r.incident_id = s.id AND r.state = 'verified')
        OR EXISTS (SELECT 1 FROM rescue_response_outbox r
          WHERE r.owner_id = s.owner_id AND r.incident_id = s.id)
      ) LIMIT 1
    """,
          variables: [Variable<String>(_rescueResponseRepository.ownerId)],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<void> _processDue() async {
    final now = _now().toUtc();
    _log(
      'relay_scheduler_tick foreground=$_foreground participating=$_participating',
    );
    await _retryFailedSessionProofs(now);
    final chatRows = chatRelayRepository == null
        ? const <ChatRelayOutboxData>[]
        : await chatRelayRepository!.due(now: now);
    if (chatRows.isNotEmpty) {
      _hasPendingWork = true;
      await _ensureIdentity();
      await _ensureDiscovery();
      await _broadcastCapabilities();
    }
    final receiptRows = chatRelayRepository == null
        ? const <ChatReceiptData>[]
        : await _chatReceipts.pending(now);
    if (receiptRows.isNotEmpty) {
      _hasPendingWork = true;
      await _ensureIdentity();
      await _ensureDiscovery();
    }
    await _processChatReceipts(now);
    await _processRescueResponseDue(now);
    await _processChatRelayDue(now);
    await _repository.recoverStaleAttempts(
      olderThan: now.subtract(ackTimeout),
      now: now,
    );
    final storedMessages = await _repository.listForwardableMessages(now: now);
    final messages = _participating
        ? storedMessages
        : storedMessages
              .where(
                (message) =>
                    message.incomingPeerId == RelayRepository.localOriginPeerId,
              )
              .toList(growable: false);
    final hasConversation = await _hasActiveConversation();
    final mediaPending = mediaStore == null
        ? false
        : (await mediaStore!.pending(now)).isNotEmpty;
    if (hasConversation) {
      await _startAdvertising();
    } else if (!_participating) {
      await _stopAdvertising();
    }
    final hadPendingWork = _hasPendingWork;
    _hasPendingWork =
        messages.isNotEmpty ||
        chatRows.isNotEmpty ||
        receiptRows.isNotEmpty ||
        mediaPending ||
        hasConversation ||
        _pendingLocalControlWork;
    _log('relay_job_due count=${messages.length}');
    if (!_hasPendingWork) {
      _log('relay_scheduler_idle pending=0');
      if (_discoveryLeaseHeld) {
        await _presence.releaseDiscovery(_discoveryLease);
        _discoveryLeaseHeld = false;
      }
      return;
    }
    final retainedSessionsNeedingCapabilities = hadPendingWork
        ? const <(String, BleSessionRole)>[]
        : _connected.entries
              .expand((entry) => entry.value.map((role) => (entry.key, role)))
              .toList(growable: false);
    await _ensureIdentity();
    await _ensureDiscovery();
    // A native connection can be restored before start() has reloaded the
    // durable relay queue. That early connected event cannot advertise relay
    // capability because `_hasPendingWork` is still false. Once persisted work
    // is discovered, advertise on every retained session; otherwise both
    // peers can remain connected while the origin waits forever for a proven
    // eligible relay.
    if (retainedSessionsNeedingCapabilities.isNotEmpty) {
      await _broadcastCapabilitySessions(retainedSessionsNeedingCapabilities);
    }
    final participationGeneration = _participationGeneration;
    for (final message in messages) {
      if (participationGeneration != _participationGeneration) {
        return;
      }
      final offer = await _repository.loadVerifiedOffer(
        message.originMessageId,
        now: now,
      );
      final provenPeers = _provenPeers();
      if (provenPeers.isEmpty) {
        _log(
          'relay_forward_skipped reason=no_authenticated_peer '
          'incident=${_safeCorrelation(message.incidentId)}',
        );
      }
      for (final entry in provenPeers.entries) {
        final peer = entry.key;
        final capability = entry.value.peer;
        if (!capability.participating) {
          _log(
            'relay_forward_skipped reason=peer_not_participating peer=${_safeCorrelation(peer)}',
          );
          continue;
        }
        if (offer.pathKeyIds.contains(capability.keyId)) {
          _log(
            'relay_forward_skipped reason=path_loop peer=${_safeCorrelation(peer)}',
          );
          continue;
        }
        if (message.incomingPeerId == peer) {
          _log(
            'relay_forward_skipped reason=previous_hop peer=${_safeCorrelation(peer)}',
          );
          continue;
        }
        if (!(_connected[peer]?.isNotEmpty ?? false)) {
          _log(
            'relay_forward_skipped reason=session_not_connected peer=${_safeCorrelation(peer)}',
          );
          continue;
        }
        _log(
          'relay_forward_eligible incident=${_safeCorrelation(message.incidentId)} '
          'peer=${_safeCorrelation(peer)}',
        );
        await _sendOfferToPeer(
          message,
          peer,
          entry.value.role,
          capability,
          now,
          participationGeneration,
        );
      }
    }
    await _processMediaDue(now);
  }

  Future<void> _processMediaDue(DateTime now) async {
    final store = mediaStore;
    if (store == null || !_started || !_foreground) return;
    final identity = await _ensureIdentity();
    for (final media in await store.pending(now)) {
      try {
        final envelope = ChatRelayEnvelope.fromCanonicalWire(media.envelope!);
        final localRecipient = envelope.body.recipientKeyId == identity.keyId;
        if (!localRecipient && !_participating) continue;
        final transfer = ChatRelayTransfer.fromJson(
          Map<String, Object?>.from(jsonDecode(media.transfer!) as Map),
        );
        await _authorizeMedia(envelope, transfer.wireRescueOffer);
        final index = await store.nextMissing(media.id);
        if (index == null) {
          final recovered = await store.find(media.id);
          if (localRecipient && recovered?.complete == true) {
            await onChatRelayReceived?.call(envelope);
            await _prepareRecipientReceipt(envelope);
          }
          continue;
        }
        final routes = _provenPeers().entries.where(
          (r) => r.value.peer.keyId == media.previousKey,
        );
        if (routes.isEmpty) continue;
        final route = routes.first;
        final session = _requireProvenSession(route.key, route.value.role);
        if (!await store.claimRequest(media.id, index, now)) continue;
        await _sendMessage(
          route.key,
          route.value.role,
          BleMessage(
            id: 'media-request:${media.id}:$index:${now.microsecondsSinceEpoch}',
            type: 'chat.media.request.v1',
            createdAt: now,
            payload: {
              'messageId': media.id,
              'digest': media.manifest.digest,
              'index': index,
              'binding': session.outboundBinding,
            },
          ),
          sendAllowed: () =>
              session.proofComplete && (localRecipient || _participating),
        );
        // One bounded chunk request per scheduler pass; SOS/control/text ran first.
        break;
      } on Object {
        // Persisted request budget/backoff/expiry bounds retry across restarts.
      }
    }
  }

  Future<void> _handleMediaPacket(
    String peer,
    BleSessionRole role,
    BleMessage packet,
  ) async {
    final store = mediaStore;
    if (store == null) {
      throw const RelayProtocolException('Media not supported');
    }
    final session = _requireProvenSession(peer, role);
    final payload = packet.payload;
    if (payload['messageId'] is! String ||
        payload['digest'] is! String ||
        payload['index'] is! int ||
        (payload['binding'] != session.inboundBinding &&
            payload['binding'] != session.outboundBinding)) {
      throw const RelayProtocolException('Invalid media session binding');
    }
    final id = payload['messageId'] as String;
    final index = payload['index'] as int;
    final media = await store.find(id);
    if (media == null ||
        media.manifest.digest != payload['digest'] ||
        !(media.expires?.isAfter(_now()) ?? false)) {
      throw const RelayProtocolException('Unknown or expired media');
    }
    media.manifest.lengthAt(index);
    final envelope = ChatRelayEnvelope.fromCanonicalWire(media.envelope!);
    if (!await _cryptography.verifyChatRelay(envelope, now: _now())) {
      throw const RelayProtocolException('Invalid media signature');
    }
    final transfer = media.transfer == null
        ? null
        : ChatRelayTransfer.fromJson(
            Map<String, Object?>.from(jsonDecode(media.transfer!) as Map),
          );
    await _authorizeMedia(envelope, transfer?.wireRescueOffer);
    final identity = await _ensureIdentity();
    final localEndpoint =
        identity.keyId == envelope.body.senderKeyId ||
        identity.keyId == envelope.body.recipientKeyId;
    if (!_started ||
        !identical(_sessions[_sessionKey(peer, role)], session) ||
        !session.proofComplete) {
      throw const RelayProtocolException('Media session changed');
    }
    if (!localEndpoint && !_participating) {
      throw const RelayProtocolException('Media relay opted out');
    }
    final remoteKey = session.declaredPeer!.keyId;
    if (packet.type == 'chat.media.request.v1') {
      if (!media.complete ||
          !(media.state['targets'] as List? ?? []).contains(remoteKey)) {
        throw const RelayProtocolException('Media not authorized for this hop');
      }
      final replyKey = _sessionKey(peer, role);
      if (!_mediaReplies.add(replyKey)) return;
      try {
        final chunk = await store.chunk(id, index);
        await _sendMessage(
          peer,
          role,
          BleMessage(
            id: 'media-chunk:$id:$index:${packet.createdAt.microsecondsSinceEpoch}',
            type: 'chat.media.chunk.v1',
            createdAt: _now(),
            payload: {
              'messageId': id,
              'digest': media.manifest.digest,
              'index': index,
              'binding': session.outboundBinding,
              'data': base64UrlEncode(chunk.data),
              'proof': chunk.proof,
            },
          ),
          sendAllowed: () =>
              session.proofComplete && (localEndpoint || _participating),
        );
      } finally {
        _mediaReplies.remove(replyKey);
      }
      return;
    }
    if (remoteKey != media.previousKey ||
        payload['data'] is! String ||
        (payload['data'] as String).length > 5500 ||
        payload['proof'] is! List ||
        (payload['proof'] as List).length > 12) {
      throw const RelayProtocolException('Invalid media chunk source');
    }
    final complete = await store.putChunk(
      id,
      index,
      base64Url.decode(payload['data'] as String),
      List<String>.from(payload['proof'] as List),
    );
    if (complete.complete && identity.keyId == envelope.body.recipientKeyId) {
      await onChatRelayReceived?.call(envelope);
      await _prepareRecipientReceipt(envelope);
    }
    _hasPendingWork = true;
    _chatArrivedDuringDrain = true;
    unawaited(processDue());
  }

  final Set<String> _mediaReplies = {};

  Future<void> _prepareRecipientReceipt(ChatRelayEnvelope envelope) async {
    if (onChatRelayReceived == null) return;
    if (envelope.body.media != null) {
      final stored = await mediaStore?.find(envelope.body.messageId);
      if (stored == null || !stored.complete || !await stored.file.exists()) {
        return;
      }
    }
    final row = await _chatReceipts.route(envelope.body.messageId);
    if (row == null || row.receipt != null) return;
    final identity = await _ensureIdentity();
    if (identity.keyId != envelope.body.recipientKeyId ||
        !envelope.body.expiresAt.isAfter(_now())) {
      return;
    }
    // The presentation repository callback must have committed the actual
    // authorized message, not just the transport inbox, before signing.
    final chat =
        await (_database.select(_database.chatMessages)..where(
              (r) =>
                  r.ownerId.equals(chatRelayRepository!.ownerId) &
                  r.messageId.equals(envelope.body.messageId) &
                  r.sosId.equals(envelope.body.incidentId),
            ))
            .getSingleOrNull();
    if (chat == null ||
        chat.senderId != envelope.body.senderKeyId ||
        chat.textContent != envelope.body.text) {
      return;
    }
    final receipt = await ChatReceipt.sign(envelope, identity, _now());
    await receipt.verify(envelope, _now());
    await _chatReceipts.store(receipt, envelope, applied: false);
  }

  Future<void> _authorizeMedia(
    ChatRelayEnvelope envelope,
    String? offer,
  ) async {
    final owner = mediaStore!.ownerId;
    await ChatRelayAuthorization(
      _database,
      ownerId: owner,
    ).authorize(envelope, suppliedOffer: offer);
    final terminal = await IncidentLifecycleRepository(
      _database,
      ownerId: owner,
    ).authorizedEvents(incidentId: envelope.body.incidentId);
    final local =
        await (_database.select(_database.sosMessages)..where(
              (r) =>
                  r.ownerId.equals(owner) &
                  r.id.equals(envelope.body.incidentId),
            ))
            .getSingleOrNull();
    if (terminal.isNotEmpty || (local != null && local.status != 'active')) {
      throw const RelayProtocolException('Media incident is no longer active');
    }
  }

  Future<void> _handleChatReceipt(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final repo = chatRelayRepository;
    if (repo == null) return;
    final active = _requireSession(peer, role);
    final binding = message.payload['sessionBinding'];
    if (binding is! String) {
      throw const FormatException('Missing receipt session.');
    }
    await active.pendingInboundBindings[binding]?.future;
    await _waitForActiveProof(peer, role, active);
    final session = _requireProvenSession(peer, role);
    if (!identical(active, session) ||
        (binding != session.inboundBinding &&
            binding != session.outboundBinding)) {
      throw const FormatException('Receipt session changed.');
    }
    final wire = message.payload['receipt'];
    if (wire is! String) throw const FormatException('Missing receipt.');
    final receipt = ChatReceipt.fromWire(wire);
    final row = await repo.findOutbox(receipt.messageId);
    if (row == null) throw const FormatException('Unknown receipt message.');
    final envelope = repo.decode(row.payload);
    final identity = await _ensureIdentity();
    if (message.id != 'receipt:${receipt.messageId}:${identity.keyId}') {
      throw const FormatException('Receipt transport target invalid.');
    }
    await receipt.verify(envelope, _now());
    final localSender = identity.keyId == envelope.body.senderKeyId;
    if (!localSender &&
        (!_participating ||
            await _chatReceipts.route(receipt.messageId) == null)) {
      throw const FormatException('Receipt relay not authorized.');
    }
    if (!identical(_sessions[_sessionKey(peer, role)], session) ||
        !session.proofComplete) {
      throw const FormatException('Receipt session changed.');
    }
    await _chatReceipts.store(receipt, envelope, applied: localSender);
    _chatArrivedDuringDrain = true;
    unawaited(processDue());
    _log(
      'chat_receipt_verified message=${receipt.messageId} final=$localSender',
    );
  }

  Future<void> _processChatReceipts(DateTime now) async {
    final repo = chatRelayRepository;
    if (repo == null) return;
    final pending = await _chatReceipts.pending(now);
    if (pending.isEmpty) return;
    final identity = await _ensureIdentity();
    for (final row in pending) {
      var claimed = false;
      try {
        final transfer = _chatReceipts.decode(row.transfer);
        final envelope = repo.decode(transfer.wireEnvelope);
        if (row.messageId != envelope.body.messageId ||
            row.incidentId != envelope.body.incidentId ||
            row.previousKeyId != transfer.path.last ||
            row.expiresAt.millisecondsSinceEpoch ~/ 1000 !=
                envelope.body.expiresAt
                        .add(ChatReceipt.grace)
                        .millisecondsSinceEpoch ~/
                    1000 ||
            !await _cryptography.verifyChatRelay(
              envelope,
              now: envelope.body.createdAt,
            ) ||
            !await transfer.verifyPath(
              immediateKeyId: transfer.path.last,
              immediatePublicKey:
                  transfer.hops.last['senderPublicKey'] as String,
              localKeyId: identity.keyId,
            )) {
          throw const FormatException(
            'Stored receipt route integrity invalid.',
          );
        }
        await ChatRelayAuthorization(
          _database,
          ownerId: repo.ownerId,
        ).authorize(envelope, suppliedOffer: transfer.wireRescueOffer);
        if (row.receipt == null) {
          if (identity.keyId != envelope.body.recipientKeyId ||
              onChatRelayReceived == null ||
              !envelope.body.expiresAt.isAfter(now)) {
            continue;
          }
          await onChatRelayReceived!(envelope);
          await _prepareRecipientReceipt(envelope);
        }
        final receipt = await _chatReceipts.known(row.messageId);
        if (receipt == null) continue;
        await receipt.verify(envelope, now);
        if (identity.keyId != envelope.body.recipientKeyId && !_participating) {
          continue;
        }
        if (!await transfer.verifyPath(
          immediateKeyId: transfer.path.last,
          immediatePublicKey: transfer.hops.last['senderPublicKey'] as String,
          localKeyId: identity.keyId,
        )) {
          throw const FormatException('Stored receipt reverse route invalid.');
        }
        final routes = _provenPeers().entries.where(
          (e) => e.value.peer.keyId == row.previousKeyId,
        );
        if (routes.isEmpty) continue;
        final route = routes.first;
        final session = _sessions[_sessionKey(route.key, route.value.role)];
        if (session == null || !session.proofComplete) continue;
        // Claim retry durably before writing so a process restart cannot
        // reset the budget after an accepted write with a lost completion.
        await _chatReceipts.attempted(row.messageId, _now());
        claimed = true;
        await _sendMessage(
          route.key,
          route.value.role,
          BleMessage(
            id: 'receipt:${row.messageId}:${row.previousKeyId}',
            type: ChatReceipt.transferKind,
            payload: {
              'receipt': receipt.toWire(),
              'sessionBinding': session.outboundBinding,
            },
            createdAt: DateTime.parse(receipt.body['persistedAt'] as String),
          ),
          sendAllowed: () =>
              _started &&
              _foreground &&
              session.proofComplete &&
              identical(
                _sessions[_sessionKey(route.key, route.value.role)],
                session,
              ) &&
              (identity.keyId == envelope.body.recipientKeyId ||
                  _participating),
        );
      } on Object {
        if (!claimed) await _chatReceipts.attempted(row.messageId, _now());
      }
    }
  }

  Future<void> _processChatRelayDue(DateTime now) async {
    final repository = chatRelayRepository;
    if (repository == null) return;
    final rows = await repository.due(now: now);
    if (rows.isEmpty) return;
    final routes = _provenPeers();
    final identity = await _ensureIdentity();
    for (final row in rows) {
      try {
        final envelope = repository.decode(row.payload);
        envelope.body.validate(now: now);
        if (!await _cryptography.verifyChatRelay(envelope, now: now)) {
          throw const FormatException('Stored Chat signature invalid.');
        }
        final stored = repository.storedTransfer(row.payload);
        final localSender = identity.keyId == envelope.body.senderKeyId;
        if (!localSender && !_participating) continue;
        if (stored == null && !localSender) {
          throw const FormatException('Stored Chat hop evidence unavailable.');
        }
        if (stored != null &&
            !await stored.verifyPath(
              immediateKeyId: stored.path.last,
              immediatePublicKey: stored.hops.last['senderPublicKey'] as String,
              localKeyId: identity.keyId,
            )) {
          throw const FormatException('Stored Chat path invalid.');
        }
        final authorization = await ChatRelayAuthorization(
          _database,
          ownerId: repository.ownerId,
        ).authorize(envelope, suppliedOffer: stored?.wireRescueOffer);
        if (envelope.body.media != null) {
          await _authorizeMedia(envelope, stored?.wireRescueOffer);
          final file = await mediaStore?.find(envelope.body.messageId);
          if (file == null || !file.complete) continue;
        }
        if (identity.keyId == envelope.body.recipientKeyId) {
          await onChatRelayReceived?.call(envelope);
          await repository.markForwarded(row.messageId, now: now);
          continue;
        }
        final eligible = routes.entries.where(
          (e) =>
              (envelope.body.media == null || e.value.peer.mediaSupported) &&
              (e.value.peer.participating ||
                  e.value.peer.keyId == envelope.body.recipientKeyId) &&
              !(stored?.path.contains(e.value.peer.keyId) ?? false) &&
              e.value.peer.keyId != envelope.body.senderKeyId,
        );
        MapEntry<String, _ProvenRoute>? candidate;
        for (final entry in eligible) {
          if (entry.value.peer.keyId == envelope.body.recipientKeyId) {
            candidate = entry;
            break;
          }
        }
        // A relay may not know the final recipient's currently reachable
        // session. Forward opportunistically to one authenticated, opted-in
        // relay while keeping the immutable final recipient key in the signed
        // envelope. The next relay must repeat the same validation.
        candidate ??= eligible
            .cast<MapEntry<String, _ProvenRoute>?>()
            .firstWhere((entry) => entry != null, orElse: () => null);
        if (candidate == null) continue;
        final session =
            _sessions[_sessionKey(candidate.key, candidate.value.role)];
        if (session == null || !session.proofComplete) continue;
        final base =
            stored ??
            ChatRelayTransfer(
              attemptId: '',
              wireEnvelope: envelope.toCanonicalWire(),
              hopCount: 0,
              wireRescueOffer: authorization,
            );
        final transfer = await base.forNextHop(
          identity: identity,
          nextHopKeyId: candidate.value.peer.keyId,
          binding: session.outboundBinding ?? '',
        );
        if (envelope.body.media != null) {
          await mediaStore!.allowTarget(
            row.messageId,
            candidate.value.peer.keyId,
          );
        }
        await _sendMessage(
          candidate.key,
          candidate.value.role,
          BleMessage(
            id: transfer.attemptId,
            type: ChatRelayTransfer.wireKind,
            payload: transfer.toJson(),
            createdAt: envelope.body.createdAt,
          ),
          sendAllowed: () =>
              _started &&
              _foreground &&
              session.proofComplete &&
              identical(
                _sessions[_sessionKey(candidate!.key, candidate.value.role)],
                session,
              ) &&
              (session.declaredPeer?.participating == true ||
                  session.declaredPeer?.keyId ==
                      envelope.body.recipientKeyId) &&
              (localSender || _participating),
        );
        await repository.markForwarded(row.messageId, now: now);
        await onChatRelayForwarded?.call(row.messageId);
        _log(
          'chat_relay_forwarded incident=${row.incidentId} message=${row.messageId}',
        );
      } on Object catch (error) {
        await repository.markFailed(row.messageId, error, now: now);
      }
    }
  }

  Future<void> _processRescueResponseDue(DateTime now) async {
    if (!_started || !_foreground) return;
    final rows = await _rescueResponseRepository.listDueOutbox(now: now);
    if (rows.isEmpty) return;
    _log('response_job_due count=${rows.length}');
    final routes = _provenPeers();
    for (final row in rows) {
      final isAck = row.payload.contains('"kind":"rescue.offer_ack"');
      final targetKey = row.responderKeyId;
      RescueResponseTransfer? transfer;
      try {
        final sessionTarget = routes.entries
            .where((entry) {
              final declared = entry.value.peer.keyId;
              if (isAck) return declared == targetKey;
              return declared == row.originKeyId;
            })
            .toList(growable: false);
        final fallback = routes.entries.where(
          (entry) => entry.value.peer.keyId != targetKey,
        );
        final candidate = sessionTarget.isNotEmpty
            ? sessionTarget.first
            : (fallback.isNotEmpty ? fallback.first : null);
        if (candidate == null) continue;
        if (isAck) {
          RescueResponseAckEnvelope.fromCanonicalWire(row.payload).validate();
        } else {
          RescueResponseEnvelope.fromCanonicalWire(row.payload).validate();
        }
        final session =
            _sessions[_sessionKey(candidate.key, candidate.value.role)];
        if (session == null || !session.proofComplete) continue;
        transfer = RescueResponseTransfer(
          attemptId: 'rescue:${row.messageId}:${candidate.value.peer.keyId}',
          correlationId: 'rescue-correlation:${row.messageId}',
          sessionBinding: session.outboundBinding ?? '',
          wireEnvelope: row.payload,
          hopCount: 0,
          maxHops: RelayProtocolLimits.maximumHops,
          isAck: isAck,
        );
        transfer.validate();
        final claimed = await _rescueResponseRepository.queueAttempt(
          messageId: row.messageId,
          nextHopKeyId: candidate.value.peer.keyId,
          nextHopDeviceId: candidate.key,
          sessionBinding: session.outboundBinding ?? '',
          now: now,
        );
        if (!claimed) continue;
        _log(
          'response_forward_started incident=${row.incidentId} '
          'response=${row.messageId} hop=0',
        );
        await _sendMessage(
          candidate.key,
          candidate.value.role,
          BleMessage(
            id: transfer.attemptId,
            type: RescueResponseTransfer.wireKind,
            payload: transfer.toJson(),
            createdAt: now,
          ),
          sendAllowed: () =>
              session.proofComplete &&
              identical(
                _sessions[_sessionKey(candidate.key, candidate.value.role)],
                session,
              ),
        );
        await _rescueResponseRepository.markState(
          row.messageId,
          RescueResponseDeliveryState.forwarded,
          now: _now(),
        );
        _log(
          'response_transfer_completed incident=${row.incidentId} '
          'response=${row.messageId}',
        );
      } on Object catch (error) {
        await _rescueResponseRepository.markState(
          row.messageId,
          RescueResponseDeliveryState.failed,
          now: _now(),
          error: error.toString(),
        );
      }
    }
  }

  Future<void> _sendOfferToPeer(
    BleRelayMessage message,
    String peer,
    BleSessionRole role,
    _RelayPeer capability,
    DateTime now,
    int participationGeneration,
  ) async {
    final locallyOriginated =
        message.incomingPeerId == RelayRepository.localOriginPeerId;
    if (!_relaySendAllowed(
      peer,
      role,
      participationGeneration,
      locallyOriginated: locallyOriginated,
      originMessageId: message.originMessageId,
    )) {
      return;
    }
    final identity = await _ensureIdentity();
    final outgoing = await _repository.prepareOutgoingOffer(
      originMessageId: message.originMessageId,
      identity: identity,
      now: now,
    );
    final correlation = await _cryptography.forwardCorrelationId(
      originMessageId: message.originMessageId,
      immutableDigest: message.immutableDigest,
      nextHopKeyId: capability.keyId,
    );
    var attempt = await _repository.createNextHopAttempt(
      originMessageId: message.originMessageId,
      nextHopKeyId: capability.keyId,
      nextHopDeviceId: peer,
      localRelayKeyId: identity.keyId,
      correlationId: correlation,
      now: now,
    );
    if (attempt.state == RelayAttemptState.acceptedByRelay.wireValue ||
        (attempt.state == RelayAttemptState.failed.wireValue &&
            attempt.retryCount >= RelayRepository.maximumRetriesPerPeer)) {
      return;
    }
    final claimed = await _repository.claimAttemptForSending(
      originMessageId: message.originMessageId,
      attemptId: attempt.attemptId,
      now: now,
    );
    if (claimed == null) return;
    final transfer = RelayOfferTransfer(
      wireOffer: outgoing.toCanonicalWire(),
      attemptId: attempt.attemptId,
      correlationId: attempt.correlationId,
    );
    try {
      _timing(
        'forwarding_started',
        message.originMessageId,
        peer: peer,
        hop: message.incomingHopCount + 1,
        retry: attempt.retryCount,
      );
      await _sendMessage(
        peer,
        role,
        BleMessage(
          id: attempt.attemptId,
          type: RelayOfferTransfer.wireKind,
          payload: transfer.toJson(),
          createdAt: outgoing.body.createdAt,
        ),
        sendAllowed: () => _relaySendAllowed(
          peer,
          role,
          participationGeneration,
          locallyOriginated: locallyOriginated,
          originMessageId: message.originMessageId,
        ),
      );
      if (_cancelledOriginMessageIds.contains(message.originMessageId)) return;
      // A physical relay offer can span hundreds of 20-byte BLE frames. Start
      // the application-receipt timeout only after the complete native write;
      // otherwise a slow but healthy transfer can be recovered as stale while
      // it is still in flight, making its later signed receipt inadmissible.
      attempt = await _repository.markAttemptAwaitingHopReceipt(
        originMessageId: message.originMessageId,
        attemptId: attempt.attemptId,
        now: _now(),
      );
      _timing(
        'transfer_completed',
        message.originMessageId,
        peer: peer,
        hop: message.incomingHopCount + 1,
        retry: attempt.retryCount,
      );
      _log(
        attempt.state == RelayAttemptState.acceptedByRelay.wireValue
            ? 'relayOfferAcceptedDuringNativeCompletion'
            : 'relayOfferWrittenAwaitingHopReceipt',
      );
    } on Object {
      if (_cancelledOriginMessageIds.contains(message.originMessageId)) return;
      await _repository.markAttemptFailed(
        originMessageId: message.originMessageId,
        attemptId: attempt.attemptId,
        error: 'Native relay write failed.',
        retryDelay: _retryDelay(attempt.retryCount + 1),
        now: _now(),
      );
      _log('relayOfferWriteFailed');
    }
  }

  Future<void> _handleCapabilities(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    var session = _requireSession(peer, role);
    final advertisement = RelayCapabilityAdvertisement.fromJson(
      message.payload,
    );
    if (advertisement.relayKeyId == null) {
      session.invalidate();
      return;
    }
    if (!await _cryptography.publicKeyMatchesId(
      advertisement.relayPublicKey!,
      advertisement.relayKeyId!,
    )) {
      throw const RelayProtocolException('Relay capability key mismatch.');
    }
    if (!identical(_sessions[_sessionKey(peer, role)], session)) return;
    final declared = _RelayPeer(
      keyId: advertisement.relayKeyId!,
      publicKey: advertisement.relayPublicKey!,
      participating: advertisement.participating,
      sessionGeneration: advertisement.sessionGeneration!,
      sessionRole: advertisement.sessionRole!,
      mediaSupported: advertisement.capabilities.contains('chat.media.v1'),
    );
    if (declared.sessionRole != _oppositeRole(role).wireValue) {
      session.invalidate();
      throw const RelayProtocolException(
        'Relay capability role does not match the active session.',
      );
    }
    final identity = await _ensureIdentity();
    if (!identical(_sessions[_sessionKey(peer, role)], session)) return;
    if (identity.keyId == declared.keyId) {
      session.invalidate();
      throw const RelayProtocolException(
        'Relay cannot establish a session with its own installation key.',
      );
    }
    final duplicateSession = _activeSessionForInstallation(
      declared.keyId,
      excluding: session,
    );
    if (duplicateSession != null) {
      // Native BLE addresses are not durable device identities. In
      // particular, two opted-in peers can discover and connect to each other
      // at the same time. "First capability wins" is not symmetric: each end
      // can retain a different physical link and then disconnect the link the
      // other end retained. Derive the preferred local role from the two
      // authenticated installation keys so both ends choose the same link.
      final preferredRole = identity.keyId.compareTo(declared.keyId) < 0
          ? BleSessionRole.central
          : BleSessionRole.peripheral;
      final duplicateHasPreferredRole =
          duplicateSession.session.role == preferredRole;
      if (role != preferredRole || duplicateHasPreferredRole) {
        await _rejectDuplicateSession(peer, role);
        _log('relayDuplicateInstallationSessionRejected');
        return;
      }
      await _rejectDuplicateSession(
        duplicateSession.peer,
        duplicateSession.session.role,
      );
      _log('relayDuplicateInstallationSessionRebound');
    }
    if (!identical(_sessions[_sessionKey(peer, role)], session)) return;
    var existing = session.declaredPeer;
    if (existing != null &&
        (existing.keyId != declared.keyId ||
            existing.publicKey != declared.publicKey ||
            existing.sessionRole != declared.sessionRole)) {
      session.invalidate();
      throw const RelayProtocolException(
        'Relay capability key changed within an active session.',
      );
    }
    final verifiedGeneration = session.verifiedPeerGeneration;
    if (verifiedGeneration != null &&
        declared.sessionGeneration < verifiedGeneration) {
      _log('relayStaleCapabilityIgnored');
      return;
    }
    if (existing != null &&
        existing.sessionGeneration != declared.sessionGeneration) {
      final old = session;
      final deferred = old.deferredPeerChallenge;
      final seen = old.seenChallengeNonces.toList();
      session =
          _RelaySession(
              generation: old.generation,
              role: old.role,
              nativeAttempt: old.nativeAttempt,
            )
            ..verifiedPeerGeneration = verifiedGeneration
            ..deferredPeerChallenge = deferred;
      session.seenChallengeNonces.addAll(seen);
      old.invalidate();
      _sessions[_sessionKey(peer, role)] = session;
      existing = null;
      _log('relayPeerProofGenerationChanged');
    }
    if (existing != null &&
        existing.participating == declared.participating &&
        (session.proofComplete ||
            session.challengeIssuing != null ||
            session.pendingChallenge != null ||
            session.respondingChallengeNonces.isNotEmpty ||
            session.pendingInboundBindings.isNotEmpty)) {
      return;
    }
    final deferredChallenge = session.deferredPeerChallenge;
    final seenNonces = session.seenChallengeNonces.toList();
    session.resetProof();
    session.seenChallengeNonces.addAll(seenNonces);
    session.declaredPeer = declared;
    if (deferredChallenge != null) {
      await _respondToSessionChallenge(peer, role, session, deferredChallenge);
    }
    await _issueSessionChallenge(peer, session);
  }

  Future<void> _handleIncomingOffer(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    if (!_participating) {
      _log('relayOfferIgnoredParticipationDisabled');
      return;
    }
    final participationGeneration = _participationGeneration;
    final incomingSession = _requireSession(peer, role);
    await _waitForActiveProof(peer, role, incomingSession);
    final session = _requireProvenSession(peer, role);
    if (session.outboundBinding == null) {
      throw const RelayProtocolException(
        'Relay offer session binding is incomplete.',
      );
    }
    final sender = session.declaredPeer;
    if (sender == null) {
      throw const RelayProtocolException(
        'Relay offer arrived before session proof.',
      );
    }
    final identity = await _ensureIdentity();
    final transfer = RelayOfferTransfer.fromJson(message.payload);
    final offer = RelayOfferEnvelope.fromCanonicalWire(transfer.wireOffer);
    _timing(
      'envelope_validated',
      offer.body.originMessageId,
      peer: peer,
      hop: offer.hopCount,
    );
    if (message.id != transfer.attemptId ||
        message.createdAt.toUtc() != offer.body.createdAt.toUtc() ||
        sender.keyId != offer.immediateSenderKeyId ||
        transfer.attemptId !=
            await RelayRepository.attemptIdFor(
              offer.body.originMessageId,
              identity.keyId,
            )) {
      throw const RelayProtocolException('Relay transfer binding is invalid.');
    }
    final expectedCorrelation = await _cryptography.forwardCorrelationId(
      originMessageId: offer.body.originMessageId,
      immutableDigest: await _cryptography.immutableDigest(offer.body),
      nextHopKeyId: identity.keyId,
    );
    if (transfer.correlationId != expectedCorrelation) {
      throw const RelayProtocolException('Relay correlation is invalid.');
    }
    final accepted = await _repository.acceptIncomingOffer(
      offer,
      sourceDeviceId: peer,
      relayEnabled: true,
      participationStillEnabled: () =>
          _participating &&
          participationGeneration == _participationGeneration &&
          identical(_sessions[_sessionKey(peer, role)], session) &&
          session.proofComplete,
      now: _now(),
    );
    await IncidentLifecycleRepository(
      _database,
      ownerId: _rescueResponseRepository.ownerId,
    ).reconcileIncident(offer.body.incidentId, now: _now());
    _log(
      'relay_job_persisted incident=${_safeCorrelation(offer.body.incidentId)} '
      'duplicate=${accepted.duplicate}',
    );
    // The durable hop copy is already safe to forward. Do not make the next
    // hop wait for the receipt write back to the previous hop; on physical
    // links that write can be a long multi-frame operation and used to stall
    // B→C forwarding behind A→B acknowledgement traffic.
    _hasPendingWork = true;
    unawaited(processDue());
    if (offer.body.scope == RelayAuthorizationScope.voluntaryRescue &&
        (rescueModeEnabled?.call() ?? false) &&
        rescueInbox != null) {
      await rescueInbox!.insertCandidate(
        offer,
        immutableDigest: await _cryptography.immutableDigest(offer.body),
        now: _now(),
      );
      _timing(
        'candidate_persisted',
        offer.body.originMessageId,
        peer: peer,
        hop: offer.hopCount,
      );
      _log('rescueCandidatePersisted origin=${offer.body.originMessageId}');
    }
    if (!_participating ||
        participationGeneration != _participationGeneration ||
        !identical(_sessions[_sessionKey(peer, role)], session) ||
        !session.proofComplete) {
      _log('relayHopReceiptSuppressedAfterOptOut');
      return;
    }
    final unsigned = RelayReceiptEnvelope(
      receiptId: await _cryptography.hopReceiptId(
        originMessageId: offer.body.originMessageId,
        attemptId: transfer.attemptId,
        signerKeyId: identity.keyId,
      ),
      type: RelayReceiptType.hop,
      originMessageId: offer.body.originMessageId,
      incidentId: offer.body.incidentId,
      immutableDigest: await _cryptography.immutableDigest(offer.body),
      signerKeyId: identity.keyId,
      signerPublicKey: base64UrlEncode(identity.publicKey),
      status: 'persisted',
      createdAt: accepted.row.persistedAt.toUtc(),
      expiresAt: accepted.row.retentionDeadline.toUtc(),
      signature: base64UrlEncode(List<int>.filled(64, 0)),
      correlationId: transfer.correlationId,
      attemptId: transfer.attemptId,
      // Bind the receipt to the proof challenge issued by this receiver. The
      // offer sender stores the same value as its inbound binding after it
      // answers that challenge, so a receipt cannot be replayed onto another
      // physical session. Do not depend on the reciprocal challenge: either
      // direction can be lost independently on a real GATT link.
      sessionBinding: session.outboundBinding,
    );
    final receipt = RelayReceiptEnvelope(
      receiptId: unsigned.receiptId,
      type: unsigned.type,
      originMessageId: unsigned.originMessageId,
      incidentId: unsigned.incidentId,
      immutableDigest: unsigned.immutableDigest,
      signerKeyId: unsigned.signerKeyId,
      signerPublicKey: unsigned.signerPublicKey,
      status: unsigned.status,
      createdAt: unsigned.createdAt,
      expiresAt: unsigned.expiresAt,
      signature: await _cryptography.signReceipt(unsigned, identity.keyPair),
      correlationId: unsigned.correlationId,
      attemptId: unsigned.attemptId,
      sessionBinding: unsigned.sessionBinding,
    );
    await _sendMessage(
      peer,
      role,
      BleMessage(
        id: receipt.receiptId,
        type: receipt.type.wireValue,
        payload: receipt.toJson(),
        createdAt: receipt.createdAt,
      ),
    );
    _hasPendingWork = true;
    _log(
      accepted.duplicate ? 'relayDuplicateReacknowledged' : 'relayPersisted',
    );
    _timing(
      'relay_persisted',
      offer.body.originMessageId,
      peer: peer,
      hop: offer.hopCount,
    );
    await processDue();
  }

  Future<void> _handleIncomingReceipt(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final incomingSession = _requireSession(peer, role);
    await _waitForActiveProof(peer, role, incomingSession);
    final session = _requireProvenSession(peer, role);
    final receipt = RelayReceiptEnvelope.fromJson(message.payload);
    if (message.id != receipt.receiptId ||
        message.createdAt.toUtc() != receipt.createdAt.toUtc()) {
      throw const RelayProtocolException('Relay receipt transport mismatch.');
    }
    if (receipt.type == RelayReceiptType.finalRecipient) {
      // RelayRepository also rejects this. Keep the transport gate explicit so
      // no future caller can reinterpret a final receipt as a hop receipt.
      throw const RelayProtocolException(
        'Final recipient receipts are unsupported in hop-only relay.',
      );
    }
    final declared = session.declaredPeer;
    if (declared == null ||
        declared.keyId != receipt.signerKeyId ||
        session.inboundBinding == null ||
        receipt.sessionBinding != session.inboundBinding) {
      throw const RelayProtocolException(
        'Hop receipt peer binding is invalid.',
      );
    }
    await _repository.persistReceipt(
      receipt,
      sourcePeerDeviceId: peer,
      now: _now(),
    );
    _log('relayStoredOnNextHop');
  }

  Future<void> _issueSessionChallenge(
    String peer,
    _RelaySession session,
  ) async {
    final declared = session.declaredPeer;
    if (declared == null ||
        session.proofComplete ||
        session.pendingChallenge != null ||
        session.challengeIssuing != null) {
      return;
    }
    final reservation = Object();
    session.challengeIssuing = reservation;
    session.proofReady = Completer<void>();
    try {
      await _signAndSendSessionChallenge(peer, session, declared, reservation);
    } on Object {
      if (identical(session.challengeIssuing, reservation)) {
        if (session.proofReady != null && !session.proofReady!.isCompleted) {
          session.proofReady!.complete();
        }
        session.proofRetryAt ??= _now().toUtc().add(
          _retryDelay(session.proofRecoveryAttempts + 1),
        );
      }
      rethrow;
    } finally {
      if (identical(session.challengeIssuing, reservation)) {
        session.challengeIssuing = null;
      }
    }
  }

  Future<void> _signAndSendSessionChallenge(
    String peer,
    _RelaySession session,
    _RelayPeer declared,
    Object reservation,
  ) async {
    bool current() =>
        identical(_sessions[_sessionKey(peer, session.role)], session) &&
        identical(session.challengeIssuing, reservation) &&
        identical(session.declaredPeer, declared);
    final identity = await _ensureIdentity();
    if (!current()) return;
    final unsigned = RelaySessionChallenge(
      nonce: base64UrlEncode(_nonceSource()),
      challengerKeyId: identity.keyId,
      challengerPublicKey: base64UrlEncode(identity.publicKey),
      challengedKeyId: declared.keyId,
      challengerRole: session.role.wireValue,
      challengedRole: _oppositeRole(session.role).wireValue,
      challengerGeneration: session.generation,
      challengedGeneration: declared.sessionGeneration,
      challengerParticipating: _participating,
      signature: base64UrlEncode(List<int>.filled(64, 0)),
    );
    final challenge = RelaySessionChallenge(
      nonce: unsigned.nonce,
      challengerKeyId: unsigned.challengerKeyId,
      challengerPublicKey: unsigned.challengerPublicKey,
      challengedKeyId: unsigned.challengedKeyId,
      challengerRole: unsigned.challengerRole,
      challengedRole: unsigned.challengedRole,
      challengerGeneration: unsigned.challengerGeneration,
      challengedGeneration: unsigned.challengedGeneration,
      challengerParticipating: unsigned.challengerParticipating,
      signature: await _cryptography.signSessionChallenge(
        unsigned,
        identity.keyPair,
      ),
    );
    if (!current()) return;
    session.pendingChallenge = challenge;
    session.proofRetryAt = null;
    session.proofTimeout?.cancel();
    session.proofTimeout = null;
    _authTrace(
      'session_challenge_started',
      peer: peer,
      role: session.role,
      session: session,
    );
    try {
      await _sendMessage(
        peer,
        session.role,
        BleMessage(
          id: 'relay-proof-challenge:${session.generation}',
          type: RelaySessionChallenge.wireKind,
          payload: challenge.toJson(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
      _authTrace(
        'session_challenge_completed',
        peer: peer,
        role: session.role,
        session: session,
      );
    } on Object {
      if (identical(session.pendingChallenge, challenge)) {
        session.pendingChallenge = null;
        session.proofComplete = false;
        if (session.proofReady != null && !session.proofReady!.isCompleted) {
          session.proofReady!.complete();
        }
        session.proofRetryAt = _now().toUtc().add(
          _retryDelay(session.proofRecoveryAttempts + 1),
        );
      }
      rethrow;
    }
    // The proof payload spans many 20-byte BLE frames on the physical
    // transport. Starting this timer before the challenge write completed
    // consumed most (or all) of the response window and cleared the active
    // challenge while a valid response was still arriving. Start the response
    // timeout only after the complete challenge has been handed to BLE. A
    // full-duplex response may already have completed by then, in which case
    // _handleSessionResponse cleared pendingChallenge and no timer is needed.
    if (identical(session.pendingChallenge, challenge)) {
      session.proofTimeout = _proofTimer(proofTimeout, () {
        if (identical(session.pendingChallenge, challenge)) {
          session.pendingChallenge = null;
          session.proofComplete = false;
          if (session.proofReady != null && !session.proofReady!.isCompleted) {
            session.proofReady!.complete();
          }
          session.proofRetryAt = _now().toUtc().add(
            _retryDelay(session.proofRecoveryAttempts + 1),
          );
          _log('relaySessionProofTimedOut');
          _authTrace(
            'session_failed',
            peer: peer,
            role: session.role,
            session: session,
            reason: 'proof_timeout',
          );
        }
      });
    }
  }

  Future<void> _handleSessionChallenge(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final session = _requireSession(peer, role);
    final challenge = RelaySessionChallenge.fromJson(message.payload);
    final declared = session.declaredPeer;
    if (declared == null ||
        challenge.challengerGeneration != declared.sessionGeneration) {
      // A capability advertisement is unsigned and can be lost before a long
      // signed challenge completes on a physical GATT link. The challenge
      // carries the same installation key, participation, role and generation
      // facts under an Ed25519 signature. Recover the missing declaration only
      // after binding every local-session field and verifying that signature;
      // malformed, replayed or wrong-session challenges still fail closed.
      final identity = await _ensureIdentity();
      if ((declared != null &&
              (challenge.challengerKeyId != declared.keyId ||
                  challenge.challengerPublicKey != declared.publicKey)) ||
          (session.verifiedPeerGeneration != null &&
              challenge.challengerGeneration <
                  session.verifiedPeerGeneration!) ||
          challenge.challengedKeyId != identity.keyId ||
          challenge.challengerRole != _oppositeRole(role).wireValue ||
          challenge.challengedRole != role.wireValue ||
          challenge.challengedGeneration != session.generation ||
          !await _cryptography.verifySessionChallenge(challenge)) {
        throw const RelayProtocolException(
          'Relay challenge cannot recover the missing capability.',
        );
      }
      if (!identical(_sessions[_sessionKey(peer, role)], session)) return;
      session.deferredPeerChallenge = challenge;
      _log('relaySessionCapabilityRecoveredFromChallenge');
      await _handleCapabilities(
        peer,
        role,
        BleMessage(
          id: 'relay-capabilities-v1',
          type: RelayCapabilityAdvertisement.wireKind,
          payload: RelayCapabilityAdvertisement(
            capabilities: [
              RelayProtocolCapabilities.relayV2,
              if (mediaStore != null) 'chat.media.v1',
            ],
            participating: challenge.challengerParticipating,
            relayKeyId: challenge.challengerKeyId,
            relayPublicKey: challenge.challengerPublicKey,
            sessionGeneration: challenge.challengerGeneration,
            sessionRole: challenge.challengerRole,
          ).toJson(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
      return;
    }
    await _respondToSessionChallenge(peer, role, session, challenge);
  }

  Future<void> _respondToSessionChallenge(
    String peer,
    BleSessionRole role,
    _RelaySession session,
    RelaySessionChallenge challenge,
  ) async {
    final declared = session.declaredPeer;
    if (declared == null) {
      throw const RelayProtocolException(
        'Relay challenge arrived before capability exchange.',
      );
    }
    final identity = await _ensureIdentity();
    if (challenge.challengerKeyId != declared.keyId ||
        challenge.challengerPublicKey != declared.publicKey ||
        challenge.challengedKeyId != identity.keyId ||
        challenge.challengerRole != _oppositeRole(role).wireValue ||
        challenge.challengedRole != role.wireValue ||
        challenge.challengedGeneration != session.generation ||
        challenge.challengerGeneration != declared.sessionGeneration ||
        challenge.challengerParticipating != declared.participating ||
        session.seenChallengeNonces.contains(challenge.nonce) ||
        !await _cryptography.verifySessionChallenge(challenge)) {
      throw const RelayProtocolException('Relay session challenge is invalid.');
    }
    if (!identical(_sessions[_sessionKey(peer, role)], session)) return;
    // A duplicate callback while the first response is still being written is
    // not a second authenticated operation. The original write owns it.
    if (!session.respondingChallengeNonces.add(challenge.nonce)) return;
    try {
      final unsigned = RelaySessionResponse(
        challenge: challenge,
        responderKeyId: identity.keyId,
        responderPublicKey: base64UrlEncode(identity.publicKey),
        responderGeneration: session.generation,
        responderParticipating: _participating,
        signature: base64UrlEncode(List<int>.filled(64, 0)),
      );
      final response = RelaySessionResponse(
        challenge: unsigned.challenge,
        responderKeyId: unsigned.responderKeyId,
        responderPublicKey: unsigned.responderPublicKey,
        responderGeneration: unsigned.responderGeneration,
        responderParticipating: unsigned.responderParticipating,
        signature: await _cryptography.signSessionResponse(
          unsigned,
          identity.keyPair,
        ),
      );
      _authTrace(
        'session_response_generated',
        peer: peer,
        role: role,
        session: session,
      );
      final inboundBinding = await _cryptography.relaySessionBinding(
        challenge,
        response,
      );
      if (!identical(_sessions[_sessionKey(peer, role)], session)) return;
      final bindingReady = Completer<void>();
      session.pendingInboundBindings[inboundBinding] = bindingReady;
      try {
        await _sendMessage(
          peer,
          role,
          BleMessage(
            id: 'relay-proof-response:${challenge.nonce}',
            type: RelaySessionResponse.wireKind,
            payload: response.toJson(),
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
        _authTrace(
          'session_response_completed',
          peer: peer,
          role: role,
          session: session,
        );
        // Commit replay protection and the inbound binding only after the whole
        // response has been handed to BLE. If foreground loss or a disconnect
        // interrupts the write, the same signed challenge remains retryable on
        // this still-active session instead of becoming permanently poisoned.
        if (!identical(_sessions[_sessionKey(peer, role)], session) ||
            !identical(
              session.pendingInboundBindings[inboundBinding],
              bindingReady,
            )) {
          throw const RelayProtocolException('Relay proof session changed.');
        }
        session.deferredPeerChallenge = null;
        session.seenChallengeNonces.add(challenge.nonce);
        session.inboundBinding = inboundBinding;
      } finally {
        if (identical(
          session.pendingInboundBindings[inboundBinding],
          bindingReady,
        )) {
          session.pendingInboundBindings.remove(inboundBinding);
        }
        if (!bindingReady.isCompleted) bindingReady.complete();
      }
    } finally {
      session.respondingChallengeNonces.remove(challenge.nonce);
    }
  }

  Future<void> _handleSessionResponse(
    String peer,
    BleSessionRole role,
    BleMessage message,
  ) async {
    final session = _requireSession(peer, role);
    final declared = session.declaredPeer;
    final pending = session.pendingChallenge;
    if (declared == null || pending == null) {
      throw const RelayProtocolException(
        'Relay session response has no active challenge.',
      );
    }
    final response = RelaySessionResponse.fromJson(message.payload);
    if (relayCanonicalJson(response.challenge.toJson()) !=
            relayCanonicalJson(pending.toJson()) ||
        response.responderKeyId != declared.keyId ||
        response.responderPublicKey != declared.publicKey ||
        response.responderGeneration != declared.sessionGeneration ||
        response.responderParticipating != declared.participating ||
        !await _cryptography.verifySessionResponse(response)) {
      throw const RelayProtocolException('Relay session response is invalid.');
    }
    final outboundBinding = await _cryptography.relaySessionBinding(
      response.challenge,
      response,
    );
    if (!identical(_sessions[_sessionKey(peer, role)], session) ||
        !identical(session.pendingChallenge, pending)) {
      throw const RelayProtocolException('Relay proof session changed.');
    }
    session.proofTimeout?.cancel();
    session.proofTimeout = null;
    session.pendingChallenge = null;
    session.proofComplete = true;
    session.proofRetryAt = null;
    session.outboundBinding = outboundBinding;
    session.verifiedPeerGeneration = declared.sessionGeneration;
    if (session.proofReady != null && !session.proofReady!.isCompleted) {
      session.proofReady!.complete();
    }
    _log('relaySessionProofEstablished');
    _authTrace(
      'session_authenticated',
      peer: peer,
      role: role,
      session: session,
    );
    _log(
      'authenticated_peer_ready peer=${session.declaredPeer?.keyId ?? 'unknown'}',
    );
    await processDue();
  }

  _RelaySession _requireSession(String peer, BleSessionRole role) {
    final session = _sessions[_sessionKey(peer, role)];
    if (session == null || !(_connected[peer]?.contains(role) ?? false)) {
      throw const RelayProtocolException(
        'Relay transport session is inactive.',
      );
    }
    return session;
  }

  Future<void> _waitForActiveProof(
    String peer,
    BleSessionRole role,
    _RelaySession session,
  ) async {
    // Do not authenticate from a declaration or a payload signature alone.
    // An early frame can wait only for the nonce proof already in progress;
    // success, failure, reset and disconnect all release this bounded wait.
    if (!session.proofComplete &&
        (session.pendingChallenge != null ||
            session.challengeIssuing != null)) {
      await session.proofReady?.future.timeout(proofTimeout);
    }
    if (!identical(_sessions[_sessionKey(peer, role)], session)) {
      throw const RelayProtocolException('Relay proof session changed.');
    }
  }

  _RelaySession _requireProvenSession(String peer, BleSessionRole role) {
    final session = _requireSession(peer, role);
    if (!session.proofComplete || session.declaredPeer == null) {
      throw const RelayProtocolException(
        'Relay peer has not completed active-session proof.',
      );
    }
    return session;
  }

  Map<String, _ProvenRoute> _provenPeers() {
    final routes = <String, _ProvenRoute>{};
    for (final entry in _sessions.entries) {
      final session = entry.value;
      final declared = session.declaredPeer;
      if (!session.proofComplete || declared == null) continue;
      final separator = entry.key.lastIndexOf('|');
      final peer = entry.key.substring(0, separator);
      final existing = routes[peer];
      if (existing == null ||
          (session.role == BleSessionRole.central &&
              existing.role != BleSessionRole.central)) {
        routes[peer] = _ProvenRoute(role: session.role, peer: declared);
      }
    }
    return routes;
  }

  AuthenticatedRelayRoute? authenticatedRouteForKey(String keyId) {
    final routes = _provenPeers().entries
        .where((entry) => entry.value.peer.keyId == keyId)
        .toList();
    if (routes.length != 1) return null;
    final route = routes.single;
    final session = _sessions[_sessionKey(route.key, route.value.role)];
    if (session == null) return null;
    bool current() =>
        _started &&
        _foreground &&
        session.proofComplete &&
        session.declaredPeer?.keyId == keyId &&
        identical(
          _sessions[_sessionKey(route.key, route.value.role)],
          session,
        ) &&
        (_connected[route.key]?.contains(route.value.role) ?? false);
    return current()
        ? AuthenticatedRelayRoute(
            deviceId: route.key,
            role: route.value.role,
            isCurrent: current,
          )
        : null;
  }

  bool _relaySendAllowed(
    String peer,
    BleSessionRole role,
    int participationGeneration, {
    required bool locallyOriginated,
    required String originMessageId,
  }) {
    final session = _sessions[_sessionKey(peer, role)];
    return (_participating || locallyOriginated) &&
        !_cancelledOriginMessageIds.contains(originMessageId) &&
        participationGeneration == _participationGeneration &&
        session != null &&
        session.proofComplete &&
        (_connected[peer]?.contains(role) ?? false);
  }

  void _replaceSession(String peer, BleSessionRole role, {int? nativeAttempt}) {
    _invalidateSession(peer, role);
    _sessions[_sessionKey(peer, role)] = _RelaySession(
      generation: ++_nextSessionGeneration,
      nativeAttempt: nativeAttempt,
      role: role,
    );
  }

  void _invalidateSession(String peer, BleSessionRole role) {
    _sessions.remove(_sessionKey(peer, role))?.invalidate();
  }

  void _invalidatePeerSessions(String peer) {
    for (final role in BleSessionRole.values) {
      _invalidateSession(peer, role);
    }
  }

  void _invalidateAllProofs() {
    // GATT can survive a background/consent change. Advertise a new local
    // proof generation so the other endpoint also discards its old binding.
    for (final entry in _sessions.entries.toList(growable: false)) {
      final old = entry.value;
      final declared = old.declaredPeer;
      final verified = old.verifiedPeerGeneration;
      old.invalidate();
      _sessions[entry.key] =
          _RelaySession(
              generation: ++_nextSessionGeneration,
              role: old.role,
              nativeAttempt: old.nativeAttempt,
            )
            ..declaredPeer = declared
            ..verifiedPeerGeneration = verified;
    }
  }

  _ActiveInstallationSession? _activeSessionForInstallation(
    String relayKeyId, {
    required _RelaySession excluding,
  }) {
    for (final entry in _sessions.entries) {
      final candidate = entry.value;
      if (identical(candidate, excluding) ||
          candidate.declaredPeer?.keyId != relayKeyId) {
        continue;
      }
      final separator = entry.key.lastIndexOf('|');
      if (separator <= 0) continue;
      final candidatePeer = entry.key.substring(0, separator);
      if (_connected[candidatePeer]?.contains(candidate.role) ?? false) {
        return _ActiveInstallationSession(
          peer: candidatePeer,
          session: candidate,
        );
      }
    }
    return null;
  }

  Future<void> _rejectDuplicateSession(String peer, BleSessionRole role) async {
    final hasOtherRole =
        _connected[peer]?.any((candidate) => candidate != role) ?? false;
    _authTrace(
      'peer_removed',
      peer: peer,
      role: role,
      session: _sessions[_sessionKey(peer, role)],
      reason: 'duplicate_installation_session',
    );
    _invalidateSession(peer, role);
    _connected[peer]?.remove(role);
    if (_connected[peer]?.isEmpty ?? false) _connected.remove(peer);
    // The transport's disconnect event is role-less on some platforms. Do not
    // tear down the preferred opposite-role session when both native roles
    // share the same peer identifier.
    if (role == BleSessionRole.central && !hasOtherRole) {
      await _transport.disconnect(peer).catchError((_) {});
    }
  }

  String _sessionKey(String peer, BleSessionRole role) =>
      '$peer|${role.wireValue}';

  BleSessionRole _oppositeRole(BleSessionRole role) =>
      role == BleSessionRole.central
      ? BleSessionRole.peripheral
      : BleSessionRole.central;

  Future<RelaySigningIdentity> _ensureIdentity() async =>
      _identity ??= await _identityService.loadOrCreate(allowCreate: true);

  Future<void> _sendCapabilities(String peer, BleSessionRole role) async {
    RelaySigningIdentity? identity = _identity;
    if (_participating || _hasPendingWork) identity = await _ensureIdentity();
    final advertisement = RelayCapabilityAdvertisement(
      capabilities: [
        RelayProtocolCapabilities.relayV2,
        if (mediaStore != null) 'chat.media.v1',
      ],
      participating: _participating,
      relayKeyId: identity?.keyId,
      relayPublicKey: identity == null
          ? null
          : base64UrlEncode(identity.publicKey),
      sessionGeneration: identity == null
          ? null
          : _requireSession(peer, role).generation,
      sessionRole: identity == null ? null : role.wireValue,
    );
    final session = _sessions[_sessionKey(peer, role)];
    _authTrace(
      'capability_write_started',
      peer: peer,
      role: role,
      session: session,
    );
    await _sendMessage(
      peer,
      role,
      BleMessage(
        id: 'relay-capabilities-v1',
        type: RelayCapabilityAdvertisement.wireKind,
        payload: advertisement.toJson(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    _authTrace(
      'capability_write_completed',
      peer: peer,
      role: role,
      session: session,
    );
  }

  Future<void> _broadcastCapabilities() async {
    // Sending a capability can synchronously complete proof in tests, or
    // asynchronously trigger a native disconnect/rebind on devices. Iterate a
    // stable snapshot so those legitimate session transitions cannot mutate
    // the collection being traversed.
    final sessions = <(String, BleSessionRole)>[
      for (final entry in _connected.entries)
        for (final role in entry.value) (entry.key, role),
    ];
    await _broadcastCapabilitySessions(sessions);
  }

  Future<void> _broadcastCapabilitySessions(
    Iterable<(String, BleSessionRole)> sessions,
  ) async {
    for (final (peer, role) in sessions) {
      try {
        await _sendCapabilities(peer, role);
      } on Object {
        _log('relayCapabilityWriteFailed');
      }
    }
  }

  Future<void> _retryFailedSessionProofs(DateTime now) async {
    // A failed proof leaves GATT connected. Neither a fresh discovery event
    // nor another connected callback is guaranteed, so the existing scheduler
    // must resume authentication. Bound retries and retain full verification.
    for (final entry in _sessions.entries.toList(growable: false)) {
      final session = entry.value;
      final retryAt = session.proofRetryAt;
      if (retryAt == null ||
          retryAt.isAfter(now) ||
          session.proofComplete ||
          session.pendingChallenge != null ||
          session.declaredPeer == null ||
          session.proofRecoveryAttempts >=
              RelayRepository.maximumRetriesPerPeer) {
        continue;
      }
      final separator = entry.key.lastIndexOf('|');
      if (separator <= 0) continue;
      final peer = entry.key.substring(0, separator);
      if (!identical(_sessions[entry.key], session) ||
          !(_connected[peer]?.contains(session.role) ?? false)) {
        continue;
      }
      session.proofRetryAt = null;
      session.proofRecoveryAttempts++;
      _log(
        'relaySessionProofRetry attempt=${session.proofRecoveryAttempts} '
        'peer=${_safeCorrelation(peer)}',
      );
      try {
        await _issueSessionChallenge(peer, session);
      } on Object {
        _log('relaySessionProofWriteFailed');
      }
    }
  }

  Future<void> _challengeDeclaredPeers() async {
    for (final entry in _sessions.entries) {
      final session = entry.value;
      if (session.declaredPeer == null) continue;
      final separator = entry.key.lastIndexOf('|');
      if (separator <= 0) continue;
      try {
        await _issueSessionChallenge(
          entry.key.substring(0, separator),
          session,
        );
      } on Object {
        _log('relaySessionProofWriteFailed');
      }
    }
  }

  Future<void> _sendMessage(
    String peer,
    BleSessionRole role,
    BleMessage message, {
    bool Function()? sendAllowed,
  }) async {
    final key = _sessionKey(peer, role);
    final session = _sessions[key];
    if (session == null || !(_connected[peer]?.contains(role) ?? false)) {
      throw const RelayPersistenceException('Relay peer disconnected.');
    }
    if (_isControlMessage(message)) {
      await _sendMessageFrames(
        peer,
        role,
        message,
        session,
        sendAllowed: sendAllowed,
      );
      return;
    }
    final previous = _sendTails[key] ?? Future<void>.value();
    late final Future<void> current;
    current = previous.catchError((Object _) {}).then((_) async {
      if (!identical(_sessions[key], session)) {
        throw const RelayPersistenceException('Relay session changed.');
      }
      await _sendMessageFrames(
        peer,
        role,
        message,
        session,
        sendAllowed: sendAllowed,
      );
    });
    _sendTails[key] = current;
    try {
      await current;
    } finally {
      if (identical(_sendTails[key], current)) _sendTails.remove(key);
    }
  }

  Future<void> _sendMessageFrames(
    String peer,
    BleSessionRole role,
    BleMessage message,
    _RelaySession session, {
    bool Function()? sendAllowed,
  }) async {
    final frameBytes = await negotiatedBleFrameBytes(_transport, peer, role);
    _log('relay_frame_capacity role=${role.wireValue} bytes=$frameBytes');
    final completed = await _writes.sendFrames(
      peer,
      BleMessageCodec.encode(message, maxFrameBytes: frameBytes),
      role: role,
      control: _isControlMessage(message),
      canSend: () =>
          (sendAllowed == null || sendAllowed()) &&
          _started &&
          _foreground &&
          identical(_sessions[_sessionKey(peer, role)], session) &&
          (_connected[peer]?.contains(role) ?? false),
    );
    if (!completed) {
      throw const RelayPersistenceException(
        'Relay send cancelled by participation or session change.',
      );
    }
  }

  bool _isControlMessage(BleMessage message) =>
      message.type == RelayCapabilityAdvertisement.wireKind ||
      message.type == RelaySessionChallenge.wireKind ||
      message.type == RelaySessionResponse.wireKind ||
      message.type == RelayReceiptType.hop.wireValue ||
      (message.type == RescueResponseTransfer.wireKind &&
          message.payload['isAck'] == true);

  Future<void> _maybeConnect(String peer) async {
    if (!_started ||
        !_foreground ||
        !_hasPendingWork ||
        _connected.containsKey(peer) ||
        _connecting.contains(peer)) {
      return;
    }
    // Android can briefly report both the stale and current privacy address
    // for the same iOS peripheral. Serialize only the identity-discovery
    // window for that same peer; a relay must still be able to connect to a
    // second peer while the first hop is proving its session.
    if (_hasCentralHandshakeOrWriteInFlight(peer)) return;
    var attempts = _connectionAttempts[peer] ?? 0;
    final now = _now().toUtc();
    final window = _connectionAttemptWindows[peer];
    if (attempts >= 2 &&
        window != null &&
        now.difference(window) >= const Duration(seconds: 30)) {
      attempts = 0;
    }
    if (attempts >= 2 ||
        (_connectionAttempts.length >= maximumConnectionCandidates &&
            !_connectionAttempts.containsKey(peer)) ||
        _connecting.contains(peer)) {
      return;
    }
    if (attempts == 0) _connectionAttemptWindows[peer] = now;
    _connectionAttempts[peer] = attempts + 1;
    _connecting.add(peer);
    _authTrace(
      'connection_request_started',
      peer: peer,
      role: BleSessionRole.central,
      attempt: attempts + 1,
    );
    try {
      await _transport.connect(peer);
    } on Object {
      _connecting.remove(peer);
      _log('relayCandidateConnectFailed');
      _authTrace(
        'session_failed',
        peer: peer,
        role: BleSessionRole.central,
        attempt: attempts + 1,
        reason: 'connection_request_failed',
      );
    }
  }

  bool _hasCentralHandshakeOrWriteInFlight(String targetPeer) {
    for (final entry in _sessions.entries) {
      final session = entry.value;
      if (session.role != BleSessionRole.central) continue;
      final separator = entry.key.lastIndexOf('|');
      if (separator <= 0) continue;
      final peer = entry.key.substring(0, separator);
      if (peer != targetPeer ||
          !(_connected[peer]?.contains(BleSessionRole.central) ?? false)) {
        continue;
      }
      if (!session.proofComplete || _sendTails.containsKey(entry.key)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _startAdvertising() async {
    if (_advertisingLeaseHeld) return;
    _advertisingLeaseHeld = true;
    try {
      await _presence.acquireAdvertising(
        _advertisingLease,
        name: 'Emergency Relay',
      );
    } on Object {
      _advertisingLeaseHeld = false;
      rethrow;
    }
  }

  Future<void> _ensureDiscovery() async {
    if (_discoveryLeaseHeld || !_started || !_foreground) return;
    _discoveryLeaseHeld = true;
    try {
      await _presence.acquireDiscovery(_discoveryLease);
    } on Object {
      _discoveryLeaseHeld = false;
      rethrow;
    }
  }

  Future<void> _stopPresence() async {
    if (_discoveryLeaseHeld) {
      await _presence.releaseDiscovery(_discoveryLease);
      _discoveryLeaseHeld = false;
    }
    await _stopAdvertising();
  }

  Future<void> _stopAdvertising() async {
    if (!_advertisingLeaseHeld) return;
    await _presence.releaseAdvertising(_advertisingLease);
    _advertisingLeaseHeld = false;
  }

  Duration _retryDelay(int retryCount) {
    final multiplier = 1 << retryCount.clamp(0, 4);
    return retryBase * multiplier;
  }

  void _timing(
    String event,
    String originMessageId, {
    String? peer,
    int? hop,
    int? retry,
  }) {
    final timer = _timers.putIfAbsent(
      originMessageId,
      () => Stopwatch()..start(),
    );
    final fields = <String>[
      'timing=$event',
      'origin=${_safeCorrelation(originMessageId)}',
      'elapsedMs=${timer.elapsedMilliseconds}',
      if (peer != null) 'peer=${_safeCorrelation(peer)}',
      if (hop != null) 'hop=$hop',
      if (retry != null) 'retry=$retry',
    ];
    _log(fields.join(' '));
  }

  String _safeCorrelation(String value) {
    final normalized = value.trim();
    if (normalized.length <= 24) return normalized;
    return '${normalized.substring(0, 12)}…${normalized.substring(normalized.length - 8)}';
  }

  void _authTrace(
    String event, {
    required String peer,
    BleSessionRole? role,
    int? attempt,
    _RelaySession? session,
    String? reason,
  }) {
    _log(
      <String>[
        'auth_t=${_diagnosticClock.elapsedMicroseconds}',
        'platform=${Platform.operatingSystem}',
        'event=$event',
        'peer=${_safeCorrelation(peer)}',
        if (role != null) 'role=${role.wireValue}',
        if (attempt != null) 'attempt=$attempt',
        if (session != null) 'generation=${session.generation}',
        if (reason != null) 'reason=$reason',
      ].join(' '),
    );
  }

  String _nativeFailureCategory(String? error) {
    if (error == null || error.trim().isEmpty) return 'normal_disconnect';
    final normalized = error.toLowerCase();
    final status = RegExp(r'status\s+(\d+)').firstMatch(normalized);
    if (status != null) return 'gatt_status_${status.group(1)}';
    if (normalized.contains('timeout')) return 'gatt_timeout';
    if (normalized.contains('notification')) return 'notification_setup';
    if (normalized.contains('service')) return 'service_discovery';
    if (normalized.contains('characteristic')) {
      return 'characteristic_discovery';
    }
    if (normalized.contains('disconnect')) return 'native_disconnect';
    return 'native_error';
  }

  String _authenticationFailureCategory(Object error) {
    final normalized = error.toString().toLowerCase();
    if (normalized.contains('timeout')) return 'proof_timeout';
    if (normalized.contains('session changed')) return 'session_replaced';
    if (normalized.contains('inactive') ||
        normalized.contains('disconnected')) {
      return 'transport_inactive';
    }
    if (normalized.contains('capability key mismatch')) {
      return 'capability_key_mismatch';
    }
    if (normalized.contains('capability role')) {
      return 'capability_role_mismatch';
    }
    if (normalized.contains('own installation key')) return 'self_identity';
    if (normalized.contains('challenge')) return 'challenge_rejected';
    if (normalized.contains('response')) return 'response_rejected';
    if (normalized.contains('cancelled')) return 'write_cancelled';
    return 'authentication_error';
  }

  void _log(String message) {
    onLog?.call(message);
    final normalized = message.trim();
    if (normalized.isEmpty) return;
    _runtimeEvents.add(normalized);
    if (_runtimeEvents.length > 40) {
      _runtimeEvents.removeRange(0, _runtimeEvents.length - 40);
    }
    if (normalized.startsWith('relay_scheduler_tick')) {
      _lastSchedulerExecution = _now();
    } else if (normalized.startsWith('relay_job_due count=')) {
      _runtimeDueJobs = int.tryParse(normalized.split('=').last) ?? 0;
    } else if (normalized.contains('relay_forward_skipped reason=')) {
      _runtimeSkipReason = normalized.split('reason=').last.split(' ').first;
    } else if (normalized.startsWith('relay_forward_eligible')) {
      _runtimeSelectedPeer = normalized.contains('peer=')
          ? normalized.split('peer=').last.split(' ').first
          : null;
    } else if (normalized.contains('timing=forwarding_started') ||
        normalized.contains('relay_forward_started') ||
        normalized.contains('response_forward_started')) {
      _runtimeForwardAttempt = normalized;
    } else if (normalized.contains('relayStoredOnNextHop') ||
        normalized.contains('relay_hop_receipt')) {
      _runtimeDurableReceipt = normalized;
    }
    final peers = <RelayPeerDiagnostic>[];
    for (final entry in _connected.entries) {
      for (final role in entry.value) {
        final session = _sessions['${entry.key}|${role.wireValue}'];
        peers.add(
          RelayPeerDiagnostic(
            peer: _safeCorrelation(entry.key),
            connected: true,
            authenticated: session?.proofComplete ?? false,
            participating: session?.declaredPeer?.participating ?? false,
            role: role.wireValue,
          ),
        );
      }
    }
    runtimeDiagnostics.update(
      RelayRuntimeDiagnosticsSnapshot(
        peers: peers,
        events: List<String>.unmodifiable(_runtimeEvents),
        lastSchedulerExecution: _lastSchedulerExecution,
        dueJobs: _runtimeDueJobs,
        lastSelectedPeer: _runtimeSelectedPeer,
        lastSkipReason: _runtimeSkipReason,
        lastForwardAttempt: _runtimeForwardAttempt,
        lastDurableReceipt: _runtimeDurableReceipt,
      ),
    );
  }
}
