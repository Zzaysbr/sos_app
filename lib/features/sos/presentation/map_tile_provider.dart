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
  });

  static const _developmentUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static final current = MapTileProviderConfig(
    urlTemplate: String.fromEnvironment(
      'MAP_TILE_URL',
      defaultValue: _developmentUrl,
    ),
    attribution: String.fromEnvironment(
      'MAP_TILE_ATTRIBUTION',
      defaultValue: 'OpenStreetMap contributors',
    ),
    userAgentPackageName: String.fromEnvironment(
      'MAP_TILE_USER_AGENT',
      defaultValue: 'com.example.sos_app',
    ),
    isDevelopmentFallback: String.fromEnvironment('MAP_TILE_URL').isEmpty,
  );

  final String urlTemplate;
  final String attribution;
  final String userAgentPackageName;
  final bool isDevelopmentFallback;
}
