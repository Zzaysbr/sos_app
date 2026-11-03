import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

typedef OfflineTileFetcher = Future<Uint8List> Function(
  Uri uri,
  Map<String, String> headers,
  Duration timeout,
);

@immutable
class OfflineMapBounds {
  const OfflineMapBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  Map<String, Object> toJson() => {
    'north': north,
    'south': south,
    'east': east,
    'west': west,
  };

  factory OfflineMapBounds.fromJson(Map<String, Object?> json) =>
      OfflineMapBounds(
        north: (json['north'] as num).toDouble(),
        south: (json['south'] as num).toDouble(),
        east: (json['east'] as num).toDouble(),
        west: (json['west'] as num).toDouble(),
      );
}

@immutable
class OfflineMapRegion {
  const OfflineMapRegion({
    required this.id,
    required this.name,
    required this.providerKey,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.sizeBytes,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String providerKey;
  final OfflineMapBounds bounds;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final int sizeBytes;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'version': 1,
    'id': id,
    'name': name,
    'providerKey': providerKey,
    'bounds': bounds.toJson(),
    'minZoom': minZoom,
    'maxZoom': maxZoom,
    'tileCount': tileCount,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory OfflineMapRegion.fromJson(Map<String, Object?> json) =>
      OfflineMapRegion(
        id: json['id']! as String,
        name: json['name']! as String,
        providerKey: json['providerKey']! as String,
        bounds: OfflineMapBounds.fromJson(
          (json['bounds']! as Map).cast<String, Object?>(),
        ),
        minZoom: json['minZoom']! as int,
        maxZoom: json['maxZoom']! as int,
        tileCount: json['tileCount']! as int,
        sizeBytes: json['sizeBytes']! as int,
        createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
      );
}

@immutable
class OfflineMapDownloadRequest {
  const OfflineMapDownloadRequest({
    required this.name,
    required this.providerKey,
    required this.urlTemplate,
    required this.userAgent,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
  });

  final String name;
  final String providerKey;
  final String urlTemplate;
  final String userAgent;
  final OfflineMapBounds bounds;
  final int minZoom;
  final int maxZoom;
}

@immutable
class OfflineMapProgress {
  const OfflineMapProgress({required this.completed, required this.total});

  final int completed;
  final int total;
  double get fraction => total == 0 ? 0 : completed / total;
}

class OfflineMapCancellation {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class OfflineMapException implements Exception {
  const OfflineMapException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OfflineMapCancelled extends OfflineMapException {
  const OfflineMapCancelled() : super('Map download was cancelled.');
}

class OfflineMapRepository {
  OfflineMapRepository({
    required Directory rootDirectory,
    OfflineTileFetcher? fetcher,
    this.requestDelay = const Duration(milliseconds: 220),
  }) : _root = rootDirectory,
       _fetcher = fetcher ?? _fetchTile;

  static const maxTilesPerRegion = 400;
  static const maxZoom = 16;
  static const minZoom = 1;
  static const maxTileBytes = 2 * 1024 * 1024;
  static const maxRegionBytes = 80 * 1024 * 1024;
  static const maxTotalStorageBytes = 250 * 1024 * 1024;
  static const requestTimeout = Duration(seconds: 15);
  static const estimatedBytesPerTile = 35 * 1024;

  final Directory _root;
  final OfflineTileFetcher _fetcher;
  final Duration requestDelay;
  final List<OfflineMapRegion> _regions = [];

  List<OfflineMapRegion> get regions => List.unmodifiable(_regions);
  int get storageBytes => _regions.fold(0, (sum, item) => sum + item.sizeBytes);

  static Future<OfflineMapRepository> createDefault() async {
    final support = await getApplicationSupportDirectory();
    return OfflineMapRepository(
      rootDirectory: Directory('${support.path}/offline_map_regions'),
    );
  }

  Future<void> initialize() async {
    await _root.create(recursive: true);
    _regions.clear();
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final leaf = entity.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (leaf.startsWith('.partial-')) {
        await entity.delete(recursive: true);
        continue;
      }
      final manifest = File('${entity.path}/manifest.json');
      if (!await manifest.exists()) continue;
      try {
        final json = jsonDecode(await manifest.readAsString());
        final region = OfflineMapRegion.fromJson(
          (json as Map).cast<String, Object?>(),
        );
        if (region.id != leaf || !RegExp(r'^region-[0-9]+$').hasMatch(leaf)) {
          continue;
        }
        _regions.add(region);
      } on Object {
        // An invalid/incomplete directory is never treated as an offline map.
      }
    }
    _regions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int estimateTileCount(OfflineMapBounds bounds, int minZoom, int maxZoom) {
    _validateBoundsAndZoom(bounds, minZoom, maxZoom);
    var count = 0;
    for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
      count += _tilesAtZoom(bounds, zoom).length;
    }
    return count;
  }

  int estimateSizeBytes(OfflineMapBounds bounds, int minZoom, int maxZoom) =>
      estimateTileCount(bounds, minZoom, maxZoom) * estimatedBytesPerTile;

  Future<OfflineMapRegion> downloadRegion(
    OfflineMapDownloadRequest request, {
    required OfflineMapCancellation cancellation,
    ValueChanged<OfflineMapProgress>? onProgress,
  }) async {
    _validateRequest(request);
    final tiles = <_TileCoordinate>[];
    for (var zoom = request.minZoom; zoom <= request.maxZoom; zoom++) {
      tiles.addAll(_tilesAtZoom(request.bounds, zoom));
    }
    if (tiles.length > maxTilesPerRegion) {
      throw OfflineMapException(
        'This area needs ${tiles.length} tiles; the limit is $maxTilesPerRegion.',
      );
    }
    final estimatedBytes = tiles.length * estimatedBytesPerTile;
    if (storageBytes + estimatedBytes > maxTotalStorageBytes) {
      throw const OfflineMapException(
        'Offline maps have reached the device storage safety limit.',
      );
    }

    final id = 'region-${DateTime.now().toUtc().microsecondsSinceEpoch}';
    final staging = Directory('${_root.path}/.partial-$id');
    final complete = Directory('${_root.path}/$id');
    var bytesWritten = 0;
    await _root.create(recursive: true);
    await staging.create(recursive: true);
    try {
      onProgress?.call(OfflineMapProgress(completed: 0, total: tiles.length));
      for (var index = 0; index < tiles.length; index++) {
        if (cancellation.isCancelled) throw const OfflineMapCancelled();
        final tile = tiles[index];
        final uri = Uri.parse(
          request.urlTemplate
              .replaceAll('{z}', '${tile.z}')
              .replaceAll('{x}', '${tile.x}')
              .replaceAll('{y}', '${tile.y}'),
        );
        final bytes = await _fetcher(uri, {
          'User-Agent': request.userAgent,
        }, requestTimeout);
        if (bytes.isEmpty || bytes.length > maxTileBytes) {
          throw const OfflineMapException('A map tile response was invalid.');
        }
        bytesWritten += bytes.length;
        if (bytesWritten > maxRegionBytes ||
            storageBytes + bytesWritten > maxTotalStorageBytes) {
          throw const OfflineMapException(
            'The map region exceeded the storage safety limit.',
          );
        }
        final file = File('${staging.path}/${tile.z}/${tile.x}/${tile.y}.tile');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        onProgress?.call(
          OfflineMapProgress(completed: index + 1, total: tiles.length),
        );
        if (index + 1 < tiles.length && requestDelay > Duration.zero) {
          await Future<void>.delayed(requestDelay);
        }
      }
      if (cancellation.isCancelled) throw const OfflineMapCancelled();
      final region = OfflineMapRegion(
        id: id,
        name: request.name.trim(),
        providerKey: request.providerKey,
        bounds: request.bounds,
        minZoom: request.minZoom,
        maxZoom: request.maxZoom,
        tileCount: tiles.length,
        sizeBytes: bytesWritten,
        createdAt: DateTime.now().toUtc(),
      );
      await File('${staging.path}/manifest.json')
          .writeAsString(jsonEncode(region.toJson()), flush: true);
      await staging.rename(complete.path);
      _regions.insert(0, region);
      return region;
    } on FileSystemException {
      throw const OfflineMapException(
        'Unable to store the offline map. Check available device storage.',
      );
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  File? tileFile(String providerKey, int z, int x, int y) {
    for (final region in _regions) {
      if (region.providerKey != providerKey ||
          z < region.minZoom ||
          z > region.maxZoom) {
        continue;
      }
      final file = File('${_root.path}/${region.id}/$z/$x/$y.tile');
      if (file.existsSync()) return file;
    }
    return null;
  }

  Future<void> deleteRegion(String id) async {
    final index = _regions.indexWhere((item) => item.id == id);
    if (index == -1) return;
    try {
      final directory = Directory('${_root.path}/$id');
      if (await directory.exists()) await directory.delete(recursive: true);
      _regions.removeAt(index);
    } on FileSystemException {
      throw const OfflineMapException('Unable to delete the offline map.');
    }
  }

  void _validateRequest(OfflineMapDownloadRequest request) {
    _validateBoundsAndZoom(request.bounds, request.minZoom, request.maxZoom);
    if (request.name.trim().isEmpty || request.name.trim().length > 60) {
      throw const OfflineMapException('Enter a map name up to 60 characters.');
    }
    final uri = Uri.tryParse(request.urlTemplate);
    if (request.providerKey.trim().isEmpty ||
        request.userAgent.trim().isEmpty ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'maps.geoapify.com' ||
        (uri.queryParameters['apiKey']?.trim().isEmpty ?? true) ||
        !request.urlTemplate.contains('{z}') ||
        !request.urlTemplate.contains('{x}') ||
        !request.urlTemplate.contains('{y}')) {
      throw const OfflineMapException('The offline map provider is invalid.');
    }
  }

  void _validateBoundsAndZoom(
    OfflineMapBounds bounds,
    int minZoomValue,
    int maxZoomValue,
  ) {
    final values = [bounds.north, bounds.south, bounds.east, bounds.west];
    if (values.any((value) => !value.isFinite) ||
        bounds.north <= bounds.south ||
        bounds.north > 85.05112878 ||
        bounds.south < -85.05112878 ||
        bounds.east < -180 ||
        bounds.east > 180 ||
        bounds.west < -180 ||
        bounds.west > 180) {
      throw const OfflineMapException('The selected map area is invalid.');
    }
    if (minZoomValue < minZoom ||
        maxZoomValue > maxZoom ||
        minZoomValue > maxZoomValue) {
      throw OfflineMapException(
        'Choose zoom levels from $minZoom to $maxZoom.',
      );
    }
  }

  List<_TileCoordinate> _tilesAtZoom(OfflineMapBounds bounds, int zoom) {
    final n = 1 << zoom;
    final northY = _latitudeToTileY(bounds.north, zoom);
    final southY = _latitudeToTileY(bounds.south, zoom);
    final ranges = bounds.west <= bounds.east
        ? [
            (
              start: _longitudeToTileX(bounds.west, zoom),
              end: _longitudeToTileX(bounds.east, zoom),
            ),
          ]
        : [
            (start: _longitudeToTileX(bounds.west, zoom), end: n - 1),
            (start: 0, end: _longitudeToTileX(bounds.east, zoom)),
          ];
    final result = <_TileCoordinate>[];
    for (final range in ranges) {
      for (var x = range.start; x <= range.end; x++) {
        for (var y = northY; y <= southY; y++) {
          result.add(_TileCoordinate(z: zoom, x: x, y: y));
        }
      }
    }
    return result;
  }

  int _longitudeToTileX(double longitude, int zoom) {
    final n = 1 << zoom;
    return (((longitude + 180) / 360) * n).floor().clamp(0, n - 1);
  }

  int _latitudeToTileY(double latitude, int zoom) {
    final n = 1 << zoom;
    final radians = latitude * math.pi / 180;
    final value =
        (1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) / 2;
    return (value * n).floor().clamp(0, n - 1);
  }

  static Future<Uint8List> _fetchTile(
    Uri uri,
    Map<String, String> headers,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw const OfflineMapException(
          'The map provider rejected a tile request.',
        );
      }
      if (response.headers.contentType?.primaryType.toLowerCase() != 'image') {
        throw const OfflineMapException(
          'The map provider returned an invalid tile response.',
        );
      }
      if (response.contentLength > maxTileBytes) {
        throw const OfflineMapException('A map tile exceeded the size limit.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxTileBytes) {
          throw const OfflineMapException(
            'A map tile exceeded the size limit.',
          );
        }
      }
      return builder.takeBytes();
    } on TimeoutException {
      throw const OfflineMapException('The map download timed out.');
    } on SocketException {
      throw const OfflineMapException('The map provider is unreachable.');
    } finally {
      client.close(force: true);
    }
  }
}

@immutable
class _TileCoordinate {
  const _TileCoordinate({required this.z, required this.x, required this.y});
  final int z;
  final int x;
  final int y;
}
