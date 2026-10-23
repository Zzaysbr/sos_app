# Phase B — Architecture Roadmap

Phase B is design-only in this task. No offline-map, relay or LoRa code,
dependency, protocol kind, UUID or schema was introduced.

## B1 — Offline map tiles

### Decision gate

Select a provider and license that explicitly permits packaged/downloaded
offline regions for the intended usage. A normal online raster cache and the
public OSM tile service are not an offline-map license or reliable release
backend. Record attribution, redistribution, retention, maximum zoom, request
rate and privacy requirements before choosing a Flutter/native implementation.

### Proposed design

- Introduce an explicit `OfflineMapRegion` manifest containing provider/style
  version, bounded geometry, min/max zoom, tile count/bytes estimate, download
  state, timestamps and integrity/version metadata.
- Use a dedicated tile store under the app's managed storage. Keep map tiles
  separate from SOS/Chat databases so eviction cannot delete incident records.
- Require the user to select a bounded region and show the estimated download
  size before starting. Enforce provider limits, a device-wide storage quota,
  per-region limits and minimum free-space headroom.
- Download with bounded concurrency, resumable checkpoints and atomic temporary
  files. Validate response type/size and a manifest hash or per-tile integrity
  metadata before making a region available.
- Apply deterministic LRU/expiry eviction only to tiles that are not pinned or
  active. Provide explicit delete controls and report reclaimed space.
- Resolve tiles offline-first from the verified local store, then use the
  approved online provider only when network/configuration permits. Missing or
  corrupt tiles render a neutral empty tile while incident/shared/current
  markers and textual coordinates remain available.
- Keep attribution visible offline and store the attribution/version with each
  region so provider changes do not erase legal notices.
- Encrypting tiles is optional and does not replace provider licensing. Avoid
  storing search history or precise download-region telemetry unless required.

### Validation

Test interrupted/resumed download, quota/full disk, corrupt/truncated tile,
provider-style version change, partial region, eviction, app restart, network
loss and marker persistence. Run physical airplane-mode map tests at region
edges and multiple zoom levels. Do not call B1 complete until licensing and
device-storage evidence exist.

## B2 — BLE relay/store-and-forward

### Initial scope

Start with a controlled single-relay path rather than general mesh routing. Keep
SOS/Chat domain IDs stable and let a transport layer carry a versioned relay
envelope. Preserve direct BLE behavior for peers that do not advertise relay
support.

### Proposed envelope and queue

- Immutable message ID and content digest; original sender installation ID;
  final destination; created/expiry timestamps; protocol version; hop limit;
  traversed-relay identifiers or compact loop-prevention data; payload kind and
  encrypted/authenticated payload.
- Separate custody receipt from final application delivery receipt. A relay's
  native write or local persistence must never mark the origin message
  Delivered. Only an authenticated receipt tied to the final destination and
  original message ID may do that.
- Durable bounded relay queue with byte/count caps, per-origin fairness,
  priority for SOS over Chat/location, expiry, atomic claims and crash recovery.
  Reject expired, over-hop, malformed, unsupported or duplicate content before
  forwarding.
- Exponential bounded retry/backoff with jitter and battery-aware scan/advertise
  windows. Avoid continuous background promises that iOS/Android cannot meet.
- Deduplicate across restarts using message ID plus digest; reject same-ID
  conflicting payloads. Prevent loops through hop decrement and seen-message
  state retained for at least the maximum TTL.

### Security and compatibility

Define threat cases before implementation: forged relay receipts, replay,
tracking, queue flooding, malicious payload conflict and unauthorized metadata
inspection. Device binding currently used for routing is not cryptographic
authentication. Select an end-to-end authentication/encryption scheme and key
distribution model before relaying sensitive payloads.

Add capability negotiation as an additive, versioned feature. Old peers must
continue direct delivery and ignore unsupported relay messages safely. Do not
reuse existing production message kinds with changed semantics.

### Validation

Build deterministic three-node simulations, then physical origin→relay→target
tests for expiry, hop exhaustion, duplicate paths, restart at each node, queue
pressure, wrong receipt, target ACK loss and mixed old/new versions. Measure
battery and latency; document OS background limits.

## B3 — LoRa transport

### Hardware and regulatory gate

Ordinary phones cannot transmit LoRa without external hardware. Select a
documented module/device with an authenticated USB, BLE or accessory link and a
maintained native SDK/protocol. Confirm permitted regional frequency plan,
power, channel, airtime/duty-cycle and certification requirements with the
owner's deployment jurisdiction and current regulator guidance before radio
tests. No frequency or range promise should be inferred from another region.

### Integration boundary

- Implement a Flutter-facing `LoRaTransport` behind a narrow native/platform
  adapter for discovery, connection, radio configuration, send/receive and
  hardware status. Keep SOS/Chat persistence and domain identity above the
  adapter.
- Expose hardware model/firmware, supported payload size, region configuration,
  signal metrics and actionable errors without logging message contents or
  coordinates.
- Use a versioned transport envelope with stable domain message ID, fragment
  index/count, content digest, TTL, sender/destination identity and authenticated
  metadata. Reassemble with strict byte/fragment/time bounds and reject
  conflicting or replayed fragments.
- Design for small payloads: compact encoding, explicit maximum message size,
  no map tiles/images and limited location precision only when product/privacy
  requirements allow it.
- Schedule airtime conservatively with bounded retries/backoff. Application ACK
  remains distinct from module acceptance. Record custody/final delivery states
  separately when BLE relay and LoRa coexist.

### Security and interoperability

Choose encryption/authentication and key provisioning before field use; radio
link-layer features alone are not a complete end-to-end design. Define device
replacement, revoked keys, replay windows and firmware trust/update policy.
Use a transport-independent domain delivery state with transport-specific
attempt records so BLE and LoRa cannot acknowledge each other's message without
matching domain ID, destination and authenticated receipt.

### Validation

Begin with native adapter unit/loopback tests, malformed/fragmented payloads and
hardware-disconnect recovery. Continue with bench tests for airtime, queueing,
power loss and firmware versions, followed by legally compliant outdoor trials.
Report measured conditions and never convert RSSI into a distance guarantee.

## Recommended sequencing

Finish Phase A gates first. Then run B1 as a provider/licensing and storage
spike with no BLE changes. Start B2 only after a three-node threat model and
receipt semantics are approved. Start B3 only after hardware and regional radio
requirements are selected. Each phase needs its own compatibility plan,
feature flag, migration review and rollback path before production integration.
