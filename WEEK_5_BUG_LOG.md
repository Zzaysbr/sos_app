# Week 5 — Phase 7 defects and verification

## Manual testing documentation standard (Q-805B)

Physical procedures now require a Test ID, purpose, preconditions, exact
numbered steps, expected result, sanitized evidence, and an explicit
PASS/FAIL/PARTIAL/NOT RUN result. The reusable map cases are in
`PHYSICAL_MAP_ACCEPTANCE.md`; the same standard applies to BLE, Chat, Location,
SOS, Permissions, Auth and release-install checks. Existing Android/iPhone
operator results are preserved; the latest iPhone fresh online tile reload is
now PASS by operator report because a previously unseen area rendered new tiles
after network restoration.

## Q-806 — Guest/authenticated isolation verification — 3 November 2026

Focused automated verification found no reproducible ownership defect. Coverage
includes Guest SQLite restart continuity, Guest history surviving login/logout,
Guest sync exclusion, Account A/B query isolation, retained-stream invalidation,
in-flight account-change fencing, duplicate sync protection and BLE queue scope.
No source fix was justified. Live Firebase Rules and physical account-switch
testing remain NOT RUN and must not be inferred from these tests.

## Q-803 — Critical SOS accessibility — 3 November 2026

Confirmed improvement: the primary SOS hold action had a label but no explicit
instruction hint or enabled-state semantics. The control now announces the
hold instruction and disabled state during submission without changing the
gesture or SOS lifecycle. Added a widget regression test; physical
VoiceOver/TalkBack acceptance remains NOT RUN.

Q-803 physical acceptance guide `Q803_PHYSICAL_ACCESSIBILITY.md` defines
independent TalkBack and VoiceOver cases. No physical screen-reader or contrast
result is claimed in this pass.

## Q-804 — Regression coverage matrix — 3 November 2026

The current tree was checked across authentication, Guest/account ownership,
SOS persistence/status, BLE identity/lifecycle, Chat/ACK, Location Sharing,
Relay v2, maps/configuration, settings/localization, accessibility/navigation
and cloud-sync failure recovery. Existing assertions cover the local/security
paths; no reproducible defect was found. Automated results remain separate from
live Firebase and physical-device acceptance.

Q-806 external acceptance preparation added `Q806_EXTERNAL_ACCEPTANCE.md` with
Guest persistence, A/B separation, logout/session and pending-sync race steps.
The checked-in Rules suite passed in the available emulator (8 tests); no live
Firebase or physical account-switch result is claimed.

Firebase CLI metadata access and local Rules dry-run compilation succeeded, but
live Account A/B testing is blocked without designated test credentials. No
production records were read or written.

Continuation date: 20–22 October 2026 (Asia/Bangkok). Existing working-tree changes were retained. Release remains **BLOCKED** pending real-radio retests and release configuration. Automated results below never replace physical results in `PHASE_7_RELEASE_VERIFICATION.md`.

## W5-01 — P0: Chat identity namespaces disagree

- Reproduce: offline Guest Android → iPhone SOS succeeds; iPhone replies once on that incident. Android assembles the Chat but rejects its account/Guest sender ID against its native Bluetooth peer address. Five same-message retries were observed; no receiver Chat/ACK success.
- Expected: the selected incident peer can exchange durable Chat with an application ACK; another peer cannot impersonate it.
- Root cause: account ownership, app device identity and native routing identity were treated as interchangeable.
- Fix: a nonsecret installation ID is persisted in Android private preferences / iOS UserDefaults, independent of account and Guest ownership. Production coordinators perform a connection-local `peer.binding.v1` challenge/response exchange. Chat transport sender and Chat author IDs must both match that peer's bound app identity; the native peer must also match an incoming SOS route or explicitly selected outgoing SOS recipient. Another simultaneous peer cannot claim the same bound identity. Disconnect clears the binding. Existing messages/owners are not rewritten.
- Compatibility: additive message type on existing v1 framing and existing service/characteristic UUIDs; no database migration, new dependency or Firebase Rules change. Old peers ignore the unknown type. SOS without optional sender identity remains compatible; Chat/Location with an old peer fail closed. A three-way response handles asymmetric GATT readiness; hello retries are bounded to three attempts. Binding frames retain immutable metadata across retries. Chat waiting for capability association remains queued without consuming retries or blocking SOS; Location UI waits at most 40 seconds for association. This is a session association with a user-selected radio peer, **not cryptographic identity verification, encryption or Firebase authentication**.
- Tests: two independent in-memory databases/radios, valid Chat persistence/ACK, asymmetric readiness, wrong logical/native sender, forged local Chat author (failed before fix, passed after), unrelated incident, stale binding response, disconnect and same-peer replay. Original expected-success release tests remain enabled and now pass using the production binding mode.
- Status: **FIXED IN SOURCE / FINAL PHYSICAL RETEST PENDING**. Frozen-source Android and iPhone profile builds are installed with app data preserved. Historical physical Chat result remains FAIL until a new-input run succeeds.

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

- Legacy SOS inbox rows without an observed native source and already-queued old-identity Chat are preserved. No peer is inferred from a replay, account login or whichever device happens to connect. No automatic resend or payload/owner rewrite is implemented. Explicit recovery for queued/failed outgoing Chat is now implemented in W5-13; legacy SOS rows remain unchanged.
- Map decision remains conditional Geoapify Free only; no account/key, paid plan or production configuration was introduced. Public OSM release fallback guard remains enabled. Native attribution links are now implemented; provider acceptance/terms/quota decision and runtime release configuration still require verification. No offline map tiles.
- Status: **PARTIALLY CLOSED / RELEASE BLOCKER**. Legacy Chat recovery is automated-pass; production map configuration remains OPEN. Review existing provider documentation/terms before configuring a free account. Do not treat debug/profile development tiles as production approval.

## Validation

Final command results and source evidence: `validation/week5/command-results.json`. Logs remain in `validation/week5/`; intermediate failures are retained. The frozen W5-09 source passes **203 full tests** and **90 focused tests** (both exit 0). Baseline was 169 PASS / 2 FAIL. This continuation adds 32 tests, fixes both original identity release tests and strengthens the existing location widget test. Analyzer and `git diff --check` exit 0. The first Android compile failed for an Int/Long scan-session mismatch; that failure log is retained. Final Android debug build exits 0 (29.2s Gradle). Final signed development iOS profile build exits 0 (12.6s Xcode), installs and launches on the iPhone after the user's Trust/Verify action. Final unsigned iOS debug build exits 0 (289.1s Xcode). Signed release remains NOT RUN. Compilation/install/runtime are reported separately from BLE acceptance.


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
- Status: **FIXED IN SOURCE / FINAL PHYSICAL RETEST PENDING**. Frozen-source builds are installed on both devices. This is a targeted routing correction, not Guest data migration.

Unsigned iOS debug validation before W5-08: **exit 0, 464.3s**, `ios-debug-build.log`. iPhone profile runtime subsequently opened after user Trust/Verify check: **USER PASS**; prior security/CLI failures are retained. W5-08 changes Dart source and therefore requires refreshed app/framework builds and final validation; earlier native compilation is preserved as historical evidence.


## W5-09 — P0: nullable Location sender bypassed a missing session binding

- Reproduce: disconnect the known incident peer, then inject a late Location packet or Location ACK without optional senderDeviceId. Both missing values compared equal, allowing persistence or acknowledgement without a current association.
- Expected: binding presence and matching logical sender are both mandatory in production, even for a previously known native route. No stale packet persistence or confirmation after disconnect.
- Root cause: comparing `_peerBindings[peer] != senderDeviceId` alone does not reject null/null.
- Fix: require an actual current binding entry before comparing identity. Existing native-source, incident, recipient, freshness, payload and ACK checks remain.
- Tests: both negative cases fail before the fix (unexpected inbox row / unexpected acknowledged state) and pass after the one-condition correction. Valid two-endpoint paths remain enabled.
- Status: **FIXED IN SOURCE / AUTOMATED VALIDATION PASS / PHYSICAL RETEST PENDING**. Frozen-source builds are installed. No UUID, schema, ownership or additional wire-format change.

## W5-10 — P0: native route rotation stranded a valid incident reply

- Reproduce: deliver and ACK an SOS, restart/update a peer so its native BLE
  route changes, then enqueue Chat on the same incident. The durable destination
  still points at the old route and the message remains queued.
- Root cause: the live binding had a stable app installation identity, but
  validated SOS/ACK evidence did not consistently persist it for route recovery.
- Fix: SOS delivery and ACK carry the existing nonsecret installation identity.
  A pending Chat/Location destination can change only when exactly one connected
  route is bound to the identity recovered from a validated SOS or ACK. Message
  ID, payload, owner and retry row are preserved. Chat/Location cannot establish
  this trust. Legacy unbound messages remain unchanged.
- Tests: full two-radio SOS/ACK, native-route rotation, reconnect/binding,
  same-ID Chat delivery and one persisted ACK/receiver row.
- Physical: new SOS passed Android→iPhone; Chat passed once in each direction
  with Delivered and one receiver row. Reopened/reconnected Chat retained
  Delivered and one receiver row.
- Status: **FIXED / AUTOMATED AND ANDROID↔IPHONE PHYSICAL PASS**. Controlled
  close-while-Queued and ACK suppression remain NOT RUN physically.

## W5-11 — P0: large Location delivery and stale UI route filter

- Reproduce 1: a production-shaped Location update encoded to 97 frames.
  Android reported native write acceptance for every frame, while the iPhone
  inbox had no Location row and no application ACK. Smaller SOS/Chat envelopes
  had passed on the same connection.
- Fix 1: omit `kind`, `messageId` and `createdAt` duplicates from the Location
  payload because the outer v1 envelope authenticates them. The decoder accepts
  compact and previous redundant representations and rejects conflicts. UUIDs,
  framing version/header and stored payload format remain compatible.
- Reproduce 2: after compact delivery, Android received two persisted ACKs and
  iPhone stored two verified updates, but `View shared location` stayed hidden.
  The query compared the current native source with the incident route saved
  before process/update rotation.
- Fix 2: current UI location selection uses the stable installation identity
  from validated incident evidence, with native-route matching only as a legacy
  fallback.
- Tests: compact frame budget/old-format compatibility; stable identity across
  route rotation; existing wrong sender/recipient, expiration, map and Stop
  tests retained.
- Physical: initial and subsequent Location updates received persisted ACKs;
  iPhone displayed `View shared location`; Stop returned to Off. Coordinates
  are not exported.
- Status: **FIXED / AUTOMATED AND ANDROID→IPHONE PHYSICAL PASS**.

## Final validation — 22 October 2026

- `flutter test`: **206 passed**, exit 0.
- Final focused Location/identity/map set: **46 passed**, exit 0.
- `flutter analyze lib test`: **No issues found**, exit 0.
- Android debug: exit 0, Gradle 7.1s; installed with data preserved.
- Signed development iOS profile: exit 0, Xcode 24.5s; installed with data
  preserved and used for final physical tests.
- Unsigned iOS debug: exit 0, Xcode 260.3s; active compilation, not a
  dependency-resolution delay or hang.
- `flutter doctor -v`: exit 0, no issues; Xcode 26.6 (17F113), CocoaPods 1.17.0.
- Signed App Store/release: NOT RUN.

## W5-12 — Debug BLE quality test lacked application delivery evidence

- Reproduce: use `BLE Test (Debug)` and send a message. The page reports native
  write acceptance but has no matched receiver ACK, PDR, latency, timeout or
  reconnect summary. The Settings entry also remained present in release mode.
- Root cause: the screen was a transport exerciser, not a two-endpoint quality
  diagnostic, and its route was not guarded by `kDebugMode`.
- Fix: add debug-only ping/ACK messages over the existing transport and framing,
  plus deterministic PDR/latency/native-failure/timeout/reconnect statistics.
  Settings hides the route outside debug and the page has a release-mode guard.
  RSSI is explicitly the last scan result; no distance is inferred.
- Tests: 19 focused BLE UI/statistics tests pass, including a decoded
  application ACK, wrong-peer/late ACK rejection and reconnect transitions.
  A process-restart test also proves a stale SQLite outbox sends the same message
  ID once after a new coordinator/database session starts.
- Physical range runs: **NOT RUN**. Use `BLE_RANGE_TEST_RUNBOOK.md`; no maximum
  range claim is made.

## W5-13 — P1: legacy queued Chat had no explicit recipient recovery

- Reproduce: an outgoing Chat persisted before a BLE destination was known has
  a durable queued/failed outbox row with `destinationId = null`. Opening the
  incident allowed selecting a recipient only for a new message; the existing
  row could never become due and remained stranded across restarts.
- Root cause: `assignDestinationIfMissing` existed at the persistence layer,
  but no owner-scoped Chat recovery operation or UI action connected it to an
  explicit user selection.
- Fix: incident Chat displays a separate warning for unrouted outgoing pending
  messages and requires the user to select a discovered/GATT-ready peer. One
  transaction scopes candidates by owner and incident, verifies the stored wire
  kind is Chat and the state is queued/failed, then records the route and resets
  retry state. Message ID, wire payload, sender and owner remain unchanged. An
  already-routed or other-owner row cannot be redirected. No peer is inferred
  from login, replay, proximity or an unrelated connection.
- Tests: repository coverage proves owner isolation, stable message/payload,
  idempotence and no redirection; widget coverage proves the warning, explicit
  picker/connect flow and durable route callback. Focused tests pass 29, full
  tests pass 331 and analyzer reports no issues.
- Status: **FIXED IN SOURCE / AUTOMATED PASS / PHYSICAL NOT RUN**. A device
  revalidation must start with a deliberately retained legacy unrouted Chat and
  confirm one same-ID delivery and one receiver row after explicit selection.

## W5-14 — P1: SOS delivery UI could display an older Chat outbox state

- Reproduce: persist an outgoing Chat for an incident before its missing SOS
  delivery row is reconciled. `watchDeliveryForSos` selected the oldest outbox
  row without checking its envelope kind, so SOS Details could label the Chat
  queue/ACK state as the SOS BLE delivery state.
- Root cause: an incident ID is shared by SOS, Chat and Location outbox rows;
  row age is not a message-kind boundary.
- Fix: keep the existing durable stream but select only a validated
  `sos.delivery` envelope before exposing the row to SOS status UI. No row,
  state, message ID, ACK correlation, schema or wire payload is changed.
- Recovery race audit: deterministic tests confirm owner/incident/Chat-kind,
  eligible-state and null-destination constraints; concurrent explicit choices
  assign exactly one peer; in-flight rows cannot be redirected; and the same
  routed message/payload remains due after a database restart. Coordinator
  startup failure therefore does not erase the committed route. A real-radio
  recovery run remains required.
- Tests: the reproducer failed before the watcher fix (`chat-before-sos` was
  returned) and passes after it. Current focused repository/widget tests pass
  33, the full suite passes 335, and analyzer reports no issues.
- Status: **FIXED IN SOURCE / AUTOMATED PASS / PHYSICAL NOT RUN**.

## W5-15 — P0: repository ACK acceptance did not require observed peer evidence

- Reproduce: enqueue a selected-destination SOS or Location row, then call the
  ACK persistence API with the correct `ackFor` but without an observed native
  source peer. Before this fix the row became `acknowledged`, because peer
  comparison was conditional on the optional source argument being present.
- Expected: a selected peer and matching message/kind are all required. Missing
  peer evidence, another peer or another message must not confirm delivery.
- Root cause: coordinator callers supplied the observed peer, but the repository
  invariant was fail-open for callers that omitted it. In addition, failed rows
  with no `nextRetryAt` were labelled as retryable/scheduled by SOS and Location
  UI, overstating the evidence after a rejected ACK.
- Fix: SOS and Location ACK persistence now require a non-empty stored
  destination and a non-empty, exact observed native source before accepting
  the ACK. Existing message, kind, incident, expiry and terminal-state checks
  remain in force. Failed UI states now distinguish a scheduled retry from
  `retry not scheduled`. No UUID, frame, schema, retry policy or message identity
  changed.
- Tests: the two peerless-ACK reproducers failed before the fix and pass after
  it. Additional deterministic coverage proves ACK correlation to exactly one
  SOS message, Location wrong-peer/wrong-message rejection, and accurate failed
  retry labels. Existing missing/delayed/duplicate ACK, terminal-state,
  receiver-deduplication and Location identity tests remain enabled. Focused
  tests pass 126 and the full suite passes 341; analyzer and diff check pass.
- Status: **FIXED IN SOURCE / AUTOMATED PASS / PHYSICAL NOT RUN**. Real-radio
  wrong-peer, ACK-loss/retry and duplicate-delivery tests are still required.

## W5-16 — Release/Relay physical gate is blocked by owner signing assets

- Current source evidence: the Relay v2 security/migration/lifecycle suite
  passes 165 tests, the full suite passes 341 and `flutter analyze lib test`
  reports no issues. No new reproducible Relay or Direct-v1 source defect was
  found in this continuation.
- Android: the Release task exits 1 as designed because the owner keystore and
  `android/key.properties` are absent; no Release APK/AAB was produced. A fresh
  debug APK has the same package and debug signer as the installed application,
  and was installed update-in-place on the SM-A536E without uninstalling or
  clearing data. Build, install and launcher invocation exit 0. This is not a
  signed Release result.
- iOS/iPadOS: iPhone 15 Plus and iPad Air 11-inch (M2) are paired, available and
  have Developer Mode enabled. The existing Team `78GZXS97G6` profile matches
  `com.n1cxltine.sosapp`, includes both UDIDs and expires 3 November 2026, but
  this Mac has only Team `ZZ6WC9ADGQ` development identities. The unsigned iOS
  Release compile exits 0; it is not installable and was not installed.
- Physical matrix: current-build Android↔iPhone, Android↔iPad, iPhone↔iPad and
  A→B→C Relay remain **NOT RUN / BLOCKED**. Installation or simulated three-node
  tests are not treated as physical transport evidence.
- Status: **AUTOMATED PASS / ANDROID DEBUG INSTALLED / RELEASE AND PHYSICAL
  BLOCKED**. Required next action is owner signing material, not weaker identity
  or protocol checks.

## W5-17 — P0 UX: Emergency creation required Relay and BLE choices

- Reproduce: hold the primary SOS action. The critical path displayed
  per-incident Relay Options and then a BLE recipient picker before opening the
  incident Chat. A person in distress had to understand transport concepts and
  wait for radio interaction even though local persistence had succeeded.
- Root cause: privacy consent, route assignment and emergency creation were
  coupled in one synchronous UI flow. The app had no durable, preconfigured
  origin-relay/location consent distinct from the existing switch that
  volunteers this device to carry other people's messages.
- Fix: Settings now stores two fail-closed choices: automatic Public Relay for
  this device's future SOS incidents, and separate inclusion of incident
  location. Android private preferences and iOS UserDefaults implement the same
  native contract. SOS is persisted first with its original incident identity,
  Chat opens immediately, and eligible Public Relay v2 enqueue plus discovery
  continues asynchronously. The critical path no longer opens either modal or
  picker. Relay participation for carrying other people's SOS remains a
  separate, default-OFF choice.
- Evidence semantics: a hop receipt is displayed as stored by a relay with
  final delivery unconfirmed. Native write is not delivery. Persistence failure
  does not open Chat; repeated submission and active-incident guards remain.
- Security limit: Direct v1 cannot safely choose an arbitrary discovered peer.
  Its current binding proves an installation session, not that the person or
  device is an authorized responder for this incident. Consequently an
  unrouted Direct v1 row remains durable and waiting rather than selecting the
  first radio or weakening recipient/ACK checks. Automatic direct selection is
  **NOT IMPLEMENTED** pending an approved responder-capability/trust design;
  Public Relay v2 is the automatic, capability-gated route available now.
- Tests: current widget coverage proves no critical modal/picker, persistence
  before Chat, Chat navigation without waiting for relay enqueue, safe consent,
  explicit location consent, persistence failure, status wording and native
  preference contract validation. Existing wrong-peer, wrong-recipient, ACK,
  retry and deduplication tests remain enabled. The follow-up active-incident
  regression retains inbound-ID streams for the page lifecycle so hold-progress
  rebuilds cannot reset the banner to a waiting state. `flutter test` passes
  373 tests, `flutter analyze lib test` reports no issues and
  `git diff --check` passes (1 November 2026).
- Physical evidence: an iPhone 15 Plus Profile build was signed with the
  existing Team and Bundle ID, installed update-in-place and opened from its
  Home Screen with existing data retained. One hold created exactly one SOS,
  opened its Chat immediately and displayed neither Relay Options nor a
  recipient picker. History card-to-Chat, its separate Details action, compact
  filters and search were also accepted. With an SOS already active, holding
  again kept the banner stable, created no additional incident and opened the
  existing incident Chat.
- Status: **PARTIAL / AUTOMATED PASS / IPHONE UX PASS**. One-tap local
  persistence and the active-incident duplicate guard are device-verified on
  this iPhone build. This is not BLE delivery evidence. Direct responder
  selection and current-build iPhone→Android→iPad validation remain open
  release blockers.

## W5-18 — Relay-only physical evidence was not observable in the app

- Physical evidence (1 November 2026): iPhone A → Android B → iPad C completed
  one foreground hop-only store-and-forward route. C retained one relay-only
  envelope at incoming hop 1; B retained one verified signed hop receipt;
  message ID and immutable digest matched. C correctly created no normal SOS
  History row. This is **not** final-responder delivery.
- Usability gap: confirming the relay-only row required copying the private app
  database with development tools. The normal History model intentionally
  excludes the row, so the operator had no safe on-device evidence view.
- Fix: developer builds now expose a read-only `Relay Diagnostics` screen backed
  by the existing Relay v2 message, attempt and receipt tables. It shows only
  masked IDs, shortened digests, hop/persistence/job state, counts and coarse
  error categories. It never shows message text, coordinates, peers, keys,
  signatures or raw errors and never mutates relay state.
- Evidence semantics: the screen separates local-origin jobs, relay-only
  envelopes, hop receipts and final responder receipts. A hop receipt is never
  labelled final delivery. Because the current schema does not durably record a
  receipt sent by the local hop, absence is displayed as `Not recorded locally`
  rather than inferred.
- Release guard: Settings does not construct the route in Release, the route
  factory returns no route in Release, and the page refuses to render diagnostic
  data in Release. Debug/Profile developer builds remain available for physical
  investigation.
- Physical remediation (2 November 2026): Android logs exposed two independent
  fail-closed boundaries during the new run. An authenticated receiver rejected
  an offer because the receipt path required the reciprocal session binding
  instead of the proof binding issued by the offer receiver. A second run lost
  foreground while a multi-frame proof response was being written; resume kept
  the native GATT connection but did not restart proof. Receipt correlation now
  uses the receiver-issued binding, and foreground resume invalidates partial
  proof then re-advertises capability and re-challenges retained sessions. No
  BLE UUID, wire format, schema or message identity changed.
- Automated evidence (2 November 2026): 8 diagnostics tests pass; the focused
  Relay/diagnostics set passes 105; the latest focused coordinator set passes
  25; the full suite passes 391; analyzer and `git diff --check` pass. Android
  Debug and signed iOS Profile builds installed update-in-place on the tested
  devices. The prior unsigned iOS Release compile and release-label inspection
  remain compile evidence only, not release signing evidence.
- Physical Diagnostics evidence: a fresh iPhone A → Android B → iPad C run
  showed one hop-0 relay-only envelope on B and one hop-1 relay-only envelope on
  C. B recorded `Stored by next relay`, one attempt and `Received from next
  relay`; C recorded `Stored on relay`. Both screens hid sensitive fields,
  remained read-only and stable after navigation. B/C History remained empty.
  The origin still correctly showed final delivery unconfirmed.
- Status: **FIXED / AUTOMATED PASS / ANDROID + IPAD PHYSICAL DIAGNOSTICS PASS**.
  Final responder delivery remains **NOT IMPLEMENTED / NOT VERIFIED**.

## W5-15 — Option A Safe Minimal MVP decision

- Decision date: 2 November 2026 (Asia/Bangkok).
- Owner decision: **Option A — Safe Minimal MVP APPROVED**. Final Delivery v3
  is deferred; no credential, enrollment, trust authority, schema or protocol
  implementation is authorized.
- Production Trust Authority, real responder enrollment/eligibility and external
  operational ownership remain **BLOCKED**.
- Source verification: Direct v1 remains independent and application-ACK based;
  Relay v2 remains hop-only; self-signed final receipts fail closed; hop storage
  never creates normal History; native write is not delivery; exact duplicate
  hop receipts are idempotent; terminal verified delivery cannot regress; Guest
  SOS remains local and is not merged into authenticated cloud sync.
- UI review: Relay copy consistently retains `final delivery unconfirmed` and
  Diagnostics explicitly says hop storage does not prove responder receipt.
  Direct Chat/Location delivery wording is backed by the selected-peer persisted
  application ACK and is not a real-world responder or dispatch claim.
- Safety defects found: none. No source, schema, native code, BLE UUID/wire
  format or dependency change was required.
- Current automated evidence: focused Relay/SOS/Chat/identity/Guest tests
  **215/215 PASS**; full suite **391/391 PASS**; analyzer and
  `git diff --check` pass. No source/test safety fix was necessary.
- Physical verification: **NOT RUN** for this decision task. Existing historical
  hop-only evidence remains unchanged.
- Release Gate: **BLOCKED** by production trust, map configuration, signed
  distribution artifacts and required physical-device verification.

## W5-19 — BLE adapter-off session state mismatch

- Physical evidence (3 November 2026): initial A↔B connection succeeded, but
  after disabling Bluetooth on A, A still showed Connected while B showed
  Disconnected. Re-enabling Bluetooth did not reconnect within 15 seconds;
  manual reconnect remained stuck at Connecting. No application messages were
  sent.
- Source evidence: iOS `centralManagerDidUpdateState` emits adapter state
  without clearing connected/connecting/ready sessions or emitting disconnect;
  Dart coordinator presence-loss handling does not invalidate peer sessions or
  schedule reconnect on powered-on. Android has separate GATT cleanup/stale
  callback guards.
- Attribution: **CURRENT LIFECYCLE DEFECT / REGRESSION UNPROVEN**. The iOS
  adapter-state gap exists in the historical `144f1cf` lineage and the prior
  physical pass did not cover Bluetooth Off→On. Later Chat/Location/Relay work
  is not established as the cause.
- Automated coverage gap: no native adapter poweredOff→poweredOn callback
  contract test asserting session invalidation and serialized recovery.
- Status: **PHYSICAL FAIL / SOURCE FIX NOT YET AUTHORIZED**. Recommended next
  step is a focused adapter-state contract and sanitized native event trace
  before a minimal platform fix; Q-703 and Release remain blocked.

### Q-703 contract remediation — 3 November 2026

- Defined the shared adapter-state contract in `PHYSICAL_BLE_ACCEPTANCE.md`.
- Dart coordinator now invalidates connected/connecting/binding/assembler state
  on powered-off, unauthorized, unsupported, or resetting events; powered-on
  restores eligibility without claiming a connection or auto-selecting a peer.
- iOS native transport now clears central sessions, cancels setup/write work,
  emits sanitized disconnect events, and removes stale discovered sessions when
  the adapter becomes unavailable. Android native behavior was not changed;
  existing GATT stale-callback cleanup remains in place.
- Added deterministic lifecycle coverage for powered-off invalidation,
  powered-on explicit reconnection eligibility, repeated adapter events, and
  unavailable-state blocking in `test/ble_session_lifecycle_test.dart`.
- Physical Bluetooth Off→On retest: **NOT RUN**. Q-703 remains acceptance-
  incomplete pending real-device recovery evidence.

### Q-703 physical recovery retest — 3 November 2026

- Operator observed initialization, discovery, connect, disconnect and three
  reconnect cycles passing on Samsung↔iPhone. Bluetooth Off produced
  disconnection; Bluetooth On restored adapter availability without an
  automatic connection. This is positive evidence for the adapter-state
  invalidation contract.
- Leaving the BLE screen without an explicit disconnect cleared the discovered
  list on return; no crash was reported. This is treated as a new scan-session
  behavior until lifecycle logs show otherwise.
- A UI convergence defect remains: one side can show Connected while the peer
  UI still shows disconnected even though a test message reaches the peer.
  Transport reachability is not equivalent to synchronized connection state.
- Fresh explicit reconnect result was not recorded. Status: **PARTIAL /
  ACCEPTANCE-INCOMPLETE**. Follow-up operator action confirmed that after
  Bluetooth was enabled again, explicit peer selection and reconnect succeeded.
  The UI convergence mismatch remains; collect sanitized event ordering before
  changing source again.

### Q-703B peer connection-state convergence investigation — 3 November 2026

- Read-only source/log review; no production source change.
- **Confirmed:** coordinator/native state is role-aware, while
  `BleTestPage._states` is keyed only by peer ID.
- Retained Android logs show same-peer central/peripheral event ordering. This
  supports the UI-conflation hypothesis but is not a paired remote-UI proof.
- Classification: source hazard **CONFIRMED**; stale-label explanation
  **LIKELY**; platform loss and cross-device convergence cause **UNPROVEN**.
- Paired sanitized runtime capture: **NOT RUN**. No SOS, Chat, or Location
  traffic was used.
- Proposed next step: role-aware UI aggregation and deterministic widget tests,
  only after approval. Q-703 remains `PARTIAL / ACCEPTANCE-INCOMPLETE`.

### Q-703B remediation — 3 November 2026

- Changed only `BleTestPage` state mapping: `_states` is now keyed by normalized
  peer and `BleSessionRole`.
- Aggregate labels preserve a connected role, expose both active roles, and
  restore connected snapshots after navigation.
- Added observable widget regressions for central/peripheral disconnect order,
  both-role aggregation, terminal disconnect, and navigation restoration.
- Physical verification after this patch: **NOT RUN**.

### Q-703B physical revalidation — operator report

- Updated Android and iPhone builds were reported passing for launch, data
  preservation, BLE visibility, reconnect cycles, navigation restoration, and
  Bluetooth Off→On explicit reconnect.
- Status: **DEVICE-VERIFIED (operator-reported)**. Paired sanitized logs were
  not retained in this turn; no SOS/Chat/Location traffic was used.

### Q-805 map provider validation — 3 November 2026

- Confirmed defect: non-empty but malformed Geoapify API-key configuration was
  previously accepted by provider validation.
- Fix: reject malformed key characters/lengths with a credential-safe error;
  no key is logged or displayed. Added a regression test.
- Physical map verification and provider account/quota/terms confirmation
  remain incomplete.

### Q-805A provider verification — 3 November 2026

- Local configuration is present, ignored and untracked; only the key name and
  presence were checked. The secret value was not printed.
- Build-time injection is via `--dart-define-from-file`; malformed/missing
  values fail closed in automated tests.
- Account ownership, active plan/quota, key validity against the live service,
  and current provider terms remain **NOT VERIFIED**.
- The ignored local config is mode 644; owner should tighten it to mode 600
  outside Git if other local users are in scope.

### Q-805B physical map acceptance — 3 November 2026

- Samsung SM-A536E: operator reported the complete map checklist passing.
- iPhone 15 Plus: map loading, pan/zoom, navigation, Geoapify/OSM attribution,
  links, no-network stability, existing-coordinate visibility, permission
  denial/regrant and large-text layout passed by operator report.
- iPhone online recovery is now **PASS — DEVICE VERIFIED (operator-reported)**:
  after network restoration, a previously unseen area rendered fresh tiles; the
  existing map remained visible, attribution remained present, and no crash or
  error was observed.
- No source fix was required and no production key was exposed.

### Q-707 Stage A direct BLE acceptance — operator report

- Samsung SM-A536E and iPhone 15 Plus discovered each other, connected,
  disconnected and reconnected successfully.
- Both UIs agreed on Connected/Disconnected state; no mismatch was observed.
- No SOS, Chat or Location payload was sent. Stages B–E remain NOT RUN.

### Q-707C SOS regression investigation — 3 November 2026

- **Observed:** Samsung created a local SOS while iPhone was connected and in
  Rescue/listening mode, but no received SOS appeared in iPhone History.
- **Confirmed root cause boundary:** the current automatic path persists the
  SOS and queues Relay v2 (`enqueuePublicRelay`). It does not enqueue Direct
  SOS v1 with a selected `destinationId`; relay-only envelopes are not normal
  SOS History records.
- **Guest/Auth classification:** `UNPROVEN`; no authenticated Account A/B
  physical run was available, so Guest mode must not be blamed.
- **Evidence:** existing Direct v1 coordinator tests and receiver persistence
  tests pass (57 focused tests). The captured Android window showed BLE scan
  activity but no SOS-level direct enqueue/persist/ACK evidence; this supports
  the routing divergence but is not a standalone transport failure proof.
- **Action:** no source change. Keep Q-707C open pending an explicit product
  decision and authenticated two-account physical validation.

### Q-707D guest three-device relay — Stage A/B operator evidence

- Stage A Samsung→iPhone: local SOS persisted; origin status was `stored on 1
  relay device`; iPhone Diagnostics showed incoming hop 1 and `stored on
  relay`. Local receipt state was not recorded.
- Stage B iPhone→iPad: iPad Relay On, but incoming hop remained 0, no relay job
  or receipt was visible, and no Rescue incident appeared.
- Classification: **PARTIAL**. The first observed missing boundary is B→C
  forwarding/receive; root cause remains unresolved because no paired B↔C
  session or forwarding-attempt log was captured. History 0 is expected for
  relay-only data.

### Q-707D latest B→C correction — 3 November 2026

- The later operator run showed iPad Diagnostics incoming hop `1` and
  `stored on relay` while Relay was On. This confirms relay persistence on C
  for that run and supersedes the earlier incomplete B→C observation.
- B/C local receipt state was not recorded, and C History remained `0`.
- Rescue incident visibility and Help acceptance remain unavailable by the
  current hop-only Relay v2 design; no source change was made.

### Q-708A final Rescue reception assessment — 3 November 2026

- **Confirmed:** Q-707D proves relay persistence only. C cannot currently
  promote a Relay v2 row into an actionable Rescue incident.
- **Required before implementation:** additive final-reception wire version,
  explicit voluntary-rescue consent/recipient binding, and a dedicated
  owner-scoped inbox with idempotent replay/expiry handling.
- **Safety decision:** do not reinterpret relay-only rows, auto-authorize BLE
  peers, or reuse professional Trusted Responder authorization. Implementation
  is paused pending owner approval of the protocol/trust design.

Q-708A implementation update — 3 November 2026: added voluntary-rescue scope
and consent (default off), schema 7 Rescue Inbox migration, Rescue Mode
candidate persistence, and idempotent local Offer Help. No relay-only row is
promoted into SOS History and no final delivery is claimed. Physical test is
NOT RUN.
