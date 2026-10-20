import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sos_app/core/database/app_database.dart';
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

void main() {
  testWidgets('shows incident map and unavailable current location', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
  });

  testWidgets('renders current location status when permission is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
      MaterialApp(
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
      MaterialApp(
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

  testWidgets('does not start concurrent refresh requests', (tester) async {
    final completer = Completer<Position?>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
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
      MaterialApp(
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
      MaterialApp(
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
      MaterialApp(
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
      MaterialApp(
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

  testWidgets('shows timeout and preserves the last valid position', (
    tester,
  ) async {
    var fail = false;
    await tester.pumpWidget(
      MaterialApp(
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
}
