import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sos_app/features/nearby_ble/data/relay_repository.dart';
import 'package:sos_app/features/nearby_ble/data/rescue_response_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/rescue_response_envelope.dart';
import 'package:sos_app/core/database/app_database.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scenario in [(false, false), (true, false), (false, true)]) {
    final (loseAck, resumeReceiver) = scenario;
    test(
      'cold proof, SOS, Help Offer and bidirectional Chat; ACK loss=$loseAck resume=$resumeReceiver',
      () async {
        final clock = SimulationClock();
        final radio = SimBleNetwork(clock)..allow('A', 'C');
        final a = SimNode('A', 1, radio);
        final c = SimNode('C', 3, radio);
        addTearDown(a.close);
        addTearDown(c.close);
        await a.start();
        await a.coordinator.setRelayParticipationEnabled(false);
        await c.start();
        await a.materialize('incident-1');
        radio.connect('A', 'C');
        // Queue before either local proof exchange has completed. No signed
        // origin/participant state is provisioned directly into the receiver.
        await a.coordinator.enqueuePublicRelay(
          SosMessage(
            id: 'incident-1',
            ownerId: 'A',
            type: 'emergency',
            message: 'test SOS',
            latitude: null,
            longitude: null,
            status: 'active',
            createdAt: clock.now,
            updatedAt: clock.now,
            syncState: 'deviceOnly',
          ),
          includeLocation: false,
          scope: RelayAuthorizationScope.voluntaryRescue,
        );
        await radio.until(
          () async => (await c.db.select(c.db.rescueInbox).get()).length == 1,
        );
        final runtime = await a.coordinator.relayRuntimeDiagnosticsDataSource
            .watchRuntimeDiagnostics()
            .first;
        expect(
          runtime.lastForwardAttempt,
          contains('timing=forwarding_started'),
        );
        if (resumeReceiver) {
          await radio.pump();
          final oldCapability = radio.captures
              .lastWhere(
                (p) =>
                    p.$1 == 'C' &&
                    p.$3.type == RelayCapabilityAdvertisement.wireKind,
              )
              .$3;
          final oldChallenge = radio.captures
              .lastWhere(
                (p) =>
                    p.$1 == 'C' && p.$3.type == RelaySessionChallenge.wireKind,
              )
              .$3;
          // OS permission sheets/settings can briefly background only one peer,
          // leaving native GATT connected while both bindings must be re-proven.
          c.coordinator.didChangeAppLifecycleState(AppLifecycleState.inactive);
          await radio.pump();
          c.coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
          await radio.until(
            () async => await a.authenticated() && await c.authenticated(),
          );
          await radio.pump();
          final before = radio.captures
              .where(
                (p) =>
                    p.$1 == 'A' &&
                    (p.$3.type == RelaySessionChallenge.wireKind ||
                        p.$3.type == RelaySessionResponse.wireKind),
              )
              .length;
          radio.inject('C', 'A', oldCapability);
          radio.inject('C', 'A', oldChallenge);
          await radio.pump();
          expect(await a.authenticated(), isTrue);
          expect(
            radio.captures
                .where(
                  (p) =>
                      p.$1 == 'A' &&
                      (p.$3.type == RelaySessionChallenge.wireKind ||
                          p.$3.type == RelaySessionResponse.wireKind),
                )
                .length,
            before,
          );
        }
        final stored = await c.db.select(c.db.bleRelayMessages).getSingle();
        final offer = await RelayRepository(database: c.db)
            .loadVerifiedOffer(stored.originMessageId, now: clock.now);
        var dropAck = loseAck;
        radio.dropMessage = (_, _, message) =>
            message.type == RescueResponseTransfer.wireKind &&
            RescueResponseTransfer.fromJson(message.payload).isAck &&
            dropAck;
        final responses = RescueResponseRepository(c.db, ownerId: 'C');
        final response = await responses.signAndEnqueueOffer(
          origin: offer.body,
          responder: await c.identity(),
          sessionBinding: 'test-incident-authorization',
          now: clock.now,
        );
        await c.coordinator.processDue();
        await radio.until(
          () async =>
              (await a.db.select(a.db.rescueResponseInbox).get()).length == 1,
        );
        if (!loseAck) {
          await radio.until(
            () async =>
                (await responses.findOutbox(response.messageId))?.state ==
                'delivered',
          );
        } else {
          await radio.pump();
          final before = radio.captures
              .where((p) => p.$3.type == RescueResponseTransfer.wireKind)
              .length;
          for (var i = 0; i < 5; i++) {
            await a.coordinator.processDue();
            await c.coordinator.processDue();
            await radio.pump(rounds: 20);
          }
          expect(
            radio.captures
                .where((p) => p.$3.type == RescueResponseTransfer.wireKind)
                .length,
            before,
          );
        }
        await c.materialize('incident-1');
        await a.send('forward-text', 'A to C', c);
        await radio.until(
          () async =>
              (await c.chat.loadMessages('incident-1'))
                  .any((m) => m.id == 'forward-text'),
        );
        await c.send('reverse-text', 'C to A', a);
        await radio.until(
          () async =>
              (await a.chat.loadMessages('incident-1'))
                  .any((m) => m.id == 'reverse-text'),
        );
        if (loseAck) {
          dropAck = false;
          clock.advance(const Duration(seconds: 30));
          await c.coordinator.processDue();
          await radio.until(
            () async =>
                (await responses.findOutbox(response.messageId))?.state ==
                'delivered',
          );
        }
        await radio.pump();
        expect(
          (await responses.findOutbox(response.messageId))!.state,
          'delivered',
        );
        expect(await a.db.select(a.db.rescueResponseInbox).get(), hasLength(1));
        expect(
          (await c.chat.loadMessages('incident-1'))
              .where((m) => m.id == 'forward-text'),
          hasLength(1),
        );
        expect(
          (await a.chat.loadMessages('incident-1'))
              .where((m) => m.id == 'reverse-text'),
          hasLength(1),
        );
        expect(
          [...a.logs, ...c.logs].where(
            (l) =>
                l.contains('session binding is invalid') ||
                l.contains('binding is invalid'),
          ),
          isEmpty,
        );
      },
    );
  }
}
