# Architecture Overview

## Runtime layers

- Flutter presentation: authentication, SOS, Chat, Location, maps, settings.
- Domain/data services: AuthService, SOS repositories, BLE coordinators,
  location sharing and OfflineMapRepository.
- Local persistence: Drift database with owner-scoped records and guest-local
  isolation.
- Cloud: Firebase Auth and Firestore for authenticated synchronization.
- Transport: direct BLE v1 and signed, hop-only Relay v2.

## Security boundaries

- Firebase UID/owner checks constrain authenticated data.
- Guest records never enter cloud sync.
- BLE messages require logical sender/recipient and native peer binding.
- Relay keys remain platform-secure; relay receipts are not responder receipts.
- Map configuration fails closed in Release and never falls back to public OSM.
- Password recovery rejects email-only reset and requires a future trusted
  backend to issue independently verified factor proofs.

## Data-flow rule

Persist SOS before optional GPS completion. Location, Chat, BLE delivery and
relay evidence are separate states. UI wording must reflect the strongest
evidence actually available and must not claim human assistance.
## Q-708A — Proposed multi-hop Rescue final reception (design only)

### Current trust boundary

Relay v2 currently carries an origin-signed, immutable public-emergency body
with per-hop attestations, expiry, hop limits and deduplication. A relay
installation may durably store and forward that envelope, but relay persistence
is deliberately not an SOS History record and does not authorize human help.
Rescue Mode currently displays only inbound Direct SOS v1 rows. Q-707D proved
A→B→C relay persistence, not final-recipient reception.

### Required additive extension

Making C an actionable endpoint requires a new, explicitly versioned final-
reception protocol (for example a signed `sos.rescue.offer.v1` transition)
and a dedicated local Rescue Inbox. The existing Relay v2 offer must remain
hop-only and must not be reinterpreted in place.

The proposed transition would carry an origin-signed immutable intent with:

- voluntary-rescue audience/consent (separate from relay consent);
- immutable relay digest, origin incident/message ID and origin public key;
- `includeLocation` and expiry/TTL already authorized by the origin;
- the existing hop count/path attestations;
- a new final-reception protocol version and recipient/session binding.

C would promote only after local Rescue Mode opt-in, successful origin and hop
signature verification, expiry/TTL/replay checks, digest matching, and an
idempotent insert into the dedicated inbox. B would continue storing only the
relay row unless B itself is explicitly in Rescue Mode and accepts locally.

The inbox must be owner-scoped, restart-safe and separate from relay storage
and normal SOS History until the receiver explicitly accepts the incident.
Any future Help action must be explicit and must not claim responder dispatch.

### Gate

This design requires a wire-protocol version, recipient/consent semantics and
likely a dedicated persistence table. Per Q-708A instructions, implementation
is **STOPPED pending owner approval**. No production source, schema, BLE UUID,
or trust behavior was changed.

### Q-708A implementation update — 3 November 2026

Owner approval was received. The first vertical slice now adds an explicit
`voluntaryRescue` scope, separate `allowVoluntaryRescue` consent (default off),
schema 7 owner-scoped Rescue Inbox storage, Rescue Mode candidate persistence,
and local-only Offer Help. Relay-only rows remain outside SOS History.
