import 'package:flutter/foundation.dart';

/// Stable, credential-safe reasons why a tile-provider configuration cannot
/// be used. Presentation code must localize these values rather than echoing a
/// URL, query string, or API key back to the user.
enum MapTileProviderValidationIssue {
  productionProviderMissing,
  urlMissing,
  urlInvalid,
  publicOsmInRelease,
  geoapifyKeyMissing,
  geoapifyKeyMalformed,
  templatePlaceholdersMissing,
  attributionMissing,
  geoapifyAttributionIncomplete,
  userAgentMissing,
}

/// Runtime-selectable tile configuration for the Incident Map.
///
/// The defaults are deliberately development-only. Supply a compliant
/// provider at build time with either `GEOAPIFY_API_KEY` or explicit
/// `MAP_TILE_URL`/attribution/user-agent values. No API key is stored in this
/// repository.
class MapTileProviderConfig {
  const MapTileProviderConfig({
    required this.urlTemplate,
    required this.attribution,
    required this.userAgentPackageName,
    required this.isDevelopmentFallback,
    this.validationError,
    this.validationIssue,
  });

  static const _developmentUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _geoapifyAttribution =
      'Powered by Geoapify | © OpenStreetMap contributors';
  static const _defaultUserAgent = 'com.n1cxltine.sosapp';

  static final current = MapTileProviderConfig.fromEnvironment(
    isRelease: kReleaseMode,
  );

  factory MapTileProviderConfig.fromEnvironment({required bool isRelease}) {
    const configuredUrl = String.fromEnvironment('MAP_TILE_URL');
    const geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');
    const configuredAttribution = String.fromEnvironment(
      'MAP_TILE_ATTRIBUTION',
    );
    const configuredUserAgent = String.fromEnvironment('MAP_TILE_USER_AGENT');
    final useGeoapifyDefault =
        configuredUrl.isEmpty && geoapifyApiKey.trim().isNotEmpty;
    final urlTemplate = useGeoapifyDefault
        ? _geoapifyUrl(geoapifyApiKey)
        : _addGeoapifyKeyIfNeeded(configuredUrl, geoapifyApiKey);
    final isFallback = urlTemplate.isEmpty;
    final config = MapTileProviderConfig(
      urlTemplate: isFallback ? _developmentUrl : urlTemplate,
      attribution: configuredAttribution.isEmpty
          ? useGeoapifyDefault
                ? _geoapifyAttribution
                : isFallback
                ? 'OpenStreetMap contributors'
                : configuredAttribution
          : configuredAttribution,
      userAgentPackageName:
          configuredUserAgent.isEmpty && (isFallback || useGeoapifyDefault)
          ? _defaultUserAgent
          : configuredUserAgent,
      isDevelopmentFallback: isFallback,
    );
    return config.withValidation(isRelease: isRelease);
  }

  static String _geoapifyUrl(String apiKey) =>
      'https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=$apiKey';

  static String _addGeoapifyKeyIfNeeded(String url, String apiKey) {
    if (url.isEmpty || apiKey.trim().isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.host.toLowerCase() != 'maps.geoapify.com' ||
        uri.queryParameters['apiKey']?.trim().isNotEmpty == true) {
      return url;
    }
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'apiKey': apiKey})
        .toString();
  }

  final String urlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final bool isDevelopmentFallback;
  final String? validationError;
  final MapTileProviderValidationIssue? validationIssue;

  bool get isUsable => validationError == null;

  /// Bulk/offline downloads are deliberately restricted to Geoapify's map-tile
  /// endpoint, whose current published tile terms permit storing tiles with
  /// the required attribution. Public OSM tiles are never prefetched.
  bool get supportsOfflineRegionDownloads {
    if (!isUsable || isDevelopmentFallback) return false;
    final uri = Uri.tryParse(urlTemplate);
    return uri != null &&
        uri.host.toLowerCase() == 'maps.geoapify.com' &&
        uri.path.startsWith('/v1/tile/') &&
        uri.queryParameters['apiKey']?.trim().isNotEmpty == true;
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
    final issue = _validateIssue(isRelease: isRelease);
    return MapTileProviderConfig(
      urlTemplate: urlTemplate,
      attribution: attribution,
      userAgentPackageName: userAgentPackageName,
      isDevelopmentFallback: isDevelopmentFallback,
      validationError: issue == null ? null : _messageFor(issue),
      validationIssue: issue,
    );
  }

  /// Returns a user-safe configuration error, without echoing URLs or keys.
  String? validate({required bool isRelease}) {
    final issue = _validateIssue(isRelease: isRelease);
    return issue == null ? null : _messageFor(issue);
  }

  MapTileProviderValidationIssue? _validateIssue({required bool isRelease}) {
    if (isRelease && isDevelopmentFallback) {
      return MapTileProviderValidationIssue.productionProviderMissing;
    }
    if (urlTemplate.trim().isEmpty) {
      return MapTileProviderValidationIssue.urlMissing;
    }
    final uri = Uri.tryParse(urlTemplate);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return MapTileProviderValidationIssue.urlInvalid;
    }
    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
    if (isRelease &&
        (host == 'tile.openstreetmap.org' ||
            host.endsWith('.tile.openstreetmap.org'))) {
      return MapTileProviderValidationIssue.publicOsmInRelease;
    }
    if (host == 'geoapify.com' || host.endsWith('.geoapify.com')) {
      final apiKey = uri.queryParameters['apiKey']?.trim();
      if (apiKey == null || apiKey.isEmpty) {
        return MapTileProviderValidationIssue.geoapifyKeyMissing;
      }
      if (!_isValidGeoapifyKey(apiKey)) {
        return MapTileProviderValidationIssue.geoapifyKeyMalformed;
      }
    }
    if (!urlTemplate.contains('{z}') ||
        !urlTemplate.contains('{x}') ||
        !urlTemplate.contains('{y}')) {
      return MapTileProviderValidationIssue.templatePlaceholdersMissing;
    }
    if (attribution.trim().isEmpty) {
      return MapTileProviderValidationIssue.attributionMissing;
    }
    if ((host == 'geoapify.com' || host.endsWith('.geoapify.com')) &&
        (!attribution.toLowerCase().contains('geoapify') ||
            !attribution.toLowerCase().contains('openstreetmap'))) {
      return MapTileProviderValidationIssue.geoapifyAttributionIncomplete;
    }
    if (userAgentPackageName.trim().isEmpty) {
      return MapTileProviderValidationIssue.userAgentMissing;
    }
    return null;
  }

  static bool _isValidGeoapifyKey(String value) =>
      value.length >= 16 &&
      value.length <= 128 &&
      RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value);

  static String _messageFor(MapTileProviderValidationIssue issue) =>
      switch (issue) {
        MapTileProviderValidationIssue.productionProviderMissing =>
          'A production map provider is not configured for this build.',
        MapTileProviderValidationIssue.urlMissing => 'Map tile URL is missing.',
        MapTileProviderValidationIssue.urlInvalid =>
          'Map tile URL must be a valid HTTPS template.',
        MapTileProviderValidationIssue.publicOsmInRelease =>
          'The public OpenStreetMap tile service is development-only.',
        MapTileProviderValidationIssue.geoapifyKeyMissing =>
          'The Geoapify API key is missing.',
        MapTileProviderValidationIssue.geoapifyKeyMalformed =>
          'The Geoapify API key format is invalid.',
        MapTileProviderValidationIssue.templatePlaceholdersMissing =>
          'Map tile URL must contain {z}, {x}, and {y} placeholders.',
        MapTileProviderValidationIssue.attributionMissing =>
          'Map attribution is missing.',
        MapTileProviderValidationIssue.geoapifyAttributionIncomplete =>
          'Geoapify and OpenStreetMap attribution are required.',
        MapTileProviderValidationIssue.userAgentMissing =>
          'Map user-agent identity is missing.',
      };
}
