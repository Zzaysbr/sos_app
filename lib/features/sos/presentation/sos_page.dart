import 'current_sos_route_panel.dart';
import '../../nearby_ble/presentation/nearby_connection_status.dart';
import '../../nearby_ble/data/user_route_repository.dart';
import '../../nearby_ble/data/route_device_names.dart';
import '../../nearby_ble/presentation/user_route_view.dart';

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/localization/language_selector_tile.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/localization/localization.dart';
import '../../role/data/role_preference_store.dart';
import '../../role/domain/app_role.dart';
import '../../role/domain/role_workflow_controller.dart';
import '../../role/presentation/role_selection_page.dart';
import '../../role/presentation/home_mode_switch.dart';
import '../../nearby_ble/data/ble_delivery_repository.dart';
import '../../nearby_ble/data/ble_transport.dart';
import '../../nearby_ble/data/emergency_consent_store.dart';
import '../../nearby_ble/data/hop_relay_coordinator.dart';
import '../../nearby_ble/data/relay_preference_store.dart';
import '../../nearby_ble/data/rescue_inbox_repository.dart';
import '../../nearby_ble/data/rescue_response_repository.dart';
import '../../nearby_ble/data/relay_repository.dart';
import '../../nearby_ble/data/relay_key_store.dart';
import '../../nearby_ble/data/sos_ble_coordinator.dart';
import '../../nearby_ble/presentation/ble_recipient_picker_page.dart';
import '../../nearby_ble/presentation/ble_test_page.dart';
import '../../nearby_ble/presentation/relay_diagnostics_page.dart';
import '../../nearby_ble/domain/ble_delivery_state.dart';
import '../../nearby_ble/domain/location_ble_envelope.dart';
import '../../nearby_ble/domain/relay_envelope.dart';
import '../data/sos_repository.dart';
import '../data/chat_repository.dart';
import 'account_page.dart';
import 'app_version_label.dart';
import 'emergency_chat_page.dart';
import 'in_app_notifications_page.dart';
import 'incident_map_page.dart';
import 'location_sharing_panel.dart';

import 'package:geolocator/geolocator.dart';

class LocationAcquisitionException implements Exception {
  const LocationAcquisitionException(
    this.message, {
    this.category = 'unavailable',
  });

  final String category;

  final String message;
}

@visibleForTesting
String sosBleDeliveryStatusText(BleOutboxData? row) {
  final state = row == null ? null : BleOutboxState.parse(row.state);
  return switch (state) {
    null => 'Waiting for recipient',
    BleOutboxState.queued =>
      row!.destinationId == null ? 'Waiting for recipient' : 'Queued',
    BleOutboxState.sending => 'Sending',
    BleOutboxState.writeAccepted ||
    BleOutboxState.awaitingAcknowledgement => 'Awaiting receiver confirmation',
    BleOutboxState.acknowledged => 'บันทึกบนเครื่องผู้รับแล้ว',
    BleOutboxState.failed =>
      row!.nextRetryAt == null
          ? 'Delivery failed; retry not scheduled'
          : 'Failed; retry scheduled',
    BleOutboxState.expired => 'Expired; retry unavailable',
  };
}

class SosPage extends StatefulWidget {
  const SosPage({
    super.key,
    required this.repository,
    this.bleTransport,
    this.bleCoordinator,
    this.chatRepository,
    this.onChatMessageCreated,
    this.onBleStartRequested,
    this.pendingBleWorkCheck,
    this.isGuest = false,
    this.onLoginRequested,
    this.rolePreferenceStore,
    this.relayPreferenceStore,
    this.emergencyConsentStore,
    this.locationProvider,
    this.localeController,
  });

  final SosRepository repository;
  final BleTransportClient? bleTransport;
  final SosBleCoordinator? bleCoordinator;
  final ChatRepository? chatRepository;
  final Future<void> Function(EmergencyChatMessage message)?
  onChatMessageCreated;
  final Future<void> Function()? onBleStartRequested;
  final Future<bool> Function()? pendingBleWorkCheck;
  final bool isGuest;
  final VoidCallback? onLoginRequested;
  final RolePreferenceStore? rolePreferenceStore;
  final RelayPreferenceStore? relayPreferenceStore;
  final EmergencyConsentStore? emergencyConsentStore;
  final Future<Position?> Function()? locationProvider;
  final LocaleController? localeController;

  @override
  State<SosPage> createState() => _SosPageState();
}

class _SosPageState extends State<SosPage> {
  int _currentIndex = 0;
  AppRole? _role;
  AppRole? _savingRole;
  bool _loadingRole = true;
  String? _roleError;
  bool _rescueListening = false;
  bool _rescueStarting = false;
  final Object _rescueAdvertisingLease = Object();
  final Object _manualDiscoveryLease = Object();
  Timer? _manualDiscoveryTimer;
  BlePresenceManager? _blePresence;
  ValueListenable<Set<String>>? _incidentReachability;

  bool _canContactIncident(String id) =>
      _incidentReachability?.value.contains(id) ?? true;

  void _reachabilityChanged() {
    if (mounted && _role == AppRole.rescue) setState(() {});
  }

  void _bindIncidentReachability() {
    _incidentReachability?.removeListener(_reachabilityChanged);
    _incidentReachability = widget.bleCoordinator?.reachableIncidents;
    _incidentReachability?.addListener(_reachabilityChanged);
  }

  bool _syncing = false;
  bool _sendingSos = false;
  bool _openingIncidentChat = false;
  bool _checkingLocation = false;
  String? _locationCheckMessage;
  Future<Position?>? _locationRequest;
  bool _sosHoldActive = false;
  double _sosHoldProgress = 0;
  Timer? _sosHoldTimer;
  final Set<String> _stoppingFollowing = <String>{};
  String _historyFilter = 'all';
  String _historySearch = '';
  bool _historyNewestFirst = true;
  bool _historySearchVisible = false;
  final _historySearchController = TextEditingController();
  late final RolePreferenceStore _roleStore;
  late final RelayPreferenceStore _relayPreferenceStore;
  late final EmergencyConsentStore _emergencyConsentStore;
  late final Future<void> _emergencyConsentReady;
  EmergencyConsent _emergencyConsent = const EmergencyConsent.safeDefault();
  bool _emergencyConsentLoading = true;
  bool _emergencyConsentSaving = false;
  String? _emergencyConsentError;
  bool _relayParticipationEnabled = false;
  bool _relayPreferenceLoading = true;
  bool _relayPreferenceSaving = false;
  String? _relayPreferenceError;
  RouteDeviceNames? _routeNamesCache;
  late BleDeliveryRepository _deliveryRepository;
  late RescueInboxRepository _rescueInboxRepository;
  late RescueResponseRepository _rescueResponseRepository;
  late Stream<List<RescueInboxData>> _rescueCandidatesStream;
  late Stream<List<SosMessage>> _rescueSosStream;
  late Stream<List<SosMessage>> _acceptedSosStream;
  late Stream<List<SosMessage>> _activeSosStream;
  late Stream<List<SosMessage>> _historySosStream;
  late Stream<List<SosMessage>> _chatSosStream;
  late Stream<Set<String>> _rescueInboundSosIdsStream;
  late Stream<Set<String>> _acceptedInboundSosIdsStream;
  late Stream<Set<String>> _activeInboundSosIdsStream;
  late Stream<Set<String>> _chatInboundSosIdsStream;
  final RoleWorkflowController _roleWorkflow = RoleWorkflowController();

  static const _sosHoldDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _bindIncidentReachability();
    _roleStore =
        widget.rolePreferenceStore ?? const PlatformRolePreferenceStore();
    _relayPreferenceStore =
        widget.relayPreferenceStore ?? const PlatformRelayPreferenceStore();
    _emergencyConsentStore =
        widget.emergencyConsentStore ?? const PlatformEmergencyConsentStore();
    final transport = widget.bleTransport;
    if (transport != null) {
      _blePresence = BlePresenceManager.sharedFor(transport);
    }
    _deliveryRepository = BleDeliveryRepository(widget.repository.database);
    _rescueInboxRepository = RescueInboxRepository(
      widget.repository.database,
      ownerId: widget.repository.currentOwnerId ?? guestDeviceOwnerId,
    );
    _rescueResponseRepository = RescueResponseRepository(
      widget.repository.database,
      ownerId: widget.repository.currentOwnerId ?? guestDeviceOwnerId,
    );
    _rescueCandidatesStream = _rescueInboxRepository.watchCandidates();
    _bindSosStreams();
    unawaited(_loadRole());
    unawaited(_loadRelayPreference());
    _emergencyConsentReady = _loadEmergencyConsent();
  }

  Future<void> _loadEmergencyConsent() async {
    try {
      final consent = await _emergencyConsentStore.load();
      if (!mounted) return;
      setState(() {
        _emergencyConsent = consent;
        _emergencyConsentLoading = false;
        _emergencyConsentError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emergencyConsent = const EmergencyConsent.safeDefault();
        _emergencyConsentLoading = false;
        _emergencyConsentError = 'Saved emergency consent could not be read. Safe defaults remain active.';
      });
    }
  }

  Future<void> _saveEmergencyConsent(EmergencyConsent consent) async {
    if (_emergencyConsentLoading || _emergencyConsentSaving) return;
    final previous = _emergencyConsent;
    setState(() {
      _emergencyConsent = consent.copyWith(configured: true);
      _emergencyConsentSaving = true;
      _emergencyConsentError = null;
    });
    try {
      await _emergencyConsentStore.save(_emergencyConsent);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emergencyConsent = previous;
        _emergencyConsentError = 'Emergency consent could not be saved. The previous setting remains active.';
      });
    } finally {
      if (mounted) setState(() => _emergencyConsentSaving = false);
    }
  }

  Future<void> _loadRelayPreference() async {
    try {
      final enabled = await _relayPreferenceStore.loadParticipationEnabled();
      if (enabled) {
        await widget.onBleStartRequested?.call();
        await widget.bleCoordinator?.setRelayParticipationEnabled(true);
      } else {
        // Relay participation and per-incident origin consent are separate.
        // Resume a durable Public Relay SOS after restart without opting this
        // device into receiving or forwarding other people's incidents.
        if ((await widget.bleCoordinator?.hasPendingPublicRelay() ?? false) ||
            (await widget.pendingBleWorkCheck?.call() ?? false)) {
          await widget.onBleStartRequested?.call();
        }
        await widget.bleCoordinator?.setRelayParticipationEnabled(false);
      }
      if (!mounted) return;
      setState(() {
        _relayParticipationEnabled = enabled;
        _relayPreferenceLoading = false;
        _relayPreferenceError = null;
      });
    } catch (_) {
      await _forceRelayOff();
      if (!mounted) return;
      setState(() {
        _relayParticipationEnabled = false;
        _relayPreferenceLoading = false;
        _relayPreferenceError =
            'Relay remains off because its saved setting could not be applied.';
      });
    }
  }

  Future<void> _setRelayParticipation(bool enabled) async {
    if (_relayPreferenceSaving || _relayPreferenceLoading) return;
    setState(() {
      _relayPreferenceSaving = true;
      _relayPreferenceError = null;
    });
    var enableStage = 'preference';
    try {
      if (enabled) {
        await _relayPreferenceStore.saveParticipationEnabled(true);
        enableStage = 'bluetooth';
        await widget.onBleStartRequested?.call();
        enableStage = 'relay';
        await widget.bleCoordinator?.setRelayParticipationEnabled(true);
      } else {
        await widget.bleCoordinator?.setRelayParticipationEnabled(false);
        await _relayPreferenceStore.saveParticipationEnabled(false);
      }
      if (!mounted) return;
      setState(() => _relayParticipationEnabled = enabled);
    } catch (error) {
      debugPrint(
        '[SOS relay] enable failed stage=$enableStage '
        'type=${error.runtimeType}',
      );
      await _forceRelayOff();
      if (!mounted) return;
      setState(() {
        _relayParticipationEnabled = false;
        _relayPreferenceError = switch (enableStage) {
          'bluetooth' => 'Relay could not start Bluetooth. Check Nearby devices permission and Bluetooth, then try again.',
          'relay' => 'Relay could not initialize its secure queue. Expired data was kept from forwarding; restart the app and try again.',
          _ => 'Relay setting could not be saved on this device. Relay remains off.',
        };
      });
    } finally {
      if (mounted) setState(() => _relayPreferenceSaving = false);
    }
  }

  Future<void> _forceRelayOff() async {
    try {
      await widget.bleCoordinator?.setRelayParticipationEnabled(false);
    } on Object {
      // Runtime implementations are required to set the hard-disabled flag
      // before performing fallible native cleanup.
    }
    try {
      await _relayPreferenceStore.saveParticipationEnabled(false);
    } on Object {
      // Persistence failure cannot re-enable the runtime relay state.
    }
  }

  void _bindSosStreams() {
    _rescueSosStream = widget.repository.watchAll();
    _acceptedSosStream = widget.repository.watchAll();
    _activeSosStream = widget.repository.watchAll();
    _historySosStream = widget.repository.watchAll();
    _chatSosStream = widget.repository.watchAll();
    _rescueInboundSosIdsStream = _deliveryRepository.watchInboundSosIds();
    _acceptedInboundSosIdsStream = _deliveryRepository.watchInboundSosIds();
    _activeInboundSosIdsStream = _deliveryRepository.watchInboundSosIds();
    _chatInboundSosIdsStream = _deliveryRepository.watchInboundSosIds();
  }

  @override
  void didUpdateWidget(covariant SosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bleCoordinator, widget.bleCoordinator)) {
      _bindIncidentReachability();
    }
    if (!identical(oldWidget.repository, widget.repository)) {
      _deliveryRepository = BleDeliveryRepository(widget.repository.database);
      _bindSosStreams();
    }
  }

  Future<void> _loadRole() async {
    try {
      // Victim/need-help is the safe emergency default. A first-run user must
      // be able to press SOS immediately; Rescue Mode remains an explicit,
      // persistent opt-in available from Settings.
      final savedRole = await _roleStore.load();
      final role = savedRole ?? AppRole.needHelp;
      if (savedRole == null) {
        try {
          await _roleStore.save(role);
        } catch (_) {
          // A preference write failure must not block local SOS creation.
        }
      }
      if (!mounted) return;
      setState(() {
        _role = role;
        _loadingRole = false;
      });
      widget.bleCoordinator?.setRescueModeEnabled(false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        // A preference read failure must not strand a user behind a setup
        // gate during an emergency. Fall back to the least-privileged victim
        // flow; Rescue Mode still requires an explicit later opt-in.
        _role = AppRole.needHelp;
        _loadingRole = false;
        _roleError = null;
      });
      widget.bleCoordinator?.setRescueModeEnabled(false);
    }
  }

  @override
  void dispose() {
    _sosHoldTimer?.cancel();
    _manualDiscoveryTimer?.cancel();
    unawaited(
      _blePresence
              ?.releaseDiscovery(_manualDiscoveryLease)
              .catchError((Object _) {}) ??
          Future<void>.value(),
    );
    unawaited(
      _blePresence
              ?.releaseAdvertising(_rescueAdvertisingLease)
              .catchError((_) {}) ??
          Future<void>.value(),
    );
    _historySearchController.dispose();
    _incidentReachability?.removeListener(_reachabilityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_role == null) {
      return RoleSelectionPage(
        savingRole: _savingRole,
        errorText: _roleError,
        onSelected: _selectRole,
      );
    }
    final rescue = _role == AppRole.rescue;
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: rescue
            ? [
                _buildRescueHome(),
                _buildAcceptedIncidents(),
                _buildChat(),
                _buildSettings(),
              ]
            : [_buildHome(), _buildHistory(), _buildChat(), _buildSettings()],
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final compactNavigation = constraints.maxWidth < 360;
          return NavigationBar(
            height: _navigationBarHeight(context, constraints.maxWidth),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: rescue
                ? [
                    NavigationDestination(
                      icon: const Icon(Icons.radar_outlined),
                      selectedIcon: const Icon(Icons.radar),
                      label: l10n.navNearby,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.assignment_outlined),
                      selectedIcon: const Icon(Icons.assignment_turned_in),
                      label: l10n.navHelping,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.chat_bubble_outline),
                      selectedIcon: const Icon(Icons.chat_bubble),
                      label: l10n.navChat,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: l10n.navSettings,
                    ),
                  ]
                : [
                    NavigationDestination(
                      icon: Icon(Icons.sos_outlined),
                      selectedIcon: Icon(Icons.sos),
                      label: compactNavigation
                          ? l10n.navHelpCompact
                          : l10n.navHelp,
                      tooltip: l10n.navHelp,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.history_outlined),
                      selectedIcon: const Icon(Icons.history),
                      label: l10n.navHistory,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.chat_bubble_outline),
                      selectedIcon: const Icon(Icons.chat_bubble),
                      label: l10n.navChat,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: l10n.navSettings,
                    ),
                  ],
          );
        },
      ),
    );
  }

  double _navigationBarHeight(BuildContext context, double availableWidth) {
    const baseHeight = 72.0;
    if (availableWidth >= 600) return baseHeight;

    final theme = Theme.of(context);
    final labelStyle =
        NavigationBarTheme.of(context).labelTextStyle
            ?.resolve({WidgetState.selected}) ??
        theme.textTheme.labelMedium ??
        const TextStyle(fontSize: 12);
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final linePainter = TextPainter(
      text: TextSpan(text: 'กข', style: labelStyle),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    return baseHeight + (linePainter.preferredLineHeight * 2);
  }

  Future<void> _selectRole(AppRole role) async {
    if (_savingRole != null) return;
    setState(() {
      _savingRole = role;
      _roleError = null;
    });
    try {
      await _roleStore.save(role);
      if (role != AppRole.rescue && _rescueListening) {
        try {
          await _blePresence?.releaseAdvertising(_rescueAdvertisingLease);
        } on Object {
          // Aggregate presence reconciliation retries on a later BLE action.
        }
        _rescueListening = false;
      }
      if (!mounted) return;
      setState(() {
        _role = role;
        _savingRole = null;
        _currentIndex = 0;
      });
      widget.bleCoordinator?.setRescueModeEnabled(
        role == AppRole.rescue && _rescueListening,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingRole = null;
        _roleError = 'บันทึกโหมดไม่สำเร็จ กรุณาลองอีกครั้ง';
      });
    }
  }

  Future<void> _requestRoleSwitch() async {
    final target = _role == AppRole.needHelp
        ? AppRole.rescue
        : AppRole.needHelp;
    final hasActiveIncident = await widget.repository.hasActiveIncident();
    if (!mounted) return;
    if (hasActiveIncident) {
      final proceed = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.activeIncidentExists,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(context.l10n.roleSwitchPreservesData),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: Text(context.l10n.stayInMode),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        child: Text(context.l10n.switchMode),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (proceed != true) return;
    }
    await _selectRole(target);
  }

  Widget _buildRescueHome() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    const rescue = Color(0xFF1565C0);
    final rescueColor = dark ? const Color(0xFF90CAF9) : rescue;
    final background = dark ? const Color(0xFF101A2B) : const Color(0xFFEFF6FF);
    return SafeArea(
      child: ColoredBox(
        color: background,
        child: StreamBuilder<List<SosMessage>>(
          stream: _rescueSosStream,
          builder: (context, sosSnapshot) {
            if (sosSnapshot.hasError) {
              return _buildPageError('โหลดเหตุที่ได้รับไม่สำเร็จ');
            }
            return StreamBuilder<Set<String>>(
              stream: _rescueInboundSosIdsStream,
              builder: (context, inboundSnapshot) {
                if (inboundSnapshot.hasError) {
                  return _buildPageError('ตรวจสอบแหล่งที่มาของเหตุไม่สำเร็จ');
                }
                final all = sosSnapshot.data ?? const <SosMessage>[];
                final inboundIds = inboundSnapshot.data ?? const <String>{};
                final received = all
                    .where((sos) => inboundIds.contains(sos.id))
                    .toList();
                final ownActive = all.where(
                  (sos) =>
                      sos.status == 'active' && !inboundIds.contains(sos.id),
                );
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 16, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.nearbyRescueCenter,
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.8,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.receivedOnDevice,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildHomeModeSwitch(),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (ownActive.isNotEmpty) ...[
                            _buildActiveSosChatBanner(ownActive.first),
                            const SizedBox(height: 12),
                          ],
                          Material(
                            key: const ValueKey('rescue-controls-banner'),
                            color: dark
                                ? const Color(0xFF102A43)
                                : const Color(0xFFDCEBFA),
                            borderRadius: BorderRadius.circular(24),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.health_and_safety_rounded,
                                    size: 42,
                                    color: rescueColor,
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    _rescueListening
                                        ? l10n.readyForNearbyIncidents
                                        : l10n.listenWhenReady,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _rescueListening
                                        ? l10n.rescueListeningDescription
                                        : l10n.rescueOffDescription,
                                    style: const TextStyle(height: 1.4),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      key: const ValueKey(
                                        'rescue-listening-toggle',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: rescue,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: _rescueStarting
                                          ? null
                                          : _rescueListening
                                          ? _stopRescueListening
                                          : _startRescueListening,
                                      icon: _rescueStarting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              _rescueListening
                                                  ? Icons.check_circle
                                                  : Icons.bluetooth_searching,
                                            ),
                                      label: Text(
                                        _rescueStarting
                                            ? l10n.rescuePreparingBluetooth
                                            : _rescueListening
                                            ? routeText(
                                                context,
                                                'Stop receiving',
                                                'ปิดรับเหตุ',
                                              )
                                            : l10n.startRescueListening,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  NearbyConnectionStatus(
                                    transport: widget.bleTransport,
                                    verifiedPeerKey:
                                        widget.bleCoordinator?.verifiedPeerKey,
                                    onSearch: widget.bleTransport == null
                                        ? null
                                        : _searchNearby,
                                    onConnect: widget
                                        .bleCoordinator
                                        ?.connectSelectedPeer,
                                    onDisconnect: widget
                                        .bleCoordinator
                                        ?.disconnectSelectedPeer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          if (_rescueListening)
                            StreamBuilder<List<RescueInboxData>>(
                              stream: _rescueCandidatesStream,
                              builder: (context, candidateSnapshot) {
                                final candidates =
                                    (candidateSnapshot.data ??
                                            const <RescueInboxData>[])
                                        .where(
                                          (candidate) =>
                                              candidate.state !=
                                                  'archivedLocally' &&
                                              candidate.state != 'expired' &&
                                              candidate.state != 'cancelled' &&
                                              candidate.state != 'resolved' &&
                                              candidate.expiresAt.isAfter(
                                                DateTime.now().toUtc(),
                                              ) &&
                                              _canContactIncident(
                                                candidate.incidentId,
                                              ),
                                        )
                                        .toList(growable: false);
                                final archivedIds =
                                    (candidateSnapshot.data ??
                                            const <RescueInboxData>[])
                                        .where(
                                          (candidate) => const {
                                            'archivedLocally',
                                            'cancelled',
                                            'resolved',
                                            'expired',
                                          }.contains(candidate.state),
                                        )
                                        .map(
                                          (candidate) => candidate.incidentId,
                                        )
                                        .toSet();
                                final activeReceived = received
                                    .where(
                                      (sos) =>
                                          sos.status == 'active' &&
                                          !archivedIds.contains(sos.id) &&
                                          _canContactIncident(sos.id),
                                    )
                                    .toList(growable: false);
                                final existingIds = activeReceived
                                    .map((sos) => sos.id)
                                    .toSet();
                                final uniqueCandidates = candidates
                                    .where(
                                      (candidate) => !existingIds.contains(
                                        candidate.incidentId,
                                      ),
                                    )
                                    .toList(growable: false);
                                final total =
                                    activeReceived.length +
                                    uniqueCandidates.length;
                                final waitingForContact =
                                    (candidateSnapshot.data ??
                                            const <RescueInboxData>[])
                                        .any(
                                          (row) =>
                                              const {
                                                'pending',
                                                'viewed',
                                                'locallyAccepted',
                                              }.contains(row.state) &&
                                              row.expiresAt.isAfter(
                                                DateTime.now().toUtc(),
                                              ) &&
                                              !_canContactIncident(
                                                row.incidentId,
                                              ),
                                        ) ||
                                    received.any(
                                      (row) =>
                                          row.status == 'active' &&
                                          !archivedIds.contains(row.id) &&
                                          !_canContactIncident(row.id),
                                    );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          l10n.receivedIncidents,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          l10n.incidentCount(total),
                                          style: TextStyle(color: rescueColor),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (waitingForContact)
                                      _buildWaitingForContactNotice(),
                                    if (sosSnapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        inboundSnapshot.connectionState ==
                                            ConnectionState.waiting ||
                                        candidateSnapshot.connectionState ==
                                            ConnectionState.waiting)
                                      const Padding(
                                        padding: EdgeInsets.all(36),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else if (total == 0)
                                      _buildRescueEmptyState()
                                    else ...[
                                      for (final sos in activeReceived) ...[
                                        _buildRescueIncidentCard(sos),
                                        const SizedBox(height: 12),
                                      ],
                                      for (final candidate
                                          in uniqueCandidates) ...[
                                        _buildIncomingCandidateCard(candidate),
                                        const SizedBox(height: 12),
                                      ],
                                    ],
                                  ],
                                );
                              },
                            ),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildAcceptedIncidents() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      child: StreamBuilder<List<SosMessage>>(
        stream: _acceptedSosStream,
        builder: (context, snapshot) => StreamBuilder<Set<String>>(
          stream: _acceptedInboundSosIdsStream,
          builder: (context, inboundSnapshot) =>
              StreamBuilder<List<RescueInboxData>>(
                stream: _rescueCandidatesStream,
                builder: (context, candidateSnapshot) {
                  final inboundIds = inboundSnapshot.data ?? const <String>{};
                  final archivedIds =
                      (candidateSnapshot.data ?? const <RescueInboxData>[])
                          .where(
                            (candidate) => const {
                              'archivedLocally',
                              'cancelled',
                              'resolved',
                              'expired',
                            }.contains(candidate.state),
                          )
                          .map((candidate) => candidate.incidentId)
                          .toSet();
                  final accepted = (snapshot.data ?? const <SosMessage>[])
                      .where(
                        (sos) =>
                            inboundIds.contains(sos.id) &&
                            sos.status == 'active' &&
                            !archivedIds.contains(sos.id) &&
                            _roleWorkflow.isAccepted(sos.id) &&
                            _canContactIncident(sos.id),
                      )
                      .toList();
                  final acceptedCandidates =
                      (candidateSnapshot.data ?? const <RescueInboxData>[])
                          .where(
                            (candidate) =>
                                candidate.state == 'locallyAccepted' &&
                                _canContactIncident(candidate.incidentId),
                          )
                          .toList();
                  return CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        title: Text(l10n.helpingIncidents),
                        actions: [
                          IconButton(
                            tooltip: l10n.receivedHistory,
                            icon: const Icon(Icons.history_outlined),
                            onPressed: _openReceivedHistory,
                          ),
                          IconButton(
                            tooltip: l10n.switchModeTooltip,
                            onPressed: _requestRoleSwitch,
                            icon: const Icon(Icons.swap_horiz_rounded),
                          ),
                        ],
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            Text(
                              l10n.storedOnThisDevice,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.helpingStateNotice,
                              style: const TextStyle(height: 1.4),
                            ),
                            if ((candidateSnapshot.data ??
                                        const <RescueInboxData>[])
                                    .any(
                                      (row) =>
                                          row.state == 'locallyAccepted' &&
                                          !_canContactIncident(row.incidentId),
                                    ) ||
                                (snapshot.data ?? const <SosMessage>[]).any(
                                  (row) =>
                                      inboundIds.contains(row.id) &&
                                      row.status == 'active' &&
                                      _roleWorkflow.isAccepted(row.id) &&
                                      !_canContactIncident(row.id),
                                ))
                              _buildWaitingForContactNotice(),
                            const SizedBox(height: 20),
                            if (accepted.isEmpty && acceptedCandidates.isEmpty)
                              _buildEmptyCard(
                                icon: Icons.assignment_outlined,
                                title: l10n.noTrackedIncidents,
                                message: l10n.trackIncidentHint,
                                actionLabel: l10n.viewReceivedIncidents,
                                onAction: () =>
                                    setState(() => _currentIndex = 0),
                              )
                            else ...[
                              for (final sos in accepted) ...[
                                _buildRescueIncidentCard(sos),
                                const SizedBox(height: 12),
                              ],
                              for (final candidate in acceptedCandidates) ...[
                                _buildAcceptedRescueCandidateCard(candidate),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ]),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }

  String _offerDeliveryLabel(BuildContext context, String? state) =>
      switch (state) {
        'delivered' => routeText(
          context,
          'Origin device confirmed your offer',
          'เครื่องต้นทางยืนยันรับข้อเสนอแล้ว',
        ),
        'forwarded' => routeText(
          context,
          'Offer forwarded · waiting for confirmation',
          'ส่งข้อเสนอต่อแล้ว · รอยืนยัน',
        ),
        'queued' => routeText(
          context,
          'Waiting to send your help offer',
          'รอส่งข้อเสนอช่วยเหลือ',
        ),
        'failed' => routeText(
          context,
          'Help offer could not be sent',
          'ส่งข้อเสนอช่วยเหลือไม่สำเร็จ',
        ),
        'expired' => routeText(
          context,
          'Help offer delivery window ended',
          'หมดเวลาส่งข้อเสนอช่วยเหลือ',
        ),
        _ => routeText(
          context,
          'Help offer saved on this device',
          'บันทึกข้อเสนอไว้บนเครื่องนี้',
        ),
      };

  Widget _buildWaitingForContactNotice() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      routeText(
        context,
        'Waiting for the SOS source. Your help offer and chat are saved; the incident returns automatically when contact resumes.',
        'กำลังรอสัญญาณจากต้นทาง การรับช่วยเหลือและแชทยังอยู่ เหตุจะแสดงอีกครั้งอัตโนมัติเมื่อติดต่อได้',
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    ),
  );

  Widget _buildAcceptedRescueCandidateCard(RescueInboxData candidate) {
    return Card(
      key: ValueKey('accepted-rescue-candidate-${candidate.originMessageId}'),
      child: StreamBuilder<List<RescueResponseOutboxData>>(
        stream: _rescueResponseRepository.watchOutboxForIncident(
          candidate.incidentId,
        ),
        builder: (context, snapshot) {
          final state = snapshot.data != null && snapshot.data!.isNotEmpty
              ? snapshot.data!.first.state
              : null;
          final status = _offerDeliveryLabel(context, state);
          return ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: Text(candidate.emergencyType.toUpperCase()),
            subtitle: Text('${candidate.emergencyMessage}\n$status'),
            isThreeLine: true,
            onTap: () => _showRescueCandidate(candidate),
            trailing: PopupMenuButton<String>(
              key: ValueKey('stop-following-menu-${candidate.originMessageId}'),
              tooltip: context.l10n.stopFollowing,
              enabled: !_stoppingFollowing.contains(candidate.originMessageId),
              onSelected: (_) => _stopFollowing(candidate),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'stop',
                  child: Text(context.l10n.stopFollowing),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _stopFollowing(RescueInboxData candidate) async {
    if (!_stoppingFollowing.add(candidate.originMessageId)) return;
    setState(() {});
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.stopFollowingQuestion),
          content: Text(context.l10n.stopFollowingExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.back),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.stopFollowing),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _rescueInboxRepository.stopFollowing(candidate.originMessageId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.stoppedFollowing)));
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.stopFollowingFailed)),
        );
      }
    } finally {
      _stoppingFollowing.remove(candidate.originMessageId);
      if (mounted) setState(() {});
    }
  }

  void _openReceivedHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.receivedHistory)),
          body: StreamBuilder<List<RescueInboxData>>(
            stream: _rescueInboxRepository.watchCandidates(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(context.l10n.receivedHistoryError));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final candidates = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(context.l10n.receivedHistoryNotice),
                  const SizedBox(height: 16),
                  if (candidates.isEmpty)
                    Text(context.l10n.receivedHistoryEmpty),
                  for (final candidate in candidates)
                    Card(
                      key: ValueKey(
                        'rescue-history-${candidate.originMessageId}',
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(candidate.emergencyType.toUpperCase()),
                        subtitle: Text(
                          '${candidate.emergencyMessage}\n${switch (candidate.state) {
                            'archivedLocally' => context.l10n.stoppedFollowing,
                            'locallyAccepted' => context.l10n.rescueHistoryHelping,
                            'cancelled' => context.l10n.rescueHistoryCancelled,
                            'resolved' => context.l10n.rescueHistoryResolved,
                            'expired' => context.l10n.rescueHistoryExpired,
                            _ => context.l10n.storedOnThisDevice,
                          }}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showRescueCandidate(candidate),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIncomingCandidateCard(RescueInboxData candidate) {
    return Card(
      key: ValueKey('received-rescue-candidate-${candidate.incidentId}'),
      child: ListTile(
        leading: const Icon(Icons.warning_rounded),
        title: Text(candidate.emergencyType.toUpperCase()),
        subtitle: Text(candidate.emergencyMessage),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _showRescueCandidate(candidate),
      ),
    );
  }

  Widget _buildPageError(String message) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildErrorCard(message),
      ),
    ),
  );

  Widget _buildRescueEmptyState() => _buildEmptyCard(
    icon: Icons.radar_rounded,
    title: context.l10n.noReceivedIncidents,
    message: context.l10n.receivedIncidentHint,
  );

  Future<void> _showRescueCandidate(RescueInboxData candidate) async {
    var submitting = false;
    var locallyAccepted = candidate.state == 'locallyAccepted';
    final canOffer =
        candidate.state == 'pending' || candidate.state == 'viewed';
    final routeStream = _userRouteStream(candidate.incidentId);
    final routeNames = _routeNames();
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeText(sheetContext, 'SOS details', 'รายละเอียด SOS'),
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(candidate.emergencyType.toUpperCase()),
                  const SizedBox(height: 8),
                  Text(candidate.emergencyMessage),
                  const SizedBox(height: 8),
                  StreamBuilder<UserRoutesSnapshot>(
                    stream: routeStream,
                    builder: (ctx, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          routeText(
                            ctx,
                            'Route information unavailable',
                            'อ่านข้อมูลเส้นทางไม่ได้',
                          ),
                        );
                      }
                      return UserRouteView(
                        routes: snapshot.data?.sos ?? const [],
                        names: routeNames,
                        compact: true,
                      );
                    },
                  ),
                  if (candidate.includeLocation &&
                      candidate.latitude != null &&
                      candidate.longitude != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Victim location: ${candidate.latitude!.toStringAsFixed(6)}, '
                      '${candidate.longitude!.toStringAsFixed(6)}',
                    ),
                    Text(
                      'Location timestamp: ${_formatDateTime(candidate.createdAt)}',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => IncidentMapPage(
                              localParticipantRole: _role == AppRole.rescue
                                  ? 'rescue'
                                  : 'victim',
                              incident: SosMessage(
                                id: candidate.incidentId,
                                ownerId: candidate.ownerId,
                                type: candidate.emergencyType,
                                message: candidate.emergencyMessage,
                                latitude: candidate.latitude,
                                longitude: candidate.longitude,
                                status: 'active',
                                createdAt: candidate.createdAt,
                                updatedAt: candidate.receivedAt,
                                syncState: 'deviceOnly',
                              ),
                              rescueCandidate: candidate,
                              incomingLocationStream: widget.bleCoordinator
                                  ?.watchIncomingLocation(candidate.incidentId),
                              liveLocationStream: widget.bleCoordinator
                                  ?.watchLiveLocation(candidate.incidentId),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View victim location'),
                    ),
                  ] else
                    const Text('Victim location was not included in this SOS.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final incident = await _ensureRescueIncident(candidate);
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      if (mounted) await _openIncidentChat(incident);
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Open incident chat'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: !canOffer || locallyAccepted || submitting
                          ? null
                          : () async {
                              if (submitting) return;
                              setSheetState(() => submitting = true);
                              RescueInboxData? localAcceptance;
                              try {
                                localAcceptance = await _rescueInboxRepository
                                    .acceptLocally(candidate.originMessageId);
                              } on Object {
                                if (sheetContext.mounted) {
                                  setSheetState(() => submitting = false);
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to save help offer. Please try again.',
                                          ),
                                        ),
                                      );
                                }
                                return;
                              }
                              if (localAcceptance?.state != 'locallyAccepted') {
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                                return;
                              }
                              if (sheetContext.mounted) {
                                setSheetState(() => locallyAccepted = true);
                              }
                              var queued = false;
                              Object? queueError;
                              try {
                                final relay = RelayRepository(
                                  database: widget.repository.database,
                                );
                                final stored = await relay.lookupMessage(
                                  candidate.originMessageId,
                                );
                                if (stored == null) {
                                  throw StateError(
                                    'Signed origin envelope is not available locally.',
                                  );
                                }
                                final origin =
                                    RelayOfferEnvelope.fromCanonicalWire(
                                      stored.wireEnvelope,
                                    ).responseOrigin;
                                final identity = await RelayIdentityService(
                                  keyStore: PlatformRelayPrivateKeyStore(),
                                ).loadOrCreate(allowCreate: true);
                                final digest = await RelayCryptography()
                                    .immutableDigest(origin);
                                await _rescueResponseRepository.signAndEnqueueOffer(
                                  origin: origin,
                                  responder: identity,
                                  receivedSos: localAcceptance,
                                  sessionBinding:
                                      'incident-binding:${origin.originMessageId}:$digest',
                                );
                                queued = true;
                                // The signed outbox is durable. Native radio work
                                // must not keep the sheet/navigation waiting.
                                unawaited(_processQueuedHelpOffer());
                              } catch (error) {
                                queueError = error;
                              }
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, true);
                              }
                              if (mounted && !queued) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Help saved locally; delivery queued failed: $queueError',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.volunteer_activism),
                      label: Text(
                        locallyAccepted ? 'Help offered locally' : 'Offer Help',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Saving an offer records your intent. Offer delivery shows whether the origin confirmed it.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (accepted == true && mounted) {
      setState(() => _currentIndex = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Help offered locally and saved on this device.'),
        ),
      );
    }
  }

  Future<void> _processQueuedHelpOffer() async {
    try {
      await widget.bleCoordinator?.processDue();
    } on Object {
      // Keep the durably queued offer; scheduler retries are independent of UI.
      debugPrint('Help offer processing deferred; saved offer retained.');
    }
  }

  Future<SosMessage> _ensureRescueIncident(RescueInboxData candidate) {
    return widget.repository.ensureReceivedIncident(
      id: candidate.incidentId,
      type: candidate.emergencyType,
      message: candidate.emergencyMessage,
      latitude: candidate.latitude,
      longitude: candidate.longitude,
      createdAt: candidate.createdAt,
    );
  }

  Widget _buildRescueIncidentCard(SosMessage sos) {
    final theme = Theme.of(context);
    final accepted = _roleWorkflow.isAccepted(sos.id);
    final accepting = _roleWorkflow.isAccepting(sos.id);
    final age = DateTime.now().difference(sos.createdAt).abs();
    final freshness = age.inMinutes < 1
        ? 'เมื่อสักครู่'
        : age.inHours < 1
        ? '${age.inMinutes} นาทีที่ผ่านมา'
        : '${age.inHours} ชั่วโมงที่ผ่านมา';
    final stale = age > const Duration(minutes: 15);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showSosDetail(sos, rescueView: true),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_rounded,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sos.type.toUpperCase(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$freshness · ${sos.latitude == null ? 'ไม่มีพิกัดเหตุ' : 'มีพิกัดเมื่อสร้างเหตุ'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: stale
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    accepted
                        ? Icons.assignment_turned_in
                        : Icons.chevron_right_rounded,
                    color: accepted ? const Color(0xFF1565C0) : null,
                  ),
                ],
              ),
              if (stale) ...[
                const SizedBox(height: 12),
                Text(
                  'ข้อมูลเหตุเกิน 15 นาที ตำแหน่งอาจไม่ใช่ตำแหน่งปัจจุบัน',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: accepted
                    ? OutlinedButton.icon(
                        onPressed: () => _showSosDetail(sos, rescueView: true),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: Text(context.l10n.openTrackedIncident),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: accepting
                            ? null
                            : () => _acceptIncident(sos),
                        icon: accepting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.volunteer_activism_rounded),
                        label: Text(
                          accepting ? 'กำลังบันทึก...' : 'รับช่วยเหลือ',
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRescueListening() async {
    if (_rescueStarting || _rescueListening) return;
    setState(() => _rescueStarting = true);
    try {
      await _prepareBleForInteraction();
      final transport = widget.bleTransport;
      if (transport == null) {
        throw StateError('Bluetooth transport is unavailable.');
      }
      final presence = _blePresence ?? BlePresenceManager.sharedFor(transport);
      await presence.acquireAdvertising(
        _rescueAdvertisingLease,
        name: 'Emergency Rescue',
      );
      if (!mounted) return;
      widget.bleCoordinator?.setRescueModeEnabled(true);
      setState(() => _rescueListening = true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.rescueStartFailed(error.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _rescueStarting = false);
    }
  }

  Future<void> _stopRescueListening() async {
    setState(() {
      _rescueListening = false;
      _rescueStarting = true;
    });
    widget.bleCoordinator?.setRescueModeEnabled(false);
    try {
      await _blePresence?.releaseAdvertising(_rescueAdvertisingLease);
    } on Object {
      // Receiving stays off even if native advertising needs reconciliation.
      debugPrint('Rescue advertising stop deferred.');
    } finally {
      if (mounted) setState(() => _rescueStarting = false);
    }
  }

  Future<void> _acceptIncident(SosMessage sos) async {
    setState(() {});
    final accepted = await _roleWorkflow.accept(sos.id);
    if (!mounted) return;
    setState(() {});
    if (!accepted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'บันทึกไว้ใน “กำลังช่วย” บนเครื่องนี้แล้ว ยังไม่ได้ยืนยันแบบเอกสิทธิ์หรือส่งการตอบรับกลับ',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOME
  // ---------------------------------------------------------------------------

  Widget _buildHome() {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: ColoredBox(
        color: colors.surface,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHomeHeader()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([_buildActiveSosSection()]),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ขอความช่วยเหลือ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          _buildHomeModeSwitch(),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: widget.isGuest
          ? 'Guest SOS stays on this device'
          : _syncing
          ? 'Syncing'
          : 'Sync pending SOS',
      onPressed: widget.isGuest || _syncing ? null : _syncPending,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        minimumSize: const Size(52, 52),
      ),
      icon: _syncing
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sync_rounded, color: Color(0xFFD92323), size: 28),
    );
  }

  Widget _buildHomeModeSwitch() => HomeModeSwitch(
    key: const ValueKey('home-mode-switch'),
    role: _role ?? AppRole.needHelp,
    onChanged: _savingRole == null ? _requestRoleSwitch : null,
  );

  Widget _buildSendSosButton(SosMessage? active) {
    final l10n = context.l10n;
    final progress = _sosHoldProgress.clamp(0.0, 1.0);
    final cancelLabel = routeText(
      context,
      'Hold to cancel SOS',
      'กดค้างเพื่อยกเลิก SOS',
    );
    return Semantics(
      button: true,
      label: active == null ? l10n.sosHold : cancelLabel,
      hint: active == null ? l10n.holdToStart : cancelLabel,
      enabled: !_sendingSos,
      child: GestureDetector(
        onTapDown: _sendingSos ? null : (_) => _startSosHold(active),
        onTapUp: _sendingSos ? null : (_) => _cancelSosHold(),
        onTapCancel: _sendingSos ? null : _cancelSosHold,
        child: AnimatedContainer(
          key: const ValueKey('primary-sos-hold-action'),
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 280),
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
              for (final size in [224.0, 170.0, 116.0])
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
                    width: 124,
                    height: 124,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const CircleAvatar(
                          radius: 62,
                          backgroundColor: Colors.white,
                        ),
                        if (_sosHoldActive)
                          SizedBox(
                            width: 94,
                            height: 94,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              color: const Color(0xFFD92323),
                              backgroundColor: const Color(0xFFFCE5E4),
                            ),
                          ),
                        Icon(
                          Icons.warning_rounded,
                          size: 66,
                          color: const Color(0xFFD92323),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _sendingSos
                        ? l10n.creatingSos
                        : _sosHoldActive
                        ? l10n.keepHolding
                        : active != null
                        ? l10n.cancelSos
                        : l10n.sendSos,
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
                        ? l10n.checkingLocation
                        : _sosHoldActive
                        ? '${((1 - progress) * 1.4).ceil()} sec'
                        : active != null
                        ? cancelLabel
                        : l10n.holdToStart,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSosSection() {
    return StreamBuilder<List<SosMessage>>(
      stream: _activeSosStream,
      builder: (context, sosSnapshot) => StreamBuilder<Set<String>>(
        stream: _activeInboundSosIdsStream,
        builder: (context, inboundSnapshot) {
          final inboundIds = inboundSnapshot.data ?? const <String>{};
          final active =
              (sosSnapshot.data ?? const <SosMessage>[])
                  .where(
                    (sos) =>
                        inboundSnapshot.hasData &&
                        sos.status == 'active' &&
                        !inboundIds.contains(sos.id),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final current = active.firstOrNull;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (current != null) ...[
                _buildActiveSosChatBanner(current),
                const SizedBox(height: 12),
              ],
              _buildSendSosButton(current),
              if (widget.bleTransport != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: NearbyConnectionStatus(
                      transport: widget.bleTransport,
                      verifiedPeerKey: widget.bleCoordinator?.verifiedPeerKey,
                      onSearch: _searchNearby,
                      onConnect: widget.bleCoordinator?.connectSelectedPeer,
                      onDisconnect:
                          widget.bleCoordinator?.disconnectSelectedPeer,
                    ),
                  ),
                ),
              if (sosSnapshot.hasError || inboundSnapshot.hasError)
                _buildErrorCard('Unable to load the active SOS.'),
              if (current != null) ...[
                const SizedBox(height: 12),
                CurrentSosRoutePanel(
                  key: ValueKey('current-sos-route-${current.id}'),
                  incidentId: current.id,
                  repository: _userRoutes(),
                  names: _routeNames(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveSosChatBanner(SosMessage sos) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.openActiveChat,
      hint: 'เปิดห้องสนทนาของเหตุ ${sos.id}',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('active-sos-chat-banner-${sos.id}'),
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openIncidentChat(sos),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.chat_bubble, color: colors.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.activeSos,
                          style: TextStyle(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.tapToOpenIncidentChat(sos.id),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colors.onErrorContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startSosHold(SosMessage? active) {
    if (_sendingSos || _sosHoldActive) return;
    _sosHoldTimer?.cancel();
    setState(() {
      _sosHoldActive = true;
      _sosHoldProgress = 0;
    });
    _sosHoldTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (!mounted) return timer.cancel();
      final progress =
          (timer.tick * const Duration(milliseconds: 40).inMilliseconds) /
          _sosHoldDuration.inMilliseconds;
      if (progress >= 1) {
        timer.cancel();
        _sosHoldTimer = null;
        setState(() {
          _sosHoldActive = false;
          _sosHoldProgress = 0;
        });
        if (active == null) {
          unawaited(_sendSos());
        } else {
          unawaited(_changeSosStatus(active, 'cancelled', holdConfirmed: true));
        }
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

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  Widget _buildHistory() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final background = theme.colorScheme.surface;
    return SafeArea(
      child: ColoredBox(
        color: background,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.historyTitle,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _historySearchVisible
                          ? l10n.closeSearch
                          : l10n.searchHistory,
                      onPressed: () => setState(
                        () => _historySearchVisible = !_historySearchVisible,
                      ),
                      icon: Icon(
                        _historySearchVisible ? Icons.close : Icons.search,
                      ),
                    ),
                    IconButton(
                      tooltip: _historyNewestFirst
                          ? l10n.newestFirst
                          : l10n.oldestFirst,
                      onPressed: () => setState(
                        () => _historyNewestFirst = !_historyNewestFirst,
                      ),
                      icon: Icon(
                        _historyNewestFirst
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          icon: const Icon(Icons.phone_android, size: 20),
                          label: Text(l10n.deviceData),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          onPressed: _openDeviceHistory,
                        ),
                      ),
                    ),
                    _buildSyncButton(),
                  ],
                ),
              ),
            ),
            if (!widget.isGuest)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(l10n.accountHistoryPendingSync),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              sliver: StreamBuilder<List<SosMessage>>(
                stream: _historySosStream,
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
                      if (_historySearchVisible) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _historySearchController,
                          autofocus: true,
                          onChanged: (value) => setState(
                            () => _historySearch = value.trim().toLowerCase(),
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: l10n.historySearch,
                            suffixIcon: _historySearch.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: l10n.clearSearch,
                                    onPressed: () {
                                      _historySearchController.clear();
                                      setState(() => _historySearch = '');
                                    },
                                    icon: const Icon(Icons.clear),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                          _buildSosCard(sos, historyStyle: true),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('history-status-summary'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildHistoryCount(
            label: context.l10n.filterAll,
            semanticLabel: 'ประวัติทั้งหมด',
            count: total,
            filter: 'all',
            color: colors.onSurfaceVariant,
          ),
          _buildHistoryCount(
            label: context.l10n.filterActive,
            semanticLabel: 'SOS ที่กำลังดำเนินอยู่',
            count: active,
            filter: 'active',
            color: colors.error,
          ),
          _buildHistoryCount(
            label: context.l10n.filterCompleted,
            semanticLabel: 'SOS ที่สิ้นสุดแล้ว',
            count: resolved,
            filter: 'resolved',
            color: const Color(0xFF397A62),
          ),
          _buildHistoryCount(
            label: context.l10n.filterCancelled,
            semanticLabel: 'SOS ที่ยกเลิกแล้ว',
            count: cancelled,
            filter: 'cancelled',
            color: colors.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCount({
    required String label,
    required String semanticLabel,
    required int count,
    required String filter,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final selected = _historyFilter == filter;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$semanticLabel ${context.l10n.itemCount(count)}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _historyFilter = filter),
            child: Container(
              key: ValueKey('history-filter-$filter'),
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count.toString(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: selected ? color : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? color
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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
                  sheetContext.l10n.location,
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.location_on_outlined,
                  label: sheetContext.l10n.locationServices,
                  value: serviceEnabled ? 'Enabled' : 'Disabled',
                ),
                _buildProfileRow(
                  context: sheetContext,
                  icon: Icons.security_outlined,
                  label: sheetContext.l10n.permission,
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
                      label: Text(sheetContext.l10n.openLocationSettings),
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
                      label: Text(sheetContext.l10n.openAppSettings),
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
                      child: Text(sheetContext.l10n.close),
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
    if (_currentIndex != 2) return const SizedBox.shrink();
    return SafeArea(
      child: StreamBuilder<List<SosMessage>>(
        stream: _chatSosStream,
        builder: (context, sosSnapshot) => StreamBuilder<Set<String>>(
          stream: _chatInboundSosIdsStream,
          builder: (context, inboundSnapshot) {
            if (sosSnapshot.hasError || inboundSnapshot.hasError) {
              return _buildPageError('โหลดรายการแชตไม่สำเร็จ');
            }
            if (sosSnapshot.connectionState == ConnectionState.waiting ||
                inboundSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final inboundIds = inboundSnapshot.data ?? const <String>{};
            final rescue = _role == AppRole.rescue;
            final incidents =
                (sosSnapshot.data ?? const <SosMessage>[])
                    .where(
                      (sos) => rescue
                          ? inboundIds.contains(sos.id) &&
                                (sos.status != 'active' ||
                                    _canContactIncident(sos.id))
                          : !inboundIds.contains(sos.id) &&
                                sos.status == 'active',
                    )
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  title: Text(context.l10n.incidentChats),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        rescue
                            ? 'เลือกเหตุที่ได้รับเพื่อเปิดแชตให้ถูกเหตุการณ์'
                            : routeText(
                                context,
                                'Your active SOS chats. Find past conversations in History.',
                                'แชทของ SOS ที่ยังเปิดอยู่ ดูแชทเก่าได้ในประวัติ',
                              ),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (incidents.isEmpty)
                        _buildEmptyCard(
                          icon: Icons.chat_bubble_outline,
                          title: context.l10n.noChatIncidents,
                          message: rescue
                              ? 'เหตุที่รับผ่าน BLE จะปรากฏที่นี่หลังบันทึกบนอุปกรณ์สำเร็จ'
                              : routeText(
                                  context,
                                  'Start an SOS to chat. Past conversations are saved in History.',
                                  'เปิด SOS เพื่อเริ่มแชท บทสนทนาเก่ายังอยู่ในประวัติ',
                                ),
                          actionLabel: rescue
                              ? 'ดูเหตุที่ได้รับ'
                              : 'ดูประวัติ SOS',
                          onAction: () =>
                              setState(() => _currentIndex = rescue ? 0 : 1),
                        )
                      else
                        for (final sos in incidents) ...[
                          _buildChatIncidentCard(sos),
                          const SizedBox(height: 12),
                        ],
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatIncidentCard(SosMessage sos) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: context.l10n.openIncidentChatSemantics(sos.type, sos.id),
        child: InkWell(
          onTap: () => _openIncidentChat(sos),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(child: Icon(Icons.chat_bubble_outline)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sos.type.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Incident ${sos.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(sos.createdAt),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusChip(sos.status),
                    const SizedBox(height: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  UserRouteRepository _userRoutes() => UserRouteRepository(
    widget.repository.database,
    ownerId: widget.repository.currentOwnerId ?? guestDeviceOwnerId,
    readLocalKeyId: widget.bleCoordinator?.existingRelayKeyId,
  );

  Stream<UserRoutesSnapshot>? _userRouteStream(String incident) =>
      widget.bleCoordinator == null ? null : _userRoutes().watch(incident);

  RouteDeviceNames _routeNames() {
    final owner = widget.repository.currentOwnerId ?? guestDeviceOwnerId;
    if (_routeNamesCache?.ownerId != owner) {
      _routeNamesCache = RouteDeviceNames(ownerId: owner);
    }
    return _routeNamesCache!;
  }

  void _openIncidentMap(SosMessage sos) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => IncidentMapPage(
          localParticipantRole: _role == AppRole.rescue ? 'rescue' : 'victim',
          incident: sos,
          incomingLocationStream: widget.bleCoordinator?.watchIncomingLocation(
            sos.id,
          ),
          liveLocationStream: widget.bleCoordinator?.watchLiveLocation(sos.id),
        ),
      ),
    );
  }

  Future<void> _openIncidentChat(
    SosMessage sos, {
    ValueListenable<String?>? locationFeedback,
  }) async {
    if (_openingIncidentChat) return;
    _openingIncidentChat = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EmergencyChatPage(
            sosId: sos.id,
            routeStream: _userRouteStream(sos.id),
            routeDeviceNames: _routeNames(),
            onOpenMap: () => _openIncidentMap(sos),
            repository: widget.chatRepository,
            attachmentStore: widget.bleCoordinator?.mediaStore,
            canAttach: () async =>
                await widget.bleCoordinator?.canSendMedia(sos.id) == true,
            onMessageCreatedWithDestination: _enqueueChat,
            sosDeliveryStream: widget.bleCoordinator?.watchDeliveryForSos(
              sos.id,
            ),
            relayStatusStream: widget.bleCoordinator?.watchRelayStatus(sos.id),
            verifiedHelpOfferStream: _rescueResponseRepository
                .watchVerifiedOffersForIncident(sos.id),
            locationFeedback: locationFeedback,
          ),
        ),
      );
    } finally {
      _openingIncidentChat = false;
    }
  }

  Future<void> _enqueueChat(
    EmergencyChatMessage message, {
    String? destinationId,
  }) async {
    final coordinator = widget.bleCoordinator;
    if (coordinator != null) {
      // Start the foreground BLE coordinator before queueing a relay message.
      // Otherwise the message is durable but can remain queued until an
      // unrelated lifecycle event starts the transport.
      await widget.onBleStartRequested?.call();
      // Both enqueue paths schedule delivery after their durable queue write.
      // Completing the composer must not wait for the shared BLE drain, which
      // can include slow writes or retries for other queued work.
      final participant = await coordinator.resolveVerifiedChatParticipant(
        message.sosId,
      );
      if (message.attachmentPath != null && participant == null) {
        throw const ChatRepositoryException(
          'A verified helper is required for media',
        );
      }
      if (participant != null) {
        await coordinator.enqueueChatThroughRelay(
          chat: message,
          recipientKeyId: participant.keyId,
          recipientPublicKey: participant.publicKey,
        );
        return;
      }
      await coordinator.enqueueChat(message, destinationId: destinationId);
      return;
    }
    await widget.onChatMessageCreated?.call(message);
  }

  Widget _buildSettings() {
    final l10n = context.l10n;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverAppBar(pinned: true, title: Text(l10n.settingsTitle)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAccountCard(),
                const SizedBox(height: 28),
                _buildSettingsSection(
                  title: l10n.preferences,
                  children: [
                    if (widget.localeController != null) ...[
                      LanguageSelectorTile(
                        controller: widget.localeController!,
                      ),
                      const Divider(height: 1, indent: 56),
                    ],
                    _buildSettingsTile(
                      icon: _role == AppRole.rescue
                          ? Icons.health_and_safety_outlined
                          : Icons.sos_outlined,
                      title: l10n.usageMode,
                      subtitle: _role == AppRole.rescue
                          ? l10n.modeRescueDescription
                          : l10n.modeNeedHelpDescription,
                      onTap: _requestRoleSwitch,
                    ),
                    const Divider(height: 1, indent: 56),
                    _buildSettingsTile(
                      icon: Icons.notifications_outlined,
                      title: l10n.notifications,
                      subtitle: l10n.notificationsDescription,
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
                                    routeStream: _userRouteStream(sosId),
                                    routeDeviceNames: _routeNames(),
                                    repository: widget.chatRepository,
                                    attachmentStore:
                                        widget.bleCoordinator?.mediaStore,
                                    canAttach: () async =>
                                        await widget.bleCoordinator
                                            ?.canSendMedia(sosId) ==
                                        true,
                                    onMessageCreatedWithDestination:
                                        _enqueueChat,
                                    sosDeliveryStream: widget.bleCoordinator
                                        ?.watchDeliveryForSos(sosId),
                                    relayStatusStream: widget.bleCoordinator
                                        ?.watchRelayStatus(sosId),
                                    verifiedHelpOfferStream:
                                        _rescueResponseRepository
                                            .watchVerifiedOffersForIncident(
                                              sosId,
                                            ),
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
                      title: l10n.location,
                      subtitle: l10n.locationSettingsDescription,
                      onTap: _showLocationSettings,
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      key: const ValueKey('voluntary-rescue-consent'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      secondary: const Icon(Icons.volunteer_activism_outlined),
                      title: const Text(
                        'Share SOS with voluntary rescuers',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Off by default. Allows an opted-in Rescue Mode user to receive this SOS candidate.',
                      ),
                      value: _emergencyConsent.allowVoluntaryRescue,
                      onChanged:
                          _emergencyConsentLoading ||
                              _emergencyConsentSaving ||
                              !_emergencyConsent.allowPublicRelay
                          ? null
                          : (value) => _saveEmergencyConsent(
                              _emergencyConsent.copyWith(
                                allowVoluntaryRescue: value,
                              ),
                            ),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      key: const ValueKey('emergency-public-relay-consent'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      secondary: const Icon(Icons.sos_outlined),
                      title: Text(
                        l10n.automaticPublicRelay,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _emergencyConsentError ??
                            (_emergencyConsent.allowPublicRelay
                                ? l10n.automaticPublicRelayOn
                                : l10n.automaticPublicRelayOff),
                      ),
                      value: _emergencyConsent.allowPublicRelay,
                      onChanged:
                          _emergencyConsentLoading || _emergencyConsentSaving
                          ? null
                          : (value) => _saveEmergencyConsent(
                              _emergencyConsent.copyWith(
                                allowPublicRelay: value,
                                shareLocation: value
                                    ? _emergencyConsent.shareLocation
                                    : false,
                              ),
                            ),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      key: const ValueKey('emergency-location-consent'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      secondary: const Icon(Icons.location_on_outlined),
                      title: Text(
                        l10n.includeLocationRelay,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(l10n.includeLocationRelayDescription),
                      value:
                          _emergencyConsent.allowPublicRelay &&
                          _emergencyConsent.shareLocation,
                      onChanged:
                          _emergencyConsentLoading ||
                              _emergencyConsentSaving ||
                              !_emergencyConsent.allowPublicRelay
                          ? null
                          : (value) => _saveEmergencyConsent(
                              _emergencyConsent.copyWith(shareLocation: value),
                            ),
                    ),
                    ListTile(
                      key: const ValueKey('emergency-location-check'),
                      leading: const Icon(Icons.my_location),
                      title: Text(l10n.checkCurrentLocation),
                      subtitle: Semantics(
                        liveRegion: true,
                        child: Text(
                          _checkingLocation
                              ? l10n.checkingCurrentLocation
                              : (_locationCheckMessage ??
                                    l10n.checkCurrentLocationHint),
                        ),
                      ),
                      trailing: _checkingLocation
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      onTap: _checkingLocation ? null : _checkCurrentLocation,
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      secondary: const Icon(Icons.hub_outlined),
                      title: Text(
                        l10n.nearbyRelay,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _relayPreferenceError ??
                            (_relayParticipationEnabled
                                ? l10n.nearbyRelayOn
                                : l10n.nearbyRelayOff),
                      ),
                      value: _relayParticipationEnabled,
                      onChanged:
                          _relayPreferenceLoading ||
                              _relayPreferenceSaving ||
                              widget.bleCoordinator == null
                          ? null
                          : _setRelayParticipation,
                    ),
                    if (!kReleaseMode && widget.bleCoordinator != null) ...[
                      const Divider(height: 1, indent: 56),
                      _buildSettingsTile(
                        icon: Icons.monitor_heart_outlined,
                        title: l10n.relayDiagnostics,
                        subtitle: l10n.relayDiagnosticsDescription,
                        onTap: () {
                          final route = RelayDiagnosticsRoute.build(
                            dataSource: widget
                                .bleCoordinator!
                                .relayDiagnosticsDataSource,
                            runtimeDataSource: widget
                                .bleCoordinator!
                                .relayRuntimeDiagnosticsDataSource,
                          );
                          if (route != null) {
                            Navigator.of(context).push<void>(route);
                          }
                        },
                      ),
                    ],
                    // Profile builds are used for physical-device validation.
                    // Keep the development-only BLE diagnostics available in
                    // Debug/Profile, while never exposing it in Release.
                    if (!kReleaseMode) ...[
                      const Divider(height: 1, indent: 56),
                      _buildSettingsTile(
                        icon: Icons.bluetooth_outlined,
                        title: l10n.bleTest,
                        subtitle: l10n.bleTestDescription,
                        onTap: () async {
                          await _prepareBleForInteraction();
                          if (!mounted) return;
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => BleTestPage(
                                transport: widget.bleTransport,
                                runtimeDiagnostics: widget
                                    .bleCoordinator
                                    ?.relayRuntimeDiagnosticsDataSource,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
                        'Emergency',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.emergencyCommunication,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const AppVersionLabel(),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final email = widget.isGuest
        ? l10n.savedOnDevice
        : FirebaseAuth.instance.currentUser?.email ?? l10n.noEmailAvailable;
    final currentEmail = widget.isGuest
        ? null
        : FirebaseAuth.instance.currentUser?.email;
    final initial = (currentEmail?.isNotEmpty ?? false)
        ? currentEmail![0].toUpperCase()
        : '?';
    final verified =
        !widget.isGuest &&
        (FirebaseAuth.instance.currentUser?.emailVerified ?? false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.isGuest ? widget.onLoginRequested : _openAccountPage,
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
                      l10n.myAccount,
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
                        children: [
                          Icon(
                            verified
                                ? Icons.verified_outlined
                                : Icons.mark_email_unread_outlined,
                            size: 15,
                            color: verified ? colors.primary : colors.tertiary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.isGuest
                                  ? l10n.signInForCloud
                                  : verified
                                  ? l10n.emailVerified
                                  : l10n.emailNotVerified,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: verified
                                    ? colors.primary
                                    : colors.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
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

  Future<void> _checkCurrentLocation() async {
    if (_checkingLocation) return;
    final l10n = context.l10n;
    setState(() => _checkingLocation = true);
    final clock = Stopwatch()..start();
    debugPrint('[SOS location] check_started');
    try {
      final position = await _readLocation(
        timeout: const Duration(seconds: 30),
      );
      if (position == null ||
          !isValidSosCoordinatePair(position.latitude, position.longitude)) {
        throw LocationAcquisitionException(
          l10n.currentLocationUnavailable,
          category: 'invalid_fix',
        );
      }
      if (!mounted) return;
      final age = DateTime.now()
          .toUtc()
          .difference(position.timestamp.toUtc())
          .abs();
      setState(
        () => _locationCheckMessage = age > const Duration(seconds: 30)
            ? l10n.recentLocationCheckReady
            : l10n.currentLocationCheckReady,
      );
      debugPrint(
        '[SOS location] check_succeeded elapsedMs=${clock.elapsedMilliseconds}',
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _locationCheckMessage = error is LocationAcquisitionException
            ? error.message
            : l10n.currentLocationUnavailable,
      );
      debugPrint(
        '[SOS location] check_failed category=${_locationErrorCategory(error)} elapsedMs=${clock.elapsedMilliseconds}',
      );
    } finally {
      if (mounted) setState(() => _checkingLocation = false);
    }
  }

  String _locationErrorCategory(Object error) =>
      error is LocationAcquisitionException
      ? error.category
      : error is TimeoutException
      ? 'timed_out'
      : 'provider_error';

  Future<Position?> _readLocation({
    Duration timeout = const Duration(seconds: 15),
  }) {
    // CoreLocation uses a one-shot request handler. Share a check already in
    // progress instead of overwriting it when SOS is pressed during the check.
    final l10n = context.l10n;
    var request = _locationRequest;
    if (request == null) {
      request = Future<Position?>.sync(
        () =>
            widget.locationProvider?.call() ??
            _getCurrentLocation(timeout: timeout),
      );
      _locationRequest = request;
      final current = request;
      void clear() {
        if (identical(_locationRequest, current)) _locationRequest = null;
      }

      unawaited(
        request.then<void>(
          (_) => clear(),
          onError: (Object _, StackTrace _) => clear(),
        ),
      );
    }
    // Keep a stalled platform result bounded, including last-known fallback.
    return request.timeout(
      timeout + const Duration(seconds: 5),
      onTimeout: () => throw LocationAcquisitionException(
        l10n.locationTimedOut,
        category: 'timed_out',
      ),
    );
  }

  Future<Position?> _getCurrentLocation({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final l10n = context.l10n;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw LocationAcquisitionException(
        l10n.locationServicesDisabled,
        category: 'services_disabled',
      );
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw LocationAcquisitionException(
        l10n.locationPermissionRequired,
        category: 'permission_denied',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationAcquisitionException(
        l10n.locationPermissionDeniedForever,
        category: 'permission_denied_forever',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      final recent = await _recentUsableLastKnownPosition();
      if (recent != null) return recent;
      throw LocationAcquisitionException(
        l10n.locationTimedOut,
        category: 'timed_out',
      );
    } catch (_) {
      final recent = await _recentUsableLastKnownPosition();
      if (recent != null) return recent;
      throw LocationAcquisitionException(l10n.currentLocationUnavailable);
    }
  }

  Future<Position?> _recentUsableLastKnownPosition() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null ||
          !isValidSosCoordinatePair(position.latitude, position.longitude) ||
          !position.accuracy.isFinite ||
          position.accuracy > 500) {
        return null;
      }
      final age = DateTime.now().toUtc().difference(position.timestamp).abs();
      if (age > const Duration(minutes: 5)) return null;
      return position;
    } on Object {
      return null;
    }
  }

  String _locationFailureMessage(Object error, AppLocalizations l10n) {
    final reason = error is LocationAcquisitionException
        ? error.message
        : l10n.currentLocationUnavailable;
    return '${l10n.locationUnavailableSaved} ($reason)';
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

  Future<void> _prepareBleForInteraction() async {
    try {
      // Subscribe the coordinator before the picker/debug page can establish a
      // native connection. Broadcast connection events cannot be replayed later.
      await widget.onBleStartRequested?.call();
    } catch (_) {
      // Permission/startup failure must still allow local SOS creation.
      debugPrint('BLE startup unavailable; local SOS remains available.');
    }
  }

  Future<void> _searchNearby() async {
    final presence = _blePresence;
    if (presence == null) return;
    await widget.onBleStartRequested?.call();
    if (!mounted) return;
    await presence.acquireDiscovery(_manualDiscoveryLease);
    _manualDiscoveryTimer?.cancel();
    if (!mounted) {
      await presence.releaseDiscovery(_manualDiscoveryLease);
      return;
    }
    _manualDiscoveryTimer = Timer(const Duration(seconds: 30), () {
      unawaited(
        presence
            .releaseDiscovery(_manualDiscoveryLease)
            .catchError((Object _) {}),
      );
    });
  }

  Future<void> _beginAutomaticEmergencyRouting(
    SosMessage sos,
    EmergencyConsent consent,
    ValueNotifier<String?> locationFeedback,
  ) async {
    final l10n = context.l10n;
    final routingClock = Stopwatch()..start();
    try {
      var routedSos = sos;
      var includeLocation = false;
      if (consent.shareLocation) {
        // Location acquisition is deliberately after local SOS persistence and
        // Chat navigation. A slow GPS, denied permission, or offline device
        // must never prevent the emergency record from being created.
        Position? position;
        var acquisitionFailed = false;
        final locationClock = Stopwatch()..start();
        debugPrint('[SOS location] acquisition_started');
        try {
          position = await _readLocation();
        } catch (error) {
          // A failed location attempt must not cancel BLE routing or change
          // the already-persisted SOS into a failed creation.
          acquisitionFailed = true;
          debugPrint(
            '[SOS location] acquisition_failed category=${_locationErrorCategory(error)} elapsedMs=${locationClock.elapsedMilliseconds}',
          );
          locationFeedback.value = _locationFailureMessage(error, l10n);
        }
        if (position != null &&
            isValidSosCoordinatePair(position.latitude, position.longitude)) {
          try {
            await widget.repository.update(
              id: sos.id,
              type: sos.type,
              message: sos.message,
              latitude: position.latitude,
              longitude: position.longitude,
              status: sos.status,
            );
            routedSos = await widget.repository.findById(sos.id) ?? sos;
            includeLocation = true;
            debugPrint(
              '[SOS timing] sos_location_ready incident=${sos.id} '
              'elapsedMs=${routingClock.elapsedMilliseconds}',
            );
          } catch (error) {
            debugPrint(
              '[SOS location] update failed type=${error.runtimeType}',
            );
          }
        } else if (!acquisitionFailed) {
          locationFeedback.value = _locationFailureMessage(
            LocationAcquisitionException(l10n.currentLocationUnavailable),
            l10n,
          );
        }
      }
      if (consent.allowPublicRelay) {
        final coordinator = widget.bleCoordinator;
        if (coordinator == null) {
          throw StateError('Public relay is unavailable on this device.');
        }
        // Persist the signed relay job before starting native discovery. A
        // permission or Bluetooth failure cannot erase the local SOS or job.
        await coordinator.enqueuePublicRelay(
          routedSos,
          includeLocation: includeLocation,
          scope: consent.allowVoluntaryRescue
              ? RelayAuthorizationScope.voluntaryRescue
              : RelayAuthorizationScope.publicEmergencyRelay,
        );
        debugPrint(
          '[SOS timing] sos_relay_enqueued incident=${sos.id} '
          'elapsedMs=${routingClock.elapsedMilliseconds}',
        );
      }
      await widget.onBleStartRequested?.call();
    } catch (error) {
      debugPrint('[SOS auto-route] startup failed type=${error.runtimeType}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SOS is saved locally. Nearby delivery is waiting for Bluetooth permission or a compatible device.',
          ),
        ),
      );
    }
  }

  Future<void> _sendSos() async {
    if (_sendingSos) {
      return;
    }
    final creationClock = Stopwatch()..start();
    debugPrint('[SOS timing] sos_create_started');
    setState(() {
      _sendingSos = true;
    });

    try {
      final messages = await widget.repository.listActiveIncidents();
      final inboundIds = await _deliveryRepository.listInboundSosIds();
      if (!mounted) return;
      final activeOwn = messages.where(
        (sos) => sos.status == 'active' && !inboundIds.contains(sos.id),
      );
      if (activeOwn.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'มี SOS ที่กำลังดำเนินอยู่แล้ว เปิดเหตุเดิมแทนการสร้างรายการซ้ำ',
            ),
          ),
        );
        await _openIncidentChat(activeOwn.first);
        return;
      }

      await _emergencyConsentReady;
      if (!mounted) return;
      final consent = _emergencyConsent;
      final id = DateTime.now().microsecondsSinceEpoch.toString();

      await widget.repository.create(
        id: id,
        type: 'emergency',
        message: 'Emergency SOS',
        // Location is attached asynchronously after the SOS is persisted.
        // This keeps SOS creation independent from GPS, permission and
        // network availability.
        latitude: null,
        longitude: null,
        // Direct v1 deliberately stays unrouted until a trustworthy incident
        // route exists. Public Relay v2 performs its own authenticated,
        // capability-gated discovery below.
        destinationId: null,
      );
      debugPrint(
        '[SOS timing] sos_local_persisted incident=$id '
        'elapsedMs=${creationClock.elapsedMilliseconds}',
      );

      final created = await widget.repository.findById(id);
      if (created == null) {
        throw StateError('The saved SOS could not be reopened.');
      }

      // Navigation does not wait for scanning, session proof, connection or
      // acknowledgement. The same persisted incident/message identities are
      // used if a route becomes available later.
      final locationFeedback = ValueNotifier<String?>(null);
      unawaited(
        _beginAutomaticEmergencyRouting(created, consent, locationFeedback),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            consent.allowPublicRelay
                ? context.l10n.sosSavedRelaySearching
                : context.l10n.sosSavedLocally,
          ),
        ),
      );
      await _openIncidentChat(created, locationFeedback: locationFeedback);
      debugPrint(
        '[SOS timing] sos_chat_opened incident=$id '
        'elapsedMs=${creationClock.elapsedMilliseconds}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.sosSendFailed(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingSos = false;
        });
      }
    }
  }

  void _openDeviceHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.deviceHistory)),
          body: StreamBuilder<List<SosMessage>>(
            stream: widget.repository.watchDeviceHistory(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildErrorCard('Unable to load device history.');
              }
              final rows = snapshot.data ?? const <SosMessage>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(context.l10n.guestHistoryNotice),
                  const SizedBox(height: 16),
                  if (rows.isEmpty) Text(context.l10n.noGuestHistory),
                  for (final row in rows) ...[
                    _buildSosCard(row, readOnly: true),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showSosDetail(
    SosMessage sos, {
    bool readOnly = false,
    bool rescueView = false,
  }) async {
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
                          sheetContext.l10n.sosDetails,
                          style: Theme.of(sheetContext).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _buildStatusChip(sos.status),
                      if (!readOnly && !rescueView)
                        PopupMenuButton<String>(
                          tooltip: sheetContext.l10n.manageSos,
                          onSelected: (value) {
                            Navigator.of(sheetContext).pop();
                            if (value == 'edit') {
                              unawaited(_editSos(sos));
                            } else if (value == 'delete') {
                              unawaited(_deleteSos(sos));
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(context.l10n.editMessage),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(context.l10n.deleteSos),
                            ),
                          ],
                        ),
                      IconButton(
                        tooltip: sheetContext.l10n.closeSosDetails,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (rescueView || _role == AppRole.rescue)
                    _buildDetailRow(
                      icon: Icons.warning_amber_rounded,
                      label: sheetContext.l10n.type,
                      value: sos.type,
                    ),
                  if (!readOnly && !rescueView && widget.bleCoordinator != null)
                    _buildBleDeliveryDetail(sos, sheetContext),
                  if (!readOnly && !rescueView && widget.bleCoordinator != null)
                    _buildRelayDeliveryDetail(sos),
                  if (!readOnly && !rescueView)
                    _buildDetailRow(
                      icon: Icons.volunteer_activism_outlined,
                      label: sheetContext.l10n.humanResponse,
                      value: sheetContext.l10n.noHumanConfirmation,
                    ),
                  if (rescueView)
                    _buildDetailRow(
                      icon: _roleWorkflow.isAccepted(sos.id)
                          ? Icons.assignment_turned_in
                          : Icons.assignment_outlined,
                      label: sheetContext.l10n.responderStatus,
                      value: _roleWorkflow.isAccepted(sos.id)
                          ? 'รับติดตามบนอุปกรณ์นี้แล้ว ไม่ใช่การมอบหมายแบบเอกสิทธิ์และยังไม่ได้ตอบกลับผู้ประสบภัย'
                          : 'ยังไม่ได้รับติดตามบนอุปกรณ์นี้ การรับผ่าน BLE ไม่ใช่การตอบรับจากผู้ช่วยเหลือ',
                    ),
                  if (!readOnly &&
                      sos.status == 'active' &&
                      widget.bleCoordinator != null &&
                      widget.bleTransport != null) ...[
                    const SizedBox(height: 12),
                    LocationSharingPanel(
                      sos: sos,
                      coordinator: widget.bleCoordinator!,
                      transport: widget.bleTransport!,
                      participantRole: rescueView ? 'rescue' : 'victim',
                      automaticRefresh: true,
                      onBleStartRequested: widget.onBleStartRequested,
                    ),
                  ],
                  if (!readOnly && widget.bleCoordinator != null) ...[
                    const SizedBox(height: 12),
                    StreamBuilder<LocationBleEnvelope?>(
                      stream: widget.bleCoordinator!.watchIncomingLocation(
                        sos.id,
                      ),
                      builder: (context, snapshot) {
                        final location = snapshot.data;
                        if (location == null) {
                          return Text(
                            sheetContext.l10n.noVerifiedSharedLocation,
                            style: const TextStyle(color: Color(0xFF777777)),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              icon: Icons.share_location,
                              label: sheetContext.l10n.sharedLocation,
                              value:
                                  '${location.latitude!.toStringAsFixed(6)}, '
                                  '${location.longitude!.toStringAsFixed(6)}\n'
                                  '${_formatDateTime(location.createdAt)}',
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  // Keep the sharing panel mounted while its map is open.
                                  Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => IncidentMapPage(
                                        localParticipantRole:
                                            _role == AppRole.rescue
                                            ? 'rescue'
                                            : 'victim',
                                        incident: sos,
                                        incomingLocation: location,
                                        incomingSenderDeviceId:
                                            location.senderDeviceId,
                                        incomingLocationStream: widget
                                            .bleCoordinator
                                            ?.watchIncomingLocation(sos.id),
                                        liveLocationStream: widget
                                            .bleCoordinator
                                            ?.watchLiveLocation(sos.id),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.map_outlined),
                                label: Text(
                                  sheetContext.l10n.viewSharedLocation,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                  _buildDetailRow(
                    icon: Icons.schedule,
                    label: sheetContext.l10n.created,
                    value: _formatDateTime(sos.createdAt),
                  ),
                  _buildDetailRow(
                    icon: Icons.update,
                    label: sheetContext.l10n.updated,
                    value: _formatDateTime(sos.updatedAt),
                  ),
                  _buildDetailRow(
                    icon: sos.ownerId == guestDeviceOwnerId
                        ? Icons.phone_android
                        : sos.syncState == 'synced'
                        ? Icons.cloud_done
                        : Icons.cloud_upload_outlined,
                    label: sheetContext.l10n.sync,
                    value: sos.ownerId == guestDeviceOwnerId
                        ? sheetContext.l10n.deviceOnly
                        : sos.syncState == 'synced'
                        ? sheetContext.l10n.synced
                        : sheetContext.l10n.pendingSync,
                  ),
                  if ((rescueView || _role == AppRole.rescue) &&
                      sos.message != null &&
                      sos.message!.isNotEmpty)
                    _buildDetailRow(
                      icon: Icons.message_outlined,
                      label: sheetContext.l10n.message,
                      value: sos.message!,
                    ),
                  const SizedBox(height: 12),
                  if (!readOnly || rescueView)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => EmergencyChatPage(
                                sosId: sos.id,
                                onOpenMap: () => _openIncidentMap(sos),
                                routeStream: _userRouteStream(sos.id),
                                routeDeviceNames: _routeNames(),
                                repository: widget.chatRepository,
                                attachmentStore:
                                    widget.bleCoordinator?.mediaStore,
                                canAttach: () async =>
                                    await widget.bleCoordinator?.canSendMedia(
                                      sos.id,
                                    ) ==
                                    true,
                                onMessageCreatedWithDestination: _enqueueChat,
                                sosDeliveryStream: widget.bleCoordinator
                                    ?.watchDeliveryForSos(sos.id),
                                relayStatusStream: widget.bleCoordinator
                                    ?.watchRelayStatus(sos.id),
                                verifiedHelpOfferStream:
                                    _rescueResponseRepository
                                        .watchVerifiedOffersForIncident(sos.id),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(sheetContext.l10n.openIncidentChat),
                      ),
                    ),
                  if (sos.latitude != null && sos.longitude != null) ...[
                    _buildDetailRow(
                      icon: Icons.location_on_outlined,
                      label: sheetContext.l10n.location,
                      value:
                          '${sos.latitude!.toStringAsFixed(6)}, '
                          '${sos.longitude!.toStringAsFixed(6)}',
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Keep the sharing panel mounted while its map is open.
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => IncidentMapPage(
                                localParticipantRole: _role == AppRole.rescue
                                    ? 'rescue'
                                    : 'victim',
                                incident: sos,
                                incomingLocationStream: widget.bleCoordinator
                                    ?.watchIncomingLocation(sos.id),
                                liveLocationStream: widget.bleCoordinator
                                    ?.watchLiveLocation(sos.id),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: Text(sheetContext.l10n.viewOnMap),
                      ),
                    ),
                  ] else
                    _buildDetailRow(
                      icon: Icons.location_off_outlined,
                      label: sheetContext.l10n.location,
                      value: sheetContext.l10n.incidentCoordinatesUnavailable,
                    ),
                  const SizedBox(height: 20),
                  if (!readOnly && !rescueView && sos.status == 'active') ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await _changeSosStatus(sos, 'resolved');
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(sheetContext.l10n.markResolved),
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
                        label: Text(sheetContext.l10n.cancelSos),
                      ),
                    ),
                  ],
                  if (readOnly || rescueView || sos.status != 'active')
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(sheetContext.l10n.close),
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
        final label = _localizedSosDeliveryStatus(row);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              icon: state == BleOutboxState.acknowledged
                  ? Icons.check_circle_outline
                  : Icons.bluetooth,
              label: context.l10n.bleDelivery,
              value: label,
            ),
            if (row?.destinationId != null)
              _buildDetailRow(
                icon: Icons.person_search_outlined,
                label: context.l10n.recipient,
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
                            content: Text(
                              context.l10n.unableSetRecipient(error.toString()),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.add_link),
                  label: Text(context.l10n.chooseRecipient),
                ),
              ),
          ],
        );
      },
    );
  }

  String _localizedSosDeliveryStatus(BleOutboxData? row) {
    final l10n = context.l10n;
    final state = row == null ? null : BleOutboxState.parse(row.state);
    return switch (state) {
      null => l10n.waitingForRecipient,
      BleOutboxState.queued =>
        row!.destinationId == null
            ? l10n.waitingForRecipient
            : l10n.statusQueued,
      BleOutboxState.sending => l10n.statusSending,
      BleOutboxState.writeAccepted || BleOutboxState.awaitingAcknowledgement =>
        l10n.waitingReceiverConfirmation,
      BleOutboxState.acknowledged => l10n.statusConfirmedStored,
      BleOutboxState.failed =>
        row!.nextRetryAt == null
            ? l10n.statusFailedNoRetry
            : l10n.statusFailedRetryScheduled,
      BleOutboxState.expired => l10n.statusExpired,
    };
  }

  Widget _buildRelayDeliveryDetail(SosMessage sos) {
    return StreamBuilder<RelayStatusSnapshot>(
      stream: widget.bleCoordinator!.watchRelayStatus(sos.id),
      builder: (context, snapshot) {
        final relay = snapshot.data;
        if (relay == null || !relay.hasRelayJob) return const SizedBox.shrink();
        final expired =
            relay.expiresAt != null &&
            !relay.expiresAt!.isAfter(DateTime.now().toUtc());
        final label = expired
            ? context.l10n.relayExpiredUnconfirmed
            : relay.acceptedRelayCount > 0
            ? context.l10n.storedOnRelay(relay.acceptedRelayCount)
            : relay.pendingAttemptCount > 0
            ? context.l10n.relayForwardingUnconfirmed
            : relay.failedAttemptCount > 0
            ? context.l10n.relayRetryUnconfirmed
            : context.l10n.relayWaitingUnconfirmed;
        return _buildDetailRow(
          icon: relay.acceptedRelayCount > 0 ? Icons.hub : Icons.hub_outlined,
          label: context.l10n.publicSosRelay,
          value: label,
        );
      },
    );
  }

  Future<void> _changeSosStatus(
    SosMessage sos,
    String status, {
    bool holdConfirmed = false,
  }) async {
    final isResolved = status == 'resolved';

    final confirmed =
        holdConfirmed ||
        await showDialog<bool>(
              useRootNavigator: false,
              context: context,
              builder: (dialogContext) {
                return AlertDialog(
                  title: Text(
                    isResolved
                        ? context.l10n.resolveSosQuestion
                        : context.l10n.cancelSosQuestion,
                  ),
                  content: Text(
                    isResolved
                        ? context.l10n.resolveSosConfirmation
                        : context.l10n.cancelSosConfirmation,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: Text(context.l10n.back),
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
                      child: Text(
                        isResolved
                            ? context.l10n.resolve
                            : context.l10n.cancelSos,
                      ),
                    ),
                  ],
                );
              },
            ) ==
            true;

    if (!confirmed || !mounted) {
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
      await widget.bleCoordinator?.enqueueIncidentLifecycle(
        sosId: sos.id,
        status: status,
      );
      await widget.bleCoordinator?.cancelPublicRelay(sos.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isResolved
                ? context.l10n.sosMarkedResolved
                : context.l10n.sosCancelled,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedUpdateSos('$error'))),
      );
    }
  }

  Future<void> _editSos(SosMessage sos) async {
    final result = await showDialog<String?>(
      useRootNavigator: false,
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
          .showSnackBar(SnackBar(content: Text(context.l10n.sosUpdated)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedUpdateSos('$error'))),
      );
    }
  }

  Future<void> _deleteSos(SosMessage sos) async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.deleteSosQuestion),
          content: Text(context.l10n.deleteCannotUndo),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(context.l10n.delete),
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
      await widget.bleCoordinator?.cancelPublicRelay(sos.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.sosDeleted)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failedDeleteSos('$error'))),
      );
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
          .showSnackBar(SnackBar(content: Text(context.l10n.syncCompleted)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.syncFailed('$error'))),
      );
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
    bool historyStyle = false,
    bool readOnly = false,
  }) {
    final isActive = sos.status == 'active';

    final statusColor = isActive
        ? const Color(0xFFD92323)
        : sos.status == 'cancelled'
        ? const Color(0xFF9A6A13)
        : const Color(0xFF397A62);

    return Card(
      key: historyStyle && !readOnly
          ? ValueKey('history-sos-chat-card-${sos.id}')
          : null,
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
          if (historyStyle && !readOnly) {
            unawaited(_openIncidentChat(sos));
          } else {
            _showSosDetail(sos, readOnly: readOnly);
          }
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
                    width: historyStyle ? 48 : 42,
                    height: historyStyle ? 48 : 42,
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
                      size: historyStyle ? 26 : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          historyStyle && _role != AppRole.rescue
                              ? 'SOS · ${sos.id}'
                              : sos.type.toUpperCase(),
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
              Row(
                children: [
                  Icon(
                    readOnly ? Icons.phone_android : Icons.chat_bubble_outline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    readOnly
                        ? context.l10n.localDataOnly
                        : historyStyle
                        ? context.l10n.tapToOpenChat
                        : context.l10n.tapToViewDetails,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (historyStyle && !readOnly)
                    TextButton.icon(
                      key: ValueKey('sos-details-button-${sos.id}'),
                      onPressed: () => _showSosDetail(sos),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: Text(context.l10n.details),
                    )
                  else if (historyStyle)
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
      title: Text(context.l10n.editSos),
      content: TextField(
        controller: _messageController,
        maxLines: 3,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          labelText: context.l10n.message,
          hintText: context.l10n.describeEmergency,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(context.l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(context.l10n.save)),
      ],
    );
  }
}
