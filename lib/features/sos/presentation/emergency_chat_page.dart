import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../nearby_ble/data/hop_relay_coordinator.dart';
import '../../nearby_ble/data/ble_transport.dart';
import '../../nearby_ble/domain/ble_delivery_state.dart';
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
    this.onAssignPendingDestination,
    this.bleTransport,
    this.sosDeliveryStream,
    this.relayStatusStream,
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
  final Future<int> Function(String sosId, String destinationId)?
  onAssignPendingDestination;
  final BleTransportClient? bleTransport;
  final Stream<BleOutboxData?>? sosDeliveryStream;
  final Stream<RelayStatusSnapshot>? relayStatusStream;

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
  bool _assigningPendingDestination = false;
  bool _loadingMessages = true;
  String? _loadError;

  bool get _hasUnroutedPendingMessages => _messages.any(
    (message) =>
        message.isMine &&
        message.recipientId?.trim().isNotEmpty != true &&
        (message.status == ChatDeliveryStatus.pending ||
            message.status == ChatDeliveryStatus.failed),
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MockEmergencyChatRepository();
    final sosId = widget.sosId;
    if (sosId != null) {
      _messagesSubscription = _repository
          .watchMessages(sosId)
          .listen(
            (messages) {
              if (!mounted) return;
              setState(() {
                _messages
                  ..clear()
                  ..addAll(messages);
                _loadingMessages = false;
                _loadError = null;
              });
              for (final message in messages.reversed) {
                // Incoming recipientId is the local owner scope, not a radio route.
                if (!message.isMine) continue;
                final recipient = message.recipientId;
                if (recipient != null && recipient.isNotEmpty) {
                  _selectedDestinationId = recipient;
                  break;
                }
              }
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _loadingMessages = false;
                _loadError = 'โหลดข้อความไม่สำเร็จ';
              });
            },
          );
      unawaited(_loadMessages(sosId));
    } else {
      _loadingMessages = false;
    }
  }

  Future<void> _loadMessages(String sosId) async {
    try {
      final messages = await _repository.loadMessages(sosId);
      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(messages);
          _loadingMessages = false;
          _loadError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadingMessages = false;
          _loadError = 'โหลดข้อความไม่สำเร็จ กรุณาลองอีกครั้ง';
        });
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

  Future<void> _assignPendingDestination() async {
    final sosId = widget.sosId;
    final assign = widget.onAssignPendingDestination;
    final transport = widget.bleTransport;
    if (sosId == null ||
        assign == null ||
        transport == null ||
        _assigningPendingDestination) {
      return;
    }
    setState(() => _assigningPendingDestination = true);
    try {
      final destinationId = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
          builder: (_) => BleRecipientPickerPage(transport: transport),
        ),
      );
      if (!mounted || destinationId == null) return;
      final assigned = await assign(sosId, destinationId);
      if (!mounted) return;
      if (assigned == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No queued messages needed a recipient.'),
          ),
        );
        return;
      }
      _selectedDestinationId = destinationId;
      await _loadMessages(sosId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              assigned == 1
                  ? 'Recipient assigned to 1 queued message.'
                  : 'Recipient assigned to $assigned queued messages.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to assign recipient: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningPendingDestination = false);
    }
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แชตฉุกเฉิน')),
      body: Column(
        children: [
          if (widget.sosId != null)
            Semantics(
              label: 'กำลังสนทนาในเหตุ ${widget.sosId}',
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Row(
                  children: [
                    const Icon(Icons.sos_rounded, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.contactName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const Text(
                            'บันทึกในเครื่องก่อน',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.sosId != null) _buildEmergencyDeliveryStatus(),
          if (_hasUnroutedPendingMessages &&
              widget.onAssignPendingDestination != null &&
              widget.bleTransport != null)
            MaterialBanner(
              leading: const Icon(Icons.link_off_rounded),
              content: const Text(
                'Queued messages need a BLE recipient. Choose the intended peer; the app will not guess one.',
              ),
              actions: [
                TextButton(
                  onPressed: _assigningPendingDestination
                      ? null
                      : _assignPendingDestination,
                  child: Text(
                    _assigningPendingDestination
                        ? 'Assigning…'
                        : 'Choose recipient',
                  ),
                ),
              ],
            ),
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 36),
                          const SizedBox(height: 10),
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: widget.sosId == null
                                ? null
                                : () {
                                    setState(() {
                                      _loadingMessages = true;
                                      _loadError = null;
                                    });
                                    unawaited(_loadMessages(widget.sosId!));
                                  },
                            icon: const Icon(Icons.refresh),
                            label: const Text('ลองอีกครั้ง'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.sosId == null ? 'เลือกเหตุการณ์ก่อนเริ่มแชต' : 'ยังไม่มีข้อความ\nส่งข้อมูลสั้น ๆ ที่ผู้ช่วยเหลือต้องรู้',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _statusIcon(message.status),
                                    size: 13,
                                    semanticLabel: _statusLabel(message.status),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${_time(message.createdAt)} · ${_statusLabel(message.status)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ),
                                ],
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
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: 'ข้อความฉุกเฉิน',
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'พิมพ์ข้อความ…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
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

  Widget _buildEmergencyDeliveryStatus() {
    return StreamBuilder<BleOutboxData?>(
      stream: widget.sosDeliveryStream,
      builder: (context, directSnapshot) {
        return StreamBuilder<RelayStatusSnapshot>(
          stream: widget.relayStatusStream,
          builder: (context, relaySnapshot) {
            final progress = _emergencyProgress(
              directSnapshot.data,
              relaySnapshot.data,
              unavailable:
                  widget.sosDeliveryStream == null &&
                  widget.relayStatusStream == null,
              error: directSnapshot.hasError || relaySnapshot.hasError,
            );
            return Semantics(
              liveRegion: true,
              label: progress.text,
              child: Container(
                key: const ValueKey('emergency-delivery-status'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 9),
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Row(
                  children: [
                    Icon(progress.icon, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        progress.text,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  _EmergencyProgress _emergencyProgress(
    BleOutboxData? direct,
    RelayStatusSnapshot? relay, {
    required bool unavailable,
    required bool error,
  }) {
    if (error) {
      return const _EmergencyProgress(
        Icons.error_outline,
        'Delivery status is temporarily unavailable. The SOS remains saved locally.',
      );
    }
    if (unavailable) {
      return const _EmergencyProgress(
        Icons.save_outlined,
        'Saved locally. Nearby delivery is unavailable in this session.',
      );
    }
    if (direct != null) {
      final state = BleOutboxState.parse(direct.state);
      if (state == BleOutboxState.acknowledged) {
        return const _EmergencyProgress(
          Icons.done_all,
          'Confirmed stored on the selected nearby device.',
        );
      }
      if (state == BleOutboxState.awaitingAcknowledgement ||
          state == BleOutboxState.writeAccepted) {
        return const _EmergencyProgress(
          Icons.outbox_outlined,
          'Sent to a nearby device; awaiting application confirmation.',
        );
      }
    }
    if ((relay?.acceptedRelayCount ?? 0) > 0) {
      final count = relay!.acceptedRelayCount;
      return _EmergencyProgress(
        Icons.hub_outlined,
        'Stored on $count relay device${count == 1 ? '' : 's'}; final delivery is unconfirmed.',
      );
    }
    if ((relay?.pendingAttemptCount ?? 0) > 0) {
      return const _EmergencyProgress(
        Icons.bluetooth_searching,
        'Forwarding to an authenticated nearby relay.',
      );
    }
    if (direct != null) {
      final state = BleOutboxState.parse(direct.state);
      if (state == BleOutboxState.failed) {
        return _EmergencyProgress(
          Icons.error_outline,
          direct.nextRetryAt == null
              ? 'Nearby delivery failed; no retry is currently scheduled.'
              : 'Nearby delivery failed; retry is scheduled.',
        );
      }
      if (state == BleOutboxState.expired) {
        return const _EmergencyProgress(
          Icons.timer_off_outlined,
          'Nearby delivery expired without confirmation.',
        );
      }
      if (state == BleOutboxState.sending ||
          direct.destinationId?.trim().isNotEmpty == true) {
        return const _EmergencyProgress(
          Icons.send_outlined,
          'Preparing the trusted nearby route.',
        );
      }
    }
    if ((relay?.failedAttemptCount ?? 0) > 0) {
      return const _EmergencyProgress(
        Icons.refresh,
        'No relay accepted yet. The saved SOS will retry while eligible.',
      );
    }
    return const _EmergencyProgress(
      Icons.bluetooth_searching,
      'Searching for an eligible nearby device. Final delivery is unconfirmed.',
    );
  }

  String _statusLabel(ChatDeliveryStatus status) => switch (status) {
    ChatDeliveryStatus.pending => 'Queued',
    ChatDeliveryStatus.sent => 'Awaiting confirmation (sent)',
    ChatDeliveryStatus.delivered => 'Confirmed received',
    ChatDeliveryStatus.failed => 'Failed; retryable',
  };

  IconData _statusIcon(ChatDeliveryStatus status) => switch (status) {
    ChatDeliveryStatus.pending => Icons.schedule,
    ChatDeliveryStatus.sent => Icons.outbox_outlined,
    ChatDeliveryStatus.delivered => Icons.done_all,
    ChatDeliveryStatus.failed => Icons.error_outline,
  };
}

class _EmergencyProgress {
  const _EmergencyProgress(this.icon, this.text);

  final IconData icon;
  final String text;
}
