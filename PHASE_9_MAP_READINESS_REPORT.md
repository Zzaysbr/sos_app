# Phase 9 — Production Map Provider & Offline Map Readiness

Date: 2 November 2026 (Asia/Bangkok)  
Repository baseline: `main` at `af6efe2cf4133de2c340d3cd374f9ee944d5b163`  
Release Gate: **BLOCKED**

## Scope and preservation

This review began from an already dirty working tree containing unrelated
Relay, UX, localization and documentation work. Nothing was reset, cleaned,
stashed, staged, committed or pushed. No production credential, account or map
provider configuration was created or used.

## Current implementation audit

| Area | Result | Evidence |
| --- | --- | --- |
| Renderer and markers | IMPLEMENTED | `flutter_map` + `latlong2`; incident, verified shared and current-device markers are independent. |
| Configuration | IMPLEMENTED | `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, `MAP_TILE_USER_AGENT` use compile-time Dart defines. |
| Release fail-closed | IMPLEMENTED | Missing provider, invalid/non-HTTPS URL, missing placeholders, public OSM release use, missing attribution/user-agent and a Geoapify URL without an API key are rejected. |
| Tile failure behavior | AUTOMATED-TESTED | Map retains coordinates/markers and exposes retry without falling back to public OSM. |
| Attribution | AUTOMATED-TESTED | Visible attribution and native HTTPS-only credit links are retained; links have 48 px minimum target sizing. |
| Current location | IMPLEMENTED / AUTOMATED-TESTED | Permission, service, invalid-coordinate, timeout, stale and disposal cases are handled without crashing. |
| Offline regions | IMPLEMENTED / AUTOMATED-TESTED | Explicit download, bounds/zoom/storage limits, staging cleanup, cancellation, persistence across restart and offline-first lookup exist. |
| Production provider runtime | NOT RUN | No account-owned configuration/key or release artifact was available. |
| Physical offline storage | NOT RUN | No Android/iPhone/iPad provider-backed region download/restart/storage-pressure run was performed. |

Android declares `INTERNET`; iOS uses standard HTTPS networking, so no new
platform network permission was needed. The map is not a prerequisite for BLE
SOS/Chat operation: when tiles are unavailable, coordinates and markers remain
available locally.

## Defects corrected in this phase

1. **Localized, credential-safe configuration errors.**
   `MapTileProviderConfig` now records a typed validation issue. The map page
   maps it to Thai/English text instead of showing raw configuration content.
   URLs and keys are never echoed.
2. **Geoapify attribution validation.** Geoapify configurations must state
   both Geoapify and OpenStreetMap attribution before being usable. The page
   also retains its visible public credit links.
3. **Offline downloader identity guard.** Direct repository callers with an
   empty/whitespace user-agent now fail before any network request. This closes
   the path that could bypass the UI's map-config user-agent validation.
4. **Offline error privacy.** Download/delete UI now shows a localized generic
   recovery message instead of displaying provider/network response detail.

No BLE UUID, wire format, SOS/Chat/Location business logic, database schema,
Guest ownership or Firebase behavior changed.

## Provider recommendation

**Recommended current candidate: Geoapify Free, raster `osm-carto`.** It works
with the existing `flutter_map` raster architecture and requires no renderer
replacement. Geoapify's current tile documentation specifies the `osm-carto`
ZXY URL, requires an API key, and says the Free plan requires Geoapify and
OpenStreetMap attribution. `osm-carto` avoids the extra OpenMapTiles credit
required by other listed Geoapify styles. Geoapify currently documents 3,000
credits/day; one tile costs 0.25 credit. Its published tile guidance says tile
products may be stored/reused while attribution and rate limits are respected.

This is a conditional provider choice, not a capacity, SLA, quota or release
approval. The owner must recheck terms at activation and determine expected
daily active users, pan/zoom behavior, quota alerts, usage handling and privacy
disclosures. A client-side tile API key is an identifier, not a privileged
secret: it must still be restricted using provider controls appropriate for
native clients and never be logged or committed.

Public `tile.openstreetmap.org` stays development-only. Its official policy
forbids offline/prefetch downloads and offers only best-effort service, so it
cannot be a production or Offline Region source.

Alternatives are not selected in this phase: MapTiler's own current guidance
states bulk API tile downloading requires a Custom plan; switching renderer or
self-hosting is a separate product/operations decision.

## Production configuration

The owner must create an account-owned Geoapify project/key and place the
following values in an ignored file outside source control (placeholder only):

```json
{
  "MAP_TILE_URL": "https://maps.geoapify.com/v1/tile/osm-carto/{z}/{x}/{y}.png?apiKey=ACCOUNT_OWNED_KEY",
  "MAP_TILE_ATTRIBUTION": "Powered by Geoapify | © OpenStreetMap contributors",
  "MAP_TILE_USER_AGENT": "com.n1cxltine.sosapp"
}
```

Use `--dart-define-from-file=/private/path/map.release.json`; never paste the
key into a command line, shell history, source file, ARB, test, report or log.
The repository ignore rules already cover `map.release*.json` and
`map.production*.json` while allowing safe `*.example.json` templates.

## Phase 9.1 — Geoapify configuration verification

On 3 November 2026, an ignored local `config/production.json` was verified as
a JSON object containing a nonempty `GEOAPIFY_API_KEY` field. It is not
tracked, is ignored by the local `config/` rule, and its value was neither
printed nor copied into source, test output, documentation, UI, or logs.

The previous map implementation accepted only the three expanded
`MAP_TILE_*` values, so that one-key configuration was not consumed. The
smallest safe adapter now accepts `GEOAPIFY_API_KEY` and, when no explicit
`MAP_TILE_URL` is supplied, creates the fixed Geoapify `osm-carto` HTTPS
template, required Geoapify/OpenStreetMap attribution, and the application
user-agent. Explicit `MAP_TILE_*` configuration remains supported. The key is
only used as the HTTPS query parameter required by Geoapify; it is excluded
from offline storage keys and configuration errors.

The same configuration produced an Android Debug APK and an iOS Debug
no-codesign app. This verifies compile-time Dart-define ingestion and the
release-equivalent validation path exercised by tests; it does **not** verify
a signed Release artifact, a live tile response, quota, or a physical device
map session. Release still fails closed if neither a valid explicit provider
nor a nonempty Geoapify key is supplied, and it never substitutes public OSM.

## Offline map compliance

The code permits Offline Region downloads only for a validated HTTPS
`maps.geoapify.com/v1/tile/...` endpoint with a nonempty `apiKey`, complete
Geoapify/OSM attribution, a stable user-agent, a complete configuration, and
no development fallback. Raw repository calls independently reject any other
host and empty user-agent. The public OSM service cannot enter this path.

Completed regions are atomically promoted from a `.partial-*` staging directory
only after every tile and manifest has been written; cancellation, failure and
startup remove partial directories. Limits are 400 tiles per region, 80 MiB per
region, 250 MiB total, 2 MiB per tile and zoom 1–16. Missing downloaded tiles
remain an ordinary network miss; the UI does not pretend a region is complete.

Terms-based offline compliance is **CONDITIONALLY IMPLEMENTED**, not
production-verified: Geoapify's current published terms support storage, but
the owner has not yet accepted applicable terms, provided a key, validated plan
restrictions or completed device testing.

## Automated evidence

Current Phase 9 focused validation:

- `flutter gen-l10n`: PASS, exit 0.
- `flutter test test/map_tile_provider_test.dart test/offline_map_repository_test.dart test/incident_map_page_test.dart --reporter compact`: PASS, 34 tests, exit 0.

Additional current validation:

- Relevant Map/Offline/SOS/Location suite: PASS, 48 tests, exit 0.
- `flutter test --reporter compact`: PASS, 414 tests, exit 0.
- `flutter analyze lib test`: PASS, no issues, exit 0.
- `git diff --check`: PASS, exit 0.
- `flutter build apk --debug`: PASS, exit 0; artifact
  `build/app/outputs/flutter-apk/app-debug.apk`. This is not signed Release
  evidence. The existing dependency KGP compatibility warning remains.
- `flutter build ios --debug --no-codesign`: PASS, exit 0; artifact
  `build/ios/iphoneos/Runner.app`. This is compile-only evidence and cannot be
  deployed without signing.
- `flutter test --dart-define-from-file=config/production.json test/map_tile_provider_test.dart --reporter compact`:
  PASS, 9 tests, exit 0. It confirms the local key creates a valid Geoapify
  configuration without exposing its value.
- `flutter build apk --debug --dart-define-from-file=config/production.json`:
  PASS, exit 0.
- `flutter build ios --debug --no-codesign --dart-define-from-file=config/production.json`:
  PASS, exit 0. This is compile-only evidence and cannot be deployed without
  signing.

No build was installed or run on a device. No debug build is evidence of
production provider readiness.

## Required physical verification

1. Build a signed release candidate with an owner-provided configuration.
2. On Android and iOS, open a map, confirm configured raster tiles load and
   both OSM/Geoapify credits are visible and actionable.
3. Verify invalid/revoked key and network loss show safe localized recovery
   while incident/shared coordinates remain visible.
4. Download a deliberately bounded region on each platform; confirm progress,
   cancellation cleanup, restart persistence, missing-tile behavior and storage
   accounting. Do not use the public OSM tile service.
5. Monitor real provider credits/request rate and confirm expected daily
   traffic stays within the owner-approved plan.

## Owner actions and remaining blockers

1. Create/restrict the Geoapify project key; review current terms, attribution,
   privacy and quota/rate policy.
2. Supply the ignored Dart-define file only to the controlled build session.
3. Perform the release-artifact and physical map/offline checks above.
4. Complete remaining distribution signing, physical reliability/range,
   production trust/operations and Final Delivery v3 (deferred) gates.

Until those actions are complete, the Release Gate remains **BLOCKED**.

## Phase 9.2 — Physical Map Verification — 3 November 2026

The ignored production config was used without printing or tracking its key.
The same `--dart-define-from-file` input was installed update-in-place on the
currently detected devices; no uninstall, clear-data, Bundle ID, Team,
Firebase, or app-data operation was performed:

| Device | Connectivity/build | Install/launch | Map UI evidence |
| --- | --- | --- | --- |
| Samsung SM-A536E, Android 14 | USB ADB `RFCT80GPFVY`; `flutter run` exit 0 | Debug APK installed and launched; existing package retained | **NOT RUN** — device was at the lock screen when the UI was inspected |
| iPhone 15 Plus, iOS 27.0.1 | Flutter wireless device available; automatic Team `78GZXS97G6` signing | Build, install and launch completed; session stopped after launch | **NOT RUN** — no screen-level tile/attribution/offline evidence captured |
| iPad Air 11-inch (M2), iPadOS 27.0.1 | Flutter wireless device available and paired | Build, install and launch completed; session stopped after launch | **NOT RUN** — no screen-level tile/attribution/offline evidence captured |

The Android run emitted startup performance/rendering warnings (including
skipped frames and device graphics-buffer warnings) but no Flutter exception
or map-specific failure was observed in the captured startup output. This is
not a map pass. The required next step is an unlocked, user-observed session
on each device covering tile load, both attributions, marker/coordinate
placement, zoom/pan/recenter, offline error/recovery, and a safe invalid-key
check. Offline Region download remains out of scope for this phase.

### Android follow-up evidence — Samsung SM-A536E

Internet was enabled once outside the app, then disabled before opening the
app. The map showed the real current position. Marker/coordinates, pan and
recenter were reported working. Tiles disappeared at very high and very low
zoom while offline and returned after Internet recovery. This is **PHYSICAL
PASS** for GPS after warm-up and online tile recovery, **PARTIAL** for Offline
Map tile coverage, and **NOT VERIFIED** for attribution because the text was
not read back clearly. It is not evidence of a cold-start GNSS fix or broad
offline coverage; Offline Region download was not run.

## Phase 9.3–9.4 — GPS offline behavior and automatic location sharing

### iPhone physical follow-up — iPhone 15 Plus, iOS 27.0.1

The Profile build was installed update-in-place and launched from the Home
Screen icon. During the offline attempt, current location was unavailable.
After the narrowly scoped UX fix, Details displayed
`Incident coordinates are not available.` without creating a synthetic marker.
Record: installation **PASS**, icon launch **PASS**, no-coordinate UX
**PHYSICAL PASS**, GPS offline **FAIL/UNAVAILABLE**, Map with cached tiles **NOT
RUN**, Map without cached tiles **NOT RUN**, online recovery **NOT RUN**,
attribution **NOT RUN**, and automatic location sharing **NOT RUN**.

The confirmed GPS-related defect was in SOS ordering, not a network dependency
inside Geolocator: `_sendSos()` awaited location acquisition before calling
`SosRepository.create()`. A denied permission, unavailable service or timeout
could therefore delay or fail the user-visible SOS flow. The fix is limited to
`sos_page.dart`: the local SOS is now persisted and Chat is opened first;
consented location acquisition runs asynchronously afterward. A valid position
updates the existing incident identity and is then included in the existing
Relay path. A failed or unavailable position leaves SOS/Chat working and sends
Relay without location. No schema, BLE UUID, wire format, recipient routing or
delivery semantics changed.

Automatic location sharing remains consent-gated and OFF by default. OS
permission is not treated as sharing consent; Relay/public sharing consent and
location consent remain separate. The implementation never claims a location
was shared until a valid coordinate was obtained and queued through the
existing path.

The existing Offline Region implementation remains the only offline-map
mechanism. It reads completed local tiles when available; with coordinates but
no cached tiles it preserves coordinates/markers and explains that tiles need
internet; with no coordinates it does not create a synthetic marker. A region
must be downloaded in advance, and this phase did not perform a physical
Offline Region download test.

Phase 9.3–9.4 focused regression coverage passes 12 tests including persistence
before GPS completion and GPS failure preserving SOS/Relay routing. The full
Flutter suite passes 417 tests; analyzer and diff check pass. Android Debug and
iOS Debug no-codesign builds with the ignored production config pass. Physical
GPS, online-map and offline-map UI checks remain NOT RUN unless directly
observed on an unlocked device.

### iPad physical follow-up — iPad Air 11-inch (M2), iPadOS 27.0.1

The Profile build was installed update-in-place and launched from the Home
Screen icon. With Internet disabled, SOS creation and immediate Chat navigation
were observed. Current location was unavailable; Details displayed
`Incident coordinates are not available.` without creating a synthetic marker.
Record: installation **PASS**, icon launch **PASS**, offline SOS **PASS**, Chat
navigation **PASS**, no-coordinate UX **PHYSICAL PASS**, GPS **FAIL/UNAVAILABLE**.
Map tiles, marker/coordinates with a valid position, offline cached and
uncached tile behavior, zoom/pan/recenter, attribution, online recovery and
automatic location sharing were **NOT RUN** because this run produced no
incident coordinates. No claim is made for those checks.

## Phase 9.5 iPhone GPS feedback — Case A

With Location Services manually disabled on the iPhone 15 Plus Profile build,
the test SOS persisted and Chat opened immediately. The feedback banner showed
`Location unavailable` with the reason `Current location is unavailable or
invalid.`. The SOS remained **active** and duplicate count was **0**. This is
**PHYSICAL PASS** for the GPS-unavailable feedback path. GPS recovery and
lifecycle cases remain **NOT RUN**.

### iPad Profile reinstall verification — iPad Air 11-inch (M2)

The latest Profile build was installed update-in-place with the existing
Bundle ID and Team. Opening from the Home Screen passed; the existing
login/session, SOS History and Chat were present, and no startup crash was
observed. Installation and launch are **PHYSICAL PASS**. GPS and map cases are
recorded separately below and were not implied by this installation result.

### Phase 9.5 iPad GPS feedback — Case A

With Location Services disabled, the iPad Air 11-inch (M2) created a new SOS
while the prior resolved incident remained in History. Chat opened immediately
and displayed `Location unavailable` with `SOS was saved without coordinates`
and `Current location is unavailable or invalid.`. The new incident remained
**active** and duplicate count was **0**. This is **PHYSICAL PASS** for the
iPad GPS-unavailable feedback path.

### Phase 9.5 Android GPS feedback — Cases A and B

On the Samsung Galaxy A53 (Android 14) Debug build, Case A with Location
Services disabled persisted one SOS, opened Chat immediately, showed
`Location unavailable` with `Current location is unavailable or invalid.`,
kept the incident **active**, and created no duplicate. Case A is **PHYSICAL
PASS**.

For Case B, Location Services was enabled with **While using** permission. A
new SOS was persisted, Chat opened immediately, Details contained coordinates,
and a map marker was visible. The incident stayed **active**, duplicate count
was **0**, and no error was observed. Case B is **PHYSICAL PASS**.

### Phase 9.5 Android GPS feedback — Case C

The user left Chat before the asynchronous location callback completed on the
Samsung Galaxy A53. The app did not crash and no lifecycle error was observed.
The prior incident remained available after resolution, the subsequent
incident contained the correct data, and no prior location feedback appeared
in the new Chat. Duplicate count was **0**. Android callback lifecycle safety
and incident isolation are **PHYSICAL PASS**.

### Phase 9.5 iPad GPS feedback — Case B

With Location Services enabled and permission set to **While Using**, the iPad
Air 11-inch (M2) persisted a new SOS and opened Chat immediately. Details
contained a coordinate and a map marker was visible. The SOS remained
**active**, duplicate count was **0**, and no error was observed. This is
**PHYSICAL PASS** for iPad GPS recovery and same-incident coordinate
persistence.

### Phase 9.5 iPad GPS feedback — Case C

The user left Chat before the asynchronous location callback completed. The
iPad app did not crash and no lifecycle error was observed. The prior incident
remained available after resolution, the subsequent incident contained the
correct data, and no location feedback from the prior incident appeared in the
new Chat. Duplicate count remained **0**. This is **PHYSICAL PASS** for iPad
callback lifecycle safety and incident isolation.

### Phase 9.5 iPhone GPS feedback — Case B

With Location Services enabled and permission set to **While Using**, the
iPhone 15 Plus created a new SOS while Internet remained enabled. The SOS was
persisted, Chat opened immediately, Details contained a real incident
coordinate, and a map marker was visible. The incident remained **active**,
duplicate count was **0**, and no error was observed. This is **PHYSICAL PASS**
for GPS recovery and same-incident coordinate persistence. Acquisition time was
not measured, so cold-start timing remains unquantified.

### Phase 9.5 iPhone GPS feedback — Case C

The user left Chat before the asynchronous location callback completed. The
app did not crash and no lifecycle error was observed. The prior incident
remained available in resolved state, a subsequent incident contained the
correct data, and no location feedback from the prior incident appeared in the
new incident Chat. Duplicate count was **0**. This is **PHYSICAL PASS** for
callback lifecycle safety and incident isolation. Callback/timeout duration was
not measured.

## Phase 9 production map and Offline Region verification — 3 November 2026

### Source and configuration

**PASS (static):** `MapTileProviderConfig` accepts the ignored local
`GEOAPIFY_API_KEY` dart define, constructs an HTTPS Geoapify `osm-carto` tile
template when explicit `MAP_TILE_*` values are absent, requires `{z}`, `{x}`
and `{y}`, requires a user-agent and attribution, and rejects public OSM in
Release. `config/production.json` is ignored and untracked; only its key name
was inspected. No secret value was printed. Offline Regions accept only the
validated Geoapify endpoint, use staging directories, publish a manifest only
after all tiles succeed, clean abandoned partial downloads, and enforce tile,
region and total-storage bounds.

### Automated verification

**PASS:** Map provider, Offline Region and incident-map focused tests: 34/34,
exit 0. Full Flutter suite: 418/418, exit 0. `flutter analyze lib test`: exit
0, no issues. `git diff --check`: exit 0. No new defect or source change was
required in this verification.

### Release configuration

**BLOCKED_SIGNING (Android):**
`flutter build apk --release --dart-define-from-file=config/production.json`
failed at `android/app/build.gradle.kts:26` because the account-owned release
keystore and `android/key.properties` are absent. No replacement key was
created.

**NOT VERIFIED (iOS Release no-codesign):**
`flutter build ios --release --no-codesign --dart-define-from-file=config/production.json`
started an Xcode Release build and produced/retained an app bundle, but the
invocation was stopped after prolonged silence before a reliable terminal
completion result was captured. This is not signed-distribution evidence.

### Physical and provider-policy evidence

Physical GPS and map evidence remains separate from configuration proof:
Android previously demonstrated real coordinates, marker, pan/recenter and
online recovery, but tile coverage was **PARTIAL** at uncached zoom levels and
attribution was **NOT VERIFIED**. iPhone/iPad GPS recovery and marker evidence
exists; screen-level Geoapify attribution and Offline Region download/restart
behavior were **NOT RUN** in this phase. No device is claimed to have passed
Offline Region validation.

Geoapify's current map documentation states that tiles may be generated,
stored, reused and redistributed subject to RPS limits and required
attribution; the Terms require OpenStreetMap attribution and Geoapify
attribution on the Free plan. These web references do not verify this
project's account plan, accepted terms, quota, or production key ownership.

### Remaining blockers

Production Map and Offline Region are **NOT RELEASE-READY**. Owner actions:
provide/review the account-owned Geoapify key and plan/quota, verify attribution
on each target device, run a controlled Offline Region download/restart test,
capture a successful iOS Release no-codesign completion (then separately verify
signing), and provide the Android release keystore plus ignored
`android/key.properties`. The Release Gate remains **BLOCKED**.

### Physical Offline Region acceptance — Samsung Galaxy A53, 3 November 2026

The downloaded region rendered real cached tiles while offline (**PHYSICAL
PASS** within the downloaded area). Outside that region, tiles were absent and
retry required Internet (**PARTIAL/EXPECTED** bounded-cache behavior). Exact
zoom coverage, attribution/link interaction, progress completion,
force-close/restart persistence, storage-pressure handling and interrupted
download retry remain **NOT VERIFIED** from this observation. iPhone and iPad
Offline Region tests remain **NOT RUN**.

