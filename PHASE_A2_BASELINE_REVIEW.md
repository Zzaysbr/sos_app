# Phase A2 — Baseline Review

Date: 23 October 2026 (Asia/Bangkok)

References:

- `PHASE_A2_IDENTITY_MIGRATION_READINESS.md`
- `PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md`

Scope: repository review and staging-plan preparation only. No source,
configuration, identity, Firebase, signing, device, index, stash, commit, or
remote operation was performed. This report is the only file created.

## Final decision

**Commit execution: NO-GO in this task.**

The proposed baseline is internally coherent and may proceed to an explicit
staging review after owner authorization. Commit execution remains NO-GO now
because this task expressly prohibits staging and committing, and the recorded
test evidence is historical evidence tied to an uncommitted working tree rather
than an immutable commit.

Before any future commit, stage exactly one manifest below, confirm the staged
name list and complete staged diff, run `git diff --cached --check`, and verify
that the implementation snapshot has not changed. Do not begin Android identity
migration until all three baseline commits are authorized and recoverable.

## Git baseline and working-tree status

| Item | Observed state |
| --- | --- |
| Branch | `main` |
| HEAD | `8e2b5ad115071f31ad781ccf43eff41f73dd8abd` |
| Upstream | `origin/main` |
| Divergence | 0 ahead / 0 behind |
| Staged changes | 0 |
| Tracked modifications | 10 files |
| Untracked files before this report | 18 files |
| Ignored files | 36,104 files, mainly dependency/build caches and prior logs |
| Tracked diff | 939 insertions, 99 deletions |
| Tracked `git diff --check` | No whitespace errors |

The committed baseline and upstream relationship match the readiness report.
That report correctly recorded 10 tracked modifications and 17 untracked files
before the readiness report itself was created. The current eighteenth
untracked file is `PHASE_A2_IDENTITY_MIGRATION_READINESS.md`. This baseline
review becomes the nineteenth untracked file.

### Tracked modifications compared with readiness

All ten paths match exactly:

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

### Untracked files compared with readiness

All eighteen current paths match the seventeen pre-existing paths plus the
readiness report predicted by that document:

1. `.impeccable.md`
2. `CLAUDE.md`
3. `PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md`
4. `PHASE_A2_IDENTITY_MIGRATION_READINESS.md`
5. `PHASE_A2_RELEASE_BLOCKERS.md`
6. `PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md`
7. `ROLE_BASED_UX_AUDIT.md`
8. `ROLE_BASED_UX_VALIDATION.md`
9. `lib/core/theme/app_theme.dart`
10. `lib/features/role/data/role_preference_store.dart`
11. `lib/features/role/domain/app_role.dart`
12. `lib/features/role/domain/role_workflow_controller.dart`
13. `lib/features/role/presentation/role_selection_page.dart`
14. `test/role_based_ux_test.dart`
15. `validation/phase-a2/command-results.json`
16. `validation/phase-a2/test-matrix.json`
17. `validation/role-based-ux/command-results.json`
18. `validation/role-based-ux/test-matrix.json`

### Ignored files compared with readiness exclusions

Ignored files are present in the following top-level groups. They are not part
of any proposed commit:

| Path/category | Count | Status |
| --- | ---: | --- |
| `build/` | 20,870 | Generated build output; EXCLUDE |
| `packages/` ignored content | 7,575 | Vendored/package generated content; EXCLUDE |
| `ios/` ignored content | 6,647 | Pods, derived build/signing copies; EXCLUDE |
| `.dart_tool/` | 790 | Generated Dart tooling state; EXCLUDE |
| `validation/**/*.log` | 114 | Prior raw/sanitized command logs; EXCLUDE from this baseline |
| `.widget_preview/` | 71 | Generated preview state; EXCLUDE |
| `android/` ignored content | 26 | Local/Gradle state; EXCLUDE |
| `.idea/` | 5 | Local IDE state; EXCLUDE |
| Other ignored root metadata/logs | 6 | Local/generated state; EXCLUDE |

The counts include files already covered by Git ignore rules. Their presence
does not alter the exact staged manifests below.

## Dependency review

### Commit 1 must remain one atomic implementation/test set

`SosPage` imports the new role store, role model, workflow controller, role
selection page, and `BleDeliveryRepository`. It also calls the newly added
`SosRepository.listActiveIncidents()` and reads `repository.database` for the
delivery view. Omitting any of those source changes would either break
compilation or remove a documented ownership/state guard.

`main.dart` uses the new `AppTheme`. Android `MainActivity.kt` and iOS
`AppDelegate.swift` implement the platform channel required by
`PlatformRolePreferenceStore`; omitting either native change would leave role
persistence incomplete on that platform.

The three test files depend on the same new role modules and repository API.
Keeping them with the implementation makes the commit self-contained and
prevents a source-only baseline without its regression coverage.

No Commit 1 file changes application ID, namespace, native package path,
Firebase mapping, signing, dependency manifests, schema, Firebase Rules, BLE
UUIDs, or production message kinds.

### Commit 2 may follow Commit 1 without affecting compilation

Commit 2 contains design context, release/checklist updates, audit documents,
and JSON validation evidence only. It has no runtime import or build dependency.
It is semantically dependent on Commit 1 because its claims and referenced test
paths describe that implementation. Therefore it must be committed after
Commit 1, not before it, and must not be separated from the evidence JSON it
summarizes.

`.impeccable.md` and `CLAUDE.md` are byte-identical design-context documents
for different tooling entry points. The Role UX audit explicitly lists both.
The proposed manifest includes both so the audit remains accurate. If the owner
chooses not to track repository-level agent guidance, remove both from Commit 2
and update `ROLE_BASED_UX_AUDIT.md` before staging; do not stage only one copy or
silently leave the audit inconsistent.

### Commit 3 is planning evidence only

The preflight, readiness gate, and this review contain no implementation.
Commit 3 can be reviewed independently after Commits 1 and 2. It records that
the identity migration remains blocked and must not include future Gradle,
Firebase, package-path, or signing changes.

## Validation evidence consistency review

No test or build was run during this review. The following findings compare the
existing evidence with the current files only and do not constitute new PASS
results.

- All four proposed JSON evidence files parse successfully.
- `validation/role-based-ux/command-results.json` records the earlier Role UX
  stage: 35 focused tests and 220 full tests.
- `validation/phase-a2/command-results.json` records the later A2 stage: 156
  focused tests and 224 full tests. The different counts represent two recorded
  stages and are not internally contradictory.
- The current `test/role_based_ux_test.dart` contains the cited cases for rapid
  duplicate prevention, active-incident/queue preservation, Rescue owner
  scoping, idempotent acceptance, Light/Dark/System behavior, and application
  ACK wording.
- The test matrices keep every current-build physical row at `NOT RUN`; they do
  not reuse older physical BLE evidence as a new PASS.
- Phase A2 evidence keeps the full-repository analyzer result at exit 1 for
  vendored info findings and keeps signed releases/live production map as NOT
  RUN. It does not hide those limitations.
- The ignored Android debug APK currently exists and its SHA-256 matches the
  digest recorded in Phase A2 evidence. This is a read-only artifact comparison,
  not a new build or test result, and the APK remains excluded from commits.

The evidence uses `8e2b5ad with preserved Role UX working-tree changes` rather
than an immutable source commit. It has no full source-tree digest, so it cannot
prove that no byte changed after the commands ran. To identify the exact state
reviewed here, deterministic path/content snapshots were calculated:

- Commit 1 proposed files: 14 files; snapshot SHA-256
  `79b74793ff5e4800feb905afefff5bc376a8762fc5e8da984b40c811ad8fe13e`
- Commit 2 proposed files: 12 files; snapshot SHA-256
  `e4e0fccf0e5ddfec835464346bc3128412e6fce31cb9f65683731ae786c00b08`

These hashes identify the reviewed file sets only; they do not replace test
execution. If either snapshot changes before staging, treat the prior command
evidence as requiring renewed review and rerun affected validation.

## Exact staging manifest

### Proposed Commit 1 — Role UX implementation and regression coverage

Proposed message: `feat: add role-based SOS and rescue UX`

| Exact path | Reason for inclusion |
| --- | --- |
| `android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt` | Android role-preference channel required by the new store |
| `ios/Runner/AppDelegate.swift` | iOS role-preference channel required by the new store |
| `lib/core/theme/app_theme.dart` | Calm & Decisive Light/Dark theme definitions |
| `lib/features/nearby_ble/data/ble_delivery_repository.dart` | Durable inbound SOS IDs used by owner-scoped Rescue UI |
| `lib/features/role/data/role_preference_store.dart` | Platform and in-memory role persistence abstraction |
| `lib/features/role/domain/app_role.dart` | Need Help/Rescue role model |
| `lib/features/role/domain/role_workflow_controller.dart` | Duplicate and concurrent local workflow guards |
| `lib/features/role/presentation/role_selection_page.dart` | Explicit role-selection UI |
| `lib/features/sos/data/sos_repository.dart` | Current-owner active-incident query used by switch/duplicate guards |
| `lib/features/sos/presentation/sos_page.dart` | Role navigation, Rescue list, status copy, and repeated-SOS fix |
| `lib/main.dart` | Applies Light/Dark/System application themes |
| `test/ble_start_order_test.dart` | Adapts BLE-start regression to role-aware shell |
| `test/local_device_history_test.dart` | Preserves Guest/local history coverage in role-aware shell |
| `test/role_based_ux_test.dart` | New role, isolation, state, duplicate, theme, and wording coverage |

Proposed command; **do not execute without authorization**:

```sh
git add -- \
  android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt \
  ios/Runner/AppDelegate.swift \
  lib/core/theme/app_theme.dart \
  lib/features/nearby_ble/data/ble_delivery_repository.dart \
  lib/features/role/data/role_preference_store.dart \
  lib/features/role/domain/app_role.dart \
  lib/features/role/domain/role_workflow_controller.dart \
  lib/features/role/presentation/role_selection_page.dart \
  lib/features/sos/data/sos_repository.dart \
  lib/features/sos/presentation/sos_page.dart \
  lib/main.dart \
  test/ble_start_order_test.dart \
  test/local_device_history_test.dart \
  test/role_based_ux_test.dart
```

### Proposed Commit 2 — Role UX audit and validation evidence

Proposed message: `docs: record Phase A2 role UX validation`

| Exact path | Reason for inclusion |
| --- | --- |
| `.impeccable.md` | Recorded design context used for the Role UX direction |
| `CLAUDE.md` | Matching tool-specific copy of the recorded design context |
| `OFFLINE_SOS_RELEASE_READINESS.md` | Living release gate updated with Role UX/A2 status |
| `PHYSICAL_TEST_SESSION_CHECKLIST.md` | Adds the unexecuted role-specific physical gate |
| `PHASE_A2_RELEASE_BLOCKERS.md` | Historical Phase A2 blocker inventory |
| `PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md` | Physical matrix with PASS policy and NOT RUN status |
| `ROLE_BASED_UX_AUDIT.md` | Architecture, ownership, UX, and limitation audit |
| `ROLE_BASED_UX_VALIDATION.md` | Earlier Role UX automated-validation summary |
| `validation/phase-a2/command-results.json` | Machine-readable later A2 command evidence |
| `validation/phase-a2/test-matrix.json` | Machine-readable A2 automated/physical matrix |
| `validation/role-based-ux/command-results.json` | Machine-readable earlier Role UX command evidence |
| `validation/role-based-ux/test-matrix.json` | Machine-readable earlier Role UX test matrix |

Proposed command; **do not execute without authorization**:

```sh
git add -- \
  .impeccable.md \
  CLAUDE.md \
  OFFLINE_SOS_RELEASE_READINESS.md \
  PHYSICAL_TEST_SESSION_CHECKLIST.md \
  PHASE_A2_RELEASE_BLOCKERS.md \
  PHASE_A2_ROLE_UX_PHYSICAL_VALIDATION.md \
  ROLE_BASED_UX_AUDIT.md \
  ROLE_BASED_UX_VALIDATION.md \
  validation/phase-a2/command-results.json \
  validation/phase-a2/test-matrix.json \
  validation/role-based-ux/command-results.json \
  validation/role-based-ux/test-matrix.json
```

### Proposed Commit 3 — Identity migration planning gates

Proposed message: `docs: record Android identity migration baseline gates`

| Exact path | Reason for inclusion |
| --- | --- |
| `PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md` | Authoritative migration impact and rollback plan |
| `PHASE_A2_IDENTITY_MIGRATION_READINESS.md` | Firebase/baseline NO-GO gate and original commit proposal |
| `PHASE_A2_BASELINE_REVIEW.md` | Exact manifest, dependency, evidence, and staging review |

Proposed command; **do not execute without authorization**:

```sh
git add -- \
  PHASE_A2_IDENTITY_MIGRATION_PREFLIGHT.md \
  PHASE_A2_IDENTITY_MIGRATION_READINESS.md \
  PHASE_A2_BASELINE_REVIEW.md
```

## Files and categories excluded from staging

The following names/categories may contain machine-specific configuration,
credentials, personal/device information, signing data, or generated output.
Only names and status are reported; contents were not included in this review.

| File or pattern | Status |
| --- | --- |
| `android/local.properties` | IGNORED; local SDK configuration; EXCLUDE |
| `firebase-debug.log` | IGNORED; raw Firebase log; EXCLUDE |
| `firestore-debug.log` | IGNORED; raw Firestore log; EXCLUDE |
| `validation/phase6_3/*.log` | IGNORED; historical command logs; EXCLUDE |
| `validation/phase7/*.log` | IGNORED; historical/device/build logs, including sanitized logs; EXCLUDE from this baseline |
| `validation/week5/*.log` | IGNORED; historical/device/build logs; EXCLUDE from this baseline |
| `build/app/outputs/apk/debug/app-debug.apk` | IGNORED generated debug artifact; EXCLUDE |
| `build/app/outputs/flutter-apk/app-debug.apk` | IGNORED generated debug artifact; EXCLUDE |
| `build/ios/**/Runner.app/GoogleService-Info.plist` | IGNORED generated configuration copies; EXCLUDE |
| `build/ios/**/Runner.app/embedded.mobileprovision` | IGNORED signing/provisioning copies; EXCLUDE |
| `build/`, `.dart_tool/`, `.gradle/`, `ios/Pods/` | IGNORED generated/dependency content; EXCLUDE |

No project `key.properties`, keystore, `.p12`, `.p8`, standalone provisioning
profile, or ExportOptions file was found outside ignored build outputs. No
secret-shaped value was found in the 27 reviewed changed/untracked files that
existed before this report. The Firebase files currently tracked for the old
application remain unchanged and are absent from every staging manifest.

## Required staged-diff review before any future commit

File content may change after this report because the working tree is shared
and uncommitted. Before each commit, run the following read-only checks after
staging the authorized manifest:

```sh
git status --short
git diff --cached --name-status
git diff --cached --stat
git diff --cached --check
git diff --cached
```

The reviewer must confirm:

1. The staged path list equals the relevant manifest exactly; no path from a
   later commit or exclusion category is present.
2. Commit 1 still contains all native channels, new role modules, repository
   APIs, UI integration, and three test files as one set.
3. Commit 2 contains only documentation/design/evidence and its JSON remains
   valid and truthful about historical versus NOT RUN results.
4. Commit 3 contains only the three planning documents and still says migration
   is blocked pending verified target Firebase configuration.
5. No ID, namespace, native package path, Firebase mapping, signing, schema,
   Rules, BLE protocol, dependency, secret, or generated artifact entered the
   staged diff.
6. If Commit 1 or Commit 2 content differs from the snapshot hashes recorded
   above, inspect the cause and rerun affected validation before claiming the
   existing evidence applies.

Risks of skipping this review include committing an incomplete platform
preference implementation, separating tests from required APIs, attaching
historical evidence to different source bytes, accidentally capturing local
logs/build outputs, or mixing identity migration configuration into the
baseline that is meant to precede it.

## Gate summary

- Baseline contents: **reviewable and coherently separated**.
- Proposed staging manifests: **complete and exact at review time**.
- Secrets/generated/config contamination in proposed manifests: **not found**.
- Fresh automated validation: **not run in this review**.
- Authorization to stage or commit: **not provided and explicitly prohibited**.
- Commit execution now: **NO-GO**.
- Android identity migration: **NO-GO** until baseline commits are authorized,
  captured, rechecked, and the target Firebase configuration is available and
  verified.
