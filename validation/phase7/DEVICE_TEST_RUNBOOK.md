# Physical verification procedure — Phase 7

Use only synthetic SOS/chat content. Do not include precise personal locations in screenshots or exported logs. A USB connection and a successful build do not count as BLE delivery.

Devices currently available: Samsung Galaxy A53 / SM-A536E, Android 14; iPhone 15 Plus, iOS 27.0.1. A second Android is not available. No emulator counts as a BLE endpoint.

## Establish the transport

1. Open SOS on both devices. Keep both apps in foreground and screens unlocked.
2. Settings → BLE Test (Debug). Grant the requested nearby Bluetooth permission.
3. On receiver, tap Start Advertising. On sender, tap Start Scan, select only the intended test peer and Connect.
4. Record role, GATT service discovery and notification readiness. The two platforms must use the same service/RX/TX UUIDs. Record peer aliases A/B rather than hardware identifiers in exported evidence.
5. A debug Send message only verifies transport framing. It does NOT prove SOS/Chat application persistence or ACK.

## SOS and application ACK

1. Return to Home on sender and create a synthetic SOS using an explicit receiver. Avoid real GPS coordinates in test data and logs.
2. Record the new SOS ID privately. On receiver, verify exactly one inbox/SOS row, then a positive application ACK. Verify the sender's durable outbox reaches `acknowledged`, not merely `writeAccepted`.
3. Reverse the roles and repeat iPhone → Android.
4. Record exact direction and observed state; leave NOT RUN unless actually performed.

## Chat / location / failure cases

- Chat: send a synthetic text in each direction; verify receiver persistence and matching `chat.ack`, then restart and confirm persistence.
- Location: use synthetic/mock location only; verify initial update, newer update, source/recipient matching, expiry and Stop Sharing. Verify stop affects location queue only.
- ACK loss: suppress a positive ACK using a controlled test harness; resend the same message ID and payload. Receiver row count remains 1 and a fresh positive ACK is emitted.
- Disconnect: disconnect during pending delivery, reconnect the same intended peer and verify bounded retry with unchanged message ID/destination.
- Wrong peer/sender: use a controlled harness to inject mismatched identities. A fake frame or manual debug Send is not a hardware security proof.
- Restart: terminate with a pending synthetic outbox, reopen, confirm original row and stable message ID, then deliver/ACK.
- Failure UI: deny Bluetooth permission, turn Bluetooth off, and make GPS unavailable in separate cases; local persistence must survive and UI must not claim delivery.

## Known deterministic blockers before physical acceptance

The two-endpoint automated release tests currently reproduce Chat sender-ID versus transport-peer mismatch and Location recipient-route versus owner-ID mismatch. Do not disable identity checks or mark physical cases as PASS based on existing single-endpoint fake tests. See the Phase 7 verification report and full test log.

## Native session lifecycle regression gate

Before accepting a lifecycle fix, start BLE, perform Guest → Login → Logout and A → B transitions, then start scanning/advertising without terminating the app. Verify the old transport is fully stopped, no old peer/callback is delivered to the new account, the new session emits events, and its native discovery method is actually invoked. Current iPhone evidence shows `dispose` followed by rejected `requestPermissions` with no native scan. A fresh-process retry is diagnostic only and does not close this gate. Android native event suppression also needs validation after a session change. No native automated regression test has yet closed this blocker.

## Resume after device access is restored

Device access was temporarily unavailable and is now restored. Do not recreate SOS or resend `phase7-chat-01` initially. First reconnect both devices, identify the same incident on both screens, record whether the existing message bubble is Queued/Failed or absent, and capture sender/receiver diagnostics. Distinguish no destination, disconnected route, native send failure and receiver identity rejection. Only then choose the next controlled action. Existing physical SOS evidence is retained; remaining matrix entries are not assumed to pass.

## Latest verified state

Both devices run the reply-route/source-binding fix. Android → iPhone new-SOS/application ACK retest passed. The new iPhone → Android phase7-chat-02 reply reaches Android and retries with the same ID, but is rejected for sender/native-peer identity mismatch. Chat end-to-end fails; the old phase7-chat-01 remains Queued without automatic peer assignment. Full tests: 169 pass / 2 identity release-gate failures; analyzer, Android debug, iOS profile and unsigned iOS debug builds exit 0. Resolve and regress logical-device/transport identity binding before claiming Chat/Location readiness; remaining unexecuted physical cases retain NOT RUN.
