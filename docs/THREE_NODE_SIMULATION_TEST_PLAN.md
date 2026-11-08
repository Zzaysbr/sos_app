# Three-node simulation test plan

## Boundary and topology

`test/support/three_node_ble_simulation.dart` instantiates three real
`SosBleCoordinator` instances, each owning a real `HopRelayCoordinator`, a separate
Drift executor/database, installation key seed, inbox/outbox and Chat repository.
A is the victim, B an opted-in relay, C a rescuer. Only A-B and B-C links are
permitted; attempting to connect A-C throws. A separate direct compatibility test
explicitly replaces that topology with A-C.

The normal transport passes unmodified production `BleMessageCodec` frames at its
20-byte safe size through stream events into the production assembly, Session
Proof, Chat receive/forward, authorization and persistence handlers. Signatures
use real Ed25519 and hashes. No `authenticated=true` assignment, substituted
handler or mocked database query result establishes trust. Test-only fixed key
seeds and deterministic unique nonces must never be used in production; production
constructor defaults still use secure randomness and platform key storage.

SOS and explicit Help Offer are pre-provisioned at the verified-repository boundary
using real signatures and repository validation. Their *radio delivery* is not
covered by these Chat tests. GPS is fixture data, not an authentic GPS reading.
This boundary isolates Stage 2 from the existing SOS/Help Offer suites.

## Deterministic controls

- `SimulationClock.advance` controls UTC time and one-shot/periodic timers; it
  fires due timers chronologically. Negative time and zero periodic intervals
  are rejected. Chat UI timestamps use the same injected clock.
- No real sleeps. `deliver`, `pump`, and `until` use event-loop barriers to allow
  real asynchronous SQL/crypto completion. `until` has a finite step budget and
  fails if the expected durable condition never appears. These are controlled
  asynchronous simulations, not an emulator for OS/radio scheduling.
- `SimBleTransport.discover` emits virtual discovery; `connect`/`disconnect`
  model central/peripheral roles. Generations discard retired-link data.
- `latency`, `dropTypes`, `dropNextFrame`, `dropLastFrameTypeOnce`,
  `duplicatePackets`, `reversePackets`, `holdPackets`/`releaseHeld`,
  `failMessageTypeOnce`, and `afterFrameWrite` inject faults.
- `frameWrites`, `deliveredFrames`, `staleFramesDropped`, transport discovery/
  connection counters and `SimulationSqlCounters` observe real work. SQL counters
  count select/insert/update/delete executor calls, not disk I/O or transaction
  overhead. No content/key logging is added by these counters.
- Tests advance time and call `processDue` explicitly for retries; polling uses
  an injected virtual timer with a one-day interval so it cannot rescue missing
  event-driven forwarding. The overlap regression deliberately never calls
  scheduler polling between its twenty messages.
- B can use an isolated temporary SQLite file. The restart test closes its old
  coordinator/database, creates a fresh node with the same installation seed,
  reopens the file and requires fresh Session Proof before delivery resumes.

## Executable coverage

| Requirement/fault | Executable coverage | Status |
|---|---|---|
| A-B-C and C-B-A | Runtime forward/reverse test; original sender, final hop, no A-C link | PASS |
| Twenty alternating messages | Original 40-transfer conversation, exact content/identity, wire timestamps, unique bubbles | PASS |
| Arrival while retry drain is active | Separate twenty-message conversation crosses retry deadlines without poll rescue | PASS |
| Direct behavior | Authenticated A-C and C-A with the same handlers | PASS |
| B-C unavailable before forward | Pending B outbox then reconnect with real proof | PASS |
| Disconnect during transfer | Interrupt B-C on a frame write; retain and retry after proof | PASS |
| Proof expires / unauthenticated / proves again | Drop real proof responses, fire virtual proof timeout, recover through signed proof | PASS |
| Peer ineligible / eligible | B participation opt-out/opt-in re-proves sessions; pending text resumes | PASS |
| Endpoint participation independent | A/C need not opt into relaying other people's traffic | PASS |
| Lost packet / lost frame | Whole Chat loss and single final raw-frame loss | PASS |
| Duplicates / out-of-order | Raw-frame duplication/reversal; persistent inbox and one visible bubble | PASS |
| Latency | Virtual delay prevents early receipt and then allows durable reception | PASS |
| Missing hop receipt | Dropped SOS receipt kinds do not finalize Chat; Chat currently emits no receipt | PASS for conservative state; protocol absent |
| Delayed receipt | No Chat receipt wire contract exists; delayed duplicate text is idempotent | NOT TESTED as a Chat receipt |
| Receiver persists before sender knows | Destination persists while source stays forwarded/sent | PASS |
| Coordinator restart / database reopen | B file-backed restart retains signed hop chain and pending job | PASS |
| Retired-link data callback | Simulator generation filter and old Session Binding replay rejection | PASS |
| Stale native disconnect callback | Explicit deferred contract bypassing simulator generation filter | FAIL (separate regression) |
| Expiry / retry bounds | Expiry excludes due jobs; exactly eight lost-message attempts before exclusion | PASS |
| Invalid signature / wrong incident / wrong digest | Production receive rejects and persists nothing | PASS |
| Arbitrary valid signer / wrong recipient | Verified participant authorization rejects | PASS |
| Hop signature / chain truncation / loop / max hop tamper | Security receive/path tests reject | PASS |
| ID collision / replay | Same ID with altered signed content rejected; identical replay idempotent | PASS |
| Account scope | Other owner's outbox/offer lookup cannot authorize | PASS |
| Stage 1 Cancel/Resolve authorization | Existing lifecycle authorization/envelope suites | PASS |

PASS entries refer to the final automated run recorded in
`STAGE_2_CHAT_RELAY_RECOVERY.md`; none refer to physical verification.

## Running

```sh
flutter test test/stage2_chat_runtime_test.dart test/stage2_chat_security_test.dart test/stage2_simulation_metrics_test.dart --reporter compact
flutter test test/incident_lifecycle_authorization_test.dart test/incident_lifecycle_envelope_test.dart --reporter compact
flutter test --reporter compact
flutter analyze lib test
flutter analyze regression
```

Explicitly run the unfinished contracts (they fail, are not skipped):

```sh
flutter test regression/stage2_remaining_contract_test.dart --reporter compact
```

That directory is outside Flutter's default `test/` discovery so the deferred
contracts and the eight established baseline failures have separate reports.
It is not part of the passing focused Stage 2 claim. See the recovery report for
both failure rationales and remaining work.

## Interpretation limits

Drift v9 stores display timestamps at second resolution. Signed wire creation
metadata retains milliseconds. Tests compare UTC instants, identify messages by
ID, and make no general guarantee of network arrival order or total ordering for
equal timestamps. Schema v9 is unchanged.

A proof response timeout is simulated; there is no claim that an established
Session Proof has a time-based lease. Session invalidation on disconnect,
participation changes and stale binding rejection are tested separately.

Native BLE/GATT implementation, permissions, background suspension, actual GPS,
radio loss characteristics, throughput, battery and frame rendering require
physical-device verification. No deployment is performed here.
