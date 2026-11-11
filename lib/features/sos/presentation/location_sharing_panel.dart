import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/localization.dart';
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

/// Location sharing controls for one active SOS. Once enabled, the panel
/// publishes a bounded foreground fix immediately and refreshes it every ten
/// seconds while the incident remains open. The OS/background lifecycle still
/// controls whether a platform can provide GPS and BLE work.
class LocationSharingPanel extends StatefulWidget {
  const LocationSharingPanel({
    super.key,
    required this.sos,
    required this.coordinator,
    required this.transport,
    this.participantRole = 'victim',
    this.automaticRefresh = false,
    this.locationLoader,
    this.now,
    this.onBleStartRequested,
  });

  final SosMessage sos;
  final SosBleCoordinator coordinator;
  final BleTransportClient transport;
  final String participantRole;
  final bool automaticRefresh;
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
  Timer? _autoPublishTimer;
  Future<void>? _pendingOperation;
  int _publishOperation = 0;
  _LocationPublishPhase _publishPhase = _LocationPublishPhase.idle;
  String? _currentPublishMessageId;
  int _locationSequence = 0;

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
    _autoPublishTimer?.cancel();
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
        setState(() => _error = context.l10n.selectRecipientToShare);
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
      if (widget.automaticRefresh) {
        _autoPublishTimer?.cancel();
        _autoPublishTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => unawaited(_publish()),
        );
      }
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
        throw _LocationUiException(context.l10n.currentLocationUnavailable);
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
      if (widget.automaticRefresh) {
        try {
          final live = await widget.coordinator.createLiveLocationEnvelope(
            sosId: widget.sos.id,
            participantId: widget.coordinator.ownerId,
            participantRole: widget.participantRole,
            sequence: ++_locationSequence,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyMeters: position.accuracy.isFinite && position.accuracy >= 0
                ? position.accuracy
                : null,
            createdAt: created,
            expiresAt: created.add(const Duration(minutes: 2)),
          );
          await widget.coordinator.enqueueLiveLocation(
            envelope: live,
            destinationId: recipient,
          );
        } on Object {
          // The legacy location receipt remains authoritative if the
          // installation signing key is temporarily unavailable.
        }
      }
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
    final l10n = context.l10n;
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw _LocationUiException(l10n.locationServicesDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw _LocationUiException(l10n.locationPermissionDenied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw _LocationUiException(l10n.locationPermissionDeniedForever);
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      throw _LocationUiException(l10n.locationTimedOut);
    }
  }

  Future<void> _stop() async {
    _publishOperation++;
    _autoPublishTimer?.cancel();
    _autoPublishTimer = null;
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
      : context.l10n.locationShareFailed;

  String _localizedDeliveryStatus(BleOutboxData? row) {
    final l10n = context.l10n;
    final state = row == null ? null : BleOutboxState.parse(row.state);
    return switch (state) {
      null || BleOutboxState.queued => l10n.statusQueued,
      BleOutboxState.sending => l10n.statusSending,
      BleOutboxState.writeAccepted ||
      BleOutboxState.awaitingAcknowledgement => l10n.statusAwaitingConfirmation,
      BleOutboxState.acknowledged => l10n.statusDelivered,
      BleOutboxState.failed =>
        row!.nextRetryAt == null
            ? l10n.statusFailedNoRetry
            : l10n.statusFailedRetryScheduled,
      BleOutboxState.expired => l10n.statusExpired,
    };
  }

  String _localizedTime(DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
          _LocationPublishPhase.idle =>
            _sharing ? l10n.readyToSend : l10n.locationOff,
          _LocationPublishPhase.preparing => l10n.gettingLocation,
          _LocationPublishPhase.enqueued => _localizedDeliveryStatus(
            currentDeliveryState,
          ),
          _LocationPublishPhase.failed => l10n.statusFailed,
        };
        final previousStateText =
            snapshot.data != null && !deliveryMatchesCurrent
            ? _localizedDeliveryStatus(snapshot.data)
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
                    Expanded(
                      child: Text(
                        l10n.foregroundLocationSharing,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Flexible(
                      child: Semantics(
                        container: true,
                        liveRegion: true,
                        excludeSemantics: true,
                        label: l10n.locationDeliverySemantics(stateText),
                        child: Text(stateText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _sharing
                      ? l10n.recipientLabel(
                          _recipientId ?? l10n.recipientNotSelected,
                        )
                      : l10n.locationOffDescription,
                ),
                if (_lastPublishedAt != null)
                  Text(l10n.lastUpdate(_localizedTime(_lastPublishedAt!))),
                if (previousStateText != null)
                  Text(l10n.previousDelivery(previousStateText)),
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
                        child: Text(_busy ? l10n.starting : l10n.startSharing),
                      )
                    else ...[
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _busy ? null : _publish,
                        child: Text(
                          _busy ? l10n.gettingLocation : l10n.sendLocation,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _stop,
                        child: Text(l10n.stopSharing),
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
