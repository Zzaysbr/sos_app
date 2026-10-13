import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/database/app_database.dart';
import '../domain/ble_delivery_state.dart';
import '../domain/ble_models.dart';
import '../domain/sos_ble_envelope.dart';
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
    BleTransportClient? transport,
    BleDeliveryRepository? deliveryRepository,
    this.onLog,
    SosBleNow? now,
    SosBleRandom? random,
    this.retryBase = const Duration(seconds: 2),
    this.retryMax = const Duration(minutes: 5),
    this.maxRetryAttempts = 8,
    this.staleAfter = const Duration(seconds: 30),
    this.pollInterval = const Duration(seconds: 5),
  }) : _transport = transport ?? BleTransport(),
       _ownsTransport = transport == null,
       _deliveryRepository =
           deliveryRepository ?? BleDeliveryRepository(database),
       _now = now ?? DateTime.now,
       _random = random ?? math.Random().nextDouble,
       assert(maxRetryAttempts > 0);

  final String ownerId;
  final BleTransportClient _transport;
  final bool _ownsTransport;
  final BleDeliveryRepository _deliveryRepository;
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

  final _assemblers = <String, BleMessageAssembler>{};
  final _connected = <String, Set<BleSessionRole>>{};
  final _connecting = <String>{};
  final _processingMessages = <String>{};
  final _sendingMessages = <String>{};
  StreamSubscription<BleEvent>? _eventsSubscription;
  Timer? _pollTimer;
  Future<void>? _drainFuture;
  Future<void>? _disposeFuture;
  bool _started = false;
  bool _disposed = false;
  bool _drainRequested = false;

  bool get isStarted => _started;

  /// The shared transport owned by this coordinator.
  ///
  /// Debug/test screens may subscribe to this client, but they must not
  /// dispose it while the coordinator is active.
  BleTransportClient get transport => _transport;

  Future<void> start() async {
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
      await _transport.initialize();
      final now = _now().toUtc();
      await _deliveryRepository.recoverStaleOutbox(
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
    _assemblers.clear();
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

  Future<void> processDue() async {
    if (!_started || _disposed) return;
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
          olderThan: now.subtract(staleAfter),
          nextRetryAt: now,
          now: now,
        );
        final rows = await _deliveryRepository.dueOutbox(now: now);
        for (final row in rows) {
          if (!_started || _disposed) break;
          await _trySend(row);
        }
      }
    } finally {
      _drainFuture = null;
      if (_drainRequested && _started && !_disposed) unawaited(processDue());
    }
  }

  Future<void> _trySend(BleOutboxData row) async {
    if (_sendingMessages.contains(row.messageId)) {
      return;
    }
    final destination = row.destinationId?.isNotEmpty == true
        ? row.destinationId
        : (_connected.isEmpty ? null : _connected.keys.first);
    if (destination == null) return;
    final assigned = row.destinationId == null
        ? await _deliveryRepository.assignDestinationIfMissing(
            row.messageId,
            destination,
            now: _now(),
          )
        : row;
    final deviceId = assigned.destinationId!;
    final roles = _connected[deviceId];
    if (roles == null || roles.isEmpty) {
      if (_connecting.add(deviceId)) {
        try {
          _log(
            'connect sosId=${row.sosId} messageId=${row.messageId} '
            'peer=$deviceId',
          );
          await _transport.connect(deviceId);
        } catch (error) {
          _connecting.remove(deviceId);
          final reason = 'connect failed: $error';
          try {
            // Count connection attempts in the durable outbox as well as
            // write attempts, otherwise an unreachable fixed peer can retry
            // forever with retryCount stuck at zero.
            final attempted = await _deliveryRepository.transitionOutboxState(
              row.messageId,
              BleOutboxState.sending,
              now: _now(),
            );
            await _markFailed(attempted, reason);
          } catch (transitionError) {
            _log('Unable to record BLE connect attempt: $transitionError');
            await _markFailed(row, reason);
          }
        }
      }
      return;
    }

    _sendingMessages.add(row.messageId);
    try {
      final sending = await _deliveryRepository.transitionOutboxState(
        row.messageId,
        BleOutboxState.sending,
        now: _now(),
      );
      final envelope = _decodeEnvelope(sending.payload);
      final frames = BleMessageCodec.encode(
        envelope.toBleMessage(),
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      );
      final role = _sendRoleFor(deviceId);
      _log(
        'send sosId=${envelope.sosId} messageId=${envelope.messageId} '
        'peer=$deviceId role=${role.wireValue} frames=${frames.length}',
      );
      for (final frame in frames) {
        await _transport.send(deviceId, frame, role: role);
      }
      await _deliveryRepository.transitionOutboxState(
        row.messageId,
        BleOutboxState.writeAccepted,
        now: _now(),
      );
      await _deliveryRepository.transitionOutboxState(
        row.messageId,
        BleOutboxState.awaitingAcknowledgement,
        now: _now(),
      );
      _log(
        'writeAccepted sosId=${envelope.sosId} messageId=${row.messageId} '
        'state=${BleOutboxState.awaitingAcknowledgement.wireValue}',
      );
    } on SosBleEnvelopeException catch (error) {
      await _expire(row.messageId, 'invalid stored envelope: $error');
    } catch (error) {
      await _markFailed(row, 'send failed: $error');
    } finally {
      _sendingMessages.remove(row.messageId);
    }
  }

  Future<void> _onEvent(BleEvent event) async {
    if (!_started || _disposed) return;
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
          _log('BLE connected: $deviceId');
          unawaited(processDue());
        }
        return;
      case 'disconnected':
        if (deviceId != null) {
          final role = event.role;
          if (role == null) {
            _connected.remove(deviceId);
          } else {
            final roles = _connected[deviceId];
            roles?.remove(role);
            if (roles == null || roles.isEmpty) _connected.remove(deviceId);
          }
          _connecting.remove(deviceId);
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
        _log('BLE native error: ${event.error ?? 'unknown'}');
        return;
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
      BleMessageAssembler.new,
    );
    try {
      final message = assembler.accept(frame);
      if (message == null) return;
      _log(
        'assemblyComplete peer=$deviceId role=${role.wireValue} '
        'messageId=${message.id}',
      );
      final envelope = SosBleEnvelope.fromBleMessage(message);
      _log(
        'validated kind=${envelope.kind.wireValue} sosId=${envelope.sosId} '
        'messageId=${envelope.messageId} peer=$deviceId role=${role.wireValue}',
      );
      if (envelope.kind == SosBleMessageKind.acknowledgement) {
        await _handleAcknowledgement(deviceId, envelope);
      } else {
        await _handleDelivery(deviceId, role, envelope);
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
      await _deliveryRepository.recordAcknowledgement(
        envelope,
        sourceDeviceId: deviceId,
        now: _now(),
      );
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

  Future<void> _handleDelivery(
    String deviceId,
    BleSessionRole role,
    SosBleEnvelope envelope,
  ) async {
    if (!_processingMessages.add(envelope.messageId)) return;
    try {
      try {
        final persisted = await _deliveryRepository.persistIncomingDelivery(
          envelope,
          ownerId: ownerId,
          now: _now(),
        );
        _log(
          'persisted sosId=${envelope.sosId} messageId=${envelope.messageId} '
          'duplicate=${persisted.duplicate} peer=$deviceId',
        );
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
      _processingMessages.remove(envelope.messageId);
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
      error: error,
      createdAt: _now(),
    );
    try {
      for (final frame in BleMessageCodec.encode(
        acknowledgement.toBleMessage(),
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      )) {
        await _transport.send(deviceId, frame, role: role);
      }
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

  Future<void> _markFailed(BleOutboxData row, String error) async {
    _log(
      'deliveryFailed sosId=${row.sosId} messageId=${row.messageId} '
      'reason=$error',
    );
    final current = await _deliveryRepository.lookupOutbox(row.messageId);
    final attempts = math.max(1, current?.retryCount ?? row.retryCount + 1);
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
    } catch (transitionError) {
      _log(
        'Unable to persist BLE failure for ${row.messageId}: $transitionError',
      );
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
    } catch (transitionError) {
      _log('Unable to expire BLE message $messageId: $transitionError');
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
