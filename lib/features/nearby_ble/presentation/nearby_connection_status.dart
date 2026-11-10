import 'dart:async';

import 'package:flutter/material.dart';

import '../data/ble_transport.dart';
import '../domain/ble_connection_events.dart';
import '../domain/ble_models.dart';

/// Passive view of the shared radio. Rendering this never starts scanning or
/// connects to a device. Discovery expires; connection state follows native
/// readiness/disconnect events, independently for central/peripheral roles.
class NearbyConnectionStatus extends StatefulWidget {
  const NearbyConnectionStatus({
    super.key,
    this.transport,
    this.onSearch,
    this.onConnect,
    this.onDisconnect,
  });
  final BleTransportClient? transport;
  final Future<void> Function()? onSearch;
  final Future<void> Function(String)? onConnect;
  final Future<void> Function(String)? onDisconnect;

  @override
  State<NearbyConnectionStatus> createState() => _NearbyConnectionStatusState();
}

class _NearbyConnectionStatusState extends State<NearbyConnectionStatus> {
  static final _readableModel = RegExp(r'^[A-Za-z][A-Za-z0-9 ._+-]{1,12}$');
  final _models = <String, String>{};
  final _seen = <String, DateTime>{};
  final _connecting = <String>{};
  final _connected = <String, Set<BleSessionRole>>{};
  final _events = BleConnectionEvents();
  StreamSubscription<BleEvent>? _subscription;
  Timer? _timer;
  String? _radioState;
  bool _error = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) {
        final thai = Localizations.localeOf(context).languageCode == 'th';
        final bluetoothUnavailable =
            error is BleTransportException &&
            const {
              'bluetooth_unavailable',
              'powered_off',
              'unauthorized',
              'permission_denied',
              'unsupported',
            }.contains(error.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bluetoothUnavailable
                  ? (thai
                        ? 'Bluetooth ไม่พร้อมใช้งาน'
                        : 'Bluetooth unavailable')
                  : (thai
                        ? 'ดำเนินการไม่สำเร็จ กรุณาลองใหม่'
                        : 'Could not complete the action. Try again.'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _listen();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _seen.isNotEmpty) setState(() {});
    });
  }

  void _listen() {
    _subscription = widget.transport?.events.listen(
      (event) {
        if (!mounted) return;
        for (final current in _events.accept(event)) {
          setState(() {
            _error = false;
            if (current.type == 'state' ||
                current.type == 'centralState' ||
                current.type == 'peripheralState') {
              _radioState = current.state;
              if ([
                'poweredOff',
                'unauthorized',
                'unsupported',
                'resetting',
              ].contains(current.state)) {
                _connecting.clear();
                _connected.clear();
                _seen.clear();
                _models.clear();
                _events.clear();
              }
            }
            final device = current.device;
            if (device == null || device.id.trim().isEmpty) return;
            final id = device.id;
            final model = device.model?.trim();
            if (model != null && model.isNotEmpty) _models[id] = model;
            if (current.type == 'deviceFound') {
              _seen[id] = DateTime.now();
            }
            if (current.type == 'connecting') _connecting.add(id);
            if (current.type == 'connected') {
              _connecting.remove(id);
              _connected
                  .putIfAbsent(id, () => {})
                  .add(current.role ?? BleSessionRole.central);
            } else if (current.type == 'disconnected') {
              if (current.role != BleSessionRole.peripheral) {
                _connecting.remove(id);
              }
              if (current.role == null) {
                _connected.remove(id);
              } else {
                _connected[id]?.remove(current.role);
              }
            }
          });
        }
      },
      onError: (Object error) {
        if (mounted) setState(() => _error = true);
      },
    );
  }

  @override
  void didUpdateWidget(covariant NearbyConnectionStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transport != widget.transport) {
      _subscription?.cancel();
      _events.clear();
      _connecting.clear();
      _connected.clear();
      _seen.clear();
      _models.clear();
      _radioState = null;
      _listen();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  String _modelName(String id, bool thai) {
    final model = _models[id];
    return switch (model) {
      'M:I15,5' => 'iPhone 15 Plus',
      'M:I17,4' => 'iPhone 16 Plus',
      'M:I14,5' => 'iPhone 13',
      'M:P14,8' || 'M:P14,9' || 'M:P14,10' || 'M:P14,11' => 'iPad Air (M2)',
      String code when code.startsWith('SM-A536') => 'Samsung Galaxy A53',
      String code when code.startsWith('SM-A037') => 'Samsung Galaxy A03s',
      String code when code.startsWith('M:I') => 'iPhone',
      String code when code.startsWith('M:P') => 'iPad',
      String code when code.startsWith('SM-') => 'Samsung Galaxy',
      String code when _readableModel.hasMatch(code) => code,
      _ => thai ? 'ไม่ทราบรุ่น' : 'Unknown model',
    };
  }

  @override
  Widget build(BuildContext context) {
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final connected =
        _connected.keys.where((id) => _connected[id]!.isNotEmpty).toList()
          ..sort();
    final found =
        _seen.keys
            .where(
              (id) =>
                  !connected.contains(id) &&
                  DateTime.now().difference(_seen[id]!) <
                      const Duration(seconds: 30),
            )
            .toList()
          ..sort();
    final unavailable =
        widget.transport == null ||
        _error ||
        [
          'poweredOff',
          'unauthorized',
          'unsupported',
          'resetting',
        ].contains(_radioState);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onSearch != null)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _run(widget.onSearch!),
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(thai ? 'ค้นหาเครื่องใกล้เคียง' : 'Find nearby devices'),
          ),
        if (!unavailable && widget.onDisconnect != null)
          for (final peer in connected)
            ListTile(
              title: Text(_modelName(peer, thai)),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() => widget.onDisconnect!(peer)),
                child: Text(thai ? 'เลิกเชื่อม' : 'Disconnect'),
              ),
            ),
        if (!unavailable && widget.onConnect != null)
          for (final peer in found)
            ListTile(
              title: Text(_modelName(peer, thai)),
              trailing: TextButton(
                onPressed: _busy || _connecting.contains(peer)
                    ? null
                    : () {
                        final seen = _seen[peer];
                        if (seen == null ||
                            DateTime.now().difference(seen) >=
                                const Duration(seconds: 30)) {
                          return;
                        }
                        unawaited(_run(() => widget.onConnect!(peer)));
                      },
                child: Text(
                  _connecting.contains(peer)
                      ? (thai ? 'กำลังเชื่อม…' : 'Connecting…')
                      : (thai ? 'เชื่อมต่อ' : 'Connect'),
                ),
              ),
            ),
      ],
    );
  }
}
