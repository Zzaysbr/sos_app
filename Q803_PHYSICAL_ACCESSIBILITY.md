# Q-803 Physical Accessibility Acceptance

This runbook records physical accessibility evidence separately from automated
semantics/layout tests. Do not trigger a real SOS or send BLE/Location data.
Use an existing local test incident and redact all personal data.

## Current device availability

| Device | OS | Connection | Q-803 physical status |
|---|---|---|---|
| Samsung SM-A536E | Android 14 | ADB USB (`RFCT80GPFVY`) | NOT RUN — TalkBack not operator-enabled |
| iPhone 15 Plus | iOS 27.0.1 | CoreDevice paired/available | NOT RUN — VoiceOver not operator-enabled |

Device discovery is not accessibility evidence. The operator must enable the
screen reader on the device and report the observed announcements.

## Result definitions

- `PASS`: every required announcement, focus movement and control action works.
- `FAIL`: a reproducible missing, misleading or unusable accessibility behavior.
- `PARTIAL`: some checks pass but a required screen/setting/evidence item is
  unavailable or ambiguous.
- `NOT RUN`: screen reader or required device state was not enabled.

## Android TalkBack cases

### Q803-A-01 — Home and primary SOS semantics

**Preconditions:** Samsung app is installed and open; TalkBack is enabled;
Bluetooth/network remain in a safe non-transmitting state.

1. From Home, swipe through controls until the primary SOS action is focused.
2. Confirm TalkBack announces that it is a button, says the localized SOS label,
   and instructs the user to hold.
3. Confirm the enabled state is announced. Do not activate it.

**Expected:** focus reaches the control once, with no duplicate decorative
announcements. PASS requires all three announcements; FAIL if the control is
unnamed, misleading or cannot be focused.

### Q803-A-02 — History, Chat and Details

1. Navigate to History with TalkBack.
2. Focus an existing test record and activate it.
3. Confirm Chat opens for that incident and the separate Details action is
   discoverable.
4. Navigate back and confirm focus returns to a meaningful History item.

### Q803-A-03 — Chat, Location Sharing and Settings

1. In Chat, focus the message field, send action and Back navigation.
2. Open Location Sharing and focus consent, recipient, status and stop controls.
3. Open Settings and focus language, appearance, permissions and close/back
   controls.
4. Open and dismiss one dialog or bottom sheet using its labeled dismissal.

**Expected:** controls have meaningful names, logical order and no focus trap.
Do not send a message or start location sharing.

### Q803-A-04 — Large text and contrast

1. Disable/exit TalkBack temporarily only if required to change Android font and
   display size; set a large supported size.
2. Inspect Home, History, Details, Chat, Location Sharing and Settings.
3. Verify SOS, error, selected and disabled states are not communicated by
   color alone and text/controls remain visible and reachable.
4. Restore the prior text size and re-enable TalkBack.

## iOS VoiceOver cases

Repeat equivalent cases Q803-A-01 through Q803-A-04 on the iPhone with
VoiceOver enabled. VoiceOver results must be recorded independently; Android
TalkBack results cannot be reused. Verify rotor/focus order, labeled close/back
controls, text field/send action, and no focus loss after navigation or a live
status update. Do not create or transmit an SOS.

## Evidence template

```text
Test ID:
Device / OS / app build:
Screen-reader state:
Preconditions:
Exact actions:
Expected announcement/behavior:
Actual announcement/behavior:
Evidence (sanitized):
Result (PASS/FAIL/PARTIAL/NOT RUN):
```

## Current evidence

- Automated semantics/layout and critical UX tests: VERIFIED (20 focused;
  full Flutter suite 445 passed).
- Android TalkBack: NOT RUN — requires operator to enable TalkBack and report
  announcements.
- iOS VoiceOver: NOT RUN — requires operator to enable VoiceOver and report
  announcements.
- Physical contrast/focus audit: NOT RUN.
