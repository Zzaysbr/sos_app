# Mandatory media acceptance checkpoint — 9 November 2026

This records scoped operator observations, not general reliability or release certification.

| Sender -> receiver | Source | Count / open or playback | Sender storage UI | Qualification |
|---|---|---|---|---|
| iPhone -> Samsung | Camera photo | 1 / full image opens | Confirmed stored | Earlier delivery slow; elapsed not instrumented |
| iPhone -> Samsung | Gallery photo | 1 / full image opens | Confirmed stored | One case |
| iPhone -> Samsung | Camera video | 1 / picture and audio play | Confirmed stored | One short clip |
| iPhone -> Samsung | Gallery video | 1 / picture and audio play | Confirmed stored | Playback accepted after Samsung11 viewer fix |
| Samsung -> iPhone | Camera photo | 1 / full image opens | Confirmed stored | Arrived after initial no-image report |
| Samsung -> iPhone | Gallery photo | 1 / full image opens | Confirmed stored | One case |
| Samsung -> iPhone | Camera video | 1 / picture and audio play | Confirmed stored | Required one iPhone Bluetooth OFF/ON; same clip, no resend |
| Samsung -> iPhone | Gallery video | 1 / picture and audio play | Confirmed stored | Later receiver snapshot confirms complete357134-byte file/local row/signed receipt |

Current installed versions: iPhone Profile14, Samsung Profile13, iPad Profile14 (operator confirms Home launch/history/archive continuity).
The final pair incident was cancelled at origin; user confirms original history/Chat retained and Samsung Helping removed it.

Read-only iPhone snapshots corroborate complete inbound JPEG40730/10550 and MP4 326721/357134 bytes with local Chat rows/signed receipts. Three captured receipts (two JPEGs and camera MP4) independently passed the production signature/digest/timing verifier at signed persistence time. This is not sender/receiver full-byte correlation for every row; the failed earlier340644-byte MP4 did match both files but exhausted local receipt recovery before the Apple MIME fix, remains unsigned, and is excluded from accepted media cases. No retry counters/expiry were manually reset.

Implemented: new images JPEG<=64KiB, video H264<=480px/15fps/15seconds/512KiB. Android retains supported AAC; iOS re-encodes monoAAC32kbps. Source files retained. Android local compress_video override uses VBR after physical Media3 selection regression (CBR NONE/VBR SUPPORTED). Apple local video_player_avfoundation override supplies MIME for opaque local files on iOS17+/macOS14+. No E2EE, video metadata-stripping or throughput guarantee.

Validation: full host619 passed on13;14 focused27 and native same-file Apple decoding43video/19audio samples passed; application analysis clean. Physical multi-hop media, iPad offline-map acceptance and all iPad picker routes, large/long files, background/kill, uninterrupted/repeated transfer and exhaustive permission/accessibility checks remain unverified. Text-only staged multi-hop evidence belongs to earlier scoped tests.

Offline maps: one saved region each accepted on Samsung/iPhone at documented zoom/bounds after offline reopening. Not every area/zoom or iPad.

iPad14 update-in-place: all3 SOS/15 Chat/13 rescue_inbox rows retained exactly; schema10 quick_check passed. No new media/SOS requested.

Latest Samsung-origin incident cleanup: operator confirms cancellation, history/Chat retained and iPad Helping removed it. Scoped functional demo acceptance is complete; submission packaging/rubric and documented reliability limitations remain separate. See HANDOVER.md.


Additional iPad receiver checkpoint (9 November2026): Samsung camera photo -> iPad: operator confirms count1/full image opens/Samsung Confirmed stored on a new synthetic incident. Foreground/offline pair, iPhone Bluetooth off. Size and independent file/receipt correlation not captured.

Samsung camera video -> iPad: operator confirms count1/video+audio playback/visible usable controls/Samsung Confirmed stored. No independent file/receipt capture or measured latency; no Bluetooth reset reported for this step. This completes scoped iPad receiver photo/video UI checks, not every picker route. Operator subsequently confirmed origin cancellation, retained history/Chat and iPad Helping removal.
