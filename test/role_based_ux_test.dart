import 'dart:async';

import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/core/theme/app_theme.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
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

  Widget app(RolePreferenceStore store, {ThemeMode mode = ThemeMode.light}) =>
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: store,
        ),
      );

  testWidgets('role selection persists when the app shell is recreated', (
    tester,
  ) async {
    final store = MemoryRolePreferenceStore();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    expect(find.text('วันนี้คุณต้องการทำอะไร?'), findsOneWidget);

    await tester.tap(find.text('ฉันต้องการช่วยเหลือ'));
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
      find.text('SOS ของคุณยังทำงานอยู่ · แตะเพื่อกลับไปดู'),
      findsOneWidget,
    );

    await tester.tap(find.text('SOS ของคุณยังทำงานอยู่ · แตะเพื่อกลับไปดู'));
    await tester.pumpAndSettle();
    expect(store.value, AppRole.needHelp);
    expect(find.text('SOS Details'), findsOneWidget);
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
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

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

    await tester.pumpWidget(app(MemoryRolePreferenceStore(AppRole.rescue)));
    await tester.pumpAndSettle();
    expect(find.text('FIRE'), findsOneWidget);
    expect(find.text('MEDICAL'), findsNothing);
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
    await tester.pumpWidget(app(MemoryRolePreferenceStore(AppRole.rescue)));
    await tester.pumpAndSettle();

    expect(find.text('รับช่วยเหลือ'), findsOneWidget);
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
