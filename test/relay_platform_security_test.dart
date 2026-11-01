import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android backup rules exclude every relay secure-storage namespace file',
    () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      final legacyRules = File(
        'android/app/src/main/res/xml/relay_backup_rules.xml',
      ).readAsStringSync();
      final extractionRules = File(
        'android/app/src/main/res/xml/relay_data_extraction_rules.xml',
      ).readAsStringSync();
      const protectedFiles = [
        'sos_relay_v2.xml',
        'FlutterSecureKeyStorage:sos_relay_v2.xml',
        'FlutterSecureStorageConfiguration:sos_relay_v2.xml',
      ];

      expect(
        manifest,
        contains('android:fullBackupContent="@xml/relay_backup_rules"'),
      );
      expect(
        manifest,
        contains(
          'android:dataExtractionRules="@xml/relay_data_extraction_rules"',
        ),
      );
      for (final protectedFile in protectedFiles) {
        expect(legacyRules, contains('path="$protectedFile"'));
        expect(
          RegExp('path="$protectedFile"').allMatches(extractionRules),
          hasLength(2),
        );
      }
    },
  );

  test(
    'relay key configuration is device-only and backup migration is disabled',
    () {
      final source = File('lib/features/nearby_ble/data/relay_key_store.dart')
          .readAsStringSync();
      expect(source, contains('migrateWithBackup: false'));
      expect(source, contains('KeychainAccessibility.unlocked_this_device'));
      expect(source, contains('synchronizable: false'));
      expect(source, isNot(contains('first_unlock_this_device')));
    },
  );

  test('Android peripheral relay frames retain receiver-safe pacing', () {
    final source = File(
      'android/app/src/main/kotlin/com/n1cxltine/sosapp/'
      'BleTransportBridge.kt',
    ).readAsStringSync();

    expect(source, contains('notificationInterFrameDelayMs = 12L'));
    expect(source, contains('}, notificationInterFrameDelayMs)'));
    expect(
      RegExp(
        r'pending\.result\.success\(null\)[\s\S]*?'
        r'mainHandler\.postDelayed\(\{[\s\S]*?'
        r'notificationInFlight\.remove\(id\)[\s\S]*?'
        r'\}, notificationInterFrameDelayMs\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('iOS peripheral relay frames retain receiver-safe pacing', () {
    final source = File('ios/Runner/BleTransport.swift').readAsStringSync();

    expect(source, contains('peripheralInterFrameDelay: TimeInterval = 0.012'));
    expect(source, contains('pacedPeripheralSends.insert(uuid)'));
    expect(
      source,
      contains(
        'DispatchQueue.main.asyncAfter('
        'deadline: .now() + peripheralInterFrameDelay)',
      ),
    );
    expect(
      RegExp(
        r'pending\.result\(nil\)[\s\S]*?'
        r'pacedPeripheralSends\.insert\(uuid\)[\s\S]*?'
        r'peripheralInterFrameDelay',
      ).hasMatch(source),
      isTrue,
    );
  });
}
