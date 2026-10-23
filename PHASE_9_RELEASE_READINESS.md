# Phase 9 — Release Readiness Without Physical Devices

Date: 22 October 2026 (Asia/Bangkok). **Release gate: BLOCKED.**

## Production map assessment

The Incident Map accepts `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION` and
`MAP_TILE_USER_AGENT` through Dart defines. Release validation rejects missing
configuration and the public `tile.openstreetmap.org` service. When the provider
is invalid or tile requests fail, the app keeps incident/shared-coordinate
markers and retry UI without creating an unapproved fallback request. Tests
cover invalid configuration, provider/network failure, visible attribution and
credential-safe errors. Tile downloading and offline maps are not implemented.

No map defines, `.env` file or account-owned key is present in the workspace or
current shell. Geoapify Free remains the approved free-only candidate, but it is
not production-configured. Current official documentation states that its Free
plan may be used in production within its quota and requires both Geoapify and
source attribution. Raster tiles require an account API key. References:
[pricing](https://www.geoapify.com/pricing/),
[map-tile URL and attribution](https://apidocs.geoapify.com/docs/maps), and
[terms](https://www.geoapify.com/terms-and-conditions/).

Use the `osm-carto` raster style to avoid an additional OpenMapTiles attribution
requirement. The owner must create a Geoapify project/key and prepare an ignored
or temporary JSON file containing these values:

```json
{
  "MAP_TILE_URL": "https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=ACCOUNT_OWNED_KEY",
  "MAP_TILE_ATTRIBUTION": "Powered by Geoapify | © OpenStreetMap contributors",
  "MAP_TILE_USER_AGENT": "FINAL_APPLICATION_IDENTIFIER"
}
```

Build with `--dart-define-from-file=/private/path/map.release.json`. Do not paste
the key into a command, log, evidence file or source-controlled config. The key
is a client-side identifier rather than a privileged server secret; restrict it
using the provider controls that are compatible with native apps, set quota
alerts and review usage. Runtime acceptance still requires a release build that
loads tiles, shows both attribution links, handles a denied/invalid key and
retains coordinates during network loss.

## Release-readiness findings

| Severity | Finding | Result / remediation |
| --- | --- | --- |
| BLOCKER | Production map key/config absent | Owner action required; release remains fail-closed and no public OSM fallback is enabled |
| BLOCKER | Physical reliability/range matrix incomplete | Execute the consolidated session checklist; all unexecuted rows remain NOT RUN |
| HIGH (fixed) | Injected map defines were not read by runtime config | Changed environment reads to compile-time constants; synthetic define regression now passes |
| HIGH (fixed) | Android release used debug signing | Release now requires an account-owned ignored keystore/config and fails clearly when absent |
| HIGH (fixed) | Android main manifest lacked `INTERNET` | Added to the main manifest so release Firebase/map networking is declared; no runtime prompt is introduced |
| HIGH | Android/iOS identifiers differ | Android is `com.example.sos_app`; iOS is `com.n1cxltine.sosapp`. Owner must approve final IDs before store setup. Changing Android now also requires matching Firebase registration and breaks update-in-place continuity |
| HIGH | Signed releases unverified | Android keystore/config and iOS distribution certificate/profile/App Store Connect access are external prerequisites; neither signed release is claimed |
| MEDIUM | Session-expiry live behavior unverified | `AuthGate` scopes resources from Firebase auth changes and tests cover logout/account changes. A live forced token revocation/disabled-user case remains required; no defect was reproduced that justifies changing the listener |
| LOW | Built-in Kotlin warning | Current Gradle/debug build passes. Firebase and the local BLE plugin still apply KGP; track plugin migration before a future Flutter version makes it an error |

Android permissions declare Internet, fine/coarse location, legacy Bluetooth
through API 30 and Scan/Connect/Advertise for newer Android. iOS declares
Bluetooth, local-network/Bonjour and when-in-use location descriptions. Startup
tests confirm Home becomes Guest-ready without an auth wall. Existing tests
cover database restart, failed/cancelled login, Guest retention, no Guest cloud
upload, account A→B isolation, stale repository invalidation, session route
reset, sync-queue ownership, BLE identity/retry and deduplication. No additional
test was added because the audit found no uncovered reproducible product defect.

## Signing prerequisites

Android release requires `android/key.properties` with `storeFile`,
`storePassword`, `keyAlias` and `keyPassword`, plus its account-owned keystore.
Both remain ignored. A release task without them must fail before producing an
artifact. Record certificate SHA-256 and artifact SHA-256 without recording
passwords or private-key material.

iOS uses automatic signing for team `78GZXS97G6` and bundle ID
`com.n1cxltine.sosapp`, but repository state does not prove access to a valid
Apple Distribution certificate, App Store provisioning profile or App Store
Connect record. `ExportOptions.plist` is absent. Unsigned debug success is build
evidence only.

## External actions

1. Owner: approve final Android/iOS application identifiers before store setup.
2. Owner: create and restrict a Geoapify Free project key, then provide it only
   through an ignored/temporary Dart-define file.
3. Owner: provide the Android upload keystore and ignored signing properties;
   preserve them in an access-controlled backup.
4. Owner: confirm Apple Distribution/App Store Connect access and provisioning.
5. Devices: provide Android A, Android B and iPhone with data cables, Developer
   Mode/trust and the controlled accounts described in the session checklist.
6. Lab: provide an approved one-shot debug ACK suppressor and a distinct third
   peer/injector before P8-P01/P8-P02 can be executed. No harness was added here.

