# Phase 10 — Release Identity, Signing & Configuration Audit

Date: 23 October 2026 (Asia/Bangkok). **Release gate: BLOCKED.**

This audit preserves the current application identifiers and signing identities.
It does not claim a signed release, live production-map verification, or completion
of the outstanding physical reliability matrix.

## Application identity

| Platform | Current production application identity | Configuration references | Firebase registration |
| --- | --- | --- | --- |
| Android | `com.example.sos_app` | `android/app/build.gradle.kts` namespace/application ID, `MainActivity.kt`, generated APK manifest, release checklist/user-agent examples | `android/app/google-services.json` contains the matching Android client in project `sos-app-d811a` |
| iOS | `com.n1cxltine.sosapp` | Runner Debug/Profile/Release build settings, built Runner Info.plist | `ios/Runner/GoogleService-Info.plist` contains the matching iOS client in project `sos-app-d811a` |

`com.example.sosApp.RunnerTests` identifies the iOS test bundle only. It is not
the shipped Runner identity. The configured Apple development team is
`78GZXS97G6`; this is project metadata and does not prove that a usable
distribution certificate or profile is installed.

Changing Android identity requires a new Firebase Android registration and
`google-services.json`, a matching Play Console app record, signing/service
associations, and review of links and provider restrictions. Android treats a
new application ID as a separate app, so it cannot update the installed
`com.example.sos_app` package and cannot automatically access that package's
local Drift/Guest data.

Changing iOS identity requires a new Firebase iOS registration and
`GoogleService-Info.plist`, an Apple App ID with matching capabilities,
provisioning profiles, an App Store Connect record, and updated provider
restrictions. It also creates a separate app container unless an explicit,
reviewed migration mechanism is designed.

### Recommendation and owner decision

Do not change either identifier during this audit. Before the first public store
record is created, the owner must choose one of these paths:

1. Standardize Android to an account-owned reverse-DNS identifier, with
   `com.n1cxltine.sosapp` as the current candidate. This is recommended for
   production branding if the owner accepts the new Android app identity and
   completes Firebase, Play and local-data continuity work before release.
2. Keep the current platform-specific identifiers to preserve Android
   update-in-place and existing installation data. This makes
   `com.example.sos_app` the permanent Play identity and must be an explicit
   owner decision.

Platform identifiers do not have to match. No identifier should be edited until
that decision, registrations and continuity plan are ready together.

## Signing readiness

### Android

Release tasks load `android/key.properties` and require `storeFile`,
`storePassword`, `keyAlias` and `keyPassword`. The ignored properties file and
account-owned keystore are absent. There is no debug-signing fallback.

Two fail-safe checks were completed:

- With signing properties absent, `flutter build appbundle --release --no-pub`
  exited `1` at the explicit configuration guard and created no release AAB.
- With synthetic ignored properties pointing to a nonexistent keystore, the
  release task exited `1` at Gradle `validateSigningRelease` and created no AAB.
  The temporary properties were removed; no key or password was generated or
  recorded.

A signed Android release is **NOT RUN**. The owner must supply the upload
keystore and ignored properties, protect and back them up, then inspect the
certificate identity and artifact digest after a successful signed build.

### iOS

The effective generic-device Release settings use bundle ID
`com.n1cxltine.sosapp`, development team `78GZXS97G6`, build `1`, and an
`iPhone Developer` identity. There is no checked-in `ExportOptions.plist`, and
the repository does not establish a distribution provisioning mode, valid Apple
Distribution certificate, App Store profile, or App Store Connect record.

`flutter build ios --release --no-codesign --no-pub` exited `0` and produced an
unsigned `Runner.app` (`0.1.0+1`, 52.2 MB). `codesign` correctly reports that it
is not signed. This proves compilation only. A signed iOS archive/export is
**NOT RUN**.

The owner must choose automatic or manual distribution signing, confirm the
App ID/capabilities and App Store Connect access, create the matching profile
or allow Xcode to manage it, then archive and inspect the signed artifact.

## Production map configuration

All three build values reach `MapTileProviderConfig` through compile-time Dart
defines: `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, and `MAP_TILE_USER_AGENT`.
Release validation fails closed for missing configuration, invalid HTTPS tile
templates, empty attribution/user-agent, the public OSM tile service, and now a
Geoapify URL without a non-empty `apiKey` query value. Validation messages do
not echo the URL or credential.

Incident and shared-location coordinates remain available when configuration
is invalid or tile loading fails. Tests cover missing/invalid configuration,
provider and network failure, coordinate/marker retention, visible attribution,
and synthetic injected defines. There is no public OSM release fallback and no
offline-tile implementation.

No account-owned Geoapify key is available in the repository or environment, so
live runtime verification is **NOT RUN**. The owner must create and restrict a
Geoapify Free project key and pass it in an ignored temporary JSON file:

```sh
flutter build appbundle --release \
  --dart-define-from-file=/private/path/map.release.json
```

The JSON must contain the Geoapify HTTPS template with `{z}`, `{x}`, `{y}` and
`apiKey`, the required Geoapify/OpenStreetMap attribution, and the final
application user-agent identity. Do not commit the file or print its contents.

## Regression and platform findings

- Guest retention, failed/cancelled Login, account A/B isolation, session-route
  reset, sync-queue ownership, BLE stable identity, retry and deduplication pass
  the focused and full automated suites. No ownership/schema/rules change was
  justified.
- iOS had duplicate local-network and Bonjour plist keys. The single merged
  configuration now retains `_mp-connection._tcp`, `_sosapp._tcp`, and
  `_sosapp._udp`; `plutil -lint` passes. This preserves both the local
  nearby-connections plugin service and SOS services.
- The current Android Kotlin/Gradle warning is a future compatibility warning.
  Debug compilation succeeds; it is tracked and does not justify a dependency
  or architecture change in this phase.

## Validation results

| Check | Result | Exit / evidence |
| --- | --- | --- |
| Focused map/incident/Guest/auth/SOS/BLE suite | PASS | exit `0`, 103 tests |
| Full `flutter test` | PASS | exit `0`, 212 tests |
| `flutter analyze lib test` | PASS | exit `0`, no issues |
| Android debug APK | PASS | exit `0`, `com.example.sos_app`, `0.1.0+1`, SHA-256 `272f368754fd1c4b0160a431eb37f2d5c6fe041a93f98ac4d51ded47d3b3c2ec` |
| iOS debug no-codesign | PASS | exit `0`, Xcode 266.0 s, `com.n1cxltine.sosapp`, `0.1.0+1`, unsigned as requested |
| iOS release no-codesign | PASS (compile only) | exit `0`, Xcode 342.7 s, unsigned Runner.app |
| Android missing signing guard | PASS | expected build exit `1`; no AAB |
| Android invalid keystore guard | PASS | expected build exit `1`; no AAB |
| `git diff --check` | PASS | exit `0` |
| Signed Android release | NOT RUN | owner keystore/properties absent |
| Signed iOS archive/export | NOT RUN | distribution prerequisites unverified |
| Live Geoapify release runtime | NOT RUN | account-owned key/config absent |
| Outstanding physical reliability/range tests | NOT RUN | required devices/session evidence incomplete |

## Remaining release blockers and owner actions

1. Decide the permanent Android and iOS application identifiers before creating
   store records or provider restrictions.
2. Supply Android upload signing material through ignored local files and build,
   inspect and retain a signed AAB.
3. Confirm iOS distribution signing/App Store Connect access and produce and
   inspect a signed archive/export.
4. Create and restrict an account-owned Geoapify Free key, inject it without
   logging it, and complete live success/failure/network-loss verification.
5. Complete every NOT RUN physical reliability, Android-to-Android, permission,
   ACK fault-injection and range row in the physical session checklist.
6. Perform the controlled live Firebase session-expiry/cloud-retry checks still
   listed in the release checklist.

The Release Gate remains **BLOCKED** until these external and physical items
have recorded evidence.
