# Q-708B / Q-709 / SOS Lifecycle Protocol Contract

This contract is additive to Relay v2. Relay v2 continues to transport the
origin-signed SOS and hop receipts; a hop receipt is never a final-recipient
acknowledgement.

## Common envelope

Every response or conversation message uses canonical JSON (sorted keys,
without insignificant whitespace) and contains a versioned body with:

- `messageId` and `incidentId`.
- The origin message/key binding (`originMessageId`, `originKeyId`, and the
  immutable origin digest where applicable).
- Sender and recipient key identities, public keys, and a session binding.
- UTC `createdAt`/`expiresAt`, `hopCount`, and `maxHops`.
- A sender signature over the canonical body.

Key IDs are hashes of the supplied Ed25519 public keys. BLE addresses and
display names are transport hints only and are not trusted identities.

## Message kinds

| Kind | Purpose | Status |
| --- | --- | --- |
| `rescue.offer` | Rescuer's authenticated Offer Help, bound to one origin SOS. | Schema and signature/binding validator implemented in `rescue_response_envelope.dart`. |
| `rescue.offer_ack` | Final-recipient acknowledgement for a rescue offer. | Schema, signature, exact-response binding, and durable delivery-state application implemented; BLE routing remains pending. |
| `chat.message` | Authenticated incident conversation message. | Existing direct Chat remains unchanged; multi-hop extension pending. |
| `chat.ack` | Transport/durable-receipt acknowledgement for `chat.message`. | Contract reserved; final-recipient semantics pending. |
| `sos.cancelled` | Origin-signed monotonic lifecycle update. | Contract reserved; propagation pending. |
| `sos.resolved` | Origin-signed monotonic lifecycle update. | Contract reserved; propagation pending. |

## Validation rules

- Reject malformed or unknown fields, invalid signatures, wrong key IDs,
  expired messages, future timestamps outside the existing clock-skew policy,
  invalid hop counts, and TTLs beyond the protocol limit.
- Bind a response to the exact incident, origin message, origin key, and
  immutable digest. A relay cannot alter the signed body or rebind it.
- Deduplicate by `(kind, messageId, incidentId)` in durable storage. Replays
  must be idempotent and must not create duplicate incidents or assistance
  records.
- A hop receipt only proves durable acceptance by the next relay. Final
  responder persistence requires a distinct, authenticated final-recipient
  acknowledgement.
- Consent and owner-scoped persistence remain enforced by the existing
  application layers. No message kind silently grants relay, rescue, or
  location consent.

The remaining message kinds will reuse this contract and existing Relay v2
transport once their durable repositories and coordinator paths are added.
