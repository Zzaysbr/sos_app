import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/user_route_repository.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';

void main() {
  testWidgets(
    'verified help becomes a short accepted banner only after an offer',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final offers =
          StreamController<List<RescueResponseInboxData>>.broadcast();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('th'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: EmergencyChatPage(
            sosId: 'incident',
            verifiedHelpOfferStream: offers.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('rescue-accepted-banner')),
        findsNothing,
      );
      offers.add([
        RescueResponseInboxData(
          ownerId: 'owner',
          messageId: 'offer',
          incidentId: 'incident',
          originMessageId: 'origin',
          responderKeyId: 'responder',
          immutableDigest: 'digest',
          payload: '{}',
          state: 'received',
          receivedAt: DateTime.utc(2026, 11, 11),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('ฝ่ายกู้ภัยรับเหตุแล้ว'), findsOneWidget);
      expect(find.textContaining('Verified help offer'), findsNothing);
      expect(tester.takeException(), isNull);
      offers.add([]);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('rescue-accepted-banner')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await offers.close();
    },
  );

  testWidgets(
    'source follows the original route node, not the middle device or incident ID',
    (tester) async {
      final routes = StreamController<UserRoutesSnapshot>.broadcast();
      final origin = base64UrlEncode(List.filled(32, 1));
      final relay = base64UrlEncode(List.filled(32, 2));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EmergencyChatPage(
            sosId: 'private-incident-id',
            routeStream: routes.stream,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private-incident-id'), findsNothing);
      routes.add(
        UserRoutesSnapshot(
          sos: [
            UserRoute(
              nodes: [
                UserRouteNode(origin),
                UserRouteNode(relay),
                const UserRouteNode(null, local: true),
              ],
              stage: UserRouteStage.received,
              extent: UserRouteExtent.thisDevice,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SOS from device 010101'), findsOneWidget);
      expect(find.textContaining('020202'), findsNothing);
      routes.add(
        UserRoutesSnapshot(
          sos: [
            UserRoute(
              nodes: [UserRouteNode(origin, local: true)],
              stage: UserRouteStage.saved,
              extent: UserRouteExtent.thisDevice,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SOS from this device'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await routes.close();
    },
  );

  testWidgets(
    'map action shares the composer row and keeps the draft after returning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => EmergencyChatPage(
              sosId: 'incident-map',
              onOpenMap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Map for incident-map')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'unsent draft');
      final map = find.byKey(const ValueKey('chat-open-map'));
      expect(
        tester.getCenter(map).dy,
        closeTo(tester.getCenter(find.byType(TextField)).dy, 24),
      );
      await tester.tap(map);
      await tester.pumpAndSettle();
      expect(find.text('Map for incident-map'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('unsent draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
