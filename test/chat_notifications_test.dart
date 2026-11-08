import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/notifications/chat_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test_chat_notifications');
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test(
    'notification preview uses requested Chat text without sender identity',
    () async {
      await const ChatNotifications(channel: channel).received(
        ownerId: 'owner',
        incidentId: 'incident',
        messageId: 'message',
        text: 'Hello Emergency',
      );
      expect(calls.single.method, 'notifyChat');
      expect(calls.single.arguments, {
        'ownerId': 'owner',
        'incidentId': 'incident',
        'messageId': 'message',
        'text': 'Hello Emergency',
      });
    },
  );
  test(
    'preview is bounded by Unicode scalar values without splitting emoji',
    () async {
      await const ChatNotifications(channel: channel).received(
        ownerId: 'owner',
        incidentId: 'incident',
        messageId: 'message',
        text: List.filled(510, '\u{1f6a8}').join(),
      );
      final text = (calls.single.arguments as Map)['text'] as String;
      expect(text.runes.length, 500);
      expect(text, List.filled(500, '\u{1f6a8}').join());
    },
  );

  test(
    'unavailable optional notification permission does not block SOS',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(code: 'denied'),
          );
      await const ChatNotifications(channel: channel).requestPermission();
    },
  );
}
