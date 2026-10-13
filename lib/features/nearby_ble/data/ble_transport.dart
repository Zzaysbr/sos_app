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
  Future<void> send(String deviceId, List<int> frame);
  Future<void> dispose();
}

class BleTransport implements BleTransportClient {
  BleTransport({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('sos_ble_transport/methods'),
      _events = events ?? const EventChannel('sos_ble_transport/events');
  final MethodChannel _methods;
  final EventChannel _events;
  Stream<BleEvent>? _stream;
  Future<void>? _initializeFuture;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  @override
  Stream<BleEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((e) => BleEvent.fromMap(Map<Object?, Object?>.from(e as Map)));
  @override
  Future<void> initialize() {
    if (_disposed) {
      throw const BleTransportException('BLE transport was disposed');
    }
    return _initializeFuture ??= _call('initialize');
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
  Future<void> send(String deviceId, List<int> frame) =>
      _call('send', {'deviceId': deviceId, 'data': frame});
  @override
  Future<void> dispose() {
    if (_disposeFuture != null) return _disposeFuture!;
    _disposed = true;
    return _disposeFuture = _call('dispose', null, true);
  }

  Future<void> _call(
    String method, [
    Map<String, Object?>? args,
    bool allowAfterDispose = false,
  ]) async {
    if (_disposed && !allowAfterDispose) {
      throw const BleTransportException('BLE transport was disposed');
    }
    try {
      await _methods.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      throw BleTransportException(e.message ?? e.code);
    }
  }
}
