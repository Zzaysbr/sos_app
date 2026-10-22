# Offline SOS release readiness

Current gate: **BLOCKED**. Android↔iPhone SOS and Chat pass both directions, and foreground Location passes initial/subsequent delivery, persisted ACK, map presentation and Stop on the tested devices. Remaining blockers are listed below. Integrated evidence is in [WEEK_5_BUG_LOG.md](WEEK_5_BUG_LOG.md) and [PHASE_7_RELEASE_VERIFICATION.md](PHASE_7_RELEASE_VERIFICATION.md). Historical checklists below are retained.

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
  --dart-define=MAP_TILE_USER_AGENT='com.example.sos_app'
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
