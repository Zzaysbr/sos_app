# Week 5 — Phase 7 defects and verification

Continuation date: 2026-10-20 (the requested Week 5 heading refers to 21 Oct). Existing working-tree changes were retained. Release remains **BLOCKED** pending real-radio retests and release configuration. Automated results below never replace physical results in `PHASE_7_RELEASE_VERIFICATION.md`.

## W5-01 — P0: Chat identity namespaces disagree

- Reproduce: offline Guest Android → iPhone SOS succeeds; iPhone replies once on that incident. Android assembles the Chat but rejects its account/Guest sender ID against its native Bluetooth peer address. Five same-message retries were observed; no receiver Chat/ACK success.
- Expected: the selected incident peer can exchange durable Chat with an application ACK; another peer cannot impersonate it.
- Root cause: account ownership, app device identity and native routing identity were treated as interchangeable.
- Fix: a nonsecret installation ID is persisted in Android private preferences / iOS UserDefaults, independent of account and Guest ownership. Production coordinators perform a connection-local `peer.binding.v1` challenge/response exchange. Chat transport sender and Chat author IDs must both match that peer's bound app identity; the native peer must also match an incoming SOS route or explicitly selected outgoing SOS recipient. Another simultaneous peer cannot claim the same bound identity. Disconnect clears the binding. Existing messages/owners are not rewritten.
- Compatibility: additive message type on existing v1 framing and existing service/characteristic UUIDs; no database migration, new dependency or Firebase Rules change. Old peers ignore the unknown type. SOS without optional sender identity remains compatible; Chat/Location with an old peer fail closed. A three-way response handles asymmetric GATT readiness; hello retries are bounded to three attempts. Binding frames retain immutable metadata across retries. Chat waiting for capability association remains queued without consuming retries or blocking SOS; Location UI waits at most 40 seconds for association. This is a session association with a user-selected radio peer, **not cryptographic identity verification, encryption or Firebase authentication**.
- Tests: two independent in-memory databases/radios, valid Chat persistence/ACK, asymmetric readiness, wrong logical/native sender, forged local Chat author (failed before fix, passed after), unrelated incident, stale binding response, disconnect and same-peer replay. Original expected-success release tests remain enabled and now pass using the production binding mode.
- Status: **FIXED IN SOURCE / PHYSICAL RETEST PENDING**. The updated app has not yet been installed/accepted on both devices in this continuation. Historical physical Chat result remains FAIL.

## W5-02 — P0: Location recipient/sender/ACK disagree

- Reproduce: publish default Location to native route B; receiver expects account B rather than its own device identity.
- Expected: selected incident peer receives a fresh update addressed to its app identity and ACKs the original message over its native route.
- Root cause: recipient identity was conflated with outbox destination; sender validation had the same mismatch as Chat.
- Fix: recipient identity comes from the verified session binding while the outbox keeps its explicit native destination. Repository accepts that separately checked recipient, validates the bound sender, and stores the observed native source in the existing inbox column. Wrong recipient/incident/native peer receives no ACK. Duplicate native-source binding and payload checks remain. Location queries filter the stored native source rather than comparing a logical ID to a radio ID. Location alone cannot establish an incident reply route.
- Tests: complete persistence/application ACK path, wrong peer, wrong recipient, same-message retry with one row and another ACK; existing freshness, stop and ownership tests retained.
- Status: **FIXED IN SOURCE / PHYSICAL NOT RUN**. Coordinate fixtures in tests are synthetic. Foreground sharing remains initial/manual updates; offline tile download is not implemented.

## W5-03 — P0: disposed native transport cannot reactivate safely

- Reproduce: account/session replacement disposes the shared native bridge; next iOS permission request is rejected, or Android suppresses events indefinitely. Fresh process worked around this during Phase 7.
- Expected: old teardown completes before the new session starts; late callbacks cannot affect the new owner.
- Root cause: native disposed flags persisted across Dart clients; AuthGate discarded asynchronous teardown futures. GATT-server/scan callbacks could target replacement state.
- Fix: AuthGate awaits the serialized teardown barrier and shares the actual startup future. A resource generation invalidates retired sessions immediately, including rapid A→B→A transitions before teardown completes. Coordinator startup is single-flight, subscribes before permission/readiness and checks retirement between async startup steps. iOS recreates managers at reactivation, detaches retired delegates, cancels setup timeouts and pending connection attempts, waits at most 15 seconds for known manager readiness and checks manager/peripheral identity on callbacks. Android reactivates at permission/initialize entry, fences GATT-server callbacks with a session generation, isolates scan callbacks per scan and retains existing GATT/advertising object guards. Native permission order is preserved. Android state reporting checks permission before reading adapter state; teardown continues best-effort when permissions have been revoked.
- Tests: concurrent starts both wait; disposing while permissions are pending prevents initialization; late picker subscriptions replay current connection readiness; disconnected peers are not replayed and disposal cancels the native event subscription.
- Limits: Dart lifecycle tests are deterministic. Physical Android Guest advertising → Login A → Start Scan and Logout → Guest → Start Advertising now pass by user observation (same native bridge; before final generation/scheduling refresh). Real native old-callback injection, repeated A/B transitions with connected radios, permission revocation/regrant and resume after this fix remain **NOT RUN**; native compilation is reported separately. Therefore this P0 is **PARTIALLY VERIFIED**, not a closed release gate.

## W5-04 — P0: ACK/native-write completion races

- Reproduce: receiver ACK reaches SQLite before the last native write returns, or an ACK arrives after a timeout changed state to failed.
- Expected: only a persisted ACK confirms receipt; write completion never regresses terminal confirmation. Late valid ACK can confirm a sent attempt; wrong peer and expired rows cannot.
- Root cause: sequential sending → writeAccepted → awaitingAck transitions competed with independently recorded ACK; Chat completion/status updates were not monotonic. Failed state rejected delayed valid ACKs.
- Fix: atomic write-completion reconciliation preserves acknowledged/expired rows. Delayed ACKs may confirm failed attempts after the same message/kind/SOS/native destination checks. Chat delivery status cannot leave delivered. Duplicate negative ACK uses the recorded terminal state. Failure handlers leave terminal rows intact.
- Tests: early, delayed, missing, wrong-peer, duplicate negative and expired ACK cases; full two-endpoint Chat and Location ACKs; Chat late Sent/Failed regression.
- Status: **FIXED IN SOURCE / PHYSICAL TIMING RETEST PENDING**. The historical initial iPhone Awaiting/Failed observation is not relabeled PASS; that exact timing was not captured on hardware.

## W5-05 — P1: concurrent duplicate could receive an incorrect positive ACK

- Reproduce: same peer sends the same message ID with different content before the first SQL write finishes.
- Root cause: in-flight delivery futures reported persistence without validating the second payload.
- Fix: SOS compares the persisted payload and source; concurrent Chat revalidates exact persisted content before duplicate ACK. Existing primary keys and message IDs are preserved.
- Test: simultaneous original/changed Chat payloads retain one original row and emit exactly one positive ACK.
- Status: **AUTOMATED PASS / PHYSICAL NOT RUN**.

## W5-06 — P1: UI startup, continuity and accessibility

- Location sharing now waits for coordinator readiness before opening recipient selection; cancel leaves sharing Off. A retained delivery stream avoids resubscription on every local state change.
- Connection snapshots let recipient/debug screens see an already-ready peer without requesting a second native connection; disconnect/dispose removes it.
- Location status has a separate screen-reader live region, with text labels in addition to color; sharing controls have minimum 48×48 targets. Tests exercise normal and 200% text, pending startup, navigation cancellation and cleanup.
- Public map attribution links are visible, have 48px minimum targets and open through a narrowly allowed HTTPS native channel. Link failures show a friendly message without printing URLs/keys. Automated URL/target test passes; physical link opening remains NOT RUN.
- Legacy outgoing Chat origin is retained using existing durable outbox identity, without rewriting sender IDs or owners when introducing installation IDs.
- Status: **AUTOMATED PASS / PHYSICAL NOT RUN**. A full screen-reader/device-size/reduced-motion audit was not performed.

## W5-07 — P1: legacy unbound messages and production map configuration

- Legacy SOS inbox rows without an observed native source and already-queued old-identity Chat are preserved. No peer is inferred from a replay, account login or whichever device happens to connect. No automatic resend or payload/owner rewrite is implemented. Safe explicit legacy recovery UI/compatibility remains OPEN.
- Map decision remains conditional Geoapify Free only; no account/key, paid plan or production configuration was introduced. Public OSM release fallback guard remains enabled. Native attribution links are now implemented; provider acceptance/terms/quota decision and runtime release configuration still require verification. No offline map tiles.
- Status: **OPEN / RELEASE BLOCKER**. Review existing provider documentation/terms before configuring a free account. Do not treat debug/profile development tiles as production approval.

## Validation

Final command results and source evidence: `validation/week5/command-results.json` (to be populated when each command exits). Logs remain in `validation/week5/`; intermediate failures are retained. At the latest completed full run: **203 tests PASS, exit 0**. Baseline was 169 PASS / 2 FAIL. This continuation adds 32 tests, fixes both original identity release tests and strengthens the existing location widget test. Final analyzer exits 0 with no issues. The first Android compile failed for an Int/Long scan-session mismatch; that failure log is retained and the corrected build exits 0. A final Android refresh includes the separately reproduced/fixed Chat-author guard. Signed development iOS profile builds exit 0 (initial 843.2s, final incremental 27.0s), installation exits 0. Runtime launch is currently blocked by the device security/trust error: disk signature verifies, provisioning includes this device/bundle and expires 2026-10-27. Trust/Verify check requested. Unsigned debug build remains in progress. No runtime PASS is inferred from compilation/installation.


## Free-only map decision review (2026-10-20)

Rechecked [Geoapify pricing](https://www.geoapify.com/pricing/), [tile documentation](https://apidocs.geoapify.com/docs/maps/map-tiles/) and [terms](https://www.geoapify.com/terms-and-conditions/). The Free plan currently lists 3,000 credits/day, 5 requests/second and no credit card requirement; production use requires quota compliance and provider/data attribution. The terms reserve suspension or overage charges when limits are exceeded. Consequently **no paid plan or guaranteed unlimited/free production capacity is approved**. Geoapify Free remains a candidate pending account/quota controls and acceptance of its applicable terms; no account/key was created. Production without compliant configuration keeps the existing coordinate/marker fallback, with no public OSM release tile fallback. Offline map tiles remain absent.


## Files/modules changed in this continuation

- BLE persistence/coordinator/transport: `lib/features/nearby_ble/data/ble_delivery_repository.dart`, `sos_ble_coordinator.dart`, `ble_transport.dart`.
- Session startup and Chat origin/status: `lib/main.dart`, `lib/features/sos/data/chat_repository.dart`.
- Native bridges: `android/app/src/main/kotlin/com/example/sos_app/BleTransportBridge.kt`, `MainActivity.kt`, `ios/Runner/BleTransport.swift`, `AppDelegate.swift`.
- UI: `lib/features/sos/presentation/location_sharing_panel.dart`, `incident_map_page.dart`, `emergency_chat_page.dart`.
- Tests: `test/ble_identity_release_gate_test.dart`, new `ble_session_lifecycle_test.dart`, `ble_delivery_repository_test.dart`, `ble_transport_test.dart`, `chat_repository_test.dart`, `location_sharing_panel_test.dart`, `incident_map_page_test.dart`, new `chat_reply_routing_test.dart`.
- Reports/evidence: this file, `PHASE_7_RELEASE_VERIFICATION.md`, `OFFLINE_SOS_RELEASE_READINESS.md`, `validation/week5/`.

Other changes already present at preflight were preserved, including Phase 6.3 ownership/navigation work and earlier Phase 7 SOS/map/startup fixes. Preferences may be restored/cloned with device backups; installation IDs are an association aid, not a hardware ownership guarantee. Reinstall, reset or native address rotation can require explicit recipient selection.


Final Android native permission-safety build: exit 0, 6.4s Gradle; installed with `-r` and launched. The earlier 43.8s build predates only that native permission cleanup. Full final rerun: 199 PASS, exit 0. Profile launch CLI initially rejected an unsupported option (64); corrected syntax then reached device security rejection (1), both recorded separately from successful build/install.


## W5-08 — P0: reverse Chat reused an owner ID as a native route

- Reproduce: receive a Chat (its recipientId is the local account/Guest owner), then send a reply. The page restored the incoming owner value as `_selectedDestinationId`. Separately, an SOS author with an explicitly selected outgoing SOS recipient had no incoming inbox route, so default Chat could stay unassigned.
- Expected: incoming ownership scope never becomes a Bluetooth destination; default reply uses the incident's recorded source or explicitly selected outgoing SOS peer.
- Root cause: UI restored recipientId from every history row; coordinator fallback considered incoming SOS only.
- Fix: restore destinations only from outgoing Chat rows. Coordinator fallback uses the existing `lookupIncidentDestination`, which considers incoming SOS and explicit outgoing SOS destinations, never Location/history proximity. No legacy payload, ownership or message ID is changed.
- Tests: widget reproducer fails with destination `local-owner`; outgoing-only incident test fails with null destination. Both fail before and pass after correction; all identity tests retained. The initial selector invocation matched no tests (exit 79) and was rerun correctly, not counted as a test result.
- Status: **FIXED IN SOURCE / DEVICE REFRESH AND PHYSICAL RETEST PENDING**. This is a targeted routing correction, not Guest data migration.

Unsigned iOS debug validation before W5-08: **exit 0, 464.3s**, `ios-debug-build.log`. iPhone profile runtime subsequently opened after user Trust/Verify check: **USER PASS**; prior security/CLI failures are retained. W5-08 changes Dart source and therefore requires refreshed app/framework builds and final validation; earlier native compilation is preserved as historical evidence.


## W5-09 — P0: nullable Location sender bypassed a missing session binding

- Reproduce: disconnect the known incident peer, then inject a late Location packet or Location ACK without optional senderDeviceId. Both missing values compared equal, allowing persistence or acknowledgement without a current association.
- Expected: binding presence and matching logical sender are both mandatory in production, even for a previously known native route. No stale packet persistence or confirmation after disconnect.
- Root cause: comparing `_peerBindings[peer] != senderDeviceId` alone does not reject null/null.
- Fix: require an actual current binding entry before comparing identity. Existing native-source, incident, recipient, freshness, payload and ACK checks remain.
- Tests: both negative cases fail before the fix (unexpected inbox row / unexpected acknowledged state) and pass after the one-condition correction. Valid two-endpoint paths remain enabled.
- Status: **FIXED IN SOURCE / FINAL VALIDATION AND DEVICE REFRESH PENDING**. No UUID, schema, ownership or additional wire-format change.
