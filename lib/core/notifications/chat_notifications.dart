import 'package:flutter/services.dart';

/// Shows a bounded preview of the received message, as requested by the user.
/// OS preview/lock-screen settings still control what is visible.
/// The native layer owns stable-ID deduplication across Dart/engine restarts.
class ChatNotifications {
  const ChatNotifications({
    this.channel = const MethodChannel('sos_app/background'),
  });
  final MethodChannel channel;

  Future<void> requestPermission() async {
    try {
      await channel
          .invokeMethod<bool>('requestNotifications')
          .timeout(const Duration(seconds: 30));
    } on Object {
      // Notification permission is optional; SOS/Chat must remain usable.
    }
  }

  Future<void> received({
    required String ownerId,
    required String incidentId,
    required String messageId,
    required String text,
  }) async {
    await channel
        .invokeMethod<void>('notifyChat', {
          'ownerId': ownerId,
          'incidentId': incidentId,
          'messageId': messageId,
          // Bound platform payload without splitting a Unicode surrogate pair.
          'text': String.fromCharCodes(text.runes.take(500)),
        })
        .timeout(const Duration(seconds: 3));
  }
}
