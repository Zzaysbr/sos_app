# Offline SOS release readiness

This checklist describes the implementation currently in this repository. It
does not claim Android/iOS BLE interoperability until a physical-device test
has produced evidence.

## Offline data flow

1. `SosRepository.create()` writes the SOS row and `sos_sync_queue` in one
   Drift transaction. The local row is the source of truth while offline.
2. The BLE callback receives the persisted SOS and writes a durable BLE
   outbox row. BLE delivery is independent from Firestore sync.
3. `SosSyncCoordinator` retries the Firestore queue when connectivity returns,
   on authentication changes, and when the app resumes. A failed cloud write
   remains queued.
4. Chat messages and incoming location updates are read from Drift. BLE
   inbox/outbox rows use stable message IDs and explicit destinations.

Cloud success is never inferred from local creation or a BLE characteristic
write. A delivery is acknowledged only after a valid application ACK.

## Implemented safeguards

- Drift schema version is 5 with migrations for SOS, cloud queue, BLE inbox /
  outbox, and Chat records.
- Outbox claims and state transitions are conditional and preserve the stable
  message ID and destination across retries.
- `sending`, `writeAccepted`, and `awaitingAcknowledgement` rows are recovered
  as retryable after an interrupted run. `acknowledged` and `expired` rows are
  not requeued.
- Duplicate SOS, Chat, and location deliveries are idempotent. Wrong-peer,
  wrong-kind, conflicting-payload, and invalid ACKs are rejected.
- Incident coordinates are an immutable creation snapshot. Incoming shared
  locations are separate, sender-filtered, and expired locations are not shown
  as current.
- Location permission, disabled GPS, timeout, invalid coordinates, BLE
  permission failure, disconnect, and map tile errors have explicit UI/error
  states. No background location permission or tracking is used.

## Map configuration requirement

`MapTileProviderConfig` accepts `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, and
`MAP_TILE_USER_AGENT` through `--dart-define`. The checked-in OpenStreetMap
URL is a development fallback only. A compliant production tile provider,
its attribution, rate limits, and user-agent requirements must be selected and
configured before release. No API key or secret is stored in this repository.

## Permissions and platform limits

- Android requires the Bluetooth runtime permissions declared for the target
  SDK (`BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, and `BLUETOOTH_ADVERTISE`) and
  may require location services for scanning on some OS/device combinations.
- iOS requires the Bluetooth usage description. Location permission is needed
  only for location capture and map current-location display.
- BLE foreground lifecycle, screen lock, process termination, and background
  delivery remain device/OS dependent and require hardware verification.

## Verification run for this phase

The current automated validation was run from the repository root:

```text
flutter test                         139 passed
focused BLE/location tests           55 passed
flutter analyze                      32 pre-existing info findings only
flutter build apk --debug            passed
flutter build ios --debug --no-codesign  passed
git diff --check                     passed
```

The analyzer findings are in `packages/flutter_nearby_connections_plus`; no
new app-code analyzer errors were introduced.

## Hardware acceptance matrix

Run with one controlled Android phone and one controlled iPhone, keeping logs
separate and excluding payloads, coordinates, credentials, and personal data.

| Scenario | Required evidence |
| --- | --- |
| Scan / advertise | Bluetooth and permission readiness, start callback, discovery |
| Connect / GATT setup | connection status, service/RX/TX discovery, notification readiness |
| SOS delivery | frame assembly, inbox persistence, positive ACK, sender acknowledgement |
| Chat delivery | matching chat ACK and one persisted message |
| Location delivery | explicit recipient, valid non-expired update, matching ACK |
| ACK loss / retry | same message ID and destination on retry; no duplicate record |
| Disconnect / reconnect | assembly reset, recoverable outbox, no stale callback |
| Permission revoked | clear failure state and no false Connected / Delivered state |
| Restart with pending data | local rows and outbox survive; retry remains bounded |
| Expiry / Stop Sharing | expired location is not sent or displayed as current |

Background delivery and process-terminated delivery are not acceptance claims
for this phase.

## Release blockers

1. Configure and validate a production-compliant map tile provider.
2. Complete Android ↔ Android and Android ↔ iPhone hardware BLE tests.
3. Capture evidence for service discovery, notification readiness, persistence,
   ACK correlation, retry, and reconnect behavior.
4. Decide and document OS background behavior before promising delivery while
   the app is suspended or terminated.
