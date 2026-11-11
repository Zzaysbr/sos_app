import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/ble_models.dart';
import '../domain/ble_connection_events.dart';

abstract interface class BleTransportClient {
  Stream<BleEvent> get events;
  Future<void> initialize();
  Future<void> requestPermissions();
  Future<void> startAdvertising({String? name});
  Future<void> stopAdvertising();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(String deviceId);
  Future<void> disconnect(String deviceId);
  Future<void> send(String deviceId, List<int> frame, {BleSessionRole? role});
  Future<void> dispose();
}

abstract interface class BlePeripheralRecovery {
  bool get supportsPeripheralRecovery;
  Future<void> retirePeripheralLink(String deviceId);
}

/// Retire an outgoing client without clearing an independent inbound server.
abstract interface class BleCentralRecovery {
  Future<void> retireCentralLink(String deviceId);
}

abstract interface class BleDiscoveryIdentity {
  Future<void> setDiscoveryIdentityHint(String hint);
}

/// Optional native capability, deliberately absent from simulated transports.
abstract interface class BleBackgroundExecution {
  bool get backgroundExecutionEnabled;
  Future<void> setBackgroundExecution(bool enabled);
}

/// Negotiated single-ATT-packet capacity, not an assumed requested MTU.
abstract interface class BleFrameCapacity {
  Future<int> maxFrameBytes(String deviceId, BleSessionRole role);
}

Future<int> negotiatedBleFrameBytes(
  BleTransportClient transport,
  String peer,
  BleSessionRole role,
) async {
  if (transport is! BleFrameCapacity) return 20;
  try {
    final value = await (transport as BleFrameCapacity)
        .maxFrameBytes(peer, role)
        .timeout(const Duration(seconds: 2));
    return value < 20 ? 20 : value.clamp(20, 512);
  } on Object {
    return 20;
  }
}

/// Owns the process-wide native scan and advertising state for one transport.
///
/// BLE scanning and advertising are global native operations. Feature code must
/// therefore acquire a lease instead of calling start/stop directly; releasing
/// one lease cannot stop an operation still required by another feature.
class BlePresenceManager {
  BlePresenceManager._(this._transport);

  static final Expando<BlePresenceManager> _shared =
      Expando<BlePresenceManager>('ble-presence-manager');

  static BlePresenceManager sharedFor(BleTransportClient transport) =>
      _shared[transport] ??= BlePresenceManager._(transport);

  final BleTransportClient _transport;
  final Set<Object> _discoveryLeases = <Object>{};
  final Map<Object, String> _advertisingLeases = <Object, String>{};
  Future<void> _tail = Future<void>.value();
  bool _foreground = true;
  bool _nativeDiscovering = false;
  bool _nativeAdvertising = false;

  bool get wantsDiscovery => _discoveryLeases.isNotEmpty;
  bool get wantsAdvertising => _advertisingLeases.isNotEmpty;
  bool get isDiscovering => _nativeDiscovering;
  bool get isAdvertising => _nativeAdvertising;

  Future<void> acquireDiscovery(Object owner) async {
    if (!_discoveryLeases.add(owner)) return _enqueueReconcile();
    try {
      await _enqueueReconcile();
    } on Object {
      _discoveryLeases.remove(owner);
      await _enqueueReconcile().catchError((_) {});
      rethrow;
    }
  }

  Future<void> releaseDiscovery(Object owner) async {
    _discoveryLeases.remove(owner);
    await _enqueueReconcile();
  }

  Future<void> acquireAdvertising(Object owner, {required String name}) async {
    final previous = _advertisingLeases[owner];
    _advertisingLeases[owner] = name;
    try {
      await _enqueueReconcile();
    } on Object {
      if (previous == null) {
        _advertisingLeases.remove(owner);
      } else {
        _advertisingLeases[owner] = previous;
      }
      await _enqueueReconcile().catchError((_) {});
      rethrow;
    }
  }

  Future<void> releaseAdvertising(Object owner) async {
    _advertisingLeases.remove(owner);
    await _enqueueReconcile();
  }

  /// Suspends native presence while preserving feature intent for a later
  /// foreground resume. Serialized reconciliation prevents stale completions
  /// from leaving the native state inconsistent with aggregate intent.
  Future<void> setForeground(bool foreground) async {
    _foreground = foreground;
    await _enqueueReconcile();
  }

  Future<void> retry() => _enqueueReconcile();

  /// Native adapters drop scan/advertising state when Bluetooth becomes
  /// unavailable. Forget only the observed native state while retaining all
  /// consumer leases so a later powered-on event can reconcile them.
  Future<void> notifyNativePresenceLost() {
    final operation = _tail.then((_) {
      _nativeDiscovering = false;
      _nativeAdvertising = false;
    });
    _tail = operation.catchError((_) {});
    return operation;
  }

  Future<void> shutdown() async {
    _foreground = false;
    _discoveryLeases.clear();
    _advertisingLeases.clear();
    await _enqueueReconcile();
  }

  Future<void> _enqueueReconcile() {
    final operation = _tail.then((_) => _reconcile());
    _tail = operation.catchError((_) {});
    return operation;
  }

  Future<void> _reconcile() async {
    final runtime = _transport is BleBackgroundExecution
        ? _transport as BleBackgroundExecution
        : null;
    if (runtime != null) {
      final wanted = wantsDiscovery || wantsAdvertising;
      // Start Android foreground service while a foreground activity exists.
      // A background callback may retain existing authorization, never create it.
      if (!wanted || _foreground || runtime.backgroundExecutionEnabled) {
        try {
          await runtime.setBackgroundExecution(wanted);
        } on Object {
          // OS refusal leaves foreground BLE available, without a false claim
          // that the process is protected in background.
        }
      }
    }
    final canRun =
        _foreground || (runtime?.backgroundExecutionEnabled ?? false);
    final shouldDiscover = canRun && wantsDiscovery;
    final shouldAdvertise = canRun && wantsAdvertising;

    if (shouldDiscover && !_nativeDiscovering) {
      await _transport.startDiscovery();
      _nativeDiscovering = true;
    } else if (!shouldDiscover && _nativeDiscovering) {
      await _transport.stopDiscovery();
      _nativeDiscovering = false;
    }

    if (shouldAdvertise && !_nativeAdvertising) {
      await _transport.startAdvertising(name: _advertisingLeases.values.first);
      _nativeAdvertising = true;
    } else if (!shouldAdvertise && _nativeAdvertising) {
      await _transport.stopAdvertising();
      _nativeAdvertising = false;
    }
  }
}

/// Serializes complete BLE messages across every feature sharing a transport.
///
/// Native GATT writes are frame-oriented, but the receiver can only validate a
/// message after every frame arrives. Direct SOS and Relay use the same native
/// connection, so independently paced frame loops can otherwise interleave
/// and starve a large Relay proof or offer. The queue is shared per transport
/// and peer; callers retain ownership of message encoding and protocol rules.
class BleMessageWriteQueue {
  BleMessageWriteQueue._(this._transport);

  static final Expando<BleMessageWriteQueue> _shared =
      Expando<BleMessageWriteQueue>('ble-message-write-queue');

  static BleMessageWriteQueue sharedFor(BleTransportClient transport) =>
      _shared[transport] ??= BleMessageWriteQueue._(transport);

  final BleTransportClient _transport;
  final _pending = <String, List<_BleFrameWrite>>{};
  final _draining = <String>{};

  /// Returns false when [canSend] cancels the message before all frames are
  /// written. Native write completion is deliberately not an application ACK.
  Future<bool> sendFrames(
    String deviceId,
    Iterable<List<int>> frames, {
    required BleSessionRole role,
    bool Function()? canSend,
    bool Function()? isConnectionCurrent,
    bool control = false,
    Duration writeTimeout = const Duration(seconds: 10),
  }) {
    if (writeTimeout <= Duration.zero) throw ArgumentError.value(writeTimeout);
    final write = _BleFrameWrite(
      frames.map((f) => List<int>.unmodifiable(f)).toList(growable: false),
      role,
      canSend,
      isConnectionCurrent,
      control,
      writeTimeout,
    );
    _pending.putIfAbsent(deviceId, () => []).add(write);
    if (_draining.add(deviceId)) unawaited(_drain(deviceId));
    return write.completed.future;
  }

  Future<void> _drain(String deviceId) async {
    final queue = _pending[deviceId]!;
    try {
      while (queue.isNotEmpty) {
        // Authentication and storage receipts must not wait behind a large
        // backlog. Preempt only between completed native writes. Codec
        // assemblers already isolate interleaved messages by message ID.
        final controlIndex = queue.indexWhere((w) => w.control);
        final write = queue[controlIndex < 0 ? 0 : controlIndex];
        try {
          if (write.canSend != null && !write.canSend!()) {
            queue.remove(write);
            write.completed.complete(false);
          } else if (write.index == write.frames.length) {
            queue.remove(write);
            write.completed.complete(true);
          } else {
            await _transport
                .send(deviceId, write.frames[write.index], role: write.role)
                .timeout(write.timeout);
            write.index++;
          }
        } on TimeoutException catch (error, stack) {
          if (write.isConnectionCurrent != null &&
              !write.isConnectionCurrent!()) {
            // The owning connection was retired while native completion was
            // pending. Its late deadline must not disconnect a replacement
            // session or fail that session's newly queued messages.
            queue.remove(write);
            write.completed.completeError(error, stack);
            continue;
          }
          // A missing native callback leaves the connection ambiguous. Fail
          // every queued message on it before disconnecting; never mix fresh
          // frames with an old in-flight write. Durable callers retain retry.
          for (final pending in queue.toList()) {
            pending.completed.completeError(error, stack);
          }
          queue.clear();
          try {
            await _transport.disconnect(deviceId).timeout(write.timeout);
          } on Object {
            // Native recovery is best effort and must also be bounded.
          }
        } catch (error, stack) {
          queue.remove(write);
          write.completed.completeError(error, stack);
        }
      }
    } finally {
      _pending.remove(deviceId);
      _draining.remove(deviceId);
    }
  }
}

class _BleFrameWrite {
  _BleFrameWrite(
    this.frames,
    this.role,
    this.canSend,
    this.isConnectionCurrent,
    this.control,
    this.timeout,
  );
  final Duration timeout;
  final List<List<int>> frames;
  final BleSessionRole role;
  final bool Function()? canSend;
  final bool Function()? isConnectionCurrent;
  final bool control;
  final completed = Completer<bool>();
  int index = 0;
}

class BleTransport
    implements
        BleTransportClient,
        BleBackgroundExecution,
        BleFrameCapacity,
        BleDiscoveryIdentity,
        BleCentralRecovery,
        BlePeripheralRecovery {
  @override
  Future<void> setDiscoveryIdentityHint(String hint) =>
      _call('setDiscoveryIdentityHint', {'hint': hint});
  @override
  Future<void> retireCentralLink(String deviceId) =>
      _call('retireCentralLink', {'deviceId': deviceId});

  @override
  bool get supportsPeripheralRecovery =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> retirePeripheralLink(String deviceId) =>
      _call('retirePeripheralLink', {'deviceId': deviceId});

  bool _backgroundEnabled = false;
  @override
  bool get backgroundExecutionEnabled => _backgroundEnabled;
  @override
  Future<void> setBackgroundExecution(bool enabled) async {
    if (_backgroundEnabled == enabled) return;
    _backgroundEnabled =
        await const MethodChannel('sos_app/background')
            .invokeMethod<bool>('setBleBackground', enabled)
            .timeout(const Duration(seconds: 5)) ??
        false;
  }

  BleTransport({
    MethodChannel? methods,
    EventChannel? events,
    this.nativeCallTimeout = const Duration(seconds: 8),
  }) : _methods = methods ?? const MethodChannel('sos_ble_transport/methods'),
       _events = events ?? const EventChannel('sos_ble_transport/events');
  final Duration nativeCallTimeout;
  final MethodChannel _methods;
  final EventChannel _events;
  // The native bridge has one sink per channel. Owner-scoped transports can
  // overlap briefly during login/logout. Separate receiveBroadcastStream calls
  // would replace that sink, and an old owner's cancel would detach the new
  // owner too. Share only the raw native feed; readiness/proof stays per owner.
  static final _nativeFeeds = Expando<Map<String, Stream<dynamic>>>(
    'ble-native-event-feeds',
  );

  Stream<dynamic> _nativeEvents() {
    final feeds = _nativeFeeds[_events.binaryMessenger] ??= {};
    return feeds.putIfAbsent(
      _events.name,
      () => _events.receiveBroadcastStream(),
    );
  }

  Stream<BleEvent>? _stream;
  StreamSubscription<BleEvent>? _nativeSubscription;
  StreamController<BleEvent>? _eventController;
  final _connections = <String, BleEvent>{};
  final _connectionEvents = BleConnectionEvents();
  Future<void>? _initializeFuture;
  Future<void>? _disposeFuture;
  Completer<void>? _idleCompleter;
  int _activeCalls = 0;
  bool _disposed = false;

  @override
  Future<int> maxFrameBytes(String deviceId, BleSessionRole role) async {
    if (_disposed) return 20;
    return await _methods.invokeMethod<int>('maxFrameBytes', {
          'deviceId': deviceId,
          'role': role.wireValue,
        }) ??
        20;
  }

  @override
  Stream<BleEvent> get events {
    return _stream ??= _createEvents();
  }

  Stream<BleEvent> _createEvents() {
    final source = StreamController<BleEvent>.broadcast();
    _eventController = source;
    _nativeSubscription = _nativeEvents()
        .expand((value) {
          final event = BleEvent.fromMap(
            Map<Object?, Object?>.from(value as Map),
          );
          final accepted = _connectionEvents.accept(event);
          for (final event in accepted) {
            final peer = event.device?.id;
            if (peer != null && !_disposed) {
              final key = '$peer|${event.role?.wireValue ?? 'central'}';
              if (event.type == 'connected') _connections[key] = event;
              if (event.type == 'disconnected') {
                _connections.removeWhere(
                  (k, _) =>
                      event.role == null ? k.startsWith('$peer|') : k == key,
                );
              }
            }
          }
          return accepted;
        })
        .listen((event) {
          if (!_disposed) source.add(event);
        }, onError: source.addError);

    return Stream<BleEvent>.multi((controller) {
      // Subscribe before the snapshot so there is no missing readiness window.
      final subscription = source.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      for (final event in _connections.values) {
        controller.add(event);
      }
      controller.onCancel = subscription.cancel;
    }, isBroadcast: true);
  }

  @override
  Future<void> initialize() {
    if (_disposed) {
      throw const BleTransportException('BLE transport was disposed');
    }
    final existing = _initializeFuture;
    if (existing != null) return existing;

    final initialization = _call('initialize');
    _initializeFuture = initialization;
    // Keep successful initialization single-flight, but allow a transient
    // permission/native failure to be retried. The identity check prevents an
    // older failed attempt from clearing a newer attempt's future.
    initialization.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_initializeFuture, initialization)) {
          _initializeFuture = null;
        }
      },
    );
    return initialization;
  }

  @override
  Future<void> requestPermissions() => _call('requestPermissions');
  @override
  Future<void> startAdvertising({String? name}) =>
      _call('startAdvertising', {'name': name});
  @override
  Future<void> stopAdvertising() => _call('stopAdvertising');
  @override
  Future<void> startDiscovery() => _call('startDiscovery');
  @override
  Future<void> stopDiscovery() => _call('stopDiscovery');
  @override
  Future<void> connect(String deviceId) =>
      _call('connect', {'deviceId': deviceId});
  @override
  Future<void> disconnect(String deviceId) =>
      _call('disconnect', {'deviceId': deviceId});
  @override
  Future<void> send(String deviceId, List<int> frame, {BleSessionRole? role}) =>
      _call('send', {
        'deviceId': deviceId,
        // StandardMessageCodec sends a plain List<int> to Android as an
        // ArrayList, while both native bridges require typed binary data
        // (ByteArray on Android and FlutterStandardTypedData on iOS).
        'data': Uint8List.fromList(frame),
        if (role != null) 'role': role.wireValue,
      });
  @override
  Future<void> dispose() {
    if (_disposeFuture != null) return _disposeFuture!;
    _disposed = true;
    _connections.clear();
    return _disposeFuture = _dispose();
  }

  Future<void> _dispose() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _connectionEvents.clear();
    _connections.clear();
    unawaited(_eventController?.close());
    final idle = _idleCompleter?.future;
    if (idle != null) await idle;
    try {
      await _methods.invokeMethod<void>('dispose').timeout(nativeCallTimeout);
    } on PlatformException catch (e) {
      throw BleTransportException(e.message ?? e.code, code: e.code);
    }
  }

  Future<void> _call(
    String method, [
    Map<String, Object?>? args,
    bool allowAfterDispose = false,
  ]) async {
    if (_disposed && !allowAfterDispose) {
      throw const BleTransportException('BLE transport was disposed');
    }
    if (!allowAfterDispose) {
      _activeCalls++;
      _idleCompleter ??= Completer<void>();
    }
    try {
      final timeout = method == 'requestPermissions'
          ? const Duration(minutes: 2)
          : (method == 'initialize' || method == 'startAdvertising')
          ? const Duration(seconds: 20)
          : nativeCallTimeout;
      await _methods.invokeMethod<void>(method, args).timeout(timeout);
    } on PlatformException catch (e) {
      throw BleTransportException(e.message ?? e.code, code: e.code);
    } finally {
      if (!allowAfterDispose) {
        _activeCalls--;
        if (_activeCalls == 0) {
          _idleCompleter?.complete();
          _idleCompleter = null;
        }
      }
    }
  }
}
