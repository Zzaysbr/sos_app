import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../../core/database/app_database.dart';
import '../../sos/data/sos_repository.dart';
import '../domain/ble_models.dart';
import '../domain/relay_envelope.dart';
import '../domain/rescue_response_envelope.dart';
import '../domain/chat_relay_envelope.dart';
import 'ble_protocol.dart';
import 'ble_transport.dart';
import 'relay_key_store.dart';
import 'relay_repository.dart';
import 'rescue_inbox_repository.dart';
import 'rescue_response_repository.dart';
import 'chat_relay_repository.dart';

typedef RelayNow = DateTime Function();
typedef RelayNonceSource = List<int> Function();

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

class _RelayPeer {
  const _RelayPeer({
    required this.keyId,
    required this.publicKey,
    required this.participating,
    required this.sessionGeneration,
    required this.sessionRole,
  });

  final String keyId;
  final String publicKey;
  final bool participating;
  final int sessionGeneration;
  final String sessionRole;
}

class _RelaySession {
  _RelaySession({required this.generation, required this.role});

  final int generation;
  final BleSessionRole role;
  _RelayPeer? declaredPeer;
  RelaySessionChallenge? pendingChallenge;
  RelaySessionChallenge? deferredPeerChallenge;
  bool proofComplete = false;
  String? outboundBinding;
  String? inboundBinding;
  final Set<String> seenChallengeNonces = <String>{};
  final Set<String> respondingChallengeNonces = <String>{};
  Timer? proofTimeout;

  void resetProof() {
    proofTimeout?.cancel();
    proofTimeout = null;
    pendingChallenge = null;
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

/// Foreground-only Model C coordinator. It shares the existing BLE transport
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
    this.onLog,
    this.rescueModeEnabled,
    this.rescueInbox,
    String? responseOwnerId,
    RescueResponseRepository? rescueResponseRepository,
    this.chatRelayRepository,
    this.onChatRelayReceived,
    this.onChatRelayForwarded,
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
       _nonceSource = nonceSource ?? _secureNonce;

  final AppDatabase _database;
  final BleTransportClient _transport;
  final BlePresenceManager _presence;
  final RelayRepository _repository;
  final RelayCryptography _cryptography;
  final BleMessageWriteQueue _writes;
  final RelayIdentityService _identityService;
  final RelayNow _now;
  final RelayNonceSource _nonceSource;
  final void Function(String message)? onLog;
  final bool Function()? rescueModeEnabled;
  final RescueInboxRepository? rescueInbox;
  final RescueResponseRepository _rescueResponseRepository;
  final ChatRelayRepository? chatRelayRepository;
  final Future<void> Function(ChatRelayEnvelope envelope)? onChatRelayReceived;
  final Future<void> Function(String messageId)? onChatRelayForwarded;
  final Duration ackTimeout;
  final Duration retryBase;
  final Duration proofTimeout;

  final _connected = <String, Set<BleSessionRole>>{};
  final _sessions = <String, _RelaySession>{};
  final _connecting = <String>{};
  final _connectionAttempts = <String, int>{};
  final _cancelledOriginMessageIds = <String>{};
  final _sendTails = <String, Future<void>>{};
  final _timers = <String, Stopwatch>{};
  Future<void>? _processing;
  RelaySigningIdentity? _identity;
  bool _started = false;
  bool _foreground = true;
  bool _participating = false;
  final Object _advertisingLease = Object();
  final Object _discoveryLease = Object();
  bool _advertisingLeaseHeld = false;
  bool _discoveryLeaseHeld = false;
  bool _hasPendingWork = false;
  int _nextSessionGeneration = 0;
  int _participationGeneration = 0;

  bool get participationEnabled => _participating;

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
    await _stopPresence();
    _connected.clear();
    for (final session in _sessions.values) {
      session.invalidate();
    }
    _sessions.clear();
    _connecting.clear();
    _connectionAttempts.clear();
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
    if (!_hasPendingWork) _connectionAttempts.clear();
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
    final peer = event.device?.id.trim();
    switch (event.type) {
      case 'deviceFound':
        if (peer != null && peer.isNotEmpty) {
          _log('relay_peer_discovered peer=${_safeCorrelation(peer)}');
          await _maybeConnect(peer);
        }
        return;
      case 'connected':
        if (peer == null || peer.isEmpty) return;
        final role = event.role ?? BleSessionRole.central;
        _connected.putIfAbsent(peer, () => <BleSessionRole>{}).add(role);
        _replaceSession(peer, role);
        _connecting.remove(peer);
        // A non-participating origin still needs to declare its installation
        // key and session role so an opted-in next hop can authenticate the
        // per-incident-authorized offer. This does not authorize this device
        // to accept or forward anyone else's SOS.
        if (_participating || _hasPendingWork) {
          await _sendCapabilities(peer, role);
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
      await _handleCapabilities(peer, role, message);
      return true;
    }
    if (message.type == RelaySessionChallenge.wireKind) {
      await _handleSessionChallenge(peer, role, message);
      return true;
    }
    if (message.type == RelaySessionResponse.wireKind) {
      await _handleSessionResponse(peer, role, message);
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
    if (message.type == ChatRelayTransfer.wireKind) {
      await _handleIncomingChatRelay(peer, role, message);
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
    final session = _requireProvenSession(peer, role);
    final repository = chatRelayRepository;
    if (repository == null) return;
    final transfer = ChatRelayTransfer.fromJson(message.payload);
    if (message.id != transfer.attemptId) {
      throw const RelayProtocolException(
        'Chat relay transfer binding is invalid.',
      );
    }
    final envelope = repository.decode(transfer.wireEnvelope);
    envelope.body.validate(now: _now());
    if (session.declaredPeer?.keyId != envelope.body.senderKeyId ||
        !await _cryptography.publicKeyMatchesId(
          envelope.body.recipientPublicKey,
          envelope.body.recipientKeyId,
        ) ||
        !await _cryptography.verifyChatRelay(envelope, now: _now())) {
      throw const RelayProtocolException('Chat relay authentication failed.');
    }
    await repository.persistIncoming(envelope, now: _now());
    final identity = await _ensureIdentity();
    if (identity.keyId == envelope.body.recipientKeyId) {
      await onChatRelayReceived?.call(envelope);
      _log(
        'chat_relay_received incident=${envelope.body.incidentId} message=${envelope.body.messageId}',
      );
      return;
    }
    await repository.enqueue(
      envelope,
      now: _now(),
      hopCount: transfer.hopCount + 1,
    );
    _hasPendingWork = true;
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
    final session = _requireProvenSession(peer, role);
    final transfer = RescueResponseTransfer.fromJson(message.payload);
    transfer.validate();
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
        await _sendResponseTransfer(
          peer,
          role,
          ack.toCanonicalWire(),
          true,
          session,
        );
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
          await _rescueResponseRepository.applyFinalAck(
            ack: ack,
            response: responseEnvelope,
            origin: origin,
            now: _now(),
          );
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

  Future<void> _sendResponseTransfer(
    String peer,
    BleSessionRole role,
    String wireEnvelope,
    bool isAck,
    _RelaySession session,
  ) async {
    final transfer = RescueResponseTransfer(
      attemptId: 'rescue-transfer:${DateTime.now().microsecondsSinceEpoch}',
      correlationId:
          'rescue-correlation:${DateTime.now().microsecondsSinceEpoch}',
      sessionBinding: session.outboundBinding ?? session.inboundBinding ?? '',
      wireEnvelope: wireEnvelope,
      hopCount: 0,
      maxHops: RelayProtocolLimits.maximumHops,
      isAck: isAck,
    );
    transfer.validate();
    await _sendMessage(
      peer,
      role,
      BleMessage(
        id: transfer.attemptId,
        type: RescueResponseTransfer.wireKind,
        payload: transfer.toJson(),
        createdAt: _now().toUtc(),
      ),
    );
  }

  Future<void> processDue() async {
    if (!_started || !_foreground) return;
    final active = _processing;
    if (active != null) return active;
    final operation = _processDue();
    _processing = operation;
    try {
      await operation;
    } finally {
      if (identical(_processing, operation)) _processing = null;
    }
  }

  Future<void> enqueueChatRelay(ChatRelayEnvelope envelope) async {
    final repository = chatRelayRepository;
    if (repository == null) {
      throw const RelayPersistenceException(
        'Chat relay storage is unavailable.',
      );
    }
    await repository.enqueue(envelope, now: _now());
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
  }) async {
    final identity = await _ensureIdentity();
    final body = ChatRelayBody(
      messageId: messageId,
      incidentId: incidentId,
      senderKeyId: identity.keyId,
      senderPublicKey: base64UrlEncode(identity.publicKey),
      recipientKeyId: recipientKeyId,
      recipientPublicKey: recipientPublicKey,
      originIncidentBinding: originIncidentBinding ?? incidentId,
      text: text,
      createdAt: createdAt,
      expiresAt: createdAt.toUtc().add(const Duration(minutes: 30)),
    );
    final envelope = ChatRelayEnvelope(
      body: body,
      signature: await _cryptography.signChatRelay(body, identity.keyPair),
    );
    await enqueueChatRelay(envelope);
    return envelope;
  }

  Future<void> _processDue() async {
    final now = _now().toUtc();
    _log(
      'relay_scheduler_tick foreground=$_foreground participating=$_participating',
    );
    final chatRows = chatRelayRepository == null
        ? const <ChatRelayOutboxData>[]
        : await chatRelayRepository!.due(now: now);
    if (chatRows.isNotEmpty) {
      _hasPendingWork = true;
      await _ensureIdentity();
      await _ensureDiscovery();
      await _broadcastCapabilities();
    }
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
    final hadPendingWork = _hasPendingWork;
    _hasPendingWork = messages.isNotEmpty;
    _log('relay_job_due count=${messages.length}');
    if (messages.isEmpty) {
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
        if (identity.keyId == envelope.body.recipientKeyId) {
          await onChatRelayReceived?.call(envelope);
          await repository.markForwarded(row.messageId, now: now);
          continue;
        }
        MapEntry<String, _ProvenRoute>? candidate;
        for (final entry in routes.entries) {
          if (entry.value.peer.keyId == envelope.body.recipientKeyId &&
              entry.value.peer.participating) {
            candidate = entry;
            break;
          }
        }
        // A relay may not know the final recipient's currently reachable
        // session. Forward opportunistically to one authenticated, opted-in
        // relay while keeping the immutable final recipient key in the signed
        // envelope. The next relay must repeat the same validation.
        candidate ??= routes.entries
            .where((entry) => entry.value.peer.participating)
            .cast<MapEntry<String, _ProvenRoute>?>()
            .firstWhere((entry) => entry != null, orElse: () => null);
        if (candidate == null) continue;
        final session =
            _sessions[_sessionKey(candidate.key, candidate.value.role)];
        if (session == null || !session.proofComplete) continue;
        final transfer = ChatRelayTransfer(
          attemptId: 'chat:${row.messageId}:${candidate.value.peer.keyId}',
          wireEnvelope: row.payload,
          hopCount: row.hopCount,
        );
        await _sendMessage(
          candidate.key,
          candidate.value.role,
          BleMessage(
            id: transfer.attemptId,
            type: ChatRelayTransfer.wireKind,
            payload: transfer.toJson(),
            createdAt: now,
          ),
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
        await _rescueResponseRepository.queueAttempt(
          messageId: row.messageId,
          nextHopKeyId: candidate.value.peer.keyId,
          nextHopDeviceId: candidate.key,
          sessionBinding: session.outboundBinding ?? '',
          now: now,
        );
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
        );
        await _rescueResponseRepository.markState(
          row.messageId,
          RescueResponseDeliveryState.forwarded,
          now: now,
        );
        _log(
          'response_transfer_completed incident=${row.incidentId} '
          'response=${row.messageId}',
        );
      } on Object catch (error) {
        await _rescueResponseRepository.markState(
          row.messageId,
          RescueResponseDeliveryState.failed,
          now: now,
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
    final session = _requireSession(peer, role);
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
    final declared = _RelayPeer(
      keyId: advertisement.relayKeyId!,
      publicKey: advertisement.relayPublicKey!,
      participating: advertisement.participating,
      sessionGeneration: advertisement.sessionGeneration!,
      sessionRole: advertisement.sessionRole!,
    );
    if (declared.sessionRole != _oppositeRole(role).wireValue) {
      session.invalidate();
      throw const RelayProtocolException(
        'Relay capability role does not match the active session.',
      );
    }
    final identity = await _ensureIdentity();
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
    final existing = session.declaredPeer;
    if (existing != null &&
        (existing.keyId != declared.keyId ||
            existing.publicKey != declared.publicKey ||
            existing.sessionGeneration != declared.sessionGeneration ||
            existing.sessionRole != declared.sessionRole)) {
      session.invalidate();
      throw const RelayProtocolException(
        'Relay capability key changed within an active session.',
      );
    }
    if (existing != null &&
        existing.participating == declared.participating &&
        (session.proofComplete || session.pendingChallenge != null)) {
      return;
    }
    final deferredChallenge = session.deferredPeerChallenge;
    session.resetProof();
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
    if (declared == null || session.pendingChallenge != null) return;
    final identity = await _ensureIdentity();
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
    session.pendingChallenge = challenge;
    session.proofTimeout?.cancel();
    session.proofTimeout = null;
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
    } on Object {
      if (identical(session.pendingChallenge, challenge)) {
        session.pendingChallenge = null;
        session.proofComplete = false;
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
      session.proofTimeout = Timer(proofTimeout, () {
        if (identical(session.pendingChallenge, challenge)) {
          session.pendingChallenge = null;
          session.proofComplete = false;
          _log('relaySessionProofTimedOut');
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
    if (declared == null) {
      // A capability advertisement is unsigned and can be lost before a long
      // signed challenge completes on a physical GATT link. The challenge
      // carries the same installation key, participation, role and generation
      // facts under an Ed25519 signature. Recover the missing declaration only
      // after binding every local-session field and verifying that signature;
      // malformed, replayed or wrong-session challenges still fail closed.
      final identity = await _ensureIdentity();
      if (challenge.challengedKeyId != identity.keyId ||
          challenge.challengerRole != _oppositeRole(role).wireValue ||
          challenge.challengedRole != role.wireValue ||
          challenge.challengedGeneration != session.generation ||
          !await _cryptography.verifySessionChallenge(challenge)) {
        throw const RelayProtocolException(
          'Relay challenge cannot recover the missing capability.',
        );
      }
      session.deferredPeerChallenge = challenge;
      _log('relaySessionCapabilityRecoveredFromChallenge');
      await _handleCapabilities(
        peer,
        role,
        BleMessage(
          id: 'relay-capabilities-v1',
          type: RelayCapabilityAdvertisement.wireKind,
          payload: RelayCapabilityAdvertisement(
            capabilities: const [RelayProtocolCapabilities.relayV2],
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
      final inboundBinding = await _cryptography.relaySessionBinding(
        challenge,
        response,
      );
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
      // Commit replay protection and the inbound binding only after the whole
      // response has been handed to BLE. If foreground loss or a disconnect
      // interrupts the write, the same signed challenge remains retryable on
      // this still-active session instead of becoming permanently poisoned.
      session.deferredPeerChallenge = null;
      session.seenChallengeNonces.add(challenge.nonce);
      session.inboundBinding = inboundBinding;
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
    session.proofTimeout?.cancel();
    session.proofTimeout = null;
    session.pendingChallenge = null;
    session.proofComplete = true;
    session.outboundBinding = await _cryptography.relaySessionBinding(
      response.challenge,
      response,
    );
    _log('relaySessionProofEstablished');
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

  void _replaceSession(String peer, BleSessionRole role) {
    _invalidateSession(peer, role);
    _sessions[_sessionKey(peer, role)] = _RelaySession(
      generation: ++_nextSessionGeneration,
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
    for (final session in _sessions.values) {
      session.resetProof();
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
      capabilities: const [RelayProtocolCapabilities.relayV2],
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
    final completed = await _writes.sendFrames(
      peer,
      BleMessageCodec.encode(
        message,
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      ),
      role: role,
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
    final attempts = _connectionAttempts[peer] ?? 0;
    if (attempts >= 2 ||
        (_connectionAttempts.length >= maximumConnectionCandidates &&
            !_connectionAttempts.containsKey(peer)) ||
        _connecting.contains(peer)) {
      return;
    }
    _connectionAttempts[peer] = attempts + 1;
    _connecting.add(peer);
    try {
      await _transport.connect(peer);
    } on Object {
      _connecting.remove(peer);
      _log('relayCandidateConnectFailed');
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
        name: 'Off Grid SOS Relay',
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

  void _log(String message) => onLog?.call(message);
}
