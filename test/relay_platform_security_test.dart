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

  test('Android central connection attempts have bounded native cleanup', () {
    final source = File(
      'android/app/src/main/kotlin/com/n1cxltine/sosapp/'
      'BleTransportBridge.kt',
    ).readAsStringSync();

    expect(source, contains('gattConnectionTimeoutMs = 15_000L'));
    expect(
      RegExp(
        r'clients\[id\] = gatt[\s\S]*?'
        r'scheduleConnectionTimeout\(id, gatt, attempt\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'GATT connection callback timeout[\s\S]*?'
        r'terminateTimedOutConnection\(',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'private fun terminateTimedOutConnection\([\s\S]*?'
        r'cleanupCentral\(id, gatt\)[\s\S]*?'
        r'"type" to "disconnected"',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'private fun cleanupCentral\([\s\S]*?'
        r'cancelConnectionTimeout\(id\)[\s\S]*?'
        r'cancelSetupTimeout\(id\)[\s\S]*?gatt\.close\(\)',
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains('if (clients[id] !== gatt)'));
  });

  test('Android missing notification callback retires the blocked session', () {
    final source = File(
      'android/app/src/main/kotlin/com/n1cxltine/sosapp/'
      'BleTransportBridge.kt',
    ).readAsStringSync();
    expect(source, contains('notificationCallbackTimeoutMs = 5_000L'));
    expect(source, contains('queue.firstOrNull() !== pending'));
    expect(
      source,
      contains('retireServerPeer(device, "notification_callback_timeout")'),
    );
    expect(source, contains('server?.cancelConnection(device)'));
    expect(source, contains('"error" to "notification_callback_timeout"'));
    expect(
      source,
      contains(
        'notificationTimeouts.remove(id)?.let(mainHandler::removeCallbacks)',
      ),
    );
    expect(
      source,
      contains('if (notificationQueues[id] !== queue) return@postDelayed'),
    );
  });

  test(
    'Android write timeout retires only its current GATT and completes once',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/n1cxltine/sosapp/'
        'BleTransportBridge.kt',
      ).readAsStringSync();
      expect(
        source,
        contains('!isCurrentGatt(gatt) || writeInFlight[id] !== pending'),
      );
      expect(
        source,
        contains(
          'terminateTimedOutConnection(id, gatt, attempt, "GATT write timed out for \$id")',
        ),
      );
      expect(source, contains('val active = writeInFlight.remove(id)'));
      expect(source, contains('val queued = writeQueues.remove(id)'));
      expect(
        source,
        contains('if (it !== active) it.result.error(code, message, null)'),
      );
    },
  );

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
