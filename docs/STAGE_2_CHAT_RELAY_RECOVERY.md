# Stage 2 — multi-hop Chat recovery

## Outcome

Device-free A-B-C and C-B-A text Chat now has executable coverage through real
production receive/forward handlers, real Session Proof, signatures, participant
authorization and separate durable databases. Twenty-message conversations pass
both without retries and across retry deadlines. This is **simulation success**.
No physical BLE verification, deployment, media implementation or Stage 3 work
was performed. There are remaining native callback and delivery-receipt contracts
described below; Stage 2 does not claim to solve the entire long-term system.

## Preservation and provenance

- Entry HEAD: `841add485e96836058576e619c13963a7c4bf628`.
- The project already contained extensive uncommitted Stage 0/1 and Stage 2 work,
  including the sender/hop separation, signed path chain, Chat authorization and
  initial three-node tests. That work was preserved and verified, rather than
  attributed entirely to this execution.
- `/tmp/sos_stage1_checkpoint.dCgeBv/` existed and contained HEAD, status, patch and
  archive. Its HEAD matched. Its lifecycle envelope predates the entry version's
  extra identifier-length/status validation; the newer validation was retained.
- Before editing, a new persistent workspace recovery checkpoint was created at
  `artifacts/stage2_recovery/start/`: `HEAD.txt`, `status.txt`, `tracked.patch`,
  `working-files.tar.gz`, and restoration guidance in `README.txt`.
  The archive contains tracked and nonignored untracked working files, including
  symlinks. Ignored local signing credentials/build caches were not collected;
  they were not changed. The checkpoint is local and has not been committed or
  uploaded. Retain it independently if this workspace is to be removed.
- Restore into a **separate checkout** of the recorded HEAD, then extract the
  archive there. Do not overwrite ongoing work. The binary patch is a separate
  review/recovery representation; do not apply it on top of extracted modified
  files.
- `security_preservation.json` records byte-for-byte preservation since entry of
  lifecycle repository/envelope, SOS repository, both lifecycle test files and
  database definition. Drift remains v9. No app identifiers, signing settings or
  native files were edited in this execution. No database migration/data deletion,
  destructive Git command, reset or cleanup operation was used.
- Entry working-tree baseline was **523 PASS / 8 FAIL**, rather than the older
  supplied 491/8 count, because it already included further work. Baseline
  analysis reported 12 issues in the unfinished Stage 2 test files.

## Authentication and routing

`HopRelayCoordinator._handleIncomingChatRelay` treats the two identities
independently:

1. Require an active proven immediate-peer session and current session binding;
   reject mismatched attempt IDs and retired sessions.
2. Verify the signed bounded hop chain ends at that authenticated immediate
   peer, addresses this installation and starts at the immutable original sender.
   Each hop commits to the envelope, explicit Help Offer, maximum hop count and
   preceding signed chain. Duplicate path keys, truncation, tampering and loops
   are rejected. Maximum path length remains three transfers.
3. Verify the original Chat signature and recipient key-to-public-key mapping.
4. `ChatRelayAuthorization` re-verifies the stored signed voluntary-rescue SOS,
   its origin key and immutable digest, then a signed explicit rescuer Help Offer
   bound to that origin/digest. Only victim/rescuer pairs for that incident may
   communicate. Arbitrary valid signers or self-declared incident ownership do
   not grant participant authorization. Legacy signed incident-ID bindings still
   require those origin and Help Offer checks; digest bindings are also accepted.
5. After asynchronous verification, recheck that the proven session is still
   current. Relaying requires opt-in from intermediates; authorized endpoints
   need not opt into forwarding other people's traffic.
6. Atomically persist the inbox and (on intermediates) the durable outbox with
   signed received path evidence. At the recipient, persist the visible Chat
   through the real Chat repository. Replayed identical content is idempotent;
   the same ID with conflicting signed content is rejected.
7. Prefer the final recipient when reachable. Otherwise choose an authenticated
   participating next hop that is not in the signed path or the original sender.
   Recheck current session/eligibility before each frame write. Preserve the
   immutable original sender and recipient at every hop.

`ChatRelayRepository` retains data for restart/retry and owner-scopes inbox/outbox
lookups. A transport write produces `forwarded`/UI `sent`, never sender-side
`delivered`. Successful writes and write failures consume a bounded attempt
budget (eight), with exponential delay capped at 320 seconds and a 30-minute
signed message lifetime. Expired rows cease being due. Exhausted rows are retained
but excluded from automatic retries; they do not imply successful delivery or a
proof of permanent destination failure. There is no automatic unlimited retry
reset on reconnect.

### Additional repaired arrival race

A Chat persisted after an active drain's due-query snapshot could join that
drain's future without being processed, leaving it waiting for the next periodic
poll. This was reproduced by a twenty-message alternating conversation that
crossed retry deadlines. `_chatArrivedDuringDrain` requests another pass only for
new Chat arrivals while preserving the existing scheduler/coalescing behavior
for other events. The regression succeeds without explicit polling or sleeps.
The original twenty-message/40-transfer test remains intact in its no-retry time
window; the separate overlap test permits legitimate retry traffic.

### Deterministic seams and observation

Optional constructor injection now supplies the Chat repository clock, periodic
coordinator timers and relay nonce source. Production defaults remain system time,
real timers and secure nonce generation. The simulator already supplies proof
timeouts and independent test key stores. SQL and transport counters live only in
test infrastructure and never replace business decisions or query results.

See `THREE_NODE_SIMULATION_TEST_PLAN.md` for topology, every failure injection,
reproduction commands and what each test actually covers.

## Automated verification (6 November 2026, Asia/Bangkok)

| Command / scope | PASS | FAIL | Result |
|---|---:|---:|---|
| Entry `flutter test --reporter compact` | 523 | 8 | Baseline failures recorded before editing |
| Final `flutter test --reporter compact` | 529 | 8 | Same eight baseline failures; no additional default-suite failure |
| Final focused Stage 2 + lifecycle + signed envelope + Q709 integration files | 65 | 0 | PASS |
| Stage 2 runtime/security/metrics subset | 38 | 0 | PASS (also included in final full and focused runs) |
| `flutter analyze lib test` | — | 0 | PASS, no issues |
| `flutter analyze regression` | — | 0 | PASS, no issues |
| `git diff --check` | — | 0 | PASS |
| Explicit deferred contract test file | 0 | 2 | FAIL, outstanding contracts below |
| Physical BLE/GPS/UI/energy behavior | — | — | NOT TESTED / REQUIRES PHYSICAL DEVICE |
| Media transfer | — | — | NOT TESTED; design only |

Focused final run includes:

```text
test/stage2_chat_runtime_test.dart
test/stage2_chat_security_test.dart
test/stage2_simulation_metrics_test.dart
test/incident_lifecycle_authorization_test.dart
test/incident_lifecycle_envelope_test.dart
test/chat_relay_envelope_test.dart
test/q709_chat_integration_test.dart
test/q709_three_node_integration_test.dart
```

Full suite includes existing direct Chat, hop relay, presence, Session lifecycle,
platform security, repository and UI tests. Existing Stage 1 authorization tests
remain passing. Drift's multiple-database debug warning is emitted because tests
instantiate the same database class multiple times; nodes use distinct executors
and the reopened file is closed before reopening. The warning was not suppressed.

All final and baseline logs are preserved under
`artifacts/stage2_recovery/results/`; `verification.json` records exit statuses.
The temporary initial SDK-cache sandbox denial was resolved by running Flutter
with authorized SDK access. A formatter telemetry write denial occurred after
formatting; final formatting was rerun successfully with SDK access. Neither was
reported as an application test failure.

### Eight unchanged baseline failures

| File | Test | Cause |
|---|---|---|
| `test/chat_relay_repository_test.dart` | outbox and inbox are owner-scoped and idempotent | Hard-coded 4 November envelope enqueued against actual clock; expired |
| same | due rows expire by envelope validation and retain queued state | Same expired enqueue fixture before the explicit `due(now:)` call |
| `test/rescue_response_envelope_test.dart` | reverse response persistence is idempotent and owner scoped | Expired Help Offer fixture |
| `test/ble_test_page_test.dart` | peripheral disconnect does not overwrite central connected | Expected legacy `State: connected` text not found |
| same | central disconnect does not overwrite peripheral connected | Same legacy UI assertion mismatch |
| same | both active roles are shown without an ambiguous state | Same legacy UI assertion mismatch |
| same | both role disconnects produce disconnected state | Expected legacy disconnected text not found |
| same | connected role snapshot restores after navigation | Same legacy UI assertion mismatch |

These files/tests were not deleted, skipped, weakened or changed in this
execution. Their baseline and final failures are the same. Fixing time fixtures
and UI expectations is follow-up work, not evidence against Session Proof.

## Explicit deferred failures and limits

`regression/stage2_remaining_contract_test.dart` contains executable, **unskipped
failing tests** for outstanding contracts. Run with:

```sh
flutter test regression/stage2_remaining_contract_test.dart --reporter compact
```

The file is deliberately outside default `test/` discovery; these two failures
are separately reported, not included in the 529/8 or passing focused claim.

1. **Stale native disconnect after reconnect — FAIL.** The simulator normally
   filters old-link data by generation. Bypassing that filter and surfacing a
   stale `disconnected` with the retired native attempt to the real coordinator
   invalidates the newer peer/role session: expected authenticated=true, actual
   false. The Dart coordinator does not gate this callback by native attempt.
   Android/iOS already have native callback/object guards, but this does not
   prove all stale callbacks are suppressed. Coordinated native-event generation
   semantics and transport snapshot filtering are deferred; no broad native
   lifecycle rewrite was attempted. The failure is loss of availability; it
   does not authorize forwarding without new proof. Physical reproduction and
   platform-specific callback ordering remain unverified.
2. **Signed final Chat receipt — FAIL / protocol not implemented.** After C
   durably receives text, A remains `sent`, not `delivered`. This is the correct
   conservative current behavior. Stage 2 does not invent new receipt semantics
   or reuse SOS receipts as Chat proof. A future version must define signed,
   immutable-message/digest/destination-bound receipts, durable receipt routing,
   replay protection and retransmission before satisfying the test. Missing
   receipt state is covered; a delayed Chat receipt itself is **NOT TESTED**
   because no such receive handler exists. Delayed duplicate text is covered.

The harness provisions verified SOS/Help Offer repository state; it does not
claim a new simulated end-to-end proof of their radio paths. Established proof
has no time-based lease; proof-response timeout/recovery and session loss are
covered. Text is authenticated signed plaintext and is **not end-to-end
encrypted**. Display time ties at Drift v9 second precision do not guarantee
total conversation order. Image/video remains unimplemented.

## Read-only performance and media deliverables

- `BLE_PERFORMANCE_INVESTIGATION.md`: real simulator SQL/transport counters,
  scheduler cadence and duplicate work, scan/connection controls, isolate and
  reassembly candidates, queues/listeners/timers, cleanup and proposed future
  measurements. No radio/battery/FPS improvement is claimed.
- `MEDIA_TRANSFER_ARCHITECTURE.md`: future signed manifest, file storage,
  resumable bounded chunks, integrity, quota/cleanup, MIME/privacy/authorization,
  separate E2EE evaluation, priority and Android/iOS design. No implementation.

## Changed-file inventory

The exact complete pre-existing working-tree modifications are in
`start/status.txt` and `start/tracked.patch`. This execution additionally changed:

| File | Purpose |
|---|---|
| `lib/features/nearby_ble/data/hop_relay_coordinator.dart` | Remember new Chat during an active drain; formatting |
| `lib/features/nearby_ble/data/sos_ble_coordinator.dart` | Optional virtual periodic timer/nonce seams; clarify forwarded state |
| `lib/features/sos/data/chat_repository.dart` | Optional clock for deterministic stored Chat metadata |
| `test/support/three_node_ble_simulation.dart` | Virtual timers/nonces, SQL/transport counters, targeted mid-frame faults |
| `test/stage2_chat_runtime_test.dart` | More exact metadata/attempt checks, direct path, frame loss, mid-transfer disconnect, missing receipts and arrival race |
| `test/stage2_chat_security_test.dart` | Analysis cleanup; all security assertions retained |
| `test/stage2_simulation_metrics_test.dart` | Idle work measurement against real SQL/handlers |
| `regression/stage2_remaining_contract_test.dart` | Two explicit failing deferred contracts |
| `docs/STAGE_2_CHAT_RELAY_RECOVERY.md` | This result, provenance and limits |
| `docs/THREE_NODE_SIMULATION_TEST_PLAN.md` | Harness boundary and fault coverage matrix |
| `docs/BLE_PERFORMANCE_INVESTIGATION.md` | Read-only investigation |
| `docs/MEDIA_TRANSFER_ARCHITECTURE.md` | Future design only |
| `artifacts/stage2_recovery/` | Local checkpoint, preservation/entry-delta manifests and validation evidence |

`changed_since_entry.json` records hashes for the implementation/test/document
files; recovery evidence is excluded from that manifest to avoid self-reference.
The Stage 2 authentication implementation already at entry includes
`chat_relay_authorization.dart`, `chat_relay_repository.dart` and
`chat_relay_envelope.dart`; they remain part of the resulting uncommitted patch
but were not rewritten by this execution. Other existing native/UI/security
changes remain untouched. No commit was created.

## Remaining physical verification checklist (not executed)

- [ ] A victim, B relay and C rescuer on supported Android/iOS combinations;
      physically exclude direct A-C reachability and confirm both Chat directions.
- [ ] Observe original key identity vs immediate authenticated peer on each hop,
      actual Help Offer binding and authentic permission-controlled GPS provenance.
- [ ] Disconnect before/during frame writes and receipt writes; reconnect,
      reauthenticate, restart each app and verify pending data and deduplication.
- [ ] Exercise stale native callbacks, adapter power loss, role overlap, address
      changes, permission changes and foreground/background suspension.
- [ ] Confirm signed Cancel/Resolve authorization and existing lifecycle behavior
      with real peers after the Stage 2 changes.
- [ ] Record realistic scheduler/SQL/callback/scan/connection counts, CPU and
      Flutter frame timings, transfer throughput and battery impact.
- [ ] Verify native key storage, signing configuration and persistent-data
      recovery on both platforms. Do not delete app data to make tests pass.
- [ ] After a separately authorized receipt/media stage, validate those protocols
      independently; current text tests do not prove media transfer or E2EE.

Stop point: automated Stage 2 verification completed. No physical deployment and
no progression into Stage 3.
