# SOS Lifecycle Audit

## Scope

Code-level audit only. No physical-device testing was performed in this task.

## Lifecycle gap matrix

| Stage | Entry point | Current implementation | Gap / action |
|---|---|---|---|
| SOS creation | `SosRepository.create`, `SosBleCoordinator.enqueueSos` | Local Drift persistence precedes asynchronous BLE/GPS work; Chat navigation is immediate. | Implemented and covered by existing SOS/navigation tests. |
| GPS attachment | SOS page location acquisition and repository update | Missing/late GPS does not block local SOS; valid later coordinates update the incident. | Implemented; physical GPS remains unverified here. |
| A → B relay | `HopRelayCoordinator.queuePublicEmergency`, `_handleIncomingOffer` | Signed Relay v2 envelope is persisted as relay-only data and hop receipt is emitted. | Existing deterministic coverage; scheduler now starts after durable persistence before receipt write completes. |
| B → C relay | `HopRelayCoordinator._processDue`, `_provenPeers`, `_sendOfferToPeer` | Requires an authenticated, participating peer and foreground coordinator. | Deterministic A→B→C coverage exists; physical B→C remains unverified. |
| Rescue Inbox | `_handleIncomingOffer`, `RescueInboxRepository.insertCandidate` | Voluntary-rescue candidates are owner-scoped and reactive. | Existing implementation; no relay-only SOS History promotion. |
| Victim location | `IncidentMapPage` and candidate map action | Candidate coordinates are copied from the signed origin envelope. | Existing implementation; physical verification remains unverified. |
| A ↔ C Chat | `SosBleCoordinator.enqueueChat`, `_handleChatDelivery`, `ChatRelayEnvelope` | Direct Chat remains unchanged; a signed additive Q-709 envelope contract is now available and independently verified. | **Not complete:** runtime durable relay jobs and final ACK wiring are still required before enabling multi-hop Chat. |
| Cancel/Resolve | Local SOS repository/UI transitions | Local transitions exist. | Signed multi-hop lifecycle synchronization is not complete and is deferred behind P0 Chat design. |

## Confirmed implementation change

When a relay node persists an incoming offer, it now marks pending work and schedules
`processDue()` before writing the previous-hop receipt. This prevents a slow multi-frame
receipt write from serializing the next-hop forwarding path.

## Security boundaries preserved

- Relay v2 signatures, session proof, TTL, hop limits, path-loop checks and deduplication remain enforced.
- Relay-only records do not become SOS History incidents.
- Consent and Guest/Auth owner isolation were not weakened.
- No database migration, signing change, or physical-device action was performed.
