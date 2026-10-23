# BLE Range / Quality Diagnostic Runbook

Status: debug-only engineering tool. It is hidden from Settings in release
builds and the page itself refuses to render its controls in release mode.

## What the tool measures

The diagnostic sends a versioned debug ping through the existing
`BleTransportClient`, framing codec, native GATT connection and service UUIDs.
The peer's debug screen returns a matching application ACK on the same native
session role.

- `Attempted`: logical pings created by the sender.
- `Application ACK`: pings assembled by the peer and acknowledged back to the
  selected sender. This is the numerator for PDR.
- `Native failed`: a native frame write threw before the complete ping could be
  accepted by the local transport.
- `Timed out`: no valid ACK from the selected peer arrived within three seconds.
- `Pending`: pings still inside that timeout window.
- ACK latency: min, average, p50, p95 and max over valid application ACKs.
- Disconnect/reconnect: edge-counted state changes for the selected peer during
  the current run.
- RSSI: the last discovery result only. Android and iOS currently expose RSSI
  while scanning, but this transport has no connected-peer RSSI read API. The UI
  says `unavailable` when there is no valid scan result.

A successful native write is logged separately and never counted as delivery.
RSSI is never converted into distance, and one run cannot establish a maximum
range.

## Field workflow

Use two foreground, unlocked test phones with personal accounts, messages and
coordinates excluded. On the receiver, open **Settings → BLE Test (Debug)** and
start advertising. On the sender, scan, select the intended peer and wait for
`connected / GATT ready`.

For each of 5, 10, 20, 30 and 50 metres where the site safely allows it:

1. Select the operator-measured distance and `Open space`.
2. Keep phone height and orientation recorded and unchanged within the set.
3. Run at least 30 seconds. Save attempted/ACK/failed/timeout/PDR, latency,
   scan-time RSSI, disconnect/reconnect and device/OS details.
4. Repeat at least three times.
5. Repeat the same set with `Obstructed`, recording the obstruction (wall,
   vehicle, floor, vegetation) and interference conditions.
6. If the connection drops, preserve that run as evidence. Reconnect and start a
   separate run; do not combine results from different environments.

The result is an empirical quality sample for those devices, orientation,
firmware and site. It is not a guaranteed range or delivery claim.

## Automated coverage and limitations

`test/ble_range_diagnostic_test.dart` covers PDR, latency statistics, timeout,
native failure, wrong-peer/late/duplicate ACK rejection and reconnect state.
`test/ble_test_page_test.dart` verifies that a received diagnostic ping produces
a decodable application ACK. Physical distance runs have not yet been executed.

The diagnostic does not run in the background, survive process termination or
write results to the production SOS database. It adds no database table,
dependency, production protocol kind or native connection behavior.

