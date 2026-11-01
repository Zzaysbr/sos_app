import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/ble_models.dart';

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
    final shouldDiscover = _foreground && wantsDiscovery;
    final shouldAdvertise = _foreground && wantsAdvertising;

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
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  /// Returns false when [canSend] cancels the message before all frames are
  /// written. Native write completion is deliberately not an application ACK.
  Future<bool> sendFrames(
    String deviceId,
    Iterable<List<int>> frames, {
    required BleSessionRole role,
    bool Function()? canSend,
  }) async {
    final immutableFrames = frames
        .map((frame) => List<int>.unmodifiable(frame))
        .toList(growable: false);
    final previous = _tails[deviceId] ?? Future<void>.value();
    final current = previous.then((_) async {
      for (final frame in immutableFrames) {
        if (canSend != null && !canSend()) return false;
        await _transport.send(deviceId, frame, role: role);
      }
      return true;
    });
    final tail = current.then<void>((_) {}, onError: (_) {});
    _tails[deviceId] = tail;
    try {
      return await current;
    } finally {
      if (identical(_tails[deviceId], tail)) _tails.remove(deviceId);
    }
  }
}

class BleTransport implements BleTransportClient {
  BleTransport({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('sos_ble_transport/methods'),
      _events = events ?? const EventChannel('sos_ble_transport/events');
  final MethodChannel _methods;
  final EventChannel _events;
  Stream<BleEvent>? _stream;
  StreamSubscription<BleEvent>? _nativeSubscription;
  StreamController<BleEvent>? _eventController;
  final _connections = <String, BleEvent>{};
  Future<void>? _initializeFuture;
  Future<void>? _disposeFuture;
  Completer<void>? _idleCompleter;
  int _activeCalls = 0;
  bool _disposed = false;

  @override
  Stream<BleEvent> get events {
    return _stream ??= _createEvents();
  }

  Stream<BleEvent> _createEvents() {
    final source = StreamController<BleEvent>.broadcast();
    _eventController = source;
    _nativeSubscription = _events
        .receiveBroadcastStream()
        .map((value) {
          final event = BleEvent.fromMap(
            Map<Object?, Object?>.from(value as Map),
          );
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
          return event;
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
    unawaited(_eventController?.close());
    final idle = _idleCompleter?.future;
    if (idle != null) await idle;
    try {
      await _methods.invokeMethod<void>('dispose');
    } on PlatformException catch (e) {
      throw BleTransportException(e.message ?? e.code);
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
      await _methods.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      throw BleTransportException(e.message ?? e.code);
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
