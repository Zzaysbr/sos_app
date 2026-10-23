# Phase A — Manual Actions

Date: 23 October 2026. Execute in this order. Do not uninstall apps, clear data,
reset pairing or paste credentials into committed files, terminal transcripts
or issue logs.

## 1. Decide permanent application identities

Confirm whether either identifier has ever been installed outside controlled
test devices, distributed to testers, registered in Play/App Store Connect, or
linked from another service:

- Android: `com.example.sos_app`
- iOS: `com.n1cxltine.sosapp`

Choose whether Android remains `com.example.sos_app` or changes before first
distribution to an account-owned ID such as `com.n1cxltine.sosapp`. Record the
decision and continuity requirement. This cannot be inferred from the
repository, and changing it can strand the existing Android app's Guest/local
database in the old app container.

Do not edit code yet. If the ID changes, first prepare the new Firebase Android
registration, Play record, Google services config and map-key restrictions as
one reviewed change.

## 2. Create the production map configuration

Create an owner-controlled Geoapify Free project/key after reviewing the current
official pricing, attribution, caching/offline and acceptable-use terms. Apply
the native-app restrictions and quota alerts that the provider supports.

Create an ignored file outside the repository, for example
`/private/path/map.release.json`:

```json
{
  "MAP_TILE_URL": "https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=ACCOUNT_OWNED_KEY",
  "MAP_TILE_ATTRIBUTION": "Powered by Geoapify | © OpenStreetMap contributors",
  "MAP_TILE_USER_AGENT": "FINAL_APPLICATION_IDENTIFIER"
}
```

Never send or commit the real file. Build with
`--dart-define-from-file=/private/path/map.release.json`. On a controlled device,
verify valid-key tiles and attribution links, then invalid/denied key, provider
failure and network loss. Coordinates and markers must remain visible in every
failure case. This online configuration does not authorize or implement offline
tile downloads.

## 3. Supply Android release signing

Use the account-owned Play upload keystore. Back it up in an access-controlled
location before building. Create ignored `android/key.properties` locally with
`storeFile`, `storePassword`, `keyAlias` and `keyPassword`; keep both it and the
keystore outside Git.

Build the release AAB using the private map define file. Record only application
ID, version, artifact SHA-256 and certificate SHA-256. Inspect that the artifact
is release-signed by the intended upload certificate. Never copy passwords or
private key material into validation evidence.

## 4. Configure Apple distribution signing

Confirm the Apple team owns `com.n1cxltine.sosapp`, App ID capabilities match
the Runner entitlements, App Store Connect contains the intended record, and a
valid Apple Distribution certificate/profile is available. Choose and document
automatic or manual signing. Archive/export a Release build containing the
private map defines, then inspect bundle ID, version, signing authority,
provisioning profile and entitlements. Unsigned builds from automated closure do
not satisfy this step.

## 5. Install signed candidates without clearing data

Record source revision, dirty-state approval, artifact hashes and signatures.
Install as an update over the controlled existing apps. Stop on identity or
signature mismatch; do not uninstall to make installation succeed. Confirm
Guest/local history and previously acknowledged delivery status remain intact.

## 6. Execute the physical reliability session

Provide Android A, Android B and an iPhone, all trusted/unlocked with Developer
Mode or USB debugging, plus data cables and a safe open/obstructed 50 m site.
Provide a distinct third peer/injector and an approved debug-only one-shot ACK
suppressor for the two fault cases. Follow
`PHYSICAL_TEST_SESSION_CHECKLIST.md` in order and retain redacted sender/receiver
logs. Physical PASS requires application ACK and receiver persistence; native
write success is insufficient.

## 7. Execute live Firebase recovery/isolation

Use only controlled accounts A/B and synthetic SOS data. Force account A session
expiry/disablement, verify its routes close and are not visible to Guest/B, then
test an offline/denied cloud write and recovery to exactly one Firestore
document. Verify no Guest queue entry uploads and clean up through the authorized
test account. Do not record tokens, credentials, document payloads or personal
coordinates.

## 8. Final release inspection

Update the matrix with evidence references and actual PASS/FAIL/NOT RUN. Re-run
tests, analyzer, signed builds and `git diff --check` from the frozen release
revision. Review store privacy disclosures, map attribution and permissions
against the signed artifacts. Keep the Release Gate blocked if any mandatory row
is NOT RUN or FAIL.
