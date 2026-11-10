import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/chat_relay_envelope.dart';
import '../domain/relay_envelope.dart';
import '../domain/rescue_response_envelope.dart';

/// Trust comes from the signed SOS plus an explicit signed voluntary help
/// offer, never from a device name or a sender's self-declared incident ID.
class ChatRelayAuthorization {
  ChatRelayAuthorization(this.database, {required this.ownerId});
  final AppDatabase database;
  final String ownerId;

  Future<RelayOriginBody> origin(String incidentId) async {
    final row =
        await (database.select(database.bleRelayMessages)
              ..where((r) => r.originMessageId.equals('relay:$incidentId')))
            .getSingleOrNull();
    if (row == null) {
      throw const FormatException('Verified SOS origin unavailable.');
    }
    final envelope = RelayOfferEnvelope.fromCanonicalWire(row.wireEnvelope);
    final crypto = RelayCryptography();
    if (!await crypto.verifyOffer(envelope, allowExpired: true) ||
        envelope.body.incidentId != incidentId ||
        envelope.body.originKeyId != row.originKeyId ||
        await crypto.immutableDigest(envelope.body) != row.immutableDigest ||
        envelope.body.scope != RelayAuthorizationScope.voluntaryRescue) {
      throw const FormatException('Chat SOS origin binding invalid.');
    }
    return envelope.responseOrigin;
  }

  Future<String> authorize(
    ChatRelayEnvelope envelope, {
    String? suppliedOffer,
  }) async {
    final body = await origin(envelope.body.incidentId);
    final digest = await RelayCryptography().immutableDigest(body);
    final binding = envelope.body.originIncidentBinding;
    // Legacy signed text envelopes used the incident ID. They still require
    // the same verified origin and signed offer proof; no arbitrary key trust.
    final emergencyBinding = 'emergency-text:${body.originMessageId}:$digest';
    if (binding != body.incidentId &&
        binding != emergencyBinding &&
        binding != 'incident-binding:${body.originMessageId}:$digest') {
      throw const FormatException('Chat incident digest binding invalid.');
    }
    // The SOS author can supply urgent text before a helper volunteers.
    // This permission is one-way and text-only; replies and media still
    // require the existing signed help offer. The coordinator verifies the
    // Chat signature and session/path before calling this authorization.
    if (binding == emergencyBinding) {
      if (envelope.body.senderKeyId != body.originKeyId ||
          envelope.body.senderPublicKey != body.originPublicKey ||
          envelope.body.recipientKeyId == body.originKeyId ||
          envelope.body.media != null ||
          envelope.body.createdAt.isBefore(body.createdAt) ||
          !await RelayCryptography().verifyChatRelay(envelope)) {
        throw const FormatException('Emergency text authorization invalid.');
      }
      return emergencyBinding;
    }
    final offers = <String>[];
    if (suppliedOffer != null) {
      offers.add(suppliedOffer);
    } else {
      final incoming =
          await (database.select(database.rescueResponseInbox)..where(
                (r) =>
                    r.ownerId.equals(ownerId) &
                    r.incidentId.equals(body.incidentId) &
                    r.state.equals('verified'),
              ))
              .get();
      final outgoing =
          await (database.select(database.rescueResponseOutbox)..where(
                (r) =>
                    r.ownerId.equals(ownerId) &
                    r.incidentId.equals(body.incidentId),
              ))
              .get();
      offers.addAll(incoming.map((r) => r.payload));
      offers.addAll(outgoing.map((r) => r.payload));
    }
    for (final wire in offers) {
      try {
        final offer = RescueResponseEnvelope.fromCanonicalWire(wire);
        final responder = offer.body.responderKeyId;
        if (!((envelope.body.senderKeyId == body.originKeyId &&
                envelope.body.recipientKeyId == responder) ||
            (envelope.body.senderKeyId == responder &&
                envelope.body.recipientKeyId == body.originKeyId))) {
          continue;
        }
        if (envelope.body.createdAt.isBefore(body.createdAt) ||
            envelope.body.createdAt.isBefore(offer.body.createdAt)) {
          continue;
        }
        // Expiry of offer transport is not revocation of an established Chat
        // participant. Recheck its signature/binding at its signed creation.
        if (await RelayCryptography().verifyRescueResponseForOrigin(
          offer,
          body,
          now: offer.body.createdAt,
        )) {
          return wire;
        }
      } on Object {
        /* Other response records (including ACKs) are not offers. */
      }
    }
    throw const FormatException('Verified Chat participant offer unavailable.');
  }
}
