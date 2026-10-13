import 'dart:async';

import 'package:flutter/material.dart';

import '../data/ble_protocol.dart';
import '../data/ble_transport.dart';
import '../domain/ble_models.dart';

class BleTestPage extends StatefulWidget {
  BleTestPage({super.key, BleTransportClient? transport})
    : transport = transport ?? BleTransport(),
      ownsTransport = transport == null;

  final BleTransportClient transport;
  final bool ownsTransport;

  @override
  State<BleTestPage> createState() => _BleTestPageState();
}

class _BleTestPageState extends State<BleTestPage> {
  final _messageController = TextEditingController();
  final _devices = <String, BleDevice>{};
  final _states = <String, String>{};
  final _assemblers = <String, BleMessageAssembler>{};
  final _logs = <String>[];
  final _received = <String>[];
  final _connectionWaiters = <String, Completer<void>>{};
  StreamSubscription<BleEvent>? _eventsSubscription;
  String _centralState = 'unknown';
  String _peripheralState = 'unknown';
  String _phase = 'idle';
  String? _selectedDeviceId;
  String? _busyOperation;
  bool _disposed = false;
  late Future<void> _readyFuture;

  bool get _busy => _busyOperation != null;
  BleDevice? get _selectedDevice =>
      _selectedDeviceId == null ? null : _devices[_selectedDeviceId];

  @override
  void initState() {
    super.initState();
    _eventsSubscription = widget.transport.events.listen(
      _handleEvent,
      onError: (Object error, StackTrace stack) {
        _log('Transport stream error: $error');
      },
    );
    _readyFuture = _initialize();
    unawaited(_readyFuture.catchError((Object _) {}));
  }

  Future<void> _initialize() async {
    try {
      await widget.transport.initialize();
      _log('Transport initialized');
    } catch (error) {
      _log('Initialize failed: $error');
      rethrow;
    }
  }

  void _handleEvent(BleEvent event) {
    if (_disposed) return;
    final device = event.device;
    if (device != null && device.id.isNotEmpty) {
      _devices[device.id] = device;
    }
    if (event.type == 'centralState') _centralState = event.state ?? 'unknown';
    if (event.type == 'peripheralState') {
      _peripheralState = event.state ?? 'unknown';
    }
    if (event.type == 'state') _phase = event.state ?? 'unknown';
    switch (event.type) {
      case 'deviceFound':
        if (device != null) _log('Discovered ${_deviceLabel(device)}');
        break;
      case 'connecting':
        _phase = 'connecting';
        if (device != null) _states[device.id] = 'connecting';
        _log('Connecting to ${device?.id ?? 'device'}');
        break;
      case 'connected':
        _phase = 'connected / GATT ready';
        if (device != null) _states[device.id] = 'connected';
        if (device != null) {
          _connectionWaiters.remove(device.id)?.complete();
        }
        _log('Connected to ${device?.id ?? 'device'}');
        break;
      case 'disconnected':
        _phase = 'disconnected';
        if (device != null) {
          _states[device.id] = 'disconnected';
          _assemblers.removeWhere((key, _) => key.startsWith('${device.id}|'));
        }
        if (device != null) {
          _connectionWaiters
              .remove(device.id)
              ?.completeError(
                BleTransportException(
                  event.error ?? 'Disconnected before GATT was ready',
                ),
              );
        }
        _log(
          'Disconnected from ${device?.id ?? 'device'}${event.error == null ? '' : ': ${event.error}'}',
        );
        break;
      case 'data':
        _handleData(event);
        break;
      case 'error':
        _phase = 'error';
        if (device != null) {
          _connectionWaiters
              .remove(device.id)
              ?.completeError(
                BleTransportException(event.error ?? 'BLE operation failed'),
              );
        }
        _log('Native error: ${event.error ?? 'unknown error'}');
        break;
      case 'state':
        _log('Bluetooth state: ${event.state ?? 'unknown'}');
        break;
      case 'discoveringServices':
        _phase = 'discovering services';
        _log('Discovering GATT services');
        break;
      case 'serviceDiscovered':
      case 'characteristicsDiscovered':
        _phase = 'configuring characteristics';
        _log('GATT ${event.type}');
        break;
      case 'sendAccepted':
        _log('Native write accepted; remote receipt is not confirmed');
        break;
      default:
        _log('Event: ${event.type}');
    }
    if (mounted) setState(() {});
  }

  void _handleData(BleEvent event) {
    final key =
        '${event.device?.id ?? 'unknown'}|${event.role?.wireValue ?? 'central'}';
    final payload = event.payload;
    if (payload == null) {
      _log('Received data without a payload');
      return;
    }
    final assembler = _assemblers.putIfAbsent(key, BleMessageAssembler.new);
    try {
      final message = assembler.accept(payload);
      if (message == null) return;
      final stamp = _time();
      final sender = event.device?.id ?? 'unknown sender';
      _received.insert(
        0,
        '$stamp · $sender · ${message.payload['text'] ?? message.type}',
      );
      _log('Received message from $sender');
    } on BleProtocolException catch (error) {
      _log('Received invalid frame: ${error.message}');
    }
  }

  Future<void> _run(String name, Future<void> Function() action) async {
    if (_busy || _disposed) return;
    setState(() => _busyOperation = name);
    try {
      await action();
    } catch (error) {
      _log('$name failed: $error');
    } finally {
      if (mounted) setState(() => _busyOperation = null);
    }
  }

  Future<void> _requestPermissions() => _run('permissions', () async {
    await widget.transport.requestPermissions();
    _log('Permission request sent');
  });

  Future<void> _startScan() => _run('scan', () async {
    await _readyFuture;
    _assertActive();
    _log('Starting BLE scan');
    await widget.transport.startDiscovery();
  });

  Future<void> _stopScan() => _run('stop scan', () async {
    await _readyFuture;
    _assertActive();
    await widget.transport.stopDiscovery();
    _log('Scan stopped');
  });

  Future<void> _startAdvertising() => _run('advertising', () async {
    await _readyFuture;
    _assertActive();
    await widget.transport.startAdvertising(name: 'Off Grid SOS Test');
    _log('Advertising start accepted by native transport');
  });

  Future<void> _stopAdvertising() => _run('stop advertising', () async {
    await _readyFuture;
    _assertActive();
    await widget.transport.stopAdvertising();
    _log('Advertising stopped');
  });

  Future<void> _connect(BleDevice device) => _run('connect', () async {
    await _readyFuture;
    _assertActive();
    _selectedDeviceId = device.id;
    _states[device.id] = 'connecting';
    _log('Connect requested for ${device.id}');
    final waiter = Completer<void>();
    _connectionWaiters.remove(device.id);
    _connectionWaiters[device.id] = waiter;
    try {
      await widget.transport.connect(device.id);
      await waiter.future.timeout(const Duration(seconds: 15));
    } finally {
      if (identical(_connectionWaiters[device.id], waiter)) {
        _connectionWaiters.remove(device.id);
      }
    }
  });

  Future<void> _disconnect(BleDevice device) => _run('disconnect', () async {
    await _readyFuture;
    _assertActive();
    await widget.transport.disconnect(device.id);
    _log('Disconnect requested for ${device.id}');
  });

  Future<void> _send() async {
    final device = _selectedDevice;
    final text = _messageController.text.trim();
    if (_busy ||
        device == null ||
        text.isEmpty ||
        _states[device.id] != 'connected') {
      return;
    }
    await _run('send', () async {
      await _readyFuture;
      _assertActive();
      final message = BleMessage(
        id: 'ble-test-${DateTime.now().microsecondsSinceEpoch}',
        type: 'test',
        createdAt: DateTime.now().toUtc(),
        payload: {'text': text},
      );
      final frames = BleMessageCodec.encode(
        message,
        maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
      );
      for (final frame in frames) {
        _assertActive();
        await widget.transport.send(device.id, frame);
      }
      _messageController.clear();
      _log(
        'Send accepted: ${frames.length} frame(s). Remote receipt is not confirmed.',
      );
    });
  }

  void _log(String message) {
    if (_disposed) return;
    final line = '${_time()}  $message';
    _logs.insert(0, line);
    if (_logs.length > 120) _logs.removeLast();
    if (mounted) setState(() {});
  }

  String _time() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  String _deviceLabel(BleDevice device) =>
      '${device.name?.isNotEmpty == true ? device.name : 'Unnamed'} (${device.id})';

  @override
  void dispose() {
    _disposed = true;
    unawaited(_eventsSubscription?.cancel() ?? Future<void>.value());
    for (final waiter in _connectionWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(
          const BleTransportException('BLE test screen disposed'),
        );
      }
    }
    _connectionWaiters.clear();
    _messageController.dispose();
    if (widget.ownsTransport) {
      unawaited(widget.transport.dispose());
    }
    super.dispose();
  }

  void _assertActive() {
    if (_disposed || !mounted) {
      throw const BleTransportException('BLE test screen was disposed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedConnected =
        _selectedDevice != null && _states[_selectedDevice!.id] == 'connected';
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Test (Debug)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _warningCard(),
          const SizedBox(height: 12),
          _statusCard(),
          const SizedBox(height: 12),
          _capabilityCard(),
          const SizedBox(height: 12),
          _controlsCard(),
          const SizedBox(height: 12),
          _devicesCard(),
          const SizedBox(height: 12),
          _sendCard(selectedConnected),
          const SizedBox(height: 12),
          _receivedCard(),
          const SizedBox(height: 12),
          _logCard(),
        ],
      ),
    );
  }

  Widget _warningCard() => Card(
    color: const Color(0xFFFFF4E5),
    child: const ListTile(
      leading: Icon(Icons.bug_report_outlined, color: Color(0xFF9A5A00)),
      title: Text(
        'Debug tool only',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'This screen does not create or send production SOS alerts.',
      ),
    ),
  );

  Widget _statusCard() => Card(
    child: ListTile(
      leading: Icon(
        _centralState == 'poweredOff'
            ? Icons.bluetooth_disabled
            : Icons.bluetooth,
        color: Colors.blue,
      ),
      title: const Text('Bluetooth status'),
      subtitle: Text(
        'Central: $_centralState\nPeripheral: $_peripheralState\nPhase: $_phase',
      ),
      isThreeLine: true,
      trailing: FilledButton.tonal(
        onPressed: _busy ? null : _requestPermissions,
        child: const Text('Permissions'),
      ),
    ),
  );

  Widget _capabilityCard() => const Card(
    child: Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'Android: scan, advertise, connect, write and receive GATT data.\niOS: scan, advertise, connect, write and receive CoreBluetooth data.\nForeground testing is required; background operation and delivery acknowledgements are not implemented.',
      ),
    ),
  );

  Widget _controlsCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _startScan,
            icon: const Icon(Icons.search),
            label: const Text('Start Scan'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _stopScan,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Scan'),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _startAdvertising,
            icon: const Icon(Icons.cell_tower),
            label: const Text('Start Advertising'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _stopAdvertising,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop Advertising'),
          ),
        ],
      ),
    ),
  );

  Widget _devicesCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Discovered devices',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (_devices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No devices discovered yet. Start a scan on both phones.',
              ),
            ),
          for (final device in _devices.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                device.name?.isNotEmpty == true
                    ? device.name!
                    : 'Unnamed device',
              ),
              subtitle: Text(
                '${device.id}${device.rssi == null ? '' : ' · RSSI ${device.rssi}'}\nState: ${_states[device.id] ?? 'discovered'}',
              ),
              isThreeLine: true,
              trailing: _states[device.id] == 'connected'
                  ? OutlinedButton(
                      onPressed: _busy ? null : () => _disconnect(device),
                      child: const Text('Disconnect'),
                    )
                  : FilledButton.tonal(
                      onPressed: _busy ? null : () => _connect(device),
                      child: const Text('Connect'),
                    ),
            ),
        ],
      ),
    ),
  );

  Widget _sendCard(bool enabled) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: enabled && !_busy,
              decoration: const InputDecoration(
                labelText: 'Test message',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: enabled && !_busy ? _send : null,
            child: const Text('Send'),
          ),
        ],
      ),
    ),
  );

  Widget _receivedCard() => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text('Received messages (${_received.length})'),
      children: _received.isEmpty
          ? [const ListTile(title: Text('No complete messages received yet.'))]
          : _received
                .map((message) => ListTile(dense: true, title: Text(message)))
                .toList(),
    ),
  );

  Widget _logCard() => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Row(
        children: [
          const Expanded(child: Text('Diagnostic log')),
          TextButton(
            onPressed: _logs.isEmpty ? null : () => setState(_logs.clear),
            child: const Text('Clear'),
          ),
        ],
      ),
      children: [
        SizedBox(
          height: 180,
          child: _logs.isEmpty
              ? const Center(child: Text('No diagnostics yet.'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 2,
                    ),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
        ),
      ],
    ),
  );
}
