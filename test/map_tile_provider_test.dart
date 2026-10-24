import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/presentation/map_tile_provider.dart';

void main() {
  const valid = MapTileProviderConfig(
    urlTemplate: 'https://tiles.example.test/{z}/{x}/{y}.png',
    attribution: 'Example Maps',
    userAgentPackageName: 'com.n1cxltine.sosapp',
    isDevelopmentFallback: false,
  );

  test('development fallback is valid only for non-release builds', () {
    const development = MapTileProviderConfig(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      attribution: 'OpenStreetMap contributors',
      userAgentPackageName: 'com.n1cxltine.sosapp',
      isDevelopmentFallback: true,
    );
    expect(development.withValidation(isRelease: false).isUsable, isTrue);
    expect(
      development.withValidation(isRelease: true).validationError,
      contains('production map provider'),
    );
  });

  test(
    'production configuration requires a valid template and attribution',
    () {
      expect(valid.withValidation(isRelease: true).isUsable, isTrue);
      expect(
        const MapTileProviderConfig(
          urlTemplate: 'http://tiles.example.test/{z}/{x}/{y}.png',
          attribution: 'Example Maps',
          userAgentPackageName: 'com.n1cxltine.sosapp',
          isDevelopmentFallback: false,
        ).withValidation(isRelease: true).validationError,
        contains('HTTPS'),
      );
      expect(
        const MapTileProviderConfig(
          urlTemplate: 'https://tiles.example.test/{z}/{x}.png',
          attribution: 'Example Maps',
          userAgentPackageName: 'com.n1cxltine.sosapp',
          isDevelopmentFallback: false,
        ).withValidation(isRelease: true).validationError,
        contains('placeholders'),
      );
      expect(
        const MapTileProviderConfig(
          urlTemplate: 'https://tiles.example.test/{z}/{x}/{y}.png',
          attribution: '',
          userAgentPackageName: 'com.n1cxltine.sosapp',
          isDevelopmentFallback: false,
        ).withValidation(isRelease: true).validationError,
        contains('attribution'),
      );
    },
  );

  test('validation errors do not echo provider credentials', () {
    final config = const MapTileProviderConfig(
      urlTemplate:
          'https://tiles.example.test/{z}/{x}/{y}.png?key=super-secret',
      attribution: '',
      userAgentPackageName: 'com.n1cxltine.sosapp',
      isDevelopmentFallback: false,
    ).withValidation(isRelease: true);
    expect(config.validationError, isNot(contains('super-secret')));
  });
  test('release rejects an explicitly configured public OSM server', () {
    for (final host in [
      'tile.openstreetmap.org',
      'a.tile.openstreetmap.org',
      'TILE.OPENSTREETMAP.ORG.',
    ]) {
      final config = MapTileProviderConfig(
        urlTemplate: 'https://$host/{z}/{x}/{y}.png',
        attribution: 'OpenStreetMap contributors',
        userAgentPackageName: 'com.n1cxltine.sosapp',
        isDevelopmentFallback: false,
      );
      expect(
        config.withValidation(isRelease: true).isUsable,
        isFalse,
        reason: 'Explicit configuration must not enable the public OSM service in release',
      );
      expect(config.withValidation(isRelease: false).isUsable, isTrue);
    }
  });

  test('Geoapify configuration without an API key fails closed', () {
    const config = MapTileProviderConfig(
      urlTemplate:
          'https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png',
      attribution: 'Powered by Geoapify | © OpenStreetMap contributors',
      userAgentPackageName: 'com.n1cxltine.sosapp',
      isDevelopmentFallback: false,
    );

    final validated = config.withValidation(isRelease: true);
    expect(validated.isUsable, isFalse);
    expect(validated.validationError, 'The Geoapify API key is missing.');
    expect(validated.validationError, isNot(contains('maps.geoapify.com')));
  });

  test('actual release environment enforces public-provider safety', () {
    const configured = String.fromEnvironment('MAP_TILE_URL');
    final config = MapTileProviderConfig.fromEnvironment(isRelease: true);
    final host = Uri.tryParse(configured)?.host.toLowerCase() ?? '';
    if (configured.isEmpty ||
        host == 'tile.openstreetmap.org' ||
        host.endsWith('.tile.openstreetmap.org')) {
      expect(config.isUsable, isFalse);
    } else {
      expect(config.isDevelopmentFallback, isFalse);
    }
  });
}
