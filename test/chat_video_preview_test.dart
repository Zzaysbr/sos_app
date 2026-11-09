import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/presentation/chat_video_preview.dart';

final poster = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS2UAAAAASUVORK5CYII=',
);

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets(
    'poster appears without opening a player and rebuild retains it',
    (tester) async {
      var calls = 0;
      Future<Uint8List> load(File _) async {
        calls++;
        return poster;
      }

      Widget preview() =>
          ChatVideoPreview(file: File('/opaque/content'), loadThumbnail: load);
      await tester.pumpWidget(app(preview()));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('Open video'), findsOneWidget);
      await tester.pumpWidget(app(preview()));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed thumbnail keeps the full-video action usable', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      app(
        InkWell(
          onTap: () => opened = true,
          child: ChatVideoPreview(
            file: File('/opaque/missing'),
            loadThumbnail: (_) =>
                Future.error(StateError('decoder unavailable')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late old-file thumbnail cannot replace a new bubble preview', (
    tester,
  ) async {
    final old = Completer<Uint8List>();
    Future<Uint8List> load(File f) =>
        f.path == '/old' ? old.future : Future.value(poster);
    await tester.pumpWidget(
      app(ChatVideoPreview(file: File('/old'), loadThumbnail: load)),
    );
    await tester.pump();
    await tester.pumpWidget(
      app(ChatVideoPreview(file: File('/new'), loadThumbnail: load)),
    );
    await tester.pumpAndSettle();
    old.complete(Uint8List(0));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow bubble and large text keep the play action inside', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            width: 140,
            child: ChatVideoPreview(
              file: File('/opaque/content'),
              loadThumbnail: (_) async => poster,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final preview = tester.getRect(find.byType(ChatVideoPreview));
    final play = tester.getRect(find.byIcon(Icons.play_arrow_rounded));
    expect(preview.contains(play.topLeft), isTrue);
    expect(preview.contains(play.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });
}
