import 'package:flutter/material.dart';

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
  final notifications = <InAppNotification>[
    InAppNotification(
      id: 'welcome',
      title: 'Notifications are ready',
      detail: 'SOS updates will appear here.',
      createdAt: DateTime.now(),
      type: InAppNotificationType.statusChange,
    ),
  ];
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
      widget.repository ?? MockNotificationRepository();

  IconData _icon(InAppNotificationType type) => switch (type) {
    InAppNotificationType.newSos => Icons.warning_amber_rounded,
    InAppNotificationType.statusChange => Icons.sync,
    InAppNotificationType.chat => Icons.chat_bubble_outline,
  };

  @override
  Widget build(BuildContext context) {
    final items = _repository.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _repository.unreadCount == 0
                ? null
                : () => setState(_repository.markAllRead),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('No notifications yet.'))
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
                      '${item.detail}\n${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}',
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
