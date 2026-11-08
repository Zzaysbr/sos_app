import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_inbox_repository.dart';

Future<void> seed(AppDatabase db, String owner, String state) async {
  final old = DateTime.utc(2026, 1, 1);
  await db
      .into(db.rescueInbox)
      .insert(
        RescueInboxCompanion.insert(
          ownerId: owner,
          originMessageId: 'origin',
          incidentId: 'incident',
          originKeyId: 'origin-key',
          immutableDigest: 'digest',
          emergencyType: 'emergency',
          emergencyMessage: 'Saved incident',
          includeLocation: false,
          incomingHopCount: 1,
          incomingPath: '["origin","relay"]',
          createdAt: old,
          expiresAt: old.add(const Duration(minutes: 30)),
          receivedAt: old,
          state: state,
        ),
      );
}

void main() {
  test('stopping expired legacy tracking survives reopen and preserves data/owner isolation', () async {
    final temp = await Directory.systemTemp.createTemp('rescue-stop-');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/local.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    await seed(db, 'owner-a', 'locallyAccepted');
    await seed(db, 'owner-b', 'locallyAccepted');
    final now = DateTime.utc(2026, 1, 1);
    await db
        .into(db.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'incident',
            ownerId: 'owner-a',
            type: 'emergency',
            status: 'active',
            syncState: 'deviceOnly',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.chatMessages)
        .insert(
          ChatMessagesCompanion.insert(
            messageId: 'saved-chat',
            sosId: 'incident',
            ownerId: 'owner-a',
            senderId: 'origin',
            messageType: 'text',
            textContent: const Value('Saved message'),
            createdAt: now,
            deliveryStatus: 'sent',
          ),
        );
    final beforeCandidate = (await RescueInboxRepository(
      db,
      ownerId: 'owner-a',
    ).find('origin'))!;
    final beforeChat = await db.select(db.chatMessages).getSingle();
    final beforeSos = await db.select(db.sosMessages).getSingle();
    final repo = RescueInboxRepository(db, ownerId: 'owner-a');
    await repo.stopFollowing('origin');
    await repo.stopFollowing('origin');
    // A stale Offer Help callback cannot reactivate a locally archived entry.
    expect((await repo.acceptLocally('origin'))!.state, 'archivedLocally');
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final restored = (await RescueInboxRepository(
      db,
      ownerId: 'owner-a',
    ).find('origin'))!;
    expect(restored.state, 'archivedLocally');
    expect(restored.copyWith(state: beforeCandidate.state), beforeCandidate);
    expect(
      (await RescueInboxRepository(db, ownerId: 'owner-b').find('origin'))!
          .state,
      'locallyAccepted',
    );
    expect(await db.select(db.chatMessages).getSingle(), beforeChat);
    expect(await db.select(db.sosMessages).getSingle(), beforeSos);
    expect(await db.select(db.bleOutbox).get(), isEmpty);
    expect(await db.select(db.sosSyncQueue).get(), isEmpty);
    expect(await db.select(db.rescueResponseOutbox).get(), isEmpty);
    expect(await db.select(db.rescueInbox).get(), hasLength(2));
  });

  test(
    'stop following cannot overwrite a terminal or unaccepted candidate',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (final state in ['cancelled', 'resolved', 'pending']) {
        await seed(db, state, state);
        final repo = RescueInboxRepository(db, ownerId: state);
        await repo.stopFollowing('origin');
        expect((await repo.find('origin'))!.state, state);
      }
    },
  );
}
