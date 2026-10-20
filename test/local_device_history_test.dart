import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';
import 'package:sos_app/features/sos/presentation/sos_page.dart';

class HistoryRepository extends Mock implements SosRepository {}

void main() {
  testWidgets(
    'device history exposes Guest details and map without account actions',
    (tester) async {
      final repository = HistoryRepository();
      final sos = SosMessage(
        id: 'original-guest-id',
        ownerId: guestDeviceOwnerId,
        type: 'emergency',
        message: 'Guest record stays here',
        latitude: 13.7,
        longitude: 100.5,
        status: 'active',
        syncState: 'pending',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      when(() => repository.watchAll()).thenAnswer((_) => Stream.value([]));
      when(() => repository.watchDeviceHistory())
          .thenAnswer((_) => Stream.value([sos]));
      await tester.pumpWidget(
        MaterialApp(home: SosPage(repository: repository, isGuest: true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ข้อมูลในเครื่อง'));
      await tester.pumpAndSettle();
      expect(find.text('Guest record stays here'), findsOneWidget);
      expect(find.text('ข้อมูลในเครื่องเท่านั้น'), findsOneWidget);
      await tester.tap(find.text('Guest record stays here'));
      await tester.pumpAndSettle();
      expect(find.text('SOS Details'), findsOneWidget);
      expect(find.text('View on map'), findsOneWidget);
      expect(find.text('Mark as Resolved'), findsNothing);
      expect(find.text('Cancel SOS'), findsNothing);
      expect(find.text('Open incident chat'), findsNothing);
      expect(find.text('Pending sync'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('active SOS detail has an immediately accessible close action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = HistoryRepository();
    final sos = SosMessage(
      id: 'synthetic-active-guest',
      ownerId: guestDeviceOwnerId,
      type: 'emergency',
      message: 'Synthetic active SOS',
      latitude: null,
      longitude: null,
      status: 'active',
      syncState: 'pending',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    when(() => repository.watchAll()).thenAnswer((_) => Stream.value([sos]));
    await tester.pumpWidget(
      MaterialApp(home: SosPage(repository: repository, isGuest: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Synthetic active SOS'));
    await tester.tap(find.text('Synthetic active SOS'));
    await tester.pumpAndSettle();
    expect(find.text('SOS Details'), findsOneWidget);
    final close = find.byTooltip('Close SOS details').hitTestable();
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('SOS Details'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
