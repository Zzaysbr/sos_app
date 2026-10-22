import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../../sos/data/chat_repository.dart';
import '../domain/ble_delivery_state.dart';
import '../domain/ble_models.dart';
import '../domain/sos_ble_envelope.dart';
import '../domain/location_ble_envelope.dart';
import 'ble_delivery_repository.dart';
import 'ble_protocol.dart';
import 'ble_transport.dart';

typedef SosBleNow = DateTime Function();
typedef SosBleRandom = double Function();

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
    String? localDeviceId,
    BleTransportClient? transport,
    BleDeliveryRepository? deliveryRepository,
    this.chatRepository,
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
       assert(maxRetryAttempts > 0);

  final String ownerId;
  final bool requirePeerBinding;
  final bool Function()? isSessionCurrent;
  bool get _sessionActive => isSessionCurrent?.call() ?? true;
  final AppDatabase _database;
  final String _localDeviceId;
  final BleTransportClient _transport;
  final bool _ownsTransport;
  final BleDeliveryRepository _deliveryRepository;
  final ChatRepository? chatRepository;
  final void Function(String message)? onLog;
  final SosBleNow _now;
  final SosBleRandom _random;
  final Duration retryBase;
  final Duration retryMax;

  /// Failed rows remain in the outbox, but are expired after this many
  /// attempts so an unreachable destination cannot monopolize the drain.
  final int maxRetryAttempts;
  final Duration staleAfter;
  final Duration pollInterval;

  final _bindingRetries = <String, Timer>{};
  final _peerBindings = <String, String>{};
  final _peerChallenges = <String, String>{};
  final _bindingWaiters = <String, Completer<void>>{};

  final _assemblers = <String, BleMessageAssembler>{};
  final _connected = <String, Set<BleSessionRole>>{};
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

  bool get isStarted => _started;

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

  /// The shared transport owned by this coordinator.
  ///
  /// Debug/test screens may subscribe to this client, but they must not
  /// dispose it while the coordinator is active.
  BleTransportClient get transport => _transport;

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
      _log('BLE permissions granted');
      await _transport.initialize();
      if (_disposed || !_sessionActive) return;
      _log('BLE transport initialized');
      final now = _now().toUtc();
      await _deliveryRepository.recoverStaleOutbox(
        ownerId: isSessionCurrent == null ? null : ownerId,
        olderThan: now.subtract(staleAfter),
        nextRetryAt: now,
        now: now,
      );
      _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(processDue()));
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
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _pollTimer = null;
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    _connected.clear();
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
    if (state == AppLifecycleState.resumed && _started) {
      unawaited(processDue());
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

  Future<void> processDue() async {
    if (!_started || _disposed || !_sessionActive) return;
    _drainRequested = true;
    if (_drainFuture != null) return _drainFuture!;
    final future = _drain();
    _drainFuture = future;
    await future;
  }

  Future<void> _drain() async {
    try {
      while (_drainRequested && _started && !_disposed) {
        _drainRequested = false;
        final now = _now().toUtc();
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
      }
    } finally {
      _drainFuture = null;
      if (_drainRequested && _started && !_disposed) unawaited(processDue());
    }
  }

  Future<void> _trySend(BleOutboxData row) async {
    if (!_sessionActive || _disposed) return;
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
    var identityRoutedPayload = false;
    try {
      final stored = jsonDecode(activeRow.payload);
      identityRoutedPayload =
          stored is Map &&
          (stored['kind'] == SosBleMessageKind.chatMessage.wireValue ||
              stored['kind'] == 'location.update');
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
              stored['kind'] == 'location.update') &&
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
      final envelope = locationEnvelope == null
          ? _decodeEnvelope(sending.payload)
          : null;
      final frames = BleMessageCodec.encode(
        (locationEnvelope?.toBleMessage() ?? envelope!.toBleMessage()),
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      );
      final role = _sendRoleFor(deviceId);
      _log(
        'send sosId=${sending.sosId} messageId=${sending.messageId} '
        'peer=$deviceId role=${role.wireValue} frames=${frames.length}',
      );
      for (final frame in frames) {
        if (!_sessionActive || _disposed) return;
        await _transport.send(deviceId, frame, role: role);
      }
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
    } catch (error) {
      await _markFailed(activeRow, 'send failed: $error');
    } finally {
      _sendingMessages.remove(activeRow.messageId);
    }
  }

  Future<void> _onEvent(BleEvent event) async {
    if (!_started || _disposed || !_sessionActive) return;
    final deviceId = event.device?.id;
    _log(
      'event=${event.type} peer=${deviceId ?? 'unknown'} '
      'role=${event.role?.wireValue ?? 'unknown'} '
      'state=${event.state ?? 'n/a'}${event.error == null ? '' : ' error=${event.error}'}',
    );
    switch (event.type) {
      case 'connected':
        if (deviceId != null) {
          final role = event.role ?? BleSessionRole.central;
          _connected.putIfAbsent(deviceId, () => <BleSessionRole>{}).add(role);
          _connecting.remove(deviceId);
          _pendingConnectionMessages.remove(deviceId);
          _log('BLE connected: $deviceId');
          if (requirePeerBinding) {
            unawaited(_beginPeerBinding(deviceId, role));
          }
          unawaited(processDue());
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
        _bindingRetries[peer] = Timer.periodic(const Duration(seconds: 2), (
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
    for (final frame in BleMessageCodec.encode(
      message,
      maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
    )) {
      if (!_sessionActive ||
          _disposed ||
          !(_connected[peer]?.contains(role) ?? false)) {
        return;
      }
      await _transport.send(peer, frame, role: role);
    }
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
      if (message == null) return;
      _log(
        'assemblyComplete peer=$deviceId role=${role.wireValue} '
        'messageId=${message.id}',
      );
      if (message.type == 'peer.binding.v1') {
        await _handlePeerBinding(deviceId, role, message);
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
      for (final frame in BleMessageCodec.encode(
        acknowledgement.toBleMessage(),
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      )) {
        if (!_sessionActive || _disposed) return;
        await _transport.send(deviceId, frame, role: role);
      }
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
      for (final frame in BleMessageCodec.encode(
        acknowledgement.toBleMessage(),
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      )) {
        if (!_sessionActive || _disposed) return;
        await _transport.send(deviceId, frame, role: role);
      }
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
      for (final frame in BleMessageCodec.encode(
        acknowledgement.toBleMessage(),
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      )) {
        if (!_sessionActive || _disposed) return;
        await _transport.send(deviceId, frame, role: role);
      }
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
      if (row == null || row.state != BleOutboxState.queued.wireValue) {
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
