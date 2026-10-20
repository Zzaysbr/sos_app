import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../nearby_ble/data/ble_transport.dart';
import '../../nearby_ble/data/sos_ble_coordinator.dart';
import '../../nearby_ble/presentation/ble_recipient_picker_page.dart';
import '../../nearby_ble/presentation/ble_test_page.dart';
import '../../nearby_ble/domain/ble_delivery_state.dart';
import '../../nearby_ble/domain/location_ble_envelope.dart';
import '../data/sos_repository.dart';
import '../data/chat_repository.dart';
import 'account_page.dart';
import 'emergency_chat_page.dart';
import 'in_app_notifications_page.dart';
import 'incident_map_page.dart';
import 'location_sharing_panel.dart';

import 'package:geolocator/geolocator.dart';

class SosPage extends StatefulWidget {
  const SosPage({
    super.key,
    required this.repository,
    this.bleTransport,
    this.bleCoordinator,
    this.chatRepository,
    this.onChatMessageCreated,
  });

  final SosRepository repository;
  final BleTransportClient? bleTransport;
  final SosBleCoordinator? bleCoordinator;
  final ChatRepository? chatRepository;
  final Future<void> Function(EmergencyChatMessage message)?
  onChatMessageCreated;

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  int _currentIndex = 0;
  bool _syncing = false;
  bool _sendingSos = false;
  bool _sosHoldActive = false;
  double _sosHoldProgress = 0;
  Timer? _sosHoldTimer;
  String _historyFilter = 'all';
  String _historySearch = '';
  bool _historyNewestFirst = true;
  final _historySearchController = TextEditingController();

  static const _sosHoldDuration = Duration(milliseconds: 1400);

  @override
  void dispose() {
    _sosHoldTimer?.cancel();
    _historySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHome(),
          _buildHistory(),
          _buildChat(),
          _buildSettings(),
        ],
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
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
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
      child: ColoredBox(
        color: const Color(0xFFFFFAF9),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHomeHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeCard(),
                  const SizedBox(height: 24),
                  _buildSendSosButton(),
                  const SizedBox(height: 14),
                  _buildSafetyCard(),
                  const SizedBox(height: 28),
                  _buildActiveSosSection(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 54,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 46,
                  color: const Color(0xFFD92323),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD92323),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 5),
                Text(
                  'Off Grid SOS',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Stay safe. We’re here when you need help.',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 16),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _syncing ? 'Syncing' : 'Sync pending SOS',
            onPressed: _syncing ? null : _syncPending,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              minimumSize: const Size(52, 52),
            ),
            icon: _syncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    color: Color(0xFFD92323),
                    size: 28,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return _surfaceCard(
      onTap: _showEmergencyAssistanceInfo,
      child: Row(
        children: [
          _softIcon(Icons.shield_outlined, size: 52),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency assistance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Create an SOS alert and keep track of its status from one place.',
                  style: TextStyle(color: Color(0xFF4B4746), height: 1.35),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF4B4746)),
        ],
      ),
    );
  }

  Widget _buildSendSosButton() {
    final progress = _sosHoldProgress.clamp(0.0, 1.0);
    return Semantics(
      button: true,
      label: 'Press and hold to send SOS',
      child: GestureDetector(
        onTapDown: _sendingSos ? null : (_) => _startSosHold(),
        onTapUp: _sendingSos ? null : (_) => _cancelSosHold(),
        onTapCancel: _sendingSos ? null : _cancelSosHold,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: 230,
          decoration: BoxDecoration(
            color: const Color(0xFFD92323),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD92323).withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (final size in [190.0, 145.0, 100.0])
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const CircleAvatar(
                          radius: 54,
                          backgroundColor: Colors.white,
                        ),
                        if (_sosHoldActive)
                          SizedBox(
                            width: 82,
                            height: 82,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              color: const Color(0xFFD92323),
                              backgroundColor: const Color(0xFFFCE5E4),
                            ),
                          ),
                        Icon(
                          Icons.warning_rounded,
                          size: 58,
                          color: const Color(0xFFD92323),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _sendingSos
                        ? 'SENDING SOS...'
                        : _sosHoldActive
                        ? 'KEEP HOLDING'
                        : 'SEND SOS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sendingSos
                        ? 'Getting your location'
                        : _sosHoldActive
                        ? '${((1 - progress) * 1.4).ceil()} sec'
                        : 'Tap and hold to start',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyCard() {
    return _surfaceCard(
      child: Row(
        children: [
          _softIcon(Icons.shield_outlined, size: 42),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Use SOS in an emergency.\nLocation availability depends on device settings and permissions.',
              style: TextStyle(color: Color(0xFF4B4746), height: 1.35),
            ),
          ),
          FutureBuilder<bool>(
            future: _isLocationPermissionReady(),
            builder: (context, snapshot) => Icon(
              Icons.location_on_outlined,
              color: snapshot.data == true
                  ? const Color(0xFFD92323)
                  : const Color(0xFF777777),
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceCard({required Widget child, VoidCallback? onTap}) {
    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0ECEB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    return onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: card,
            ),
          );
  }

  Widget _softIcon(IconData icon, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFFCE8E7),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Color(0xFFD92323), size: 27),
    );
  }

  Widget _buildActiveSosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'My SOS',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _currentIndex = 1),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD92323),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              label: const Text('View all'),
            ),
          ],
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

            final recent = messages.take(2).toList();

            return Column(
              children: [
                for (final sos in recent) ...[
                  _buildSosCard(sos, historyStyle: true),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  void _startSosHold() {
    if (_sendingSos || _sosHoldActive) return;
    _sosHoldTimer?.cancel();
    setState(() {
      _sosHoldActive = true;
      _sosHoldProgress = 0;
    });
    final started = DateTime.now();
    _sosHoldTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) return timer.cancel();
      final progress =
          DateTime.now().difference(started).inMilliseconds /
          _sosHoldDuration.inMilliseconds;
      if (progress >= 1) {
        timer.cancel();
        _sosHoldTimer = null;
        setState(() {
          _sosHoldActive = false;
          _sosHoldProgress = 0;
        });
        _sendSos();
      } else {
        setState(() => _sosHoldProgress = progress);
      }
    });
  }

  void _cancelSosHold() {
    if (!_sosHoldActive) return;
    _sosHoldTimer?.cancel();
    _sosHoldTimer = null;
    setState(() {
      _sosHoldActive = false;
      _sosHoldProgress = 0;
    });
  }

  Future<bool> _isLocationPermissionReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _showEmergencyAssistanceInfo() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency assistance',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 10),
              Text(
                'Press and hold the red SOS button to create an alert. Your record is saved locally first, then synchronized when the connection is available.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  Widget _buildHistory() {
    const background = Color(0xFFFFFAF9);
    return SafeArea(
      child: ColoredBox(
        color: background,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'History',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Review your SOS activity and status.',
                            style: TextStyle(
                              color: Color(0xFF777777),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Filter history',
                      onPressed: _showHistoryFilterSheet,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE8E4E3)),
                        minimumSize: const Size(52, 52),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
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
                      const SizedBox(height: 12),
                      TextField(
                        controller: _historySearchController,
                        onChanged: (value) => setState(
                          () => _historySearch = value.trim().toLowerCase(),
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search SOS ID or message',
                          suffixIcon: _historySearch.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _historySearchController.clear();
                                    setState(() => _historySearch = '');
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (filteredMessages.isEmpty)
                        _buildEmptyCard(
                          icon: _historyFilterIcon,
                          title: _historyEmptyTitle,
                          message: _historyEmptyMessage,
                          actionLabel: messages.isEmpty ? 'Send SOS' : null,
                          onAction: messages.isEmpty ? _sendSos : null,
                        )
                      else
                        for (final sos in filteredMessages) ...[
                          _buildSosCard(
                            sos,
                            showActions: true,
                            historyStyle: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistoryFilterSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Filter history',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            for (final filter in const [
              ('all', 'All', Icons.history_rounded),
              ('active', 'Active', Icons.warning_amber_rounded),
              ('resolved', 'Resolved', Icons.check_circle_outline),
              ('cancelled', 'Cancelled', Icons.cancel_outlined),
            ])
              ListTile(
                onTap: () => Navigator.pop(context, filter.$1),
                title: Text(filter.$2),
                leading: Icon(filter.$3),
                trailing: Icon(
                  _historyFilter == filter.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: _historyFilter == filter.$1
                      ? const Color(0xFFD92323)
                      : const Color(0xFFAAA4A2),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.sort),
              title: Text(
                _historyNewestFirst ? 'Newest first' : 'Oldest first',
              ),
              trailing: const Icon(Icons.swap_vert),
              onTap: () {
                Navigator.pop(context);
                setState(() => _historyNewestFirst = !_historyNewestFirst);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Reset filters'),
              onTap: () {
                Navigator.pop(context);
                _historySearchController.clear();
                setState(() {
                  _historyFilter = 'all';
                  _historySearch = '';
                  _historyNewestFirst = true;
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _historyFilter = selected);
    }
  }

  List<SosMessage> _filterHistory(List<SosMessage> messages) {
    final filtered = messages.where((message) {
      final statusMatches =
          _historyFilter == 'all' || message.status == _historyFilter;
      final queryMatches =
          _historySearch.isEmpty ||
          message.id.toLowerCase().contains(_historySearch) ||
          (message.message ?? '').toLowerCase().contains(_historySearch);
      return statusMatches && queryMatches;
    }).toList();
    filtered.sort(
      (a, b) => _historyNewestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt),
    );
    return filtered;
  }

  Widget _buildHistorySummary({
    required int total,
    required int active,
    required int resolved,
    required int cancelled,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFF0ECEB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final itemWidth = (constraints.maxWidth - spacing) / 2;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _buildHistoryCount(
                    label: 'Total',
                    description: 'All time',
                    count: total,
                    icon: Icons.history,
                    background: const Color(0xFFF4F3F8),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildHistoryCount(
                    label: 'Active',
                    description: 'Currently open',
                    count: active,
                    icon: Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                    background: const Color(0xFFFFF1F0),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildHistoryCount(
                    label: 'Resolved',
                    description: 'Completed',
                    count: resolved,
                    icon: Icons.check_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    background: const Color(0xFFF0F8F5),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _buildHistoryCount(
                    label: 'Cancelled',
                    description: 'Cancelled by you',
                    count: cancelled,
                    icon: Icons.cancel_outlined,
                    color: Theme.of(context).colorScheme.tertiary,
                    background: const Color(0xFFFFF8EC),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryCount({
    required String label,
    required int count,
    required IconData icon,
    required String description,
    required Color background,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: itemColor.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: itemColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilter() {
    return Row(
      children: [
        for (final filter in const [
          ('all', 'All'),
          ('active', 'Active'),
          ('resolved', 'Resolved'),
          ('cancelled', 'Cancelled'),
        ])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: filter.$1 == 'cancelled' ? 0 : 8),
              child: _buildHistoryFilterChip(
                value: filter.$1,
                label: filter.$2,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryFilterChip({
    required String value,
    required String label,
  }) {
    final selected = _historyFilter == value;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label history filter',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _historyFilter = value),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFCE5E4) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF2B8B5)
                  : const Color(0xFFE4E0DF),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Color(0xFFD92323),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFFD92323)
                        : const Color(0xFF4B4746),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildChat() {
    return EmergencyChatPage(
      repository: widget.chatRepository,
      onMessageCreatedWithDestination: _enqueueChat,
      bleTransport: widget.bleTransport,
    );
  }

  Future<void> _enqueueChat(
    EmergencyChatMessage message, {
    String? destinationId,
  }) async {
    final coordinator = widget.bleCoordinator;
    if (coordinator != null) {
      await coordinator.enqueueChat(message, destinationId: destinationId);
      return;
    }
    await widget.onChatMessageCreated?.call(message);
  }

  Widget _buildSettings() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(pinned: true, title: Text('Settings')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAccountCard(),
                const SizedBox(height: 28),
                _buildSettingsSection(
                  title: 'PREFERENCES',
                  children: [
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: 'SOS updates and in-app alerts',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => InAppNotificationsPage(
                            onOpen: (notification) {
                              final sosId = notification.sosId;
                              if (sosId == null) return;
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => EmergencyChatPage(
                                    sosId: sosId,
                                    repository: widget.chatRepository,
                                    onMessageCreatedWithDestination:
                                        _enqueueChat,
                                    bleTransport: widget.bleTransport,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      subtitle: 'Permission and location services',
                      onTap: _showLocationSettings,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.bluetooth_outlined,
                      title: 'BLE Test (Debug)',
                      subtitle: 'Test nearby Bluetooth between phones',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              BleTestPage(transport: widget.bleTransport),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 28,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Off Grid SOS',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Emergency communication',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'No email available';
    final currentEmail = FirebaseAuth.instance.currentUser?.email;
    final initial = (currentEmail?.isNotEmpty ?? false)
        ? currentEmail![0].toUpperCase()
        : '?';
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openAccountPage,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: Text(
                  initial,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My account',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: (verified ? colors.primary : colors.tertiary)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            verified
                                ? Icons.verified_outlined
                                : Icons.mark_email_unread_outlined,
                            size: 15,
                            color: verified ? colors.primary : colors.tertiary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            verified ? 'Email verified' : 'Email not verified',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: verified
                                  ? colors.primary
                                  : colors.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAccountPage() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const AccountPage()));
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final color = isDestructive ? colors.error : colors.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 28,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? colors.error : colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ],
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
    if (_sendingSos) {
      return;
    }

    setState(() {
      _sendingSos = true;
    });

    final id = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      String? destinationId;
      if (widget.bleTransport != null) {
        destinationId = await Navigator.of(context).push<String>(
          MaterialPageRoute<String>(
            builder: (_) =>
                BleRecipientPickerPage(transport: widget.bleTransport!),
          ),
        );
        if (!mounted) return;
      }
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
        destinationId: destinationId,
      );

      if (!mounted) {
        return;
      }

      final hasLocation = isValidSosCoordinatePair(
        position?.latitude,
        position?.longitude,
      );

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
    } finally {
      if (mounted) {
        setState(() {
          _sendingSos = false;
        });
      }
    }
  }

  Future<void> _showSosDetail(SosMessage sos) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
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
                  if (widget.bleCoordinator != null)
                    _buildBleDeliveryDetail(sos, sheetContext),
                  if (sos.status == 'active' &&
                      widget.bleCoordinator != null &&
                      widget.bleTransport != null) ...[
                    const SizedBox(height: 12),
                    LocationSharingPanel(
                      sos: sos,
                      coordinator: widget.bleCoordinator!,
                      transport: widget.bleTransport!,
                    ),
                  ],
                  if (widget.bleCoordinator != null) ...[
                    const SizedBox(height: 12),
                    StreamBuilder<LocationBleEnvelope?>(
                      stream: widget.bleCoordinator!.watchIncomingLocation(
                        sos.id,
                      ),
                      builder: (context, snapshot) {
                        final location = snapshot.data;
                        if (location == null) {
                          return const Text(
                            'No verified shared location is available for this incident.',
                            style: TextStyle(color: Color(0xFF777777)),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              icon: Icons.share_location,
                              label: 'Shared location',
                              value:
                                  '${location.latitude!.toStringAsFixed(6)}, '
                                  '${location.longitude!.toStringAsFixed(6)}\n'
                                  '${_formatDateTime(location.createdAt)}',
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => IncidentMapPage(
                                        incident: sos,
                                        incomingLocation: location,
                                        incomingSenderDeviceId:
                                            location.senderDeviceId,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('View shared location'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
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
                    value: sos.syncState == 'synced'
                        ? 'Synced'
                        : 'Pending sync',
                  ),
                  if (sos.message != null && sos.message!.isNotEmpty)
                    _buildDetailRow(
                      icon: Icons.message_outlined,
                      label: 'Message',
                      value: sos.message!,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => EmergencyChatPage(
                              sosId: sos.id,
                              repository: widget.chatRepository,
                              onMessageCreatedWithDestination: _enqueueChat,
                              bleTransport: widget.bleTransport,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Open incident chat'),
                    ),
                  ),
                  if (sos.latitude != null && sos.longitude != null) ...[
                    _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Location',
                      value:
                          '${sos.latitude!.toStringAsFixed(6)}, '
                          '${sos.longitude!.toStringAsFixed(6)}',
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => IncidentMapPage(incident: sos),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('View on map'),
                      ),
                    ),
                  ],
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
          ),
        );
      },
    );
  }

  Widget _buildBleDeliveryDetail(SosMessage sos, BuildContext sheetContext) {
    return StreamBuilder<BleOutboxData?>(
      stream: widget.bleCoordinator!.watchDeliveryForSos(sos.id),
      builder: (context, snapshot) {
        final row = snapshot.data;
        final state = row == null ? null : BleOutboxState.parse(row.state);
        final label = switch (state) {
          null => 'Waiting for recipient',
          BleOutboxState.queued =>
            row!.destinationId == null ? 'Waiting for recipient' : 'Queued',
          BleOutboxState.sending => 'Sending',
          BleOutboxState.writeAccepted ||
          BleOutboxState.awaitingAcknowledgement =>
            'Awaiting receiver confirmation',
          BleOutboxState.acknowledged => 'Confirmed received',
          BleOutboxState.failed => 'Failed; will retry',
          BleOutboxState.expired => 'Expired; retry unavailable',
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              icon: state == BleOutboxState.acknowledged
                  ? Icons.check_circle_outline
                  : Icons.bluetooth,
              label: 'BLE delivery',
              value: label,
            ),
            if (row?.destinationId != null)
              _buildDetailRow(
                icon: Icons.person_search_outlined,
                label: 'Recipient',
                value: row!.destinationId!,
              ),
            if (row != null &&
                row.destinationId == null &&
                state != BleOutboxState.acknowledged)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await Navigator.of(sheetContext)
                        .push<String>(
                          MaterialPageRoute<String>(
                            builder: (_) => BleRecipientPickerPage(
                              transport: widget.bleTransport!,
                            ),
                          ),
                        );
                    if (selected == null || !context.mounted) return;
                    try {
                      await widget.bleCoordinator!.assignSosDestination(
                        sos.id,
                        selected,
                      );
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to set recipient: $error'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_link),
                  label: const Text('Choose recipient'),
                ),
              ),
          ],
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

  // void _showComingSoon(String feature) {
  //   if (!mounted) {
  //     return;
  //   }

  //   ScaffoldMessenger.of(context)
  //       .showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  // }

  // ---------------------------------------------------------------------------
  // COMPONENTS
  // ---------------------------------------------------------------------------

  Widget _buildSosCard(
    SosMessage sos, {
    bool showActions = false,
    bool historyStyle = false,
  }) {
    final isActive = sos.status == 'active';
    final isSynced = sos.syncState == 'synced';

    final statusColor = isActive
        ? const Color(0xFFD92323)
        : sos.status == 'cancelled'
        ? const Color(0xFF9A6A13)
        : const Color(0xFF397A62);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: historyStyle ? 1 : null,
      shadowColor: Colors.black.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(historyStyle ? 20 : 12),
        side: historyStyle
            ? const BorderSide(color: Color(0xFFF0ECEB))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () {
          _showSosDetail(sos);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            historyStyle ? 20 : 16,
            16,
            historyStyle ? 14 : 16,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: historyStyle ? 56 : 42,
                    height: historyStyle ? 56 : 42,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isActive
                          ? Icons.warning_rounded
                          : sos.status == 'cancelled'
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      color: statusColor,
                      size: historyStyle ? 30 : null,
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
                      tooltip: 'SOS actions',
                      padding: EdgeInsets.zero,
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
                  historyStyle ? sos.message! : sos.message!,
                  maxLines: historyStyle ? 1 : null,
                  overflow: historyStyle ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 12),
              if (historyStyle)
                const Divider(height: 1, color: Color(0xFFEDE9E8)),
              if (historyStyle) const SizedBox(height: 12),
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
                  const Spacer(),
                  if (historyStyle)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF4B4746),
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
    String? actionLabel,
    VoidCallback? onAction,
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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sendingSos ? null : onAction,
                icon: _sendingSos
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.warning_amber_rounded),
                label: Text(_sendingSos ? 'Sending...' : actionLabel),
              ),
            ],
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
