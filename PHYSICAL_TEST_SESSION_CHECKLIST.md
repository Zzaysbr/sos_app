# Physical Test Session Checklist

## Phase 10 release-candidate precondition

Before installing a release candidate, record the owner's permanent identifier
decision. The current update-in-place identities are Android
`com.example.sos_app` and iOS `com.n1cxltine.sosapp`; their Firebase platform
registrations must match. Do not install a build with a changed identifier over
the evidence devices: it creates a separate app container and invalidates the
local Guest/history continuity setup.

The session build must also record its version/build number, source revision,
Android signing-certificate SHA-256 or iOS signing identity/profile, artifact
SHA-256, and production map configuration status without logging credentials.
An unsigned or debug-signed artifact may be used for explicitly labelled debug
physical diagnostics, but it is not signed-release evidence.

Use this checklist for one controlled Phase 8/9 acceptance session. Never mark
a row PASS from automated tests or historical evidence. Do not uninstall the
app, clear storage, reset pairing, log credentials/coordinates or expose native
device identifiers in committed evidence.

## 1. Required equipment and accounts

- Mac with Flutter 3.47.6, Xcode 26.6, Android SDK/ADB and enough disk space for
  three separate redacted log streams.
- Android A and Android B, each unlocked with Developer options and USB
  debugging enabled; record model, OS/API, battery and Bluetooth chipset if
  available.
- iPhone, currently expected as iPhone 15 Plus/iOS 27.0.1, unlocked, paired,
  trusted and in Developer Mode.
- Data-capable cables for every phone, chargers/power banks, tape/range markers,
  and an open plus an obstructed site that safely supports 50 metres.
- Controlled Guest state and test accounts A/B. Do not use personal SOS text,
  personal coordinates or production credentials.
- For wrong-peer testing, all three phones or a distinct native injector. For
  ACK suppression, an approved debug-only one-shot harness matching the design
  gate in `PHASE_8_PHYSICAL_TEST_RUNBOOK.md`.

Expected version is `0.1.0+1`. Current bundle IDs are Android
`com.example.sos_app` and iOS `com.n1cxltine.sosapp`. Before installation record
the exact Git revision, dirty-state summary, build mode and SHA-256 of each
artifact. Stop if identifiers/signatures differ from the already installed app;
do not solve an update failure by uninstalling.

## 2. Host connectivity gate

Run and retain redacted outputs plus exit codes:

```sh
flutter doctor -v
flutter devices --device-timeout 10
adb devices -l
xcrun devicectl list devices
xcrun xcdevice list
xcodebuild -showdestinations -workspace ios/Runner.xcworkspace -scheme Runner
```

PASS requires both Android serials in ADB state `device`, not `offline` or
`unauthorized`, and the intended iPhone available/paired with Developer Mode.
An unavailable record for another iPhone does not fail the active iPhone. If a
phone is absent, check unlock state, data mode, cable/port and the existing
trust/debugging prompt. Do not reset pairing or device settings without a
separately documented reason.

## 3. Build and update-in-place installation

Build current debug artifacts, then preserve data with update installation:

```sh
flutter build apk --debug --no-pub
adb -s ANDROID_A install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s ANDROID_B install -r build/app/outputs/flutter-apk/app-debug.apk
flutter build ios --debug
xcrun devicectl device install app --device IOS_DEVICE build/ios/iphoneos/Runner.app
```

Use shell variables or local aliases for device identifiers and redact them
from evidence. A signing mismatch is FAIL/BLOCKED; never uninstall or clear data.
Open each app, record version/build, confirm prior Guest/local history still
opens and take a count only—do not export message contents or coordinates.

## 4. Evidence format

For every case record case ID, start/end timestamp with timezone, source SHA,
artifact SHA-256, device aliases/model/OS, sender→receiver direction, foreground
and screen-lock state, permissions, distance/environment, message ID in a
private log, and redacted evidence filenames. Capture sender and receiver logs
separately. A valid trace correlates enqueue → send attempt → native write
accepted or failed → receiver persisted/duplicate → ACK sent → sender
acknowledged. Native write success alone is never delivery.

Store only redacted summaries under `validation/`; keep raw logs outside source
control. Coordinates, account credentials, API keys, tokens, serials, UDIDs and
installation IDs must not enter committed evidence.

## 5. Ordered execution

1. **Android ↔ iPhone baseline:** run Android→iPhone and iPhone→Android
   separately. In each direction establish discovery and GATT readiness, send
   one unique SOS and one incident Chat, and verify a valid application ACK and
   exactly one receiver row. Send an initial and subsequent shared-location
   update using synthetic/non-personal coordinates, verify the matched-peer map
   presentation, then Stop Sharing and prove no later update is delivered.
   Confirm Guest/local history before and after the case.
2. **P8-P03 close while pending:** make receiver unavailable, enqueue one Chat,
   confirm pending, terminate sender without clearing data, reopen, reconnect
   the same logical peer and require the same message ID, one receiver row and
   final valid ACK.
3. **P8-P04 restart/reconnect:** disconnect after native send begins and before
   ACK, terminate/restart sender, reconnect and prove bounded same-ID retry,
   stale-callback isolation and one receiver record.
4. **Duplicate/reconnect:** replay the same message through disconnect/reconnect;
   receiver must retain one row, re-ACK the duplicate and preserve ownership and
   incident identity.
5. **P8-P01 controlled ACK loss:** only with the approved one-shot harness.
   Suppress the first positive ACK after persistence, allow retry and the second
   ACK, then prove native success did not count as delivery. Disarm immediately.
6. **P8-P02 wrong-peer ACK:** while intended ACK is held, use the distinct third
   peer to send the matching synthetic ACK. Sender must remain pending until the
   selected peer ACKs. Remove the injector afterward.
7. **P8-P05 Android A↔Android B:** run SOS, Chat, ACK and reconnect in both
   directions with exactly one persisted receiver row per logical message.
8. **P8-P06 iOS permission:** establish a baseline session, revoke Bluetooth in
   Settings, verify scan/advertise fails without false Connected/Delivered and
   history remains. Regrant, record whether process restart is required, then
   reconnect and complete one diagnostic application ACK.
9. **Location permission:** establish a foreground shared-location baseline,
   revoke location permission on the sending device, verify a clear unavailable
   state and no fabricated/old update, and prove SOS/Chat/local history remain
   usable. Regrant When In Use permission, refresh, deliver one new update with
   a valid application ACK, Stop Sharing, and restore the original state.
10. **Firebase expiry and cloud recovery:** while using controlled account A,
    force a token/session invalidation or disable the test user through the
    controlled Firebase project. Confirm account A routes close, its cached
    history is not exposed to Guest or account B, local rows/queues remain, and
    no Guest row uploads. Re-enable/sign in as appropriate, create one synthetic
    authenticated SOS while network writes are denied/offline, then restore the
    service and verify exactly one cloud document and an empty matching queue.
    Record only redacted document/count evidence; delete synthetic cloud data
    through the authorized account after evidence is captured.
11. **Guest/account isolation:** create a Guest SOS offline, restart, sign in to
    A, sign out, sign in to B, and perform one failed/cancelled login. At every
    transition verify Guest data is available only through device history,
    account caches never cross scopes, ownership/timestamps do not change, and
    Guest sync-queue rows are never sent to Firestore.
12. **P8-P07/P8-P08 range:** run three independent 30-second diagnostics at 5,
   10, 20, 30 and 50 metres for open and obstructed conditions. Record phone
   height/orientation and obstruction class. Start a new run after reconnect.
   Verify `attempted = acknowledged + nativeFailed + timedOut + pending`.
   Report scan-time RSSI only as signal evidence, never as distance or a range
   guarantee.
13. **Post-session regression:** reopen original histories, confirm account A/B
    isolation and Guest retention, stop sharing/scan/advertising and verify no
    unexpected synthetic row remains pending.

## 6. PASS / FAIL / NOT RUN

- **PASS:** every stated criterion is observed on required physical devices and
  has correlated redacted evidence.
- **FAIL:** the case was executed and any criterion failed, including false
  delivery, changed identity/owner, duplicate row, unbounded retry or data loss.
- **NOT RUN:** prerequisites or evidence are absent. Record the exact blocker;
  partial execution is not PASS.

Range failure at a distance is a valid measured FAIL and must not be hidden.
Do not infer a maximum range from RSSI or fewer than the required runs.

## 7. Cleanup and recovery

Disarm the ACK harness, remove the injector, stop scan/advertising/location
sharing, reconnect normal intended peers, restore Bluetooth/location/Nearby
permissions, restore network state and leave iOS Bluetooth granted. Reopen Guest
and account histories and record final counts. If recovery fails, preserve logs,
stop the session and avoid uninstall/reset/clear-data actions. Record every
remaining pending message and its retry state for the next session.

