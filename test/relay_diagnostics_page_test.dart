import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/features/nearby_ble/data/relay_diagnostics_repository.dart';
import 'package:sos_app/features/nearby_ble/presentation/relay_diagnostics_page.dart';

class _FakeDiagnosticsSource implements RelayDiagnosticsDataSource {
  _FakeDiagnosticsSource(this.stream);

  final Stream<RelayDiagnosticsSnapshot> stream;

  @override
  Stream<RelayDiagnosticsSnapshot> watchDiagnostics() => stream;
}

RelayDiagnosticEntry _entry({
  RelayDiagnosticOrigin origin = RelayDiagnosticOrigin.relayOnly,
  RelayDiagnosticReceiptState receipt = RelayDiagnosticReceiptState.notRecorded,
  int hopReceipts = 0,
  bool finalConfirmed = false,
}) => RelayDiagnosticEntry(
  origin: origin,
  maskedMessageId: '…325a9f10',
  shortDigest: '0123456789ab…',
  incomingHopCount: 1,
  persistedAt: DateTime.utc(2026, 11, 1, 15, 18, 18),
  jobStatus: 'storedOnRelay',
  hopReceiptState: receipt,
  hopReceiptCount: hopReceipts,
  finalReceiptCount: 0,
  finalDeliveryConfirmed: finalConfirmed,
  attemptCount: 0,
  lastErrorCategory: null,
);

Widget _app(RelayDiagnosticsDataSource source) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: RelayDiagnosticsPage(dataSource: source, releaseMode: false),
);

void main() {
  testWidgets('shows an empty state when no relay records exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeDiagnosticsSource(
          Stream.value(const RelayDiagnosticsSnapshot([])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No relay records'), findsOneWidget);
    expect(
      find.textContaining('Relay-only records never appear in SOS History'),
      findsOneWidget,
    );
  });

  testWidgets('displays a persisted incoming hop record', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeDiagnosticsSource(
          Stream.value(RelayDiagnosticsSnapshot([_entry()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Relay messages stored: 1'), findsOneWidget);
    expect(find.text('Relay-only envelope'), findsOneWidget);
    expect(find.text('Incoming hop count'), findsOneWidget);
    expect(find.text('Stored on relay · Pending'), findsOneWidget);
  });

  test(
    'relay-only diagnostics do not create SOS History and redact payload data',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final timestamp = DateTime.utc(2026, 11, 1, 15, 18, 18);
      await database
          .into(database.bleRelayMessages)
          .insert(
            BleRelayMessagesCompanion.insert(
              originMessageId: 'relay:private-origin-message-id',
              incidentId: 'private-incident-id',
              originKeyId: 'private-origin-key',
              originPublicKey: 'private-public-key',
              immutablePayload:
                  '{"message":"private emergency text","latitude":13.7}',
              wireEnvelope: '{"signature":"private-signature"}',
              immutableDigest: '0123456789abcdef0123456789abcdef',
              originSignature: 'private-signature',
              authorizationScope: 'publicEmergencyRelay',
              emergencyType: 'emergency',
              createdAt: timestamp,
              expiresAt: timestamp.add(const Duration(minutes: 30)),
              retentionDeadline: timestamp.add(const Duration(minutes: 30)),
              maxHops: 3,
              incomingHopCount: 1,
              incomingPath: '["private-key-id"]',
              incomingPeerId: 'private-peer-id',
              previousHopKeyId: 'private-previous-key-id',
              processingState: 'queued',
              payloadBytes: 128,
              storageBytes: 256,
              receivedAt: timestamp,
              persistedAt: timestamp,
              lastError: const Value(
                'Bluetooth write failed to private-peer-id',
              ),
            ),
          );

      final snapshot = await RelayDiagnosticsRepository(database)
          .watchDiagnostics()
          .firstWhere((value) => value.entries.isNotEmpty);

      expect(await database.select(database.sosMessages).get(), isEmpty);
      expect(snapshot.entries, hasLength(1));
      final entry = snapshot.entries.single;
      expect(entry.origin, RelayDiagnosticOrigin.relayOnly);
      expect(entry.maskedMessageId, '…ssage-id');
      expect(entry.shortDigest, '0123456789ab…');
      expect(entry.lastErrorCategory, 'transport');
      expect(entry.toString(), isNot(contains('private emergency text')));
      expect(entry.toString(), isNot(contains('13.7')));
      expect(entry.toString(), isNot(contains('private-signature')));
      expect(entry.toString(), isNot(contains('private-peer-id')));
    },
  );

  testWidgets('hop receipt is never labeled as final delivery', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeDiagnosticsSource(
          Stream.value(
            RelayDiagnosticsSnapshot([
              _entry(
                receipt: RelayDiagnosticReceiptState.received,
                hopReceipts: 1,
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Received from next relay'), findsOneWidget);
    expect(find.text('Final responder receipt'), findsOneWidget);
    expect(find.text('Not confirmed'), findsOneWidget);
    expect(find.text('Confirmed'), findsNothing);
  });

  testWidgets('missing receipt is represented as not recorded', (tester) async {
    await tester.pumpWidget(
      _app(
        _FakeDiagnosticsSource(
          Stream.value(RelayDiagnosticsSnapshot([_entry()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not recorded locally'), findsOneWidget);
    expect(find.text('Not confirmed'), findsOneWidget);
  });

  testWidgets('data source error renders a safe non-mutating error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeDiagnosticsSource(
          Stream<RelayDiagnosticsSnapshot>.error(StateError('db failed')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Relay diagnostics unavailable'), findsOneWidget);
    expect(find.textContaining('No data changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen exposes only shortened identifiers and no raw payload', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeDiagnosticsSource(
          Stream.value(RelayDiagnosticsSnapshot([_entry()])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('…325a9f10'), findsOneWidget);
    expect(find.text('0123456789ab…'), findsOneWidget);
    expect(find.textContaining('GPS'), findsNothing);
    expect(find.textContaining('latitude'), findsNothing);
    expect(find.textContaining('signature'), findsNothing);
    expect(find.textContaining('private key'), findsNothing);
  });

  testWidgets('release configuration cannot create or render diagnostics', (
    tester,
  ) async {
    final source = _FakeDiagnosticsSource(
      Stream.value(RelayDiagnosticsSnapshot([_entry()])),
    );
    expect(
      RelayDiagnosticsRoute.build(dataSource: source, releaseMode: true),
      isNull,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RelayDiagnosticsPage(dataSource: source, releaseMode: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Developer tool unavailable'), findsOneWidget);
    expect(find.text('Relay Diagnostics'), findsNothing);
    expect(find.text('Relay messages stored: 1'), findsNothing);
  });
}
