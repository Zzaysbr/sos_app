import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_transport.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/sos/presentation/emergency_chat_page.dart';

class IncomingHistory extends MockEmergencyChatRepository {
  final incoming = EmergencyChatMessage(
    id: 'incoming',
    sosId: 'incident',
    senderId: 'other-installation',
    // PersistentChatRepository stores the local owner here for incoming rows.
    recipientId: 'local-owner',
    text: 'received',
    createdAt: DateTime.utc(2026),
    status: ChatDeliveryStatus.delivered,
    isMine: false,
  );
  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async => [
    incoming,
    ...messagesFor(sosId),
  ];
  @override
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) async* {
    yield await loadMessages(sosId);
  }
}

class LegacyUnroutedHistory extends MockEmergencyChatRepository {
  EmergencyChatMessage message = EmergencyChatMessage(
    id: 'legacy-chat',
    sosId: 'incident',
    senderId: 'local-installation',
    text: 'queued before route binding',
    createdAt: DateTime.utc(2026),
    status: ChatDeliveryStatus.failed,
    isMine: true,
  );

  void assign(String destinationId) {
    message = EmergencyChatMessage(
      id: message.id,
      sosId: message.sosId,
      senderId: message.senderId,
      recipientId: destinationId,
      text: message.text,
      createdAt: message.createdAt,
      status: ChatDeliveryStatus.pending,
      isMine: true,
    );
  }

  @override
  Future<List<EmergencyChatMessage>> loadMessages(String sosId) async => [
    message,
  ];

  @override
  Stream<List<EmergencyChatMessage>> watchMessages(String sosId) async* {
    yield await loadMessages(sosId);
  }
}

class PickerTransport implements BleTransportClient {
  final eventsController = StreamController<BleEvent>.broadcast();
  final connected = <String>[];

  @override
  Stream<BleEvent> get events => eventsController.stream;
  @override
  Future<void> requestPermissions() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> startAdvertising({String? name}) async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> connect(String deviceId) async => connected.add(deviceId);
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<void> send(
    String deviceId,
    List<int> frame, {
    BleSessionRole? role,
  }) async {}
  @override
  Future<void> dispose() async => eventsController.close();
}

void main() {
  testWidgets(
    'incoming local owner is never reused as a BLE reply destination',
    (tester) async {
      final repository = IncomingHistory();
      String? selected = 'callback-not-called';
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyChatPage(
            sosId: 'incident',
            repository: repository,
            onMessageCreatedWithDestination: (message, {destinationId}) async {
              selected = destinationId;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'reply');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(
        selected,
        isNull,
        reason: 'Use the established incident route; incoming recipient is an owner scope.',
      );
      expect(repository.messagesFor('incident').single.recipientId, isNull);
    },
  );

  testWidgets(
    'legacy unrouted Chat requires explicit peer selection before retry',
    (tester) async {
      final repository = LegacyUnroutedHistory();
      final transport = PickerTransport();
      addTearDown(transport.eventsController.close);
      String? assignedSos;
      String? assignedPeer;
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyChatPage(
            sosId: 'incident',
            repository: repository,
            bleTransport: transport,
            onAssignPendingDestination: (sosId, destinationId) async {
              assignedSos = sosId;
              assignedPeer = destinationId;
              repository.assign(destinationId);
              return 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Queued messages need a BLE recipient'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose recipient'));
      await tester.pumpAndSettle();
      expect(find.text('Choose BLE recipient'), findsOneWidget);

      transport.eventsController.add(
        const BleEvent(
          type: 'deviceFound',
          device: BleDevice(id: 'peer-1', name: 'Responder phone'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(transport.connected, ['peer-1']);
      transport.eventsController.add(
        const BleEvent(
          type: 'connected',
          device: BleDevice(id: 'peer-1', name: 'Responder phone'),
        ),
      );
      await tester.pumpAndSettle();

      expect(assignedSos, 'incident');
      expect(assignedPeer, 'peer-1');
      expect(repository.message.id, 'legacy-chat');
      expect(repository.message.recipientId, 'peer-1');
      expect(
        find.textContaining('Queued messages need a BLE recipient'),
        findsNothing,
      );
      expect(
        find.text('Recipient assigned to 1 queued message.'),
        findsOneWidget,
      );
    },
  );
}
