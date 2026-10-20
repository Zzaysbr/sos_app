# Phase 7 — End-to-End Release Verification

Date: 20 October 2026 (Asia/Bangkok). **Release gate remains BLOCKED.**

**Current source update:** see [Week 5 bug log](WEEK_5_BUG_LOG.md) and the continuation section below: 203 automated tests pass; final focused/build refresh is pending; analyzer and Android debug build pass. Older failure sections/matrix retain historical hardware results. Fixed Chat/Location physical acceptance and current iOS builds remain pending.

This report distinguishes real-device actions, live Firebase REST requests, SQLite/widget tests and build results. A successful test using fake radios is never a physical BLE PASS. A successful debug build is never a signed release PASS.

## Preflight

Read the current readiness checklist, Phase 6.3 audit and its complete iOS log plus validation logs. Phase 6.3's simulator command exited 0; it did not validate physical delivery. Existing modified/untracked files were preserved. No schema, UUID, BLE protocol or Firebase Rules changes are made in Phase 7.

Reviewed the Dart transport, coordinator, delivery repository, frame assembler, ownership/sync filters and map configuration, plus native Android/iOS connection readiness. Both native implementations use the same service/RX/TX UUIDs. Android waits for CCCD/notification readiness and iOS waits for `didUpdateNotificationState`; a native write is not an application ACK. The coordinator permits complete duplicate messages through the assembler so persistence deduplication can re-ACK them. Drift primary keys and transaction checks provide message idempotency. Explicit destinations and ACK kind/SOS/message/peer correlation remain required.

Account History is the current owner’s **local cache**, including pending/synced rows. `SosCloudService` does not implement a Firestore history download/list subscription. Device UI isolation and live Firestore authorization therefore remain separate evidence; REST-created fixtures are not expected to appear automatically in app History.

Initial blockers: physical Android/Android and Android/iPhone acceptance evidence absent; live test accounts not yet authorized; production tile provider unset; background/terminated behavior unverified; no signed release validation. During this phase the user authorized synthetic A/B accounts in the existing Firebase project, confirmed one Android and one iPhone and required **free-only maps**.

## Devices and physical matrix

| Alias | Hardware | OS | Observed state |
| --- | --- | --- | --- |
| Android A | Samsung Galaxy A53, SM-A536E | Android 14 | ADB-connected; debug APK installed with `-r` preserving app data; app process launched |
| Android B | Not available | Unknown | NOT RUN: user has one Android only |
| iPhone | iPhone 15 Plus | iOS 27.0.1 | USB-connected, paired, Developer Mode enabled; signed debug launch failed; profile build/install succeeded and process launch and visible runtime confirmed; initial BLE scan blocked after native dispose |

A remembered iPhone 13 entry and iOS simulator are not test endpoints. Device serial numbers/UDIDs, credentials and personal coordinates are excluded from this report.

| Required physical scenario | Direction | Result | Evidence / reason |
| --- | --- | --- | --- |
| Android advertising preparation | Android A peripheral | PASS | User confirmation and native onStartSuccess / state=advertising |
| iPhone advertising preparation | iPhone peripheral | PASS | User confirmation and native didStartAdvertising error=none |
| Initial iPhone discovery attempt | iPhone scans Android A | FAIL / BLOCKED | User saw no peer; native log shows requestPermissions after dispose, with no startDiscovery call; fresh-process retest passes separately |
| Fresh-process iPhone discovery | iPhone scans Android A | PASS | User found Android; native startDiscovery accepted, then didDiscover Galaxy A53 5G; discovery only |
| GATT connection / notification readiness | iPhone central → Android A peripheral | PASS | User saw connected / GATT ready; native service/RX/TX discovery, notifying=true and transport ready on attempt 2; not application ACK |
| SOS + application ACK | Android A → Android B | NOT RUN | Second Android unavailable |
| Reverse SOS + ACK | Android B → Android A | NOT RUN | Second Android unavailable |
| SOS + application ACK | Android A → iPhone | PASS | User confirmed exactly 1 new SOS on iPhone and Confirmed received on Android; sender log correlates enqueue/send/writeAccepted/acknowledged persisted on same message and peer |
| New-source SOS + application ACK retest | Android A → iPhone | PASS | Updated reply-route builds: user confirmed 1 new SOS and sender Confirmed received; same-ID/peer persisted ACK at 22:21:16.226 |
| Initial SOS sender confirmation | iPhone → Android A | FAIL / UI observation | User initially saw new SOS on Android but iPhone awaiting/failed; original native return notifications present |
| Original SOS delivery + persisted confirmation after reopen | iPhone → Android A | PASS with timing limit | User later opened the same SOS and saw Confirmed received after update/reopen/reconnect; Android original persisted/ackSent evidence; immediate confirmation timing unresolved |
| Offline Chat first reply attempt | iPhone → Android A, latest Android-origin SOS | FAIL | User confirmed existing phase7-chat-01 bubble remains Queued after reconnect; no receiver/ACK trace. Default reply route fixed/deployed for new records; original unbound Queued fixture preserved; identity blocker separate |
| New-source Chat reply / application ACK | iPhone → Android A | FAIL | phase7-chat-02 reaches Android and assembles, then rejected for declared-sender/native-peer mismatch; user reports no received message and sender awaiting/failed |
| Chat retry attempts / stable message identity | iPhone → Android A | PASS (attempts only) | Five complete receptions of same message ID after identity rejection; no successful delivery, controlled ACK-loss, dedup or reconnect claim |
| Reverse Chat / persistence / ACK | Android A → iPhone and restart retention | NOT RUN | No completed physical sequence |
| Location initial/newer/stop | Android A ↔ iPhone | NOT RUN | No physical application trace; deterministic recipient-identity defect reproduced separately |
| Duplicate / ACK loss / bounded retry | Both directions | NOT RUN | Requires controlled real-radio replay/ACK suppression; unit evidence below is separate |
| Disconnect/reconnect pending outbox | Both directions | NOT RUN | No physical persistence/reconnect/ACK evidence yet |
| Wrong peer / wrong sender | Both directions | NOT RUN | Automated rejection tests are not a hardware injection test |
| Restart during pending delivery | Both directions | NOT RUN | File-backed SQLite restart tests pass separately; no real process-restart delivery trace |
| GPS unavailable during Guest SOS create | Android A | PASS | User disabled GPS and observed SOS creation without coordinates; local layer only |
| Bluetooth off / scan failure / retained Guest SOS | Android A | PASS | User disabled Bluetooth, scan reported off/unavailable and original Guest SOS still opened |
| Nearby devices permission denied | Android A | PASS | User denied permission, BLE Test reported permission problem, Guest SOS remained accessible; permission restored |
| Permission denied / Bluetooth off | iPhone | NOT RUN | App runtime/physical sequence not completed |
| GPS unavailable | iPhone | NOT RUN | App runtime/physical sequence not completed |

Physical runbook: `validation/phase7/DEVICE_TEST_RUNBOOK.md`. Real-device logs/observations will update this table only when completed.

## Defects reproduced

### Fixed: explicit public OSM URL bypassed release guard

`isDevelopmentFallback` only identified the absence of a URL. Supplying `tile.openstreetmap.org` explicitly set the flag false and passed release validation. The new test failed before the fix (exit 1). Release validation now rejects the public host and its subdomains, including case/trailing-dot variants, independently of that flag. Debug behavior is retained. The environment test also passes when the OSM URL is supplied through actual `--dart-define` values with no keys.

Evidence: `map-guard-before-fix.log`, `map-explicit-osm-environment.log`, `map-focused.log` under `validation/phase7/`.

### Fixed: attribution text hidden behind a closed popup

The existing `RichAttributionWidget` started closed. A widget test asserting visible provider credit failed (exit 1). Map credit text now remains visible and wraps in an always-visible panel. No new dependency was added. Provider-specific outbound attribution hyperlinks are **not yet implemented**; complete them before approving a provider that requires links.

Evidence: `map-attribution-before-fix.log` and `map-focused.log`. Tests cover provider error and network-loss callbacks, retained incident marker/coordinates and retry tile-layer replacement. They do not contact a real provider.

### Fixed: BLE coordinator subscribed after connection

The recipient picker could establish the native connection before `onBleStartRequested` was invoked after SOS creation. A broadcast `connected` event could therefore be lost; a later `connect` meets the native busy/already-connected guard. The debug advertising workflow likewise initialized native BLE without starting the application coordinator. A regression reproduced the debug-screen order failure. Both entry points now wait for coordinator startup before entering the picker/debug route, while startup exceptions still permit the local SOS flow. Startup-order regression tests pass after the fix. No native transport or wire-format changes were made.

Evidence: `ble-start-order-before-fix.log` and `ble-start-order-after-fix.log`. The initial hold-button test was corrected to use the actual History Send SOS action because the hold timer uses wall-clock `DateTime.now()`; only the corrected test is used for final validation.

### Open release blocker: default Chat sender uses account identity as radio identity

In `enqueueChat`, the default `senderDeviceId` is `ownerId`. On receipt `_onFrame` compares a declared sender against the native transport peer ID. These are different namespaces: Firebase UID/device Guest namespace versus Android Bluetooth address/iOS peer UUID. A sender using the application's default arguments and a receiver observing a distinct real-style transport route produces `BLE envelope sender does not match the transport peer`, no receiver Chat row and no positive ACK.

### Open release blocker: default Location recipient uses route as owner identity

`publishLocationUpdate` uses the selected native destination as `recipientId`; the receiver requires `_localDeviceId`, which defaults to its account owner ID. Two endpoints therefore reject a valid intended update with `Location update has the wrong recipient`. Default sender identity also requires an explicit mapping before it can be compared safely to the observed peer.

These two expected-success release tests are retained in **`test/ble_identity_release_gate_test.dart` and included in ordinary `flutter test`**, with no skip/expected-failure annotation. They currently FAIL and block release. Existing single-endpoint tests mostly construct matching synthetic identities; they do not establish real cross-platform identity compatibility. No peer check was removed. A safe correction needs an explicit, tested logical-identity/transport-route binding; changing or guessing that binding during acceptance testing without cross-platform evidence would risk wrong-peer acceptance. No such architecture/protocol change is claimed here.

### Open release blocker: native BLE remains disposed across a Dart session replacement

After visible iPhone profile runtime was confirmed, the user could not discover Android. Android native logs confirm successful advertising. iPhone logs show `dispose`, followed by new `requestPermissions` calls and **no** `startDiscovery`. Inspection confirms the Swift bridge rejects every method except `initialize` while disposed, and `initialize` does not clear `disposed`; the coordinator requests permissions before initialization. Android also leaves its native `disposed` event-suppression flag set until bridge registration. This is a session-lifecycle defect, not evidence of a changed service UUID or an on-air scan failing. A process restart retaining app data is being used to isolate the issue for a physical retest; the fresh-process retest now passes discovery: the user found Android and native logs confirm `startDiscovery accepted` followed by `didDiscover` for Galaxy A53 5G. The user then confirmed GATT ready; native logs show matched service/RX/TX, notification subscription and ready on manual attempt 2. Evidence: `iphone-gatt-sanitized.log`. This confirms discovery/connection after the restart workaround only, not session-transition recovery or application delivery. The first connection attempt did not reach ready before a manual retry; no automatic reconnect success is claimed. Sanitized evidence: `validation/phase7/ble-session-lifecycle-sanitized.log`; the regression procedure is recorded in the device runbook and has not closed the blocker. No identity checks or cleanup guards have been weakened. Safe reactivation must also serialize old-session teardown and reject stale callbacks across owners before a lifecycle correction can be accepted.

### Open observation: initial SOS sender state, later persisted confirmation

On the controlled offline Guest iPhone → Android test (location permission denied), the user observed a new SOS on Android while the iPhone remained awaiting confirmation/failed. Android logs show validated/persisted `duplicate=false` and `ackSent status=persisted` for the same message. Native iPhone logs show notification callbacks during that ACK. This initial observation is retained as **FAIL for the immediate sender confirmation check**, despite successful receiver persistence and native return traffic; later confirmation evidence below is recorded separately. Exact UI record count was not supplied. Root cause is still under investigation; profile builds previously disabled coordinator diagnostics. Phase 7 now enables existing coordinator metadata logs in debug/profile while keeping release logging disabled. The first diagnostics build failed due to a syntax typo; it is retained in `ios-profile-ack-diagnostics-build.log` and the corrected profile build exited 0 (26.9s), installation exited 0 and process launch was confirmed. Corrected-source full tests still report 165 pass / 2 existing identity failures; analyzer exits 0. Latest-source Android debug and unsigned iOS debug builds now exit 0 (iOS 391.0s); focused BLE/ownership/SOS regressions pass 68 tests. The user then confirmed the **original SOS** shows `Confirmed received` after update/reopen and reconnect. Android recovery logs contain only the original persistence/ACK; the new iPhone console shows connection setup without a new notification sequence. Thus final persisted sender confirmation is observed, but an actual retransmission/re-ACK is **not proven**. Do not count this as controlled ACK-loss/retry PASS or claim the initial UI/timing discrepancy was fixed. No wire-format/UUID/ownership/schema/rules change was made. Evidence: `android-sos-ack-sanitized.log`, `iphone-sos-ack-sanitized.log`.

### Physical Android observations during this phase

The user created a Guest SOS on Galaxy A53 with GPS disabled and reported that the SOS appeared without location. This is an observed **PASS for local creation / no-GPS fallback only**. The app log confirms one new SOS outbox entry in `queued`; no selected peer or application ACK is present. Native logs show activity/Flutter-engine reinitialization. The exact new-row count was not supplied. The user subsequently confirmed all Guest records remain visible after updating/reopening the app: **PASS for physical local continuity**, without claiming a pending delivery/ACK restart test.

The user also reproduced a real UI defect: active SOS Details had no explicit exit button. The original sheet only showed its bottom Close action for non-active/read-only records. A header × action now closes every detail state. Corrected widget tests open the normal active detail, assert the close action is hit-testable and return to the app; detail/startup focused tests pass (4 tests). The updated APK was installed preserving existing app data. **Physical retest PASS:** the user confirmed the × button closes the sheet and existing Guest records remain intact. Initial close-test attempts did not reach the off-screen Home card; the final test uses the rendered History card and is the acceptance evidence.

After Login A, the user first reported missing Guest SOS while viewing account History. On opening the separate **ข้อมูลในเครื่อง** page, the user confirmed the original Guest SOS remains and opens. This is a **physical PASS for Guest visibility after Login**, not proof of device-to-Firestore sync behavior. The user then confirmed A history is hidden after Logout and Login B, with the original Guest SOS still opening in both stages. **Physical UI isolation PASS**; live sync/ownership correlation remains separate.

Evidence: `android-physical-sanitized.log`, `android-guest-observation.json`, `sos-detail-and-startup-after-fix.log`. No personal coordinates or payload contents are included.

### Fixed in source: default SOS did not retain its observed reply peer

Normal `enqueueSos` envelopes omit the optional `senderDeviceId`. The receiver previously stored that optional field directly in `ble_inbox.senderDeviceId`; `lookupReplyDestination` therefore returned null, so a Chat reply without an explicit picker destination could stay queued. My earlier physical-test instruction assumed this fallback already worked; it did not for the default SOS path. This code defect is reproduced in regression tests; the user confirmed the original physical bubble remains Queued, but its database route was not directly inspected.

The coordinator now passes the observed transport source into inbox persistence. New records retain that route in the existing column without changing payload, message ID, owner, schema, UUIDs or wire format. Persistence binds the original observed peer transactionally. Replays from another peer receive no application ACK, including concurrent duplicates; same-peer duplicates still re-ACK with one SOS/inbox row. Legacy inbox entries with no recorded source remain unbound and are not assigned a peer from a replay. Existing legacy Chat/SOS entries are preserved; this fix does not automatically repair their missing destination.

Two acceptance tests failed before the fix (missing route and an ACK to another peer). Four new regressions cover the default route, concurrent wrong-peer replay, same-peer re-ACK/idempotency and unchanged legacy binding/owner. Focused tests pass **72**. Latest full tests report **169 passed / 2 existing identity failures** (exit 1); analyzer and Android debug build exit 0. Signed iOS profile build exits 0 (463.7s), installation exits 0 and process launch is confirmed; unsigned debug validation also exits 0 after 1268.4s of active native compilation. The Android APK has been installed with `-r` and launched (exit 0). The user confirmed the original SOS remains, Details opens, and its stored `Confirmed received` state is retained: **physical data/ACK-state continuity PASS after update**, not a new transmission PASS. iPhone profile build/install now exit 0 and process launch is confirmed. The updated builds subsequently passed Android → iPhone SOS/application ACK: user confirmed one new receiver SOS and sender Confirmed received; sender log correlates enqueue 22:21:08.716 → send 22:21:08.906 → writeAccepted 22:21:15.974 → persisted ACK 22:21:16.226 (Asia/Bangkok). New-source Chat routing subsequently reached Android, but end-to-end Chat failed the identity check; no Chat delivery/wrong-peer/dedup hardware PASS is inferred. Evidence: `reply-route-before-fix.log`, `reply-route-after-fix.log`, `focused-reply-route.log`. Existing Chat sender-ID and Location identity release gates remain separate and unresolved.

### Physical Chat attempt blocked; root cause not yet assigned

The user attempted a single synthetic reply on the latest Android-origin incident from iPhone and reported Queued or unable to send. The UI route used Continue without recipient only for the existing incident’s stored reply route; this does not establish that a destination was actually resolved or frames were sent. At the next diagnostic read, adb reported no connected Android device. USB reconnection and the exact UI bubble/error were requested. The user subsequently confirmed that reconnecting the devices is currently unavailable; further physical diagnostics are blocked by device access. No new receiver log, Chat persistence or ACK PASS is claimed, and this physical observation is not automatically attributed to the separately reproduced sender/peer identity defect. No resend or new SOS was requested.

### Physical confirmation of the Chat identity blocker after route fix

On updated builds the user sent exactly one synthetic `phase7-chat-02` reply on the new Android-origin incident, using its stored reply route. The user reported Android received no message and iPhone remained awaiting/failed. Android logs show complete Chat assembly at 22:22:40.686, followed by `BLE envelope sender does not match the transport peer`. The same message ID is reassembled and rejected at 22:23:13.156, 22:23:43.195 and 22:24:13.124, with a fifth complete attempt at 22:24:43.231 (Asia/Bangkok). This proves the default reply route now transports the message to the receiver and automatic retry retains message identity. It also physically reproduces the separate sender/account versus radio-peer identity defect already covered by the retained failing release test.

**Chat end-to-end FAIL.** No receiver record/positive ACK success is inferred. Rejection-induced retries are not a controlled ACK-loss, successful deduplication, or disconnect/reconnect test. No identity guard was removed. Evidence: `android-chat02-sanitized.log`, `chat-physical.json`. The old `phase7-chat-01` remains a separate preserved Queued fixture.

### Physical Android → iPhone SOS/application ACK PASS

With both devices Guest/offline, Android GPS off and iPhone advertising, the user confirmed exactly **one** new SOS on iPhone and `Confirmed received` on Android. Sender native/application evidence correlates the same message and selected peer: enqueue 17:27:58.631 → send 17:27:58.798 (74 frames) → write accepted/awaiting ACK 17:28:03.942 → `acknowledged status=persisted` 17:28:04.154 (Asia/Bangkok). This is actual application ACK evidence, not just GATT write acceptance. No controlled retry, duplicate injection or ACK-loss claim is inferred. Evidence: `android-reverse-sos-sanitized.log`, `iphone-reverse-sos-sanitized.log`, `ios-profile-device.json`.

## Guest / Firebase results, by layer

| Layer / case | Result | Evidence and limit |
| --- | --- | --- |
| Local SQLite Guest create/reopen; ownership/queue unchanged after login/logout/A-B switch | PASS | File-backed Guest continuity and scoped repository tests; mocked Firebase session state |
| Local SOS/BLE duplicate persistence, stable message ID, stale recovery and reconnect policy | PASS | Focused repository/coordinator/assembler tests using fake radio events and SQL, not physical BLE |
| Live controlled accounts A/B registration and sign-in | PASS | Firebase REST responses, synthetic emails, no real personal data |
| Live Firestore A/B persistence and own-document reads | PASS | Exact synthetic document IDs, successful writes then GETs |
| Live A↔B read/update/delete isolation and forged-owner create | PASS | Both directions denied with HTTP 403 |
| Unauthenticated Guest cloud read/create | PASS | Authorization denied |
| Logged-in token trying to create a record retaining Guest owner | PASS | HTTP 403; no ownership transfer permitted |
| Failed login then controlled sign-in/account switch | PASS | REST auth error then valid controlled sign-ins and own-document reads |
| Invalid-token cloud failure followed by authorized retry | PASS | REST rejection then successful GET; not an app network-loss sync-queue test |
| Physical Android Guest offline SOS / GPS-off / update-reopen continuity | PASS | User observed local SOS creation, no GPS coordinate, and retained records after reopening; sanitized queue log corroborates creation |
| Physical Android active SOS detail close | PASS | Initial user-reported failure fixed and retested successfully on the device |
| Physical Android Guest → Login A, local visibility | PASS | User initially saw only A on History, then entered ข้อมูลในเครื่อง and confirmed original Guest SOS remains and opens; no ownership transfer inferred |
| Physical Android Logout / Login B isolation | PASS | User confirmed A history absent after Logout and Login B, and original Guest SOS opens in both stages; UI visibility evidence only |
| Physical Android failed Login / exit | PASS | User intentionally entered wrong controlled password after Logout, returned to app, Guest remained accessible and A/B history absent |
| Observed offline Guest SOS absent from A/B cloud after app Login | PASS (snapshot) | Exact observed SOS ID + controlled owner queries both returned HTTP 200 / 0 documents after physical Login A/B; not a full outbound-network trace |
| App cloud sync failure / queue retry on device | NOT RUN | REST invalid-token retry passes separately; no controlled app network/auth failure with durable queue evidence |
| Real auth-session expiry during app use | NOT RUN | Local auth-state regression tests are separate; no observed real expired-session sequence |
| BLE delivery of original Android Guest/auth test SOS | NOT RUN | That earlier no-recipient SOS is separate from the later iPhone → Android physical fixture |
| iPhone SOS retention across profile update/reopen | PASS (user observation) | User reopened the original SOS and observed Confirmed received; exact record-count/SQL ownership inspection not performed |

`validation/phase7/live-firebase.json` records **27 PASS / 0 FAIL** live REST checks. After the user-observed app Login A/B sequence, `guest-cloud-after-login.json` adds **2 PASS** narrowly scoped live queries: the exact observed offline SOS ID is absent from both controlled owners’ Firestore histories at the time of inspection. This does not establish a complete traffic trace or rule out later writes/changed IDs. Only new synthetic accounts/documents were created/read; no existing account's data was read. Credentials/tokens remain in mode-0600 temporary files outside source control and are never printed to validation logs. Synthetic test accounts/documents are retained for the ongoing physical checks; cleanup has not been performed or claimed.

## Free-only production map decision

**Selected candidate: Geoapify Free, raster `osm-carto` style. Activation/production approval remains blocked**, pending an account-owned API key, complete attribution links, usage/rate controls and a release-artifact runtime check. No paid subscription or automatic upgrade is authorized; no key is committed or logged. MapTiler paid tiers are excluded by the user's free-only requirement. OpenFreeMap would require changing the current raster renderer; no renderer architecture change was made.

- Geoapify's [pricing](https://www.geoapify.com/pricing/) permits free production/commercial use within plan limits, lists 3,000 credits/day and 5 requests/second, and requires no card. Its [tile documentation](https://apidocs.geoapify.com/docs/maps/) prices a tile at 0.25 credit: a tile-only daily budget is therefore about 12,000 requests, not unlimited usage.
- The [terms](https://www.geoapify.com/terms-and-conditions/) reserve suspension/overage remedies and require usage monitoring. Do not promise unlimited or unconditional zero-cost service beyond the free allocation. No account/billing settings have been changed.
- [Raster attribution requirements](https://apidocs.geoapify.com/docs/maps/map-tiles/) require Geoapify and OpenStreetMap credits/links; `osm-carto` avoids the additional OpenMapTiles credit required for other listed styles. Visible text is fixed, but link activation is still a gate.
- Configuration template (placeholder only): `MAP_TILE_URL=https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=<account-owned-key>`, matching provider attribution and an identifying `MAP_TILE_USER_AGENT`. Supply actual credentials from a private ignored build-definition file; do not pass them in logged command lines or verbose build logs.
- Current generated build settings contain **none** of the three `MAP_TILE_*` definitions (`map-build-config.json` logs presence only). No approved release map configuration is active. Unconfigured release mode fails closed and public OSM host validation is tested; a built release artifact's runtime requests have **NOT RUN**. Debug builds deliberately retain the existing development fallback.
- There is **no offline map tile download/storage implementation**. Marker coordinates remain available when tiles fail. Physical provider outage/network-loss behavior remains NOT RUN; automated failure callbacks pass.

## Build / test results

| Command | Status | Exit | Evidence |
| --- | --- | --- | --- |
| `flutter test` | **FAIL: 169 passed, 2 failed**, latest reply-route source | **1** | `validation/phase7/flutter-test-reply-route.log` |
| Focused existing regressions (persistence/ACK/retry/auth/map) | PASS, 113 tests | 0 | `focused-existing-regressions.log` |
| Map focused tests including failure/retry/attribution | PASS, 18 tests | 0 | `map-focused.log` |
| Latest focused BLE/ownership/SOS regressions | PASS, 72 tests | 0 | `focused-reply-route.log` |
| BLE startup-order regression tests | PASS, 2 tests | 0 | `ble-start-order-after-fix.log` |
| Explicit public OSM environment guard | PASS, 1 test | 0 | `map-explicit-osm-environment.log` |
| `flutter analyze lib test` | PASS, latest reply-route source | 0 | `flutter-analyze-reply-route.log` |
| `flutter build apk --debug` | PASS, latest reply-route source | 0 | `android-debug-reply-route-build.log` |
| `flutter build ios --debug --no-codesign` | PASS, latest reply-route source; Xcode build 1268.4s | 0 | `ios-debug-reply-route-build.log` |
| Signed iOS **profile** build | PASS, latest reply-route source; 463.7s; installed successfully | 0 | `ios-profile-reply-route-build.log` |
| `flutter doctor -v` / `xcodebuild -version` | PASS; Xcode 26.6 (17F113); both USB devices listed | 0 / 0 | `flutter-doctor.log`, `xcode-version.log` |
| Signed iOS **debug** build | PASS before latest SOS startup fix | 0 | `ios-signed-debug-build.log` |
| Signed iOS **release** build | NOT RUN | N/A | Distribution/provisioning readiness not validated; no release acceptance claimed |
| `git diff --check` | PASS | 0 | `git-diff-check.log` |
| Live Firebase REST verification | PASS, 27 checks | 0 | `live-firebase.json` |

Signed debug apps installed on both devices. The user observed the iOS debug home-screen launch restriction; Flutter debug launch failed to discover the VM service and exited 1. A direct Xcode Run subsequently failed at linking with **`Framework 'Pods_Runner' not found` / linker exit 1**, after compilation completed. These are distinct runtime-launch and direct-Xcode-link failures; prior Flutter CLI build success does not erase them. The project retains CocoaPods framework references alongside the generated Swift package. No package-manager migration or speculative linker change was made. The final unsigned CLI debug build completed successfully after 502.8s of active native compilation; this was build work, not a proven hang. A signed development profile fallback subsequently completed successfully after 652.1s (61.9MB); profile installation exited 0 and `devicectl` confirmed process launch. The user confirmed visible runtime. Initial BLE discovery was blocked by a disposed native session; fresh-process discovery subsequently passed with user/native evidence; GATT readiness subsequently passed on the second manual attempt, with service/characteristic discovery and notifications enabled. Subsequent physical SOS/ACK results are recorded separately in the matrix. These development builds and runtime checks are not signed release acceptance.

## Phase 7 files changed

- `lib/main.dart`: enable existing BLE coordinator metadata diagnostics in profile as well as debug; release remains disabled.
- `lib/features/sos/presentation/map_tile_provider.dart`: public OSM host release exclusion.
- `lib/features/sos/presentation/incident_map_page.dart`: permanently visible attribution text.
- `lib/features/sos/presentation/sos_page.dart`: coordinator startup before recipient/debug connection and an always-accessible detail Close action.
- `test/map_tile_provider_test.dart`, `test/incident_map_page_test.dart`: release safety, visible attribution and error/retry checks; existing tests preserved.
- `test/ble_start_order_test.dart`: waits for coordinator startup at both interaction entry points.
- `lib/features/nearby_ble/data/ble_delivery_repository.dart`, `sos_ble_coordinator.dart`: retain observed SOS peer transactionally and reject replay ACKs from other/unbound peers without changing ownership/payload.
- `test/sos_ble_coordinator_test.dart`: four default-route, replay, idempotency and legacy-binding regressions added; earlier work preserved.
- `test/local_device_history_test.dart`: physical-defect regression for dismissing an active SOS detail.
- `test/ble_identity_release_gate_test.dart`: retained failing expected-success two-endpoint Chat/Location regressions.
- `OFFLINE_SOS_RELEASE_READINESS.md`: appended current acceptance status without replacing earlier work.
- This report, the device runbook and sanitized evidence under `validation/phase7/`. Raw physical consoles, device identifiers and all credentials stay in private temporary files. Logs are ignored by the repository's existing `*.log` rule.

## Remaining release blockers

1. Resolve Chat logical sender/native peer identity binding with the failing two-endpoint test passing safely, preserving wrong-peer rejection.
2. Resolve Location logical recipient/native route binding and validate both directions, including ACK and sender checks.
3. Complete physical Android/iPhone SOS, Chat, Location, duplicate/retry/reconnect/restart and permission-failure matrix; second Android needed for Android/Android.
4. Complete app cloud-failure/durable-queue retry and real auth-session-expiry traces. Android Guest visibility across Login/Logout/B/failed Login and the narrowly scoped cloud-absence snapshot passed; these are separate from queue recovery.
5. Activate a free-only provider with account-owned key, working attribution links, rate/usage controls and real release-artifact validation; no offline tiles exist.
6. Validate signed release/distribution configuration separately; signed debug deployment is not release acceptance.
7. Document and test suspended/locked/process-terminated delivery before promising background behavior.
8. Resolve the direct Xcode Run `Pods_Runner` linker failure and validate a clean distribution build; successful Flutter CLI debug/profile builds do not prove the direct Xcode workflow is healthy.
9. Correct and regress native BLE lifecycle reactivation across Dart/auth session replacement on both platforms, including old-session cleanup/callback isolation.
10. Investigate the initial iPhone sender UI/timing discrepancy. The original SOS later shows persisted Confirmed received after reopen; no retransmission evidence or code fix for that observation is claimed. Repeat first-attempt confirmation checks before closing this gate.
11. Complete new-source physical retests and a safe explicit recovery path for legacy inbox records whose original peer is missing; the fix deliberately does not infer those bindings.

## Current physical handoff

Both devices are reconnected. Android’s retained log confirms prior SOS ACKs/disconnections but no receive/reject trace for the legacy phase7-chat-01 attempt; the user confirmed the original `phase7-chat-01` bubble is still **Queued**. The reply-route source fix passed focused/full regression checks apart from the two existing identity release gates. Android is updated and the user confirmed the original SOS/Details/Confirmed received remain intact. iPhone profile build/install exit 0, process launch is confirmed, and the new-input Android → iPhone physical SOS/ACK retest passed with user/native evidence (`android-reply-route-sos-retest-sanitized.log`). The phase7-chat-02 physical retest reaches Android and retries with a stable ID, but fails the declared-sender/native-peer identity check; Chat end-to-end remains FAIL. The latest unsigned debug build exited 0 (1268.4s); active gRPC/Firestore compiler progress was recorded in `ios-debug-reply-route-progress.json`, so this delay is not reported as a hang. Other physical gates remain open. Preserve the old queued message without guessing its peer. Physical Chat receipt/ACK remains FAIL; reverse Chat, controlled ACK loss, duplicate injection, pending-delivery restart/reconnect, Location Sharing and remaining iOS failure cases remain NOT RUN.

Physical PASS rows above describe the builds actually used at that time. After the reply-route/source-binding fix, affected physical SOS/Chat/replay cases require a new-build retest before release acceptance; historical hardware PASS is not promoted to acceptance of new source. Legacy inbox entries without an original peer remain unbound, and replays receive no ACK; safely repairing such a route needs explicit trusted peer selection that has not been implemented. No automatic owner/route merge is performed.

## Week 5 continuation — current source status

See `WEEK_5_BUG_LOG.md` for reproducible steps, root causes, compatibility changes, fixes, tests and remaining limits. Historical physical results above remain unchanged. A failed physical Chat run is not replaced by automated PASS.

The source now separates installation identity, native peer routing and account ownership. New Android/iOS private-preference installation IDs are nonsecret and survive ordinary restart/account changes. An additive connection-bound challenge/response capability exchange binds these identities, with three bounded hello attempts and a final response for asymmetric readiness. Chat author and transport identity must both match the selected incident peer; Location uses the bound recipient ID independently of its outbox destination. Existing v1 framing, UUIDs, schema and Firebase Rules are unchanged. Legacy SOS remains compatible; Chat/Location with an unbound/old peer fail closed. Binding is not cryptographic identity or encryption.

Native reactivation and session teardown fencing are implemented, with deterministic Dart startup/retirement/readiness replay regressions. Real native callback injection and account transitions on connected radios remain NOT RUN. Early/late/duplicate ACK reconciliation preserves terminal state and durable Chat confirmation. A concurrent changed-payload duplicate cannot obtain a positive duplicate ACK. These source fixes still require physical timing and reconnect/permission retests.

Visible attribution now has native HTTPS links with minimum 48px targets; Location controls/status are accessible and tested at 100%/200% text. Legacy outgoing Chat origin is read from the existing durable outbox without rewriting records. Unbound legacy route/payload recovery remains open.

Android update/install/launch exited 0, preserving app data. The user confirmed original SOS records remain complete and prior Confirmed received state remains: **physical continuity PASS after the Week 5 update**. This predates the final additional Chat-author guard and is not a new Chat/SOS transmission test. No new Firebase tests were run in this continuation; the earlier 27 REST checks and two snapshot queries retain their original limited scope.

Latest validation logs and final exit codes are recorded under `validation/week5/`, superseding only the current source test/build status above. Build completion is never inferred from Xcode activity. Signed development profile is for device testing only; signed release remains NOT RUN. Map provider remains conditional/free-only, no account/key provisioned, no offline tiles, and production configuration remains a release blocker.


Week 5 automated result: **199 tests PASS (exit 0), 86 focused PASS (exit 0), analyzer no issues (exit 0), final Android debug APK build exit 0 (43.8s Gradle)**. Added 28 tests; two original identity failure tests remain enabled and pass. First Kotlin compile failure is retained, corrected without dependency changes. The user also confirmed Guest advertising → Login A → BLE Start Scan works on the updated Android native bridge: physical reactivation PASS for that direction only, before final generation/scheduling refresh. iOS profile/debug statuses remain pending confirmed command exits.
