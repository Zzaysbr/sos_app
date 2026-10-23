# Phase A2 — Identity Migration Readiness Gate

Date: 23 October 2026 (Asia/Bangkok)

Authoritative plan: `PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md`

Decision: **NO-GO — stop before implementation**

No application identifier, namespace, native package path, Firebase
configuration, signing setting, credential, device installation, or app data
was changed during this gate. This readiness report is the only new file.

## Repository baseline status

| Item | Observed state |
| --- | --- |
| Branch | `main` |
| HEAD | `8e2b5ad115071f31ad781ccf43eff41f73dd8abd` |
| Upstream | `origin/main` |
| Divergence | 0 ahead / 0 behind |
| Staged changes | 0 |
| Tracked working-tree modifications | 10 files |
| Untracked files before this report | 17 files |
| Baseline recoverability | Committed HEAD is recoverable; Phase A2 working-tree work is not yet captured by a commit/snapshot |

The Git baseline matches the revision recorded in the migration preflight and
the Phase A2 evidence. The committed starting point is recoverable from
`origin/main`. The Role UX implementation and its evidence exist only as
unstaged working-tree files, so the migration must not be layered on top of
them until they are reviewed and captured in dedicated commits or an equivalent
owner-approved snapshot.

### Exact tracked modifications since `8e2b5ad`

1. `OFFLINE_SOS_RELEASE_READINESS.md`
2. `PHYSICAL_TEST_SESSION_CHECKLIST.md`
3. `android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt`
4. `ios/Runner/AppDelegate.swift`
5. `lib/features/nearby_ble/data/ble_delivery_repository.dart`
6. `lib/features/sos/data/sos_repository.dart`
7. `lib/features/sos/presentation/sos_page.dart`
8. `lib/main.dart`
9. `test/ble_start_order_test.dart`
10. `test/local_device_history_test.dart`

### Exact untracked files before this report

1. `.impeccable.md`
2. `CLAUDE.md`
3. `PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md`
4. `PHASE_A2_RELEASE_BLOCKERS.md`
5. `PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md`
6. `ROLE_BASED_UX_AUDIT.md`
7. `ROLE_BASED_UX_VALIDATION.md`
8. `lib/core/theme/app_theme.dart`
9. `lib/features/role/data/role_preference_store.dart`
10. `lib/features/role/domain/app_role.dart`
11. `lib/features/role/domain/role_workflow_controller.dart`
12. `lib/features/role/presentation/role_selection_page.dart`
13. `test/role_based_ux_test.dart`
14. `validation/phase-a2/command-results.json`
15. `validation/phase-a2/test-matrix.json`
16. `validation/role-based-ux/command-results.json`
17. `validation/role-based-ux/test-matrix.json`

This report becomes the eighteenth untracked file. No other file was created or
modified by the readiness audit.

## Diff review

### Confirmed coherent Role UX changes

The source diff implements the previously documented Role UX work:

- platform-private role preference channels on Android and iOS;
- Light/Dark/System themes;
- Need Help and Rescue role models, selection, and local workflow state;
- active-incident duplicate protection and return flow;
- owner-scoped inbound SOS display for Rescue;
- retained SOS, Chat, Location, BLE queue, and incident identity while changing
  the local UI role;
- regression tests for role persistence, duplicate actions, isolation,
  acknowledgement wording, and theme contrast.

The Android native edit stays inside the existing
`com.example.sos_app` package and adds only the role-preference method channel.
The iOS native edit adds the equivalent `UserDefaults` channel. Neither edit
changes platform identity, BLE identity, protocol, or signing.

### Secret and artifact review

The 27 changed/untracked files present before this report were scanned by file
name and content pattern without printing matched values.

- Private-key markers: 0
- Password assignments: 0
- Google API-key-shaped values: 0
- Generic secret/token assignments: 0
- Keystore, signing property, certificate, provisioning, APK, AAB, IPA,
  archive, object, or compiled-library candidates: 0
- Files under tracked/untracked build, Gradle cache, Pods, or Dart tool output:
  0
- Tracked-diff whitespace errors: 0

The JSON files under `validation/` are text evidence, parse as valid JSON, and
do not contain raw build artifacts. They record debug/unsigned build results and
keep signed releases and physical tests correctly classified as NOT RUN or
BLOCKED where applicable.

No raw device logs, coordinates, installation identities, access tokens,
passwords, or signing credentials were found in the proposed snapshot.

### Configuration and unrelated-change review

No working-tree diff exists in:

- `android/app/build.gradle.kts`;
- `android/settings.gradle.kts`;
- Android manifests;
- `android/app/google-services.json`;
- `firebase.json`;
- `lib/firebase_options.dart`;
- `android/key.properties` or a keystore;
- iOS bundle-identifier/build settings;
- Firebase Rules;
- Drift schema/migrations;
- BLE UUID or production wire-message definitions; or
- dependency manifests.

Therefore no accidental identity, Firebase, signing, schema, Rules, protocol,
or dependency change is mixed into the current diff.

`.impeccable.md` and `CLAUDE.md` are identical, text-only design-context files.
They are not runtime code or generated build output. The Role UX audit
explicitly lists both as introduced artifacts, and their content matches the
Calm & Decisive Light/Dark implementation. The proposed plan keeps them in the
documentation/evidence commit so their intent is explicit. If the owner does
not want repository-level agent/design guidance, exclude both together and
update the audit's file list before committing; do not silently include only
one copy.

`PHASE_A2_RELEASE_BLOCKERS.md` records the identity decision as unresolved at
the time that evidence was produced. It should remain truthful historical
evidence. The migration preflight and this gate supersede that one decision;
the historical file must not be rewritten to imply the target Firebase
registration already exists.

No unrelated product feature was identified in the current diff.

## Proposed baseline commit plan

No commit was created. The following three-commit plan keeps implementation,
historical evidence, and the later identity decision independently reviewable.

### Commit 1 — Role UX implementation and regression coverage

Proposed message: `feat: add role-based SOS and rescue UX`

Include exactly:

1. `android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt`
2. `ios/Runner/AppDelegate.swift`
3. `lib/core/theme/app_theme.dart`
4. `lib/features/nearby_ble/data/ble_delivery_repository.dart`
5. `lib/features/role/data/role_preference_store.dart`
6. `lib/features/role/domain/app_role.dart`
7. `lib/features/role/domain/role_workflow_controller.dart`
8. `lib/features/role/presentation/role_selection_page.dart`
9. `lib/features/sos/data/sos_repository.dart`
10. `lib/features/sos/presentation/sos_page.dart`
11. `lib/main.dart`
12. `test/ble_start_order_test.dart`
13. `test/local_device_history_test.dart`
14. `test/role_based_ux_test.dart`

This commit should be accepted only after the already recorded focused/full
tests are rerun from the exact staged content or their prior evidence is
explicitly accepted as belonging to the same byte-for-byte tree.

### Commit 2 — Role UX audit, validation, and release evidence

Proposed message: `docs: record Phase A2 role UX validation`

Include exactly:

1. `.impeccable.md`
2. `CLAUDE.md`
3. `OFFLINE_SOS_RELEASE_READINESS.md`
4. `PHYSICAL_TEST_SESSION_CHECKLIST.md`
5. `PHASE_A2_RELEASE_BLOCKERS.md`
6. `PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md`
7. `ROLE_BASED_UX_AUDIT.md`
8. `ROLE_BASED_UX_VALIDATION.md`
9. `validation/phase-a2/command-results.json`
10. `validation/phase-a2/test-matrix.json`
11. `validation/role-based-ux/command-results.json`
12. `validation/role-based-ux/test-matrix.json`

The command evidence may reference artifacts under ignored `build/` paths, but
those binaries must stay excluded. Raw device logs must also remain excluded.

### Commit 3 — Identity migration planning evidence

Proposed message: `docs: record Android identity migration readiness`

Include exactly:

1. `PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md`
2. `PHASE_A2_IDENTITY_MIGRATION_READINESS.md`

This commit records a NO-GO gate and must not contain the future application-ID
implementation.

### Explicit exclusions from every baseline commit

- `build/`, `.dart_tool/`, Android/iOS derived data, Pods, Gradle caches, and
  compiled application artifacts;
- raw ADB/CoreDevice/Xcode logs or screenshots containing device identifiers or
  personal data;
- `android/key.properties`, keystores, certificates, private keys,
  provisioning profiles, export options containing account data, passwords,
  API secrets, and private map-define files;
- any downloaded Firebase configuration until the new registration is
  verified and the identity implementation is explicitly authorized; and
- any identifier, namespace, native package move, Firebase mapping, or signing
  edit from the future migration.

No currently changed file falls into these exclusion categories. If the owner
chooses not to track the two design-context files, apply the paired exception
described above before staging Commit 2.

## Firebase configuration readiness

Local, presence-only inspection produced the following result:

| Check | Result |
| --- | --- |
| Existing `android/app/google-services.json` present | YES |
| Existing file contains current `com.example.sos_app` client | YES |
| Existing file contains target `com.n1cxltine.sosapp` client | **NO** |
| `firebase.json` maps Android to a verified target registration | **NO** |
| Generated Dart Android options match a verified target registration | **NO** |
| Another matching target Firebase config supplied in the repository | **NO** |
| New target registration exists in Firebase Console | **NOT VERIFIED** |

Repository contents cannot prove that an owner may already have created the
registration in Firebase Console. No authenticated Console/CLI query was made,
and no registration was created or changed. What can be confirmed is that the
matching configuration file has **not** been supplied to this workspace and
the checked-in Android configuration still consistently targets the old app.

Do not rename or edit the old Firebase file. The owner must securely supply a
new file downloaded for the exact target package and intended existing project.
At implementation time, verify package/project/app consistency without printing
API keys or client values, then regenerate the Android FlutterFire mapping while
preserving iOS configuration.

## Guest and local-data preservation implications

Changing Android application ID creates a new Android package, Linux UID, and
private application sandbox. The target app will not automatically inherit:

- the Drift database containing Guest/account SOS, Chat, sync queue, BLE inbox,
  BLE outbox, message IDs, and delivery states;
- the Firebase Auth session or local Firestore cache;
- the locally persisted Need Help/Rescue preference; or
- the persisted BLE installation identity.

The Guest owner constant and BLE identity algorithm do not depend directly on
the application ID. Continuity is lost because their storage is private to the
old package. The target installation should therefore be expected to create a
new stable BLE identity and start with no old local history.

The old and target packages may coexist for controlled validation, but this is
not update-in-place. Do not uninstall or clear the old app. If its synthetic or
Guest data matters, retain the installation and establish an explicitly
approved export/retention method before migration. No supported cross-package
restore path is currently confirmed, and this gate does not authorize schema,
ownership, Guest merge, or data-transfer work.

## Remaining manual prerequisites

Before the migration can receive GO:

1. Review and explicitly authorize the proposed three-commit baseline plan.
2. Capture the entire Phase A2 working tree in those commits or an equivalent
   verifiable snapshot, then confirm a clean working tree and record the commit
   IDs.
3. Decide whether the old package's local test data may be abandoned. If not,
   approve a separate retention/export plan while keeping the old installation
   untouched.
4. In the existing Firebase project, create or confirm the Android registration
   for exactly `com.n1cxltine.sosapp` through an owner-controlled session.
5. Supply its matching `google-services.json` through a secure local path and
   verify presence/package/project consistency without exposing values.
6. Retain the old Firebase Android registration and old configuration backup
   through implementation acceptance and rollback testing.
7. Keep signing assets, map keys, private define files, and store actions out of
   this baseline. They remain separate owner-controlled release prerequisites.

## Gate decision

**NO-GO.** The committed Git starting point is recoverable, and the current
Role UX diff is coherent and free of detected secrets, generated binaries, and
accidental identity/signing/configuration changes. However, the Phase A2 work
has not yet been committed or snapshotted, and no verified Firebase Android
configuration for `com.n1cxltine.sosapp` is available in the workspace.

Recommend GO only after the baseline is captured and reviewed, the old local
data disposition is recorded, and the owner-supplied target Firebase
configuration is verified. Stop before changing IDs, namespace, package paths,
Firebase mappings, or signing behavior.
