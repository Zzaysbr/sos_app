import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/live_location_envelope.dart';

void main() {
  final created = DateTime.utc(2026, 11, 9, 12);

  LiveLocationEnvelope sample({int sequence = 1}) => LiveLocationEnvelope(
    messageId: 'live:1:$sequence',
    sosId: 'sos-1',
    participantId: 'device-a',
    participantRole: 'victim',
    originKeyId: 'key-a',
    originPublicKey: 'public-a',
    originSignature: 'signature-a',
    sequence: sequence,
    latitude: 13.7563,
    longitude: 100.5018,
    createdAt: created,
    expiresAt: created.add(const Duration(minutes: 2)),
  );

  test('round trips an immutable participant location and relay path', () {
    final forwarded = sample().copyWithHop(relayKeyId: 'key-b', nextHop: 1);
    final decoded = LiveLocationEnvelope.fromJson(forwarded.toJson());
    expect(decoded.sequence, 1);
    expect(decoded.participantRole, 'victim');
    expect(decoded.pathKeyIds, ['key-b']);
  });

  test('rejects stale or malformed relay paths', () {
    expect(
      () => sample().copyWithHop(relayKeyId: 'key-b', nextHop: 2).validate(),
      throwsA(isA<LiveLocationEnvelopeException>()),
    );
    expect(
      () => LiveLocationEnvelope.fromJson({
        ...sample().toJson(),
        'latitude': 999,
      }),
      throwsA(isA<LiveLocationEnvelopeException>()),
    );
  });

  test('expires according to receiver time', () {
    expect(
      () => sample().validate(now: created.add(const Duration(minutes: 3))),
      throwsA(isA<LiveLocationEnvelopeException>()),
    );
  });
  test('rejects unknown roles and future timestamps', () {
    expect(
      () => LiveLocationEnvelope.fromJson({
        ...sample().toJson(),
        'participantRole': 'admin',
      }),
      throwsA(isA<LiveLocationEnvelopeException>()),
    );
    expect(
      () =>
          sample().validate(now: created.subtract(const Duration(minutes: 1))),
      throwsA(isA<LiveLocationEnvelopeException>()),
    );
  });

  test(
    'coalesces GPS fixes and retains replay rejection without deleting Chat',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = BleDeliveryRepository(db);
      await repository.persistIncomingLiveLocation(
        sample(),
        sourceDeviceId: 'middle',
        now: created,
      );
      await repository.persistIncomingLiveLocation(
        sample(sequence: 2),
        sourceDeviceId: 'middle',
        now: created,
      );
      expect(await db.select(db.bleInbox).get(), hasLength(1));
      expect(
        (await repository.latestLiveLocation('sos-1', now: created))!.sequence,
        2,
      );
      await expectLater(
        repository.persistIncomingLiveLocation(
          sample(),
          sourceDeviceId: 'middle',
          now: created,
        ),
        throwsException,
      );
      expect(await db.select(db.bleInbox).get(), hasLength(1));
    },
  );
}
