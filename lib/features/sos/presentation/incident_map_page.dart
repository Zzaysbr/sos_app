import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/database/app_database.dart';
import '../../nearby_ble/domain/location_ble_envelope.dart';
import 'map_tile_provider.dart';

typedef LocationLoader = Future<Position?> Function();

/// Displays the persisted incident location and, when authorized, the
/// current device location. Tile loading is online-only in this phase.
class IncidentMapPage extends StatefulWidget {
  const IncidentMapPage({
    super.key,
    required this.incident,
    this.locationLoader,
    this.incomingLocation,
    this.incomingSenderDeviceId,
    this.tileProvider,
  });

  final SosMessage incident;
  final LocationLoader? locationLoader;
  final LocationBleEnvelope? incomingLocation;
  final String? incomingSenderDeviceId;
  final MapTileProviderConfig? tileProvider;

  @override
  State<IncidentMapPage> createState() => _IncidentMapPageState();
}

class _IncidentMapPageState extends State<IncidentMapPage> {
  Position? _currentPosition;
  String? _locationError;
  bool _loadingLocation = false;
  bool _tileError = false;
  int _tileRetryToken = 0;

  MapTileProviderConfig get _tileProvider =>
      widget.tileProvider ?? MapTileProviderConfig.current;

  static const _minLatitude = -90.0;
  static const _maxLatitude = 90.0;
  static const _minLongitude = -180.0;
  static const _maxLongitude = 180.0;

  LatLng? get _incidentPoint {
    final latitude = widget.incident.latitude;
    final longitude = widget.incident.longitude;
    if (!_validCoordinate(latitude, longitude)) return null;
    return LatLng(latitude!, longitude!);
  }

  LatLng? get _incomingPoint {
    final location = widget.incomingLocation;
    if (location == null ||
        (widget.incomingSenderDeviceId != null &&
            location.senderDeviceId != widget.incomingSenderDeviceId)) {
      return null;
    }
    try {
      location.validate(now: DateTime.now().toUtc());
    } on Object {
      return null;
    }
    final latitude = location.latitude;
    final longitude = location.longitude;
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude, longitude);
  }

  bool get _incomingExpired {
    final location = widget.incomingLocation;
    if (location == null) return false;
    try {
      location.validate(now: DateTime.now().toUtc());
      return false;
    } on Object {
      return true;
    }
  }

  bool get _incidentCoordinatesProvided =>
      widget.incident.latitude != null || widget.incident.longitude != null;

  String? get _incidentCoordinateError {
    if (!_incidentCoordinatesProvided) return null;
    final latitude = widget.incident.latitude;
    final longitude = widget.incident.longitude;
    if (!_validCoordinate(latitude, longitude)) {
      return 'Incident coordinates are unavailable or invalid.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (_incidentPoint == null && _incomingPoint == null) {
      _loadCurrentLocation();
    }
  }

  Future<void> _loadCurrentLocation() async {
    if (_loadingLocation) return;
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      final position = widget.locationLoader != null
          ? await widget.locationLoader!()
          : await _readCurrentLocation();
      if (!mounted) return;
      if (position != null &&
          !_validCoordinate(position.latitude, position.longitude)) {
        throw const _LocationUnavailable('Current location is invalid.');
      }
      setState(() => _currentPosition = position);
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationError = _locationErrorText(error));
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<Position?> _readCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const _LocationUnavailable('Location Services are disabled.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw _LocationUnavailable(
        permission == LocationPermission.deniedForever
            ? 'Location permission is permanently denied. Open Settings.'
            : 'Location permission was denied.',
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
      throw const _LocationUnavailable('Location request timed out.');
    }
  }

  String _locationErrorText(Object error) {
    if (error is _LocationUnavailable) return error.message;
    if (error is TimeoutException) return 'Location request timed out.';
    return 'Unable to get the current location.';
  }

  Widget _attributionLink(String label, String url) => TextButton(
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: () async {
      try {
        await const MethodChannel('sos_app/external_links')
            .invokeMethod<void>('open', url);
      } on Object {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open attribution link.')),
        );
      }
    },
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final incidentPoint = _incidentPoint;
    final incomingPoint = _incomingPoint;
    final currentPoint = _currentPosition == null
        ? null
        : _validCoordinate(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          )
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : null;
    final center =
        incidentPoint ?? incomingPoint ?? currentPoint ?? const LatLng(0, 0);
    final markers = <Marker>[
      if (incidentPoint != null)
        Marker(
          point: incidentPoint,
          width: 56,
          height: 56,
          child: const Icon(Icons.location_on, color: Colors.red, size: 44),
        ),
      if (incomingPoint != null)
        Marker(
          point: incomingPoint,
          width: 56,
          height: 56,
          child: const Icon(
            Icons.share_location,
            color: Colors.deepPurple,
            size: 42,
          ),
        ),
      if (currentPoint != null)
        Marker(
          point: currentPoint,
          width: 52,
          height: 52,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 32),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Incident Map')),
      body: Column(
        children: [
          _statusPanel(
            context,
            incidentPoint: incidentPoint,
            incomingPoint: incomingPoint,
            currentPoint: currentPoint,
          ),
          Expanded(
            child:
                incidentPoint == null &&
                    incomingPoint == null &&
                    currentPoint == null
                ? _emptyMapState()
                : FlutterMap(
                    options: MapOptions(initialCenter: center, initialZoom: 15),
                    children: [
                      if (_tileProvider.isUsable)
                        TileLayer(
                          key: ValueKey(_tileRetryToken),
                          urlTemplate: _tileProvider.urlTemplate,
                          userAgentPackageName:
                              _tileProvider.userAgentPackageName,
                          errorTileCallback: (tile, error, stackTrace) {
                            if (mounted && !_tileError) {
                              setState(() => _tileError = true);
                            }
                          },
                        ),
                      MarkerLayer(markers: markers),
                      if (_tileProvider.attribution.trim().isNotEmpty)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: SafeArea(
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'flutter_map | ${_tileProvider.attribution}',
                                      textAlign: TextAlign.center,
                                    ),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _attributionLink(
                                          'OpenStreetMap copyright',
                                          'https://www.openstreetmap.org/copyright',
                                        ),
                                        if (Uri.tryParse(
                                              _tileProvider.urlTemplate,
                                            )?.host.endsWith('geoapify.com') ??
                                            false)
                                          _attributionLink(
                                            'Geoapify',
                                            'https://www.geoapify.com/',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadingLocation ? null : _loadCurrentLocation,
        tooltip: 'Refresh current location',
        child: _loadingLocation
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.my_location),
      ),
    );
  }

  Widget _statusPanel(
    BuildContext context, {
    required LatLng? incidentPoint,
    required LatLng? incomingPoint,
    required LatLng? currentPoint,
  }) {
    final theme = Theme.of(context);
    final incomingStatus = widget.incomingLocation == null
        ? null
        : incomingPoint != null
        ? 'Shared location available from the matched peer.'
        : _incomingExpired
        ? 'Shared location is expired and is not shown as current.'
        : 'Shared location is unavailable.';
    final status =
        _incidentCoordinateError ??
        (_locationError != null
            ? _locationError!
            : currentPoint == null
            ? 'Current location unavailable. Incident location remains available.'
            : _isStale
            ? 'Current location is stale. Refresh before relying on it.'
            : 'Current location available.');
    final coordinateText =
        _validCoordinate(widget.incident.latitude, widget.incident.longitude)
        ? 'Incident: ${widget.incident.latitude!.toStringAsFixed(6)}, '
              '${widget.incident.longitude!.toStringAsFixed(6)}'
        : 'Incident coordinates are not available.';
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(
              _locationError == null ? Icons.info_outline : Icons.warning,
              color: _locationError == null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status),
                  if (incomingStatus != null) ...[
                    const SizedBox(height: 2),
                    Text(incomingStatus, style: const TextStyle(fontSize: 12)),
                    if (incomingPoint != null)
                      Text(
                        'Shared: ${widget.incomingLocation!.latitude!.toStringAsFixed(6)}, '
                        '${widget.incomingLocation!.longitude!.toStringAsFixed(6)} · '
                        '${_formatLocationTime(widget.incomingLocation!.createdAt)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                  const SizedBox(height: 2),
                  const Text(
                    'Map tiles require internet; coordinates remain available offline.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(coordinateText, style: const TextStyle(fontSize: 12)),
                  if (_tileError) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _retryTiles,
                      child: const Text('Retry map tiles'),
                    ),
                  ],
                  if (!_tileProvider.isUsable)
                    Text(
                      _tileProvider.validationError ??
                          'Map provider is unavailable for this build.',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  if (_tileProvider.isDevelopmentFallback &&
                      _tileProvider.isUsable)
                    const Text(
                      'Development tile provider; configure MAP_TILE_URL for production.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (incidentPoint != null)
              const Tooltip(
                message:
                    'Red: incident · Purple: shared · Blue: current device',
                child: Icon(Icons.legend_toggle_outlined),
              ),
          ],
        ),
      ),
    );
  }

  String _formatLocationTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  bool get _isStale {
    final timestamp = _currentPosition?.timestamp;
    return timestamp == null ||
        DateTime.now().difference(timestamp).abs() > const Duration(minutes: 5);
  }

  Widget _emptyMapState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56),
            const SizedBox(height: 12),
            Text(
              _incidentCoordinateError ??
                  'No location is available for this incident.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  void _retryTiles() {
    if (!mounted) return;
    setState(() {
      _tileError = false;
      _tileRetryToken++;
    });
  }

  static bool _validCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= _minLatitude &&
        latitude <= _maxLatitude &&
        longitude >= _minLongitude &&
        longitude <= _maxLongitude;
  }
}

class _LocationUnavailable implements Exception {
  const _LocationUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}
