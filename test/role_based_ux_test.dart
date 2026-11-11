import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/core/theme/app_theme.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/data/emergency_consent_store.dart';
import 'package:sos_app/features/nearby_ble/data/relay_preference_store.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/nearby_ble/domain/location_ble_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';
import 'package:sos_app/features/role/data/role_preference_store.dart';
import 'package:sos_app/features/role/domain/app_role.dart';
import 'package:sos_app/features/role/domain/role_workflow_controller.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';
import 'package:sos_app/features/sos/presentation/sos_page.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _Cloud extends Mock implements SosCloudService {}

class _Repository extends Mock implements SosRepository {}

class _BleCoordinator extends Mock implements SosBleCoordinator {}

class _ListeningTransport implements BleTransportClient {
  final controller = StreamController<BleEvent>.broadcast();
  int advertisingStarts = 0;
  int advertisingStops = 0;
  @override
  Stream<BleEvent> get events => controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> startAdvertising({String? name}) async {
    advertisingStarts++;
  }

  @override
  Future<void> stopAdvertising() async {
    advertisingStops++;
  }

  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(String deviceId) async {}
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {}
  @override
  Future<void> dispose() => controller.close();
}

class _FailingRelayPreferenceStore implements RelayPreferenceStore {
  _FailingRelayPreferenceStore({this.failRead = false, this.failWrite = false});

  bool enabled = false;
  bool failRead;
  bool failWrite;

  @override
  Future<bool> loadParticipationEnabled() async {
    if (failRead) throw StateError('preference read failed');
    return enabled;
  }

  @override
  Future<void> saveParticipationEnabled(bool enabled) async {
    if (failWrite) throw StateError('preference write failed');
    this.enabled = enabled;
  }
}

void main() {
  late AppDatabase database;
  late _Auth auth;
  late _Cloud cloud;
  late SosRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    auth = _Auth();
    cloud = _Cloud();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    repository = SosRepository(
      database: database,
      cloudService: cloud,
      firebaseAuth: auth,
      localOwnerId: guestDeviceOwnerId,
    );
  });

  tearDown(() async => database.close());

  testWidgets(
    'stop following preserves legacy history and Chat without a remote cancellation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final old = DateTime.utc(2026, 1, 1);
      await database
          .into(database.rescueInbox)
          .insert(
            RescueInboxCompanion.insert(
              ownerId: guestDeviceOwnerId,
              originMessageId: 'legacy-origin',
              incidentId: 'legacy-incident',
              originKeyId: 'old-key',
              immutableDigest: 'old-digest',
              emergencyType: 'emergency',
              emergencyMessage: 'Legacy saved SOS',
              includeLocation: false,
              incomingHopCount: 0,
              incomingPath: '["old-key"]',
              createdAt: old,
              expiresAt: old.add(const Duration(minutes: 30)),
              receivedAt: old,
              state: 'locallyAccepted',
            ),
          );
      await database
          .into(database.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              messageId: 'legacy-chat',
              sosId: 'legacy-incident',
              ownerId: guestDeviceOwnerId,
              senderId: 'old-key',
              messageType: 'text',
              textContent: const Value('Retained Chat message'),
              createdAt: old,
              deliveryStatus: 'delivered',
            ),
          );
      final chat = PersistentChatRepository(
        database: database,
        ownerId: guestDeviceOwnerId,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SosPage(
            repository: repository,
            isGuest: true,
            chatRepository: chat,
            rolePreferenceStore: MemoryRolePreferenceStore(AppRole.rescue),
            relayPreferenceStore: MemoryRelayPreferenceStore(),
            emergencyConsentStore: MemoryEmergencyConsentStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.assignment_outlined).last);
      await tester.pumpAndSettle();
      final menu = find.byKey(
        const ValueKey('stop-following-menu-legacy-origin'),
      );
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop following on this device'));
      await tester.pumpAndSettle();
      // Dismissing the confirmation must leave the incident tracked.
      await tester.tap(find.widgetWithText(TextButton, 'Back'));
      await tester.pumpAndSettle();
      expect(
        (await RescueInboxRepository(
          database,
          ownerId: guestDeviceOwnerId,
        ).find('legacy-origin'))!.state,
        'locallyAccepted',
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop following on this device'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Stop following on this device'),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('accepted-rescue-candidate-legacy-origin')),
        findsNothing,
      );
      expect(await database.select(database.sosMessages).get(), isEmpty);
      expect(await database.select(database.bleOutbox).get(), isEmpty);
      expect(await database.select(database.sosSyncQueue).get(), isEmpty);
      await tester.tap(find.byTooltip('Received incident history'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('rescue-history-legacy-origin')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('rescue-history-legacy-origin')),
      );
      await tester.pumpAndSettle();
      final offerButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Offer Help'),
      );
      expect(offerButton.onPressed, isNull);
      await tester.tap(find.text('Open incident chat'));
      await tester.pumpAndSettle();
      expect(find.text('Retained Chat message'), findsOneWidget);
      expect((await database.select(database.chatMessages).get()).length, 1);
      expect(await database.select(database.bleOutbox).get(), isEmpty);
      expect(await database.select(database.sosSyncQueue).get(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'Offer Help closes sheet after durable enqueue while radio processing is blocked',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      FlutterSecureStorage.setMockInitialValues({
        'ed25519-origin-seed-v1': base64UrlEncode(List<int>.filled(32, 23)),
      });
      final now = DateTime.now().toUtc();
      final key = await Ed25519().newKeyPairFromSeed(List<int>.filled(32, 42));
      final public = (await key.extractPublicKey()).bytes;
      final crypto = RelayCryptography();
      final keyId = await crypto.publicKeyId(public);
      final body = RelayOriginBody(
        originMessageId: 'relay:offer-ui',
        incidentId: 'offer-ui',
        originKeyId: keyId,
        originPublicKey: base64UrlEncode(public),
        emergencyType: 'emergency',
        emergencyMessage: 'Widget test SOS',
        includeLocation: false,
        scope: RelayAuthorizationScope.voluntaryRescue,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 30)),
      );
      final offer = RelayOfferEnvelope(
        body: body,
        originSignature: await crypto.signOriginBody(body, key),
        hopCount: 0,
        pathKeyIds: [keyId],
        immediateSenderKeyId: keyId,
      );
      await RelayRepository(database: database)
          .persistOriginOffer(offer, now: now);
      await RescueInboxRepository(
        database,
        ownerId: guestDeviceOwnerId,
      ).insertCandidate(
        offer,
        immutableDigest: await crypto.immutableDigest(body),
        now: now,
      );
      final processing = Completer<void>();
      final coordinator = _BleCoordinator();
      final transport = _ListeningTransport();
      addTearDown(transport.dispose);
      when(() => coordinator.hasPendingPublicRelay())
          .thenAnswer((_) async => false);
      when(() => coordinator.setRelayParticipationEnabled(any()))
          .thenAnswer((_) async {});
      when(() => coordinator.processDue()).thenAnswer((_) => processing.future);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SosPage(
            repository: repository,
            isGuest: true,
            rolePreferenceStore: MemoryRolePreferenceStore(AppRole.rescue),
            relayPreferenceStore: MemoryRelayPreferenceStore(),
            emergencyConsentStore: MemoryEmergencyConsentStore(),
            bleCoordinator: coordinator,
            bleTransport: transport,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final candidate = find.byKey(
        const ValueKey('received-rescue-candidate-offer-ui'),
      );
      expect(candidate, findsNothing);
      await tester.tap(find.byKey(const ValueKey('rescue-listening-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offer Help'));
      await tester.tap(
        find.text('Offer Help'),
      ); // old widget callback cannot double-queue
      await tester.pumpAndSettle();
      expect(processing.isCompleted, isFalse);
      expect(find.text('Incoming SOS candidate'), findsNothing);
      expect(
        find.byKey(const ValueKey('accepted-rescue-candidate-relay:offer-ui')),
        findsOneWidget,
      );
      final queued = await database.select(database.rescueResponseOutbox).get();
      expect(queued, hasLength(1));
      expect(queued.single.state, 'queued');
      verify(() => coordinator.processDue()).called(1);
      processing.complete();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'saved terminal recovery starts BLE without enabling public relay',
    (tester) async {
      var starts = 0;
      final store = MemoryRelayPreferenceStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SosPage(
            repository: repository,
            isGuest: true,
            rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
            relayPreferenceStore: store,
            emergencyConsentStore: MemoryEmergencyConsentStore(),
            pendingBleWorkCheck: () async => true,
            onBleStartRequested: () async {
              starts++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(await store.loadParticipationEnabled(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test('SOS failed status only promises a retry when one is scheduled', () {
    final now = DateTime.utc(2026, 1, 1);
    BleOutboxData failed({DateTime? nextRetryAt}) => BleOutboxData(
      messageId: 'sos-status',
      sosId: 'sos-status-incident',
      destinationId: 'peer-a',
      schemaVersion: 1,
      payload: '{}',
      state: 'failed',
      retryCount: 1,
      nextRetryAt: nextRetryAt,
      lastError: 'receiver rejected persistence',
      createdAt: now,
      updatedAt: now,
    );

    expect(
      sosBleDeliveryStatusText(failed()),
      'Delivery failed; retry not scheduled',
    );
    expect(
      sosBleDeliveryStatusText(
        failed(nextRetryAt: now.add(const Duration(seconds: 2))),
      ),
      'Failed; retry scheduled',
    );
  });

  Widget app(
    RolePreferenceStore store, {
    ThemeMode mode = ThemeMode.light,
    BleTransportClient? bleTransport,
  }) => MaterialApp(
    locale: const Locale('th'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: SosPage(
      repository: repository,
      isGuest: true,
      rolePreferenceStore: store,
      bleTransport: bleTransport,
      relayPreferenceStore: bleTransport == null
          ? null
          : MemoryRelayPreferenceStore(),
    ),
  );

  testWidgets('first run defaults to victim mode and rescue opt-in persists', (
    tester,
  ) async {
    final store = MemoryRolePreferenceStore();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.text('วันนี้คุณต้องการทำอะไร?'), findsNothing);
    expect(find.text('ส่ง SOS'), findsOneWidget);
    expect(store.value, AppRole.needHelp);

    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('โหมดการใช้งาน'));
    await tester.pumpAndSettle();
    expect(find.text('ศูนย์ช่วยเหลือใกล้ตัว'), findsOneWidget);
    expect(store.value, AppRole.rescue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(store, mode: ThemeMode.dark));
    await tester.pumpAndSettle();
    expect(find.text('วันนี้คุณต้องการทำอะไร?'), findsNothing);
    expect(find.text('ศูนย์ช่วยเหลือใกล้ตัว'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  for (final received in [false, true]) {
    testWidgets(
      'Chat banner and Back preserve rescue role and listening; received=$received',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        if (received) {
          await repository.ensureReceivedIncident(
            id: 'role-incident',
            type: 'emergency',
            message: 'received signed incident fixture',
            createdAt: DateTime.now().toUtc(),
          );
        } else {
          await repository.create(id: 'role-incident', type: 'emergency');
        }
        final store = MemoryRolePreferenceStore(AppRole.rescue);
        final transport = _ListeningTransport();
        addTearDown(transport.dispose);
        await tester.pumpWidget(app(store, bleTransport: transport));
        await tester.pumpAndSettle();
        await tester.tap(find.text('เริ่มเปิดรับเหตุ'));
        await tester.pumpAndSettle();
        expect(transport.advertisingStarts, 1);
        expect(transport.advertisingStops, 0);
        expect(find.text('ปิดรับเหตุ'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('active-sos-chat-banner-role-incident')),
        );
        await tester.pumpAndSettle();
        expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
        expect(store.value, AppRole.rescue);
        expect(transport.advertisingStops, 0);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(store.value, AppRole.rescue);
        expect(find.text('ศูนย์ช่วยเหลือใกล้ตัว'), findsOneWidget);
        expect(find.text('ปิดรับเหตุ'), findsOneWidget);
        expect(transport.advertisingStarts, 1);
        expect(transport.advertisingStops, 0);
        expect((await repository.findById('role-incident'))!.status, 'active');
        await tester.tap(find.byKey(const ValueKey('rescue-listening-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('เริ่มเปิดรับเหตุ'), findsOneWidget);
        expect(transport.advertisingStops, 1);
        // Only the explicit role switch releases the listening lease.
        await tester.tap(find.byTooltip('สลับไปโหมดขอความช่วยเหลือ'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('สลับโหมด'));
        await tester.pumpAndSettle();
        expect(store.value, AppRole.needHelp);
        expect(transport.advertisingStops, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        expect(transport.advertisingStops, 1);
      },
    );
  }

  testWidgets('switching modes warns and preserves an active incident', (
    tester,
  ) async {
    await repository.create(id: 'active-own', type: 'emergency');
    await PersistentChatRepository(
      database: database,
      ownerId: guestDeviceOwnerId,
    ).insertMessage(
      sosId: 'active-own',
      messageId: 'role-chat',
      text: 'keep chat',
    );
    final now = DateTime.now().toUtc();
    final deliveryRepository = BleDeliveryRepository(database);
    await deliveryRepository.enqueueOutbox(
      SosBleEnvelope.delivery(
        messageId: 'role-sos-delivery',
        sosId: 'active-own',
        senderDeviceId: 'installation-a',
        sosType: 'emergency',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      destinationId: 'peer-a',
    );
    await deliveryRepository.enqueueLocationOutbox(
      LocationBleEnvelope.update(
        messageId: 'role-location',
        sosId: 'active-own',
        senderDeviceId: 'installation-a',
        recipientId: 'peer-a',
        latitude: 13.7,
        longitude: 100.5,
        createdAt: now,
        expiresAt: now.add(const Duration(minutes: 2)),
      ),
      destinationId: 'peer-a',
    );
    final before = await database.select(database.sosMessages).getSingle();
    final chatBefore = await database.select(database.chatMessages).get();
    final outboxBefore = await database.select(database.bleOutbox).get();
    final store = MemoryRolePreferenceStore(AppRole.needHelp);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('สลับไปโหมดผู้ช่วยเหลือ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ยังมีเหตุที่กำลังดำเนินอยู่'), findsOneWidget);
    expect(find.textContaining('ไม่ยกเลิกเหตุ'), findsOneWidget);

    await tester.tap(find.text('สลับโหมด'));
    await tester.pumpAndSettle();
    expect(store.value, AppRole.rescue);
    expect(
      find.byKey(const ValueKey('active-sos-chat-banner-active-own')),
      findsOneWidget,
    );
    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('active-sos-chat-banner-active-own')),
          )
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('rescue-controls-banner')))
            .dy,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('active-sos-chat-banner-active-own')),
    );
    await tester.pumpAndSettle();
    // Opening Chat is navigation, not an implicit role-switch action.
    expect(store.value, AppRole.rescue);
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(find.text('SOS จากเครื่องต้นทาง'), findsOneWidget);
    expect(await database.select(database.sosMessages).getSingle(), before);
    expect(
      (await database.select(database.chatMessages).get()).map(
        (row) => (row.messageId, row.deliveryStatus),
      ),
      chatBefore.map((row) => (row.messageId, row.deliveryStatus)),
    );
    expect(
      (await database.select(database.bleOutbox).get()).map(
        (row) => (row.messageId, row.state, row.destinationId),
      ),
      outboxBefore.map((row) => (row.messageId, row.state, row.destinationId)),
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(store.value, AppRole.rescue);
    expect(find.text('ศูนย์ช่วยเหลือใกล้ตัว'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'holding the primary SOS button cancels and retains the incident',
    (tester) async {
      await repository.create(id: 'hold-cancel', type: 'emergency');
      await tester.pumpWidget(app(MemoryRolePreferenceStore(AppRole.needHelp)));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('primary-sos-hold-action'));
      final press = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(seconds: 2));
      await press.up();
      await tester.pumpAndSettle();
      expect((await repository.findById('hold-cancel'))?.status, 'cancelled');
      expect(
        find.byKey(const ValueKey('active-sos-chat-banner-hold-cancel')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test('active own SOS blocks duplicates but inbound SOS does not', () {
    final workflow = RoleWorkflowController();
    expect(
      workflow.canCreateSos(
        activeIncidentIds: const ['own'],
        inboundIncidentIds: const {},
      ),
      isFalse,
    );
    expect(
      workflow.canCreateSos(
        activeIncidentIds: const ['received'],
        inboundIncidentIds: const {'received'},
      ),
      isTrue,
    );
  });

  test('rescue acceptance ignores concurrent and repeated taps', () async {
    final workflow = RoleWorkflowController();
    final gate = Completer<void>();
    var effects = 0;
    final first = workflow.accept(
      'sos-1',
      onAccepted: () async {
        effects++;
        await gate.future;
      },
    );
    expect(await workflow.accept('sos-1'), isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(await workflow.accept('sos-1'), isFalse);
    expect(effects, 1);
  });

  testWidgets('rapid repeated SOS actions start one submission', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final delayedRepository = _Repository();
    final gate = Completer<List<SosMessage>>();
    when(() => delayedRepository.database).thenReturn(database);
    when(() => delayedRepository.watchAll())
        .thenAnswer((_) => Stream.value([]));
    when(() => delayedRepository.listActiveIncidents())
        .thenAnswer((_) => gate.future);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SosPage(
          repository: delayedRepository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ประวัติ'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send SOS'));
    await tester.tap(find.text('Send SOS'));
    await tester.tap(find.text('Send SOS'));
    verify(() => delayedRepository.listActiveIncidents()).called(1);

    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete([]);
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'emergency relay and location consent are configured in Settings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final consentStore = MemoryEmergencyConsentStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SosPage(
            repository: repository,
            isGuest: true,
            rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
            relayPreferenceStore: MemoryRelayPreferenceStore(),
            emergencyConsentStore: consentStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ตั้งค่า'));
      await tester.pumpAndSettle();

      final relayConsent = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('emergency-public-relay-consent')),
      );
      final locationConsent = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('emergency-location-consent')),
      );
      expect(relayConsent.value, isFalse);
      expect(locationConsent.value, isFalse);
      expect(locationConsent.onChanged, isNull);

      relayConsent.onChanged!(true);
      await tester.pumpAndSettle();
      expect(consentStore.consent.allowPublicRelay, isTrue);
      expect(consentStore.consent.shareLocation, isFalse);
      final enabledLocation = tester.widget<SwitchListTile>(
        find.byKey(const ValueKey('emergency-location-consent')),
      );
      expect(enabledLocation.onChanged, isNotNull);
      enabledLocation.onChanged!(true);
      await tester.pumpAndSettle();
      expect(consentStore.consent.configured, isTrue);
      expect(consentStore.consent.shareLocation, isTrue);
      expect(consentStore.saveCount, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('relay participation defaults off and changes explicitly', (
    tester,
  ) async {
    final store = MemoryRelayPreferenceStore();
    final coordinator = _BleCoordinator();
    when(() => coordinator.hasPendingPublicRelay())
        .thenAnswer((_) async => false);
    when(() => coordinator.setRelayParticipationEnabled(any()))
        .thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          relayPreferenceStore: store,
          bleCoordinator: coordinator,
        ),
      ),
    );
    await tester.pumpAndSettle();
    verify(() => coordinator.setRelayParticipationEnabled(false)).called(1);

    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    final toggleFinder = find.widgetWithText(
      SwitchListTile,
      'Nearby SOS relay',
    );
    expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);
    tester.widget<SwitchListTile>(toggleFinder).onChanged!(true);
    await tester.pumpAndSettle();

    expect(store.enabled, isTrue);
    expect(store.saveCount, 1);
    verify(() => coordinator.setRelayParticipationEnabled(true)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'pending local Public Relay resumes BLE while participation remains off',
    (tester) async {
      final store = MemoryRelayPreferenceStore();
      final coordinator = _BleCoordinator();
      var starts = 0;
      when(() => coordinator.hasPendingPublicRelay())
          .thenAnswer((_) async => true);
      when(() => coordinator.setRelayParticipationEnabled(false))
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        MaterialApp(
          home: SosPage(
            repository: repository,
            isGuest: true,
            rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
            relayPreferenceStore: store,
            bleCoordinator: coordinator,
            onBleStartRequested: () async => starts++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(starts, 1);
      expect(store.enabled, isFalse);
      verify(() => coordinator.setRelayParticipationEnabled(false)).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('saved relay ON fails closed when BLE startup fails', (
    tester,
  ) async {
    final store = MemoryRelayPreferenceStore(enabled: true);
    final coordinator = _BleCoordinator();
    when(() => coordinator.setRelayParticipationEnabled(false))
        .thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          relayPreferenceStore: store,
          bleCoordinator: coordinator,
          onBleStartRequested: () async => throw StateError('BLE unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(store.enabled, isFalse);
    verify(() => coordinator.setRelayParticipationEnabled(false)).called(1);
    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Nearby SOS relay'),
          )
          .value,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('preference read failure hard-disables a reused coordinator', (
    tester,
  ) async {
    final store = _FailingRelayPreferenceStore(failRead: true);
    final coordinator = _BleCoordinator();
    when(() => coordinator.setRelayParticipationEnabled(false))
        .thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          relayPreferenceStore: store,
          bleCoordinator: coordinator,
        ),
      ),
    );
    await tester.pumpAndSettle();

    verify(() => coordinator.setRelayParticipationEnabled(false)).called(1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('preference write failure keeps runtime and UI disabled', (
    tester,
  ) async {
    final store = _FailingRelayPreferenceStore(failWrite: true);
    final coordinator = _BleCoordinator();
    when(() => coordinator.setRelayParticipationEnabled(any()))
        .thenAnswer((_) async {});
    await tester.pumpWidget(
      MaterialApp(
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          relayPreferenceStore: store,
          bleCoordinator: coordinator,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Nearby SOS relay');
    tester.widget<SwitchListTile>(toggle).onChanged!(true);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    verify(() => coordinator.setRelayParticipationEnabled(false)).called(2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('relay queue failure is not mislabeled as Bluetooth permission', (
    tester,
  ) async {
    final store = MemoryRelayPreferenceStore();
    final coordinator = _BleCoordinator();
    when(() => coordinator.setRelayParticipationEnabled(false))
        .thenAnswer((_) async {});
    when(() => coordinator.setRelayParticipationEnabled(true))
        .thenThrow(StateError('relay queue unavailable'));
    await tester.pumpWidget(
      MaterialApp(
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          relayPreferenceStore: store,
          bleCoordinator: coordinator,
          onBleStartRequested: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ตั้งค่า'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Nearby SOS relay');
    tester.widget<SwitchListTile>(toggle).onChanged!(true);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.textContaining('secure queue'), findsOneWidget);
    expect(
      find.textContaining('Check Nearby devices permission'),
      findsNothing,
    );
    expect(store.enabled, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'SOS hold keeps repository streams stable and starts one submission',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final delayedRepository = _Repository();
      final activeGate = Completer<List<SosMessage>>();
      var watchAllCalls = 0;
      var submissionCalls = 0;
      when(() => delayedRepository.database).thenReturn(database);
      when(() => delayedRepository.watchAll()).thenAnswer((_) {
        watchAllCalls++;
        return Stream.value(<SosMessage>[]);
      });
      when(() => delayedRepository.listActiveIncidents()).thenAnswer((_) {
        submissionCalls++;
        return activeGate.future;
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SosPage(
            repository: delayedRepository,
            isGuest: true,
            rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(watchAllCalls, 5);
      expect(find.text('พร้อมเมื่อคุณต้องการความช่วยเหลือ'), findsNothing);
      expect(find.textContaining('ใช้ SOS เมื่อมีเหตุฉุกเฉิน'), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('ส่ง SOS')),
      );
      for (var i = 0; i < 7; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        expect(watchAllCalls, 5);
      }
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();

      expect(submissionCalls, 1);
      expect(watchAllCalls, 5);

      await tester.pumpWidget(const SizedBox.shrink());
      activeGate.complete([]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.takeException(), isNull);
      expect(submissionCalls, 1);
    },
  );

  testWidgets('rescue list excludes received SOS owned by another scope', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final deliveryRepository = BleDeliveryRepository(database);
    await deliveryRepository.persistIncomingDelivery(
      SosBleEnvelope.delivery(
        messageId: 'guest-inbound-message',
        sosId: 'guest-inbound-sos',
        senderDeviceId: 'guest-peer',
        sosType: 'fire',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      ownerId: guestDeviceOwnerId,
      sourceDeviceId: 'guest-peer',
      now: now,
    );
    await deliveryRepository.persistIncomingDelivery(
      SosBleEnvelope.delivery(
        messageId: 'account-inbound-message',
        sosId: 'account-inbound-sos',
        senderDeviceId: 'account-peer',
        sosType: 'medical',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      ownerId: 'account-b',
      sourceDeviceId: 'account-peer',
      now: now,
    );

    final transport = _ListeningTransport();
    addTearDown(transport.dispose);
    await tester.pumpWidget(
      app(MemoryRolePreferenceStore(AppRole.rescue), bleTransport: transport),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rescue-listening-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('FIRE'), findsOneWidget);
    expect(find.text('MEDICAL'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Need Help Chat tab selects an exact owned incident', (
    tester,
  ) async {
    await repository.create(id: 'own-chat-incident', type: 'medical');
    await repository.create(id: 'closed-chat-incident', type: 'emergency');
    await repository.update(
      id: 'closed-chat-incident',
      type: 'emergency',
      status: 'cancelled',
    );
    final now = DateTime.now().toUtc();
    await BleDeliveryRepository(database).persistIncomingDelivery(
      SosBleEnvelope.delivery(
        messageId: 'inbound-chat-message',
        sosId: 'inbound-chat-incident',
        senderDeviceId: 'peer-a',
        sosType: 'fire',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      ownerId: guestDeviceOwnerId,
      sourceDeviceId: 'peer-a',
      now: now,
    );

    await tester.pumpWidget(app(MemoryRolePreferenceStore(AppRole.needHelp)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แชต'));
    await tester.pumpAndSettle();

    expect(find.text('แชตตามเหตุการณ์'), findsOneWidget);
    expect(find.text('MEDICAL'), findsOneWidget);
    expect(find.text('FIRE'), findsNothing);
    expect(find.text('Incident own-chat-incident'), findsOneWidget);
    expect(find.textContaining('closed-chat-incident'), findsNothing);

    await tester.tap(find.text('Incident own-chat-incident'));
    await tester.pumpAndSettle();
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(find.text('SOS จากเครื่องต้นทาง'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-open-map')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const ValueKey('chat-open-map'))))
        .pop();
    await tester.pumpAndSettle();
    await repository.update(
      id: 'own-chat-incident',
      type: 'medical',
      status: 'cancelled',
    );
    await tester.pumpAndSettle();
    expect(find.text('Incident own-chat-incident'), findsNothing);
    await tester.tap(find.text('ประวัติ'));
    await tester.pumpAndSettle();
    final oldChat = find.byKey(
      const ValueKey('history-sos-chat-card-own-chat-incident'),
    );
    expect(oldChat, findsOneWidget);
    await tester.tap(oldChat);
    await tester.pumpAndSettle();
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Rescue Chat tab lists only received incidents in scope', (
    tester,
  ) async {
    await repository.create(id: 'own-chat-incident', type: 'medical');
    final now = DateTime.now().toUtc();
    await BleDeliveryRepository(database).persistIncomingDelivery(
      SosBleEnvelope.delivery(
        messageId: 'inbound-chat-message',
        sosId: 'inbound-chat-incident',
        senderDeviceId: 'peer-a',
        sosType: 'fire',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      ownerId: guestDeviceOwnerId,
      sourceDeviceId: 'peer-a',
      now: now,
    );

    await tester.pumpWidget(app(MemoryRolePreferenceStore(AppRole.rescue)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('แชต'));
    await tester.pumpAndSettle();

    expect(find.text('แชตตามเหตุการณ์'), findsOneWidget);
    expect(find.text('FIRE'), findsOneWidget);
    expect(find.text('MEDICAL'), findsNothing);
    expect(find.text('Incident inbound-chat-incident'), findsOneWidget);

    await tester.tap(find.text('Incident inbound-chat-incident'));
    await tester.pumpAndSettle();
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(find.text('SOS จากเครื่องต้นทาง'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  test('light and dark semantic text colors meet WCAG AA contrast', () {
    double contrast(Color foreground, Color background) {
      final light = foreground.computeLuminance() + 0.05;
      final dark = background.computeLuminance() + 0.05;
      return light > dark ? light / dark : dark / light;
    }

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(
          theme.colorScheme.onErrorContainer,
          theme.colorScheme.errorContainer,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets(
    'system theme follows platform brightness without changing role',
    (tester) async {
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      final store = MemoryRolePreferenceStore(AppRole.rescue);
      await tester.pumpWidget(app(store, mode: ThemeMode.system));
      await tester.pumpAndSettle();
      final title = find.text('ศูนย์ช่วยเหลือใกล้ตัว');
      expect(Theme.of(tester.element(title)).brightness, Brightness.dark);
      expect(store.value, AppRole.rescue);

      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.light;
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(title)).brightness, Brightness.light);
      expect(store.value, AppRole.rescue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('BLE persistence is not presented as human acknowledgement', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final envelope = SosBleEnvelope.delivery(
      messageId: 'inbound-message',
      sosId: 'inbound-sos',
      senderDeviceId: 'installation-a',
      sosType: 'emergency',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    await BleDeliveryRepository(database).persistIncomingDelivery(
      envelope,
      ownerId: guestDeviceOwnerId,
      sourceDeviceId: 'installation-a',
      now: now,
    );
    final transport = _ListeningTransport();
    addTearDown(transport.dispose);
    await tester.pumpWidget(
      app(MemoryRolePreferenceStore(AppRole.rescue), bleTransport: transport),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rescue-listening-toggle')));
    await tester.pumpAndSettle();

    expect(find.text('รับช่วยเหลือ'), findsOneWidget);
    await tester.ensureVisible(find.text('EMERGENCY'));
    await tester.tap(find.text('EMERGENCY'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('การรับผ่าน BLE ไม่ใช่การตอบรับจากผู้ช่วยเหลือ'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
