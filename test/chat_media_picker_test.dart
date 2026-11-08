import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/l10n/generated/app_localizations.dart';
import 'package:sos_app/features/sos/data/media_attachment_store.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';
import 'package:sos_app/features/sos/presentation/chat_media.dart';

class PickerContextStore extends MediaAttachmentStore {
  PickerContextStore() : super(ownerId: 'test');
  @override
  Future<void> beginPicker(String incident, String kind) async {}
  @override
  Future<void> endPicker(String incident) async {}
}

void main() {
  Widget app({
    required bool allowed,
    required Future<PreparedChatMedia?> Function(ChatMediaSource) picker,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: EmergencyChatPage(
      sosId: 'incident',
      attachmentStore: PickerContextStore(),
      canAttach: () async => allowed,
      mediaPicker: picker,
    ),
  );
  testWidgets(
    'all four attachment choices reach the picker and cancellation leaves composer available',
    (tester) async {
      final selected = <ChatMediaSource>[];
      await tester.pumpWidget(
        app(
          allowed: true,
          picker: (source) async {
            selected.add(source);
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      for (final name in [
        'Take photo',
        'Choose photo',
        'Record video',
        'Choose video',
      ]) {
        await tester.tap(find.byTooltip('Attach photo or video'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      expect(selected, ChatMediaSource.values);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester
            .widget<PopupMenuButton<ChatMediaSource>>(
              find.byType(PopupMenuButton<ChatMediaSource>),
            )
            .enabled,
        isTrue,
      );
    },
  );
  testWidgets('no verified helper cannot open camera/library', (tester) async {
    var called = false;
    await tester.pumpWidget(
      app(
        allowed: false,
        picker: (_) async {
          called = true;
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attach photo or video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(
      find.text('Wait for a verified help offer before attaching media.'),
      findsOneWidget,
    );
  });
}
