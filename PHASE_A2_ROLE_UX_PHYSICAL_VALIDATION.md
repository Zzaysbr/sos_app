# Phase A2 — Role UX Physical Validation

Date: 23 October 2026 (Asia/Bangkok)
Source baseline: `8e2b5ad` plus the preserved Role UX working tree
Release Gate: **BLOCKED**

## Code-level result

One reproducible defect was fixed. `_sendSos()` previously set its in-flight
guard after two asynchronous duplicate checks. Two rapid actions could both
enter the checks before the guard became true. The guard is now set before the
first await and is released in the existing `finally` block, including active
incident, error, cancellation and disposal paths.

Regression coverage now verifies:

- rapid repeated SOS actions start one submission;
- switching Need Help → Rescue → Need Help preserves the active SOS, Chat row,
  queued SOS delivery and queued Location update;
- returning from Rescue opens the original active incident;
- Rescue intersects durable BLE inbox IDs with the current owner-scoped SOS
  query and does not display another owner's received SOS;
- repeated/concurrent Rescue accept remains idempotent;
- application ACK copy does not claim human acceptance or rescue arrival;
- Light and Dark semantic text pairs meet WCAG AA contrast and System theme
  follows platform brightness without changing the selected role.

Existing suites cover stale/expired shared location, missing coordinates,
provider/network failure, Guest non-upload, login failure/cancel, A/B isolation,
session route reset, durable queue restart, retry, duplicate delivery and
wrong-peer ACK rejection.

## Current devices and deployment

| Item | Fresh observation | Classification |
| --- | --- | --- |
| Android | Samsung SM A536E, Android 14/API 34; ADB state `device` | AVAILABLE |
| iPhone | iPhone 15 Plus, iOS 27.0.1; CoreDevice connected | AVAILABLE |
| Second Android | Not detected by Flutter or ADB | UNAVAILABLE |
| Android current debug build | Installed with `adb install -r`; exit 0; data not cleared | PREPARATION PASS |
| iOS current development-signed debug build | Installed through CoreDevice; exit 0; data not cleared | PREPARATION PASS |
| App launch | Both bundle IDs launched successfully | PREPARATION PASS |
| Android interactive state | Device was on the lock screen when accessibility hierarchy was captured | PHYSICAL BLOCKER |

Deployment and launch do not prove SOS delivery, application ACK, persistence,
role switching or BLE behavior. No row below is promoted from historical Phase
7 evidence or automated tests.

## Fresh physical matrix

| ID | Test and pass criteria | Status | Fresh evidence / blocker |
| --- | --- | --- | --- |
| A2-P01 | Android → iPhone SOS: receiver persists exactly one row and selected-peer application ACK changes sender state | NOT RUN | No coordinated unlocked interaction or correlated sender/receiver log |
| A2-P02 | iPhone → Android SOS with the same criteria | NOT RUN | No coordinated unlocked interaction or correlated log |
| A2-P03 | Android A ↔ Android B in both directions | NOT RUN | Second Android unavailable |
| A2-P04 | Switch role with active SOS and pending outbox; return restores the same incident/IDs/states | NOT RUN | Current builds installed, but device interaction/evidence not executed |
| A2-P05 | Close/restart/reconnect while pending; same message ID retries and receiver keeps one row | NOT RUN | Requires controlled receiver unavailability and logs |
| A2-P06 | Chat in both roles/directions reaches Delivered only after matching application ACK | NOT RUN | No fresh BLE session |
| A2-P07 | Shared Location in both roles: initial/subsequent update, stale state, Stop, permission recovery | NOT RUN | No fresh BLE/location session |
| A2-P08 | Duplicate delivery is stored once and re-ACKed | NOT RUN | No controlled replay evidence |
| A2-P09 | First ACK suppressed after persistence; native write is not delivery and retry succeeds | NOT RUN | Approved one-shot debug harness not available |
| A2-P10 | Wrong peer sends matching ACK; sender remains pending until selected peer ACKs | NOT RUN | Distinct third peer/injector unavailable |
| A2-P11 | iOS Bluetooth permission revoke/regrant has no false Connected/Delivered state | NOT RUN | Requires manual Settings interaction and active peer |
| A2-P12 | Firebase session expiry, denied/offline write and exactly-once recovery | NOT RUN | Requires controlled admin action and redacted Firestore evidence |
| A2-P13 | Guest restart/login/logout/A→B/failed-login isolation on current build | NOT RUN | Current builds installed; transition session not executed |
| A2-P14 | BLE range at 5/10/20/30/50 m, three runs, open and obstructed | NOT RUN | Suitable measured site and coordinated session not available |

## Concise manual session order

1. Unlock both installed devices, confirm previous local-history counts and
   record Light/Dark/System role screens without personal content.
2. Run A2-P04 first: create one synthetic Guest SOS and pending Chat, switch to
   Rescue, return through the active-SOS banner and compare incident/message
   IDs and queue states before/after restart.
3. Run A2-P01/P02, then Chat and Location in each direction. Capture enqueue,
   receiver persistence, ACK emission and sender acknowledgement. Native write
   success alone is insufficient.
4. Run duplicate and restart/reconnect. Use the same message ID and require one
   receiver row.
5. Execute permission recovery. Restore Bluetooth, Nearby and Location
   permissions afterward.
6. Run Guest/account and Firebase recovery with synthetic accounts/data.
7. Add Android B before A2-P03 and a distinct injector/approved one-shot harness
   before A2-P09/P10. Complete range measurements last.
8. Stop sharing/scanning/advertising, restore permissions/network, and record
   remaining pending rows. Never uninstall or clear app data to recover.

Raw device logs must remain outside source control. Committed evidence may
contain only redacted device aliases, timestamps, states and counts—never
credentials, tokens, serials, installation IDs or coordinates.
