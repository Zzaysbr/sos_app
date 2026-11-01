import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';
import 'package:sos_app/features/sos/presentation/in_app_notifications_page.dart';

void main() {
  testWidgets('emergency chat blocks empty sends and supports mock send', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EmergencyChatPage(sosId: 'sos-test')),
    );

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(
      find.text('ยังไม่มีข้อความ\nส่งข้อมูลสั้น ๆ ที่ผู้ช่วยเหลือต้องรู้'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'I am safe');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('I am safe'), findsOneWidget);
    expect(find.textContaining('sent'), findsOneWidget);
  });

  testWidgets('notifications can be marked read individually and all at once', (
    tester,
  ) async {
    final repository = MockNotificationRepository();
    repository.notifications.add(
      InAppNotification(
        id: 'chat-1',
        title: 'New chat message',
        detail: 'A helper replied.',
        createdAt: DateTime(2026),
        type: InAppNotificationType.chat,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: InAppNotificationsPage(repository: repository)),
    );

    expect(find.byIcon(Icons.fiber_manual_record), findsNWidgets(2));
    await tester.tap(find.text('New chat message'));
    await tester.pump();
    expect(repository.notifications.last.read, isTrue);

    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(repository.unreadCount, 0);
  });

  test('mock chat keeps messages isolated by SOS id', () async {
    final repository = MockEmergencyChatRepository();
    await repository.send('sos-a', 'for A');
    await repository.send('sos-b', 'for B');
    expect(repository.messagesFor('sos-a').single.text, 'for A');
    expect(repository.messagesFor('sos-b').single.text, 'for B');
  });
}
