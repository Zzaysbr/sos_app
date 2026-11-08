import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../data/relay_diagnostics_repository.dart';

class RelayDiagnosticsRoute {
  const RelayDiagnosticsRoute._();

  static Route<void>? build({
    required RelayDiagnosticsDataSource dataSource,
    RelayRuntimeDiagnosticsDataSource? runtimeDataSource,
    bool releaseMode = kReleaseMode,
  }) {
    if (releaseMode) return null;
    return MaterialPageRoute<void>(
      builder: (_) => RelayDiagnosticsPage(
        dataSource: dataSource,
        runtimeDataSource: runtimeDataSource,
      ),
    );
  }
}

class RelayDiagnosticsPage extends StatelessWidget {
  const RelayDiagnosticsPage({
    super.key,
    required this.dataSource,
    this.runtimeDataSource,
    this.releaseMode = kReleaseMode,
  });

  final RelayDiagnosticsDataSource dataSource;
  final RelayRuntimeDiagnosticsDataSource? runtimeDataSource;
  final bool releaseMode;

  @override
  Widget build(BuildContext context) {
    if (releaseMode) {
      return Scaffold(
        body: Center(child: Text(context.l10n.developerToolUnavailable)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.relayDiagnostics)),
      body: StreamBuilder<RelayDiagnosticsSnapshot>(
        stream: dataSource.watchDiagnostics(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              title: context.l10n.relayDiagnosticsUnavailable,
              body: context.l10n.relayDiagnosticsReadFailed,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!.entries;
          if (entries.isEmpty) {
            return _MessageState(
              icon: Icons.hub_outlined,
              title: context.l10n.noRelayRecords,
              body: context.l10n.noRelayRecordsDescription,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _EvidenceNotice(),
              if (runtimeDataSource != null) ...[
                const SizedBox(height: 12),
                StreamBuilder<RelayRuntimeDiagnosticsSnapshot>(
                  stream: runtimeDataSource!.watchRuntimeDiagnostics(),
                  builder: (context, runtime) => _RuntimeCard(
                    snapshot:
                        runtime.data ??
                        const RelayRuntimeDiagnosticsSnapshot(
                          peers: <RelayPeerDiagnostic>[],
                          events: <String>[],
                        ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                context.l10n.relayMessagesStored(entries.length),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (final entry in entries) ...[
                _RelayEntryCard(entry: entry),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({required this.snapshot});

  final RelayRuntimeDiagnosticsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Runtime relay state', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _DiagnosticRow(label: 'Due jobs', value: '${snapshot.dueJobs}'),
            _DiagnosticRow(
              label: 'Last scheduler',
              value:
                  snapshot.lastSchedulerExecution?.toLocal().toString() ??
                  'Not recorded',
            ),
            _DiagnosticRow(
              label: 'Last selected peer',
              value: snapshot.lastSelectedPeer ?? 'Not recorded',
            ),
            _DiagnosticRow(
              label: 'Last skip reason',
              value: snapshot.lastSkipReason ?? 'Not recorded',
            ),
            _DiagnosticRow(
              label: 'Last forward attempt',
              value: snapshot.lastForwardAttempt ?? 'Not recorded',
            ),
            _DiagnosticRow(
              label: 'Last durable receipt',
              value: snapshot.lastDurableReceipt ?? 'Not recorded',
            ),
            const SizedBox(height: 8),
            Text('Peer sessions', style: theme.textTheme.titleSmall),
            for (final peer in snapshot.peers)
              Text(
                '${peer.peer} · ${peer.role} · ${peer.connected ? 'connected' : 'disconnected'} · ${peer.authenticated ? 'authenticated' : 'unauthenticated'} · ${peer.authenticated && peer.participating ? 'eligible' : 'ineligible'}',
              ),
            const SizedBox(height: 8),
            Text('Recent events', style: theme.textTheme.titleSmall),
            for (final event in snapshot.events) Text(event),
          ],
        ),
      ),
    );
  }
}

class RelayRuntimeDiagnosticsPage extends StatelessWidget {
  const RelayRuntimeDiagnosticsPage({super.key, required this.dataSource});

  final RelayRuntimeDiagnosticsDataSource dataSource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relay Runtime Diagnostics')),
      body: StreamBuilder<RelayRuntimeDiagnosticsSnapshot>(
        stream: dataSource.watchRuntimeDiagnostics(),
        builder: (context, snapshot) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _EvidenceNotice(),
            const SizedBox(height: 12),
            _RuntimeCard(
              snapshot:
                  snapshot.data ??
                  const RelayRuntimeDiagnosticsSnapshot(
                    peers: <RelayPeerDiagnostic>[],
                    events: <String>[],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvidenceNotice extends StatelessWidget {
  const _EvidenceNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(context.l10n.relayEvidenceNotice),
      ),
    );
  }
}

class _RelayEntryCard extends StatelessWidget {
  const _RelayEntryCard({required this.entry});

  final RelayDiagnosticEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final originLabel = switch (entry.origin) {
      RelayDiagnosticOrigin.localOrigin => l10n.locallyOriginatedSos,
      RelayDiagnosticOrigin.relayOnly => l10n.relayOnlyEnvelope,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              originLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _DiagnosticRow(label: l10n.messageId, value: entry.maskedMessageId),
            _DiagnosticRow(label: l10n.payloadDigest, value: entry.shortDigest),
            _DiagnosticRow(
              label: l10n.incomingHopCount,
              value: '${entry.incomingHopCount}',
            ),
            _DiagnosticRow(
              label: l10n.latestPersisted,
              value: _displayTime(context, entry.persistedAt),
            ),
            _DiagnosticRow(
              label: l10n.latestRelayJobStatus,
              value: _displayJobStatus(context, entry.jobStatus),
            ),
            _DiagnosticRow(
              label: l10n.relayAttemptCount,
              value: '${entry.attemptCount}',
            ),
            _DiagnosticRow(
              label: l10n.hopReceipt,
              value: _displayReceipt(context, entry.hopReceiptState),
            ),
            if (entry.hopReceiptCount > 0)
              _DiagnosticRow(
                label: l10n.hopReceiptsStored,
                value: '${entry.hopReceiptCount}',
              ),
            _DiagnosticRow(
              label: l10n.finalResponderReceipt,
              value: entry.finalDeliveryConfirmed
                  ? l10n.confirmed
                  : l10n.notConfirmed,
            ),
            if (entry.finalReceiptCount > 0)
              _DiagnosticRow(
                label: l10n.finalReceiptsStored,
                value: '${entry.finalReceiptCount}',
              ),
            _DiagnosticRow(
              label: l10n.lastRelayErrorCategory,
              value: entry.lastErrorCategory ?? l10n.none,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _displayJobStatus(BuildContext context, String value) => switch (value) {
  'storedOnRelay' =>
    '${context.l10n.storedOnRelayStatus} · ${context.l10n.pending}',
  'acceptedByRelay' => context.l10n.storedByNextRelay,
  'awaitingHopReceipt' => context.l10n.awaitingHopReceipt,
  'finalDelivered' => context.l10n.finalReceiptRecorded,
  'queued' => context.l10n.statusQueued,
  'sending' => context.l10n.statusSending,
  'failed' => context.l10n.statusFailed,
  'expired' => context.l10n.statusExpired,
  _ => context.l10n.unknown,
};

String _displayReceipt(
  BuildContext context,
  RelayDiagnosticReceiptState value,
) => switch (value) {
  RelayDiagnosticReceiptState.received => context.l10n.receivedFromNextRelay,
  RelayDiagnosticReceiptState.pending => context.l10n.pending,
  RelayDiagnosticReceiptState.failed => context.l10n.failedOrExpired,
  RelayDiagnosticReceiptState.notRecorded => context.l10n.notRecordedLocally,
};

String _displayTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
