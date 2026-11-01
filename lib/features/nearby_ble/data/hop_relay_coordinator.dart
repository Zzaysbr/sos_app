import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../../../core/database/app_database.dart';
import '../../sos/data/sos_repository.dart';
import '../domain/ble_models.dart';
import '../domain/relay_envelope.dart';
import 'ble_protocol.dart';
import 'ble_transport.dart';
import 'relay_key_store.dart';
import 'relay_repository.dart';

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
  final Duration ackTimeout;
  final Duration retryBase;
  final Duration proofTimeout;

  final _connected = <String, Set<BleSessionRole>>{};
  final _sessions = <String, _RelaySession>{};
  final _connecting = <String>{};
  final _connectionAttempts = <String, int>{};
  final _cancelledOriginMessageIds = <String>{};
  final _sendTails = <String, Future<void>>{};
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
      await _stopPresence();
      return;
    }
    if (_participating) await _startAdvertising();
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
        if (peer != null && peer.isNotEmpty) await _maybeConnect(peer);
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
    if (message.type == RelayReceiptType.hop.wireValue ||
        message.type == RelayReceiptType.finalRecipient.wireValue) {
      await _handleIncomingReceipt(peer, role, message);
      return true;
    }
    return false;
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

  Future<void> _processDue() async {
    final now = _now().toUtc();
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
    if (messages.isEmpty) {
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
      for (final entry in _provenPeers().entries) {
        final peer = entry.key;
        final capability = entry.value.peer;
        if (!capability.participating ||
            offer.pathKeyIds.contains(capability.keyId) ||
            message.incomingPeerId == peer ||
            !(_connected[peer]?.isNotEmpty ?? false)) {
          continue;
        }
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
    if (session.inboundBinding == null) {
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
      sessionBinding: session.inboundBinding,
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
        session.outboundBinding == null ||
        receipt.sessionBinding != session.outboundBinding) {
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
      final deferred = session.deferredPeerChallenge;
      if (deferred != null &&
          relayCanonicalJson(deferred.toJson()) !=
              relayCanonicalJson(challenge.toJson())) {
        throw const RelayProtocolException(
          'Conflicting relay challenges arrived before capability exchange.',
        );
      }
      session.deferredPeerChallenge = challenge;
      _log('relaySessionChallengeDeferred');
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
    // for the same iOS peripheral. Opening the second GATT link while the
    // first link is still proving its installation identity (or writing a
    // complete message) creates two frame streams that iOS exposes under one
    // central identifier. Those streams can interleave and make neither
    // signed message reconstructable. Serialize that identity-discovery
    // window; once the active central route is proven and idle, other peers
    // remain eligible for discovery and fan-out.
    if (_hasCentralHandshakeOrWriteInFlight()) return;
    final attempts = _connectionAttempts[peer] ?? 0;
    if (attempts >= 2 ||
        (_connectionAttempts.length >= maximumConnectionCandidates &&
            !_connectionAttempts.containsKey(peer)) ||
        _connecting.isNotEmpty) {
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

  bool _hasCentralHandshakeOrWriteInFlight() {
    for (final entry in _sessions.entries) {
      final session = entry.value;
      if (session.role != BleSessionRole.central) continue;
      final separator = entry.key.lastIndexOf('|');
      if (separator <= 0) continue;
      final peer = entry.key.substring(0, separator);
      if (!(_connected[peer]?.contains(BleSessionRole.central) ?? false)) {
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

  void _log(String message) => onLog?.call(message);
}
