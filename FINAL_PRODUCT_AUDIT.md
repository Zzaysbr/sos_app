# Final Product Audit and Phase 7 Readiness

Audit date: 2 November 2026 (Asia/Bangkok)

Repository: `off_grid_sos`

Branch / HEAD: `main` / `af6efe2cf4133de2c340d3cd374f9ee944d5b163`

Release gate: **BLOCKED**

This is a source, automated-test, documentation and historical-evidence audit.
No physical-device test was run as part of this audit. Historical device
evidence is identified explicitly and is not treated as a current audit run.

## A. Executive Summary

The product has a substantial local-first emergency foundation. SOS incidents,
incident-scoped Chat, BLE outbox/inbox state, cloud sync work and Relay v2 jobs
are persisted in Drift. Direct SOS, Chat and foreground Location Sharing use
application-level persisted ACKs rather than native write completion. Stable
message IDs, recipient/peer checks, retry recovery, duplicate suppression,
owner scoping and Guest isolation have current automated coverage. Hop-only
Relay v2 uses signed origin envelopes, signed hop evidence, bounded storage,
expiry/hop limits and dedicated relay-only tables. A fresh historical physical
run on 2 November proved A -> B -> C relay-only storage and a signed hop receipt
without creating normal History rows at B or C.

The product is **not release-ready**. There is no trusted responder principal,
authorization credential or verified final-recipient persistence receipt.
Consequently Relay v2 correctly refuses final receipts and the origin cannot
claim final delivery or human acceptance. Production map configuration and
live provider validation are absent. The new offline-region implementation is
automated-tested but has no current production-provider/device evidence. The UI
has no localization framework, language selection or translation resources and
mixes Thai, English and transport jargon. Signed Android/iOS distribution
artifacts and several controlled physical failure/range cases remain unverified.

Recommended next phase: design and approve the Trusted Responder credential and
final-receipt protocol before implementing final delivery. In parallel, add
real localization infrastructure and resolve the production map/account setup.
Do not weaken Relay v2 or relabel a hop receipt as final delivery.

## B. Repository Baseline

- Index: empty.
- Pre-existing modified tracked files preserved:
  `OFFLINE_SOS_RELEASE_READINESS.md`, `PHASE_7_RELEASE_VERIFICATION.md`,
  `WEEK_5_BUG_LOG.md`, `hop_relay_coordinator.dart`,
  `sos_ble_coordinator.dart`, `sos_page.dart`, and
  `hop_relay_coordinator_test.dart`.
- Pre-existing untracked files preserved:
  `relay_diagnostics_repository.dart`, `relay_diagnostics_page.dart`, and
  `relay_diagnostics_page_test.dart`.
- This audit adds only this report. It did not stage, commit, push, install,
  uninstall, clear device data or alter source/configuration.

## C. Feature Readiness Matrix

| Area | Classification | Current evidence | Important limitation |
|---|---|---|---|
| Offline Chat | **IMPLEMENTED BUT PARTIALLY VERIFIED** | Incident/owner-scoped Drift rows, explicit routes, stable message IDs, app ACK correlation, retry/restart and dedup tests; focused current run 80/80; historical Android/iPhone bidirectional delivery passed | No current-audit physical run; full controlled real-radio ACK-loss/wrong-peer/range matrix and Android-to-Android remain incomplete |
| Map and SOS location | **BLOCKED** | `flutter_map`; incident/shared/current markers; stale/error/permission UI; attribution links; fail-closed release config; offline-region repository; focused current run 29/29 | No account-owned production key/runtime; no production artifact/provider outage/quota verification; offline downloads lack current device/provider evidence |
| Location Sharing | **IMPLEMENTED BUT PARTIALLY VERIFIED** | Explicit peer choice, incident route binding, two-minute expiry, sender/recipient/ACK checks, stale/duplicate rejection, Stop expiry; focused current run included in 49/49; historical foreground Android/iPhone pass | Foreground/manual updates only; not supported by Relay v2; no current-audit physical run or background promise |
| Thai/English localization | **NOT IMPLEMENTED** | Thai and English strings exist directly in widgets | No `flutter_localizations`, ARB resources, locale selector or persisted language; mixed terminology is widespread |
| Reliability and recovery | **IMPLEMENTED BUT PARTIALLY VERIFIED** | Durable queues, conditional claims, retry limits, lifecycle disposal, owner fencing, migration and relay tests; full current suite 391/391 | Storage-full/device fault injection, controlled radio faults, range, current signed releases and some real Firebase failure paths remain unverified |
| Hop-only Relay v2 | **IMPLEMENTED AND VERIFIED** for the narrow foreground hop-only scope | Current automated relay/security set 106/106; historical fresh A -> B -> C physical diagnostics proved hop 0 -> hop 1 and signed hop receipt | Foreground-only; this status does not include final responder delivery, background relay or release distribution |
| Trusted Responder / final delivery | **NOT IMPLEMENTED** | Code explicitly rejects final receipt persistence without trusted-principal authorization (`relay_repository.dart:1019-1023`) | P0 release blocker; no final receiver authorization, durable final proof or human acceptance semantics |

## D. Audit A — Offline Chat

### Confirmed lifecycle

1. `EmergencyChatPage` is opened with an incident ID and watches only that
   conversation (`emergency_chat_page.dart:127-164`).
2. `PersistentChatRepository` authorizes the incident against the current owner,
   writes the Chat row with a stable ID in Drift and rejects conflicting reuse
   (`chat_repository.dart:80-149`, `233-245`).
3. The selected recipient is stored in both Chat/outbox state. Legacy unrouted
   queued/failed Chat can only be assigned transactionally within the current
   owner, incident and Chat kind (`ble_delivery_repository.dart:506-590`).
4. `SosBleEnvelope` carries `chat.message` / `chat.ack`; outer and inner
   message ID/time/kind must agree (`sos_ble_envelope.dart:8-24`, `209-290`).
5. The outbox claim is conditional, preventing two workers from claiming the
   same queued/retryable row (`ble_delivery_repository.dart:679-716`).
6. ACK persistence checks message, incident, kind, selected destination and
   observed native peer; terminal acknowledged state is not regressed
   (`ble_delivery_repository.dart:719-792`).
7. Incoming rows use the message ID primary key and conflicting duplicate
   content is rejected (`chat_repository.dart:184-230`;
   `chat_messages.dart:3-33`).
8. Coordinator state is foreground/best-effort but durable rows remain for a
   later run (`sos_ble_coordinator.dart:23-28`). On restart, stale active states
   are recovered and the same message ID is retried (covered by current tests).

### UI and semantics

- Loading, load failure/retry, empty conversation, sending, delivered, failed
  and retry-scheduled/terminal-failure states are represented.
- A native BLE write is not presented as application delivery.
- Accessibility coverage includes normal/enlarged text in current tests, but
  mixed hardcoded language prevents a complete bilingual accessibility claim.
- Attachments exist in the local Chat model/table but the current BLE Chat
  envelope carries text only. This audit therefore does not claim offline BLE
  attachment delivery.

### Verification assessment

The current focused command passed 80 tests. Historical device evidence in
`OFFLINE_SOS_RELEASE_READINESS.md` records Android <-> iPhone Chat with exactly
one receiver row and application ACK in both directions. It is historical,
not a new physical PASS for this audit or a complete production matrix.

## E. Audit B — Map and SOS Location

### Current implementation

- Renderer: `flutter_map` 8.3.2 with `latlong2` (`pubspec.yaml`).
- Build-time configuration: `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, and
  `MAP_TILE_USER_AGENT` (`map_tile_provider.dart:24-41`).
- Release rejects an unset provider, invalid/non-HTTPS template, public OSM
  endpoint, missing placeholders/attribution/user-agent and a Geoapify URL with
  no key (`map_tile_provider.dart:88-117`).
- The page independently renders incident (red), verified shared (purple) and
  current-device (blue) markers, plus zoom and recenter controls
  (`incident_map_page.dart:231-271`, `310-404`).
- Permission denial, disabled services, timeout, invalid coordinates, stale
  current location, expired shared location, tile failure and retry have visible
  states (`incident_map_page.dart:160-213`, `422-570`). Coordinates remain
  visible when tiles fail.
- Attribution is always visible and the native allowlist opens only the OSM and
  Geoapify public credit links (`incident_map_page.dart:365-402`; platform
  `AppDelegate.swift` / `MainActivity.kt`).
- Offline regions are real implementation, not a generic cache claim. Only a
  valid Geoapify provider is accepted; partial downloads are staged and removed,
  completed manifests survive restart, and tile/region/total limits are
  enforced (`offline_map_repository.dart:146-319`). Missing downloaded tiles
  still fall through to the network (`offline_first_tile_provider.dart:8-38`).

### Provider and release assessment

No account-owned `MAP_TILE_*` runtime is present. The public OSM service is
correctly development-only: its official policy prohibits bulk/offline
downloading and offers no SLA. Geoapify currently requires an API key and
attribution; its Free plan currently lists 3,000 credits/day and up to five
requests/second. These terms/quotas remain owner acceptance and runtime
monitoring work, not guarantees:

- https://operations.osmfoundation.org/policies/tiles/
- https://apidocs.geoapify.com/docs/maps/
- https://www.geoapify.com/pricing/

The current 29/29 focused tests prove configuration guards, UI failure behavior
and repository mechanics with synthetic fetchers. They do not prove an owned
account, live tiles, quota behavior, platform storage pressure or a signed
release build.

## F. Audit C — Location Sharing

### Confirmed lifecycle

- Sharing is foreground-only and requires an active incident plus an explicit
  connected recipient (`location_sharing_panel.dart:100-149`;
  `sos_ble_coordinator.dart:423-447`). It does not start background GPS polling.
- Each publish reads a fresh high-accuracy location, creates a unique update ID,
  includes optional accuracy, and expires after two minutes
  (`location_sharing_panel.dart:151-205`).
- A per-operation token prevents an older async completion from overwriting a
  newer permission/send result (`location_sharing_panel.dart:155-203`). The UI
  separates current-operation state from previous delivery evidence
  (`location_sharing_panel.dart:253-319`).
- The envelope validates recipient, coordinate range, accuracy, UTC timestamps,
  expiry and ACK status (`location_ble_envelope.dart:146-191`).
- Receiver persistence requires the logical recipient, matching incident peer
  and bound installation identity; older/non-increasing updates and wrong peers
  are rejected (`ble_delivery_repository.dart:984-1035`;
  `sos_ble_coordinator.dart:1127-1167`).
- Stop invalidates the operation token, clears local consent, expires pending
  location outbox work and does not auto-resume after coordinator restart
  (`location_sharing_panel.dart:235-246`; `sos_ble_coordinator.dart:450-453`).

### Limitations

- Updates are user-triggered, foreground-only. “Sharing” must not be described
  as continuous/background tracking.
- Location Sharing is Direct v1 only. Relay v2 envelopes intentionally contain
  only per-incident origin location consent; they do not relay live updates.
- Accuracy is carried but is not shown in the Incident Map status panel. The UI
  shows a timestamp for shared data and stale/expiry wording, but users cannot
  see the reported uncertainty radius.
- Current automated identity/isolation group passed 49/49. Historical physical
  evidence covers success, second update, permission denial/regrant and Stop;
  no physical test was run during this audit.

## G. Audit D — Localization and UI Language

### Framework status

No localization framework is configured. `pubspec.yaml` has no
`flutter_localizations` dependency; no ARB files, `AppLocalizations`, delegates,
supported locales, language selector or stored locale were found. The default
language is whatever hardcoded string a widget contains.

### Inventory

| Screen/component | Current text/language | Problem | Recommended Thai | Recommended English | Priority |
|---|---|---|---|---|---|
| Home navigation | `ขอความช่วยเหลือ`, `แชต`, `Settings` / mixed | One navigation model changes language | `ขอความช่วยเหลือ`, `แชต`, `ตั้งค่า` | `Need Help`, `Chat`, `Settings` | P1 |
| SOS action | `กดค้างเพื่อส่ง SOS` / Thai | Clear but not selectable by locale | `กดค้างเพื่อส่ง SOS` | `Hold to send SOS` | P1 |
| Active SOS | `SOS กำลังดำเนินอยู่` plus English transport state / mixed | Emergency state and transport state compete | `SOS ยังดำเนินอยู่` | `SOS is active` | P1 |
| Chat title/input | `แชตฉุกเฉิน`, `พิมพ์ข้อความ…`, `Send` / mixed | Primary action switches language | `แชตฉุกเฉิน`, `พิมพ์ข้อความ…`, `ส่ง` | `Emergency chat`, `Type a message…`, `Send` | P1 |
| Chat queue | `Saved locally; BLE delivery is pending.` / English/technical | “BLE” is implementation jargon | `บันทึกในเครื่องแล้ว กำลังรอส่งให้อุปกรณ์ใกล้เคียง` | `Saved on this device; waiting to send nearby` | P1 |
| Chat recipient recovery | `Queued messages need a BLE recipient` / English/technical | User may not understand route recovery | `ข้อความที่รอส่งต้องเลือกอุปกรณ์ผู้รับ` | `Choose the device that should receive queued messages` | P1 |
| Delivery status | `Awaiting acknowledgement`, `Failed; retry scheduled` / English/technical | “acknowledgement” and scheduler detail are obscure | `ส่งแล้ว กำลังรอยืนยัน`, `ส่งไม่สำเร็จ ระบบจะลองใหม่` | `Sent; awaiting confirmation`, `Failed; will retry` | P1 |
| History | Thai filters plus `ข้อมูลในเครื่อง` / Thai | Mostly consistent; needs locale resource and concise semantics | `ทั้งหมด`, `กำลังดำเนินอยู่`, `สำเร็จ`, `ยกเลิก` | `All`, `Active`, `Resolved`, `Cancelled` | P1 |
| Incident Map | all operational text English | Breaks Thai emergency flow | `แผนที่เหตุฉุกเฉิน`, `ตำแหน่งเหตุ`, `กลับมาตำแหน่งปัจจุบัน` | `Incident map`, `Incident location`, `Recenter` | P1 |
| Map stale state | `Current location is stale...` / English | Correct meaning but no Thai and no age | `ตำแหน่งปัจจุบันเก่าแล้ว โปรดอัปเดตก่อนใช้งาน` | `Current location is stale; refresh before relying on it` | P1 |
| Offline map | `Downloaded map tiles...` / English/technical | “tiles” is provider jargon | `มีแผนที่บางพื้นที่ในเครื่อง ส่วนที่ไม่มีต้องใช้อินเทอร์เน็ต` | `Downloaded areas work offline; other areas need internet` | P2 |
| Location Sharing | `Foreground location sharing` / English/technical | Does not clearly say updates are manual | `แชร์ตำแหน่งขณะเปิดแอป` | `Share location while the app is open` | P1 |
| Location recipient | `Recipient: <id>` / English/identifier | Raw identifier is not meaningful to ordinary users | `ส่งตำแหน่งให้อุปกรณ์ที่เลือก` | `Sharing with the selected device` | P2 |
| BLE picker | `Choose BLE recipient`, `GATT ready` / English/technical | Debug/network terms leak into product UX | `เลือกอุปกรณ์ใกล้เคียง`, `พร้อมเชื่อมต่อ` | `Choose a nearby device`, `Ready` | P1 |
| Relay preference | `Nearby SOS Relay` and long English explanation | Meaning and consent scope are easy to confuse | `ช่วยส่งต่อ SOS ใกล้เคียง` | `Forward nearby SOS` | P1 |
| Relay origin state | `Stored on 1 relay device; final delivery unconfirmed` / English/technical | Accurate but long and jargon-heavy | `ฝากไว้กับอุปกรณ์ส่งต่อ 1 เครื่องแล้ว ยังไม่ยืนยันว่าถึงผู้ช่วยเหลือ` | `Stored by 1 relay; responder receipt not confirmed` | P1 |
| Relay Diagnostics | all English | Acceptable for developer-only screen, but should still use consistent terms | `การวินิจฉัย Relay` | `Relay diagnostics` | P3 |
| Permissions | Thai settings mixed with `Open App Settings` / mixed | Recovery action changes language | `เปิดการตั้งค่าแอป` | `Open app settings` | P1 |
| Authentication/account | all English | No Thai path for account recovery | `เข้าสู่ระบบ`, `ลืมรหัสผ่าน`, `ออกจากระบบ` | `Sign in`, `Forgot password`, `Sign out` | P2 |
| Raw BLE errors | `error.toString()` in picker | Technical/native error can confuse users and may expose implementation detail | `เชื่อมต่อ Bluetooth ไม่สำเร็จ โปรดลองอีกครั้ง` | `Bluetooth connection failed; try again` | P2 |

### Emergency terminology glossary

| Concept | Thai | English | Rule |
|---|---|---|---|
| SOS | `SOS` | `SOS` | Keep the recognized term; explain action, not acronym |
| Responder | `ผู้ช่วยเหลือที่ได้รับอนุญาต` | `Authorized responder` | Do not use for an arbitrary nearby peer |
| Relay | `อุปกรณ์ส่งต่อ` | `Relay device` | State that it is not automatically a responder |
| Stored on relay | `ฝากไว้กับอุปกรณ์ส่งต่อแล้ว` | `Stored by a relay` | Never imply final receipt |
| Received | `ได้รับข้อมูลแล้ว` | `Received` | Use only for local receipt, not durable responder persistence |
| Confirmed received | `ยืนยันว่าผู้รับบันทึกแล้ว` | `Confirmed received` | Requires valid application/final ACK for the selected recipient |
| Delivery failed | `ส่งไม่สำเร็จ` | `Delivery failed` | Add whether retry will happen |
| Location sharing | `แชร์ตำแหน่ง` | `Location sharing` | Qualify foreground/manual behavior |
| Nearby device | `อุปกรณ์ใกล้เคียง` | `Nearby device` | Avoid BLE/GATT in normal UI |
| Offline | `ออฟไลน์ (ไม่ใช้อินเทอร์เน็ต)` | `Offline` | Do not imply Bluetooth or maps always work |

## H. Audit E — Reliability, Security and Recovery

### Confirmed safeguards

- Local SOS and cloud queue are written transactionally before BLE/cloud work
  (`sos_repository.dart:120-175`). Guest rows never enter cloud sync
  (`sos_repository.dart:311-317`).
- Account/Guest resources are replaced and fenced by owner/generation; retained
  routes from a previous account are closed (`main.dart:82-180`, `191-218`).
- Cloud work retries on auth, connectivity and resume; failed commands remain in
  the queue (`sos_sync_coordinator.dart:30-97`;
  `sos_repository.dart:325-406`).
- BLE uses stable IDs, bounded exponential retry, maximum attempts, conditional
  outbox claims, application ACKs and peer correlation.
- Incoming SOS/Chat/Location deduplication uses durable primary keys and rejects
  same-ID/different-content conflicts.
- Location expires, is sender/recipient constrained and is not backgrounded.
- Relay v2 is additive, default-off for participation, foreground-only, bounded
  by 30-minute expiry, three hops, 50 jobs and 1 MiB storage; cryptographic/key
  failure fails closed without disabling Direct v1.
- Relay private seed is stored through Android Keystore-wrapped secure storage
  or non-synchronizing, this-device iOS Keychain accessibility
  (`relay_key_store.dart:14-69`). It is not stored in Drift/cloud payloads.
- Lifecycle disposal cancels subscriptions/timers, clears partial bindings and
  expires active Location Sharing (`sos_ble_coordinator.dart:250-306`).

### Verification gaps

- No current-audit device testing. Controlled real-radio ACK suppression,
  wrong-peer injection, close-while-pending and 5/10/20/30/50 m open/obstructed
  range measurements remain incomplete.
- Android-to-Android requires a second Android device and remains unverified.
- Signed Android release, signed iOS distribution release and store/archive
  provenance remain unverified.
- Real storage-full and secure-storage failure behavior needs device tests.
- Real Firebase session-expiry/network recovery needs current-build evidence.
- Relay is explicitly foreground-only. It must not be advertised as a
  background safety mesh.
- Direct-v1 session binding authenticates the installation proof within the BLE
  session, not the real-world identity/authority of the person holding it.

## I. Findings

### FPA-01 — P0 — Trusted final responder delivery is absent

- **Affected:** `relay_repository.dart:965-1024`, Relay v2 receipt/domain/tables.
- **Reproduction:** complete A -> B -> C hop-only forwarding and inspect origin
  or Diagnostics.
- **Expected for release claim:** a selected, authorized responder durably
  persists the incident and returns a verifiable final receipt.
- **Actual:** only hop storage/receipt is accepted; final receipt persistence
  throws because trusted-principal authorization is unavailable.
- **Root cause:** no responder enrollment/credential, device-to-user binding or
  final recipient authorization model exists.
- **Evidence:** source fail-closed branch; historical physical result reports
  `Final responder receipt: Not confirmed`.
- **Impact:** the sender cannot know an authorized responder received the SOS.
- **Action:** approve and implement the design in section J before any final
  delivery wording or release.

### FPA-02 — P0 — Signed distribution release is not verified

- **Affected:** Android Gradle signing, iOS Xcode signing/distribution.
- **Reproduction:** attempt controlled signed Release build with owner assets.
- **Actual:** Android signing is fail-closed without owner keystore; historical
  iOS Profile installs are development evidence, not App Store distribution.
- **Impact:** no immutable release candidate exists for acceptance.
- **Action:** owner supplies/validates signing assets, builds, inspects and
  physically tests signed artifacts without clearing existing data.

### FPA-03 — P1 — Production map runtime is absent

- **Affected:** `map_tile_provider.dart`, `incident_map_page.dart`, build defines.
- **Reproduction:** build Release without `MAP_TILE_*`.
- **Expected:** owned compliant provider, attribution, quota monitoring and live
  Android/iOS verification.
- **Actual:** fail-closed configuration error; markers/coordinates remain.
- **Root cause:** no owner account/key/private define and no approved live run.
- **Impact:** release users see coordinates/markers but no basemap.
- **Action:** owner configures Geoapify (or approves another compliant provider),
  reviews terms/quotas, injects ignored defines, and runs live success/failure
  tests on both platforms.

### FPA-04 — P1 — Bilingual localization is not implemented

- **Affected:** all presentation files; especially `sos_page.dart`,
  `emergency_chat_page.dart`, `incident_map_page.dart`,
  `location_sharing_panel.dart`, auth/account/BLE pages.
- **Reproduction:** navigate the app in Thai; observe Thai navigation with
  English status, permission, map and transport messages.
- **Expected:** selectable, persisted Thai/English locale and consistent terms.
- **Actual:** hardcoded mixed strings; no localization resources or selector.
- **Impact:** emergency comprehension and accessibility risk.
- **Action:** add Flutter localization infrastructure, glossary-backed ARB
  resources, locale persistence, fallback and layout/text-scale tests.

### FPA-05 — P1 — Required physical reliability matrix is incomplete

- **Affected:** Direct BLE, Location, Relay lifecycle/range and release evidence.
- **Actual:** automated fault tests pass and one foreground hop-only route has
  historical physical evidence, but controlled ACK loss/wrong peer/range,
  Android-to-Android and signed-release runs are not complete.
- **Impact:** field reliability and range are unknown; no maximum range claim is
  valid. RSSI is not a distance measurement.
- **Action:** execute the existing physical runbook with timestamped device logs
  and preserve PASS/FAIL evidence per case.

### FPA-06 — P2 — Location accuracy is transported but not communicated

- **Affected:** `location_ble_envelope.dart:36-48`,
  `incident_map_page.dart:422-477`.
- **Reproduction:** receive a shared update with non-null `accuracyMeters` and
  open Incident Map.
- **Expected:** timestamp, freshness and uncertainty are understandable.
- **Actual:** coordinate/time and stale/expiry status appear; accuracy does not.
- **Impact:** users may over-trust a marker.
- **Action:** show a human-readable accuracy radius and, if practical, a map
  accuracy circle; retain explicit unavailable/stale states.

### FPA-07 — P2 — Product UI exposes transport jargon/raw errors

- **Affected:** `ble_recipient_picker_page.dart:50-181`, Chat/Location status UI.
- **Reproduction:** trigger a native BLE error or legacy recipient recovery.
- **Actual:** UI can show `error.toString()`, BLE, GATT and acknowledgement terms.
- **Impact:** unclear recovery and possible exposure of implementation details.
- **Action:** map internal error categories to localized safe user messages;
  retain detailed diagnostics only in redacted debug logs/tools.

### FPA-08 — P2 — Release documentation contains stale implementation claims

- **Affected:** early/current prose in `OFFLINE_SOS_RELEASE_READINESS.md` and
  historical sections of Phase 7/Week 5 docs.
- **Reproduction:** compare “schema version 5 / no offline downloads” statements
  with `app_database.dart:33` and current offline-map files.
- **Actual:** current code is schema 6 and contains offline-region downloads,
  while older sections still state schema 5/no offline maps.
- **Impact:** reviewers can make the wrong release decision.
- **Action:** preserve historical results but add a clearly dated superseding
  current-state section after implementation work is frozen.

### FPA-09 — P2 — Startup lacks a degraded local-mode boundary

- **Affected:** `main.dart:24-36`.
- **Reproduction:** make Firebase initialization or native `deviceIdentity`
  unavailable in a deterministic startup test.
- **Expected:** either safe local-only startup or a controlled recovery screen.
- **Actual:** initialization is awaited without an app-level recovery boundary;
  missing device identity throws `StateError` before `runApp`.
- **Impact:** a configuration/plugin failure can block even local history/UI.
- **Action:** first add deterministic tests, then design a fail-closed recovery
  screen that does not silently weaken BLE identity. This is a source-level
  risk; it has not been physically reproduced in this audit.

### FPA-10 — P3 — Drift test harness emits duplicate-database warnings

- **Affected:** several migration/restart tests using `AppDatabase.forTesting`.
- **Actual:** tests pass, but Drift warns that multiple database instances share
  one executor during selected tests.
- **Impact:** noisy evidence can conceal meaningful warnings; this is not proof
  of a production corruption defect.
- **Action:** isolate executors/close instances deterministically or document the
  intentional test arrangement without suppressing production warnings.

## J. Audit F — Trusted Responder and Final Delivery Design

### Current identities and bindings

| Identity | Current representation | Assurance |
|---|---|---|
| User/owner | Firebase UID when authenticated; local Guest owner scope otherwise (`main.dart:201-205`, `sos_repository.dart:50-59`) | Database/cloud ownership scope; Guest is local only |
| Direct installation | Native `deviceIdentity` passed as `localDeviceId` (`main.dart:31-36`, `124-145`) | Stable installation identifier plus session proof; not a real-person identity |
| BLE transport peer | Platform connection/device ID | Route/session handle; may change and is not account authorization |
| Relay installation | Ed25519 public key fingerprint from device-only secure seed (`relay_key_store.dart:72-157`) | Cryptographic installation identity only; explicitly not proof of a person |
| Relay hop | Signed capability/session proof, signed origin/hop attestations and bound signed hop receipt | Proves the participating installation stored the matching envelope |

Direct incident peer binding ties a logical installation proof to the observed
native session and stored incident route. Relay v2 ties an Ed25519 installation
key to signed protocol evidence. Neither mechanism currently proves that the
installation belongs to an enrolled/authorized responder for a specific SOS.
Relay-only envelopes remain outside normal SOS History by design.

### Proposed Model C extension: trusted final responder

1. **Responder principal:** an authenticated responder account/organization ID
   with explicit eligibility state. Do not infer responder status from Rescue
   UI mode or Relay participation.
2. **Installation enrollment:** bind a responder installation Ed25519 public key
   fingerprint to the responder principal using a server-issued, signed,
   versioned credential containing scope, issue/expiry, credential ID and
   revocation/version data. The private seed remains in Keystore/Keychain.
3. **Authorization:** origin policy selects an authorized responder or an
   approved responder class. Carry the authorization requirement/credential
   reference inside a newly versioned immutable origin body. Relay nodes only
   verify/forward; they do not become responders.
4. **Final persistence:** the final device verifies origin/hop signatures,
   expiry, hop limit, authorization scope and its own credential before an
   atomic transaction inserts the responder-owned incident, dedup record and
   final-receipt outbox. Persistence—not native write—creates receipt evidence.
5. **Final receipt fields:** new wire kind/version, receipt ID, origin message
   ID, incident ID, immutable digest, responder principal ID, installation key
   fingerprint/public key, authorization credential ID, correlation ID, route
   context, `persisted` status, created/expiry time and signature. Do not encode
   “accepted” or “rescue dispatched” unless a separate human action proves it.
6. **Origin verification:** require a valid trusted credential chain/pinned
   authority, unrevoked/unexpired scope, exact message/incident/digest,
   intended-recipient match, exact correlation, expected receipt kind and valid
   installation signature. Persist semantic dedup keys and reject wrong-peer,
   delayed, conflicting and replayed receipts.
7. **Offline behavior:** cache signed responder credentials and bounded
   revocation/freshness metadata. If trust cannot be verified within policy,
   keep `Final delivery unconfirmed`; never fail open. Store-and-forward the
   final receipt back along the durable route after reconnection/restart.
8. **Recovery:** origin derives status only from the persisted verified final
   receipt, so restart cannot lose confirmation. Relays retain bounded reverse
   receipt work until accepted/expired.
9. **Backward compatibility:** add protocol/capability kinds and a migration;
   never reinterpret v1 Direct ACK or v2 hop ACK as final. Old peers continue
   Direct v1/hop-only behavior and fail closed for unsupported final delivery.

### Required design decisions before implementation

- Who operates the trust authority and responder registry?
- Which responder roles/scopes exist and who can revoke them?
- Whether Guest origins may address trusted responders and how authorization is
  conveyed without revealing account/contact data to relays.
- Offline credential freshness/revocation window and clock-skew policy.
- Privacy-minimized responder identity displayed to the origin.
- Human “accepted” semantics versus machine “persisted” semantics.

### Required tests

- Golden canonical/signature vectors across Dart/Android/iOS.
- Credential issue/expiry/revocation/wrong-scope/wrong-principal cases.
- Final ACK wrong message, incident, digest, recipient, key, peer, correlation,
  kind, version, timestamp and replay cases.
- Atomic persistence failure and crash/restart before/after receipt creation.
- Duplicate final receipts and concurrent relay paths.
- Backward compatibility with Direct v1 and hop-only v2.
- Physical A -> B -> trusted C with A unable to reach C, C persisting one
  incident, final receipt returning to A, restarts at each phase and no relay
  History leakage.

## K. Test and Validation Results

All commands below were executed against the baseline stated at the top. Logs
are under `/tmp/off_grid_sos_device_validation/final_product_audit_2026-11-02/`.

| Command | Exit | Result |
|---|---:|---|
| `flutter test --reporter compact test/chat_repository_test.dart test/chat_reply_routing_test.dart test/ble_delivery_repository_test.dart test/sos_ble_coordinator_test.dart` | 0 | 80 passed |
| `flutter test --reporter compact test/incident_map_page_test.dart test/map_tile_provider_test.dart test/offline_map_repository_test.dart` | 0 | 29 passed |
| `flutter test --reporter compact test/location_sharing_test.dart test/location_sharing_panel_test.dart test/ble_identity_release_gate_test.dart test/guest_continuity_test.dart test/local_device_history_test.dart` | 0 | 49 passed |
| `flutter test --reporter compact test/relay_envelope_test.dart test/relay_repository_test.dart test/relay_platform_security_test.dart test/hop_relay_coordinator_test.dart test/relay_diagnostics_page_test.dart test/database_migration_test.dart` | 0 | 106 passed |
| `flutter test --reporter compact` | 0 | 391 passed, 0 failed |
| `flutter analyze lib test` | 0 | No issues found |
| `git diff --check` | see final verification | Must remain 0 after this report |

No dedicated localization tests exist because localization infrastructure does
not exist. Current text-scaling/widget tests cover selected layouts, not
translation completeness. The focused groups overlap and must not be summed as
a unique full-suite count.

Physical-device tests in this audit: **NOT RUN**. Historical device evidence is
useful regression context only. No current physical BLE, Firebase, signed
release, production map, range or final responder verification is claimed.

## L. Prioritized Implementation Roadmap

1. **P0 — Trusted Responder design gate:** approve authority, credential,
   revocation, privacy and persisted-vs-human acceptance semantics. Freeze
   canonical final receipt vectors before coding.
2. **P0 — Implement final delivery additively:** credential validation, atomic
   final persistence, signed final receipt, durable reverse route, migration and
   backward compatibility. Retain all current hop-only guards.
3. **P0 — Distribution signing:** create and inspect owner-controlled Android
   and Apple distribution artifacts from a frozen source commit. Do not replace
   existing device signing/data as a workaround.
4. **P1 — Localization foundation:** add ARB-based Thai/English resources,
   glossary, persisted selector, fallback and emergency-screen accessibility
   tests before more UI copy proliferates.
5. **P1 — Production map:** owner account/key, approved attribution, ignored
   define injection, quota/usage policy and live Android/iOS release checks.
   Then physically validate bounded offline-region download/restart/storage
   errors; never enable it on public OSM.
6. **P1 — Physical reliability session:** controlled ACK loss, wrong peer,
   close/restart/reconnect, permissions, Android-to-Android and 5-50 m range.
7. **P2 — Emergency clarity:** show location accuracy, localize safe errors and
   remove BLE/GATT/ACK jargon from normal UI.
8. **P2 — Documentation reconciliation:** add one dated current-state section
   that supersedes old schema/offline-map claims while preserving historical
   evidence.
9. **P2/P3 — Startup and test hygiene:** test degraded startup and clean Drift
   harness warnings after higher-risk delivery work is stable.

Dependencies: final delivery depends on trust-model approval; signed physical
acceptance depends on final delivery plus signing assets; live offline maps
depend on an approved provider/account; translation QA should precede final UX
acceptance so emergency wording is tested once in both languages.

## M. Release Gate

Release remains **BLOCKED** until all of the following have recorded evidence:

- Trusted responder authorization and verified final-recipient persisted receipt.
- No hop/native-write state is presented as final delivery or human acceptance.
- Owner-controlled production map config, attribution, quota policy and live
  Android/iOS release runtime; offline regions validated only under permitted
  provider terms.
- Owner-controlled signed Android and iOS distribution artifacts, signature and
  provenance inspection, safe install/update and launch validation.
- Required current-build direct SOS/Chat/Location fault, permission,
  restart/reconnect/dedup/wrong-peer and Android-to-Android physical matrix.
- BLE range measurements at specified distances/environments, without treating
  RSSI as reliable distance.
- Thai/English localization and emergency terminology acceptance, including
  large-text and narrow-screen checks.
- Guest/account isolation, Firebase failure/session recovery and migration
  revalidation on the frozen release candidate.

Hop-only A -> B -> C evidence is valuable but is not a substitute for any gate
above. No release-ready claim is made by this report.
