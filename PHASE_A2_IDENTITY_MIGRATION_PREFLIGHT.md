# Phase A2 — Android Application ID Migration Preflight

Date: 23 October 2026 (Asia/Bangkok)

Audit scope: read-only inspection; no identity, Firebase, signing, source, build,
device, or credential changes were performed. This report is the only file
created by the preflight.

## Recommendation

**Decision: CONDITIONAL GO; implementation is currently on HOLD.**

Migrating Android from `com.example.sos_app` to
`com.n1cxltine.sosapp` is technically straightforward and is preferable before
the first distribution. The owner has confirmed that the Android app has only
been installed locally and has never been distributed. No Play update lineage
therefore needs to be preserved.

Do not start the edit until all three gates below are satisfied:

1. Register a new Android app named exactly `com.n1cxltine.sosapp` in the
   existing Firebase project and obtain its configuration through an
   owner-controlled Firebase session.
2. Decide whether data in the existing `com.example.sos_app` test sandbox may
   be abandoned. There is no confirmed in-app export/import facility. If any
   Guest SOS, BLE queue, Chat, or delivery evidence matters, retain the old app
   and make an approved backup before migration testing.
3. Commit or otherwise create a reviewed snapshot of the current Phase A2 work.
   The working tree is not clean at this preflight, so an identity migration on
   top of it would make review and rollback unnecessarily risky.

This is not a Release Gate approval. Signed Android/iOS artifacts, production
map configuration, and outstanding physical reliability evidence remain
separate blockers.

## Baseline and confirmed findings

- Audited revision: `8e2b5ad`.
- The working tree already contains modified and untracked Role UX, SOS, BLE,
  validation, and release-readiness work. Those changes were preserved.
- No test, build, install, uninstall, app-data clear, Firebase write, signing
  task, or device operation was run for this preflight.
- No keystore, password, API key, client secret, or private signing material is
  reproduced in this report.

### Android build identity

| Item | Confirmed state | Migration impact |
| --- | --- | --- |
| Application ID | `com.example.sos_app` in `android/app/build.gradle.kts` | Change to `com.n1cxltine.sosapp` |
| Android namespace | `com.example.sos_app` in the same Gradle file | Change with the application ID |
| Product flavors | None | No flavor-specific IDs to migrate |
| Application ID suffixes | None | No debug/profile suffix interaction |
| Build types | Release is explicitly configured; debug/profile use normal Android defaults | Preserve behavior |
| Kotlin source package | `MainActivity.kt` and `BleTransportBridge.kt` declare `com.example.sos_app` and live under the matching directory | Move both files and change both declarations |
| Java sources | Only Flutter's generated registrant under `io.flutter.plugins` | Do not edit generated source |

Android permits `namespace` and `applicationId` to differ, but they serve
different purposes. `applicationId` is the installed/store identity and
Firebase package match. `namespace` controls generated Android classes and the
resolution of relative component names. Keeping them different here provides
no benefit and would leave `.MainActivity` coupled to the old namespace.
Change both to `com.n1cxltine.sosapp` in the same reviewed change.

### Manifests, components, and links

The main manifest contains no legacy `package` attribute. It declares
`.MainActivity`, which will resolve against the new namespace after migration.
The debug and profile manifests only add Internet access.

No application provider, custom authority, manifest placeholder, deep link,
app link, custom URI scheme, or `autoVerify` declaration was found. Therefore
no manifest source edit is expected solely for the ID change. The merged APK
manifest must still be inspected after the build to prove that the application
ID and activity class resolve correctly.

Android permissions currently cover Internet, coarse/fine location, legacy
Bluetooth through Android 11, and Bluetooth Scan/Connect/Advertise on newer
versions. The migration does not justify changing them.

### Firebase configuration

The repository's tracked Android Firebase configuration has one Android client
and it matches `com.example.sos_app`. The generated Dart Android options and
`firebase.json` refer to that same current Firebase Android app. The iOS client
is separate and already matches `com.n1cxltine.sosapp`.

A **new Firebase Android app registration is required** because Firebase binds
an Android app registration to its package name. Renaming text inside the old
`google-services.json` is invalid. The owner must add
`com.n1cxltine.sosapp` to the existing Firebase project, download the matching
file through Firebase Console, and regenerate/reconcile FlutterFire metadata.
The old Android registration should remain temporarily for rollback; deleting
it is unnecessary.

The app calls `Firebase.initializeApp` with generated
`DefaultFirebaseOptions.currentPlatform`, so updating only
`google-services.json` is insufficient. The Android entry in
`lib/firebase_options.dart` and the Android mapping in `firebase.json` must
match the new Firebase Android app. The iOS options, iOS plist, and iOS bundle
ID must remain unchanged.

Authentication currently uses Firebase email/password. Certificate SHA
fingerprints are not required for that method alone, but the owner should add
the intended debug and release fingerprints to the new registration before
using services that require them, such as Google Sign-In, Phone Auth, Dynamic
Links, or certificate-bound API restrictions. Do not log certificate private
material or configuration contents.

Firestore rules authorize by `request.auth.uid` and document `ownerId`; they do
not refer to Android package name or Firebase app ID. No Firebase Rules change
is required or proposed.

### Local storage, Guest continuity, and Android sandbox

The Drift database opens the logical database name `sos_app`. Guest SOS rows
use the stable local owner value `guest-local-device`; authenticated rows and
the sync queue retain their Firebase owner UID. BLE outbox/inbox and Chat rows
are in the same Drift database.

These values do not make data portable across application IDs. Android treats
`com.n1cxltine.sosapp` as a separate application with a separate Linux UID and
private data directory. The new app cannot automatically read the old app's:

- Drift SOS, sync queue, BLE inbox/outbox, and Chat database;
- Firebase Auth session and Firestore local cache;
- role preference in private `SharedPreferences`; or
- BLE installation identity in private `SharedPreferences`.

The old and new packages can coexist during controlled testing, but that is a
fresh installation of the target package, not an update. Existing local Guest
data must be considered unavailable in the new app unless a separate, reviewed
export/import or data migration is designed. None is proposed in this phase,
and database schema or ownership changes are explicitly out of scope.

Cloud records in the same Firebase project are not deleted by registering the
new Android client. A controlled user who signs in to the new app should retain
the same Firebase UID, but cloud-history behavior must be verified against the
actual new registration and rules. This does not restore the old local
database or pending local queues.

### BLE identity and peer discovery

Android obtains `deviceIdentity` by reading a UUID from private
`SharedPreferences` named `sos_device`, generating and synchronously persisting
one only when absent. The value is not derived from `applicationId`, namespace,
Firebase UID, Android package name, or BLE MAC address. BLE service,
characteristic, and descriptor UUIDs are hard-coded protocol constants and do
not contain the application ID.

The package migration still causes a new BLE installation identity because the
new sandbox starts with empty preferences. Old peers may retain routes bound to
the old installation identity, while the new app advertises the same BLE
service using a new identity. Pending messages in the old app remain in the old
database and are not transferred. Run fresh two-way discovery, SOS, ACK, Chat,
Location, reconnect, wrong-peer, and deduplication checks on the target build.
Do not change UUIDs, wire message kinds, stable message IDs, or peer validation
to hide this expected new-install behavior.

Avoid running both package variants in the foreground during the same BLE test;
they advertise the same service and can make device selection/evidence
ambiguous.

### Signing safety

Release signing reads ignored `android/key.properties` and requires
`storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. A requested release
task fails explicitly when any value is missing. The release build type only
uses the release signing config when all required values exist; there is no
silent debug-signing fallback.

No project upload keystore or `android/key.properties` is present or tracked,
and `.gitignore` excludes `key.properties`, `*.jks`, and `*.keystore`. Changing
the application ID does not technically require a different signing key, but
the eventual Play record and signed candidate must use the owner-approved
upload identity. This migration must not create, replace, or edit signing
assets.

### Other current-ID references

Confirmed non-historical source/config references are:

- `android/app/build.gradle.kts` — namespace and application ID;
- `android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt` — directory
  and package declaration;
- `android/app/src/main/kotlin/com/example/sos_app/BleTransportBridge.kt` —
  directory and package declaration;
- `android/app/google-services.json` — current Firebase Android registration;
- `firebase.json` — current Firebase/FlutterFire Android app mapping;
- `lib/firebase_options.dart` — generated current Firebase Android options;
- `lib/features/sos/presentation/map_tile_provider.dart` — development-only
  fallback map user-agent;
- `test/map_tile_provider_test.dart` and
  `test/incident_map_page_test.dart` — map user-agent fixtures.

There is no matching reference in a checked-in CI or project script. Several
release/readiness documents and historical validation JSON files record the old
artifact identity. Living instructions must be updated after migration;
historical evidence must remain truthful and must not be rewritten to imply old
artifacts used the new ID.

In iOS and shared Dart code:

- `com.n1cxltine.sosapp` in the Xcode Runner settings,
  `GoogleService-Info.plist`, and the iOS FlutterFire options is already correct
  and must remain unchanged.
- The Dart package/import name `sos_app` is independent of Android application
  ID and must remain unchanged.
- Method-channel names such as `sos_app/preferences` and
  `sos_ble_transport/methods` are internal protocol names, not Android package
  IDs, and must remain unchanged.
- The production `MAP_TILE_USER_AGENT` is injected externally. The owner's
  private release define file and any provider restriction must use the final
  target identity after migration; no key belongs in source control.

## Exact proposed file-change list

### Required implementation changes

1. `android/app/build.gradle.kts`
   - Set `namespace` and `defaultConfig.applicationId` to
     `com.n1cxltine.sosapp`.
   - Remove the obsolete template TODO about choosing an ID.
   - Leave build types and signing guards unchanged.
2. Move
   `android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt` to
   `android/app/src/main/kotlin/com/n1cxltine/sosapp/MainActivity.kt` and change
   its package declaration.
3. Move
   `android/app/src/main/kotlin/com/example/sos_app/BleTransportBridge.kt` to
   `android/app/src/main/kotlin/com/n1cxltine/sosapp/BleTransportBridge.kt` and
   change its package declaration. Change no BLE behavior or constants.
4. Replace `android/app/google-services.json` with the file downloaded for the
   new Android registration. Do not hand-edit it.
5. Regenerate/reconcile only the Android registration references in
   `lib/firebase_options.dart` and `firebase.json`; preserve the existing iOS
   registration unchanged.
6. Change the development fallback user-agent in
   `lib/features/sos/presentation/map_tile_provider.dart` and matching fixtures
   in `test/map_tile_provider_test.dart` and
   `test/incident_map_page_test.dart`.

### Documentation/evidence changes after implementation

Update the living identity statements and commands in:

- `OFFLINE_SOS_RELEASE_READINESS.md`;
- `PHYSICAL_TEST_SESSION_CHECKLIST.md`;
- `PHASE_A_MANUAL_ACTIONS.md`; and
- `PHASE_A2_RELEASE_BLOCKERS.md`.

Add new migration validation evidence containing command exit codes, artifact
identity/version/hash, Firebase match status, and physical results without
credentials or personal data. Keep Phase 7–10 and Phase A historical artifact
records unchanged, adding a superseding reference if needed.

### Files that are not expected to change

- Android manifests, unless post-build merged-manifest inspection reveals an
  actual unresolved component;
- iOS project, bundle ID, plist, FlutterFire iOS options, or signing assets;
- `pubspec.yaml` and Dart import package name;
- Drift schema, migrations, Guest owner constant, sync ownership filters, or
  Firebase Rules;
- BLE UUIDs, message kinds, ACK semantics, identity format, or protocol;
- Android upload keystore, `android/key.properties`, signing behavior, store
  records, or credentials.

## Safe ordered migration plan

### 1. Freeze and back up before editing

1. Review the current dirty tree and commit the completed Phase A2 work on a
   dedicated branch, or create an equivalent reviewed source snapshot that
   includes untracked files. Record the commit and `git status`.
2. Record the old package's installed version, signing certificate digest,
   non-sensitive SOS/queue counts, and any physical evidence that must be
   retained. Do not clear or uninstall it.
3. If existing local records matter, stop here until an approved export or
   migration method exists. A debug-only filesystem copy may be retained as
   forensic backup where platform policy permits, but it is not a supported
   restore path into the new package and must not be treated as continuity.
4. Back up the current Firebase configuration files in an access-controlled
   location and record checksums without printing their contents.

### 2. Complete owner Firebase actions

1. In Firebase Console project `sos-app-d811a`, add an Android app with package
   name exactly `com.n1cxltine.sosapp`.
2. Use an owner-approved display name. Do not alter or delete the existing
   Android or iOS registration.
3. Add the approved debug/release SHA fingerprints if a configured Firebase
   feature requires them.
4. Download the new `google-services.json` privately. Confirm only that its
   package matches the target and its project matches the intended project;
   never paste or print keys in logs or review comments.
5. Use the official FlutterFire configuration workflow to associate Android
   with the new Firebase app and regenerate Dart metadata. Review the diff so
   the existing iOS registration remains byte-for-byte or semantically
   unchanged.

### 3. Apply the identity change atomically

1. Create a dedicated migration branch from the frozen baseline.
2. Apply the Gradle ID/namespace edit and Kotlin moves listed above.
3. Install the new Firebase Android file and generated Android FlutterFire
   metadata in the same commit.
4. Update the development map user-agent and its tests.
5. Search tracked non-historical code/config for `com.example.sos_app` and
   classify every remaining match. Only explicit historical evidence should
   remain.
6. Review the diff for accidental iOS, signing, schema, rules, dependency, or
   BLE protocol changes before running validation.

### 4. Automated validation

Run from the frozen migration branch and retain actual exit codes:

```sh
flutter test test/map_tile_provider_test.dart test/incident_map_page_test.dart
flutter test test/guest_continuity_test.dart test/local_device_history_test.dart
flutter test test/ble_identity_release_gate_test.dart test/ble_delivery_repository_test.dart test/sos_ble_coordinator_test.dart
flutter test
flutter analyze lib test
flutter build apk --debug
git diff --check
```

Then inspect the produced APK with Android build tools and record, without
secrets:

- application ID is exactly `com.n1cxltine.sosapp`;
- launcher activity resolves to
  `com.n1cxltine.sosapp.MainActivity`;
- version name/code are expected;
- certificate is the expected debug certificate for this validation only;
- Firebase Android package/project/app registration are mutually consistent;
- no release AAB or signed release claim was created.

Run the existing release-signing guard check without adding credentials. A
missing signing configuration must still fail closed and create no release
artifact. A real signed release remains NOT RUN until the owner separately
supplies and authorizes signing material.

### 5. Device verification without destroying old data

#### Fresh-install verification

1. Leave `com.example.sos_app` installed and untouched initially.
2. Install the debug target package `com.n1cxltine.sosapp`. Because it has a
   different ID, this is a separate fresh app, even if the command succeeds
   without removing the old app.
3. Confirm the target starts with no old Guest/local history and a newly
   persisted BLE installation identity. Restart it and confirm that its new
   identity and newly created Guest record remain stable.
4. Using controlled accounts, verify login, logout, A/B isolation, Firebase
   read/write authorization, Guest non-upload, cloud failure/retry, and session
   recovery.
5. Run fresh Android↔iPhone and Android↔Android SOS/ACK, Chat, Location,
   reconnect, duplicate, ACK-loss, and wrong-peer checks. Record application
   ACK and receiver persistence; native write alone is not delivery.

#### Update-in-place verification

An old-ID-to-new-ID install is not an update-in-place test and must never be
reported as one. To test future upgrades safely:

1. Install target-package build A using the intended test signing identity.
2. Create synthetic Guest SOS, queued/acknowledged BLE, Chat, role, and
   authenticated-isolation state in build A.
3. Build target-package build B with the same package and signing identity and
   an acceptable version code.
4. Install B using the platform's replace/update operation without uninstalling
   or clearing data.
5. Confirm database rows, Guest visibility, role preference, BLE installation
   identity, pending retry, ACK/deduplication, and account isolation survive.

Only after the target package is accepted and old test data is no longer
needed should removal of the old app be considered as a separate destructive
owner action.

## Rollback procedure

1. Stop on any Firebase mismatch, wrong manifest ID, unresolved activity,
   ownership regression, signing fallback, or data-continuity surprise.
2. Revert the single identity-migration commit or reset the migration branch to
   the recorded frozen baseline. Restore the original Firebase config files
   from the protected backup and verify their checksums.
3. Rebuild the old package and rerun its focused identity/Guest/BLE checks.
4. Leave the old Firebase Android registration intact throughout rollback.
   The unused new registration may also remain; deleting it is an external
   owner decision and is not needed to restore source behavior.
5. Do not uninstall either package as part of source rollback. If the new app
   contains data, preserve it until the owner explicitly approves deletion.
6. Data created inside the target sandbox cannot be merged back into the old
   sandbox by Git rollback. Treat any such transfer as a separate migration
   project.

## Acceptance criteria

The application-ID migration is accepted only when all of the following are
recorded:

- Gradle application ID and namespace, Kotlin packages/paths, merged manifest,
  and APK identity all equal `com.n1cxltine.sosapp`.
- The new Firebase Android registration, `google-services.json`, generated Dart
  Android options, and `firebase.json` match each other and the intended
  project; iOS configuration is unchanged.
- No unintended old-ID reference remains in live source/config, and historical
  records remain accurate.
- Full tests, focused identity/Guest/BLE tests, analyzer, Android debug build,
  and whitespace checks pass with captured exit codes.
- Missing release signing still fails closed; no debug-signed artifact is
  labeled as a release candidate.
- Fresh installation behavior is explicitly recorded, including the expected
  absence of the old sandbox's Guest/local records and the new stable BLE
  identity.
- Target-to-target update-in-place preserves the target sandbox's Guest SOS,
  queues, Chat, role preference, and BLE identity.
- Controlled Firebase accounts pass Guest non-upload and account isolation.
- Current-source physical BLE behavior passes required directions and failure
  cases; no old-build evidence is reused.
- Drift schema, Firebase Rules, ownership semantics, Guest isolation, BLE UUIDs,
  protocol, and dependencies are unchanged.

## Remaining owner decisions and release blockers

### Decisions required before implementation

1. Confirm whether the old Android test sandbox contains anything that must be
   preserved. If yes, approve a separate export/retention plan before editing
   or device cleanup.
2. Create/authorize the new Firebase Android app registration and provide its
   downloaded configuration through a secure local path.
3. Approve the frozen baseline/branch that the migration will be applied to.
4. Confirm that the old Firebase Android registration will be retained through
   rollback and acceptance; this report recommends retaining it.

The permanent Android target ID and distribution-history decision are already
resolved by the owner and do not need to be asked again.

### Blockers that remain after identity migration

- account-owned Android upload signing and an inspected signed AAB;
- Apple distribution signing and an inspected archive/export;
- account-owned Geoapify configuration, restrictions, and live verification;
- target-build Firebase failure/session recovery evidence; and
- outstanding physical reliability, fault-injection, Android-to-Android, and
  range evidence.

Subject to the four pre-implementation actions above, the migration is safe to
begin. It is not safe to promise preservation of existing Android local data,
and implementation must stop before any attempt to merge, rewrite ownership,
change schema/rules/protocol, create signing assets, or remove the old app.
