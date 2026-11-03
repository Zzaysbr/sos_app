# Q-805B — Physical Map Acceptance

This runbook records physical map verification separately for Android and iOS.
Provider account ownership, plan/quota and terms remain owner-controlled
checks from Q-805A and are not reclassified by device results.

## Safety

- Use the existing application identity and update in place only.
- Never uninstall, clear data, reset the device, or print the production key.
- Test one device at a time and keep screenshots/logs free of secrets and
  personal coordinates where possible.

## Manual-test standard (project-wide)

Every manual test (BLE, Chat, Location, SOS, Maps, Permissions, Auth and
release installation) must record a Test ID, purpose, preconditions, exact
numbered steps, expected result, evidence required, and PASS/FAIL/PARTIAL/NOT
RUN result. `PASS` requires every expected observation; `FAIL` is reproducible;
`PARTIAL` means a required observation is indistinguishable or incomplete;
`NOT RUN` means a prerequisite or operator step was not completed. Existing
operator results are not upgraded by this documentation and no screenshots,
logs or timestamps are invented.

### Reusable result template

```text
Test ID / purpose:
Device / OS / app build:
Preconditions:
Steps performed:
Expected result:
Evidence captured (sanitized):
Result (PASS/FAIL/PARTIAL/NOT RUN):
Reason / next action:
```

## Q-805B executable procedures

Run these cases separately on each device using the template above.

### Q805B-01 — Online incident map, navigation and controls

**Preconditions:** current build is installed from the Home Screen; an existing
incident has stored coordinates; internet is on. **Steps:** (1) Open the app
from the Home Screen. (2) Open History and select the incident. (3) Open its map
view and wait through the existing loading state. (4) Pan, zoom in, zoom out and
recenter. (5) Back out, reopen the incident and repeat one control action.
**Expected/evidence:** tiles, marker and stored coordinates are visible with no
crash or overflow; capture a sanitized screenshot. Mark NOT RUN when no
coordinate-bearing incident exists.

### Q805B-02 — Network failure and recovery

**Preconditions:** map is open and visible; record only a non-sensitive area
description. **Steps:** (1) Disable Wi-Fi and mobile data. (2) Wait for the
existing error/retry state. (3) Pan to an area not previously visible in this
session. (4) Record marker/incident-coordinate behavior. (5) Restore network and
use the existing retry/reload control. **Expected/evidence:** no crash; a fetch
need produces an explicit unavailable/error state; stored incident data remains
separate from current-location availability. A cached map is not network proof.

### Q805B-03 — Fresh online tile reload (not cache)

**Preconditions:** map open with internet on; choose an area outside tiles
already visible. **Steps:** (1) Disable internet and navigate to that unseen
area. (2) Record the offline state. (3) Re-enable internet. (4) Invoke only the
existing retry/reload control and wait normally. (5) Navigate to a second unseen
area and compare. **Expected/evidence:** newly fetched content is
distinguishable from the cached frame. If the last map remains visible and a
fresh fetch cannot be distinguished, record `PARTIAL`, never PASS.

### Q805B-04 — Attribution visibility and links

**Steps:** (1) Verify readable `Powered by Geoapify`. (2) Tap its link and record
only the destination host. (3) Return. (4) Verify readable `© OpenStreetMap
contributors`. (5) Tap its link and record only the destination host. (6) Repeat
after a map-state change and, if applicable, larger text. **Expected/evidence:**
both remain visible and links open `geoapify.com` and `openstreetmap.org`; capture
text and sanitized hosts; FAIL if hidden, clipped or wrong-domain.

### Q805B-05 — GPS permission and current-location states

**Preconditions:** one existing incident with coordinates. **Steps:** (1) Deny
location permission before opening current-location UI. (2) Open the incident
map and verify stored marker/coordinates. (3) Verify current location is shown
as unavailable/denied. (4) Re-enable `While Using the App`. (5) Use the existing
current-location action and wait for its normal result. Record the exact message
if denied again. **Expected/evidence:** denial never erases incident
coordinates and the UI never claims a valid current fix without one.

### Q805B-06 — Large text and layout resilience

**Preconditions:** Q805B-01 at default text size. **Steps:** (1) Increase OS
font/display size (iOS Larger Text or Android font size). (2) Reopen the map.
(3) Check attribution and both links. (4) Use zoom, pan, recenter and retry.
(5) Navigate away/back, then restore the prior size. **Expected/evidence:** no
clipping, overlap, inaccessible control or safe-area obstruction; capture a
sanitized screenshot of the densest state.

Offline-region tests require a real downloaded region, actual tile rendering
after restart with internet disabled, and explicit zoom/bounds evidence;
metadata alone is never tile-rendering evidence.

## Per-device procedure

1. Confirm device model, OS, build mode and production define source.
2. Launch from the Home Screen and open an existing incident with coordinates.
3. Verify raster tiles load, then pan, zoom, leave and return to the map, and
   reopen the same incident.
4. Verify readable `Powered by Geoapify` and `© OpenStreetMap contributors`
   attribution, including both links and safe-area placement.
5. Disable network while the map is open. Confirm no crash, readable error/
   retry state, preserved marker/coordinates, then restore network and retry.
6. Deny location permission. Confirm an incident with stored coordinates still
   renders and the UI does not claim current location is available. Regrant and
   retry current location.
7. Increase text size and check attribution, zoom/recenter controls and
   overlays remain accessible and unobscured.

Record each item as `PASS — DEVICE VERIFIED`, `FAIL — REPRODUCIBLE DEFECT`,
`PARTIAL — INCOMPLETE EVIDENCE`, or `NOT RUN — DEVICE/ENVIRONMENT UNAVAILABLE`.
Offline-region behavior must be tested only where a real downloaded region
exists; metadata alone is not tile-rendering evidence.

## Current execution

| Device | Availability | Installation | Map acceptance |
|---|---|---|---|
| Samsung SM-A536E / Android 14 | ADB USB available | Debug + production config installed | PASS (operator-reported) |
| iPhone 15 Plus / iOS 27.0.1 | CoreDevice paired/available | Profile + production config installed | PASS (operator-reported) |

No physical map result is claimed until the operator confirms the visible map,
attribution, network recovery and permission cases for that device.

## Physical results — 3 November 2026

### Samsung SM-A536E / Android 14

The operator reported all requested Android map checks passed, including Home
Screen launch, incident map, tile loading, pan/zoom, navigation return,
attribution and links, network-off stability/retry, location-denied behavior,
coordinate preservation and text scaling. This is recorded as
`PASS — DEVICE VERIFIED (operator-reported)`; no screenshot/log bundle was
provided in this turn.

### iPhone 15 Plus / iOS 27.0.1

| Check | Result | Evidence |
|---|---|---|
| Home Screen launch | PASS — DEVICE VERIFIED | Opened successfully |
| Incident Map / tiles | PASS — DEVICE VERIFIED | Map visible and tiles loaded |
| Pan, zoom, leave/return | PASS — DEVICE VERIFIED | All completed |
| Geoapify attribution | PASS — DEVICE VERIFIED | Visible/readable |
| OpenStreetMap attribution | PASS — DEVICE VERIFIED | Visible/readable |
| Attribution links | PASS — DEVICE VERIFIED | Links opened |
| Network disabled | PASS — DEVICE VERIFIED | Existing map remained usable |
| Error/retry state | PASS — DEVICE VERIFIED | Current-location-unavailable message; no crash |
| Online tile recovery | PASS — DEVICE VERIFIED | After network restoration, a previously unseen area rendered fresh tiles; existing map remained usable and no crash/error was observed |
| Location denied | PASS — DEVICE VERIFIED | Existing map remained viewable |
| Incident coordinates | PASS — DEVICE VERIFIED | Coordinates remained inspectable |
| Current-location claim | PASS — DEVICE VERIFIED | User reported it was not incorrectly claimed available |
| Permission regrant | PASS — DEVICE VERIFIED | Permission restored |
| Large text/layout | PASS — DEVICE VERIFIED | No overflow reported |

No provider key, account credential or personal coordinate was recorded.
The iPhone fresh-reload evidence is now closed as operator-reported PASS. Provider
account/terms/quota and signed release checks remain owner-controlled blockers.
