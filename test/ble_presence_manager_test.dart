import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

class _PresenceTransport implements BleTransportClient {
  final controller = StreamController<BleEvent>.broadcast();
  final sentFrames = <List<int>>[];
  Completer<void>? firstWriteStarted;
  Completer<void>? releaseFirstWrite;
  int discoveryStarts = 0;
  int discoveryStops = 0;
  int advertisingStarts = 0;
  int advertisingStops = 0;
  bool failDiscoveryStart = false;
  bool failDiscoveryStop = false;

  @override
  Stream<BleEvent> get events => controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> connect(String deviceId) async {}
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {
    sentFrames.add(List<int>.from(frame));
    if (sentFrames.length == 1) {
      firstWriteStarted?.complete();
      await releaseFirstWrite?.future;
    }
  }

  @override
  Future<void> dispose() => controller.close();

  @override
  Future<void> startDiscovery() async {
    if (failDiscoveryStart) throw StateError('scan start failed');
    discoveryStarts++;
  }

  @override
  Future<void> stopDiscovery() async {
    if (failDiscoveryStop) throw StateError('scan stop failed');
    discoveryStops++;
  }

  @override
  Future<void> startAdvertising({String? name}) async {
    advertisingStarts++;
  }

  @override
  Future<void> stopAdvertising() async {
    advertisingStops++;
  }
}

void main() {
  test(
    'shared write queue keeps concurrent message frames contiguous',
    () async {
      final transport = _PresenceTransport();
      final queueA = BleMessageWriteQueue.sharedFor(transport);
      final queueB = BleMessageWriteQueue.sharedFor(transport);
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      transport.firstWriteStarted = firstStarted;
      transport.releaseFirstWrite = releaseFirst;
      addTearDown(transport.dispose);

      final first = queueA.sendFrames('peer', const [
        [1],
        [2],
        [3],
      ], role: BleSessionRole.central);
      await firstStarted.future;
      final second = queueB.sendFrames('peer', const [
        [4],
        [5],
      ], role: BleSessionRole.peripheral);
      await Future<void>.delayed(Duration.zero);
      expect(transport.sentFrames, const [
        [1],
      ]);

      releaseFirst.complete();
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(transport.sentFrames, const [
        [1],
        [2],
        [3],
        [4],
        [5],
      ]);
    },
  );

  test('discovery leases are aggregate, idempotent, and isolated', () async {
    final transport = _PresenceTransport();
    final presence = BlePresenceManager.sharedFor(transport);
    final relay = Object();
    final direct = Object();
    addTearDown(transport.dispose);

    await presence.acquireDiscovery(relay);
    await presence.acquireDiscovery(relay);
    await presence.acquireDiscovery(direct);
    expect(transport.discoveryStarts, 1);

    await presence.releaseDiscovery(direct);
    expect(transport.discoveryStops, 0);
    expect(presence.isDiscovering, isTrue);

    await presence.releaseDiscovery(relay);
    await presence.releaseDiscovery(relay);
    expect(transport.discoveryStops, 1);
    expect(presence.isDiscovering, isFalse);
  });

  test('relay and rescue advertising leases do not stop each other', () async {
    final transport = _PresenceTransport();
    final presence = BlePresenceManager.sharedFor(transport);
    final relay = Object();
    final rescue = Object();
    addTearDown(transport.dispose);

    await presence.acquireAdvertising(relay, name: 'Relay');
    await presence.acquireAdvertising(rescue, name: 'Rescue');
    expect(transport.advertisingStarts, 1);

    await presence.releaseAdvertising(relay);
    expect(transport.advertisingStops, 0);
    await presence.releaseAdvertising(rescue);
    expect(transport.advertisingStops, 1);
  });

  test(
    'start failure rolls back only the failed lease and can retry',
    () async {
      final transport = _PresenceTransport()..failDiscoveryStart = true;
      final presence = BlePresenceManager.sharedFor(transport);
      final owner = Object();
      addTearDown(transport.dispose);

      await expectLater(
        presence.acquireDiscovery(owner),
        throwsA(isA<StateError>()),
      );
      expect(presence.wantsDiscovery, isFalse);
      expect(presence.isDiscovering, isFalse);

      transport.failDiscoveryStart = false;
      await presence.acquireDiscovery(owner);
      expect(transport.discoveryStarts, 1);
    },
  );

  test(
    'stop failure remains truthful and later reconciliation recovers',
    () async {
      final transport = _PresenceTransport();
      final presence = BlePresenceManager.sharedFor(transport);
      final owner = Object();
      addTearDown(transport.dispose);

      await presence.acquireDiscovery(owner);
      transport.failDiscoveryStop = true;
      await expectLater(
        presence.releaseDiscovery(owner),
        throwsA(isA<StateError>()),
      );
      expect(presence.wantsDiscovery, isFalse);
      expect(presence.isDiscovering, isTrue);

      transport.failDiscoveryStop = false;
      await presence.retry();
      expect(presence.isDiscovering, isFalse);
      expect(transport.discoveryStops, 1);
    },
  );

  test('foreground suspension preserves leases and resumes once', () async {
    final transport = _PresenceTransport();
    final presence = BlePresenceManager.sharedFor(transport);
    final owner = Object();
    addTearDown(transport.dispose);

    await presence.acquireDiscovery(owner);
    await presence.setForeground(false);
    expect(transport.discoveryStops, 1);
    expect(presence.wantsDiscovery, isTrue);

    await presence.setForeground(true);
    expect(transport.discoveryStarts, 2);
  });

  test(
    'Bluetooth power loss retains leases and powered-on retry restores',
    () async {
      final transport = _PresenceTransport();
      final presence = BlePresenceManager.sharedFor(transport);
      final owner = Object();
      addTearDown(transport.dispose);

      await presence.acquireDiscovery(owner);
      await presence.acquireAdvertising(owner, name: 'Relay');
      await presence.notifyNativePresenceLost();
      expect(presence.wantsDiscovery, isTrue);
      expect(presence.wantsAdvertising, isTrue);
      expect(presence.isDiscovering, isFalse);
      expect(presence.isAdvertising, isFalse);

      await presence.retry();
      expect(transport.discoveryStarts, 2);
      expect(transport.advertisingStarts, 2);
      expect(presence.isDiscovering, isTrue);
      expect(presence.isAdvertising, isTrue);
    },
  );
}
