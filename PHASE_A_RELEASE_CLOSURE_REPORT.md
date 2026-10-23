# Phase A — Release Closure Report

Date: 23 October 2026 (Asia/Bangkok)  
Source: `144f1cf` with preserved Phase 7–10 working-tree changes  
Release gate: **BLOCKED**

Phase A closed the repository-level release defects currently supported by
evidence. It did not change application identifiers, Firebase registrations,
BLE UUIDs/wire kinds, database schema, Firebase Rules, dependencies or
ownership semantics. Historical device results remain historical; no physical
test is promoted to PASS for this build.

## Blocker table

| Blocker | Current evidence | Actual status | Risk and impact | Exact next action | Claude can complete without owner |
| --- | --- | --- | --- | --- | --- |
| Permanent application identities | Android is `com.example.sos_app`; iOS is `com.n1cxltine.sosapp`; Firebase clients match. No repository tag, store metadata or distribution record proves whether either app has been distributed | NEEDS MANUAL ACTION | CRITICAL: changing an ID creates a new store/Firebase identity and Android/iOS data container; installed Guest history will not migrate automatically | Owner confirms distribution history and selects the permanent IDs before any edit or store registration | No |
| Android release signing | Release build has no debug fallback. Missing config exits `1` before creating an AAB. No keystore or `key.properties` exists | NEEDS MANUAL ACTION | CRITICAL: no installable/verifiable Play release artifact | Owner supplies and backs up the upload keystore plus ignored properties; then build and inspect a signed AAB | No |
| Apple distribution signing | Debug and Release compile with `--no-codesign`; bundle ID is correct. No export options, distribution certificate/profile or App Store evidence exists | NEEDS MANUAL ACTION | CRITICAL: unsigned Runner.app cannot be submitted or treated as a release | Owner confirms Apple team/App Store Connect access and configures automatic or manual distribution signing; archive/export and inspect | No |
| Production map credential/runtime | Defines reach runtime; missing/invalid config, public OSM release use and Geoapify-without-key fail closed; marker/coordinates survive tile failure. No account-owned key is available | NEEDS MANUAL ACTION | HIGH: production map tiles are intentionally unavailable until configured; no offline tiles | Owner creates/restricts a Geoapify Free key, injects it through an ignored define file, and performs success/invalid-key/offline runtime checks | No |
| BLE ACK/retry/dedup/restart logic | Automated tests distinguish native write from app ACK, reject wrong-peer ACKs, deduplicate, persist queue state, and recover same-ID work | PASS | Residual physical/OS risk remains; automation cannot prove radio behavior | Preserve implementation and run the physical matrix on the signed release candidate | Yes for automation; no for physical evidence |
| Physical reliability and range | Phase 7 contains historical Android↔iPhone evidence. Current-build Android↔Android, fault injection, permission recovery and 5–50 m matrices have no fresh device evidence | NOT RUN | CRITICAL: radio, OS lifecycle and range behavior remain unverified | Execute `PHYSICAL_TEST_SESSION_CHECKLIST.md` with two Androids, one iPhone and approved one-shot ACK/wrong-peer controls | No |
| Firebase session expiry/cloud recovery | Automated tests retain queues on cloud failure/account change, clear stale account subscriptions, isolate A/B/Guest, and now verify coordinator retry/session gating | PASS (automated); NOT RUN (live) | HIGH: real token invalidation and Firestore recovery are not proven on the release project/build | Run the controlled live expiry, denied/offline write and exactly-once recovery case with test accounts | No |
| Guest/account isolation | Restart, Login failure/cancel, Login/Logout, A→B isolation, no Guest upload, queue/ownership/timestamp preservation pass automated tests; historical Android checks exist | PASS (automated); NOT RUN (latest physical build) | Device UI/runtime behavior still needs release-candidate confirmation | Repeat the checklist transition case without clearing app data | No for physical evidence |
| Full repository analyzer | `flutter analyze` exits `1` on 32 `info` findings in the vendored nearby-connections package/example; `flutter analyze lib test` exits `0` | FAIL (LOW) | CI using unscoped analyze remains non-green; package API cleanup could destabilize transport | Track upstream/Built-in Kotlin compatible package work separately; do not suppress or mass-refactor the vendored transport during closure | Technically yes, but not safely in this phase |
| Signed release artifacts and store checks | Neither signed AAB nor signed iOS archive exists | NOT RUN | CRITICAL: artifact identity, signature, entitlements and install/update behavior are unverified | Produce signed artifacts after identity/map decisions, then inspect and install update-in-place | No |

## Repository-level changes completed

The accumulated Phase 9–A working tree contains these verified release fixes:

- Android release tasks require account-owned signing properties and cannot
  silently use the debug key.
- Android main manifest declares Internet access for Firebase/map networking.
- `MAP_TILE_*` values are compile-time environment reads; release rejects the
  public OSM tile server and Geoapify URLs without a key.
- iOS has one local-network description and one complete Bonjour service list,
  preserving `_mp-connection._tcp`, `_sosapp._tcp` and `_sosapp._udp`.
- BLE/auth changes already present in the preserved working tree retain stable
  identity, peer binding, persisted ACK semantics, retry and deduplication.
- New `sos_sync_coordinator_test.dart` directly verifies Guest/expired-session
  suppression, network-recovery retry and resumption for a later authenticated
  session. No production change was needed after these tests passed.

## Identity recommendation

No identifier was changed. Before first public distribution, use an
account-owned reverse-DNS Android ID; `com.n1cxltine.sosapp` is the current
candidate if the owner wants aligned platform branding. This requires a new
Firebase Android registration, new Google services file, Play record and
provider restrictions. It also prevents update-in-place over
`com.example.sos_app` and does not inherit that app's local database.

If any Android build has already been distributed and its local continuity must
be retained, keep `com.example.sos_app` permanently. iOS may keep
`com.n1cxltine.sosapp`; platform identifiers do not have to match. The owner
must state distribution history and choose before code, Firebase or store
settings are changed.

## Validation run

| Command/check | Exit | Result |
| --- | ---: | --- |
| Focused release suite | 0 | 108 tests passed |
| `flutter test` | 0 | 215 tests passed |
| `flutter analyze` | 1 | 32 `info` findings, all under vendored nearby-connections package/example |
| `flutter analyze lib test` | 0 | No issues found |
| `flutter build apk --debug --no-pub` | 0 | APK built; Gradle 4.7 s |
| `flutter build ios --debug --no-codesign --no-pub` | 0 | Runner.app built; Xcode 15.7 s; unsigned as requested |
| `flutter build appbundle --release --no-pub` without signing config | 1 expected | Fail-closed guard; no AAB created |
| Synthetic Geoapify define test | 0 | 6 tests passed; synthetic value only |
| `git diff --check` | 0 | Passed after final document/evidence update |

The initial combined format/focused-test attempt exited `1` before any test ran
because the sandbox denied a Flutter SDK-cache write. A following direct-format
attempt was interrupted and is not used as evidence. The authoritative focused
runs listed above completed normally and exited `0`.

Android debug artifact is `com.example.sos_app`, version `0.1.0+1`, SHA-256
`272f368754fd1c4b0160a431eb37f2d5c6fe041a93f98ac4d51ded47d3b3c2ec`.
The iOS no-codesign artifact is `com.n1cxltine.sosapp`, version `0.1.0+1`;
`codesign` reports it is unsigned, as expected.

Secret/config inspection found no private-key file, keystore, signing properties,
ExportOptions file or account-owned map key. The source contains the expected
Firebase client configuration and Gradle property-name references; neither is a
production signing secret. Actual signing/map credentials must remain outside
source control and command logs.

## Gate decision

Repository-level automated behavior is stable, but Phase A cannot close the
release gate without owner identity decisions, production map configuration,
signed artifacts and current-build physical evidence. The project is **not
release-ready**.
