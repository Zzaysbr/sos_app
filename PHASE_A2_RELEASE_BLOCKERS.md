# Phase A2 — Release Blockers

Date: 23 October 2026 (Asia/Bangkok)
Release Gate: **BLOCKED**

## Blockers in priority order

### 1. Permanent application identity — owner decision required

- Android application ID and Firebase registration: `com.example.sos_app`.
- iOS Runner bundle ID and Firebase registration: `com.n1cxltine.sosapp`.
- Repository history does not prove Play/App Store records or external
  distribution history.

No identifier was changed. If Android has never left controlled devices, an
account-owned reverse-DNS ID can be adopted only together with a new Firebase
Android registration, Google services file, Play record, key restrictions and
an explicit local-data continuity decision. If update-in-place continuity for
the existing Android container is required, the current ID must be retained.

### 2. Signed release artifacts — external credentials required

Android has no `android/key.properties` or account-owned upload keystore. The
release task fails closed with exit 1 and creates no AAB. The current APK is
debug-signed (`CN=Android Debug`) and is not a release candidate.

iOS has no `ExportOptions.plist` or repository evidence for an Apple
Distribution certificate, App Store profile or App Store Connect record. The
installed current build is development-signed for team `78GZXS97G6`; the
no-codesign build is unsigned. The development build installed and launched,
but strict host verification reports `CSSMERR_TP_NOT_TRUSTED`. Neither build is
a distribution artifact or proof of an Apple Distribution trust chain.

The owner must supply signing assets outside source control, choose automatic
or manual Apple distribution signing, then produce and inspect the signed AAB
and archive/export. Record artifact/certificate hashes without passwords,
private keys or profiles.

### 3. Production map runtime — account-owned key required

No `MAP_TILE_*` environment configuration or account-owned Geoapify key is
available. Synthetic tests prove the defines reach runtime and that missing
configuration, a Geoapify URL without a key and public OSM release use fail
closed. Coordinates and markers remain available on provider/network failure.

Geoapify's current official pages list a Free tier of 3,000 credits/day with no
credit card and allow production/commercial use within quota when required
Geoapify and data-source attribution is shown. Raster/vector tile requests use
an API key. The owner must create a project/key, apply available restrictions
and quota monitoring, and inject it only through an ignored define file.

References:

- https://www.geoapify.com/pricing/
- https://apidocs.geoapify.com/docs/maps

Live success, denied-key, provider-failure and network-loss checks on the
candidate remain NOT RUN. Offline map tiles are outside this phase and remain
unimplemented.

### 4. Current-build physical evidence — incomplete

Android and iPhone current debug builds were installed update-in-place and
launched, but no fresh coordinated BLE transaction was executed. Android was
locked at the read-only UI check, there is no second Android, and the approved
ACK suppressor/third peer are unavailable. All physical behavior rows remain
NOT RUN in `PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md`.

### 5. Live Firebase recovery — manual controlled action required

Automated tests pass for Guest non-upload, account A/B isolation, stale-session
route removal, queue ownership and network-recovery retry. Forced live token
expiry/disablement, denied Firestore write and exactly-once recovery remain NOT
RUN. Use controlled accounts and synthetic data; do not log tokens or payloads.

### 6. Vendored analyzer and Kotlin compatibility — tracked, non-blocking today

`flutter analyze lib test` passes. Full `flutter analyze` exits 1 with 32
`info` findings, all in `packages/flutter_nearby_connections_plus` and its
example/tests. Android builds also warn that Firebase and the local BLE plugin
still apply Kotlin Gradle Plugin and will need Built-in Kotlin support before a
future Flutter release makes it mandatory. Broad vendored refactoring or a
dependency change is not justified during release closure.

## Secret and permission audit

- No tracked private-key marker or signing-password assignment was found, and
  no project keystore, `.p12`, `.p8`, mobile provision, signing properties or
  export-options artifact was found. Ignored SwiftPM/BoringSSL build caches
  contain upstream test key fixtures; they are not project signing assets and
  are excluded from release credentials/evidence.
- Firebase platform client files match the current application identifiers.
- Android declares Internet, location and version-appropriate Bluetooth
  Scan/Connect/Advertise permissions.
- iOS declares Bluetooth and when-in-use Location descriptions; plist lint
  passes.
- No release signing fallback or public OSM release fallback is enabled.

## Owner actions

1. Record distribution history and approve the permanent Android/iOS IDs.
2. Supply the Android upload keystore/properties and Apple distribution/App
   Store prerequisites outside Git.
3. Create/restrict the Geoapify Free key and prepare an ignored release define
   file without sharing its contents.
4. Provide Android B, unlock/trust all devices and schedule the physical matrix
   with a measured site.
5. Approve/provide the one-shot ACK suppressor and third peer/injector.
6. Execute controlled Firebase expiry/recovery with test accounts.
7. Freeze the source, build signed artifacts, inspect signatures/identifiers,
   install update-in-place and rerun mandatory physical tests on those exact
   artifacts.
