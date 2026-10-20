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
    final configuredUrl = String.fromEnvironment('MAP_TILE_URL');
    final isFallback = configuredUrl.isEmpty;
    final config = MapTileProviderConfig(
      urlTemplate: isFallback ? _developmentUrl : configuredUrl,
      attribution: String.fromEnvironment(
        'MAP_TILE_ATTRIBUTION',
        defaultValue: isFallback ? 'OpenStreetMap contributors' : '',
      ),
      userAgentPackageName: String.fromEnvironment(
        'MAP_TILE_USER_AGENT',
        defaultValue: isFallback ? 'com.example.sos_app' : '',
      ),
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
