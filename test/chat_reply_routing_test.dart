import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';

class IncomingHistory extends MockEmergencyChatRepository {
  final incoming = EmergencyChatMessage(
    id: 'incoming',
    sosId: 'incident',
    senderId: 'other-installation',
    // PersistentChatRepository stores the local owner here for incoming rows.
    recipientId: 'local-owner',
    text: 'received',
    createdAt: DateTime.utc(2026),
    status: ChatDeliveryStatus.delivered,
    isMine: false,
  );
  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async => [
    incoming,
    ...messagesFor(sosId),
  ];
  @override
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) async* {
    yield await loadMessages(sosId);
  }
}

void main() {
  testWidgets(
    'incoming local owner is never reused as a BLE reply destination',
    (tester) async {
      final repository = IncomingHistory();
      String? selected = 'callback-not-called';
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyChatPage(
            sosId: 'incident',
            repository: repository,
            onMessageCreatedWithDestination: (message, {destinationId}) async {
              selected = destinationId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'reply');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(
        selected,
        isNull,
        reason: 'Use the established incident route; incoming recipient is an owner scope.',
      );
      expect(repository.messagesFor('incident').single.recipientId, isNull);
    },
  );
}
