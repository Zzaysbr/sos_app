# OFF_GRID_SOS — Phase 7 Physical BLE Acceptance

Date: 3 November 2026  
Status: `ACCEPTANCE-INCOMPLETE`

This matrix is the controlled procedure for Q-701 through Q-704. Automated
tests do not substitute for two-device evidence. No SOS or location message
was sent during preparation of this document.

## Device inventory

| Role | Device | Transport state | Evidence |
|---|---|---|---|
| Candidate A | Samsung SM-A536E, Android 14 | ADB USB `RFCT80GPFVY` | `adb devices -l`, `flutter devices` |
| Candidate B | iPhone 15 Plus, iOS 27.0.1 | CoreDevice paired/available; Flutter wireless ID ending `A01E` | `xcrun devicectl list devices`, `flutter devices` |
| Candidate B | iPad Air 11-inch (M2), iPadOS 27.0.1 | CoreDevice paired/available; Flutter wireless ID ending `601E` | `xcrun devicectl list devices`, `flutter devices` |

Use exactly two devices for each run. Use only tester-controlled accounts and a
non-sensitive test location. Do not use a real emergency workflow.

## Test matrix

### Q-701 — Chat identity and peer binding

**Preconditions:** A and B are foreground, Bluetooth permission is granted,
and the app build/configuration is recorded. Select B explicitly in the Chat
recipient picker on A.

| ID | Steps | Expected evidence | Actual | Result |
|---|---|---|---|---|
| Q701-01 | Send one Chat message A→B | B shows the one intended message; sender/recipient labels match | Not executed | NOT RUN |
| Q701-02 | Disconnect, reconnect, send a second message | Same selected logical peer is used after reconnect | Not executed | NOT RUN |
| Q701-03 | Attempt delivery from an unauthorized/mismatched peer using a controlled test setup | Message is rejected and no record/positive ACK is created | Not executed | NOT RUN |
| Q701-04 | Retry the same message ID | B has one record only; duplicate is idempotent | Not executed | NOT RUN |

Capture message IDs and counts only; do not capture message bodies or tokens.

### Q-702 — Location Sharing recipient and ACK

**Preconditions:** Use a safe test location and explicit consent. Never use a
real person’s precise location in screenshots or reports.

| ID | Steps | Expected evidence | Actual | Result |
|---|---|---|---|---|
| Q702-01 | Select B, enable sharing, send one update | B receives the update; A records the matching ACK | Not executed | NOT RUN |
| Q702-02 | Try a wrong recipient/native peer | Update is rejected; no misleading success state | Not executed | NOT RUN |
| Q702-03 | Retry the same update ID | One persisted update and one correlated ACK | Not executed | NOT RUN |

Record only rounded/test coordinates or a redacted marker screenshot.

### Q-703 — BLE lifecycle

| ID | Steps | Expected evidence | Actual | Result |
|---|---|---|---|---|
| Q703-01 | Initialize, connect A↔B, disconnect normally, reconnect (3 cycles) | No duplicate listeners, stale callbacks, or duplicate sessions | Not executed | NOT RUN |
| Q703-02 | Navigate away/back from BLE-dependent screen | Listener count and UI state remain stable | Not executed | NOT RUN |
| Q703-03 | Disable/re-enable Bluetooth and recover permission where supported | Coordinator recovers without stale delivery or crash | Not executed | NOT RUN |

Record device/OS/build and first actionable error only; never record keys or
authentication data.

### Q-704 — SOS delivery and ACK consistency

| ID | Steps | Expected evidence | Actual | Result |
|---|---|---|---|---|
| Q704-01 | Create a controlled test SOS on A with B selected | A persists one SOS; B persists one corresponding SOS | Not executed | NOT RUN |
| Q704-02 | Observe sender state before/after receiver persistence and ACK | Status changes only on protocol evidence; no native-write-only claim | Not executed | NOT RUN |
| Q704-03 | Disconnect before ACK, then reconnect/retry | Retryable state is shown; no duplicate SOS record | Not executed | NOT RUN |
| Q704-04 | Deliver delayed/duplicate ACK where safely reproducible | Terminal success does not regress; duplicate ACK is idempotent | Not executed | NOT RUN |

Do not contact real responders or external emergency services.

## Preparation evidence

- `flutter devices`: Android SM-A536E (Android 14), iPhone 15 Plus (iOS 27.0.1),
  and iPad Air 11-inch (M2) (iOS/iPadOS 27.0.1) detected.
- `adb devices -l`: Samsung serial `RFCT80GPFVY` in `device` state.
- `xcrun devicectl list devices`: iPhone 15 Plus and iPad Air 11-inch (M2)
  listed as `available (paired)`.
- No physical message, location update, SOS, or negative-path injection was
  executed in this preparation pass.

## Current status and next action

Q-701, Q-702, Q-703, and Q-704 remain `acceptance-incomplete`. A tester must
run the matrix with two selected devices and return the observed evidence for
each row before any Quest can be marked physically accepted. Phase 9 remains
`BLOCKED`.

## Execution preflight — 3 November 2026

- Android package `com.n1cxltine.sosapp` is installed on Samsung; version
  `0.1.0` / version code `1` was observed. Bluetooth is ON and the app has
  granted Android Bluetooth Scan/Connect/Advertise permissions.
- iPhone 15 Plus CoreDevice is `available (paired)`, Developer Mode is enabled,
  and DDI services are usable. Flutter also lists it wirelessly, although its
  LAN browsing check reports a reconnect warning; this is not evidence of BLE
  transport connectivity.
- iPad Air 11-inch (M2) is `available (paired)`, Developer Mode is enabled,
  and DDI services are usable. It is not used as the primary A/B pair in this
  run.
- BLE discovery/connection, Chat, Location, and SOS transmission were not
  initiated automatically. Therefore Q-703 lifecycle and all message cases
  remain `NOT RUN` pending operator interaction on both devices.

## Safe BLE test path restored — 3 November 2026

Root cause of the missing iOS menu: `sos_page.dart` gated `BleTestPage` with
`kDebugMode`. Flutter Profile builds set `kDebugMode` to false, so the screen
was hidden even though `BleTestPage`, `BleTransport`, and the coordinator were
still present. The gate now uses `!kReleaseMode`: Debug and Profile expose the
existing development-only screen, while Release continues to hide it. No BLE
manager, protocol, permission bypass, or production route was added.

Selected Q-703 path:

1. Build/install the same Profile source on Samsung and iPhone using the
   established update-in-place workflow; do not uninstall or clear data.
2. On each device open `Settings → BLE Test (Debug)` (Thai builds show the
   localized equivalent). Confirm the screen logs permission and transport
   initialization.
3. Start discovery on both devices. Record `centralState`, `peripheralState`,
   discovered peer ID (redacted), and scan/advertising state.
4. Select the other device, connect, then record `connected` on both sides.
5. Disconnect normally, reconnect three times, and navigate away/back between
   cycles. Record any stale callback, duplicate listener, or crash.
6. Toggle Bluetooth off/on and, only where safe, deny/regrant permission. Record
   the resulting error/recovery state.

Do not send Chat, Location, SOS, or range messages during Q-703 lifecycle-only
verification. Physical Q-703 remains `NOT RUN` until these observations are
reported from both devices.

## Profile installation evidence — 3 November 2026

- Android Profile artifact: `build/app/outputs/flutter-apk/app-profile.apk`,
  build exit 0; `adb install -r` exit 0; installed package reports version
  `0.1.0` code `1`. Existing package data was not cleared.
- iOS Profile artifact: `build/ios/iphoneos/Runner.app`, build exit 0; code
  signature verified; Team `78GZXS97G6`, application identifier
  `78GZXS97G6.com.n1cxltine.sosapp`, profile expiry 10 November 2026; CoreDevice
  update-in-place install exit 0 and installed package reports `0.1.0` code `1`.
- Android launch command exit 0.
- iPhone launch command was blocked by CoreDevice because the device was locked.
  No app crash was established. Unlock the iPhone and open the app from its
  Home Screen icon before physical BLE testing begins.

## Q-703 latest build installation — 3 November 2026

- Android Debug rebuilt from current Q-703 source: `build/app/outputs/flutter-apk/app-debug.apk`, build exit 0. `adb install -r` exit 0; package `com.n1cxltine.sosapp`, version `0.1.0` code `1`; launch exit 0 and process observed.
- iOS Profile rebuilt from current Q-703 source: `build/ios/iphoneos/Runner.app`, build exit 0. CoreDevice update-in-place install exit 0; bundle `com.n1cxltine.sosapp`, version `0.1.0` code `1`; `devicectl process launch` exit 0 and process observed.
- Existing app data was preserved; no uninstall, clear-data, or reset operation was used.
- BLE Test visibility and adapter state still require operator confirmation inside each running app. Bluetooth Off→On recovery remains `NOT RUN`.

## Q-703 physical retest evidence — operator report, 3 November 2026

| Check | Result | Notes |
|---|---|---|
| Initialization | PASS | Completed on both devices. |
| Discovery | PASS | Peer device was discovered. |
| Initial Connect | PASS | Connect completed. |
| Disconnect | PASS | Disconnect completed. |
| Reconnect cycles 1–3 | PASS | All three reconnects completed. |
| Leave/return BLE screen | PARTIAL | Discovered list disappeared after leaving without an explicit disconnect; no crash reported. Re-discovery is required when the screen starts a new scan session. |
| Bluetooth Off | PASS | Connection transitioned to disconnected. |
| Bluetooth On | PASS | Adapter became available; no automatic connection was claimed. |
| Fresh explicit reconnect | PASS | After Bluetooth was enabled again, selecting the peer and connecting succeeded. |
| UI convergence | FAIL/PARTIAL | Sometimes the initiator showed Connected while the peer UI did not, although a test message reached the peer. Transport reachability is not accepted as proof of UI state convergence. |

Q-703 is therefore `PARTIAL / ACCEPTANCE-INCOMPLETE`. Adapter recovery and
explicit reconnect are physically verified. The remaining defect is
UI/session-state synchronization or event delivery, not proof that the BLE
transport failed. Capture sanitized event order (`connecting`, `connected`,
`disconnected`, adapter state) from both devices for one mismatch before making
another source change.

## Q-703 operator evidence — 3 November 2026

- Baseline initialization/discovery: operator reports normal connection and
  Connect action succeeds on the devices.
- Repeated alternating disconnect/connect: `FAIL (reproducible symptom,
  root cause unresolved)`. One device reports connected while the other still
  reports disconnected when the roles are alternated. This is not accepted as
  a healthy lifecycle result and must not be generalized to BLE reliability.
- Bluetooth Off→On recovery: `NOT RUN`.
- No Chat, Location, or SOS data was sent during this lifecycle attempt.

Required follow-up: capture sanitized coordinator/native event order for one
disconnect/connect mismatch, then run the Bluetooth Off→On recovery case. Keep
Q-703 acceptance-incomplete until both sides converge after reconnect and no
stale callback/listener is observed.

## Adapter-state contract (Q-703)

| Adapter event | Session contract |
|---|---|
| `poweredOn` | Discovery and an explicit selected-peer connection are allowed; no peer is reported connected solely from this event. |
| `poweredOff` | Connected/connecting/ready sessions are invalidated and exposed as disconnected/unavailable. Pending writes become retryable; no automatic arbitrary-peer connection is started. |
| `unauthorized` / `unsupported` | Operations are blocked and permission/capability state is surfaced. |
| `resetting` / `unknown` | Operations wait until a stable `poweredOn`; stale callbacks cannot restore Connected. |

Ownership: native CoreBluetooth/GATT owns adapter and native session cleanup;
the Dart coordinator owns peer/session invalidation and durable retry state; the
UI renders adapter availability separately from peer Connected state. Recovery
requires a fresh explicit peer selection and identity validation.

## Q-703 regression investigation — 3 November 2026

### Historical baseline

The strongest dated source reference is validation lineage `144f1cf` (22
October 2026) with preserved working-tree changes. Existing Phase 7 records
document successful fresh-process discovery and GATT readiness after a restart,
but do not identify an immutable commit containing a complete Bluetooth
Off→On/reconnect pass. Therefore a precise “last good commit” for this scenario
cannot be established.

### Current source evidence

- `ios/Runner/BleTransport.swift::centralManagerDidUpdateState` emits only the
  adapter state. For `poweredOff` it does not clear `connected`, `connecting`,
  `ready`, services, or pending writes, and it does not emit a peer
  `disconnected` event.
- `lib/features/nearby_ble/data/sos_ble_coordinator.dart::_onEvent` handles
  powered-off/unauthorized/resetting by notifying presence loss only; it does
  not clear peer sessions or schedule automatic reconnect on powered-on.
- iOS `didDisconnectPeripheral` does clear the session, but the physical
  Bluetooth-off symptom can bypass that callback, leaving stale UI state and a
  later manual connect blocked by the existing `connecting/ready` guard.
- Android has explicit GATT cleanup and stale-callback guards in
  `BleTransportBridge.kt`; no equivalent adapter-state cleanup was proven from
  the current physical run.

### Attribution

The physical symptom is **confirmed as a current lifecycle defect** (stale
state/no recovery path), but **not confirmed as a regression caused by later
SOS/Chat/Location/Relay work**. The same iOS adapter-state gap is present in the
historical `144f1cf` source, and the historical pass did not cover this case.
No production code was changed during this investigation.

### Missing automated coverage

Current Dart lifecycle tests cover concurrent startup, disposal while startup is
pending, disconnect cleanup, stale frame/session handling, and auth-session
replacement. They do not exercise a native `centralState=poweredOff` event
followed by `poweredOn`, nor assert that all connected peers are cleared and
reconnect is serialized. Native callback injection on real iOS/Android radios
is also not covered.

### Recommended minimal next action

Add a platform-agnostic adapter-state transition contract first: powered-off
must invalidate connected/connecting/ready sessions and emit a deterministic
disconnect/retryable state; powered-on may reconnect only through the existing
coordinator/transport path. Implement platform-specific cleanup only after a
focused regression test and sanitized native event trace define the expected
ordering. Do not change UUIDs, wire format, identity checks, or retry policy.

## Q-703B peer-state convergence investigation — 3 November 2026

This was a read-only investigation; no production source was changed in this
pass.

### Event-path trace

1. Native CoreBluetooth/GATT emits `connected` only after GATT setup is ready
   (`ios/Runner/BleTransport.swift:548-555`); Android emits the equivalent
   event after the notification descriptor is enabled
   (`BleTransportBridge.kt:917-924`). Both platforms emit separate
   `role=central` and `role=peripheral` events.
2. `BleTransport` maintains its connected snapshot using `peer|role`
   (`lib/features/nearby_ble/data/ble_transport.dart:214-229`). A new
   subscriber receives connected snapshots, but discovery results are not
   snapshotted.
3. `SosBleCoordinator._onEvent` keeps connected roles as a set per peer and
   removes only the role named by a disconnect
   (`lib/features/nearby_ble/data/sos_ble_coordinator.dart:771-801`).
4. `BleTestPage._handleEvent` writes `_states[peer]` for both roles
   (`lib/features/nearby_ble/presentation/ble_test_page.dart:129-163`). A
   disconnect for one role can therefore overwrite a still-live other role.
   `_phase` is also one global field for all peers/roles
   (`ble_test_page.dart:116-120`).

### Evidence and classification

The retained Android log
`/tmp/off_grid_sos_device_validation/relay_abc_2026-11-01/retest_after_serial_gate/android_b_retry_logcat.txt`
shows same-peer role-distinct events: peripheral `connected` followed by
central `connected` around lines 182725–183486, and later peripheral then
central `disconnected` around lines 189469–189535. Raw identifiers are not
reproduced here. This proves the event ordering exists in the deployed build,
not what the remote device rendered.

| Finding | Classification |
|---|---|
| Native/coordinator sessions are role-aware | **CONFIRMED** |
| BLE Debug UI conflates roles by peer ID | **CONFIRMED** (source) |
| Conflation can create a stale Connected/disconnected label while transport remains usable | **LIKELY** explanation of the report |
| Platform event loss/reordering caused the cross-device mismatch | **UNPROVEN** |
| Asymmetry is legitimate BLE role semantics rather than a UI defect | **UNPROVEN** |

The current diagnostics do not emit structured sanitized session tokens,
`stale_callback_rejected`, or `ui_state_changed` records. A paired Samsung and
iPhone event timeline for the exact mismatch is therefore **NOT RUN**; no
temporary instrumentation was added under the no-source-change constraint.

### Proposed narrow fix (not implemented)

Make the diagnostic UI state key role-aware, or derive an aggregate state from
the transport's role-aware snapshot. Add widget tests for central-connected plus
peripheral-disconnect, the inverse, both roles disconnected, and navigation
resubscription. Preserve coordinator semantics and the wire protocol.

Q-703 remains `PARTIAL / ACCEPTANCE-INCOMPLETE`; Release Gate remains blocked.

## Q-703B UI remediation — 3 November 2026

Implemented the narrow UI-layer fix in `BleTestPage` only. Connection state is
now stored as `peer|role`; the aggregate row remains `connected` when either
role is connected and explicitly shows `connected (central + peripheral)` when
both roles are active. A disconnect from one role no longer clears the other.
Connected snapshots are allowed to restore a device row when the screen is
reopened; no native transport or coordinator changes were made.

Automated widget coverage now includes role-isolated disconnects, both-role
aggregation, both-role terminal disconnect, and connected snapshot restoration.
Physical revalidation on Samsung and iPhone is **NOT RUN** after this patch.
Q-703 remains `PARTIAL / ACCEPTANCE-INCOMPLETE` pending paired physical
convergence evidence.

### Q-703B iPhone installation — 3 November 2026

- iPhone 15 Plus CoreDevice `34C42BBC-86F2-556C-BADE-FA93AC140910` was
  available and paired.
- `build/ios/iphoneos/Runner.app` verified as
  `com.n1cxltine.sosapp`, version `0.1.0` (build `1`), TeamIdentifier
  `78GZXS97G6`, and a valid code signature. Embedded development profile
  expiry: 10 November 2026 UTC.
- CoreDevice update-in-place install completed successfully; no uninstall or
  data clear was used. CoreDevice launch completed successfully.
- Home-screen data persistence and BLE menu visibility require operator
  confirmation; physical Q-703B lifecycle/convergence remains **NOT RUN**.

### Q-703B physical revalidation — operator report

- Android and iPhone were updated in place; the operator confirmed launch,
  preserved data, and BLE Test visibility on both devices.
- Discovery, connect/disconnect, three reconnect cycles, navigation away/back,
  and Bluetooth Off→On followed by explicit reconnect were reported as passing.
- Status: **DEVICE-VERIFIED (operator-reported)**. No paired sanitized event
  log or screenshot was supplied in this turn; no SOS, Chat, or Location
  traffic was sent.

## Q-707 Stage A — Samsung ↔ iPhone direct BLE — operator evidence

- Samsung SM-A536E discovery: **PASS**
- iPhone 15 Plus discovery: **PASS**
- Initial connect: **PASS**; both devices displayed `Connected`
- Disconnect: **PASS**; both devices displayed `Disconnected`
- Reconnect: **PASS**
- Cross-device state mismatch: **NOT OBSERVED**
- No SOS, Chat or Location payload was sent during this stage.

Stage A is **PHYSICAL PASS (operator-reported)**. Stage B remains pending
explicit operator confirmation.
