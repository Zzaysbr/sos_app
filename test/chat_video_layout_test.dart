import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/presentation/chat_media.dart';

void main() {
  for (final viewport in [
    const Size(320, 568),
    const Size(640, 240),
    const Size(360, 640),
  ]) {
    testWidgets(
      'portrait video controls remain visible and tappable at $viewport',
      (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var played = false;
        var sought = false;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 34),
              ),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('ไฟล์แนบ')),
              body: ChatVideoLayout(
                aspectRatio: 9 / 20,
                video: const ColoredBox(color: Colors.black),
                progress: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => sought = true,
                  child: const SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: Center(child: LinearProgressIndicator(value: 0.5)),
                  ),
                ),
                controls: IconButton.filled(
                  tooltip: 'เล่น',
                  onPressed: () => played = true,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.play_arrow),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final play = find.byTooltip('เล่น');
        final bounds = tester.getRect(play);
        expect(bounds.bottom, lessThanOrEqualTo(viewport.height - 34));
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.height, greaterThanOrEqualTo(48));
        await tester.tap(play);
        await tester.tap(find.byType(LinearProgressIndicator));
        expect(played, true);
        expect(sought, true);
      },
    );
  }
}
