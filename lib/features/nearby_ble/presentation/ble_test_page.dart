import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../data/ble_protocol.dart';
import '../data/ble_transport.dart';
import '../domain/ble_models.dart';
import '../domain/ble_range_diagnostic.dart';
import '../data/relay_diagnostics_repository.dart';
import 'relay_diagnostics_page.dart';

class BleTestPage extends StatefulWidget {
  BleTestPage({
    super.key,
    BleTransportClient? transport,
    this.runtimeDiagnostics,
  }) : transport = transport ?? BleTransport(),
       ownsTransport = transport == null;

  final BleTransportClient transport;
  final bool ownsTransport;
  final RelayRuntimeDiagnosticsDataSource? runtimeDiagnostics;

  @override
  State<BleTestPage> createState() => _BleTestPageState();
}

class _BleTestPageState extends State<BleTestPage> {
  final Object _discoveryLease = Object();
  final Object _advertisingLease = Object();
  late final BlePresenceManager _presence;
  final _messageController = TextEditingController();
  final _devices = <String, BleDevice>{};
  final _lastSeen = <String, DateTime>{};
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
  bool _scanActive = false;
  int _scanSession = 0;
  bool _disposed = false;
  late Future<void> _readyFuture;
  BleRangeTestSession? _rangeSession;
  Timer? _rangeTimer;
  int _rangeSequence = 0;
  bool _rangeSending = false;
  bool _rangePingInFlight = false;
  int _rangeDurationSeconds = 30;
  String _rangeDistance = '5 m';
  String _rangeEnvironment = 'Open space';

  static const _rangeAckTimeout = Duration(seconds: 3);

  bool get _busy => _busyOperation != null;
  BleDevice? get _selectedDevice =>
      _selectedDeviceId == null ? null : _devices[_selectedDeviceId];

  String _deviceKey(String id) => id.trim().toLowerCase();

  String _roleKey(String deviceId, BleSessionRole? role) =>
      '${_deviceKey(deviceId)}|${(role ?? BleSessionRole.central).wireValue}';

  void _setRoleState(String deviceId, BleSessionRole? role, String state) {
    _states[_roleKey(deviceId, role)] = state;
  }

  String _peerState(String deviceId) {
    final peer = _deviceKey(deviceId);
    final hasRoleState = BleSessionRole.values.any(
      (role) => _states.containsKey('$peer|${role.wireValue}'),
    );
    if (!hasRoleState) return 'discovered';
    final roleStates = <BleSessionRole, String>{
      for (final role in BleSessionRole.values)
        role: _states['$peer|${role.wireValue}'] ?? 'disconnected',
    };
    final connected = roleStates.entries
        .where((entry) => entry.value == 'connected')
        .map((entry) => entry.key.wireValue)
        .toList(growable: false);
    if (connected.isNotEmpty) {
      return connected.length == 1
          ? 'connected'
          : 'connected (${connected.join(' + ')})';
    }
    if (roleStates.values.any((state) => state == 'connecting')) {
      return 'connecting';
    }
    if (roleStates.values.any((state) => state == 'disconnected')) {
      return 'disconnected';
    }
    return 'discovered';
  }

  bool _isPeerConnected(String deviceId) {
    final state = _peerState(deviceId);
    return state == 'connected' || state.startsWith('connected (');
  }

  @override
  void initState() {
    super.initState();
    _presence = BlePresenceManager.sharedFor(widget.transport);
    _eventsSubscription = widget.transport.events.listen(
      _handleEvent,
      onError: (Object error, StackTrace stack) {
        _log('Transport stream error: $error');
      },
    );
    _readyFuture = _initialize();
    unawaited(_readyFuture.catchError((Object _) {}));
  }

  Future<void> _initialize({bool requestPermission = true}) async {
    try {
      if (requestPermission) await widget.transport.requestPermissions();
      if (_disposed || !mounted) return;
      _log('BLE permissions granted');
      await widget.transport.initialize();
      if (_disposed || !mounted) return;
      _log('Transport initialized');
    } catch (error) {
      _log('Initialize failed: $error');
      rethrow;
    }
  }

  void _handleEvent(BleEvent event) {
    if (_disposed) return;
    final eventContext = [
      if (event.scanSession != null) 'scan=${event.scanSession}',
      if (event.attempt != null) 'attempt=${event.attempt}',
    ].join(' ');
    if (eventContext.isNotEmpty) _log('BLE event ${event.type} $eventContext');
    final device = event.device;
    final normalizedDeviceId = device?.id.trim() ?? '';
    final key = _deviceKey(normalizedDeviceId);
    final alreadyDiscovered = _devices.containsKey(key);
    final isNewScanResult = event.type == 'deviceFound' && _scanActive;
    final isConnectionSnapshot = event.type == 'connected';
    if (device != null &&
        normalizedDeviceId.isNotEmpty &&
        (isNewScanResult || alreadyDiscovered || isConnectionSnapshot)) {
      final previous = _devices[key];
      if (event.type == 'deviceFound') _lastSeen[key] = DateTime.now();
      _devices[key] = BleDevice(
        id: previous?.id ?? normalizedDeviceId,
        name: device.name?.trim().isEmpty == true
            ? previous?.name
            : device.name?.trim() ?? previous?.name,
        rssi: device.rssi ?? previous?.rssi,
      );
    }
    if (event.type == 'centralState') _centralState = event.state ?? 'unknown';
    if (event.type == 'peripheralState') {
      _peripheralState = event.state ?? 'unknown';
    }
    if (event.type == 'state') _phase = event.state ?? 'unknown';
    switch (event.type) {
      case 'deviceFound':
        if (!_scanActive) {
          _log('Ignoring device discovery outside scan session $_scanSession');
          break;
        }
        if (device != null) _log('Discovered ${_deviceLabel(device)}');
        break;
      case 'connecting':
        _phase = 'connecting';
        if (device != null) _setRoleState(device.id, event.role, 'connecting');
        _log('Connecting to ${device?.id ?? 'device'}');
        break;
      case 'connected':
        _phase = 'connected / GATT ready';
        if (device != null) _setRoleState(device.id, event.role, 'connected');
        if (device != null) {
          _connectionWaiters.remove(_deviceKey(device.id))?.complete();
          if (_isRangeTarget(device.id)) _rangeSession?.recordConnected();
        }
        _log('Connected to ${device?.id ?? 'device'}');
        break;
      case 'disconnected':
        _phase = 'disconnected';
        if (device != null) {
          _setRoleState(device.id, event.role, 'disconnected');
          _assemblers.removeWhere(
            (key, _) => key.startsWith('${_deviceKey(device.id)}|'),
          );
          if (_isRangeTarget(device.id)) _rangeSession?.recordDisconnected();
        }
        if (device != null) {
          _connectionWaiters
              .remove(_deviceKey(device.id))
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
        if (_busyOperation == 'scan' || _phase == 'discovering') {
          _scanActive = false;
        }
        _phase = 'error';
        if (device != null) {
          _connectionWaiters
              .remove(_deviceKey(device.id))
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
    final normalizedDeviceId = _deviceKey(event.device?.id ?? 'unknown');
    final key = '$normalizedDeviceId|${event.role?.wireValue ?? 'central'}';
    final payload = event.payload;
    if (payload == null) {
      _log('Received data without a payload');
      return;
    }
    if (payload.length >= BleMessageCodec.headerBytes) {
      final index = (payload[10] << 8) | payload[11];
      final count = (payload[12] << 8) | payload[13];
      _log(
        'Frame received from ${event.device?.id ?? 'unknown'}: '
        '$index/$count (${payload.length} bytes)',
      );
    } else {
      _log(
        'Frame received from ${event.device?.id ?? 'unknown'}: '
        'invalid header (${payload.length} bytes)',
      );
    }
    final assembler = _assemblers.putIfAbsent(key, BleMessageAssembler.new);
    try {
      final message = assembler.accept(payload);
      if (message == null) return;
      final stamp = _time();
      final sender = event.device?.id ?? 'unknown sender';
      if (message.type == bleRangePingType) {
        final device = event.device;
        if (device == null) {
          _log('Range ping ignored because sender identity is unavailable');
          return;
        }
        unawaited(_sendRangeAcknowledgement(device, event.role, message));
        _log('Range ping ${message.id} received; sending application ACK');
        return;
      }
      if (message.type == bleRangeAckType) {
        final acknowledgedId = BleRangeDiagnosticMessage.acknowledgedMessageId(
          message,
        );
        final accepted =
            acknowledgedId != null &&
            _rangeSession?.recordAcknowledgement(
                  messageId: acknowledgedId,
                  sourcePeerId: sender,
                  receivedAt: DateTime.now().toUtc(),
                ) ==
                true;
        _log(
          accepted
              ? 'Application ACK received for $acknowledgedId'
              : 'Ignored unmatched, late, duplicate, or wrong-peer range ACK',
        );
        return;
      }
      _received.insert(
        0,
        '$stamp · $sender · ${message.payload['text'] ?? message.type}',
      );
      _log(
        'Assembly complete from $sender: id=${message.id}, '
        'type=${message.type}',
      );
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
    _readyFuture = _initialize(requestPermission: false);
    try {
      await _readyFuture;
    } catch (_) {
      // The diagnostic log contains the actionable native error.
    }
  });

  Future<void> _startScan() => _run('scan', () async {
    if (_scanActive) {
      _log('Scan already active; ignoring duplicate start request');
      return;
    }
    await _readyFuture;
    _assertActive();
    _scanSession++;
    _scanActive = true;
    _devices.clear();
    _lastSeen.clear();
    _states.clear();
    _selectedDeviceId = null;
    _log('Starting BLE scan session $_scanSession');
    try {
      await _presence.acquireDiscovery(_discoveryLease);
    } catch (_) {
      _scanActive = false;
      rethrow;
    }
  });

  Future<void> _stopScan() => _run('stop scan', () async {
    if (!_scanActive) {
      _log('Scan is not active; ignoring duplicate stop request');
      return;
    }
    await _readyFuture;
    _assertActive();
    _scanActive = false;
    await _presence.releaseDiscovery(_discoveryLease);
    _log('Scan stopped');
  });

  Future<void> _startAdvertising() => _run('advertising', () async {
    await _readyFuture;
    _assertActive();
    await _presence.acquireAdvertising(
      _advertisingLease,
      name: 'Emergency Test',
    );
    _log('Advertising start accepted by native transport');
  });

  Future<void> _stopAdvertising() => _run('stop advertising', () async {
    await _readyFuture;
    _assertActive();
    await _presence.releaseAdvertising(_advertisingLease);
    _log('Advertising stopped');
  });

  Future<void> _connect(BleDevice device) => _run('connect', () async {
    await _readyFuture;
    _assertActive();
    final key = _deviceKey(device.id);
    _selectedDeviceId = key;
    _setRoleState(device.id, BleSessionRole.central, 'connecting');
    _log('Connect requested for ${device.id}');
    final waiter = Completer<void>();
    _connectionWaiters.remove(key);
    _connectionWaiters[key] = waiter;
    try {
      await widget.transport.connect(device.id);
      await waiter.future.timeout(const Duration(seconds: 15));
    } finally {
      if (identical(_connectionWaiters[key], waiter)) {
        _connectionWaiters.remove(key);
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
        !_isPeerConnected(device.id)) {
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

  bool _isRangeTarget(String deviceId) {
    final session = _rangeSession;
    return session != null &&
        _deviceKey(session.targetPeerId) == _deviceKey(deviceId);
  }

  Future<void> _sendDiagnosticMessage(
    BleDevice device,
    BleMessage message, {
    BleSessionRole? role,
  }) async {
    final frames = BleMessageCodec.encode(
      message,
      maxFrameBytes: BleMessageCodec.transportSafeFrameBytes,
    );
    for (final frame in frames) {
      _assertActive();
      await widget.transport.send(device.id, frame, role: role);
    }
  }

  Future<void> _sendRangeAcknowledgement(
    BleDevice device,
    BleSessionRole? role,
    BleMessage ping,
  ) async {
    try {
      await _sendDiagnosticMessage(
        device,
        BleRangeDiagnosticMessage.acknowledgement(
          ping: ping,
          receivedAt: DateTime.now().toUtc(),
        ),
        role: role,
      );
    } catch (error) {
      _log('Range application ACK native write failed: $error');
    }
  }

  void _startRangeTest() {
    final device = _selectedDevice;
    if (_rangeSending || device == null || !_isPeerConnected(device.id)) {
      return;
    }
    _rangeTimer?.cancel();
    final now = DateTime.now().toUtc();
    _rangeSequence = 0;
    _rangeSession = BleRangeTestSession(
      runId: 'range-${now.microsecondsSinceEpoch}',
      targetPeerId: device.id,
      startedAt: now,
    );
    _rangeSending = true;
    _log(
      'Range run started: $_rangeDistance, $_rangeEnvironment, '
      '$_rangeDurationSeconds seconds. Distance is operator-recorded.',
    );
    unawaited(_sendRangePing());
    _rangeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = _rangeSession;
      if (session == null || _disposed) return;
      final tick = DateTime.now().toUtc();
      final snapshot = session.snapshot(tick);
      if (_rangeSending &&
          snapshot.elapsed >= Duration(seconds: _rangeDurationSeconds)) {
        _rangeSending = false;
        _log('Range send interval complete; waiting for outstanding ACKs');
      }
      session.expire(now: tick, timeout: _rangeAckTimeout);
      if (_rangeSending) {
        unawaited(_sendRangePing());
      } else if (session.snapshot(tick).pending == 0) {
        _rangeTimer?.cancel();
        _log('Range run complete');
      }
      if (mounted) setState(() {});
    });
    setState(() {});
  }

  void _stopRangeTest() {
    if (_rangeSession == null) return;
    _rangeSending = false;
    _log('Range sending stopped; outstanding ACKs keep their timeout window');
    setState(() {});
  }

  Future<void> _sendRangePing() async {
    final session = _rangeSession;
    final device = _selectedDevice;
    if (!_rangeSending ||
        _rangePingInFlight ||
        session == null ||
        device == null) {
      return;
    }
    _rangePingInFlight = true;
    final sentAt = DateTime.now().toUtc();
    final ping = BleRangeDiagnosticMessage.ping(
      runId: session.runId,
      sequence: _rangeSequence++,
      sentAt: sentAt,
    );
    session.recordAttempt(ping.id, sentAt);
    try {
      await _sendDiagnosticMessage(device, ping);
      _log('Range ${ping.id}: native write accepted; awaiting application ACK');
    } catch (error) {
      session.recordNativeFailure(ping.id);
      _log('Range ${ping.id}: native write failed: $error');
    } finally {
      _rangePingInFlight = false;
    }
    if (mounted) setState(() {});
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
    _rangeTimer?.cancel();
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
    unawaited(() async {
      await _presence.releaseDiscovery(_discoveryLease).catchError((_) {});
      await _presence.releaseAdvertising(_advertisingLease).catchError((_) {});
      if (widget.ownsTransport) await widget.transport.dispose();
    }());
    super.dispose();
  }

  void _assertActive() {
    if (_disposed || !mounted) {
      throw const BleTransportException('BLE test screen was disposed');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return Scaffold(
        body: Center(child: Text(context.l10n.developerToolUnavailable)),
      );
    }
    final selectedConnected =
        _selectedDevice != null && _isPeerConnected(_selectedDevice!.id);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.bleTestDebug)),
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
          _runtimeDiagnosticsButton(),
          const SizedBox(height: 12),
          _devicesCard(),
          const SizedBox(height: 12),
          _sendCard(selectedConnected),
          const SizedBox(height: 12),
          _rangeCard(selectedConnected),
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
    child: ListTile(
      leading: const Icon(Icons.bug_report_outlined, color: Color(0xFF9A5A00)),
      title: Text(
        context.l10n.debugToolOnly,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(context.l10n.debugToolSafety),
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
      title: Text(context.l10n.bluetoothStatus),
      subtitle: Text(
        'Central: $_centralState\nPeripheral: $_peripheralState\nPhase: $_phase',
      ),
      isThreeLine: true,
      trailing: FilledButton.tonal(
        onPressed: _busy ? null : _requestPermissions,
        child: Text(context.l10n.permissions),
      ),
    ),
  );

  Widget _capabilityCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Text(context.l10n.blePlatformCapabilities),
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
            label: Text(context.l10n.startScan),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _stopScan,
            icon: const Icon(Icons.stop),
            label: Text(context.l10n.stopScan),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _startAdvertising,
            icon: const Icon(Icons.cell_tower),
            label: Text(context.l10n.startAdvertising),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _stopAdvertising,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(context.l10n.stopAdvertising),
          ),
        ],
      ),
    ),
  );

  Widget _runtimeDiagnosticsButton() {
    final source = widget.runtimeDiagnostics;
    if (source == null || kReleaseMode) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.monitor_heart_outlined),
        label: const Text('Open Relay Diagnostics'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => RelayRuntimeDiagnosticsPage(dataSource: source),
          ),
        ),
      ),
    );
  }

  Widget _devicesCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.discoveredDevices,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (_devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(context.l10n.noDevicesDiscovered),
            ),
          for (final device in _devices.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                device.name?.isNotEmpty == true
                    ? device.name!
                    : context.l10n.unnamedDevice,
              ),
              subtitle: Text(
                '${device.id}${device.rssi == null ? '' : ' · RSSI ${device.rssi}'}\nState: ${_peerState(device.id)}',
              ),
              isThreeLine: true,
              trailing: _peerState(device.id).startsWith('connected')
                  ? OutlinedButton(
                      onPressed: _busy ? null : () => _disconnect(device),
                      child: Text(context.l10n.disconnect),
                    )
                  : FilledButton.tonal(
                      onPressed: _busy ? null : () => _connect(device),
                      child: Text(context.l10n.connect),
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
              decoration: InputDecoration(
                labelText: context.l10n.testMessage,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: enabled && !_busy ? _send : null,
            child: Text(context.l10n.send),
          ),
        ],
      ),
    ),
  );

  Widget _rangeCard(bool connected) {
    final session = _rangeSession;
    final snapshot = session?.snapshot(DateTime.now().toUtc());
    final device = _selectedDevice;
    String latency(Duration? value) =>
        value == null ? 'n/a' : '${value.inMilliseconds} ms';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.bleRangeDiagnostic,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(context.l10n.rangeDiagnosticSafety),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                DropdownButton<int>(
                  value: _rangeDurationSeconds,
                  items: const [30, 60, 120]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value s'),
                        ),
                      )
                      .toList(),
                  onChanged: _rangeSending
                      ? null
                      : (value) =>
                            setState(() => _rangeDurationSeconds = value ?? 30),
                ),
                DropdownButton<String>(
                  value: _rangeDistance,
                  items: const ['5 m', '10 m', '20 m', '30 m', '50 m']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _rangeSending
                      ? null
                      : (value) =>
                            setState(() => _rangeDistance = value ?? '5 m'),
                ),
                DropdownButton<String>(
                  value: _rangeEnvironment,
                  items: const ['Open space', 'Obstructed']
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _rangeSending
                      ? null
                      : (value) => setState(
                          () => _rangeEnvironment = value ?? 'Open space',
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ${device?.id ?? 'none'}\n'
              'RSSI: ${device?.rssi == null ? 'unavailable (transport exposes scan-time RSSI only)' : '${device!.rssi} dBm (last scan result)'}',
            ),
            if (snapshot != null) ...[
              const SizedBox(height: 8),
              Text(
                'Elapsed: ${snapshot.elapsed.inSeconds}s · State: ${snapshot.connectionState}\n'
                'Attempted ${snapshot.attempted} · Application ACK ${snapshot.acknowledged} · Native failed ${snapshot.nativeFailed} · Timed out ${snapshot.timedOut} · Pending ${snapshot.pending}\n'
                'PDR ${snapshot.packetDeliveryRate.toStringAsFixed(1)}% · ACK latency min/avg/p50/p95/max: '
                '${latency(snapshot.minimumLatency)} / ${latency(snapshot.averageLatency)} / ${latency(snapshot.medianLatency)} / ${latency(snapshot.p95Latency)} / ${latency(snapshot.maximumLatency)}\n'
                'Disconnects ${snapshot.disconnects} · Reconnects ${snapshot.reconnects}',
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: connected && !_rangeSending
                      ? _startRangeTest
                      : null,
                  icon: const Icon(Icons.network_check),
                  label: Text(context.l10n.startRangeRun),
                ),
                OutlinedButton(
                  onPressed: _rangeSending ? _stopRangeTest : null,
                  child: Text(context.l10n.stop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receivedCard() => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(context.l10n.receivedMessages(_received.length)),
      children: _received.isEmpty
          ? [ListTile(title: Text(context.l10n.noCompleteMessages))]
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
          Expanded(child: Text(context.l10n.diagnosticLog)),
          TextButton(
            onPressed: _logs.isEmpty ? null : () => setState(_logs.clear),
            child: Text(context.l10n.clear),
          ),
        ],
      ),
      children: [
        SizedBox(
          height: 180,
          child: _logs.isEmpty
              ? Center(child: Text(context.l10n.noDiagnostics))
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
