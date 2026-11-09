import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/l10n/generated/app_localizations.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';
import 'package:sos_app/features/nearby_ble/data/route_device_names.dart';
import 'package:sos_app/features/nearby_ble/data/user_route_repository.dart';
import 'package:sos_app/features/nearby_ble/presentation/user_route_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late RouteDeviceNames names;
  final a = base64UrlEncode(List.filled(32, 1)),
      b = base64UrlEncode(List.filled(32, 2)),
      c = base64UrlEncode(List.filled(32, 3));
  final route = UserRoute(
    nodes: [UserRouteNode(a), UserRouteNode(b), UserRouteNode(c, local: true)],
    stage: UserRouteStage.received,
    extent: UserRouteExtent.thisDevice,
  );
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Thonburi.ttc');
    if (await font.exists()) {
      await (FontLoader('RouteTest')..addFont(
            Future.value(ByteData.sublistView(await font.readAsBytes())),
          ))
          .load();
    }
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk != null) {
      final icons = File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(await icons.readAsBytes())),
            ))
            .load();
      }
    }
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('route-ui-');
    names = RouteDeviceNames(ownerId: 'test', directory: root);
    await names.save(a, 'มือถือแม่');
    await names.save(b, 'เครื่องอาสา');
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  Widget app(
    Widget child, {
    bool thai = false,
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(thai ? 'th' : 'en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffa92836),
        brightness: brightness,
      ),
      fontFamily: 'RouteTest',
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  for (final thai in [false, true]) {
    testWidgets(
      'icon-led known route fits a narrow phone and large text; thai=$thai',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            UserRouteView(routes: [route], names: names),
            thai: thai,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.hub_rounded), findsOneWidget);
        expect(find.text('มือถือแม่'), findsOneWidget);
        expect(
          find.textContaining(
            thai ? 'ผ่านตัวกลาง 1 เครื่อง' : '1 intermediary device(s)',
          ),
          findsOneWidget,
        );
        expect(find.text(a), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(thai ? 'เครื่องนี้' : 'This device').first,
          180,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'confirmed destination still shows unknown intermediaries without inventing direct hops',
    (tester) async {
      final unknown = UserRoute(
        nodes: [UserRouteNode(a, local: true), UserRouteNode(c)],
        stage: UserRouteStage.confirmed,
        extent: UserRouteExtent.endpointsOnly,
      );
      await tester.pumpWidget(
        app(UserRouteView(routes: [unknown], names: names)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Destination saved the message'), findsOneWidget);
      expect(find.text('Intermediate route unknown'), findsOneWidget);
      expect(find.text('Direct · 1 hop'), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    },
  );
  testWidgets(
    'nickname dialog saves and closes without disposing an active input',
    (tester) async {
      await tester.pumpWidget(
        app(UserRouteView(routes: [route], names: names)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Set nickname').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Family phone');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 50 && names.labels[a] != 'Family phone'; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(names.labels[a], 'Family phone');
      expect(find.text('Family phone'), findsOneWidget);
      expect(names.labels[a], 'Family phone');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('route visual preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: capture,
        child: app(UserRouteView(routes: [route], names: names), thai: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final output = Platform.environment['SOS_ROUTE_PREVIEW_PATH'];
    if (output != null) {
      await tester.runAsync(() async {
        final image =
            await (capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(output).writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
  });
  testWidgets('open route details follow live evidence changes', (
    tester,
  ) async {
    final routes = ValueNotifier<List<UserRoute>>([route]);
    addTearDown(routes.dispose);
    await tester.pumpWidget(
      app(
        ValueListenableBuilder<List<UserRoute>>(
          valueListenable: routes,
          builder: (context, value, _) =>
              UserRouteView(routes: value, names: names, compact: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SOS route'));
    await tester.pumpAndSettle();
    expect(find.text('Received on this device'), findsOneWidget);
    routes.value = [
      UserRoute(
        nodes: [UserRouteNode(a, local: true), UserRouteNode(c)],
        stage: UserRouteStage.confirmed,
        extent: UserRouteExtent.endpointsOnly,
      ),
    ];
    await tester.pumpAndSettle();
    expect(find.text('Destination saved the message'), findsOneWidget);
    expect(find.text('Received on this device'), findsNothing);
  });

  testWidgets('Chat route entries fit a small phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = MockEmergencyChatRepository();
    await repository.insertMessage(
      sosId: 'incident',
      text: 'test',
      messageId: 'route-message',
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('th'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: EmergencyChatPage(
            sosId: 'incident',
            repository: repository,
            routeDeviceNames: names,
            routeStream: Stream.value(
              UserRoutesSnapshot(sos: [route], chat: {'route-message': route}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('เส้นทาง SOS'), findsOneWidget);
  });
}
