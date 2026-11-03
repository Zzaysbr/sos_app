import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/features/sos/presentation/incident_map_page.dart';
import 'package:sos_app/features/sos/presentation/map_tile_provider.dart';
import 'package:sos_app/features/nearby_ble/domain/location_ble_envelope.dart';

SosMessage _incident({double? latitude = 13.7, double? longitude = 100.5}) =>
    SosMessage(
      id: 'incident-1',
      ownerId: 'owner-1',
      type: 'emergency',
      message: 'Help',
      latitude: latitude,
      longitude: longitude,
      status: 'active',
      syncState: 'pending',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

Position _position({DateTime? timestamp}) => Position(
  longitude: 100.5001,
  latitude: 13.7001,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: 8,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
  floor: null,
  isMocked: true,
);

class _FailedTile extends Mock implements TileImage {}

Widget _app({required Widget home, Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    binding.platformDispatcher.localeTestValue = const Locale('en');
  });
  tearDown(binding.platformDispatcher.clearLocaleTestValue);

  testWidgets('shows incident map and unavailable current location', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incident Map'), findsOneWidget);
    expect(
      find.text(
        'Current location unavailable. Incident location remains available.',
      ),
      findsOneWidget,
    );
    expect(find.text('Incident: 13.700000, 100.500000'), findsOneWidget);
    expect(
      MapTileProviderConfig.current.attribution,
      'OpenStreetMap contributors',
    );
    expect(
      find.text(
        'Development tile provider; configure MAP_TILE_URL for production.',
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Center map on current location'), findsOneWidget);
    expect(
      find.byTooltip(
        'Offline downloads require the production Geoapify provider',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders a rescue candidate location as the incident marker', (
    tester,
  ) async {
    final now = DateTime.utc(2026);
    final candidate = RescueInboxData(
      ownerId: 'rescuer',
      originMessageId: 'relay:location-candidate',
      incidentId: 'location-candidate',
      originKeyId: 'origin-key',
      immutableDigest: 'digest',
      emergencyType: 'emergency',
      emergencyMessage: 'Help',
      includeLocation: true,
      latitude: 13.701,
      longitude: 100.501,
      incomingHopCount: 1,
      incomingPath: '["origin-key"]',
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
      receivedAt: now,
      state: 'pending',
    );
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(latitude: null, longitude: null),
          rescueCandidate: candidate,
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incident: 13.701000, 100.501000'), findsOneWidget);
    expect(
      find.text(
        'Current location unavailable. Incident location remains available.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders current location status when permission is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          locationLoader: () async => _position(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Refresh current location'));
    await tester.pumpAndSettle();

    expect(find.text('Current location available.'), findsOneWidget);
  });

  testWidgets('shows a recovery state when no incident location exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(latitude: null, longitude: null),
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No location is available for this incident.'),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('rejects out-of-range incident coordinates', (tester) async {
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(latitude: 91, longitude: 100),
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Incident coordinates are unavailable or invalid.'),
      findsNWidgets(2),
    );
  });

  testWidgets('localizes invalid incident coordinates in Thai', (tester) async {
    await tester.pumpWidget(
      _app(
        locale: const Locale('th'),
        home: IncidentMapPage(
          incident: _incident(latitude: 91, longitude: 100),
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('พิกัดของเหตุการณ์ใช้ไม่ได้หรือไม่ถูกต้อง'),
      findsNWidgets(2),
    );
  });

  testWidgets('does not start concurrent refresh requests', (tester) async {
    final completer = Completer<Position?>();
    var calls = 0;
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          locationLoader: () {
            calls++;
            return completer.future;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh current location'));
    await tester.tap(find.byTooltip('Refresh current location'));
    expect(calls, 1);
    completer.complete(_position());
    await tester.pumpAndSettle();
  });

  testWidgets('ignores a location result after disposal', (tester) async {
    final completer = Completer<Position?>();
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          locationLoader: () => completer.future,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh current location'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    completer.complete(_position());
    await tester.pump();
  });

  testWidgets('shows stale status from measurement timestamp', (tester) async {
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          locationLoader: () async => _position(
            timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh current location'));
    await tester.pumpAndSettle();

    expect(
      find.text('Current location is stale. Refresh before relying on it.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a verified incoming location separately from incident', (
    tester,
  ) async {
    final incoming = LocationBleEnvelope.update(
      messageId: 'incoming-map-1',
      sosId: 'incident-1',
      senderDeviceId: 'peer-1',
      recipientId: 'owner-1',
      latitude: 13.71,
      longitude: 100.51,
      createdAt: DateTime.utc(2026, 1, 1, 12),
      expiresAt: DateTime.utc(2099),
    );
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          incomingLocation: incoming,
          incomingSenderDeviceId: 'peer-1',
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Shared location available from the matched peer.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Shared: 13.710000, 100.510000'),
      findsOneWidget,
    );
  });

  testWidgets('does not present an expired incoming location as current', (
    tester,
  ) async {
    final incoming = LocationBleEnvelope.update(
      messageId: 'incoming-map-expired',
      sosId: 'incident-1',
      senderDeviceId: 'peer-1',
      recipientId: 'owner-1',
      latitude: 13.71,
      longitude: 100.51,
      createdAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 1, 1, 0, 1),
    );
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          incomingLocation: incoming,
          incomingSenderDeviceId: 'peer-1',
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Shared location is expired and is not shown as current.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'keeps the incident marker when the tile provider is unavailable',
    (tester) async {
      final unavailable = const MapTileProviderConfig(
        urlTemplate: '',
        attribution: '',
        userAgentPackageName: '',
        isDevelopmentFallback: false,
      ).withValidation(isRelease: true);
      await tester.pumpWidget(
        _app(
          home: IncidentMapPage(
            incident: _incident(),
            tileProvider: unavailable,
            locationLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
      expect(find.text('The map service address is missing.'), findsOneWidget);
      expect(find.text('Incident: 13.700000, 100.500000'), findsOneWidget);
    },
  );

  testWidgets('renders a localized map configuration failure in Thai', (
    tester,
  ) async {
    final unavailable = const MapTileProviderConfig(
      urlTemplate: '',
      attribution: '',
      userAgentPackageName: '',
      isDevelopmentFallback: false,
    ).withValidation(isRelease: true);
    await tester.pumpWidget(
      _app(
        locale: const Locale('th'),
        home: IncidentMapPage(
          incident: _incident(),
          tileProvider: unavailable,
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.location_on), findsOneWidget);
    expect(find.text('ไม่มีที่อยู่บริการแผนที่'), findsOneWidget);
  });

  testWidgets('shows timeout and preserves the last valid position', (
    tester,
  ) async {
    var fail = false;
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          locationLoader: () async {
            if (fail) throw TimeoutException('test timeout');
            return _position();
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh current location'));
    await tester.pumpAndSettle();
    expect(find.text('Current location available.'), findsOneWidget);

    fail = true;
    await tester.tap(find.byTooltip('Refresh current location'));
    await tester.pumpAndSettle();
    expect(find.text('Location request timed out.'), findsOneWidget);
    // The retained current-position marker and refresh action both use this
    // icon; the timeout must not clear the retained position.
    expect(find.byIcon(Icons.my_location), findsNWidgets(2));
    expect(find.byTooltip('Refresh current location'), findsOneWidget);
  });
  testWidgets('provider attribution is visible without opening a popup', (
    tester,
  ) async {
    const provider = MapTileProviderConfig(
      urlTemplate: 'https://tiles.example.test/{z}/{x}/{y}.png',
      attribution: 'Example Maps / OpenStreetMap contributors',
      userAgentPackageName: 'com.n1cxltine.sosapp',
      isDevelopmentFallback: false,
    );
    await tester.pumpWidget(
      _app(
        home: IncidentMapPage(
          incident: _incident(),
          tileProvider: provider,
          locationLoader: () async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find
          .textContaining('Example Maps / OpenStreetMap contributors')
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'provider failure and network loss keep coordinates and allow tile retry',
    (tester) async {
      const provider = MapTileProviderConfig(
        urlTemplate: 'https://tiles.example.test/{z}/{x}/{y}.png',
        attribution: 'Example Maps',
        userAgentPackageName: 'com.n1cxltine.sosapp',
        isDevelopmentFallback: false,
      );
      await tester.pumpWidget(
        _app(
          home: IncidentMapPage(
            incident: _incident(),
            tileProvider: provider,
            locationLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final error in [
        StateError('synthetic provider failure'),
        const SocketException('synthetic offline'),
      ]) {
        final tile = tester.widget<TileLayer>(find.byType(TileLayer));
        tile.errorTileCallback!(_FailedTile(), error, StackTrace.current);
        await tester.pump();
        expect(find.text('Retry map tiles'), findsOneWidget);
        expect(find.byIcon(Icons.location_on), findsOneWidget);
        expect(find.text('Incident: 13.700000, 100.500000'), findsOneWidget);
        await tester.tap(find.text('Retry map tiles'));
        await tester.pump();
        expect(
          tester.widget<TileLayer>(find.byType(TileLayer)).key,
          isNot(tile.key),
        );
      }
    },
  );
  testWidgets(
    'map attribution has a 48px link and opens only the public credit URL',
    (tester) async {
      String? opened;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('sos_app/external_links'),
        (call) async {
          opened = call.arguments as String;
          return null;
        },
      );
      await tester.pumpWidget(
        _app(
          home: IncidentMapPage(
            incident: _incident(),
            locationLoader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final link = find.widgetWithText(TextButton, 'OpenStreetMap copyright');
      expect(tester.getSize(link).height, greaterThanOrEqualTo(48));
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(opened, 'https://www.openstreetmap.org/copyright');
    },
  );
}
