import 'package:flutter/foundation.dart';

/// Runtime-selectable tile configuration for the Incident Map.
///
/// The defaults are deliberately development-only. Supply a compliant
/// provider at build time with `--dart-define=MAP_TILE_URL=...` and matching
/// attribution/user-agent values. No API key is stored in this repository.
class MapTileProviderConfig {
  const MapTileProviderConfig({
    required this.urlTemplate,
    required this.attribution,
    required this.userAgentPackageName,
    required this.isDevelopmentFallback,
    this.validationError,
  });

  static const _developmentUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static final current = MapTileProviderConfig.fromEnvironment(
    isRelease: kReleaseMode,
  );

  factory MapTileProviderConfig.fromEnvironment({required bool isRelease}) {
    const configuredUrl = String.fromEnvironment('MAP_TILE_URL');
    const configuredAttribution = String.fromEnvironment(
      'MAP_TILE_ATTRIBUTION',
    );
    const configuredUserAgent = String.fromEnvironment('MAP_TILE_USER_AGENT');
    final isFallback = configuredUrl.isEmpty;
    final config = MapTileProviderConfig(
      urlTemplate: isFallback ? _developmentUrl : configuredUrl,
      attribution: configuredAttribution.isEmpty && isFallback
          ? 'OpenStreetMap contributors'
          : configuredAttribution,
      userAgentPackageName: configuredUserAgent.isEmpty && isFallback
          ? 'com.n1cxltine.sosapp'
          : configuredUserAgent,
      isDevelopmentFallback: isFallback,
    );
    return config.withValidation(isRelease: isRelease);
  }

  final String urlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final bool isDevelopmentFallback;
  final String? validationError;

  bool get isUsable => validationError == null;

  /// Bulk/offline downloads are deliberately restricted to the provider whose
  /// published terms explicitly permit stored tiles. In particular, the
  /// public OpenStreetMap tile service must never be prefetched.
  bool get supportsOfflineRegionDownloads {
    if (!isUsable || isDevelopmentFallback) return false;
    final uri = Uri.tryParse(urlTemplate);
    return uri != null && uri.host.toLowerCase() == 'maps.geoapify.com';
  }

  /// A stable, non-secret namespace for persisted tiles. Query values are
  /// excluded so API keys are never written to disk.
  String get offlineStorageKey {
    final uri = Uri.tryParse(urlTemplate);
    if (uri == null) return 'invalid';
    final source =
        '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}'
        '${uri.path}?${uri.queryParameters.keys.toList()..sort()}';
    var hash = 0x811c9dc5;
    for (final value in source.codeUnits) {
      hash ^= value;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'tiles-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  MapTileProviderConfig withValidation({required bool isRelease}) {
    final error = validate(isRelease: isRelease);
    return MapTileProviderConfig(
      urlTemplate: urlTemplate,
      attribution: attribution,
      userAgentPackageName: userAgentPackageName,
      isDevelopmentFallback: isDevelopmentFallback,
      validationError: error,
    );
  }

  /// Returns a user-safe configuration error, without echoing URLs or keys.
  String? validate({required bool isRelease}) {
    if (isRelease && isDevelopmentFallback) {
      return 'A production map provider is not configured for this build.';
    }
    if (urlTemplate.trim().isEmpty) return 'Map tile URL is missing.';
    final uri = Uri.tryParse(urlTemplate);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return 'Map tile URL must be a valid HTTPS template.';
    }
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (isRelease &&
        (host == 'tile.openstreetmap.org' ||
            host.endsWith('.tile.openstreetmap.org'))) {
      return 'The public OpenStreetMap tile service is development-only.';
    }
    if ((host == 'geoapify.com' || host.endsWith('.geoapify.com')) &&
        (uri.queryParameters['apiKey']?.trim().isEmpty ?? true)) {
      return 'The Geoapify API key is missing.';
    }
    if (!urlTemplate.contains('{z}') ||
        !urlTemplate.contains('{x}') ||
        !urlTemplate.contains('{y}')) {
      return 'Map tile URL must contain {z}, {x}, and {y} placeholders.';
    }
    if (attribution.trim().isEmpty) return 'Map attribution is missing.';
    if (userAgentPackageName.trim().isEmpty) {
      return 'Map user-agent identity is missing.';
    }
    return null;
  }
}
