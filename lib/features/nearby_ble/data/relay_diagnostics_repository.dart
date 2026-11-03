import 'dart:async';

import '../../../core/database/app_database.dart';
import '../domain/relay_envelope.dart';
import 'relay_repository.dart';

enum RelayDiagnosticOrigin { localOrigin, relayOnly }

enum RelayDiagnosticReceiptState { received, pending, failed, notRecorded }

class RelayDiagnosticEntry {
  const RelayDiagnosticEntry({
    required this.origin,
    required this.maskedMessageId,
    required this.shortDigest,
    required this.incomingHopCount,
    required this.persistedAt,
    required this.jobStatus,
    required this.hopReceiptState,
    required this.hopReceiptCount,
    required this.finalReceiptCount,
    required this.finalDeliveryConfirmed,
    required this.attemptCount,
    required this.lastErrorCategory,
  });

  final RelayDiagnosticOrigin origin;
  final String maskedMessageId;
  final String shortDigest;
  final int incomingHopCount;
  final DateTime persistedAt;
  final String jobStatus;
  final RelayDiagnosticReceiptState hopReceiptState;
  final int hopReceiptCount;
  final int finalReceiptCount;
  final bool finalDeliveryConfirmed;
  final int attemptCount;
  final String? lastErrorCategory;
}

class RelayDiagnosticsSnapshot {
  const RelayDiagnosticsSnapshot(this.entries);

  final List<RelayDiagnosticEntry> entries;
}

abstract interface class RelayDiagnosticsDataSource {
  Stream<RelayDiagnosticsSnapshot> watchDiagnostics();
}

/// Read-only, privacy-reduced projection of Relay v2 persistence.
///
/// The projection intentionally excludes envelopes, signatures, keys, message
/// text, coordinates, peer identifiers, incident identifiers and raw errors.
class RelayDiagnosticsRepository implements RelayDiagnosticsDataSource {
  RelayDiagnosticsRepository(this.database);

  final AppDatabase database;

  @override
  Stream<RelayDiagnosticsSnapshot> watchDiagnostics() {
    late StreamController<RelayDiagnosticsSnapshot> controller;
    final subscriptions = <StreamSubscription<Object?>>[];
    var reading = false;
    var readAgain = false;

    Future<void> emit() async {
      if (reading) {
        readAgain = true;
        return;
      }
      reading = true;
      do {
        readAgain = false;
        try {
          final snapshot = await _readSnapshot();
          if (!controller.isClosed) controller.add(snapshot);
        } on Object catch (error, stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        }
      } while (readAgain && !controller.isClosed);
      reading = false;
    }

    controller = StreamController<RelayDiagnosticsSnapshot>(
      onListen: () {
        subscriptions.addAll([
          database
              .select(database.bleRelayMessages)
              .watch()
              .listen((_) => unawaited(emit()), onError: controller.addError),
          database
              .select(database.bleRelayAttempts)
              .watch()
              .listen((_) => unawaited(emit()), onError: controller.addError),
          database
              .select(database.bleRelayReceipts)
              .watch()
              .listen((_) => unawaited(emit()), onError: controller.addError),
        ]);
        unawaited(emit());
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<RelayDiagnosticsSnapshot> _readSnapshot() async {
    final messages = await database.select(database.bleRelayMessages).get();
    final attempts = await database.select(database.bleRelayAttempts).get();
    final receipts = await database.select(database.bleRelayReceipts).get();
    final entries =
        messages
            .map((message) {
              final matchingAttempts =
                  attempts
                      .where(
                        (attempt) =>
                            attempt.originMessageId == message.originMessageId,
                      )
                      .toList(growable: false)
                    ..sort(
                      (left, right) =>
                          right.updatedAt.compareTo(left.updatedAt),
                    );
              final matchingReceipts = receipts
                  .where(
                    (receipt) =>
                        receipt.originMessageId == message.originMessageId,
                  )
                  .toList(growable: false);
              final hopReceipts = matchingReceipts
                  .where(
                    (receipt) =>
                        receipt.receiptType == RelayReceiptType.hop.wireValue,
                  )
                  .length;
              final finalReceipts = matchingReceipts
                  .where(
                    (receipt) =>
                        receipt.receiptType ==
                        RelayReceiptType.finalRecipient.wireValue,
                  )
                  .length;
              final latestAttempt = matchingAttempts.firstOrNull;
              final rawError = latestAttempt?.lastError ?? message.lastError;
              return RelayDiagnosticEntry(
                origin:
                    message.incomingPeerId == RelayRepository.localOriginPeerId
                    ? RelayDiagnosticOrigin.localOrigin
                    : RelayDiagnosticOrigin.relayOnly,
                maskedMessageId: _masked(message.originMessageId),
                shortDigest: _shortened(message.immutableDigest),
                incomingHopCount: message.incomingHopCount,
                persistedAt: message.persistedAt,
                jobStatus: _jobStatus(message, latestAttempt),
                hopReceiptState: _hopReceiptState(
                  hopReceiptCount: hopReceipts,
                  attempts: matchingAttempts,
                ),
                hopReceiptCount: hopReceipts,
                finalReceiptCount: finalReceipts,
                finalDeliveryConfirmed:
                    finalReceipts > 0 &&
                    message.processingState ==
                        RelayMessageState.finalDelivered.wireValue &&
                    message.finalReceiptState != null,
                attemptCount: matchingAttempts.length,
                lastErrorCategory: _errorCategory(rawError),
              );
            })
            .toList(growable: false)
          ..sort(
            (left, right) => right.persistedAt.compareTo(left.persistedAt),
          );
    return RelayDiagnosticsSnapshot(entries);
  }
}

String _jobStatus(BleRelayMessage message, BleRelayAttempt? latestAttempt) {
  if (latestAttempt != null) return latestAttempt.state;
  if (message.incomingPeerId != RelayRepository.localOriginPeerId &&
      message.processingState == RelayMessageState.queued.wireValue) {
    return 'storedOnRelay';
  }
  return message.processingState;
}

RelayDiagnosticReceiptState _hopReceiptState({
  required int hopReceiptCount,
  required List<BleRelayAttempt> attempts,
}) {
  if (hopReceiptCount > 0) return RelayDiagnosticReceiptState.received;
  if (attempts.any(
    (attempt) =>
        attempt.state == RelayAttemptState.sending.wireValue ||
        attempt.state == RelayAttemptState.awaitingHopReceipt.wireValue,
  )) {
    return RelayDiagnosticReceiptState.pending;
  }
  if (attempts.any(
    (attempt) =>
        attempt.state == RelayAttemptState.failed.wireValue ||
        attempt.state == RelayAttemptState.expired.wireValue,
  )) {
    return RelayDiagnosticReceiptState.failed;
  }
  return RelayDiagnosticReceiptState.notRecorded;
}

String? _errorCategory(String? rawError) {
  final normalized = rawError?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.contains('timeout') || normalized.contains('timed out')) {
    return 'timeout';
  }
  if (normalized.contains('permission') || normalized.contains('denied')) {
    return 'permission';
  }
  if (normalized.contains('signature') ||
      normalized.contains('verify') ||
      normalized.contains('proof')) {
    return 'verification';
  }
  if (normalized.contains('storage') || normalized.contains('persist')) {
    return 'storage';
  }
  if (normalized.contains('connect') ||
      normalized.contains('write') ||
      normalized.contains('bluetooth')) {
    return 'transport';
  }
  return 'other';
}

String _masked(String value) {
  final normalized = value.trim();
  if (normalized.length <= 8) return '…$normalized';
  return '…${normalized.substring(normalized.length - 8)}';
}

String _shortened(String value) {
  final normalized = value.trim();
  if (normalized.length <= 12) return normalized;
  return '${normalized.substring(0, 12)}…';
}
