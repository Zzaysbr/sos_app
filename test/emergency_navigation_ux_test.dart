import 'package:sos_app/l10n/generated/app_localizations.dart';

import 'dart:async';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/core/theme/app_theme.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/nearby_ble/data/emergency_consent_store.dart';
import 'package:sos_app/features/nearby_ble/data/hop_relay_coordinator.dart';
import 'package:sos_app/features/nearby_ble/data/relay_preference_store.dart';
import 'package:sos_app/features/nearby_ble/data/sos_ble_coordinator.dart';
import 'package:sos_app/features/role/data/role_preference_store.dart';
import 'package:sos_app/features/role/domain/app_role.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/sos/data/media_attachment_store.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';
import 'package:sos_app/features/sos/presentation/sos_page.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _Cloud extends Mock implements SosCloudService {}

class _FailingRepository extends Mock implements SosRepository {}

class _BleCoordinator extends Mock implements SosBleCoordinator {
  @override
  final mediaStore = MediaAttachmentStore(ownerId: 'test');
}

class _Transport extends Mock implements BleTransportClient {
  @override
  Stream<BleEvent> get events => const Stream.empty();
}

class _SosMessageFake extends Fake implements SosMessage {}

class _ChatMessageFake extends Fake implements EmergencyChatMessage {}

class _OutboxFake extends Fake implements BleOutboxData {}

class _StaticChatRepository extends MockEmergencyChatRepository {
  _StaticChatRepository(this.messages);

  final List<EmergencyChatMessage> messages;

  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async =>
      messages;

  @override
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) async* {
    yield messages;
  }
}

void main() {
  late AppDatabase database;
  late SosRepository repository;

  Future<Position?> noLocation() async => null;

  Widget app(
    SosRepository source, {
    Widget Function(Widget)? wrap,
    EmergencyConsentStore? emergencyConsentStore,
    SosBleCoordinator? bleCoordinator,
    BleTransportClient? bleTransport,
    Future<void> Function()? onBleStartRequested,
    Future<Position?> Function()? locationProvider,
    ChatRepository? chatRepository,
  }) {
    final child = SosPage(
      repository: source,
      chatRepository: chatRepository,
      isGuest: true,
      rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
      relayPreferenceStore: MemoryRelayPreferenceStore(),
      emergencyConsentStore:
          emergencyConsentStore ?? MemoryEmergencyConsentStore(),
      bleCoordinator: bleCoordinator,
      bleTransport: bleTransport,
      onBleStartRequested: onBleStartRequested,
      locationProvider: locationProvider ?? noLocation,
    );
    return MaterialApp(theme: AppTheme.light, home: wrap?.call(child) ?? child);
  }

  Future<void> completeSosHold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('ส่ง SOS')),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  setUpAll(() {
    registerFallbackValue(_SosMessageFake());
    registerFallbackValue(_ChatMessageFake());
  });

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final auth = _Auth();
    final cloud = _Cloud();
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

  testWidgets('home keeps the emergency action and removes repeated guidance', (
    tester,
  ) async {
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    expect(find.text('ส่ง SOS'), findsOneWidget);
    expect(find.text('กดค้างเพื่อเริ่ม'), findsOneWidget);
    final sosAction = tester.getRect(
      find.byKey(const ValueKey('primary-sos-hold-action')),
    );
    expect(sosAction.height, greaterThanOrEqualTo(280));
    expect(sosAction.left, lessThanOrEqualTo(12));
    expect(
      sosAction.right,
      greaterThanOrEqualTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio - 12,
      ),
    );
    expect(find.text('พร้อมเมื่อคุณต้องการความช่วยเหลือ'), findsNothing);
    expect(find.textContaining('ใช้ SOS เมื่อมีเหตุฉุกเฉิน'), findsNothing);
    expect(find.text('My SOS'), findsNothing);
    expect(find.text('ประวัติ'), findsOneWidget);
    expect(find.text('ตั้งค่า'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('primary SOS action exposes an actionable semantic hint', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    final action = find.byKey(const ValueKey('primary-sos-hold-action'));
    final node = tester.getSemantics(action);
    expect(node.label, contains('กดค้างเพื่อส่ง SOS'));
    expect(node.hint, contains('กดค้างเพื่อเริ่ม'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, ui.Tristate.isTrue);

    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('the complete active SOS banner opens the exact incident chat', (
    tester,
  ) async {
    await repository.create(id: 'active-banner-incident', type: 'emergency');
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    final banner = find.byKey(
      const ValueKey('active-sos-chat-banner-active-banner-incident'),
    );
    expect(banner, findsOneWidget);
    final action = find.byKey(const ValueKey('primary-sos-hold-action'));
    final route = find.byKey(
      const ValueKey('current-sos-route-active-banner-incident'),
    );
    expect(route, findsOneWidget);
    expect(find.text('Current SOS route'), findsOneWidget);
    expect(find.text('Next device not recorded'), findsOneWidget);
    expect(
      tester.getTopLeft(banner).dy,
      lessThan(tester.getTopLeft(action).dy),
    );
    expect(
      tester.getTopLeft(route).dy,
      greaterThan(tester.getBottomRight(banner).dy),
    );
    final node = tester.getSemantics(banner);
    expect(node.label, contains('เปิดแชต SOS'));
    expect(node.hint, contains('active-banner-incident'));

    await tester.tapAt(tester.getTopLeft(banner) + const Offset(12, 12));
    await tester.tapAt(tester.getBottomRight(banner) - const Offset(12, 12));
    await tester.pumpAndSettle();

    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(find.text('SOS source device'), findsOneWidget);
    expect(find.text('SOS Details'), findsNothing);
    expect(await repository.listActiveIncidents(), hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('แชตฉุกเฉิน'), findsNothing);
    expect(banner, findsOneWidget);
    semantics.dispose();
    await disposeTree(tester);
  });

  testWidgets('active SOS banner stays mounted throughout hold progress', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await repository.create(id: 'active-during-hold', type: 'emergency');
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    final banner = find.byKey(
      const ValueKey('active-sos-chat-banner-active-during-hold'),
    );
    final action = find.byKey(const ValueKey('primary-sos-hold-action'));
    expect(banner, findsOneWidget);
    expect(action, findsOneWidget);
    final initialBannerRect = tester.getRect(banner);

    final gesture = await tester.startGesture(tester.getCenter(action));
    for (var tick = 0; tick < 8; tick++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(banner, findsOneWidget);
      expect(tester.getRect(banner), initialBannerRect);
    }
    await gesture.up();
    await tester.pump();

    expect(banner, findsOneWidget);
    expect(tester.getRect(banner), initialBannerRect);
    expect(await repository.listActiveIncidents(), hasLength(1));
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('History card opens Chat and exposes a separate Details action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await repository.create(
      id: 'history-chat-incident',
      type: 'emergency',
      message: 'History card route',
    );
    await tester.pumpWidget(app(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ประวัติ'));
    await tester.pumpAndSettle();
    final card = find.byKey(
      const ValueKey('history-sos-chat-card-history-chat-incident'),
    );
    expect(card, findsOneWidget);
    expect(find.text('SOS · history-chat-incident'), findsOneWidget);
    expect(find.text('EMERGENCY'), findsNothing);
    expect(
      find.byKey(const ValueKey('history-status-summary')),
      findsOneWidget,
    );
    expect(find.text('ทั้งหมด'), findsOneWidget);
    expect(find.text('กำลัง'), findsOneWidget);
    expect(find.text('สำเร็จ'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);
    expect(find.text('All time'), findsNothing);
    expect(find.text('Currently open'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('sos-details-button-history-chat-incident')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('ค้นหาประวัติ'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('ปิดการค้นหา'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const ValueKey('history-filter-resolved')));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    await tester.tap(find.byKey(const ValueKey('history-filter-active')));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);

    await tester.tapAt(tester.getTopLeft(card) + const Offset(18, 18));
    await tester.pumpAndSettle();
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(find.text('SOS source device'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sos-details-button-history-chat-incident')),
    );
    await tester.pumpAndSettle();
    expect(find.text('SOS Details'), findsOneWidget);
    final detailSheet = find.byType(BottomSheet);
    expect(
      find.descendant(
        of: detailSheet,
        matching: find.text('History card route'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: detailSheet, matching: find.text('emergency')),
      findsNothing,
    );
    expect(
      find.text('Incident coordinates are not available.'),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  for (final relay in [true, false]) {
    testWidgets(
      'Chat composer waits for durable enqueue, not radio drain; relay=$relay',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final coordinator = _BleCoordinator();
        final enqueueGate = Completer<void>();
        final radioGate = Completer<void>();
        addTearDown(() {
          if (!enqueueGate.isCompleted) enqueueGate.complete();
          if (!radioGate.isCompleted) radioGate.complete();
        });
        var queued = 0;
        when(() => coordinator.watchDeliveryForSos(any()))
            .thenAnswer((_) => const Stream.empty());
        when(() => coordinator.watchRelayStatus(any()))
            .thenAnswer((_) => const Stream.empty());
        when(
          () => coordinator.resolveVerifiedChatParticipant(any()),
        ).thenAnswer(
          (_) async => relay
              ? (keyId: 'verified-recipient', publicKey: 'verified-public-key')
              : null,
        );
        when(() => coordinator.processDue())
            .thenAnswer((_) => radioGate.future);
        when(
          () => coordinator.enqueueChatThroughRelay(
            chat: any(named: 'chat'),
            recipientKeyId: any(named: 'recipientKeyId'),
            recipientPublicKey: any(named: 'recipientPublicKey'),
          ),
        ).thenAnswer((_) async {
          queued++;
          await enqueueGate.future;
        });
        when(
          () => coordinator.enqueueChat(
            any(),
            destinationId: any(named: 'destinationId'),
          ),
        ).thenAnswer((_) async {
          queued++;
          await enqueueGate.future;
          return _OutboxFake();
        });
        final chat = PersistentChatRepository(
          database: database,
          ownerId: guestDeviceOwnerId,
        );
        await tester.pumpWidget(
          app(
            repository,
            bleCoordinator: coordinator,
            chatRepository: chat,
            onBleStartRequested: () async {},
          ),
        );
        await tester.pumpAndSettle();
        await completeSosHold(tester);
        final incident = (await repository.listActiveIncidents()).single;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        final send = find.widgetWithIcon(IconButton, Icons.send);
        await tester.enterText(find.byType(TextField), 'first durable message');
        await tester.tap(send);
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(queued, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(await chat.loadMessages(incident.id), hasLength(1));
        // A second tap cannot duplicate a message while its queue write is pending.
        await tester.enterText(
          find.byType(TextField),
          'second durable message',
        );
        final button = find
            .byType(IconButton)
            .evaluate()
            .map((e) => e.widget)
            .cast<IconButton>()
            .where((w) => w.icon is SizedBox)
            .single;
        expect(button.onPressed, isNull);
        enqueueGate.complete();
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(radioGate.isCompleted, isFalse);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.widget<IconButton>(send).onPressed, isNotNull);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(queued, 2);
        final messages = await chat.loadMessages(incident.id);
        expect(messages.map((m) => m.text), [
          'first durable message',
          'second durable message',
        ]);
        expect(
          messages.every((m) => m.status == ChatDeliveryStatus.pending),
          isTrue,
        );
        expect(radioGate.isCompleted, isFalse);
        await disposeTree(tester);
      },
    );
  }

  testWidgets('successful SOS creation opens chat and Back does not resubmit', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(repository, bleTransport: _Transport()));
    await tester.pumpAndSettle();

    await completeSosHold(tester);

    final incidents = await repository.listActiveIncidents();
    expect(incidents, hasLength(1));
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(find.text('SOS source device'), findsOneWidget);
    expect(find.text('SOS Details'), findsNothing);
    expect(find.text('SOS relay options'), findsNothing);
    expect(find.text('Choose BLE recipient'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('ขอความช่วยเหลือ'), findsWidgets);
    expect(await repository.listActiveIncidents(), hasLength(1));
    expect(
      find.byKey(ValueKey('active-sos-chat-banner-${incidents.single.id}')),
      findsOneWidget,
    );
    await disposeTree(tester);
  });

  testWidgets(
    'saved relay consent queues automatic routing without delaying Chat',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final coordinator = _BleCoordinator();
      final relayGate = Completer<void>();
      var starts = 0;
      when(
        () => coordinator.enqueuePublicRelay(
          any(),
          includeLocation: any(named: 'includeLocation'),
        ),
      ).thenAnswer((_) => relayGate.future);
      when(() => coordinator.watchDeliveryForSos(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => coordinator.watchRelayStatus(any()))
          .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

      await tester.pumpWidget(
        app(
          repository,
          emergencyConsentStore: MemoryEmergencyConsentStore(
            consent: const EmergencyConsent(
              configured: true,
              allowPublicRelay: true,
              shareLocation: false,
            ),
          ),
          bleCoordinator: coordinator,
          bleTransport: _Transport(),
          onBleStartRequested: () async => starts++,
        ),
      );
      await tester.pumpAndSettle();
      await completeSosHold(tester);

      expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
      expect(find.text('SOS relay options'), findsNothing);
      expect(find.text('Choose BLE recipient'), findsNothing);
      final incidents = await repository.listActiveIncidents();
      expect(incidents, hasLength(1));
      verify(
        () => coordinator.enqueuePublicRelay(
          incidents.single,
          includeLocation: false,
        ),
      ).called(1);
      expect(
        starts,
        0,
        reason: 'Chat must not wait for relay queue completion.',
      );

      relayGate.complete();
      await tester.pump();
      expect(starts, 1);
      await disposeTree(tester);
    },
  );

  testWidgets('safe consent neither reads location nor queues public relay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final coordinator = _BleCoordinator();
    var locationReads = 0;
    var starts = 0;
    when(() => coordinator.watchDeliveryForSos(any()))
        .thenAnswer((_) => Stream.value(null));
    when(() => coordinator.watchRelayStatus(any()))
        .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

    await tester.pumpWidget(
      app(
        repository,
        bleCoordinator: coordinator,
        emergencyConsentStore: MemoryEmergencyConsentStore(),
        locationProvider: () async {
          locationReads++;
          return null;
        },
        onBleStartRequested: () async => starts++,
      ),
    );
    await tester.pumpAndSettle();
    await completeSosHold(tester);

    expect(locationReads, 0);
    verifyNever(
      () => coordinator.enqueuePublicRelay(
        any(),
        includeLocation: any(named: 'includeLocation'),
      ),
    );
    expect(starts, 1);
    final deliveryStatus = find.byKey(
      const ValueKey('emergency-delivery-status'),
    );
    expect(deliveryStatus, findsOneWidget);
    final statusText = tester.widget<Text>(
      find.descendant(of: deliveryStatus, matching: find.byType(Text)),
    );
    expect(statusText.data, contains('Final delivery is unconfirmed'));
    await disposeTree(tester);
  });

  testWidgets(
    'persists SOS and opens Chat before automatic location resolves',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final coordinator = _BleCoordinator();
      final location = Completer<Position?>();
      when(
        () => coordinator.enqueuePublicRelay(
          any(),
          includeLocation: any(named: 'includeLocation'),
        ),
      ).thenAnswer((_) async {});
      when(() => coordinator.watchDeliveryForSos(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => coordinator.watchRelayStatus(any()))
          .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

      await tester.pumpWidget(
        app(
          repository,
          emergencyConsentStore: MemoryEmergencyConsentStore(
            consent: const EmergencyConsent(
              configured: true,
              allowPublicRelay: true,
              shareLocation: true,
            ),
          ),
          bleCoordinator: coordinator,
          bleTransport: _Transport(),
          locationProvider: () => location.future,
        ),
      );
      await tester.pumpAndSettle();
      await completeSosHold(tester);

      expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
      final persisted = await repository.listActiveIncidents();
      expect(persisted, hasLength(1));
      expect(persisted.single.latitude, isNull);
      expect(persisted.single.longitude, isNull);

      location.complete(
        Position(
          longitude: 100.5001,
          latitude: 13.7001,
          timestamp: DateTime.utc(2026),
          accuracy: 8,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1,
          floor: null,
          isMocked: true,
        ),
      );
      await tester.pumpAndSettle();

      final updated = await repository.listActiveIncidents();
      expect(updated.single.latitude, 13.7001);
      expect(updated.single.longitude, 100.5001);
      verify(() => coordinator.enqueuePublicRelay(any(), includeLocation: true))
          .called(1);
      await disposeTree(tester);
    },
  );

  testWidgets(
    'location check retries locally without creating SOS or changing consent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pending = Completer<Position?>();
      var reads = 0;
      final consent = MemoryEmergencyConsentStore();
      await tester.pumpWidget(
        app(
          repository,
          emergencyConsentStore: consent,
          locationProvider: () {
            reads++;
            if (reads == 1) return pending.future;
            throw const LocationAcquisitionException(
              'Specific GPS timeout',
              category: 'timed_out',
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ตั้งค่า'));
      await tester.pumpAndSettle();
      final check = find.byKey(const ValueKey('emergency-location-check'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.tap(check);
      await tester.pump();
      expect(reads, 1);
      pending.complete(
        Position(
          longitude: 100.5,
          latitude: 13.7,
          timestamp: DateTime.now().toUtc(),
          accuracy: 8,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Current location found. This check did not share coordinates.',
        ),
        findsOneWidget,
      );
      expect(await repository.listActiveIncidents(), isEmpty);
      expect(await database.select(database.bleOutbox).get(), isEmpty);
      expect(consent.consent.shareLocation, isFalse);
      expect(consent.consent.allowPublicRelay, isFalse);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Specific GPS timeout'), findsOneWidget);
      expect(await repository.listActiveIncidents(), isEmpty);
      await disposeTree(tester);
    },
  );

  testWidgets(
    'SOS shares a pending location check but its own deadline keeps relay moving',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pending = Completer<Position?>();
      var reads = 0;
      final routed = <bool>[];
      final coordinator = _BleCoordinator();
      when(
        () => coordinator.enqueuePublicRelay(
          any(),
          includeLocation: any(named: 'includeLocation'),
        ),
      ).thenAnswer((call) async {
        routed.add(call.namedArguments[#includeLocation] as bool);
      });
      when(() => coordinator.watchDeliveryForSos(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => coordinator.watchRelayStatus(any()))
          .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());
      await tester.pumpWidget(
        app(
          repository,
          bleCoordinator: coordinator,
          emergencyConsentStore: MemoryEmergencyConsentStore(
            consent: const EmergencyConsent(
              configured: true,
              allowPublicRelay: true,
              shareLocation: true,
            ),
          ),
          locationProvider: () {
            reads++;
            return pending.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ตั้งค่า'));
      await tester.pumpAndSettle();
      final check = find.byKey(const ValueKey('emergency-location-check'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pump();
      expect(reads, 1);
      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      await completeSosHold(tester);
      expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
      expect(await repository.listActiveIncidents(), hasLength(1));
      expect(reads, 1);
      expect(routed, isEmpty);
      await tester.pump(const Duration(seconds: 21));
      await tester.pumpAndSettle();
      expect(routed, [false]);
      expect(
        find.textContaining('Location request timed out.'),
        findsOneWidget,
      );
      pending.complete(
        Position(
          longitude: 100.5,
          latitude: 13.7,
          timestamp: DateTime.now().toUtc(),
          accuracy: 8,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect((await repository.listActiveIncidents()).single.latitude, isNull);
      expect(
        routed,
        [false],
        reason:
            'A later local check must not rewrite already routed SOS evidence.',
      );
      await disposeTree(tester);
    },
  );

  testWidgets('location failure keeps SOS and relay routing alive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final coordinator = _BleCoordinator();
    when(
      () => coordinator.enqueuePublicRelay(
        any(),
        includeLocation: any(named: 'includeLocation'),
      ),
    ).thenAnswer((_) async {});
    when(() => coordinator.watchDeliveryForSos(any()))
        .thenAnswer((_) => Stream.value(null));
    when(() => coordinator.watchRelayStatus(any()))
        .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

    await tester.pumpWidget(
      app(
        repository,
        emergencyConsentStore: MemoryEmergencyConsentStore(
          consent: const EmergencyConsent(
            configured: true,
            allowPublicRelay: true,
            shareLocation: true,
          ),
        ),
        bleCoordinator: coordinator,
        bleTransport: _Transport(),
        locationProvider: () async => throw StateError('synthetic GPS failure'),
      ),
    );
    await tester.pumpAndSettle();
    await completeSosHold(tester);
    await tester.pumpAndSettle();

    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
    expect(
      find.textContaining(
        'Location unavailable — SOS was saved without coordinates',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Current location is unavailable or invalid.'),
      findsOneWidget,
    );
    expect(await repository.listActiveIncidents(), hasLength(1));
    verify(() => coordinator.enqueuePublicRelay(any(), includeLocation: false))
        .called(1);
    await disposeTree(tester);
  });
  testWidgets(
    'specific location failure is preserved while SOS and relay remain available',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final coordinator = _BleCoordinator();
      when(
        () => coordinator.enqueuePublicRelay(
          any(),
          includeLocation: any(named: 'includeLocation'),
        ),
      ).thenAnswer((_) async {});
      when(() => coordinator.watchDeliveryForSos(any()))
          .thenAnswer((_) => Stream.value(null));
      when(() => coordinator.watchRelayStatus(any()))
          .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

      await tester.pumpWidget(
        app(
          repository,
          emergencyConsentStore: MemoryEmergencyConsentStore(
            consent: const EmergencyConsent(
              configured: true,
              allowPublicRelay: true,
              shareLocation: true,
            ),
          ),
          bleCoordinator: coordinator,
          bleTransport: _Transport(),
          locationProvider: () async =>
              throw const LocationAcquisitionException(
                'Specific GPS timeout',
                category: 'timed_out',
              ),
        ),
      );
      await tester.pumpAndSettle();
      await completeSosHold(tester);
      await tester.pumpAndSettle();

      expect(find.text('แชตฉุกเฉิน'), findsOneWidget);
      expect(
        find.textContaining(
          'Location unavailable — SOS was saved without coordinates',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Specific GPS timeout'), findsOneWidget);
      expect(await repository.listActiveIncidents(), hasLength(1));
      verify(
        () => coordinator.enqueuePublicRelay(any(), includeLocation: false),
      ).called(1);
      await disposeTree(tester);
    },
  );

  testWidgets('late location failure after Chat is closed is ignored safely', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final coordinator = _BleCoordinator();
    final location = Completer<Position?>();
    when(
      () => coordinator.enqueuePublicRelay(
        any(),
        includeLocation: any(named: 'includeLocation'),
      ),
    ).thenAnswer((_) async {});
    when(() => coordinator.watchDeliveryForSos(any()))
        .thenAnswer((_) => Stream.value(null));
    when(() => coordinator.watchRelayStatus(any()))
        .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

    await tester.pumpWidget(
      app(
        repository,
        emergencyConsentStore: MemoryEmergencyConsentStore(
          consent: const EmergencyConsent(
            configured: true,
            allowPublicRelay: true,
            shareLocation: true,
          ),
        ),
        bleCoordinator: coordinator,
        bleTransport: _Transport(),
        locationProvider: () => location.future,
      ),
    );
    await tester.pumpAndSettle();
    await completeSosHold(tester);
    expect(find.text('แชตฉุกเฉิน'), findsOneWidget);

    await tester.pageBack();
    location.completeError(StateError('late GPS failure'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(await repository.listActiveIncidents(), hasLength(1));
    await disposeTree(tester);
  });

  testWidgets('location is attached to public relay only after saved consent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final coordinator = _BleCoordinator();
    SosMessage? relayed;
    bool? includedLocation;
    when(
      () => coordinator.enqueuePublicRelay(
        any(),
        includeLocation: any(named: 'includeLocation'),
      ),
    ).thenAnswer((invocation) async {
      relayed = invocation.positionalArguments.single as SosMessage;
      includedLocation = invocation.namedArguments[#includeLocation] as bool;
    });
    when(() => coordinator.watchDeliveryForSos(any()))
        .thenAnswer((_) => Stream.value(null));
    when(() => coordinator.watchRelayStatus(any()))
        .thenAnswer((_) => const Stream<RelayStatusSnapshot>.empty());

    await tester.pumpWidget(
      app(
        repository,
        bleCoordinator: coordinator,
        emergencyConsentStore: MemoryEmergencyConsentStore(
          consent: const EmergencyConsent(
            configured: true,
            allowPublicRelay: true,
            shareLocation: true,
          ),
        ),
        locationProvider: () async => Position(
          longitude: 100.5001,
          latitude: 13.7001,
          timestamp: DateTime.utc(2026),
          accuracy: 8,
          altitude: 0,
          altitudeAccuracy: 1,
          heading: 0,
          headingAccuracy: 1,
          speed: 0,
          speedAccuracy: 1,
          floor: null,
          isMocked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await completeSosHold(tester);

    expect(includedLocation, isTrue);
    expect(relayed?.latitude, 13.7001);
    expect(relayed?.longitude, 100.5001);
    await disposeTree(tester);
  });

  testWidgets('failed SOS persistence reports an error and never opens chat', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final failing = _FailingRepository();
    when(() => failing.database).thenReturn(database);
    when(() => failing.watchAll()).thenAnswer((_) => Stream.value([]));
    when(() => failing.listActiveIncidents()).thenAnswer((_) async => []);
    when(
      () => failing.create(
        id: any(named: 'id'),
        type: any(named: 'type'),
        message: any(named: 'message'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        destinationId: any(named: 'destinationId'),
      ),
    ).thenThrow(StateError('persistence rejected'));

    await tester.pumpWidget(app(failing));
    await tester.pumpAndSettle();
    await completeSosHold(tester);

    expect(find.text('แชตฉุกเฉิน'), findsNothing);
    expect(find.textContaining('Failed to send SOS'), findsOneWidget);
    verify(
      () => failing.create(
        id: any(named: 'id'),
        type: 'emergency',
        message: 'Emergency SOS',
        latitude: null,
        longitude: null,
        destinationId: null,
      ),
    ).called(1);
    await disposeTree(tester);
  });

  testWidgets('chat remains responsive and labels every delivery state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 1, 1, 12);
    final messages = ChatDeliveryStatus.values
        .map(
          (status) => EmergencyChatMessage(
            id: status.name,
            sosId: 'responsive-incident',
            senderId: 'me',
            text: 'message ${status.name}',
            createdAt: now,
            status: status,
            isMine: true,
          ),
        )
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(1.6),
          ),
          child: EmergencyChatPage(
            sosId: 'responsive-incident',
            contactName: 'Incident responsive-incident',
            repository: _StaticChatRepository(messages),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Waiting to send',
      'Forwarded · awaiting confirmation',
      'Saved on destination device',
      'Send failed',
    ]) {
      await tester.scrollUntilVisible(
        find.textContaining(label),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining(label), findsOneWidget);
    }
    expect(find.byTooltip('Attach image'), findsNothing);
    expect(find.byTooltip('Share location'), findsNothing);
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });
}
