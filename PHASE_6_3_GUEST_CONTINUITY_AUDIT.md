# Phase 6.3 — Guest continuity and authentication transitions

Audit date: 20 October 2026 (Asia/Bangkok).

## Findings and changes

1. **Visibility, not deletion:** the existing Guest owner was the constant `guest-local-device`. Drift persists rows in the `sos_app` database. Login changed `SosRepository.watchAll()` and `findById()` to the Firebase UID; no screen exposed the old Guest scope. Logout selected the same Guest scope again. No auth-triggered deletion or owner transfer was found.
2. **Retained session data:** existing repositories resolved their owner dynamically, subscriptions captured their old owner, and pushed details/maps/chat/account routes could outlive the Home auth rebuild. Repositories now bind to their construction-time owner, reject stale CRUD access, recheck detail reads after awaiting SQL, and clear subscribed rows on auth changes. A session-owned navigator removes old routes and dialogs on owner changes. Account/SOS dialogs use that navigator.
3. **BLE cross-session drain:** the existing coordinator loaded and recovered all durable outbox entries. AuthGate now binds a live session guard and supplies owner-scoped SQL filters for both due entries and stale recovery. SOS ownership and persisted chat ownership provide the filter; wire payloads are not used as authorization. Inactive sessions stop draining/handling new events and stop before each additional BLE frame; regression tests also cover an auth change after the first frame. Other owners' payloads, retry metadata, message IDs, inbox and delivery state remain untouched by the new filter. Standalone coordinators without an auth binding retain their existing behavior; AuthGate is the production caller and always supplies the binding.
4. **Guest status copy:** Guest records used `pending` internally and appeared as “Pending sync”. Cards/details now say “ข้อมูลในเครื่องเท่านั้น”; Guest sync is disabled, and assistance/sign-in copy explains that login does not upload existing Guest SOS.

No dependency, schema version, migration, BLE protocol, UUID or Firebase Security Rules change was made. All changes present at the initial `git status` were retained.

## Ownership and persistence audit

- Guest ID is a stable local database namespace, not a generated credential or secret. It was not regenerated on restart. The same literal is retained as `guestDeviceOwnerId` for compatibility with existing rows; secure storage and a random replacement ID would not improve this namespace and would hide existing records.
- Drift schema version remains **5**. `sos_messages.id` is the primary key; `owner_id` is required. Sync commands independently carry `sos_id`, `owner_id`, operation, payload snapshot and an auto-increment queue ID. BLE outbox/inbox and chat tables are unchanged.
- Create/update/delete retain the transaction-time owner checks and owner-qualified SQL. Updates preserve the creation-time incident location. No auth handler rewrites ownership, clones a row or enqueues a command.
- Guest CRUD commands already persisted in `sos_sync_queue` remain inert. Guest sync returns before cloud discovery or dispatch; authenticated queue and legacy-pending discovery use only the active Firebase UID. Repeated login does not promote Guest queue entries.
- Login only changes Firebase state. Failure/cancel leaves the current repository, records and queues intact. Logout calls Firebase sign-out, disposes session services and switches navigation/resources; it does not clear Drift.
- Startup initializes Firebase before creating AuthGate and opens the same named database. AuthGate seeds its stream with `currentUser` and uses the current Firebase user when rebuilding, avoiding a transient Guest owner during session restoration. Auth stream errors hide the session and dispose its resources.
- `SosSyncCoordinator` listens to auth/connectivity/resume and requests retries. Auth-scoped queue checks run before dispatch and after cloud completion. If an already dispatched A request finishes after switching accounts, it is not acknowledged locally under B; the original operation remains queued for A.
- `SosCloudService` writes `/sos/{id}` and checks individual document existence for legacy pending rows. It has **no cloud history download/list subscription**. Current account history is that account's local cache (including pending and previously synced rows), not a newly implemented Firestore archive.
- The checked-in rules at `security-tests/firestore.rules` require authentication and matching owner UID for SOS reads/deletes, and validate owner UID on creates/updates. Guest access cannot satisfy these rules. The deployed Firebase rules were not inspected or changed; no live cross-account cloud access is claimed as tested.

## Screen/data-source audit

| Screen | Source and scope |
| --- | --- |
| Home active SOS | `repository.watchAll()`, current session owner only |
| History list | `repository.watchAll()`, current session owner only; explicitly labeled current account when signed in |
| History → ข้อมูลในเครื่อง | `repository.watchDeviceHistory()`, exactly `guest-local-device`, never account A/B caches |
| Normal SOS detail | Existing selected current-scope row; existing Guest/current-account actions remain owner checked |
| Device-history detail | Reuses existing card/detail UI in read-only mode; no edit/delete/status, chat-send or location-share action |
| Incident Map | Existing immutable `SosMessage` snapshot selected from a permitted list/detail; Guest creation location remains available through device-history detail |
| BLE/chat/location sharing | Existing repositories/coordinator retained per owner; old session routes removed; new auth-bound BLE drains use ownership filters |

### Visibility after transitions

| State | Home/main History | ข้อมูลในเครื่อง → details/map | Other account cache |
| --- | --- | --- | --- |
| Guest, including restart | Guest SOS | Guest SOS | Hidden |
| Login to A, including restart | A's locally cached SOS | Guest SOS (read-only) | B hidden |
| Login cancelled/failed | Original scope remains | Guest SOS | Hidden |
| Logout / Firebase emits signed-out state | Guest SOS | Guest SOS | A/B hidden, retained on disk |
| Switch A → B | B's locally cached SOS | Guest SOS (read-only) | A hidden, retained on disk |

Device history is explicitly shared **on this device**. The app cannot identify the original human Guest on a shared unlocked device. The UI states this boundary; authenticated records are never included in this shared scope. Guest device-history access does not create, merge or upload data. Clearing app storage/uninstalling is not a supported durability guarantee.

## Files changed for this phase

- `lib/main.dart`: restored-session initialization, auth-bound BLE resources and session-owned navigation.
- `lib/features/auth/presentation/auth_session_navigator.dart`: session route boundary.
- `lib/features/sos/data/sos_repository.dart`: stable namespace, pinned owner, invalidated watchers/reads, explicit read-only device-history query and reserved Guest sync exclusion.
- `lib/features/sos/presentation/sos_page.dart`: device-history entry/page, reused read-only details/map access, local-only labels and Guest sync affordances.
- `lib/features/sos/presentation/account_page.dart`: session-local sign-out dialog.
- `lib/features/nearby_ble/data/ble_delivery_repository.dart`: SQL owner scope for due/recovery queries.
- `lib/features/nearby_ble/data/sos_ble_coordinator.dart`: live session guard and scoped queue processing.
- `test/guest_continuity_test.dart`: real SQLite close/reopen in Guest and authenticated modes, login/logout/account isolation, failed login, ownership/queue preservation, in-flight cloud change, BLE state invariance and queue scoping.
- `test/auth_session_navigator_test.dart`: same-session route preservation and changed-session removal of retained private routes/dialogs.
- `test/local_device_history_test.dart`: device-history details/map affordance and absence of account/BLE mutation actions.
- `test/sos_ble_coordinator_test.dart`: regressions proving an auth-bound coordinator drains A only and stops after auth change, including between BLE frames.
- This report. Other modified/untracked files in the original working tree belong to pre-existing work.

## Validation

| Command | Result |
| --- | --- |
| Focused auth/ownership/SOS/BLE/UI tests (6 files) | **PASS**, 56 tests, exit 0 |
| `flutter test` | **PASS**, 158 tests, exit 0; existing SOS, Chat, Location Sharing, map and BLE tests included |
| `flutter analyze` | **FAIL**, exit 1: 32 existing info-level issues, all under unchanged `packages/flutter_nearby_connections_plus/`; no app/test issues |
| `flutter analyze lib test` | **PASS**, no issues, exit 0 |
| `flutter build apk --debug` | **PASS**, exit 0; `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | **PASS**, exit 0 |
| `flutter doctor -v` | **PASS**, exit 0, no issues found |
| `flutter build ios --simulator --debug -v` | **PASS**, exit 0; `build/ios/iphonesimulator/Runner.app` |

Full logs are retained under `validation/phase6_3/` (ignored `*.log` files). Android emits an existing Kotlin Gradle Plugin migration advisory, but the build succeeds.

### iOS validation

- Xcode **26.6**, build **17F113**; installed iOS/iOS Simulator SDK **26.5**.
- Booted target: **iPhone 17 Pro**, simulator ID `93C6B1B9-FE85-4485-93FD-8FC33780C573`, iOS 26.5.
- A wireless physical iOS 27.0.1 device is discoverable; doctor also reports local-network pairing error -27. This validation targets the simulator and does not claim a signed physical-device build.
- Command: `flutter build ios --simulator --debug -v`, full stdout/stderr captured. Xcode selects `generic/platform=iOS Simulator`.
- Dependency resolution completed and Xcode entered native compilation. Repeated process checks showed changing `clang -cc1` processes using roughly 80–90% CPU each, compiling Firestore C++ sources such as `view_snapshot.cc`, `firestore_client.cc` and `field_filter.cc`. A quiet Flutter log during this period is buffered Xcode output, not evidence of a hung process or dependency-resolution stall.
- **Final iOS status: PASS, exit 0.** The full log contains `** BUILD SUCCEEDED **`, `Xcode build done. 577.6s`, `Built build/ios/iphonesimulator/Runner.app` and `exiting with code 0`. Total Flutter command time was **593,722 ms** (about 9 minutes 54 seconds). This was a long successful native compilation, not a hung Xcode process.
- The generated Dart kernel was rebuilt after the final source changes. No signed physical-device build or simulator runtime interaction is claimed.
- Full output: `validation/phase6_3/ios-build.log`; environment diagnostics: `validation/phase6_3/flutter-doctor.log`; process evidence: `validation/phase6_3/ios-processes.log` and `ios-progress.log`.

## Limitations

- Tests simulate Firebase auth/session events and cloud responses; no live login, token revocation or physical BLE device exchange was performed. Normal ID-token refresh may keep `currentUser` present; cloud authorization failures keep operations pending rather than deleting data. Signed-out/account-change events enforce the local scope boundary.
- A cloud write accepted while A was authorized may finish after logout; the client cannot retract an already dispatched request. It never converts that request into B's ownership or drains A's queue as B.
- Device history exposes Guest records for inspection and the incident's stored location. It does not resume Guest BLE/chat/live location sharing while signed into another account; those remain tied to the original owner.
- Existing active location sharing is stopped when disposing its coordinator. Existing `stop()` behavior expires that session's active live-location outbox so stale coordinates are not resumed. SOS delivery message identity and unrelated inbox/outbox records are preserved.
- Cloud history download/recovery on a fresh installation remains outside the existing implementation. No automatic Guest import or account merge was added.
