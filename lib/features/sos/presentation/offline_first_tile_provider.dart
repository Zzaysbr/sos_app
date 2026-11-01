import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/offline_map_repository.dart';

/// Uses explicitly downloaded, completed regions before making a network
/// request. A missing local tile remains a genuine network request/error; it
/// is never represented as proof that the whole map is available offline.
class OfflineFirstTileProvider extends NetworkTileProvider {
  OfflineFirstTileProvider({
    required this.repositoryProvider,
    required this.providerKey,
  });

  final OfflineMapRepository? Function() repositoryProvider;
  final String providerKey;
  bool _disposed = false;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) {
    final File? file = repositoryProvider()?.tileFile(
      providerKey,
      coordinates.z,
      coordinates.x,
      coordinates.y,
    );
    if (file != null) return FileImage(file);
    return super.getImageWithCancelLoadingSupport(
      coordinates,
      options,
      cancelLoading,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await super.dispose();
  }
}
