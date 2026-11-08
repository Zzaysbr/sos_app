import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/localization.dart';
import '../../../core/database/app_database.dart';
import '../../nearby_ble/domain/location_ble_envelope.dart';
import '../data/offline_map_repository.dart';
import 'map_tile_provider.dart';
import 'offline_first_tile_provider.dart';

typedef LocationLoader = Future<Position?> Function();

/// Displays persisted incident/shared/current locations over an online map,
/// preferring explicitly downloaded tiles when they are available.
class IncidentMapPage extends StatefulWidget {
  const IncidentMapPage({
    super.key,
    required this.incident,
    this.locationLoader,
    this.incomingLocation,
    this.incomingSenderDeviceId,
    this.rescueCandidate,
    this.tileProvider,
    this.offlineMapRepository,
  });

  final SosMessage incident;
  final LocationLoader? locationLoader;
  final LocationBleEnvelope? incomingLocation;
  final String? incomingSenderDeviceId;
  final RescueInboxData? rescueCandidate;
  final MapTileProviderConfig? tileProvider;
  final OfflineMapRepository? offlineMapRepository;

  @override
  State<IncidentMapPage> createState() => _IncidentMapPageState();
}

class _IncidentMapPageState extends State<IncidentMapPage> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  String? _locationError;
  bool _loadingLocation = false;
  bool _tileError = false;
  int _tileRetryToken = 0;
  OfflineMapRepository? _offlineRepository;
  OfflineFirstTileProvider? _offlineTileProvider;
  bool _offlineInitializationComplete = false;
  List<OfflineMapRegion> _offlineRegions = const [];
  bool _offlineStorageUnavailable = false;
  OfflineMapProgress? _downloadProgress;
  OfflineMapCancellation? _downloadCancellation;

  MapTileProviderConfig get _tileProvider =>
      widget.tileProvider ?? MapTileProviderConfig.current;

  static const _minLatitude = -90.0;
  static const _maxLatitude = 90.0;
  static const _minLongitude = -180.0;
  static const _maxLongitude = 180.0;

  LatLng? get _incidentPoint {
    final latitude =
        widget.rescueCandidate?.latitude ?? widget.incident.latitude;
    final longitude =
        widget.rescueCandidate?.longitude ?? widget.incident.longitude;
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
      (widget.rescueCandidate?.latitude != null ||
          widget.rescueCandidate?.longitude != null) ||
      widget.incident.latitude != null ||
      widget.incident.longitude != null;

  String? get _incidentCoordinateError {
    if (!_incidentCoordinatesProvided) return null;
    final latitude =
        widget.rescueCandidate?.latitude ?? widget.incident.latitude;
    final longitude =
        widget.rescueCandidate?.longitude ?? widget.incident.longitude;
    if (!_validCoordinate(latitude, longitude)) {
      return context.l10n.incidentCoordinatesInvalid;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _offlineTileProvider = OfflineFirstTileProvider(
      repositoryProvider: () => _offlineRepository,
      providerKey: _tileProvider.offlineStorageKey,
    );
    unawaited(_initializeOfflineMaps());
    if (_incidentPoint == null && _incomingPoint == null) {
      _loadCurrentLocation();
    }
  }

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    unawaited(_offlineTileProvider?.dispose() ?? Future<void>.value());
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeOfflineMaps() async {
    try {
      final repository =
          widget.offlineMapRepository ??
          await OfflineMapRepository.createDefault();
      await repository.initialize();
      if (!mounted) return;
      setState(() {
        _offlineRepository = repository;
        _offlineRegions = repository.regions;
        _offlineInitializationComplete = true;
        _offlineStorageUnavailable = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _offlineInitializationComplete = true;
        _offlineStorageUnavailable = true;
      });
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
        throw const _LocationUnavailable(_LocationFailure.invalid);
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
      throw const _LocationUnavailable(_LocationFailure.servicesDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw _LocationUnavailable(
        permission == LocationPermission.deniedForever
            ? _LocationFailure.permissionDeniedForever
            : _LocationFailure.permissionDenied,
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
      throw const _LocationUnavailable(_LocationFailure.timedOut);
    }
  }

  String _locationErrorText(Object error) {
    if (error is _LocationUnavailable) {
      return switch (error.reason) {
        _LocationFailure.invalid => context.l10n.currentLocationUnavailable,
        _LocationFailure.servicesDisabled =>
          context.l10n.locationServicesDisabled,
        _LocationFailure.permissionDenied =>
          context.l10n.locationPermissionDenied,
        _LocationFailure.permissionDeniedForever =>
          context.l10n.locationPermissionDeniedForever,
        _LocationFailure.timedOut => context.l10n.locationTimedOut,
      };
    }
    if (error is TimeoutException) return context.l10n.locationTimedOut;
    return context.l10n.currentLocationUnavailable;
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
          SnackBar(content: Text(context.l10n.unableOpenAttribution)),
        );
      }
    },
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
      appBar: AppBar(
        title: Text(l10n.incidentMap),
        actions: [
          IconButton(
            onPressed:
                _offlineRepository == null ||
                    _downloadProgress != null ||
                    !_tileProvider.supportsOfflineRegionDownloads
                ? null
                : _showDownloadDialog,
            tooltip: _tileProvider.supportsOfflineRegionDownloads
                ? l10n.downloadVisibleArea
                : l10n.offlineDownloadRequiresProvider,
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            onPressed: _offlineRepository == null ? null : _showManageRegions,
            tooltip: l10n.manageOfflineMaps,
            icon: const Icon(Icons.offline_pin_outlined),
          ),
        ],
      ),
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
                    mapController: _mapController,
                    options: MapOptions(initialCenter: center, initialZoom: 15),
                    children: [
                      if (_tileProvider.isUsable)
                        TileLayer(
                          key: ValueKey(_tileRetryToken),
                          urlTemplate: _tileProvider.urlTemplate,
                          userAgentPackageName:
                              _tileProvider.userAgentPackageName,
                          tileProvider: _offlineTileProvider,
                          errorTileCallback: (tile, error, stackTrace) {
                            if (mounted && !_tileError) {
                              setState(() => _tileError = true);
                            }
                          },
                        ),
                      MarkerLayer(markers: markers),
                      Align(
                        alignment: Alignment.topRight,
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _changeZoom(1),
                                    tooltip: l10n.zoomIn,
                                    icon: const Icon(Icons.add),
                                  ),
                                  IconButton(
                                    onPressed: () => _changeZoom(-1),
                                    tooltip: l10n.zoomOut,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  IconButton(
                                    onPressed: currentPoint == null
                                        ? null
                                        : () => _mapController.move(
                                            currentPoint,
                                            _mapController.camera.zoom,
                                          ),
                                    tooltip: l10n.centerCurrentLocation,
                                    icon: const Icon(Icons.gps_fixed),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
        tooltip: l10n.refreshCurrentLocation,
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
    final l10n = context.l10n;
    final incomingStatus = widget.incomingLocation == null
        ? null
        : incomingPoint != null
        ? l10n.sharedLocationAvailable
        : _incomingExpired
        ? l10n.sharedLocationExpired
        : l10n.sharedLocationUnavailable;
    final status =
        _incidentCoordinateError ??
        (_locationError != null
            ? _locationError!
            : currentPoint == null
            ? l10n.currentLocationIncidentAvailable
            : _isStale
            ? l10n.currentLocationStale
            : l10n.currentLocationAvailable);
    final coordinateText =
        _validCoordinate(
          widget.rescueCandidate?.latitude ?? widget.incident.latitude,
          widget.rescueCandidate?.longitude ?? widget.incident.longitude,
        )
        ? l10n.incidentCoordinates(
            (widget.rescueCandidate?.latitude ?? widget.incident.latitude)!
                .toStringAsFixed(6),
            (widget.rescueCandidate?.longitude ?? widget.incident.longitude)!
                .toStringAsFixed(6),
          )
        : l10n.incidentCoordinatesUnavailable;
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
                        l10n.sharedCoordinates(
                          widget.incomingLocation!.latitude!.toStringAsFixed(6),
                          widget.incomingLocation!.longitude!.toStringAsFixed(
                            6,
                          ),
                          _formatLocationTime(
                            widget.incomingLocation!.createdAt,
                          ),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    _offlineRegions.any(
                          (region) =>
                              region.providerKey ==
                              _tileProvider.offlineStorageKey,
                        )
                        ? l10n.downloadedTilesAvailable
                        : l10n.mapTilesRequireInternet,
                    style: TextStyle(fontSize: 12),
                  ),
                  if (_offlineStorageUnavailable) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.offlineMapStorageUnavailable,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  if (!_offlineInitializationComplete)
                    Text(
                      l10n.preparingMapStorage,
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (_downloadProgress case final progress?) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress.fraction),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.downloadingTiles(
                              progress.completed,
                              progress.total,
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: _downloadCancellation?.cancel,
                          child: Text(l10n.cancel),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(coordinateText, style: const TextStyle(fontSize: 12)),
                  if (_tileError) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _retryTiles,
                      child: Text(l10n.retryMapTiles),
                    ),
                  ],
                  if (!_tileProvider.isUsable)
                    Text(
                      _localizedProviderError(_tileProvider.validationIssue),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  if (_tileProvider.isDevelopmentFallback &&
                      _tileProvider.isUsable)
                    Text(
                      l10n.developmentTileProvider,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
            if (incidentPoint != null)
              Tooltip(
                message: l10n.mapLegend,
                child: Icon(Icons.legend_toggle_outlined),
              ),
          ],
        ),
      ),
    );
  }

  String _localizedProviderError(MapTileProviderValidationIssue? issue) {
    final l10n = context.l10n;
    return switch (issue) {
      MapTileProviderValidationIssue.productionProviderMissing =>
        l10n.mapConfigProductionProviderMissing,
      MapTileProviderValidationIssue.urlMissing => l10n.mapConfigUrlMissing,
      MapTileProviderValidationIssue.urlInvalid => l10n.mapConfigUrlInvalid,
      MapTileProviderValidationIssue.publicOsmInRelease =>
        l10n.mapConfigPublicOsmBlocked,
      MapTileProviderValidationIssue.geoapifyKeyMissing =>
        l10n.mapConfigGeoapifyKeyMissing,
      MapTileProviderValidationIssue.geoapifyKeyMalformed =>
        l10n.mapConfigTemplateInvalid,
      MapTileProviderValidationIssue.templatePlaceholdersMissing =>
        l10n.mapConfigTemplateInvalid,
      MapTileProviderValidationIssue.attributionMissing =>
        l10n.mapConfigAttributionMissing,
      MapTileProviderValidationIssue.geoapifyAttributionIncomplete =>
        l10n.mapConfigGeoapifyAttributionIncomplete,
      MapTileProviderValidationIssue.userAgentMissing =>
        l10n.mapConfigUserAgentMissing,
      null => l10n.mapProviderUnavailable,
    };
  }

  String _formatLocationTime(DateTime value) {
    final local = value.toLocal();
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(local));
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
              _incidentCoordinateError ?? context.l10n.noIncidentLocation,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.tryAgain),
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
      _replaceTileProvider();
    });
  }

  void _replaceTileProvider() {
    if (!_tileProvider.isUsable) {
      unawaited(_offlineTileProvider?.dispose() ?? Future<void>.value());
    }
    _offlineTileProvider = OfflineFirstTileProvider(
      repositoryProvider: () => _offlineRepository,
      providerKey: _tileProvider.offlineStorageKey,
    );
    _tileRetryToken++;
  }

  void _changeZoom(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(1, 19));
  }

  Future<void> _showDownloadDialog() async {
    final repository = _offlineRepository;
    if (repository == null || !_tileProvider.supportsOfflineRegionDownloads) {
      return;
    }
    final camera = _mapController.camera;
    final visible = camera.visibleBounds;
    final bounds = OfflineMapBounds(
      north: visible.north.clamp(-85.05112878, 85.05112878),
      south: visible.south.clamp(-85.05112878, 85.05112878),
      east: visible.east.clamp(-180, 180),
      west: visible.west.clamp(-180, 180),
    );
    final minZoom = camera.zoom.floor().clamp(1, OfflineMapRepository.maxZoom);
    final maxZoom = (minZoom + 1).clamp(1, OfflineMapRepository.maxZoom);
    final selection = await showDialog<_OfflineDownloadSelection>(
      context: context,
      builder: (_) => _OfflineMapDownloadDialog(
        repository: repository,
        bounds: bounds,
        initialMinZoom: minZoom,
        initialMaxZoom: maxZoom,
        initialName: context.l10n.offlineMapDefaultName(
          MaterialLocalizations.of(context).formatCompactDate(DateTime.now()),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    await _downloadRegion(
      OfflineMapDownloadRequest(
        name: selection.name,
        providerKey: _tileProvider.offlineStorageKey,
        urlTemplate: _tileProvider.urlTemplate,
        userAgent: _tileProvider.userAgentPackageName,
        bounds: bounds,
        minZoom: selection.minZoom,
        maxZoom: selection.maxZoom,
      ),
    );
  }

  Future<void> _downloadRegion(OfflineMapDownloadRequest request) async {
    final repository = _offlineRepository;
    if (repository == null) return;
    final cancellation = OfflineMapCancellation();
    setState(() {
      _downloadCancellation = cancellation;
      _downloadProgress = const OfflineMapProgress(completed: 0, total: 1);
    });
    try {
      final region = await repository.downloadRegion(
        request,
        cancellation: cancellation,
        onProgress: (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _offlineRegions = repository.regions;
        _replaceTileProvider();
        _tileError = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.offlineRegionAvailable(region.name)),
        ),
      );
    } on OfflineMapCancelled {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.offlineDownloadCancelled)),
        );
      }
    } on OfflineMapException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.offlineMapDownloadFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadCancellation = null;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _showManageRegions() async {
    final repository = _offlineRepository;
    if (repository == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final regions = repository.regions;
          return AlertDialog(
            title: Text(context.l10n.offlineMaps),
            content: SizedBox(
              width: 420,
              child: regions.isEmpty
                  ? Text(context.l10n.noDownloadedRegions)
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: regions.length,
                      itemBuilder: (context, index) {
                        final region = regions[index];
                        return ListTile(
                          title: Text(region.name),
                          subtitle: Text(
                            context.l10n.offlineRegionSummary(
                              region.tileCount,
                              _formatBytes(region.sizeBytes),
                              region.minZoom,
                              region.maxZoom,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: context.l10n.deleteNamedItem(region.name),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await repository.deleteRegion(region.id);
                                if (!mounted) return;
                                setState(() {
                                  _offlineRegions = repository.regions;
                                  _replaceTileProvider();
                                });
                                setDialogState(() {});
                              } on OfflineMapException {
                                if (!mounted) return;
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      this
                                          .context
                                          .l10n
                                          .offlineMapDownloadFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              Text(
                context.l10n.offlineMapStorageSummary(
                  _formatBytes(repository.storageBytes),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
  const _LocationUnavailable(this.reason);

  final _LocationFailure reason;

  @override
  String toString() => reason.name;
}

enum _LocationFailure {
  invalid,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
}

class _OfflineDownloadSelection {
  const _OfflineDownloadSelection(this.name, this.minZoom, this.maxZoom);
  final String name;
  final int minZoom;
  final int maxZoom;
}

/// Own the controller until the dialog route finishes its reverse transition.
/// showDialog's future completes on pop, before its TextField is unmounted.
class _OfflineMapDownloadDialog extends StatefulWidget {
  const _OfflineMapDownloadDialog({
    required this.repository,
    required this.bounds,
    required this.initialName,
    required this.initialMinZoom,
    required this.initialMaxZoom,
  });
  final OfflineMapRepository repository;
  final OfflineMapBounds bounds;
  final String initialName;
  final int initialMinZoom;
  final int initialMaxZoom;
  @override
  State<_OfflineMapDownloadDialog> createState() =>
      _OfflineMapDownloadDialogState();
}

class _OfflineMapDownloadDialogState extends State<_OfflineMapDownloadDialog> {
  late final TextEditingController _nameController;
  late int _minZoom;
  late int _maxZoom;
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _minZoom = widget.initialMinZoom;
    _maxZoom = widget.initialMaxZoom;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int tileCount;
    try {
      tileCount = widget.repository.estimateTileCount(
        widget.bounds,
        _minZoom,
        _maxZoom,
      );
    } on Object {
      tileCount = OfflineMapRepository.maxTilesPerRegion + 1;
    }
    final estimatedMb =
        tileCount * OfflineMapRepository.estimatedBytesPerTile / (1024 * 1024);
    final tooLarge = tileCount > OfflineMapRepository.maxTilesPerRegion;
    return AlertDialog(
      title: Text(context.l10n.downloadVisibleArea),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.l10n.mapName),
            ),
            Text(context.l10n.minimumZoom(_minZoom)),
            Slider(
              value: _minZoom.toDouble(),
              min: 1,
              max: OfflineMapRepository.maxZoom.toDouble(),
              divisions: OfflineMapRepository.maxZoom - 1,
              onChanged: (value) => setState(() {
                _minZoom = value.round();
                if (_maxZoom < _minZoom) _maxZoom = _minZoom;
              }),
            ),
            Text(context.l10n.maximumZoom(_maxZoom)),
            Slider(
              value: _maxZoom.toDouble(),
              min: 1,
              max: OfflineMapRepository.maxZoom.toDouble(),
              divisions: OfflineMapRepository.maxZoom - 1,
              onChanged: (value) => setState(() {
                _maxZoom = value.round();
                if (_minZoom > _maxZoom) _minZoom = _maxZoom;
              }),
            ),
            Text(
              context.l10n.offlineTileEstimate(
                tileCount,
                estimatedMb.toStringAsFixed(1),
              ),
            ),
            if (tooLarge)
              Text(
                context.l10n.offlineMapTooLarge(
                  OfflineMapRepository.maxTilesPerRegion,
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            Text(context.l10n.offlineMapDownloadInfo),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: tooLarge || _nameController.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _OfflineDownloadSelection(
                    _nameController.text,
                    _minZoom,
                    _maxZoom,
                  ),
                ),
          child: Text(context.l10n.download),
        ),
      ],
    );
  }
}
