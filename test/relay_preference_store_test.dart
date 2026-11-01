import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/emergency_consent_store.dart';
import 'package:sos_app/features/nearby_ble/data/relay_preference_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preferences = MethodChannel('sos_app/preferences');

  test(
    'relay participation is disabled by default and changes explicitly',
    () async {
      final store = MemoryRelayPreferenceStore();

      expect(await store.loadParticipationEnabled(), isFalse);
      await store.saveParticipationEnabled(true);
      expect(await store.loadParticipationEnabled(), isTrue);
      await store.saveParticipationEnabled(false);
      expect(await store.loadParticipationEnabled(), isFalse);
    },
  );

  test(
    'emergency consent is safe by default and persists explicitly',
    () async {
      final store = MemoryEmergencyConsentStore();

      final initial = await store.load();
      expect(initial.configured, isFalse);
      expect(initial.allowPublicRelay, isFalse);
      expect(initial.shareLocation, isFalse);

      await store.save(
        const EmergencyConsent(
          configured: true,
          allowPublicRelay: true,
          shareLocation: false,
        ),
      );
      expect(store.consent.configured, isTrue);
      expect(store.consent.allowPublicRelay, isTrue);
      expect(store.consent.shareLocation, isFalse);
      expect(store.saveCount, 1);
    },
  );

  test('disabling public relay also removes location consent', () {
    const consent = EmergencyConsent(
      configured: true,
      allowPublicRelay: true,
      shareLocation: true,
    );

    final disabled = consent.copyWith(allowPublicRelay: false);
    expect(disabled.allowPublicRelay, isFalse);
    expect(disabled.shareLocation, isFalse);
  });

  test(
    'platform emergency consent uses the native preference contract',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(preferences, (call) async {
        calls.add(call);
        if (call.method == 'getEmergencyConsent') {
          return <String, Object?>{
            'configured': true,
            'allowPublicRelay': true,
            'shareLocation': false,
          };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(preferences, null));

      const store = PlatformEmergencyConsentStore();
      final loaded = await store.load();
      await store.save(
        const EmergencyConsent(
          configured: true,
          allowPublicRelay: true,
          shareLocation: true,
        ),
      );

      expect(loaded.allowPublicRelay, isTrue);
      expect(loaded.shareLocation, isFalse);
      expect(calls.map((call) => call.method), <String>[
        'getEmergencyConsent',
        'setEmergencyConsent',
      ]);
      expect(calls.last.arguments, <String, Object?>{
        'configured': true,
        'allowPublicRelay': true,
        'shareLocation': true,
      });
    },
  );

  test(
    'platform emergency consent rejects an unsafe saved combination',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        preferences,
        (_) async => <String, Object?>{
          'configured': true,
          'allowPublicRelay': false,
          'shareLocation': true,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(preferences, null));

      await expectLater(
        const PlatformEmergencyConsentStore().load(),
        throwsFormatException,
      );
    },
  );
}
