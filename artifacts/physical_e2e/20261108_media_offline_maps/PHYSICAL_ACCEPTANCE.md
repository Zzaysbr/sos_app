> Historical build6 plan. Current scoped pair results and remaining checks are in
> [9 November acceptance status](../20261109_media_acceptance/STATUS.md).
> This document is not the current installation or feature-status report.

# Required build 6 acceptance — not yet performed

User is not ready for the offline-map physical test. Resume operator steps only
when ready; no device was installed during implementation. Preserve all history
with update-in-place installation of the same application/signing identity.
Check artifacts against BUILDS.json before each install, then launch and confirm
history, stopped-following state and version6 on each device.

## Offline maps (download first, then operate without Internet)

For each required Android/iOS demonstration device:

1. Online, open an existing coordinate-bearing incident, download a small named
   visible region with a bounded zoom interval. Confirm actual completion, region
   name/count/size. A marker over an empty map is not success.
2. Turn off Wi-Fi/mobile Internet, fully close and reopen the app (no data clear),
   open the same saved region. Verify base tiles, incident marker, pan and zoom
   inside the downloaded bounds/zoom interval. This must use disk, not only an
   already displayed map/image cache.
3. Check that outside coverage or a zoom level not downloaded is honestly shown
   as unavailable. Retain downloaded region/history for later demo; no new SOS.

Configuration usability test and online tiles do not prove this acceptance.

## Media inputs and delivery

Use a synthetic active SOS and a verified Help Offer, all peers on build6. Use
neutral nonprivate test imagery; begin with a small photo and a1–2second video.
Keep apps foreground while measuring; no transfer-time promise is made.

For both iPhone and Samsung as sender, verify all four distinct actions:

| Input | Sender selected/captured preview | Receiver opens exact file once | Sender final storage receipt |
|---|---|---|---|
| Take photo | NOT TESTED | NOT TESTED | NOT TESTED |
| Choose photo | NOT TESTED | NOT TESTED | NOT TESTED |
| Record video | NOT TESTED | NOT TESTED | NOT TESTED |
| Choose video | NOT TESTED | NOT TESTED | NOT TESTED |

Check iPad receipt/playback of a photo and video. Record actual file size and
elapsed time without exporting coordinates/content. Capture read-only private
DB/file evidence when wired; export only alias/count/hash comparisons, receipt
verification and limits, never raw media or user identifiers.

Then disconnect mid-transfer, reconnect and verify same message/file identity,
completed digest and one receiver Chat bubble; restart an intermediary with a
pending file where practical. Include a staged A-B-C image/video case if the
submission claims physical multi-hop media. Host simulation is not that proof.
Check final receipt cannot precede complete validated file and Chat commit.

Also verify cancel picker, denied camera/photo/microphone permission, oversize or
over15second video rejection, decoder failure and retained prior history. Cancel
the synthetic incident from origin and confirm helper cleanup/history retention.
Restore device network/font/locale preferences when done.

Limits:2MiB images,10MiB/15second videos, no video transcoding,30minute transfer
expiry, bounded quota/retries. Actual native video codec interoperability,
background delivery, long-idle/OS-kill, E2EE and all-device reliability remain
unverified. Confirmed stored is not a human read receipt.
