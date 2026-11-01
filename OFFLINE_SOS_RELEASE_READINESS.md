# Offline SOS release readiness

Current gate: **BLOCKED**. Phase 7 historical evidence records Android↔iPhone
SOS and Chat in both directions plus foreground Location delivery, persisted
ACK, map presentation and Stop on the devices used then. Those results are not
a PASS for the current build; the latest-build physical matrix is NOT RUN.
Remaining blockers are listed below. Integrated historical evidence is in
[WEEK_5_BUG_LOG.md](WEEK_5_BUG_LOG.md) and
[PHASE_7_RELEASE_VERIFICATION.md](PHASE_7_RELEASE_VERIFICATION.md).

Phase A closure status (23 October 2026): repository-level BLE, Guest/account,
map failure and signing-guard checks pass, including new direct coverage for
connectivity retry and session-expiry gating. Full tests pass 215 and the
focused release suite passes 108. Full-repository analysis remains non-green
with 32 `info` findings confined to the vendored nearby-connections package;
`flutter analyze lib test` passes. Current-build physical cases, live Firebase
expiry/retry, account-owned map runtime and signed Android/iOS artifacts remain
NOT RUN. Identity/distribution history requires an owner decision. See
`PHASE_A_RELEASE_CLOSURE_REPORT.md`, `PHASE_A_MANUAL_ACTIONS.md`,
`PHASE_B_ROADMAP.md` and `validation/phase-a/`.

Phase 10 identity/signing evidence is in
`PHASE_10_RELEASE_IDENTITY_SIGNING_AUDIT.md` and `validation/phase10/`. The
current source identity is `com.n1cxltine.sosapp` on both Android and iOS. The
Android migration keeps the prior `com.example.sos_app` Firebase registration
and installed application available for rollback and coexistence; it does not
move or merge data from that application's private sandbox. Target-package
device coexistence and persistence checks remain NOT RUN.
Android release signing now fails safely when account-owned signing material is
missing or invalid; signed Android and iOS releases remain NOT RUN. Geoapify
configuration now also fails closed when its API key is absent. Live production
map verification is still NOT RUN.

This checklist describes the implementation currently in this repository. It
does not claim Android/iOS BLE interoperability until a physical-device test
has produced evidence.

## Offline data flow

1. `SosRepository.create()` writes the SOS row and `sos_sync_queue` in one
   Drift transaction. The local row is the source of truth while offline.
2. The BLE callback receives the persisted SOS and writes a durable BLE
   outbox row. BLE delivery is independent from Firestore sync.
3. `SosSyncCoordinator` retries the Firestore queue when connectivity returns,
   on authentication changes, and when the app resumes. A failed cloud write
   remains queued.
4. Chat messages and incoming location updates are read from Drift. BLE
   inbox/outbox rows use stable message IDs and explicit destinations.

Cloud success is never inferred from local creation or a BLE characteristic
write. A delivery is acknowledged only after a valid application ACK.

## Guest and startup behavior

The app now shows a short in-app startup animation and opens Home without an
authentication wall. Guest mode uses a local-only owner ID (`guest-local-device`)
for Drift records and BLE outbox ownership; it does not create a Firebase user,
does not bypass Firestore rules, and does not attempt cloud sync. Guest SOS,
map, explicit BLE recipient selection, offline chat, and location sharing remain
available subject to device permissions and a selected peer. Cloud sync,
account-owned history across devices, and account settings require Login or
Register.

Guest data is not automatically merged into a later authenticated account.
Signing in changes the active owner scope to the Firebase UID while the local
guest rows remain isolated on the device. This transition policy prevents
accidental ownership transfer and should be revisited before promising account
migration.

Startup does not request Bluetooth or location permissions, connect BLE, or wait
for Firestore. BLE initialization begins only after an SOS/chat delivery action
or the debug BLE workflow requests it. Local SOS persistence remains the first
step and survives permission denial or offline cloud failure.

## Implemented safeguards

- Drift schema version is 5 with migrations for SOS, cloud queue, BLE inbox /
  outbox, and Chat records.
- Outbox claims and state transitions are conditional and preserve the stable
  message ID and destination across retries.
- `sending`, `writeAccepted`, and `awaitingAcknowledgement` rows are recovered
  as retryable after an interrupted run. `acknowledged` and `expired` rows are
  not requeued.
- Duplicate SOS, Chat, and location deliveries are idempotent. Wrong-peer,
  wrong-kind, conflicting-payload, and invalid ACKs are rejected.
- Incident coordinates are an immutable creation snapshot. Incoming shared
  locations are separate, sender-filtered, and expired locations are not shown
  as current.
- Location permission, disabled GPS, timeout, invalid coordinates, BLE
  permission failure, disconnect, and map tile errors have explicit UI/error
  states. No background location permission or tracking is used.

## Map provider configuration and release gate

`MapTileProviderConfig` accepts `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, and
`MAP_TILE_USER_AGENT` through `--dart-define`, so the map UI does not depend on
one tile vendor. The checked-in OpenStreetMap URL is a development fallback
only. In a release build, an unset or invalid provider is rejected and the map
keeps its incident/shared-coordinate markers without creating tile requests.
There is currently **no approved production provider configured** for this
project, so no provider pricing or free-tier allowance is claimed.

The OSM standard tile service is not a general production backend: its
[official tile policy](https://operations.osmfoundation.org/policies/tiles/)
requires visible attribution, a valid identifying User-Agent, cache-aware
requests, and forbids bulk/offline prefetching. It is best-effort with no SLA
and access may be blocked if use harms capacity. These requirements are why
the public OSM endpoint remains development-only here. A production provider
must be selected after its current commercial terms, rate limits, attribution,
caching rules, and privacy requirements are reviewed.

For a release build, provide approved values without committing credentials:

```sh
flutter build apk --release \
  --dart-define=MAP_TILE_URL=https://approved.example/{z}/{x}/{y}.png \
  --dart-define=MAP_TILE_ATTRIBUTION='Approved provider attribution' \
  --dart-define=MAP_TILE_USER_AGENT='com.n1cxltine.sosapp'
```

If the selected provider requires a client-side key, inject it through the
provider's documented build configuration and restrict it by app identity,
platform, quotas, and allowed endpoints. Treat client-side keys as public;
never put privileged credentials in source control or logs. Release validation
must confirm `MapTileProviderConfig.current.isDevelopmentFallback == false` and
`isUsable == true`; a release must fail closed when these checks are false.
Attribution must remain visible on the map. Provider caching is subject to its
terms; this app does not implement offline tile downloading or background
prefetching. Incident and shared-location data are persisted independently of
tile availability, so coordinates remain reviewable when there is no network.

## Permissions and platform limits

- Android requires the Bluetooth runtime permissions declared for the target
  SDK (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, and `BLUETOOTH_ADVERTISE`) and
  may require location services for scanning on some OS/device combinations.
- iOS requires the Bluetooth usage description. Location permission is needed
  only for location capture and map current-location display.
- BLE foreground lifecycle, screen lock, process termination, and background
  delivery remain device/OS dependent and require hardware verification.

## Verification run for this phase

The current automated validation was run from the repository root:

```text
flutter test                         139 passed
focused BLE/location tests           55 passed
flutter analyze                      32 pre-existing info findings only
flutter build apk --debug            passed
flutter build ios --debug --no-codesign  passed
git diff --check                     passed
```

The analyzer findings are in `packages/flutter_nearby_connections_plus`; no
new app-code analyzer errors were introduced.

## Hardware acceptance matrix

Run with one controlled Android phone and one controlled iPhone, keeping logs
separate and excluding payloads, coordinates, credentials, and personal data.

| Scenario | Required evidence |
| --- | --- |
| Scan / advertise | Bluetooth and permission readiness, start callback, discovery |
| Connect / GATT setup | connection status, service/RX/TX discovery, notification readiness |
| SOS delivery | frame assembly, inbox persistence, positive ACK, sender acknowledgement |
| Chat delivery | matching chat ACK and one persisted message |
| Location delivery | explicit recipient, valid non-expired update, matching ACK |
| ACK loss / retry | same message ID and destination on retry; no duplicate record |
| Disconnect / reconnect | assembly reset, recoverable outbox, no stale callback |
| Permission revoked | clear failure state and no false Connected / Delivered state |
| Restart with pending data | local rows and outbox survive; retry remains bounded |
| Expiry / Stop Sharing | expired location is not sent or displayed as current |

Background delivery and process-terminated delivery are not acceptance claims
for this phase.

## Release blockers

1. Configure and validate a production-compliant map tile provider.
2. Complete Android ↔ Android and Android ↔ iPhone hardware BLE tests.
3. Capture evidence for service discovery, notification readiness, persistence,
   ACK correlation, retry, and reconnect behavior.
4. Decide and document OS background behavior before promising delivery while
   the app is suspended or terminated.

## Phase 7 acceptance update (20 October 2026)

Release acceptance is **blocked**. See `PHASE_7_RELEASE_VERIFICATION.md` for the
current matrix; the older automated totals above are historical results only.
Phase 7 adds two expected-success two-endpoint tests to the normal suite that
currently fail: default Chat uses an account owner ID where the receiver checks
a native Bluetooth peer ID, and default Location addresses a transport route
where the receiver expects a logical local owner ID. These are not physical
hardware results, and no wrong-peer guard has been removed to hide the failure.

Phase 7 fixes independently reproduced map release-guard and hidden-attribution
issues, and starts the BLE coordinator before the picker/debug page can create
a connection. Protocol, UUIDs, database schema and Firebase Rules are unchanged.
Live Firebase REST isolation/persistence checks with synthetic accounts pass;
that does not substitute for physical BLE or an app sync-queue trace. The user
also verified Android Guest visibility after Login, Logout, account B switching
and failed Login; original Guest SOS remains accessible in ข้อมูลในเครื่อง.
The active-detail Close defect was fixed and physically retested.
The map decision is free-only: Geoapify Free is the selected candidate within
its quota, pending an account-owned key, working attribution links and release
runtime validation. No paid plan is authorized and offline tile downloading is
not implemented. Physical BLE, signed debug deployment and signed release
status must each be read from the Phase 7 report, not inferred from a build.

Physical iPhone profile runtime is confirmed, but its initial scan attempt was
blocked after native BLE disposal. The native session reactivation/old-callback
isolation gate is open on both platforms; a process restart is only a diagnostic
workaround, not an accepted fix. See the Phase 7 native lifecycle evidence.

After devices reconnected, the existing synthetic Chat bubble was confirmed
Queued. A default-SOS reply-route defect is now fixed in source: the receiver
stores the observed peer in the existing inbox column and rejects replays from
other peers without ACK. Same-peer re-ACK and legacy-unbound records are covered
by regressions. Focused tests pass 72; full tests pass 169 with the same two
Chat/Location identity failures. Latest-source device deployment/retests and iOS
validation remain tracked separately in the Phase 7 report. No legacy peer
binding, owner, message payload or schema is automatically rewritten.

Latest reply-route builds now pass Android → iPhone physical SOS/application
ACK. The phase7-chat-02 physical reply reaches Android and retries with the same
ID, but receiver validation rejects the sender/native-peer identity mismatch.
Chat remains FAIL. Latest iOS unsigned debug build exits 0 after 1268.4s of
active gRPC/Firestore compilation; this was a slow build, not a proven hang.
Signed release and all unexecuted physical scenarios remain NOT RUN.


## Week 5 integrated continuation (20–22 October 2026)

Release remains **BLOCKED**. See `WEEK_5_BUG_LOG.md` and the Week 5 section of `PHASE_7_RELEASE_VERIFICATION.md` for current source fixes, historical physical evidence and open gates. This section supersedes older source-only identity/lifecycle statements without changing their historical test results.

Implemented explicit installation-ID/native-peer session binding for Chat/Location, selected incident route and author validation, native disposed-session reactivation/fencing, serialized AuthGate BLE teardown/startup, readiness snapshot replay, terminal ACK/Chat-state reconciliation and concurrent duplicate-content checks. No account ownership changes, Guest cloud merge, database migration, dependency, BLE UUID or framing changes. The additive capability message and old-peer fail-closed behavior are documented in the bug log. Device binding is not cryptographic authentication.

Location sharing waits for listener readiness, retains a stable delivery stream and provides live screen-reader status/48px controls with 200% text tests. Visible map attribution includes safe native HTTPS links. Android update continuity was physically confirmed; fixed Chat/Location and native-session recovery still await new physical acceptance. Old unbound records remain intact; explicit legacy recovery remains open. Free-only provider deployment, live app sync retry/expiry, unavailable second Android and signed release remain unverified. Frozen-source validation passes 203 full tests, 90 focused tests, analyzer, diff check, Android debug, signed iOS profile and unsigned iOS debug builds; exact exit codes and logs are in `validation/week5/command-results.json`.

## Final Phase 7 acceptance update — 22 October 2026

Final physical acceptance passes Android↔iPhone SOS and Chat in both directions
with application ACKs and exactly one receiver record. Android→iPhone Location
passes two updates, persisted ACKs, verified shared-location presentation and
Stop = Off. Guest data remained accessible after restart/login/logout/account
switching without ownership transfer or automatic Guest cloud sync.

Final source validation passes 206 tests and 46 focused tests; analyzer,
Android debug, signed development iOS profile, unsigned iOS debug, doctor and
diff checks exit 0. Xcode 26.6 completed the unsigned debug build in 260.3s.
Signed release remains NOT RUN.

Release remains blocked by Android↔Android testing (second Android absent),
controlled real-radio ACK-loss/wrong-peer/close-while-pending tests, the complete
iPhone permission matrix, a configured/live-tested free production map provider
and signed App Store/release validation. Geoapify Free remains a candidate;
public OSM stays blocked in release and offline tiles are absent.

## Reliability/range continuation — 22 October 2026

The durable queue now has an integration regression across a real file-backed
database/coordinator restart, preserving one row and the same message ID. The
existing delayed/lost ACK, wrong-peer, duplicate and stale-callback regressions
remain enabled. Full tests pass 211; focused BLE reliability/range tests pass
117; analyzer, Android debug and unsigned iOS debug builds exit 0.

The new BLE quality diagnostic is debug-only and uses application ACKs rather
than native write completion for PDR. It reports latency/timeouts/reconnects and
only the scan-time RSSI exposed by the native bridges. Physical 5–50 m runs are
NOT RUN and no range claim is made. LoRa remains a documented hardware-backed
future option only; no production transport, dependency, schema, UUID or rules
changed. All release blockers listed above remain open.

## Phase 8 preparation — 22 October 2026

`PHASE_8_PHYSICAL_TEST_RUNBOOK.md` now defines prerequisites, exact execution,
logs, pass/fail and cleanup for controlled production ACK loss, wrong-peer ACK,
close-while-pending, process restart/reconnect, Android↔Android, iOS Bluetooth
permission recovery and 5–50 m open/obstructed range runs. The machine currently
detects no Android; iPhone wireless discovery fails host connection with code
-27. All new physical rows therefore remain NOT RUN.

Automated validation passes: focused reliability/range/ownership 138, full 211,
analyzer, Android debug build, unsigned iOS debug build and diff check all exit
0. The initial focused command exited 1 only because it named a nonexistent test
file and was corrected without suppressing tests. No production code or
dependency changed in Phase 8 preparation. Release remains blocked by the
physical fault/range matrix, Android B, production map configuration and signed
release validation.

## Phase 8.1 environment recovery — 22 October 2026

The iOS host blocker is resolved for the active iPhone 15 Plus: CoreDevice and
Xcode report iOS 27.0.1 paired, Developer Mode enabled, tunnel connected and
available as a Runner destination; app 0.1.0+1 is installed. Flutter's `-27`
message is attached to a separate unavailable iPhone 13 record with the same
display name. No pairing reset is justified.

Android remains absent from an unrestricted ADB inventory, so close-pending,
restart/reconnect, iOS permission recovery with peer ACK, Android↔Android and
range tests remain NOT RUN. No physical PASS was inferred. Focused 138 and full
211 tests, analyzer, Android debug and unsigned iOS debug builds exit 0 in the
Phase 8.1 rerun. A physical ACK-suppression control is not added while endpoints
are unavailable; the runbook records a one-shot debug-only design gate. Release
remains blocked by the physical matrix, a production map configuration and
signed release validation.

## Phase 9 release preparation — 22 October 2026

Repository-only audit fixed three release configuration defects without
changing BLE, ownership, schema, Firebase Rules or dependencies. Injected
`MAP_TILE_*` values are now read as compile-time constants; Android main now
declares Internet access; and Android release no longer uses the debug signing
key. An unconfigured release task fails closed and no signed artifact is
claimed.

Geoapify Free remains the free-only production candidate, but no account-owned
key is available. Public OSM remains rejected in release and offline tiles are
not implemented. The exact owner actions, severity/remediation assessment and
current signing prerequisites are in `PHASE_9_RELEASE_READINESS.md`. The single
planned hardware session is in `PHYSICAL_TEST_SESSION_CHECKLIST.md`.

Final Phase 9 automated rerun passes 102 focused and 211 full tests, analyzer,
Android debug and unsigned iOS debug builds. Synthetic map config passes 5
tests. Signed Android/iOS release, live map, forced live auth expiry and all
remaining Phase 8 physical cases remain NOT RUN. Release Gate stays BLOCKED.

## Role-based UX — 23 October 2026

The app now has an explicit, locally persisted Need Help / Rescue choice with a
Calm & Decisive Light/Dark interface. Switching roles does not modify incidents,
ownership, BLE identity or durable delivery queues. Rescue lists only durable
BLE incidents that also belong to the current repository scope. Rescue accept
is clearly local, idempotent session state and does not claim exclusive or human
acknowledgement. Need Help prevents duplicate own active incidents while an
inbound incident does not block creating an SOS.

Focused Role/Guest/BLE tests pass 35, full tests pass 220, analyzer exits 0,
and Android debug plus iOS debug no-codesign builds exit 0. Physical role
journeys are NOT RUN for this UI change. See
`ROLE_BASED_UX_AUDIT.md` and `ROLE_BASED_UX_VALIDATION.md`. Release remains
BLOCKED by the existing physical, production-map and signed-release gates.

## Phase A2 role verification — 23 October 2026

A rapid repeated-action race was found and fixed: SOS submission now acquires
its in-flight guard before asynchronous active/inbound checks. Regression tests
also preserve the active incident, Chat row and queued SOS/Location states over
Need Help ↔ Rescue switching; verify Rescue owner scoping and accept
idempotence; and cover Light/Dark/System contrast and status meaning.

Focused Role/Auth/BLE/Chat/Location/Map tests pass 156, full tests pass 224 and
`flutter analyze lib test` exits 0. Android debug, iOS unsigned debug and iOS
development-signed debug builds exit 0. Android and iPhone current debug builds
were installed update-in-place and launched, but no fresh coordinated BLE test
was executed, so every physical behavior row remains NOT RUN. Full repository
analysis still exits 1 on 32 `info` findings confined to the vendored
nearby-connections package/example.

Android release signing remains fail-closed (expected exit 1, no AAB). Owner
identity decisions, account-owned Android/Apple distribution signing,
account-owned Geoapify runtime configuration, live Firebase recovery and the
physical matrix remain incomplete. See `PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md`
and `PHASE_A2_RELEASE_BLOCKERS.md`. Release Gate remains **BLOCKED**.

## Android identity migration implementation — 24 October 2026

Android source/configuration now targets `com.n1cxltine.sosapp`. The existing
Firebase project contains separate Android registrations for the old and target
packages, and the checked-in Android configuration retains both clients. The
generated Android Firebase options and mappings select the target registration;
iOS Firebase configuration is unchanged.

Static identity/config checks, 6 map-provider tests, 14 Incident Map tests, 224
full tests, `flutter analyze lib test`, and the Android debug build pass. The
generated Google Services resources select the target client, the merged
manifest resolves the launcher to `com.n1cxltine.sosapp.MainActivity`, and the
debug APK reports the target application ID. No Android device was connected,
so installation, coexistence with `com.example.sos_app`, empty target sandbox,
Firebase runtime/Auth/Firestore, BLE permissions/identity, restart persistence,
and target-to-target update behavior remain NOT RUN. Signed releases and live
production-map validation also remain NOT RUN; Release Gate stays **BLOCKED**.

## Signing-independent Phase 7 continuation — 27–28 October 2026

W5-07 legacy queued-Chat recovery is now implemented without changing Apple or
Firebase identity, BLE framing/UUIDs, ownership or schema. An outgoing
queued/failed Chat with no durable destination presents an explicit recipient
action in the incident Chat. The selected route is applied transactionally only
to Chat rows in the current owner/incident scope; message ID, payload, sender
and owner are preserved, and routed or other-owner rows cannot be redirected.
The app never selects a peer from login, replay or whichever device connects.

Focused repository/widget tests pass 29, the full suite passes 331,
`flutter analyze lib test` reports no issues and `git diff --check` exits 0.
Physical recovery from a real retained legacy row is NOT RUN. Production map
configuration, remaining physical reliability/range cases and signed release
validation remain blockers. iOS signing/identity migration remains external and
was not changed by this continuation.

The follow-up recovery race audit confirms that owner, incident, Chat kind,
queued/failed state and missing destination are enforced transactionally.
Concurrent selections cannot redirect the winner, in-flight delivery is
excluded, and an assigned same-ID payload remains due after database restart.
It also found and fixed W5-14: SOS Details previously watched the oldest outbox
row for an incident without filtering message kind, so an older Chat row could
be presented as SOS delivery status after reconciliation. The watcher now emits
only a validated `sos.delivery` row. Current focused tests pass 33, the full
suite passes 335, analyzer reports no issues and `git diff --check` passes.
These are automated results; physical Chat recovery and status revalidation
remain **NOT RUN**, and the Release Gate remains **BLOCKED**.

## SOS ACK and Location correlation continuation — 28 October 2026

The ACK repository boundary is now fail-closed when the observed native source
peer is absent: both SOS and Location require the persisted destination to match
the non-empty source peer as well as the existing message/kind/incident checks.
An ACK for another message or peer cannot confirm the selected row, native write
completion still does not imply receipt, and terminal acknowledged state remains
monotonic. Receiver deduplication and stable retry message identity are unchanged.

SOS and Location status text also separates a scheduled retry from a terminal
failed attempt with no `nextRetryAt`; the latter is no longer presented as
automatically retryable. The pre-fix peerless-ACK regression command exited 1
with two intended failures. After the fix, focused SOS/Location/BLE/UI tests pass
126, the full suite passes 341, `flutter analyze lib test` reports no issues and
`git diff --check` passes. Physical wrong-peer ACK, controlled ACK loss/retry,
duplicate delivery and current-build Android/iOS interoperability remain
**NOT RUN**. Signing and production map validation also remain incomplete, so
the Release Gate remains **BLOCKED**.

## Release and physical Relay execution gate — 28 October 2026

Current automated validation passes 165 focused Relay/ACK/migration/lifecycle
tests and 341 full tests; `flutter analyze lib test` and `git diff --check` exit
0. These results include simulated A→B→C forwarding but are not device evidence.
No new source defect was reproduced after the W5-15 ACK hardening.

Android Release signing fails closed with exit 1 because no owner-controlled
keystore or `android/key.properties` is configured, and no Release APK/AAB was
created. The current debug APK (`com.n1cxltine.sosapp` 0.1.0+1) matches the
installed debug certificate and was installed update-in-place on the connected
SM-A536E; installation and launch exit 0. Existing app data was not uninstalled
or cleared. This debug deployment is not a Release candidate.

The iPhone 15 Plus and iPad Air 11-inch (M2), both on iOS/iPadOS 27.0.1, are
paired and available with Developer Mode enabled. The Team `78GZXS97G6`
development profile matches the Bundle ID and both device UDIDs, but no matching
Apple Development identity/private key exists on this Mac. The available
identities belong to Team `ZZ6WC9ADGQ`. An unsigned iOS Release compile succeeds,
but the resulting Runner.app is explicitly unsigned, was not installed and is
not a signed artifact. CoreDevice reported both intended devices paired and
available with Developer Mode enabled, while their tunnel state was unavailable;
installation connectivity must be rechecked after signing is restored.

Consequently Android↔iPhone, Android↔iPad, iPhone↔iPad and the controlled
A→B→C physical Relay route are **NOT RUN / BLOCKED** for the current build. A
three-device PASS still requires proof that A cannot contact C directly, B
durably persists before its hop receipt, B actually forwards, C stores exactly
one logical message and the protocol evidence shown at A is accurate. Production
map configuration is also absent. The Release Gate remains **BLOCKED**.

## One-tap emergency orchestration — 31 October 2026

The critical SOS path now persists one incident, opens that incident's Chat
immediately, and starts eligible nearby work without showing Relay Options or a
BLE recipient picker. Emergency-origin Public Relay and optional incident
location are configured beforehand in Settings, stored through a common
Android/iOS native preference contract, default to OFF, and remain distinct
from the switch that volunteers a device to forward other people's messages.
Location is not requested or included without the separate saved choice.

Public Relay v2 enqueue is durable before discovery is started. Chat navigation
does not wait for scan, proof, connection, hop receipt or application ACK.
Status text distinguishes local persistence, searching, application ACK,
relay storage and final delivery; a relay hop receipt is never labelled final
delivery. Existing incident/message identity, retry, deduplication and ACK
correlation behavior is preserved.

There is no safe automatic Direct v1 responder selection in the current
protocol. The authenticated peer binding identifies an installation session,
but it does not prove responder authorization or acceptance for an incident.
The implementation therefore does not guess the first BLE device and does not
redirect legacy unrouted rows. Such work remains persisted and waiting unless
a trustworthy route exists. A future direct-auto route requires an explicitly
approved responder capability/trust design and compatibility review.

Current validation: `flutter test --reporter compact` passes 373 tests (exit
0), `flutter analyze lib test` reports no issues (exit 0), and
`git diff --check` passes. On 1 November 2026 the signed Profile build was
installed update-in-place on an iPhone 15 Plus with the existing Team, Bundle
ID and application data preserved. Physical one-tap UX passed: one incident was
persisted, Chat opened immediately, no Relay Options or recipient picker was
shown, and no duplicate was created. History card-to-Chat, the separate Details
action, compact filters and search passed. A follow-up active-incident hold also
kept its banner stable without flicker or overlap, created no additional SOS
and opened the existing Chat.

This device evidence validates the iPhone interaction and persistence path; it
does not prove BLE delivery, a final receipt or Relay forwarding. Automatic
A→B storage, controlled B→C forwarding and direct responder routing for this
build remain **NOT RUN / NOT VERIFIED**. Production map, signed Android Release
and three-device Relay evidence remain blockers; the Release Gate is
**BLOCKED**.
