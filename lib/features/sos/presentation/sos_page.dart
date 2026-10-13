import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../data/sos_repository.dart';

import 'package:geolocator/geolocator.dart';

class SosPage extends StatefulWidget {
  const SosPage({super.key, required this.repository});

  final SosRepository repository;

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  int _currentIndex = 0;
  bool _syncing = false;
  String _historyFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildHome(), _buildHistory(), _buildSettings()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOME
  // ---------------------------------------------------------------------------

  Widget _buildHome() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('SOS'),
            actions: [
              IconButton(
                tooltip: 'Sync',
                onPressed: _syncing ? null : _syncPending,
                icon: _syncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWelcomeCard(),
                const SizedBox(height: 24),
                _buildSendSosButton(),
                const SizedBox(height: 32),
                _buildActiveSosSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency SOS',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send an emergency alert quickly when you need help.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendSosButton() {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        onPressed: _sendSos,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_rounded, size: 56),
            SizedBox(height: 12),
            Text(
              'SEND SOS',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 4),
            Text('Emergency alert', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My SOS',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<SosMessage>>(
          stream: widget.repository.watchAll(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorCard('Unable to load SOS records.');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final messages = snapshot.data ?? [];

            if (messages.isEmpty) {
              return _buildEmptyCard(
                icon: Icons.inbox_outlined,
                title: 'No SOS yet',
                message: 'Your emergency alerts will appear here.',
              );
            }

            final active = messages
                .where((message) => message.status == 'active')
                .toList();

            if (active.isEmpty) {
              return _buildEmptyCard(
                icon: Icons.check_circle_outline,
                title: 'No active SOS',
                message: 'You currently have no active emergency alerts.',
              );
            }

            return Column(
              children: [
                for (final sos in active) ...[
                  _buildSosCard(sos),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  Widget _buildHistory() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('History')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: StreamBuilder<List<SosMessage>>(
              stream: widget.repository.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: _buildErrorCard('Unable to load SOS history.'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return SliverToBoxAdapter(
                    child: _buildEmptyCard(
                      icon: Icons.history,
                      title: 'No history',
                      message: 'SOS activity will appear here.',
                    ),
                  );
                }

                final filteredMessages = _filterHistory(messages);

                final activeCount = messages
                    .where((message) => message.status == 'active')
                    .length;

                final resolvedCount = messages
                    .where((message) => message.status == 'resolved')
                    .length;

                final cancelledCount = messages
                    .where((message) => message.status == 'cancelled')
                    .length;

                return SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHistorySummary(
                      total: messages.length,
                      active: activeCount,
                      resolved: resolvedCount,
                      cancelled: cancelledCount,
                    ),
                    const SizedBox(height: 20),
                    _buildHistoryFilter(),
                    const SizedBox(height: 20),
                    if (filteredMessages.isEmpty)
                      _buildEmptyCard(
                        icon: _historyFilterIcon,
                        title: _historyEmptyTitle,
                        message: _historyEmptyMessage,
                      )
                    else
                      for (final sos in filteredMessages) ...[
                        _buildSosCard(sos, showActions: true),
                        const SizedBox(height: 12),
                      ],
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<SosMessage> _filterHistory(List<SosMessage> messages) {
    if (_historyFilter == 'all') {
      return messages;
    }

    return messages
        .where((message) => message.status == _historyFilter)
        .toList();
  }

  Widget _buildHistorySummary({
    required int total,
    required int active,
    required int resolved,
    required int cancelled,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _buildHistoryCount(label: 'Total', count: total),
            ),
            Expanded(
              child: _buildHistoryCount(label: 'Active', count: active),
            ),
            Expanded(
              child: _buildHistoryCount(label: 'Resolved', count: resolved),
            ),
            Expanded(
              child: _buildHistoryCount(label: 'Cancelled', count: cancelled),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCount({required String label, required int count}) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildHistoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildHistoryFilterChip(value: 'all', label: 'All'),
          const SizedBox(width: 8),
          _buildHistoryFilterChip(value: 'active', label: 'Active'),
          const SizedBox(width: 8),
          _buildHistoryFilterChip(value: 'resolved', label: 'Resolved'),
          const SizedBox(width: 8),
          _buildHistoryFilterChip(value: 'cancelled', label: 'Cancelled'),
        ],
      ),
    );
  }

  Widget _buildHistoryFilterChip({
    required String value,
    required String label,
  }) {
    return FilterChip(
      label: Text(label),
      selected: _historyFilter == value,
      onSelected: (selected) {
        if (!selected) {
          return;
        }

        setState(() {
          _historyFilter = value;
        });
      },
    );
  }

  IconData get _historyFilterIcon {
    switch (_historyFilter) {
      case 'active':
        return Icons.warning_amber_rounded;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.history;
    }
  }

  String get _historyEmptyTitle {
    switch (_historyFilter) {
      case 'active':
        return 'No active SOS';
      case 'resolved':
        return 'No resolved SOS';
      case 'cancelled':
        return 'No cancelled SOS';
      default:
        return 'No history';
    }
  }

  String get _historyEmptyMessage {
    switch (_historyFilter) {
      case 'active':
        return 'You currently have no active emergency alerts.';
      case 'resolved':
        return 'No resolved SOS alerts yet.';
      case 'cancelled':
        return 'No cancelled SOS alerts yet.';
      default:
        return 'SOS activity will appear here.';
    }
  }

  Future<void> _showLocationSettings() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();

    if (!mounted) {
      return;
    }

    final permissionText = switch (permission) {
      LocationPermission.always => 'Always',
      LocationPermission.whileInUse => 'While using the app',
      LocationPermission.denied => 'Denied',
      LocationPermission.deniedForever => 'Permanently denied',
      LocationPermission.unableToDetermine => 'Unknown',
    };

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location',
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.location_on_outlined,
                  label: 'Location Services',
                  value: serviceEnabled ? 'Enabled' : 'Disabled',
                ),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.security_outlined,
                  label: 'Permission',
                  value: permissionText,
                ),
                const SizedBox(height: 8),
                if (!serviceEnabled)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                      icon: const Icon(Icons.location_on),
                      label: const Text('Open Location Settings'),
                    ),
                  ),
                if (permission == LocationPermission.deniedForever)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Geolocator.openAppSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open App Settings'),
                    ),
                  ),
                if (serviceEnabled &&
                    permission != LocationPermission.deniedForever)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SETTINGS
  // ---------------------------------------------------------------------------

  Widget _buildSettings() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('Settings')),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAccountCard(),
                const SizedBox(height: 24),
                _buildSettingsSection(
                  title: 'App',
                  children: [
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'Emergency notification settings',
                      onTap: () {
                        _showComingSoon('Notifications');
                      },
                    ),
                    _buildSettingsTile(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      subtitle: 'Location permission and sharing',
                      onTap: _showLocationSettings,
                    ),
                    _buildSettingsTile(
                      icon: Icons.bluetooth_outlined,
                      title: 'Nearby SOS',
                      subtitle: 'Offline nearby emergency communication',
                      onTap: () {
                        _showComingSoon('Nearby SOS');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSettingsSection(
                  title: 'Account',
                  children: [
                    _buildSettingsTile(
                      icon: Icons.logout,
                      title: 'Sign out',
                      subtitle: 'Sign out from this device',
                      isDestructive: true,
                      onTap: _signOut,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'SOS App',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final user = FirebaseAuth.instance.currentUser;

    final email = user?.email ?? 'Unknown account';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _showProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<Position?> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable Location Services and try again.'),
        ),
      );

      return null;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to send SOS.'),
        ),
      );

      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission is permanently denied. Enable it in Settings.',
          ),
        ),
      );

      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get your current location.')),
      );

      return null;
    }
  }

  Future<void> _showProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || !mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    child: Text(
                      (user.email?.isNotEmpty ?? false)
                          ? user.email![0].toUpperCase()
                          : '?',
                      style: Theme.of(sheetContext).textTheme.headlineSmall,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Profile',
                    style: Theme.of(sheetContext).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 24),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email ?? 'Unknown',
                ),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.fingerprint,
                  label: 'User ID',
                  value: user.uid,
                ),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.verified_user_outlined,
                  label: 'Email verified',
                  value: user.emailVerified ? 'Yes' : 'No',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                    },
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SOS ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _sendSos() async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      final position = await _getCurrentLocation();

      if (!mounted) {
        return;
      }

      await widget.repository.create(
        id: id,
        type: 'emergency',
        message: 'Emergency SOS',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      if (!mounted) {
        return;
      }

      final hasLocation = position != null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasLocation
                ? 'SOS sent with your location.'
                : 'SOS sent without location.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send SOS: $error')));
    }
  }

  Future<void> _showSosDetail(SosMessage sos) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SOS Details',
                        style: Theme.of(sheetContext).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _buildStatusChip(sos.status),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow(
                  icon: Icons.warning_amber_rounded,
                  label: 'Type',
                  value: sos.type,
                ),
                _buildDetailRow(
                  icon: Icons.schedule,
                  label: 'Created',
                  value: _formatDateTime(sos.createdAt),
                ),
                _buildDetailRow(
                  icon: Icons.update,
                  label: 'Updated',
                  value: _formatDateTime(sos.updatedAt),
                ),
                _buildDetailRow(
                  icon: sos.syncState == 'synced'
                      ? Icons.cloud_done
                      : Icons.cloud_upload_outlined,
                  label: 'Sync',
                  value: sos.syncState == 'synced' ? 'Synced' : 'Pending sync',
                ),
                if (sos.message != null && sos.message!.isNotEmpty)
                  _buildDetailRow(
                    icon: Icons.message_outlined,
                    label: 'Message',
                    value: sos.message!,
                  ),
                if (sos.latitude != null && sos.longitude != null)
                  _buildDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value:
                        '${sos.latitude!.toStringAsFixed(6)}, '
                        '${sos.longitude!.toStringAsFixed(6)}',
                  ),
                const SizedBox(height: 20),
                if (sos.status == 'active') ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _changeSosStatus(sos, 'resolved');
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as Resolved'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _changeSosStatus(sos, 'cancelled');
                      },
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel SOS'),
                    ),
                  ),
                ],
                if (sos.status != 'active')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeSosStatus(SosMessage sos, String status) async {
    final isResolved = status == 'resolved';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isResolved ? 'Resolve SOS?' : 'Cancel SOS?'),
          content: Text(
            isResolved
                ? 'Are you sure you want to mark this SOS as resolved?'
                : 'Are you sure you want to cancel this SOS?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton(
              style: !isResolved
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(dialogContext)
                          .colorScheme
                          .error,
                    )
                  : null,
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(isResolved ? 'Resolve' : 'Cancel SOS'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.repository.update(
        id: sos.id,
        type: sos.type,
        message: sos.message,
        latitude: sos.latitude,
        longitude: sos.longitude,
        status: status,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isResolved ? 'SOS marked as resolved.' : 'SOS cancelled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update SOS: $error')));
    }
  }

  Future<void> _editSos(SosMessage sos) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return _EditSosDialog(initialMessage: sos.message ?? '');
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      await widget.repository.update(
        id: sos.id,
        type: sos.type,
        message: result.isEmpty ? null : result,
        latitude: sos.latitude,
        longitude: sos.longitude,
        status: sos.status,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('SOS updated.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update SOS: $error')));
    }
  }

  Future<void> _deleteSos(SosMessage sos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete SOS?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.repository.delete(sos.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('SOS deleted.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete SOS: $error')));
    }
  }

  Future<void> _syncPending() async {
    if (_syncing) {
      return;
    }

    setState(() {
      _syncing = true;
    });

    try {
      await widget.repository.syncPending();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sync completed.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to use this account.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  void _showComingSoon(String feature) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  // ---------------------------------------------------------------------------
  // COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildSosCard(SosMessage sos, {bool showActions = false}) {
    final isActive = sos.status == 'active';
    final isSynced = sos.syncState == 'synced';

    final statusColor = isActive
        ? Colors.red.shade700
        : Theme.of(context).colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _showSosDetail(sos);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive
                          ? Icons.warning_rounded
                          : Icons.check_circle_outline,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sos.type.toUpperCase(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateTime(sos.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(sos.status),
                  if (showActions)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _editSos(sos);
                            break;
                          case 'delete':
                            _deleteSos(sos);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              if (sos.message != null && sos.message!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  sos.message!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isSynced ? Icons.cloud_done : Icons.cloud_upload_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSynced ? 'Synced' : 'Pending sync',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status == 'active';
    final isCancelled = status == 'cancelled';

    final color = isActive
        ? Colors.red.shade700
        : isCancelled
        ? Colors.orange.shade700
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${local.day}/${local.month}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

// =============================================================================
// EDIT SOS DIALOG
// =============================================================================

class _EditSosDialog extends StatefulWidget {
  const _EditSosDialog({required this.initialMessage});

  final String initialMessage;

  @override
  State<_EditSosDialog> createState() => _EditSosDialogState();
}

class _EditSosDialogState extends State<_EditSosDialog> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();

    _messageController = TextEditingController(text: widget.initialMessage);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _save() {
    Navigator.of(context).pop(_messageController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit SOS'),
      content: TextField(
        controller: _messageController,
        maxLines: 3,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          labelText: 'Message',
          hintText: 'Describe the emergency',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
