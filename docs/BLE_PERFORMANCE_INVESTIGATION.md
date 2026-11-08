# BLE performance investigation — Stage 2

## Result and measurement boundary

The code has measurable repeated idle work and substantial framing/cryptographic
work, but polling is **not a confirmed cause** of the reported UI lag or BLE
instability. This is a read-only investigation of scheduler/native/UI behavior.
No broad scheduling, scanning or BLE rewrite was performed. The small Chat drain
fix addresses a reproduced lost-arrival condition, not a claimed FPS improvement.

Reproduce counters with:

```sh
flutter test test/stage2_simulation_metrics_test.dart --reporter expanded
flutter test test/stage2_chat_runtime_test.dart --plain-name '20 alternating messages' --reporter expanded
```

A device-free run of 12 explicit coordinator ticks over 60 virtual seconds,
without incidents, connections or jobs, measured **per node**:

| Counter | Observed |
|---|---:|
| Hop scheduler executions | 24 |
| SQL SELECT calls | 168 |
| SQL UPDATE calls | 60 |
| SQL INSERT / DELETE calls | 0 / 0 |
| Connect calls | 0 |
| Native boundary discovery start / stop calls | 0 / 0 |

These are executor calls, including updates that match zero rows, not physical
writes. Startup was excluded by resetting counters after `start`. No query result
was mocked. There were no attached database stream/UI consumers in this idle
fixture. The test's three nodes completed in about 0.1 host seconds in a focused
run; host timing is informational and has no pass threshold.

One 20-text, no-retry conversation observed 22,981 frame writes including setup,
Session Proof, capabilities, and non-Chat traffic, of which **40 complete Chat
transfers** represented the two hops of each text. That run took about 3.1 host
seconds; SQL totals including fixture setup and test assertions were:

| Node | SELECT | INSERT | UPDATE | DELETE |
|---|---:|---:|---:|---:|
| A | 462 | 44 | 61 | 0 |
| B | 513 | 44 | 84 | 0 |
| C | 467 | 45 | 61 | 0 |

Active totals include concurrent asynchronous completion and may vary by the
observation boundary. They are not a production per-minute budget, a pure Chat
benchmark, or real radio airtime. See saved logs for final-run observations.

## Scheduler frequency and work

`SosBleCoordinator` defaults to a 5-second periodic timer (12 callbacks/minute
while started), and also reacts to enqueue, connection, authentication and
foreground events. Its `processDue` calls the hop coordinator before the Direct
outbox drain; `_drain` calls the hop coordinator again. This explains two idle hop
executions per explicit tick in the fixture. Concurrent calls are coalesced.

Each hop execution checks Session Proof recovery, calls Chat `due`, processes
Help Offer and Chat queues, recovers stale SOS attempts and lists forwardable SOS
messages. Chat `due` performs an expiry update and a select and is invoked once
for pending-work discovery and again in `_processChatRelayDue`. The outer drain
also recovers stale Direct jobs, reconciles missing SOS jobs and queries the
Direct outbox. Due queries remain real SQL work even with no eligible peers.

When Chat remains forwarded without a receipt it is retried, with 5, 10, 20, 40,
80, 160 and then capped 320-second retry spacing, up to eight attempts and expiry.
Each retry repeats signature/path/participant verification and may broadcast
capabilities. Authentication recovery is separately bounded by
`RelayRepository.maximumRetriesPerPeer` (3 recovery attempts), with a 2-minute
proof response timeout. There is no established-proof time lease to profile.

Future option: retain an event-triggered drain and schedule one wakeup for the
earliest durable retry/expiry deadline. Coalesce duplicate due queries and cache
verified immutable artifacts with explicit trust invalidation. These need
measurement and security review before implementation.

## Connections and discovery

`HopRelayCoordinator._maybeConnect` bounds discovery candidates and permits at
most two connection requests per peer in its accounting window. It avoids peers
already connected/connecting and a central handshake/write conflict. Direct
connection policy also exists in `SosBleCoordinator`; measure aggregate attempts
across both paths before attributing reconnect churn to either.

`BlePresenceManager` aggregates per-transport discovery/advertising leases and
serializes reconciliation. A held lease does not issue a native start on every
tick. Android `startDiscovery` stops the prior scanner callback, increments a
scan session and uses a service filter with low-latency scan mode. iOS uses a
service filter and disables duplicate discovery. These protections do not prove
that runtime scan overlap or restart churn never occurs across native lifecycle
transitions. Existing presence/platform tests cover code contracts; native traces
are still needed.

Record per-peer request count, connection completion/error/timeout, proof time,
scan start/stop/session and queue depth in a physical run. Avoid addresses,
coordinates, message text and key material in exported metrics.

## Main isolate and native callback work

`BleMessageCodec` JSON-encodes messages, computes a CRC and splits into a safe
20-byte frame (14-byte header, only 6 payload bytes). `BleMessageAssembler.accept`
attempts decoding as frames accumulate. Reconstructing/decoding the growing
message on each frame is a candidate for superlinear work; profile it before
changing the codec. Fragmentation magnifies signed hop chains and embedded Help
Offers even for short text.

Canonical JSON, SHA-256, Ed25519 verification, path-chain verification and trust
queries run from the Dart coordinator; the actual crypto backend may perform
asynchronous work, so `await` alone does not prove all CPU work is off-isolate.
The simulation does not measure Flutter frame times. `NativeDatabase.memory` in
tests also does not establish production database threading behavior.

The coordinator logs each inbound frame and can publish runtime diagnostics.
Large frame counts can amplify logging, platform channel callbacks and stream
updates. iOS CoreBluetooth delegates are created on `.main`; Android uses its
main handler for callbacks and timeouts. No platform callback cost was measured.

## Streams, queues, timers and cleanup

- `SosBleCoordinator.stop` cancels polling, subscriptions, binding retry timers,
  clears session/assembler state, expires location jobs and waits for the drain.
  `dispose` is idempotent and owns transport disposal only when appropriate.
- Hop sessions cancel proof timers on reset. Status streams subscribe to message
  and attempt changes and cancel both subscriptions on listener cancellation.
  `watchStatus` reads incident messages but loads the attempts table and filters
  it in Dart; overlapping async `emit` calls and large histories merit profiling.
- `BleMessageWriteQueue` serializes each peer and prioritizes control messages
  between frame writes. Its pending list has no explicit admission byte/count
  limit. Caller-controlled enqueue bursts could accumulate memory.
- `BleMessageAssembler` caps delivered-ID history at 1,024 with 10-second timeout;
  incomplete frame buckets are aged on subsequent input but have no explicit
  global bucket/byte quota. Repeated duplicate incomplete frames are another
  memory/CPU candidate. No resource-exhaustion mitigation was added in Stage 2.
- Chat inbox/outbox rows have expiry/due filtering but no storage cleanup/quota
  policy equivalent to a physical SQLite file cap. Eight attempts bound active
  retries, not long-term row accumulation. Existing SOS logical accounting does
  not automatically cover media or all Chat storage.
- `_chatTimers` and origin timing maps deserve long-session cardinality tracking;
  forwarded messages are not final delivery acknowledgements and lifecycle
  cleanup may not keep their size bounded within a long foreground run.
- Android dispose removes connection/setup/notification callbacks and clears
  native queues; iOS dispose stops scanning/advertising and completes pending
  operations. Source review cannot establish absence of native lifecycle races.

## Proposed next measurements (not implemented)

1. Capture scheduler executions and SQL counts with idle, active, unavailable
   peer, and repeated navigation cases. Compare both drain paths together.
2. Instrument queue depth/bytes, oldest waiting age and frame callback rate;
   sample logs rather than logging every frame during profiling.
3. Profile encode/reassembly and signature chains by message/frame size in Dart
   CPU timelines; correlate with Flutter frame timings on Android and iOS.
4. Track listener and timer counts before/after navigation, foreground changes,
   account changes and disposal.
5. Evaluate event-driven deadlines, bounded queues, incremental assembly and
   verification caching individually after measurements. Preserve proof and
   per-frame eligibility gates, receipt priority and durable retries.

## Verification classification

- **PASS:** device-free executor/transport counters and automated lifecycle tests.
- **NOT TESTED:** production-scale queue growth, UI rebuild costs and device CPU
  profiles; no before/after performance improvement is claimed.
- **REQUIRES PHYSICAL DEVICE:** actual FPS, radio throughput/reliability, scan
  overlap traces, OS background limits, energy and battery consumption.


## Build8 media frame recovery checkpoint (8 November 2026)

The earlier20-byte simulation measurements remain historical baseline data.
Physical build7 first-photo delivery failed: the captured492450-byte PNG and
signed manifest match at both endpoints, but receiver had0 of121 complete chunks.
One1028-frame chunk began before198 frames of another message spanning158.872s;
the old10second per-token assembly timeout discarded the interrupted chunk.
This does not identify the other message type or establish the sole hardware cause.

Build8 queries role-specific native capacity20..512 (fallback20), negotiates
Android MTU before ready with3second fallback, and retains partial assemblies
while a peer is active, bounded by5minute total age and existing memory caps.
A second reproduced startup issue now considers live outgoing Chat recovery work.
Full host suite607, explicit contract1 and captured-photo crypto1 passed; native
builds passed. iPhone8 updated, Samsung/iPad7. No build8 physical throughput or
photo/video-delivery result yet; no speed, background or large-video guarantee.
