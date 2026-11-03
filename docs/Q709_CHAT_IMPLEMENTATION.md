# Q-709 Chat Relay Implementation

Implemented code-level transport foundation:

- `chat.relay.v1` is an immutable, signed envelope bound to incident, sender
  key, recipient key and expiry.
- `chat.relay.transfer.v1` uses the existing BLE framing and authenticated
  session proof. Relays persist the envelope before forwarding.
- Chat relay outbox/inbox tables are owner-scoped and migrated at schema v9.
- Duplicate incoming messages are idempotent. Expiry, signature, recipient-key
  and hop-limit checks fail closed.
- A message is not marked final Delivered by native write or hop forwarding.

The Incident Chat send callback now resolves a previously verified participant
binding and calls `SosBleCoordinator.enqueueChatThroughRelay` automatically.
For a victim this is the verified responder key from `rescue_response_inbox`;
for a rescuer it is the origin key from the verified Relay v2 envelope. BLE
addresses and display names are never used as identity. If no binding exists,
the existing direct Chat compatibility path remains available and no unknown
multi-hop recipient is invented.

Automated verification: 465 Flutter tests pass, including the deterministic
three-node signed Chat persistence test, focused Chat repository and envelope
tests, `flutter analyze lib test`, and `git diff --check`.

Physical A→B→C and C→B→A Chat delivery is not verified in this task. A victim
cannot initiate multi-hop Chat before a verified responder binding exists; the
rescuer can reply once the origin envelope has been verified locally.
