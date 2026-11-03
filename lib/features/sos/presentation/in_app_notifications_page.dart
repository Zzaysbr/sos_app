import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';

enum InAppNotificationType { newSos, statusChange, chat }

class InAppNotification {
  InAppNotification({
    required this.id,
    required this.title,
    required this.detail,
    required this.createdAt,
    required this.type,
    this.read = false,
    this.sosId,
  });
  final String id;
  final String title;
  final String detail;
  final DateTime createdAt;
  final InAppNotificationType type;
  bool read;
  final String? sosId;
}

class MockNotificationRepository {
  MockNotificationRepository({List<InAppNotification>? initial})
    : notifications =
          initial ??
          <InAppNotification>[
            InAppNotification(
              id: 'welcome',
              title: 'Notifications are ready',
              detail: 'SOS updates will appear here.',
              createdAt: DateTime.now(),
              type: InAppNotificationType.statusChange,
            ),
          ];

  MockNotificationRepository.empty() : notifications = <InAppNotification>[];

  final List<InAppNotification> notifications;
  int get unreadCount => notifications.where((item) => !item.read).length;
  void markRead(InAppNotification item) => item.read = true;
  void markAllRead() {
    for (final item in notifications) {
      item.read = true;
    }
  }
}

class InAppNotificationsPage extends StatefulWidget {
  const InAppNotificationsPage({super.key, this.repository, this.onOpen});
  final MockNotificationRepository? repository;
  final void Function(InAppNotification notification)? onOpen;
  @override
  State<InAppNotificationsPage> createState() => _InAppNotificationsPageState();
}

class _InAppNotificationsPageState extends State<InAppNotificationsPage> {
  late final MockNotificationRepository _repository =
      widget.repository ?? MockNotificationRepository.empty();
  bool _insertedLocalizedWelcome = false;

  IconData _icon(InAppNotificationType type) => switch (type) {
    InAppNotificationType.newSos => Icons.warning_amber_rounded,
    InAppNotificationType.statusChange => Icons.sync,
    InAppNotificationType.chat => Icons.chat_bubble_outline,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (widget.repository == null && !_insertedLocalizedWelcome) {
      _insertedLocalizedWelcome = true;
      _repository.notifications.add(
        InAppNotification(
          id: 'welcome',
          title: l10n.notificationsReady,
          detail: l10n.notificationsReadyDetail,
          createdAt: DateTime.now(),
          type: InAppNotificationType.statusChange,
        ),
      );
    }
    final items = _repository.notifications;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          TextButton(
            onPressed: _repository.unreadCount == 0
                ? null
                : () => setState(_repository.markAllRead),
            child: Text(l10n.markAllRead),
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(child: Text(l10n.noNotifications))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final item = items[index];
                return Card(
                  color: item.read
                      ? null
                      : Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: .35),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(_icon(item.type))),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${item.detail}\n${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(item.createdAt.toLocal()))}',
                    ),
                    isThreeLine: true,
                    trailing: item.read
                        ? null
                        : const Icon(Icons.fiber_manual_record, size: 12),
                    onTap: () {
                      setState(() => _repository.markRead(item));
                      widget.onOpen?.call(item);
                    },
                  ),
                );
              },
            ),
    );
  }
}
