# Quest Board

| ID | Quest | Phase | Status |
|---|---|---:|---|
| Q-701 | Chat sender and transport identity binding | 7 | VERIFY / FIX AS NEEDED |
| Q-702 | Location Sharing recipient identity and ACK | 7 | VERIFY / FIX AS NEEDED |
| Q-703 | Native BLE lifecycle and stale callbacks | 7 | VERIFY / FIX AS NEEDED |
| Q-704 | SOS delivery state consistency | 7 | VERIFY / FIX AS NEEDED |
| Q-801 | Password recovery security boundary | 8 | HARDENED; backend blocked |
| Q-802 | Trusted backend and genuine MFA recovery | 2/8 | BLOCKED |
| Q-803 | Accessibility and UX hardening | 8 | IN PROGRESS |
| Q-804 | Automated regression coverage | 8 | IN PROGRESS |
| Q-805 | Map provider release readiness | 5/9 | BLOCKED UNTIL VERIFIED |
| Q-806 | Guest/authenticated data isolation | 6/8 | VERIFY |
| Q-901 | MVP release acceptance | 9 | BLOCKED |

Quest completion requires evidence appropriate to the quest. Passing mocked
tests does not certify physical BLE behavior or production backend security.

## Reconciled evidence — 3 November 2026

- Q-701: IMPLEMENTED WITH TEST COVERAGE; keep open for physical/negative-path
  acceptance of logical sender versus BLE peer.
- Q-702: IMPLEMENTED WITH TEST COVERAGE; keep open for physical recipient and
  ACK evidence.
- Q-703: IMPLEMENTED WITH TEST COVERAGE; keep open for device lifecycle matrix.
- Q-704: IMPLEMENTED WITH TEST COVERAGE; keep open for receiver-evidence audit.
- Q-801: HARDENED. Direct email-reset bypass removed; production backend remains
  blocked. Safe to close only as a client-boundary task, not as genuine MFA.
- Q-802: BLOCKED. No trusted HTTPS backend, MFA provider deployment or server
  atomic transaction exists in the repository.
- Q-805: BLOCKED. Provider account/plan, attribution and complete physical map
  acceptance remain unverified.
- Q-901: BLOCKED by RG-02–RG-12 evidence and signing/provider prerequisites.

Physical acceptance matrix prepared in `PHYSICAL_BLE_ACCEPTANCE.md` on
3 November 2026. Device discovery succeeded, but Q-701–Q-704 execution was
not run in this pass; no physical acceptance status changed.

The execution preflight confirmed Android Bluetooth permissions and usable
CoreDevice/DDI readiness for the iPhone/iPad. It did not prove BLE discovery or
transport connectivity, so all four quests remain acceptance-incomplete.

Q-703 physical attempt now has a reported reconnect mismatch: alternating
disconnect/connect can show connected on one device while the peer still shows
disconnected. Classified `REGRESSION / NEEDS REPRODUCTION WITH LOGS`; no Quest
completion credit is awarded.

Q-703 contract remediation is now implemented and covered by deterministic Dart
tests; native iOS session invalidation is also implemented. Physical Bluetooth
Off→On recovery remains unverified, so the Quest stays acceptance-incomplete.

Physical retest now confirms discovery, connect/disconnect, three reconnect
cycles and adapter Off→On invalidation. A peer UI convergence mismatch remains
when transport delivery succeeds, so Q-703 is `PARTIAL / ACCEPTANCE-INCOMPLETE`.

Follow-up confirmed fresh explicit reconnect succeeds after Bluetooth recovery;
the UI convergence mismatch remains the only reported Q-703 physical defect.

The operator now reports Q-703B passing on updated Android+iPhone builds,
including reconnect, navigation restoration, and Bluetooth Off→On explicit
reconnect. Mark as `DEVICE-VERIFIED (operator-reported)`; retain the broader
release gate and unrelated physical quests as incomplete.

Q-703B read-only tracing confirmed a source-level diagnostic UI hazard: peer
state is keyed without central/peripheral role although native transport and the
coordinator track roles separately. Existing Android logs show role-distinct
events. Paired runtime convergence remains unproven; keep Q-703
`acceptance-incomplete`.

Q-703B UI remediation is implemented in the diagnostic screen with role-aware
peer state and snapshot restoration. Automated widget coverage passes; physical
Samsung+iPhone convergence after this patch is still pending, so the Quest
remains `acceptance-incomplete`.

Q-805 implementation update: map provider validation now rejects malformed
Geoapify API-key formats without exposing the value. Map focused tests and
production-config validation pass. Q-805 remains `BLOCKED UNTIL VERIFIED`
pending owner account/terms/quota confirmation and physical map acceptance.

Q-805A verification: local production configuration is ignored/untracked and
injects `GEOAPIFY_API_KEY` only through `--dart-define-from-file`. Account
ownership, active plan/quota, live key validity and provider terms acceptance
are `NOT VERIFIED`; these provider checks remain separate from the completed
operator-reported physical map acceptance below.

Q-805B physical map acceptance is now `PASS — DEVICE VERIFIED` by operator report
for Android and iPhone. The iPhone retest confirmed fresh tiles in a previously
unseen area after network restoration, with the existing map, attribution and
stability preserved. Provider account/terms and release signing blockers remain.

Q-805B executable operator cases (including separate network, fresh-reload,
attribution-link, GPS-permission and large-text checks) are defined in
`PHYSICAL_MAP_ACCEPTANCE.md`. They require evidence per case; documentation did
not upgrade any historical result.

Q-901A Android release signing preparation/recheck: Gradle signing configuration
was verified as fail-closed, but no owner-controlled keystore or
`key.properties` exists locally. `assembleRelease` exited 1 at the signing guard;
no debug-signed artifact is accepted as release evidence. Status remains
`BLOCKED` pending owner credentials.

Q-902A iOS distribution signing audit: project identity is consistent across
Debug/Profile/Release, but a matching Apple Distribution identity and
provisioning profile are unavailable locally. Status remains `BLOCKED`; no
archive/export evidence is claimed.

Q-902A read-only recheck confirmed the available certificate's actual public
certificate OU is `78GZXS97G6` (not inferred from its display name), but it is
Apple Development only. The local profile is development-only, expires 10
November 2026, and does not include the tested iPhone/iPad UDIDs. No Apple
Distribution identity/profile or export configuration is available; status
remains `BLOCKED_SIGNING`.

Q-903A release configuration hardening is implemented: Android remains
fail-closed and Runner Release explicitly requests Apple Distribution. Signing
and MVP release acceptance remain blocked until owner-controlled artifacts are
verified.

Phase 9 scope adjustment: the current milestone is **Demo Gate**, using Android
Debug and iOS Development/Personal-Team builds for direct physical-device
demonstration. Q-901A Release signing and Q-902A Distribution signing are
deferred Store Distribution prerequisites, not Demo Gate blockers. Android
Debug installation/launch is verified; iPhone installation, Home Screen launch
and existing-data preservation are now verified. The same Profile artifact was
then installed on iPad Air 11-inch (M2), with Home Screen launch and existing
data preservation confirmed. Android, iPhone and iPad demo installation checks
are complete.

## Phase 7 Next Quest execution evidence — 3 November 2026

- Focused Q-701–Q-704 suites: 76 tests passed. Review covered sender/peer
  binding, recipient and ACK correlation, lifecycle/session replacement, and
  SOS delivery persistence. No reproducible regression was found, so no
  production code change was justified in this pass.
- Full suite: 434 tests passed; `flutter analyze lib test` passed;
  `git diff --check` passed.
- Q-701–Q-704 remain open only for physical-device/negative-path evidence;
  automated coverage does not certify BLE reliability.

Q-806 isolation verification: focused Guest persistence, account switching,
ownership and sync tests pass, including restart continuity, logout invalidation,
guest non-upload and in-flight account-change fencing. No reproducible local
ownership defect was found. Firebase live-rule verification remains NOT RUN;
keep Q-806 open for that external evidence.

Q-803 accessibility/critical UX: the primary hold-to-send SOS control now
exposes an explicit screen-reader hint and enabled state while preserving the
hold gesture. Focused UX/layout tests pass; VoiceOver/TalkBack physical
acceptance remains NOT RUN.

Q-804 regression matrix completed against the current tree. The full suite is
automated-verified; no reproducible regression was found and no additional
production fix was justified. External/live and physical limitations remain
open as listed in `RELEASE_READINESS.md`.

Q-803 physical acceptance guide is documented in
`Q803_PHYSICAL_ACCESSIBILITY.md`. Samsung and iPhone were discoverable, but
TalkBack/VoiceOver was not enabled by the operator in this pass; physical
accessibility remains `NOT RUN` and Q-803 stays acceptance-incomplete.

Q-806 external acceptance guide is now available at
`Q806_EXTERNAL_ACCEPTANCE.md`. Checked-in Firestore Rules were verified against
the available local emulator (8 tests passed); live deployed Rules and physical
account switching remain unverified, so Q-806 is acceptance-incomplete.

Firebase CLI access to project metadata and Rules dry-run compilation is
available, but no authorized Account A/B credentials were supplied; no live
records were touched and live authorization remains `BLOCKED`.

Q-707 Stage A direct BLE acceptance is now **PHYSICAL PASS (operator-reported)**:
Samsung and iPhone discovered each other, connected, disconnected and
reconnected with matching Connected/Disconnected states. No SOS or Chat payload
was sent. Stages B–E remain pending and no relay delivery is inferred.

Q-707C investigation — 3 November 2026: **ROUTING DIVERGENCE CONFIRMED**.
The current one-tap SOS path calls `enqueuePublicRelay` (Relay v2 hop-only)
after local persistence and does not call the Direct SOS v1 `enqueueSos` path.
Relay-only persistence is intentionally excluded from normal SOS History, so a
helper device will not see a received incident from that path. Guest mode is
not proven to be the cause. Authenticated Account A/B physical validation is
`WAITING_FOR_TEST_ACCOUNTS`; no source or protocol change was made.

Q-707D guest multi-hop Stage A/B: **PARTIAL**. Samsung persisted one local
SOS and reported `stored on 1 relay device`; iPhone Diagnostics showed incoming
hop 1 and `stored on relay`. The iPad Stage B run showed incoming hop 0, no
relay job/receipt and no Rescue incident. The first unverified boundary is
iPhone→iPad forwarding/session delivery.

Q-707D latest operator correction — 3 November 2026: iPad Diagnostics later
showed incoming hop 1 and `stored on relay` with Relay On. This confirms B→C
relay persistence for that run. Receipt state was not recorded locally and
Rescue History remained 0, which is expected for relay-only envelopes.

Q-708A architecture assessment: **DESIGN REQUIRED / IMPLEMENTATION BLOCKED**.
Turning C into an actionable Rescue endpoint requires an additive protocol
version, explicit voluntary-rescue consent/recipient semantics and a dedicated
owner-scoped Rescue Inbox. Existing Relay v2 must remain hop-only; no source or
schema change has been implemented pending approval.

Q-708A implementation update: the approved first slice is now implemented and
automated-verified. Physical A→B→C Rescue Inbox acceptance remains NOT RUN.
