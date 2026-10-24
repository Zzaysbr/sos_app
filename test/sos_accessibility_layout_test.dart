import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/core/theme/app_theme.dart';
import 'package:sos_app/features/role/data/role_preference_store.dart';
import 'package:sos_app/features/role/domain/app_role.dart';
import 'package:sos_app/features/sos/data/sos_cloud_service.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';
import 'package:sos_app/features/sos/presentation/sos_page.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _Cloud extends Mock implements SosCloudService {}

void main() {
  late AppDatabase database;
  late SosRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    repository = SosRepository(
      database: database,
      cloudService: _Cloud(),
      firebaseAuth: auth,
      localOwnerId: guestDeviceOwnerId,
    );
  });

  tearDown(() async => database.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    required double textScale,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> disposeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  for (final scale in [1.0, 1.1, 1.4]) {
    testWidgets('settings fit at text scale $scale', (tester) async {
      await pumpApp(tester, textScale: scale, size: const Size(384, 853));

      await tester.tap(find.text('ตั้งค่า'));
      await tester.pumpAndSettle();

      expect(find.text('My account'), findsOneWidget);
      expect(find.text('Sign in for new cloud SOS'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeApp(tester);
    });
  }

  for (final config in [
    (size: const Size(384, 853), scale: 1.0),
    (size: const Size(384, 853), scale: 1.1),
    (size: const Size(320, 700), scale: 1.4),
  ]) {
    testWidgets(
      'navigation remains visible and usable at ${config.size.width}px '
      'and scale ${config.scale}',
      (tester) async {
        await pumpApp(tester, textScale: config.scale, size: config.size);

        final navigationFinder = find.byType(NavigationBar);
        final navigation = tester.getRect(navigationFinder);
        final configuredHeight = tester
            .widget<NavigationBar>(navigationFinder)
            .height;
        final expectedLabel = config.size.width < 360
            ? 'SOS'
            : 'ขอความช่วยเหลือ';
        final label = tester.getRect(
          find.descendant(
            of: navigationFinder,
            matching: find.text(expectedLabel),
          ),
        );
        expect(label.top, greaterThanOrEqualTo(navigation.top));
        expect(
          label.bottom,
          lessThanOrEqualTo(navigation.bottom),
          reason:
              'configuredHeight=$configuredHeight navigation=$navigation '
              'label=$label',
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('ประวัติ'));
        await tester.pumpAndSettle();
        expect(find.text('ประวัติ SOS'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await disposeApp(tester);
      },
    );
  }
}
