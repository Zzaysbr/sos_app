# Phase 8 — Bug and Blocker Log

Date: 22 October 2026

## P8-ENV-01 — Android endpoint unavailable to the host

- Reproduce: run `flutter devices` from the current workspace.
- Actual: unrestricted `adb devices -l` exits 0 with an empty list. iPhone 15
  Plus/iOS 27.0.1 is paired, Developer Mode enabled, tunnel connected and is an
  available Runner destination. The `-27` error is attached to a separate
  unavailable iPhone 13 record that shares the same display name.
- Impact: no new Phase 8 physical fault, permission or range result can be
  recorded. Existing Phase 7 evidence remains historical only.
- Status: **BLOCKED BY DEVICE ACCESS**, not an application defect.
- Recovery: connect/unlock Android with a data-capable cable/mode, accept USB
  debugging for the existing host if prompted, and require a non-empty ADB
  inventory before update-in-place installation. Do not reset either iPhone's
  pairing merely to remove the unavailable record; it does not block the available
  iPhone 15 Plus.

## P8-ENV-02 — Sandboxed device tools cannot establish authoritative state

- Reproduce: run ADB/CoreDevice/Instruments under the restricted workspace
  sandbox.
- Actual: ADB cannot bind its localhost smart socket; CoreDevice initialization
  times out; Instruments cannot create its cache and aborts.
- Verification: the same read-only diagnostics outside the sandbox exit 0.
- Status: **ENVIRONMENT CLASSIFICATION COMPLETE**. These failures are host
  sandbox constraints and are not app, pairing or physical-test failures.

## P8-VAL-01 — Initial focused command referenced a missing test file

- Reproduce: include `test/sos_sync_queue_test.dart` in the focused command.
- Actual: Flutter exits 1 because that path does not exist; 129 tests that did
  load passed.
- Correction: ownership/sync coverage is in `test/sos_repository_test.dart` and
  `test/guest_continuity_test.dart`. The corrected focused command passes 138
  tests with exit 0.
- Status: **PROCEDURAL ERROR CORRECTED**. No test was deleted, skipped or
  weakened, and this is not counted as an app failure.

## P8-RISK-01 — Future Kotlin build compatibility warning

- Android debug build exits 0, but Flutter warns that `firebase_auth`,
  `firebase_core` and `flutter_nearby_connections_plus` still apply the Kotlin
  Gradle Plugin and a future Flutter version will require Built-in Kotlin.
- Status: **OPEN MAINTENANCE RISK**. It does not fail the current build and no
  dependency upgrade is justified inside this physical-validation phase.

## Application defect result

No new reproducible production defect was found. Automated Guest isolation,
ownership, identity binding, retry, ACK validation, deduplication, process
restart and range-statistics behavior remain passing. Physical cases stay NOT
RUN until their prerequisites are available.

## Phase 9 release-configuration findings

### P9-MAP-01 — Injected map configuration fell back to development tiles

- Reproduce: run `map_tile_provider_test.dart` with synthetic `MAP_TILE_*`
  Dart defines.
- Actual before fix: the test process saw the define, but
  `MapTileProviderConfig.fromEnvironment()` returned the development fallback.
- Root cause: environment constructors were not evaluated as compile-time
  constants inside the factory.
- Fix: use const environment reads, retaining release validation and
  credential-safe errors. Synthetic define rerun passes 5 tests, exit 0.
- Status: **FIXED (AUTOMATED)**. Live provider/key runtime remains NOT RUN.

### P9-REL-01 — Android release used the debug signing key

- Actual before fix: the release build type explicitly selected the debug
  signing configuration.
- Fix: load only the ignored account-owned signing properties and fail release
  tasks when any property is absent. Debug builds remain available.
- Evidence: unsigned/unconfigured `bundleRelease` exits 1 with the intentional
  signing prerequisite message; no false signed artifact is produced.
- Status: **FIXED GUARD; SIGNED RELEASE NOT RUN**.

### P9-REL-02 — Android release networking permission was missing

- Actual before fix: `INTERNET` appeared only in debug/profile manifests.
- Impact: a release could not reliably use Firebase or production map tiles.
- Fix: declare `INTERNET` in the main manifest. Final debug APK inspection
  confirms Internet and Bluetooth/location permissions are merged.
- Status: **FIXED (BUILD INSPECTION)**; signed release runtime remains NOT RUN.

### P9-BLOCK-01 — External release assets and identity decision

- Geoapify account-owned key/config is absent.
- Android upload keystore/properties and iOS distribution/export prerequisites
  are absent or unverified.
- Android `com.example.sos_app` and iOS `com.n1cxltine.sosapp` differ.
- Status: **OWNER ACTION REQUIRED** before store submission or live map gate.

