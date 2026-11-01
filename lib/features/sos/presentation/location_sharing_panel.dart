import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/database/app_database.dart';
import '../../nearby_ble/data/sos_ble_coordinator.dart';
import '../../nearby_ble/domain/ble_delivery_state.dart';
import '../../nearby_ble/presentation/ble_recipient_picker_page.dart';
import '../../nearby_ble/data/ble_transport.dart';
import '../data/sos_repository.dart';

typedef ForegroundLocationLoader = Future<Position?> Function();

enum _LocationPublishPhase { idle, preparing, enqueued, failed }

@visibleForTesting
String locationDeliveryStatusText(BleOutboxData? row) {
  final state = row == null ? null : BleOutboxState.parse(row.state);
  return switch (state) {
    null => 'Queued',
    BleOutboxState.queued => 'Queued',
    BleOutboxState.sending => 'Sending',
    BleOutboxState.writeAccepted ||
    BleOutboxState.awaitingAcknowledgement => 'Awaiting acknowledgement',
    BleOutboxState.acknowledged => 'Delivered',
    BleOutboxState.failed =>
      row!.nextRetryAt == null
          ? 'Failed; retry not scheduled'
          : 'Failed; retry scheduled',
    BleOutboxState.expired => 'Expired',
  };
}

/// Foreground-only location sharing controls for one active SOS.
class LocationSharingPanel extends StatefulWidget {
  const LocationSharingPanel({
    super.key,
    required this.sos,
    required this.coordinator,
    required this.transport,
    this.locationLoader,
    this.now,
    this.onBleStartRequested,
  });

  final SosMessage sos;
  final SosBleCoordinator coordinator;
  final BleTransportClient transport;
  final ForegroundLocationLoader? locationLoader;
  final DateTime Function()? now;
  final Future<void> Function()? onBleStartRequested;

  @override
  State<LocationSharingPanel> createState() => _LocationSharingPanelState();
}

class _LocationSharingPanelState extends State<LocationSharingPanel> {
  String? _recipientId;
  bool _sharing = false;
  bool _busy = false;
  String? _error;
  DateTime? _lastPublishedAt;
  Future<void>? _pendingOperation;
  int _publishOperation = 0;
  _LocationPublishPhase _publishPhase = _LocationPublishPhase.idle;
  String? _currentPublishMessageId;

  late Stream<BleOutboxData?> _delivery;

  @override
  void initState() {
    super.initState();
    _delivery = widget.coordinator.watchLocationDeliveryForSos(widget.sos.id);
  }

  @override
  void didUpdateWidget(covariant LocationSharingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.sos.id != widget.sos.id) {
      _publishOperation++;
      _publishPhase = _LocationPublishPhase.idle;
      _currentPublishMessageId = null;
      _delivery = widget.coordinator.watchLocationDeliveryForSos(widget.sos.id);
    }
  }

  DateTime get _now => (widget.now ?? DateTime.now).call().toUtc();

  @override
  void dispose() {
    _publishOperation++;
    if (_sharing) {
      unawaited(widget.coordinator.disableLocationSharing(widget.sos.id));
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy || _sharing) return;
    if (_pendingOperation != null) return _pendingOperation!;
    final operation = _startInternal();
    _pendingOperation = operation;
    try {
      await operation;
    } finally {
      if (identical(_pendingOperation, operation)) _pendingOperation = null;
    }
  }

  Future<void> _startInternal() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onBleStartRequested?.call();
      if (!mounted) return;
      final selected = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => BleRecipientPickerPage(transport: widget.transport),
        ),
      );
      if (!mounted) return;
      final recipient = selected?.trim();
      if (recipient == null || recipient.isEmpty) {
        setState(
          () => _error = 'Select a connected recipient to start sharing.',
        );
        return;
      }
      await widget.coordinator.enableLocationSharing(
        sosId: widget.sos.id,
        destinationId: recipient,
      );
      if (!mounted) return;
      setState(() {
        _recipientId = recipient;
        _sharing = true;
        _busy = false;
      });
      await _publish();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    if (_busy) return;
    final recipient = _recipientId;
    if (!_sharing || recipient == null || _busy) return;
    final operation = ++_publishOperation;
    setState(() {
      _busy = true;
      _error = null;
      _publishPhase = _LocationPublishPhase.preparing;
      _currentPublishMessageId = null;
    });
    try {
      final position = await (widget.locationLoader ?? _readLocation)();
      if (!mounted || !_sharing || operation != _publishOperation) return;
      if (position == null ||
          !isValidSosCoordinatePair(position.latitude, position.longitude)) {
        throw const _LocationUiException(
          'Current location is unavailable or invalid.',
        );
      }
      final created = _now;
      final messageId = 'location:${widget.sos.id}:$created';
      setState(() {
        _publishPhase = _LocationPublishPhase.enqueued;
        _currentPublishMessageId = messageId;
      });
      await widget.coordinator.publishLocationUpdate(
        sosId: widget.sos.id,
        messageId: messageId,
        destinationId: recipient,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy.isFinite && position.accuracy >= 0
            ? position.accuracy
            : null,
        createdAt: created,
        expiresAt: created.add(const Duration(minutes: 2)),
      );
      if (mounted && operation == _publishOperation) {
        setState(() => _lastPublishedAt = created);
      }
    } catch (error) {
      if (mounted && operation == _publishOperation) {
        setState(() {
          _error = _friendlyError(error);
          _publishPhase = _LocationPublishPhase.failed;
          _currentPublishMessageId = null;
        });
      }
    } finally {
      if (mounted && operation == _publishOperation) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Position?> _readLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _LocationUiException('Location Services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const _LocationUiException('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationUiException(
        'Location permission is permanently denied. Open Settings.',
      );
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      throw const _LocationUiException('Location request timed out.');
    }
  }

  Future<void> _stop() async {
    _publishOperation++;
    setState(() {
      _sharing = false;
      _recipientId = null;
      _error = null;
      _busy = false;
      _publishPhase = _LocationPublishPhase.idle;
      _currentPublishMessageId = null;
    });
    await widget.coordinator.disableLocationSharing(widget.sos.id);
  }

  String _friendlyError(Object error) =>
      error is _LocationUiException || error is BleDeliveryStateException
      ? error.toString().replaceFirst('BleDeliveryStateException: ', '')
      : 'Unable to share the current location. Try again.';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BleOutboxData?>(
      stream: _delivery,
      builder: (context, snapshot) {
        final deliveryMatchesCurrent =
            _currentPublishMessageId != null &&
            snapshot.data?.messageId == _currentPublishMessageId;
        final currentDeliveryState = deliveryMatchesCurrent
            ? snapshot.data
            : null;
        final stateText = switch (_publishPhase) {
          _LocationPublishPhase.idle => _sharing ? 'Ready to send' : 'Off',
          _LocationPublishPhase.preparing => 'Getting location…',
          _LocationPublishPhase.enqueued => locationDeliveryStatusText(
            currentDeliveryState,
          ),
          _LocationPublishPhase.failed => 'Failed',
        };
        final previousStateText =
            snapshot.data != null && !deliveryMatchesCurrent
            ? locationDeliveryStatusText(snapshot.data)
            : null;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.share_location_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Foreground location sharing',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Flexible(
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        label: 'Location delivery: $stateText',
                        child: Text(stateText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sharing
                      ? 'Recipient: ${_recipientId ?? 'not selected'}'
                      : 'Off. Choose a recipient before sharing.',
                ),
                if (_lastPublishedAt != null)
                  Text('Last update: ${_lastPublishedAt!.toLocal()}'),
                if (previousStateText != null)
                  Text('Previous delivery: $previousStateText'),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (!_sharing)
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _start,
                        child: Text(_busy ? 'Starting…' : 'Start sharing'),
                      )
                    else ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _publish,
                        child: Text(
                          _busy ? 'Getting location…' : 'Send location',
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _stop,
                        child: const Text('Stop sharing'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationUiException implements Exception {
  const _LocationUiException(this.message);
  final String message;
  @override
  String toString() => message;
}
