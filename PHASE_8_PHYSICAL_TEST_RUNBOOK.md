# Phase 8 — Physical Reliability and BLE Range Runbook

Date prepared: 22 October 2026 (Asia/Bangkok)

This runbook records only new Phase 8 executions. Phase 7 PASS rows remain
historical evidence and are not copied forward as new physical results. Use
synthetic text, controlled Guest/test accounts and no personal coordinates.
Never export credentials, Firebase tokens, native peer identifiers, installation
IDs or exact locations.

## Common setup and evidence

Use update-in-place installation only. Do not uninstall, clear app data or
change account ownership. Give each phone a non-identifying alias such as
Android A, Android B and iPhone. Record model, OS, app source revision, build
mode, direction, start/end time and whether the screen stayed foreground and
unlocked.

The BLE diagnostic requires a signed **debug** build on physical iOS. Profile
and release builds intentionally hide the route. Before each case:

1. Preserve separate sender and receiver logs. Clear only the OS log buffer,
   never application storage.
2. Open the app and confirm the expected Guest/test-account scope.
3. Open **Settings → BLE Test (Debug)**. Receiver advertises; sender scans,
   selects the intended peer and reaches `connected / GATT ready`.
4. Record discovery, GATT service/RX/TX discovery and notification readiness.
5. Redact identifiers when producing a summary under `validation/phase8/`.

Useful capture methods are `adb logcat -v threadtime` for Android and Xcode
Devices and Simulators → Open Console or `flutter logs -d <device>` for iOS.
Raw logs remain outside source control. A valid delivery trace correlates the
same logical message through `enqueue`, `send`, `writeAccepted`, receiver
`persisted`, `ackSent` and sender `acknowledged`. `writeAccepted` alone is never
delivery evidence.

After every case stop scan/advertising, reconnect the normal intended peer,
restore permissions/Bluetooth, reopen the original Guest/device history and
verify no synthetic message is left unexpectedly pending.

## P8-P01 — Controlled production application-ACK loss

**Preconditions and roles:** sender S, intended receiver R and a controlled
debug/native harness that can suppress exactly one positive SOS or Chat ACK
*after* R commits the message. The current app has no production-ACK suppression
control. Turning Bluetooth off before persistence is a disconnect test and does
not satisfy this case.

**Execution:**

1. Establish and bind S↔R with a fresh synthetic SOS if needed.
2. Arm the harness for one known synthetic message only.
3. S sends once. R must persist exactly one row; the harness drops its first
   positive application ACK.
4. Keep/re-establish the same intended peer until the durable retry sends the
   same message ID and payload.
5. Allow the second ACK. Wait for S to reach Confirmed/Delivered.

**Expected:** native write may succeed while S remains awaiting/failed; R has
one record; retry count advances within the bounded policy; retry retains owner,
incident, destination and message ID; duplicate delivery is re-ACKed; S becomes
acknowledged only after the valid ACK.

**Evidence and PASS:** harness arm/drop/release event, same-ID sender attempts,
receiver first persistence plus duplicate detection, second `ackSent`, final
`acknowledged`, and receiver count 1. FAIL for a new ID/row, confirmation before
valid ACK, ownership/route change, unbounded retry or lost durable row. Cleanup
must disarm the harness before any other test.

**Current status:** NOT RUN — no controlled production-ACK suppression harness.

## P8-P02 — Wrong-peer ACK injection

**Preconditions and roles:** S, intended receiver R and third controlled peer W,
or an equivalent native injector. W must use the existing UUID/framing and a
known synthetic `ackFor`/incident only inside the lab. The ordinary debug text
sender is not an ACK injector.

**Execution:** hold or suppress R's valid ACK, then have W send a syntactically
valid persisted ACK for S's pending message. Inspect S before allowing R to ACK.
Finally reconnect/allow R and complete delivery.

**Expected:** W's frame may assemble but cannot acknowledge the outbox or alter
the stored destination/binding. S stays pending/retryable. R's valid ACK can
subsequently acknowledge the original row.

**Evidence and PASS:** W and R have distinct redacted aliases; log shows the
wrong-peer rejection and unchanged pending message ID; no peer-binding or owner
mutation; later R ACK matches the same row. FAIL if W confirms, reroutes or
causes a duplicate record. Remove W and restore the S↔R session during cleanup.

**Current status:** NOT RUN — third peer/injector unavailable.

## P8-P03 — Close sender while a message is pending

**Preconditions and roles:** use a new incident that already has a validated
S↔R identity/route. Record the sender Chat count and receiver count. Keep R
offline or Bluetooth off before creating one unique synthetic Chat, so no ACK is
possible.

**Execution:**

1. Send exactly once and confirm the bubble/outbox is Queued/Awaiting/Failed,
   never Delivered. Capture its message ID privately from diagnostics.
2. Terminate S from the app switcher or `adb shell am force-stop
   com.example.sos_app`. Record the method. Do not clear data.
3. Keep S closed for at least one normal poll interval. Confirm R has no new row.
4. Reopen S in the same account/Guest scope. Confirm the pending bubble still
   exists before enabling R.
5. Restore R, advertise/reconnect the same identity and wait for bounded retry.

**Expected/PASS:** pending data survives termination; no send occurs while the
process is stopped; restart uses the same message ID/destination; R receives one
row; a valid ACK changes S to Delivered. FAIL for missing pending data, changed
ID/owner, delivery while terminated, duplicate rows or false Delivered state.
Cleanup restores R and confirms no remaining pending synthetic row.

**Current status:** NOT RUN — the 22 October Phase 8.1 inventory found no
Android endpoint in ADB, so no sender/receiver trace could be collected.

## P8-P04 — Process restart and reconnect recovery

Repeat P8-P03 but disconnect after a native send/write begins and before an
application ACK is observed. Terminate S while the row is sending or awaiting.
On restart, establish GATT with the same logical installation even if its native
route rotates.

PASS requires stale work to recover to a retryable state, one current peer
binding, unchanged message ID/payload/owner, a bounded retry and one receiver
record followed by a valid ACK. Old-session callbacks after the new session
starts must not confirm or reroute the row. Record disconnect, process stop,
restart, binding, retry and ACK timestamps. Cleanup stops both BLE sessions and
opens the original histories again.

**Current status:** NOT RUN. Automated file-backed database/coordinator restart
coverage is separate and does not make this physical PASS.

## P8-P05 — Android A ↔ Android B

**Preconditions:** two physical Android phones with Bluetooth/Nearby permission,
the same current debug APK and preserved separate app data. Emulators do not
count.

For each direction perform discovery/GATT readiness, one SOS with application
ACK, one incident Chat with ACK, disconnect/reconnect retention and one 30-second
range diagnostic. Each sender must reach Confirmed/Delivered only after the
receiver has exactly one row. Record both models/OS versions and direction.

PASS requires both directions and all listed operations. A one-way success is a
partial FAIL, not a matrix PASS. Restore permissions and stop all BLE operations
afterward.

**Current status:** NOT RUN — ADB found no Android endpoint; Android B also
remains unavailable.

## P8-P06 — iOS Bluetooth permission revoke/regrant

**Preconditions:** current signed debug app installed without deleting data;
iPhone foreground and connected to the log host; a controlled Android peer is
available. Record an existing Guest/local-history item before changing
permission.

**Execution:**

1. With permission granted, establish one GATT-ready session and stop it.
2. In iOS Settings → Privacy & Security → Bluetooth (or the app's Bluetooth
   setting), revoke access for the app.
3. Return without reinstalling. Attempt scan and advertise once.
4. Verify a permission/unauthorized error and no false Connected, native write,
   ACK or Delivered state. Confirm local history still opens.
5. Regrant permission. Return/resume the app, use its Permissions action if
   offered, then scan, advertise, connect and complete one diagnostic ping/ACK.
6. If iOS requires process restart, record that recovery explicitly; do not
   describe it as in-session recovery.

PASS requires clear denied behavior, preserved local/owner data, successful
regrant initialization and a valid application ACK afterward. FAIL for crash,
stuck disposed session, false delivery, data loss or callbacks from the denied
session changing current state. Cleanup leaves permission granted.

**Current status:** NOT RUN — iPhone 15 Plus is paired, Developer Mode enabled,
connected through a CoreDevice tunnel and available as a Runner destination.
The `-27` report belongs to a separate unavailable iPhone 13 device record.
Android is absent, so denial/regrant plus post-regrant peer ACK cannot be
executed to the stated PASS criteria.

## P8-P07 — BLE range and quality matrix

**Preconditions:** two current debug builds, foreground/unlocked, battery level
recorded, no personal location, a measuring tape/site markers and stable phone
height/orientation. Sender scans immediately before connection so the UI may
show a real scan-time RSSI. Unsupported RSSI remains `unavailable`.

Run 30 seconds at 5, 10, 20, 30 and 50 metres, where safe, for both open and
obstructed conditions. Perform at least three independent runs for every
distance/condition pair. For obstruction record only a category such as wall,
vehicle, floor or vegetation. Start a new run after any reconnect; never merge
two environments into one result.

For every run record target alias, duration, attempted, application ACK,
native-failed, timed-out, pending, PDR, latency min/average/p50/p95/max,
scan-time RSSI or unavailable, disconnect/reconnect and final connection state.
After the timeout drain completes, this accounting invariant must hold:

`attempted = acknowledged + nativeFailed + timedOut + pending`

PASS for a point requires three completed runs with consistent accounting and
at least one valid selected-peer application ACK per run. FAIL if connection or
ACK cannot be obtained, statistics violate the invariant, wrong/duplicate ACK
increments acknowledged, or native write alone raises PDR. A FAIL is still a
valid measured result. No product PDR threshold is approved, so results must not
be converted into a guaranteed maximum range. Reverse direction should be
reported separately when executed.

Cleanup returns both devices together, stops scan/advertising and records that
normal GATT readiness can be re-established.

**Current status:** NOT RUN — only one usable physical endpoint is visible to
the host and no measured field run was performed.

## Fault-injection implementation gate

The coordinator currently persists an inbound SOS/Chat before calling its
private acknowledgement sender. That sender encodes the production ACK and
writes it directly through `BleTransportClient`. Unit tests can inject
`FakeBleTransport` and already cover lost/delayed/wrong-peer/duplicate ACKs,
but there is no safe physical control after persistence. The BLE debug text
sender cannot produce a trusted wrong-peer source because native transport
identity is assigned by the actual connection.

No harness is added in Phase 8.1. Adding an unexercised switch to the production
coordinator while the required endpoints are absent would create an avoidable
path that can suppress a real ACK. The minimal future lab design is:

1. Add a one-shot acknowledgement fault policy at the post-persistence,
   pre-encode boundary. It must require an exact message ID, message kind,
   intended peer and short expiry; wildcard suppression is rejected.
2. Construct the policy only from the existing debug-only route. The normal
   app factory always supplies an immutable pass-through policy, and release
   UI has no arming API.
3. Auto-disarm after one matched positive ACK and emit redacted `armed`,
   `suppressed`, `expired` and `disarmed` evidence. Never suppress rejected
   ACKs, change persistence, mutate identity or change framing/UUIDs.
4. Test the release/default factory explicitly to prove suppression cannot be
   enabled, then run P8-P01 on two controlled phones.
5. Implement P8-P02 as a separate third-device/native lab injector. Do not add
   sender spoofing to the production app; the injector must use a distinct
   physical connection so the selected-peer check is exercised.

