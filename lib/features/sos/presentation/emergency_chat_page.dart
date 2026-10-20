import 'dart:async';

import 'package:flutter/material.dart';

import '../../nearby_ble/data/ble_transport.dart';
import '../../nearby_ble/presentation/ble_recipient_picker_page.dart';
import '../data/chat_repository.dart';

/// Temporary in-memory adapter. It deliberately reports Sent only; Delivered
/// must come from a future BLE/cloud acknowledgement source.
class MockEmergencyChatRepository implements ChatRepository {
  final Map<String, List<EmergencyChatMessage>> _messages = {};

  List<EmergencyChatMessage> messagesFor(String sosId) =>
      List.unmodifiable(_messages[sosId] ?? const []);

  @override
  Future<EmergencyChatMessage> insertMessage({
    required String sosId,
    required String text,
    String? messageId,
    String? recipientId,
    String messageType = 'text',
    String? attachmentPath,
    String? attachmentMimeType,
    String? attachmentName,
  }) async {
    final message = EmergencyChatMessage(
      id: messageId ?? 'chat-${DateTime.now().microsecondsSinceEpoch}',
      sosId: sosId,
      senderId: 'me',
      text: text,
      createdAt: DateTime.now(),
      status: ChatDeliveryStatus.sent,
      isMine: true,
      recipientId: recipientId,
    );
    (_messages[sosId] ??= []).add(message);
    return message;
  }

  /// Backward-compatible helper for the existing Week 4 widget tests.
  Future<EmergencyChatMessage> send(String sosId, String text) =>
      insertMessage(sosId: sosId, text: text);

  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async =>
      messagesFor(sosId);

  @override
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) async* {
    yield messagesFor(sosId);
  }

  @override
  Future<void> updateDeliveryStatus(
    String messageId,
    ChatDeliveryStatus status,
  ) async {}

  @override
  Future<EmergencyChatMessage> insertIncomingMessage({
    required String messageId,
    required String sosId,
    required String senderId,
    String? recipientId,
    required String text,
    required DateTime createdAt,
  }) => insertMessage(
    sosId: sosId,
    text: text,
    messageId: messageId,
    recipientId: recipientId,
  );
}

class EmergencyChatPage extends StatefulWidget {
  const EmergencyChatPage({
    super.key,
    this.sosId,
    this.contactName = 'Emergency helper',
    this.repository,
    this.onMessageCreated,
    this.onMessageCreatedWithDestination,
    this.bleTransport,
  });

  final String? sosId;
  final String contactName;
  final ChatRepository? repository;
  final Future<void> Function(EmergencyChatMessage message)? onMessageCreated;
  final Future<void> Function(
    EmergencyChatMessage message, {
    String? destinationId,
  })?
  onMessageCreatedWithDestination;
  final BleTransportClient? bleTransport;

  @override
  State<EmergencyChatPage> createState() => _EmergencyChatPageState();
}

class _EmergencyChatPageState extends State<EmergencyChatPage> {
  final _controller = TextEditingController();
  late final ChatRepository _repository;
  final _messages = <EmergencyChatMessage>[];
  StreamSubscription<List<EmergencyChatMessage>>? _messagesSubscription;
  String? _selectedDestinationId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MockEmergencyChatRepository();
    final sosId = widget.sosId;
    if (sosId != null) {
      _messagesSubscription = _repository.watchMessages(sosId).listen((
        messages,
      ) {
        if (!mounted) return;
        setState(
          () => _messages
            ..clear()
            ..addAll(messages),
        );
        for (final message in messages.reversed) {
          // Incoming recipientId is the local owner scope, not a radio route.
          if (!message.isMine) continue;
          final recipient = message.recipientId;
          if (recipient != null && recipient.isNotEmpty) {
            _selectedDestinationId = recipient;
            break;
          }
        }
      });
      unawaited(_loadMessages(sosId));
    }
  }

  Future<void> _loadMessages(String sosId) async {
    try {
      final messages = await _repository.loadMessages(sosId);
      if (mounted) {
        setState(
          () => _messages
            ..clear()
            ..addAll(messages),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load chat history: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_messagesSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final sosId = widget.sosId;
    if (text.isEmpty || _sending || sosId == null) return;
    setState(() => _sending = true);
    try {
      String? destinationId;
      if (_selectedDestinationId != null) {
        destinationId = _selectedDestinationId;
      } else if (widget.bleTransport != null) {
        destinationId = await Navigator.of(context).push<String>(
          MaterialPageRoute<String>(
            builder: (_) =>
                BleRecipientPickerPage(transport: widget.bleTransport!),
          ),
        );
        if (!mounted) return;
        _selectedDestinationId = destinationId;
      }
      final message = await _repository.insertMessage(
        sosId: sosId,
        text: text,
        recipientId: destinationId,
      );
      if (!mounted) return;
      _controller.clear();
      setState(() => _messages.add(message));
      try {
        if (widget.onMessageCreatedWithDestination != null) {
          await widget.onMessageCreatedWithDestination!.call(
            message,
            destinationId: destinationId,
          );
        } else {
          await widget.onMessageCreated?.call(message);
        }
        // The coordinator may have advanced the durable status to awaiting
        // acknowledgement before this callback returns. Reload from Drift so
        // the rendered status remains sourced from persistence.
        if (mounted) await _loadMessages(sosId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally; BLE delivery is pending.'),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message could not be sent. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.support_agent)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Text(
                    'SOS chat · offline-first',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          MaterialBanner(
            content: Text(
              widget.sosId == null
                  ? 'Select an SOS incident from History to start a chat.'
                  : 'Incident ${widget.sosId} · Delivered requires receiver confirmation.',
            ),
            leading: const Icon(Icons.info_outline),
            actions: [TextButton(onPressed: () {}, child: const Text('Info'))],
          ),
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nSend a status update to the helper.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final message = _messages[index];
                      return Align(
                        alignment: message.isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: message.isMine
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(message.text),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_time(message.createdAt)} · ${_statusLabel(message.status)}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach image',
                    onPressed: () =>
                        _notAvailable('Image attachments need storage setup.'),
                    icon: const Icon(Icons.attach_file),
                  ),
                  IconButton(
                    tooltip: 'Share location',
                    onPressed: () => _notAvailable(
                      'Location sharing will use the existing location service.',
                    ),
                    icon: const Icon(Icons.location_on_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Type an update…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: _sending || widget.sosId == null ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _notAvailable(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  String _statusLabel(ChatDeliveryStatus status) => switch (status) {
    ChatDeliveryStatus.pending => 'Queued',
    ChatDeliveryStatus.sent => 'Awaiting confirmation (sent)',
    ChatDeliveryStatus.delivered => 'Confirmed received',
    ChatDeliveryStatus.failed => 'Failed; retryable',
  };
}
