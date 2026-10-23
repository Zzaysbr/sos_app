# Phase 8 — Physical Reliability and BLE Range Validation

Date: 22 October 2026 (Asia/Bangkok). **Release gate: BLOCKED.**

## Preflight

The working tree contains the preserved Phase 7 reliability/range changes and
has no whitespace errors. Current automated evidence reports 211 full tests,
117 focused BLE reliability/range tests, analyzer success and successful Android
debug and unsigned iOS debug builds. Phase 7 device evidence passes normal
Android↔iPhone SOS and Chat in both directions, Android→iPhone Location and
reopen/reconnect retention. Those observations are historical and are not new
Phase 8 executions.

The range diagnostic correctly separates native write acceptance from a valid
selected-peer application ACK. Wrong-peer, late and duplicate ACKs do not
increment acknowledgement; native failures, timeout and pending states remain
separate. RSSI is the latest discovery result and is not converted to distance.

Phase 8.1 diagnostics found no Android in ADB. They did find an iPhone 15 Plus
on iOS 27.0.1: CoreDevice reports paired, Developer Mode enabled and a connected
tunnel; `xcdevice` and the Runner scheme both report it available. App version
0.1.0+1 is installed. The apparent Flutter `-27` warning belongs to a second,
unavailable iPhone 13 record with the same device name, not to the available
iPhone 15 Plus. With only one usable endpoint, no new two-device Phase 8
physical scenario satisfies its PASS criteria.

## Test matrix

| ID | Scenario | Status | Evidence / blocker |
| --- | --- | --- | --- |
| P8-A01 | ACK loss/delayed/wrong-peer/dedup automated coverage | PASS | Corrected focused suite: 138 passed, exit 0 |
| P8-P01 | Controlled production application-ACK loss | NOT RUN | No post-persistence ACK-suppression harness |
| P8-P02 | Wrong-peer ACK injection | NOT RUN | Third peer/native injector unavailable |
| P8-P03 | Close app while pending | NOT RUN | No second endpoint; ADB list empty |
| P8-P04 | Process restart/reconnect recovery | NOT RUN | Automated coverage is not physical evidence |
| P8-P05 | Android A ↔ Android B | NOT RUN | Second Android unavailable |
| P8-P06 | iOS permission revoke/regrant | NOT RUN | iPhone is ready; Android peer absent, so post-regrant ACK cannot be proven |
| P8-P07 | 5–50 m open range matrix | NOT RUN | No field run |
| P8-P08 | 5–50 m obstructed range matrix | NOT RUN | No field run |
| P8-R01 | Phase 7 Android↔iPhone normal SOS/Chat/Location | PASS (historical) | `validation/week5/physical-final.json`; preserved, not rerun |
| P8-R02 | Guest/account isolation regression review | PASS (automated/historical) | No ownership/schema/rules change; current rerun pending below |

Detailed preconditions, evidence and pass/fail rules are in
`PHASE_8_PHYSICAL_TEST_RUNBOOK.md`.

## Automated validation

Results will be recorded here only after each command exits. Physical status is
never inferred from these commands.

| Command | Exit | Result |
| --- | ---: | --- |
| Focused BLE reliability/range/ownership tests | 0 | 138 passed |
| Initial focused invocation | 1 | Test selector named a nonexistent `test/sos_sync_queue_test.dart`; 129 loaded tests passed; corrected command above is authoritative |
| `flutter test` | 0 | 211 passed |
| `flutter analyze lib test` | 0 | No issues found |
| `flutter build apk --debug --no-pub` | 0 | Gradle 7.0s |
| `flutter build ios --debug --no-codesign --no-pub` | 0 | Xcode 10.0s; unsigned device build |
| `git diff --check` | 0 | No whitespace errors after final report update |

Phase 8.1 rerun: focused 138 passed (exit 0), full 211 passed (exit 0),
analyzer exit 0, Android debug build exit 0 (Gradle 2.059s), unsigned iOS debug
build exit 0 (Xcode 7.1s). Final diff check is recorded after these report edits.

## Device-connectivity diagnosis (Phase 8.1)

| Command | Exit | Finding |
| --- | ---: | --- |
| `flutter devices --device-timeout 10` | 0 | iPhone 15 Plus shown; no Android; warning also reports a separate unavailable iPhone record |
| `adb devices -l` | 0 | Empty device list, confirmed twice |
| `xcrun devicectl list devices` | 0 | iPhone 15 Plus connected; separate iPhone 13 unavailable |
| `xcrun xcdevice list` | 0 | iPhone 15 Plus available via USB; iPhone 13 has `com.apple.dt.deviceprep` code -27 |
| `xcrun devicectl device info details` | 0 | iPhone 15 Plus paired, Developer Mode enabled, tunnel connected |
| `xcodebuild -showdestinations` | 0 | iPhone 15 Plus is a Runner destination |
| `flutter doctor -v` | 0 | Flutter/Android/Xcode toolchains pass; Xcode 26.6 |
| `system_profiler SPUSBDataType` | 0 | No USB inventory emitted in this shell; not used to override CoreDevice evidence |

The first sandboxed ADB attempt exited 1 because it could not open the local ADB
socket. A rerun outside the sandbox exited 0 with an empty list. Similarly,
sandboxed `devicectl` timed out and sandboxed `xctrace` aborted because it could
not write its cache. Their successful unrestricted read-only reruns are the
authoritative device results, not application failures.

Safe recovery is to reconnect/unlock Android, select a data-capable USB mode,
accept the existing host's USB-debugging prompt if shown, then require a
non-empty `adb devices -l` result before installing with update-in-place
semantics. No app data, pairing record or device setting was reset.

## Current blockers

1. Recover Android A visibility in ADB, then install the current APK with
   update-in-place semantics. iPhone 15 Plus connectivity itself is recovered;
   its currently installed app is version 0.1.0+1.
2. Obtain Android B for Android↔Android.
3. Obtain a third controlled peer/native injector for wrong-peer ACK.
4. Provide a controlled post-persistence production ACK-suppression harness;
   Bluetooth-off does not prove this case.
5. Complete iOS permission and range field runs.
6. Production free map configuration and signed App Store/release validation
   remain separate existing blockers. Offline tiles remain absent.

No production defect was reproduced during the automated audit. Guest scope,
sync ownership, stable incident identity, bounded retry, duplicate persistence,
wrong-peer rejection and file-backed recovery tests all pass. No BLE UUID,
production message kind, database schema, Firebase Rule, ownership behavior,
dependency or map fallback was changed in Phase 8 preparation.

