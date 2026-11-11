import '../../nearby_ble/data/user_route_repository.dart';
import '../../nearby_ble/data/route_device_names.dart';
import '../../nearby_ble/presentation/user_route_view.dart';
import 'chat_video_preview.dart';

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/localization/localization.dart';
import '../../../core/database/app_database.dart';
import '../../nearby_ble/data/hop_relay_coordinator.dart';
import '../../nearby_ble/data/ble_transport.dart';
import '../../nearby_ble/domain/ble_delivery_state.dart';
import '../../nearby_ble/presentation/ble_recipient_picker_page.dart';
import '../data/chat_repository.dart';
import '../data/media_attachment_store.dart';
import 'chat_media.dart';
import 'chat_media_compression.dart';

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
      attachmentPath: attachmentPath,
      attachmentMimeType: attachmentMimeType,
      attachmentName: attachmentName,
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
    this.contactName = 'SOS',
    this.onOpenMap,
    this.repository,
    this.onMessageCreated,
    this.onMessageCreatedWithDestination,
    this.onAssignPendingDestination,
    this.bleTransport,
    this.sosDeliveryStream,
    this.relayStatusStream,
    this.routeStream,
    this.routeDeviceNames,
    this.verifiedHelpOfferStream,
    this.locationFeedback,
    this.attachmentStore,
    this.canAttach,
    this.mediaPicker,
  });

  final String? sosId;
  final String contactName;
  final VoidCallback? onOpenMap;
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
  final Stream<UserRoutesSnapshot>? routeStream;
  final RouteDeviceNames? routeDeviceNames;
  final Stream<List<RescueResponseInboxData>>? verifiedHelpOfferStream;
  final ValueListenable<String?>? locationFeedback;
  final MediaAttachmentStore? attachmentStore;
  final Future<bool> Function()? canAttach;
  final Future<PreparedChatMedia?> Function(ChatMediaSource source)?
  mediaPicker;

  @override
  State<EmergencyChatPage> createState() => _EmergencyChatPageState();
}

class _EmergencyChatPageState extends State<EmergencyChatPage> {
  final _controller = TextEditingController();
  late final ChatRepository _repository;
  final _messages = <EmergencyChatMessage>[];
  StreamSubscription<List<EmergencyChatMessage>>? _messagesSubscription;
  StreamSubscription<UserRoutesSnapshot>? _routeSubscription;
  UserRoutesSnapshot _routes = const UserRoutesSnapshot();
  bool _routeError = false;
  bool _routesLoading = true;
  String? _selectedDestinationId;
  bool _sending = false;
  bool _picking = false;
  bool _assigningPendingDestination = false;
  bool _loadingMessages = true;
  String? _loadError;

  bool get _hasUnroutedPendingMessages => _messages.any(
    (message) =>
        message.isMine &&
        message.attachmentPath == null &&
        message.recipientId?.trim().isNotEmpty != true &&
        (message.status == ChatDeliveryStatus.pending ||
            message.status == ChatDeliveryStatus.failed),
  );

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? MockEmergencyChatRepository();
    _routeSubscription = widget.routeStream?.listen(
      (value) {
        if (mounted) {
          setState(() {
            _routes = value;
            _routeError = false;
            _routesLoading = false;
          });
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _routes = const UserRoutesSnapshot();
            _routeError = true;
            _routesLoading = false;
          });
        }
      },
    );
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
    unawaited(_recoverPicker());
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
    unawaited(_routeSubscription?.cancel() ?? Future<void>.value());
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
            SnackBar(content: Text(context.l10n.chatSavedPending)),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.chatSendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _recoverPicker() async {
    final store = widget.attachmentStore;
    final id = widget.sosId;
    if (!Platform.isAndroid || store == null || id == null) return;
    try {
      final kind = await store.pendingPicker(id);
      if (kind == null || !mounted) return;
      final source = ChatMediaSource.values.byName(kind);
      final lost = await ImagePicker().retrieveLostData();
      await store.endPicker(id);
      if (!mounted || lost.files?.isNotEmpty != true) return;
      final selected = await prepareChatMedia(
        File(lost.files!.first.path),
        video:
            source == ChatMediaSource.cameraVideo ||
            source == ChatMediaSource.libraryVideo,
      );
      if (mounted) await _attach(source, recovered: selected);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mediaText(
                context,
                'Attachment selection was interrupted. Please choose again.',
                'การเลือกไฟล์แนบถูกขัดจังหวะ กรุณาเลือกใหม่',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _attach(
    ChatMediaSource source, {
    PreparedChatMedia? recovered,
  }) async {
    final store = widget.attachmentStore;
    final sosId = widget.sosId;
    if (store == null || sosId == null || _picking || _sending) return;
    setState(() => _picking = true);
    PreparedChatMedia? selected;
    try {
      if (await widget.canAttach?.call() != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                mediaText(
                  context,
                  'Wait for a verified help offer before attaching media.',
                  'รอข้อเสนอช่วยเหลือที่ยืนยันแล้วก่อนส่งไฟล์แนบ',
                ),
              ),
            ),
          );
        }
        return;
      }
      if (recovered == null) await store.beginPicker(sosId, source.name);
      selected =
          recovered ?? await (widget.mediaPicker ?? pickChatMedia)(source);
      await store.endPicker(sosId);
      if (!mounted || selected == null) return;
      final attachmentBytes = await selected.file.length();
      if (!mounted) return;
      final sizeKb = (attachmentBytes / 1024).ceil();
      final originalBytes = selected.originalBytes;
      final savings = originalBytes != null && originalBytes > attachmentBytes
          ? ' (−${((1 - attachmentBytes / originalBytes) * 100).round()}%)'
          : '';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: Text(
            mediaText(dialog, 'Send attachment?', 'ส่งไฟล์แนบหรือไม่?'),
          ),
          content: Text(
            mediaText(
              dialog,
              'Ready to send: $sizeKb KB$savings. Photos and videos are automatically compressed. Keep both apps open during nearby transfer.',
              'พร้อมส่ง: $sizeKb KB$savings บีบอัดรูปและวิดีโออัตโนมัติแล้ว กรุณาเปิดแอปทั้งสองเครื่องไว้ระหว่างส่ง',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.l10n.send),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final id =
          'media-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';
      final saved = await store.importFile(
        id: id,
        incident: sosId,
        source: selected.file,
        mime: selected.mime,
      );
      if (!mounted) return;
      final image = selected.mime.startsWith('image/');
      final message = await _repository.insertMessage(
        sosId: sosId,
        text: image ? 'Photo' : 'Video',
        messageId: id,
        recipientId: _selectedDestinationId,
        messageType: 'media',
        attachmentPath: saved.file.path,
        attachmentMimeType: selected.mime,
        attachmentName: image ? 'Photo' : 'Video',
      );
      await widget.onMessageCreatedWithDestination?.call(
        message,
        destinationId: _selectedDestinationId,
      );
      if (mounted) await _loadMessages(sosId);
    } on Object catch (error) {
      if (kDebugMode || kProfileMode) {
        // Do not log native details, file paths, media content or identifiers.
        debugPrint(
          '[attachment] prepare_failed code=${chatMediaFailureCode(error)}',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mediaText(
                context,
                'Unable to prepare attachment. Try another photo or a video up to 15 seconds. Compression must finish before sending.',
                'เตรียมไฟล์แนบไม่สำเร็จ ลองรูปอื่นหรือวิดีโอไม่เกิน 15 วินาที ต้องบีบอัดสำเร็จก่อนส่ง',
              ),
            ),
          ),
        );
      }
    } finally {
      if (selected?.temporary == true) {
        try {
          await selected!.file.delete();
        } on Object {
          /* cache cleanup only */
        }
      }
      if (mounted) setState(() => _picking = false);
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
          SnackBar(content: Text(context.l10n.noQueuedMessagesNeedRecipient)),
        );
        return;
      }
      _selectedDestinationId = destinationId;
      await _loadMessages(sosId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.recipientAssigned(assigned))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.assignRecipientFailed(error.toString())),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigningPendingDestination = false);
    }
  }

  String _time(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(TimeOfDay.fromDateTime(value.toLocal()));

  String _sourceLabel() {
    final origins = _routes.sos
        .where((route) => route.nodes.isNotEmpty)
        .map((route) => route.nodes.first)
        .toList();
    final source = origins.firstOrNull;
    if (source != null && origins.every((node) => node.keyId == source.keyId)) {
      final alias = widget.routeDeviceNames?.labels[source.keyId];
      final name = alias?.isNotEmpty == true
          ? alias!
          : source.local
          ? routeText(context, 'this device', 'เครื่องนี้')
          : source.keyId != null
          ? '${routeText(context, 'device', 'เครื่อง')} ${shortRouteDeviceCode(source.keyId!)}'
          : null;
      if (name != null) {
        return '${routeText(context, 'SOS from', 'SOS จาก')} $name';
      }
    }
    if (widget.contactName != 'SOS' &&
        !widget.contactName.startsWith('Incident ')) {
      return widget.contactName;
    }
    return routeText(context, 'SOS source device', 'SOS จากเครื่องต้นทาง');
  }

  Widget _sourceHeading() {
    Widget label() => Text(
      _sourceLabel(),
      key: const ValueKey('chat-sos-source'),
      style: const TextStyle(fontWeight: FontWeight.w700),
    );
    final names = widget.routeDeviceNames;
    return names == null
        ? label()
        : ListenableBuilder(listenable: names, builder: (_, _) => label());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.emergencyChat)),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.sosId != null)
                        Semantics(
                          label: _sourceLabel(),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            child: Row(
                              children: [
                                const Icon(Icons.sos_rounded, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _sourceHeading(),
                                      Text(
                                        l10n.savedLocallyFirst,
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
                      if (widget.routeStream != null &&
                          widget.routeDeviceNames != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _routeError
                              ? Text(
                                  routeText(
                                    context,
                                    'Route information unavailable',
                                    'อ่านข้อมูลเส้นทางไม่ได้',
                                  ),
                                )
                              : _routesLoading
                              ? ListTile(
                                  leading: const Icon(Icons.route_rounded),
                                  title: Text(
                                    routeText(
                                      context,
                                      'Loading route',
                                      'กำลังอ่านเส้นทาง',
                                    ),
                                  ),
                                )
                              : UserRouteView(
                                  routes: _routes.sos,
                                  names: widget.routeDeviceNames!,
                                  compact: true,
                                ),
                        ),
                      if (widget.verifiedHelpOfferStream != null)
                        StreamBuilder<List<RescueResponseInboxData>>(
                          stream: widget.verifiedHelpOfferStream,
                          builder: (context, snapshot) {
                            final offers = snapshot.data ?? const [];
                            if (offers.isEmpty) return const SizedBox.shrink();
                            return Container(
                              key: const ValueKey('rescue-accepted-banner'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0xFF102A43)
                                  : const Color(0xFFDCEBFA),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.health_and_safety_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Semantics(
                                      liveRegion: true,
                                      child: Text(
                                        mediaText(
                                          context,
                                          'Rescuer accepted your SOS',
                                          'ฝ่ายกู้ภัยรับเหตุแล้ว',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (widget.locationFeedback != null)
                        ValueListenableBuilder<String?>(
                          valueListenable: widget.locationFeedback!,
                          builder: (context, message, _) => message == null
                              ? const SizedBox.shrink()
                              : Semantics(
                                  liveRegion: true,
                                  label: message,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      16,
                                      10,
                                    ),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerLow,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.location_off_outlined,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(message)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      if (_hasUnroutedPendingMessages &&
                          widget.onAssignPendingDestination != null &&
                          widget.bleTransport != null)
                        MaterialBanner(
                          leading: const Icon(Icons.link_off_rounded),
                          content: Text(l10n.chatNeedsRecipient),
                          actions: [
                            TextButton(
                              onPressed: _assigningPendingDestination
                                  ? null
                                  : _assignPendingDestination,
                              child: Text(
                                _assigningPendingDestination
                                    ? l10n.assigning
                                    : l10n.chooseRecipient,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                _messagesSliver(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  if (widget.onOpenMap != null)
                    IconButton(
                      key: const ValueKey('chat-open-map'),
                      tooltip: routeText(
                        context,
                        'View SOS map',
                        'ดูแผนที่ SOS',
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: widget.onOpenMap,
                      icon: const Icon(Icons.map_outlined),
                    ),
                  if (widget.attachmentStore != null)
                    PopupMenuButton<ChatMediaSource>(
                      tooltip: mediaText(
                        context,
                        'Attach photo or video',
                        'แนบรูปหรือวิดีโอ',
                      ),
                      enabled: !_picking && !_sending && widget.sosId != null,
                      icon: _picking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined),
                      onSelected: _attach,
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: ChatMediaSource.cameraImage,
                          child: Text(
                            mediaText(context, 'Take photo', 'ถ่ายรูป'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ChatMediaSource.libraryImage,
                          child: Text(
                            mediaText(context, 'Choose photo', 'เลือกรูป'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ChatMediaSource.cameraVideo,
                          child: Text(
                            mediaText(context, 'Record video', 'ถ่ายวิดีโอ'),
                          ),
                        ),
                        PopupMenuItem(
                          value: ChatMediaSource.libraryVideo,
                          child: Text(
                            mediaText(context, 'Choose video', 'เลือกวิดีโอ'),
                          ),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: l10n.emergencyMessage,
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: l10n.typeMessage,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: l10n.send,
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

  Widget _messagesSliver() {
    final l10n = context.l10n;
    if (_loadingMessages) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 32),
              const SizedBox(height: 8),
              Text(routeText(context, 'Loading messages', 'กำลังโหลดข้อความ')),
            ],
          ),
        ),
      );
    }
    if (_loadError != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 36),
                const SizedBox(height: 10),
                Text(_loadError!, textAlign: TextAlign.center),
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
                  label: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              widget.sosId == null
                  ? l10n.chooseIncidentBeforeChat
                  : l10n.noChatMessages,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      sliver: SliverList.builder(
        itemCount: _messages.length,
        itemBuilder: (_, index) => _messageBubble(index),
      ),
    );
  }

  Widget _messageBubble(int index) {
    final message = _messages[index];
    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: message.attachmentPath == null
                  ? Text(message.text)
                  : InkWell(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => ChatMediaViewer(
                            file: File(message.attachmentPath!),
                            mime: message.attachmentMimeType ?? 'image/png',
                          ),
                        ),
                      ),
                      child:
                          (message.attachmentMimeType ?? '').startsWith(
                            'image/',
                          )
                          ? Image.file(
                              File(message.attachmentPath!),
                              width: 220,
                              height: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Text(
                                mediaText(
                                  context,
                                  'Attachment unavailable',
                                  'ไม่พบไฟล์แนบ',
                                ),
                              ),
                            )
                          : ChatVideoPreview(
                              key: ValueKey(message.id),
                              file: File(message.attachmentPath!),
                            ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_time(context, message.createdAt)} · ${_statusLabel(context, message.status)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
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
      return _EmergencyProgress(
        Icons.error_outline,
        context.l10n.deliveryStatusUnavailable,
      );
    }
    if (unavailable) {
      return _EmergencyProgress(
        Icons.save_outlined,
        context.l10n.savedNearbyUnavailable,
      );
    }
    if (direct != null) {
      final state = BleOutboxState.parse(direct.state);
      if (state == BleOutboxState.acknowledged) {
        return _EmergencyProgress(
          Icons.done_all,
          context.l10n.directStoredConfirmed,
        );
      }
      if (state == BleOutboxState.awaitingAcknowledgement ||
          state == BleOutboxState.writeAccepted) {
        return _EmergencyProgress(
          Icons.outbox_outlined,
          context.l10n.sentAwaitingConfirmation,
        );
      }
    }
    if ((relay?.acceptedRelayCount ?? 0) > 0) {
      final count = relay!.acceptedRelayCount;
      return _EmergencyProgress(
        Icons.hub_outlined,
        context.l10n.storedOnRelay(count),
      );
    }
    if ((relay?.pendingAttemptCount ?? 0) > 0) {
      return _EmergencyProgress(
        Icons.bluetooth_searching,
        context.l10n.forwardingAuthenticatedRelay,
      );
    }
    if (direct != null) {
      final state = BleOutboxState.parse(direct.state);
      if (state == BleOutboxState.failed) {
        return _EmergencyProgress(
          Icons.error_outline,
          direct.nextRetryAt == null
              ? context.l10n.nearbyFailedNoRetry
              : context.l10n.nearbyFailedRetry,
        );
      }
      if (state == BleOutboxState.expired) {
        return _EmergencyProgress(
          Icons.timer_off_outlined,
          context.l10n.nearbyExpired,
        );
      }
      if (state == BleOutboxState.sending ||
          direct.destinationId?.trim().isNotEmpty == true) {
        return _EmergencyProgress(
          Icons.send_outlined,
          context.l10n.preparingNearbyRoute,
        );
      }
    }
    if ((relay?.failedAttemptCount ?? 0) > 0) {
      return _EmergencyProgress(Icons.refresh, context.l10n.noRelayAccepted);
    }
    return _EmergencyProgress(
      Icons.bluetooth_searching,
      context.l10n.searchingEligibleDevice,
    );
  }

  // Keep final-recipient confirmation as the boundary for Sent. Transport
  // submission alone is still waiting; failed/queued messages remain pending.
  String _statusLabel(BuildContext context, ChatDeliveryStatus status) =>
      switch (status) {
        ChatDeliveryStatus.pending ||
        ChatDeliveryStatus.failed => mediaText(context, 'Queued', 'ค้างส่ง'),
        ChatDeliveryStatus.sent => mediaText(context, 'Waiting', 'รอส่ง'),
        ChatDeliveryStatus.delivered => mediaText(context, 'Sent', 'ส่งแล้ว'),
      };
}

class _EmergencyProgress {
  const _EmergencyProgress(this.icon, this.text);

  final IconData icon;
  final String text;
}
