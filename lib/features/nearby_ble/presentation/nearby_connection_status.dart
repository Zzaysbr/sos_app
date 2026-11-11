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
    this.verifiedPeerKey,
  });
  final BleTransportClient? transport;
  final Future<void> Function()? onSearch;
  final Future<void> Function(String)? onConnect;
  final Future<void> Function(String)? onDisconnect;
  final String? Function(String)? verifiedPeerKey;

  @override
  State<NearbyConnectionStatus> createState() => _NearbyConnectionStatusState();
}

class _NearbyConnectionStatusState extends State<NearbyConnectionStatus> {
  static final _readableModel = RegExp(r'^[A-Za-z][A-Za-z0-9 ._+-]{1,12}$');
  final _models = <String, String>{};
  final _seen = <String, DateTime>{};
  final _connecting = <String>{};
  final _disconnecting = <String>{};
  final _disconnectCalls = <String>{};
  final _disconnectTimers = <String, Timer>{};
  final _lost = <String, DateTime>{};
  final _connected = <String, Set<BleSessionRole>>{};
  final _events = BleConnectionEvents();
  StreamSubscription<BleEvent>? _subscription;
  Timer? _timer;
  String? _radioState;
  bool _error = false;
  bool _busy = false;
  bool _searched = false;

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
      if (mounted && (_seen.isNotEmpty || _lost.isNotEmpty)) {
        setState(
          () => _lost.removeWhere(
            (_, time) =>
                DateTime.now().difference(time) >= const Duration(seconds: 30),
          ),
        );
      }
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
                for (final peer in {..._connecting, ..._connected.keys}) {
                  if (_connecting.contains(peer) ||
                      _connected[peer]?.isNotEmpty == true) {
                    _lost[peer] = DateTime.now();
                  }
                }
                _connecting.clear();
                _connected.clear();
                _seen.clear();
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
            if (current.type == 'connecting') {
              _connecting.add(id);
              _lost.remove(id);
            }
            if (current.type == 'connected') {
              _connecting.remove(id);
              _lost.remove(id);
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
              if (_connected[id]?.isNotEmpty != true &&
                  !_connecting.contains(id)) {
                _lost[id] = DateTime.now();
                if (!_disconnectCalls.contains(id)) _clearDisconnect(id);
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
      _disconnecting.clear();
      _disconnectCalls.clear();
      for (final timer in _disconnectTimers.values) {
        timer.cancel();
      }
      _disconnectTimers.clear();
      _lost.clear();
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
    for (final timer in _disconnectTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  String _modelName(String id, bool thai) {
    final key = widget.verifiedPeerKey?.call(id);
    final model =
        _models[id] ??
        (key == null
            ? null
            : _models.entries
                  .where(
                    (entry) => widget.verifiedPeerKey?.call(entry.key) == key,
                  )
                  .map((entry) => entry.value)
                  .firstOrNull);
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

  Future<void> _disconnectGroup(String peer) async {
    final key = widget.verifiedPeerKey?.call(peer);
    final aliases = key == null
        ? [peer]
        : _connected.entries
              .where(
                (entry) =>
                    entry.value.isNotEmpty &&
                    widget.verifiedPeerKey?.call(entry.key) == key,
              )
              .map((entry) => entry.key)
              .toList();
    // Capture aliases before awaits: explicit disconnect may revoke selection.
    final transport = widget.transport;
    final disconnect = widget.onDisconnect!;
    setState(() {
      _disconnecting.addAll(aliases);
      _disconnectCalls.addAll(aliases);
    });
    var success = false;
    try {
      for (final alias in aliases) {
        await disconnect(alias);
      }
      success = true;
    } finally {
      if (mounted && identical(widget.transport, transport)) {
        setState(() {
          for (final alias in aliases) {
            _disconnectCalls.remove(alias);
            if (!success || _connected[alias]?.isNotEmpty != true) {
              _clearDisconnect(alias);
            } else {
              // A native request can complete before its disconnect event.
              // Do not leave the retry action disabled forever if it is lost.
              _disconnectTimers.remove(alias)?.cancel();
              _disconnectTimers[alias] = Timer(const Duration(seconds: 10), () {
                if (mounted) setState(() => _clearDisconnect(alias));
              });
            }
          }
        });
      }
    }
  }

  void _clearDisconnect(String peer) {
    _disconnecting.remove(peer);
    _disconnectTimers.remove(peer)?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final connected = {
      ..._connected.keys.where((id) => _connected[id]!.isNotEmpty),
      ..._disconnecting,
    }.toList()..sort();
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
    // Only full, proof-verified keys can merge native aliases. Equal model
    // names and public discovery hints must never collapse distinct devices.
    final shownKeys = <String>{};
    bool showPeer(String peer) {
      final key = widget.verifiedPeerKey?.call(peer);
      return key == null || shownKeys.add(key);
    }

    final visibleConnected = connected.where(showPeer).toList();
    final visibleFound = found.where(showPeer).toList();
    final lostOnly = _lost.keys
        .where(
          (peer) =>
              !connected.contains(peer) &&
              !found.contains(peer) &&
              DateTime.now().difference(_lost[peer]!) <
                  const Duration(seconds: 30),
        )
        .where(showPeer)
        .toList();
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
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _searched = true);
                    await _run(widget.onSearch!);
                  },
            icon: const Icon(Icons.bluetooth_searching),
            label: Text(thai ? 'ค้นหาเครื่องใกล้เคียง' : 'Find nearby devices'),
          ),
        if (unavailable && _searched)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              thai ? 'เปิด Bluetooth และอนุญาตการค้นหาอุปกรณ์ แล้วลองอีกครั้ง' : 'Turn on Bluetooth and allow nearby access, then try again.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (!unavailable &&
            _searched &&
            !_busy &&
            visibleConnected.isEmpty &&
            visibleFound.isEmpty &&
            lostOnly.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              thai ? 'ยังไม่พบเครื่อง เปิดแอปบนอีกเครื่องและวางไว้ใกล้กัน' : 'No devices found yet. Open the app on the other device and keep it nearby.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (!unavailable && widget.onDisconnect != null)
          for (final peer in visibleConnected)
            _peerTile(
              peer,
              thai,
              connected: true,
              action: TextButton(
                onPressed: _busy || _disconnecting.contains(peer)
                    ? null
                    : () => _run(() => _disconnectGroup(peer)),
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                child: Text(
                  _disconnecting.contains(peer)
                      ? (thai ? 'กำลังเลิกเชื่อมต่อ' : 'Disconnecting…')
                      : (thai ? 'เลิกเชื่อม' : 'Disconnect'),
                ),
              ),
            ),
        if (!unavailable && widget.onConnect != null)
          for (final peer in visibleFound)
            _peerTile(
              peer,
              thai,
              connected: false,
              status: _lost.containsKey(peer)
                  ? (thai ? 'หลุดการเชื่อมต่อ' : 'Disconnected')
                  : null,
              action: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
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
        for (final peer in lostOnly)
          _peerTile(
            peer,
            thai,
            connected: false,
            status: thai ? 'หลุดการเชื่อมต่อ' : 'Disconnected',
          ),
      ],
    );
  }

  Widget _peerTile(
    String peer,
    bool thai, {
    required bool connected,
    Widget? action,
    String? status,
  }) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final details = <Widget>[
          if (status != null) Text(status, style: theme.textTheme.bodySmall),
          if (stacked && action != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
        ];
        return ListTile(
          dense: true,
          minVerticalPadding: 0,
          minLeadingWidth: 20,
          horizontalTitleGap: 8,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            connected ? Icons.bluetooth_connected : Icons.smartphone,
            size: 20,
            color: connected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          title: Text(
            _modelName(peer, thai),
            style: theme.textTheme.titleSmall,
          ),
          trailing: stacked ? null : action,
          subtitle: details.isEmpty
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: details,
                ),
        );
      },
    );
  }
}
