import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../data/ble_transport.dart';
import '../domain/ble_models.dart';

/// Lets the user choose one currently discovered and GATT-ready peer.
/// The transport is shared with the coordinator; this page never disposes it.
class BleRecipientPickerPage extends StatefulWidget {
  const BleRecipientPickerPage({super.key, required this.transport});

  final BleTransportClient transport;

  @override
  State<BleRecipientPickerPage> createState() => _BleRecipientPickerPageState();
}

class _BleRecipientPickerPageState extends State<BleRecipientPickerPage> {
  final Object _discoveryLease = Object();
  late final BlePresenceManager _presence;
  final _devices = <String, BleDevice>{};
  final _states = <String, String>{};
  StreamSubscription<BleEvent>? _subscription;
  Future<void>? _ready;
  String? _error;
  String? _connecting;
  bool _scanning = false;
  bool _disposed = false;

  String _key(String id) => id.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _presence = BlePresenceManager.sharedFor(widget.transport);
    _subscription = widget.transport.events.listen(_onEvent);
    _ready = _prepare();
    unawaited(_ready!.catchError((_) {}));
  }

  Future<void> _prepare() async {
    try {
      await widget.transport.requestPermissions();
      await widget.transport.initialize();
      if (_disposed) return;
      _scanning = true;
      await _presence.acquireDiscovery(_discoveryLease);
      if (mounted) setState(() {});
    } catch (error) {
      _scanning = false;
      _error = error.toString();
      if (mounted) setState(() {});
      rethrow;
    }
  }

  void _onEvent(BleEvent event) {
    if (_disposed) return;
    final device = event.device;
    if (event.type == 'deviceFound' && !_scanning) {
      return;
    }
    if (device != null && device.id.trim().isNotEmpty) {
      final key = _key(device.id);
      final old = _devices[key];
      _devices[key] = BleDevice(
        id: old?.id ?? device.id.trim(),
        name: device.name?.trim().isNotEmpty == true
            ? device.name!.trim()
            : old?.name,
        rssi: device.rssi ?? old?.rssi,
      );
    }
    if (device != null && event.type == 'connecting') {
      _states[_key(device.id)] = 'connecting';
    } else if (device != null && event.type == 'connected') {
      _states[_key(device.id)] = 'connected';
      if (_connecting == _key(device.id) && mounted) {
        Navigator.of(context).pop(device.id);
        return;
      }
    } else if (device != null && event.type == 'disconnected') {
      _states[_key(device.id)] = 'disconnected';
      if (_connecting == _key(device.id)) {
        _error = event.error ?? 'Peer disconnected before GATT was ready.';
        _connecting = null;
      }
    } else if (event.type == 'error') {
      _error = event.error ?? 'BLE operation failed.';
      _connecting = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _connect(BleDevice device) async {
    if (_connecting != null) return;
    if (_states[_key(device.id)] == 'connected') {
      Navigator.of(context).pop(device.id);
      return;
    }
    setState(() {
      _connecting = _key(device.id);
      _states[_connecting!] = 'connecting';
      _error = null;
    });
    try {
      await _ready;
      await widget.transport.connect(device.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _connecting = null;
          _states[_key(device.id)] = 'error';
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _scanning = false;
    unawaited(_presence.releaseDiscovery(_discoveryLease).catchError((_) {}));
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseBleRecipient)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(l10n.bleRecipientTrustNotice),
            ),
          ),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l10n.bleNotReady),
                subtitle: Text(_error!),
              ),
            ),
          if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text(l10n.scanningNearby)),
            ),
          for (final device in _devices.values)
            ListTile(
              title: Text(
                device.name?.isNotEmpty == true
                    ? device.name!
                    : l10n.unnamedDevice,
              ),
              subtitle: Text(
                '${device.id}${device.rssi == null ? '' : ' · RSSI ${device.rssi}'}\n'
                '${l10n.deviceStatus(_states[_key(device.id)] ?? 'discovered')}',
              ),
              isThreeLine: true,
              trailing: FilledButton(
                onPressed: _connecting == null ? () => _connect(device) : null,
                child: Text(
                  _states[_key(device.id)] == 'connected'
                      ? l10n.useDevice
                      : l10n.connect,
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.continueWithoutRecipient),
          ),
        ],
      ),
    );
  }
}
