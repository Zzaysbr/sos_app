# MVP Release Readiness

Status: **BLOCKED**  
Date: 3 November 2026

| Gate | Requirement | Status |
|---|---|---|
| RG-01 | SOS local persistence | Implemented; regression evidence maintained |
| RG-02 | Offline Chat reliability | Verification required |
| RG-03 | BLE peer identity security | Verification required |
| RG-04 | Location recipient integrity | Verification required |
| RG-05 | Guest/account isolation | Verification required |
| RG-06 | Accurate SOS delivery status | Verification required |
| RG-07 | Map provider and attribution | Blocked pending production verification |
| RG-08 | Accessibility and critical UX | In progress |
| RG-09 | Android physical acceptance | Partial evidence |
| RG-10 | iOS physical acceptance | Historical acceptance; revalidate when required |
| RG-11 | Release signing/configuration | Must verify current validity |
| RG-12 | No critical security/data-integrity defect | Not accepted |

Password recovery is intentionally unavailable until trusted server-side MFA
recovery is deployed. This is a documented mitigation, not a release claim of
genuine 2FA recovery.

## Audit evidence — 3 November 2026

- Full Flutter suite: **434 passed**, exit 0.
- `flutter analyze lib test`: exit 0, no issues.
- `git diff --check`: exit 0.
- Physical evidence is historical/user-reported and is not re-run by this
  reconciliation; untested cases remain NOT VERIFIED.
- Android release signing is blocked by missing owner keystore/configuration.
- iOS signing/profile validity is time-sensitive and requires current
  preflight; expired-profile artifacts must not be installed.
- Production Geoapify plan/key, attribution and Offline Region acceptance are
  not fully verified.

Release decision remains **BLOCKED**. No phase is marked COMPLETED solely from
source presence or automated tests.

## Q-805 map provider update — 3 November 2026

- Current architecture remains compile-time Dart defines with Geoapify
  `osm-carto` support and development-only public OSM fallback.
- Added fail-closed validation for malformed Geoapify API-key values; errors
  are generic and never echo the key.
- Map configuration tests, full Flutter tests, analysis, Android Debug,
  iOS Profile, and iOS Release no-codesign builds were run successfully.
- Android Release remains blocked by the missing owner-controlled keystore.
- Live provider account/plan/quota, attribution interaction and complete
  physical map acceptance remain unverified. Q-805 remains blocked.

## Q-805A provider verification — 3 November 2026

| Check | Result |
|---|---|
| Local production key define present | VERIFIED (presence only; value withheld) |
| Define file ignored and untracked | VERIFIED |
| Key hardcoded in tracked source | NOT FOUND |
| Missing/malformed key fail-closed | VERIFIED by automated tests |
| Geoapify account ownership | NOT VERIFIED |
| Active plan, quota and rate-limit allowance | NOT VERIFIED |
| Provider terms for this account/use case | NOT VERIFIED |
| Physical live tile/attribution acceptance | NOT VERIFIED |

The project injects the key with
`--dart-define-from-file=config/production.json` (or an owner-controlled
equivalent private file). The file must never be committed or printed. Android
Release remains blocked by the missing owner keystore; iOS unsigned Release
build success is not distribution signing readiness.

Q-805B physical map acceptance is **PASS — DEVICE VERIFIED (operator-reported)**:
Android and iPhone map display, attribution, links, permission handling and
layout passed. The iPhone retest also confirmed fresh tiles in a previously
unseen area after connectivity returned, without crash/error.
Provider account/terms/quota and signed release verification remain open.

## Manual test evidence rule

All physical BLE, Chat, Location, SOS, Maps, Permissions, Auth and release
installation checks must record a Test ID, preconditions, exact steps, expected
result, sanitized evidence and PASS/FAIL/PARTIAL/NOT RUN criteria. Q-805B cases
are maintained in `PHYSICAL_MAP_ACCEPTANCE.md`; the latest operator evidence
explicitly distinguishes the fresh iPhone tile reload from the earlier cache-only
observation.

## Q-901A Android release signing preparation — 3 November 2026

- `android/app/build.gradle.kts` uses a dedicated `release` signing config only
  when all four local properties are present: `storeFile`, `storePassword`,
  `keyAlias` and `keyPassword`.
- Missing properties fail closed with a Gradle exception; release does not fall
  back to the debug certificate.
- No owner-controlled keystore or `android/key.properties` was found. The
  release APK build was therefore **NOT RUN — OWNER KEYSTORE REQUIRED** (the
  guarded command exited 1 before producing a release artifact).
- `key.properties`, `*.jks` and `*.keystore` are ignored by Git. No credential
  value was printed or recorded.

Android Release Signing remains **BLOCKED** until the owner supplies and safely
backs up the account-controlled keystore and local properties file.

### Q-901A readiness recheck — 3 November 2026

- Current inspection found no owner-controlled keystore or `android/key.properties`.
- Root and Android-level ignore rules exclude `key.properties`, keystore files and
  certificate containers; no signing secret was printed or added.
- `./android/gradlew -p android :app:assembleRelease` failed closed at
  `android/app/build.gradle.kts:26` with exit code 1 because the four required
  release properties are absent. No release artifact was produced and no Debug
  keystore fallback was used.
- Certificate fingerprint and artifact verification are **NOT RUN — OWNER KEYSTORE
  REQUIRED**.

## Q-902A iOS distribution signing audit — 3 November 2026

- Xcode 26.6 is installed; the project has Runner and RunnerTests targets with
  Debug, Profile and Release configurations.
- Runner keeps automatic signing, bundle ID `com.n1cxltine.sosapp` and project
  team `78GZXS97G6` in all three configurations. Release still uses the
  development identity label and has no distribution export configuration.
- The local keychain exposes only Apple Development identities for another
  team; no Apple Distribution identity for the configured team was found.
- No matching provisioning profile for the Runner bundle was present in the
  local provisioning-profile directory. No ExportOptions plist or app
  extension entitlement was found. `Info.plist` contains Bluetooth, local
  network and location usage descriptions; these do not prove distribution
  entitlement approval.
- Signed archive/export was **NOT RUN — OWNER DISTRIBUTION SIGNING REQUIRED**.

### Q-902A distribution readiness recheck — 3 November 2026

- The current code-signing identities are valid Apple Development identities;
  their public certificate `OU` is `78GZXS97G6` and the certificates are within
  their validity period. This corrects the earlier display-name-only assessment;
  no Apple Distribution identity is available locally.
- The only local Runner profile is a development profile for
  `78GZXS97G6.com.n1cxltine.sosapp`, expires 10 November 2026, and has
  `get-task-allow=true`. The intended iPhone 15 Plus and iPad Air M2 UDIDs are
  not present in its provisioned-device list.
- Release effective settings are automatic signing, Team `78GZXS97G6`, bundle
  `com.n1cxltine.sosapp`, and `CODE_SIGN_IDENTITY=Apple Distribution`.
- No local distribution provisioning profile or ExportOptions plist was found;
  signed archive/export was not attempted. iOS distribution remains
  **BLOCKED_SIGNING**.
  A no-codesign or development build would not be distribution evidence.

iOS Distribution Signing status: **BLOCKED**. The owner must access Team
`78GZXS97G6`, create/renew an Apple Distribution certificate with its private
key, register the bundle ID/capabilities, create a matching distribution
profile, and provide an authorized export method before archive validation.

## Phase 9 demo scope adjustment — 3 November 2026

The current milestone is a physical-device MVP demo, not paid store
distribution. Therefore Q-901A Android Release signing and Q-902A iOS
Distribution signing are deferred Store Distribution prerequisites and are not
Demo Gate blockers. Existing Release safeguards remain unchanged.

### Demo Gate

- Android Debug APK: **PASS — BUILD/INSTALL/LAUNCH VERIFIED** on Samsung
  SM-A536E (`RFCT80GPFVY`) using the production define file; installed with
  `adb install -r` and launched successfully. No app data was cleared.
- iOS Development build: **BUILD/INSTALL VERIFIED** using Xcode automatic
  development signing for Team `78GZXS97G6`, Bundle ID
  `com.n1cxltine.sosapp`, and the existing Personal-Team certificate. The
  CoreDevice install succeeded update-in-place on iPhone 15 Plus. The owner
  then opened it from the Home Screen successfully; existing session, SOS
  History and Chat data were reported preserved. **PHYSICAL PASS**.
- BLE, SOS Chat and Location Sharing remain subject to the existing physical
  evidence records; no new feature acceptance is inferred from installation.
- iPad Air 11-inch (M2): the same Profile artifact installed update-in-place via
  CoreDevice and the owner confirmed Home Screen launch, session, SOS History
  and Chat preservation. **PHYSICAL PASS**.

### Store Distribution Gate

Remains **DEFERRED / BLOCKED** until owner-controlled Android Release signing,
Apple Developer Program distribution signing, profiles and signed artifacts
are intentionally pursued.

## Q-903A release configuration hardening — 3 November 2026

- Android release signing remains fail-closed and keeps the existing package
  identity. No debug fallback, debug-only manifest override or production
  endpoint was enabled; backup/data-extraction rules exclude relay key material.
- Production map configuration continues to use owner-supplied Dart defines;
  tracked source contains no Geoapify secret. Missing/invalid map configuration
  remains fail-closed by the existing validation.
- Firebase generated options contain client-side project identifiers/API-key
  fields as expected for Firebase mobile clients; no password or private server
  credential was exposed by this audit. Firebase Rules and project restrictions
  remain an owner-controlled production check.
- iOS Runner Release now explicitly requests `Apple Distribution`, while Debug
  and Profile retain `Apple Development`. Automatic signing, Team
  `78GZXS97G6`, bundle ID and version variables are unchanged. This makes a
  distribution archive fail clearly when the required owner certificate/profile
  is absent instead of presenting a development identity as release evidence.
- No signed archive/export was attempted because owner distribution assets are
  still unavailable. The setting is configuration hardening, not proof of
  distribution readiness.

## Q-806 data isolation verification — 3 November 2026

Local Drift/repository isolation and sync-lifecycle tests passed (focused suite
30 tests; full suite 444 tests). Guest records remain under the local guest
owner and are excluded from cloud sync; authenticated reads and queue retries
are fenced by the current Firebase UID. Production Firebase Rules, live sync,
and physical account-switch behavior remain NOT VERIFIED, so this evidence does
not close the release gate.

## Q-803 accessibility and critical UX — 3 November 2026

The primary SOS hold control now exposes a localized semantic hint and enabled
state; existing text-scaling, navigation, Chat, location-feedback and duplicate
submission tests remain green. This is source/automated evidence only:
VoiceOver/TalkBack, contrast, focus and complete physical accessibility review
remain NOT VERIFIED.

Q-803 physical accessibility remains `NOT RUN`: Samsung and iPhone were
discoverable, but TalkBack/VoiceOver announcements, focus order, contrast and
large-text behavior were not observed by an operator. See
`Q803_PHYSICAL_ACCESSIBILITY.md`; automated semantics do not replace device
acceptance.

## Q-804 regression and QA matrix — 3 November 2026

| Area | Automated evidence | External limitation |
|---|---|---|
| Auth/account lifecycle | auth, session navigator and recovery tests | live backend not verified |
| Guest/authenticated ownership | restart, login/logout, A/B isolation and sync fencing tests | physical account switch/live Firebase Rules not verified |
| SOS persistence/status | repository and emergency UX tests | complete physical timing matrix open |
| BLE identity/lifecycle | protocol, binding, stale-session and UI tests | complete physical matrix open |
| Chat/ACK and Location | repository, routing, recipient and ACK tests | end-to-end device evidence limited |
| Relay v2 | envelope, quota, expiry, hop and diagnostics tests | final responder delivery intentionally absent |
| Maps/configuration | provider validation, attribution and offline repository tests | fresh iPhone tile reload/provider terms open |
| Settings/accessibility/navigation | localization, text-scale, semantics and navigation tests | VoiceOver/TalkBack and contrast audit not run |
| Cloud synchronization | ownership-scoped queue/retry tests | live Firebase production behavior not verified |

Full suite: **445 passed**, exit `0`; `flutter analyze lib test`: exit `0`;
`git diff --check`: exit `0`. Q-804 is **AUTOMATED VERIFIED / EXTERNAL
ACCEPTANCE OPEN**, not a release approval.

Q-806 external acceptance: checked-in Firestore Rules emulator tests passed
(8/8, exit `0`) using the local `security-tests` suite. Live deployed Rules,
production sync and physical account switching remain `NOT RUN — OWNER ACCESS /
DEVICE REQUIRED`; see `Q806_EXTERNAL_ACCEPTANCE.md`.

Firebase CLI project metadata access and local Rules dry-run compilation were
verified for `sos-app-d811a`; this does not prove deployed Rules. Live tests are
blocked until the owner supplies designated Account A/B credentials and an
authorized non-production test procedure.

Q-707 Stage A direct BLE acceptance is **PHYSICAL PASS (operator-reported)** for
Samsung SM-A536E ↔ iPhone 15 Plus discovery, connect, disconnect and reconnect.
No SOS/Chat/Location delivery is claimed from this stage; the remaining Q-707
stages are still open.

## Q-707C SOS regression investigation — 3 November 2026

- **Confirmed:** the automatic SOS action uses Relay v2 hop-only routing via
  `enqueuePublicRelay`; it does not invoke Direct SOS v1 `enqueueSos`.
- **Confirmed:** a relay-only envelope is retained as relay evidence and is not
  converted into a receiver SOS History row.
- **Not proven:** Guest mode or account authentication caused the physical miss.
  No two-account authenticated device run was available.
- **Physical status:** helper-visible SOS delivery is `NOT VERIFIED`; the next
  required run is with designated authenticated Account A/B test users.
- **Product decision required:** choose an explicit Direct v1 recipient flow
  for helper-visible incidents, or retain the current Relay v2 hop-only MVP.
  No protocol or authorization weakening is justified by the current evidence.

## Q-707D three-device relay evidence — latest run, 3 November 2026

- Samsung A: local SOS persisted and reported one stored relay device.
- iPhone B: Diagnostics showed incoming hop 1 and `stored on relay`.
- iPad C: Diagnostics showed incoming hop 1 and `stored on relay` with Relay
  On, confirming B→C relay persistence for this run.
- Receipt state was not recorded locally on B or C.
- C SOS History remained 0 and Rescue Mode showed no incident; this is expected
  for relay-only Relay v2 data and is not final delivery evidence.
- Help acceptance and C→B→A response remain unavailable in the current MVP.

## Q-708A final Rescue reception assessment — 3 November 2026

Final Rescue reception is **BLOCKED_PENDING_DESIGN_APPROVAL**. The current
Relay v2 envelope has origin signatures, hop attestations, TTL and replay
protection, but no final-recipient transition or voluntary-responder consent
field. Promoting every relay row would violate the current trust boundary and
owner isolation. A safe implementation requires an additive protocol version,
recipient/consent semantics and a dedicated Rescue Inbox; none has been added.

Q-708A implementation update: the approved first slice is present with
separate opt-in consent, schema 7 Rescue Inbox persistence, existing relay
cryptographic verification, and local-only acceptance. Physical validation and
full release acceptance remain BLOCKED.
