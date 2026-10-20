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
        'data': frame,
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
