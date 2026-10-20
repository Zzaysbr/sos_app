import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sos_app/core/database/app_database.dart';
import 'package:sos_app/features/nearby_ble/data/ble_delivery_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_delivery_state.dart';
import 'package:sos_app/features/nearby_ble/domain/location_ble_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/sos_ble_envelope.dart';

LocationBleEnvelope _update({
  required String messageId,
  String recipientId = 'peer-1',
  DateTime? createdAt,
  DateTime? expiresAt,
}) => LocationBleEnvelope.update(
  messageId: messageId,
  sosId: 'sos-1',
  senderDeviceId: 'device-1',
  recipientId: recipientId,
  latitude: 13.7,
  longitude: 100.5,
  accuracyMeters: 4,
  createdAt: createdAt ?? DateTime.utc(2026, 1, 1, 12),
  expiresAt: expiresAt ?? DateTime.utc(2026, 1, 1, 12, 1),
);

void main() {
  late AppDatabase database;
  late BleDeliveryRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = BleDeliveryRepository(database);
  });

  tearDown(() => database.close());

  test('validates location identity, coordinates and expiration', () {
    expect(
      () => _update(messageId: 'location-1').toBleMessage(),
      returnsNormally,
    );
    expect(
      () => _update(
        messageId: 'location-expired',
        expiresAt: DateTime.utc(2026, 1, 1, 12, 1),
      ).validate(now: DateTime.utc(2026, 1, 1, 12, 2)),
      throwsA(isA<LocationBleEnvelopeException>()),
    );
    expect(
      () => LocationBleEnvelope.update(
        messageId: 'location-invalid',
        sosId: 'sos-1',
        senderDeviceId: 'device-1',
        recipientId: 'peer-1',
        latitude: double.nan,
        longitude: 100,
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 1, 1),
      ).toBleMessage(),
      throwsA(isA<LocationBleEnvelopeException>()),
    );
  });

  test('requires the explicit recipient and bounds queued updates', () async {
    final first = _update(messageId: 'location-old');
    final second = _update(messageId: 'location-new');
    final now = DateTime.utc(2026, 1, 1, 12);
    await repository.enqueueLocationOutbox(
      first,
      destinationId: 'peer-1',
      now: now,
    );
    await repository.enqueueLocationOutbox(
      second,
      destinationId: 'peer-1',
      now: now,
    );

    final rows = await database.select(database.bleOutbox).get();
    expect(rows.map((row) => row.messageId), ['location-new']);
    expect(
      () => repository.enqueueLocationOutbox(
        _update(messageId: 'location-wrong'),
        destinationId: 'peer-2',
      ),
      throwsA(isA<BleDeliveryStateException>()),
    );

    final claimed = await repository.claimOutboxForSending(
      'location-new',
      now: now,
    );
    await repository.transitionOutboxState(
      claimed!.messageId,
      BleOutboxState.failed,
      now: now,
      nextRetryAt: now.add(const Duration(minutes: 1)),
      error: 'temporary failure',
    );
    expect(
      (await repository.lookupOutbox('location-new'))!.destinationId,
      'peer-1',
    );
  });

  test('duplicate inbound location delivery is idempotent', () async {
    final update = _update(messageId: 'location-duplicate');
    final first = await repository.persistIncomingLocation(
      update,
      expectedRecipientId: 'peer-1',
      now: DateTime.utc(2026, 1, 1, 12),
    );
    final second = await repository.persistIncomingLocation(
      update,
      expectedRecipientId: 'peer-1',
      now: DateTime.utc(2026, 1, 1, 12),
    );

    expect(first.inserted, isTrue);
    expect(second.inserted, isFalse);
    expect(await database.select(database.bleInbox).get(), hasLength(1));
    expect(await database.select(database.sosMessages).get(), isEmpty);
  });

  test('wrong recipient and expired inbound updates are rejected', () async {
    expect(
      () => repository.persistIncomingLocation(
        _update(messageId: 'location-wrong-recipient'),
        expectedRecipientId: 'other-device',
        now: DateTime.utc(2026, 1, 1, 12),
      ),
      throwsA(isA<BleDeliveryStateException>()),
    );
    expect(
      () => repository.persistIncomingLocation(
        _update(
          messageId: 'location-expired-inbound',
          expiresAt: DateTime.utc(2026, 1, 1, 12, 1),
        ),
        expectedRecipientId: 'peer-1',
        now: DateTime.utc(2026, 1, 1, 12, 2),
      ),
      throwsA(isA<LocationBleEnvelopeException>()),
    );
  });

  test('latest incoming location ignores expired history', () async {
    await repository.persistIncomingLocation(
      _update(
        messageId: 'location-old-history',
        expiresAt: DateTime.utc(2026, 1, 1, 12, 1),
      ),
      expectedRecipientId: 'peer-1',
      now: DateTime.utc(2026, 1, 1, 12),
    );
    await repository.persistIncomingLocation(
      _update(
        messageId: 'location-current-history',
        createdAt: DateTime.utc(2026, 1, 1, 12, 0, 1),
        expiresAt: DateTime.utc(2026, 1, 1, 12, 10),
      ),
      expectedRecipientId: 'peer-1',
      now: DateTime.utc(2026, 1, 1, 12),
    );

    final current = await repository.latestIncomingLocation(
      'sos-1',
      now: DateTime.utc(2026, 1, 1, 12, 5),
    );
    expect(current!.messageId, 'location-current-history');
    expect(
      await repository.latestIncomingLocation(
        'sos-1',
        now: DateTime.utc(2026, 1, 1, 12, 20),
      ),
      isNull,
    );
  });

  test('latest incoming location can require the established sender', () async {
    await repository.persistIncomingLocation(
      _update(messageId: 'location-peer-a'),
      expectedRecipientId: 'peer-1',
      sourceDeviceId: 'device-1',
      now: DateTime.utc(2026, 1, 1, 12),
    );
    expect(
      (await repository.latestIncomingLocation(
        'sos-1',
        requiredSenderDeviceId: 'device-1',
        now: DateTime.utc(2026, 1, 1, 12),
      ))!.messageId,
      'location-peer-a',
    );
    expect(
      await repository.latestIncomingLocation(
        'sos-1',
        requiredSenderDeviceId: 'other-device',
        now: DateTime.utc(2026, 1, 1, 12),
      ),
      isNull,
    );
  });

  test(
    'receiver rejects an older update and a mismatched transport sender',
    () async {
      await repository.persistIncomingLocation(
        _update(messageId: 'location-new'),
        expectedRecipientId: 'peer-1',
        sourceDeviceId: 'device-1',
        now: DateTime.utc(2026, 1, 1, 12),
      );
      expect(
        () => repository.persistIncomingLocation(
          _update(
            messageId: 'location-old',
            createdAt: DateTime.utc(2026, 1, 1, 11, 59),
          ),
          expectedRecipientId: 'peer-1',
          sourceDeviceId: 'device-1',
          now: DateTime.utc(2026, 1, 1, 12),
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );
      expect(
        () => repository.persistIncomingLocation(
          _update(messageId: 'location-wrong-sender'),
          expectedRecipientId: 'peer-1',
          sourceDeviceId: 'other-device',
          now: DateTime.utc(2026, 1, 1, 12),
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );
    },
  );

  test(
    'location acknowledgement cannot acknowledge an SOS outbox row',
    () async {
      final sos = SosBleEnvelope.delivery(
        messageId: 'sos-message',
        sosId: 'sos-1',
        sosType: 'emergency',
        status: 'active',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await repository.enqueueOutbox(sos, destinationId: 'peer-1');
      final ack = LocationBleEnvelope.ack(
        messageId: 'location-ack:sos-message',
        sosId: 'sos-1',
        ackFor: 'sos-message',
        ackStatus: 'persisted',
        createdAt: DateTime.utc(2026, 1, 1, 1),
      );

      expect(
        () => repository.recordLocationAcknowledgement(
          ack,
          sourceDeviceId: 'peer-1',
        ),
        throwsA(isA<BleDeliveryStateException>()),
      );
      expect(
        (await repository.lookupOutbox('sos-message'))!.state,
        BleOutboxState.queued.wireValue,
      );
    },
  );

  test(
    'stopping location sharing expires only pending location rows',
    () async {
      await repository.enqueueLocationOutbox(
        _update(messageId: 'location-stop'),
        destinationId: 'peer-1',
        now: DateTime.utc(2026, 1, 1, 12),
      );
      final sos = SosBleEnvelope.delivery(
        messageId: 'sos-keep',
        sosId: 'sos-1',
        sosType: 'emergency',
        status: 'active',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 1),
      );
      await repository.enqueueOutbox(sos, destinationId: 'peer-1');

      final changed = await repository.expireLocationOutbox(
        'sos-1',
        now: DateTime.utc(2026, 1, 1, 12, 1),
      );

      expect(changed, 1);
      expect(
        (await repository.lookupOutbox('location-stop'))!.state,
        BleOutboxState.expired.wireValue,
      );
      expect(
        (await repository.lookupOutbox('sos-keep'))!.state,
        BleOutboxState.queued.wireValue,
      );
    },
  );

  test(
    'changing recipient expires the old update without rerouting it',
    () async {
      await repository.enqueueLocationOutbox(
        _update(messageId: 'location-peer-a', recipientId: 'peer-a'),
        destinationId: 'peer-a',
        now: DateTime.utc(2026, 1, 1, 12),
      );
      await repository.enqueueLocationOutbox(
        _update(messageId: 'location-peer-b', recipientId: 'peer-b'),
        destinationId: 'peer-b',
        now: DateTime.utc(2026, 1, 1, 12),
      );

      expect(
        (await repository.lookupOutbox('location-peer-a'))!.state,
        BleOutboxState.expired.wireValue,
      );
      final current = await repository.lookupOutbox('location-peer-b');
      expect(current!.destinationId, 'peer-b');
      expect(current.state, BleOutboxState.queued.wireValue);
    },
  );
}
