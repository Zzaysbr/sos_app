# Q-806 External Acceptance Guide

This guide verifies Guest/local history, Account A/B isolation and session
changes without using real user data. Use only owner-authorized test accounts
and clearly synthetic SOS text such as `Q806-A-<date>`.

Never record passwords, OTPs, access tokens, email addresses, personal
coordinates or full screenshots containing account data. Redact identifiers in
evidence.

## Result vocabulary

- `PASS`: every expected observation and required evidence is present.
- `FAIL`: a reproducible isolation or ownership violation occurs.
- `PARTIAL`: local behavior passes but a required live Firebase/physical
  observation is unavailable or indistinguishable.
- `NOT RUN`: a prerequisite or step was not performed.
- `BLOCKED`: the required owner credential, deployed environment or device is
  unavailable.

## Q806-G-01 — Guest persistence and restart

**Preconditions:** fresh test device or a clearly identified Guest test scope;
internet may be off; app data must not be cleared during the case.

1. Open the app and choose Guest/local mode.
2. From Home, hold the primary SOS action until the SOS is created.
3. Open History and record that the synthetic incident is visible locally.
4. Force-close the app using the OS app switcher; do not uninstall it.
5. Reopen from the Home Screen icon and open History.

**Expected:** the same Guest incident remains visible with the same local
identity and no cloud-sync claim. **Evidence:** redacted History screenshot and
device/build identifier. PASS requires both pre- and post-restart observations;
FAIL if the record disappears or changes owner; NOT RUN if Guest mode was not
available.

## Q806-G-02 — Guest survives login/logout without migration

**Preconditions:** Q806-G-01 passed; authorized synthetic Account A credentials
are available to the operator without sharing them with the reviewer.

1. Start in Guest Home/History and note the synthetic Guest incident count.
2. Open Settings → Account and sign in to Account A.
3. Return to Home/History and inspect the authenticated list.
4. Use the existing local/device-history entry, if shown, and confirm the
   Guest incident remains there.
5. Sign out through Settings → Account → Sign out.
6. Reopen History in Guest mode.

**Expected:** the Guest record is not merged into Account A, is not marked as
cloud-synced, and remains available after logout. PASS requires all three
scopes; PARTIAL if local evidence passes but cloud upload cannot be observed.

## Q806-A-01 — Account A/B separation

**Preconditions:** two owner-authorized synthetic accounts A and B; use unique
labels `Q806-A-<date>` and `Q806-B-<date>`; never use production data.

1. Sign in as Account A and create one synthetic SOS.
2. Open History and confirm the A-labelled record is visible.
3. Sign out completely.
4. Sign in as Account B and open History.
5. Confirm the A-labelled record is absent.
6. Create the B-labelled SOS and confirm it is visible to B.
7. Sign out, sign back in as A, and open History.
8. Confirm A's record is visible and B's record is absent.

**Expected:** each account sees only its own authenticated records. PASS needs
the A→B and B→A negative observations; FAIL if either private record leaks.
Do not infer Firebase authorization from UI filtering alone.

## Q806-S-01 — Logout/session expiry clears retained state

**Preconditions:** Account A has a visible synthetic record and the app is open
on a screen showing account-scoped history or a retained stream.

1. Leave the account-scoped screen open.
2. Sign out through the app's Account screen (or use the authorized test
   session-expiry control).
3. Observe the current screen without restarting the app.
4. Navigate to History and then sign in as Account B.

**Expected:** A's retained rows, dialogs and subscriptions clear immediately;
no A record appears in B's state. Capture only redacted visible state. FAIL if
stale A data remains after the session transition.

## Q806-R-01 — Pending sync/account-switch race

**Preconditions:** authorized test environment can pause or make sync retryable
(for example, controlled offline network); never interrupt a production write.

1. Sign in as Account A and create a synthetic record while sync is pending.
2. Before retry completes, sign out or switch to Account B.
3. Restore connectivity and allow the normal retry path to run.
4. Inspect A and B histories after each session is re-established.

**Expected:** the pending operation retains owner A or is safely cancelled; it
is never written under B, and retries do not duplicate the record. PASS requires
sanitized sync logs or emulator evidence showing the original owner. PARTIAL if
only local fencing can be observed.

## Q806-F-01 — Firebase Rules emulator verification

The repository includes `security-tests/firestore.rules` and
`security-tests/firestore.rules.test.js`.

1. Ensure Java and Firebase CLI are installed.
2. Confirm no unrelated process owns the configured emulator port 8080.
3. Run:
   `firebase emulators:exec --config security-tests/firebase.json --project demo-off-grid-sos 'npm --prefix security-tests test'`
4. Record the sanitized test count and exit code.

**Expected:** unauthenticated access and cross-owner reads/writes fail; owner
operations succeed. This verifies the checked-in rules against the emulator,
not deployed production rules. If port 8080 is occupied, stop and report the
owner/process rather than killing an unrelated service.

## Evidence record

```text
Test ID:
Device / OS / app build:
Account scope (Guest/A/B, redacted):
Preconditions:
Steps completed:
Expected result:
Observed result:
Evidence path (redacted):
Result (PASS/FAIL/PARTIAL/NOT RUN/BLOCKED):
```

Current repository evidence is separate from this operator guide:

- Local automated isolation tests: VERIFIED.
- Firebase emulator rules suite: VERIFIED (8 tests passed in the available
  emulator; production deployment is not implied).
- Firebase CLI project access: VERIFIED for project `sos-app-d811a` (read-only
  project/database metadata and local Rules dry-run compilation succeeded).
- Live deployed Rules/production sync: BLOCKED — no designated Account A/B test
  credentials were provided, and no live records were read or written. A dry
  run compiles the local rules; it does not prove those rules are deployed.
- Physical account-switch acceptance: NOT RUN.
