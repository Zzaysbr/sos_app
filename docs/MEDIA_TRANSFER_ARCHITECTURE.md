# Image/video transfer — build 9 implementation and future design

## Current implementation (8 November 2026)

Offline media is now mandatory for the mini-project. The working tree implements
four Chat choices: take/choose a photo and record/choose a video, using
`image_picker` 1.2.4; local video validation/playback uses `video_player` 2.14.1.
Both plugins are maintained by Flutter; platform setup was checked against
https://pub.dev/packages/image_picker and https://pub.dev/packages/video_player.
Implementation is **not physical media acceptance**. Build 5 device results apply
to the previous text-only version, not this source.

The following current source replaces conflicting historical design statements
below. The remaining sections describe additional future hardening, not features
that can be claimed implemented or verified.

| Layer | Current behavior |
|---|---|
| UI | `chat_media.dart` and `emergency_chat_page.dart`: explicit four-source menu, confirmation, camera/library permission errors, private copied files, image preview, local video player; verified active incident/helper required. Android lost picker result is bound to owner/incident and reconfirmed; no automatic send. |
| Image processing | Source at most20MiB/64MP; raster onto white at960px and native JPEG quality68, retry720px55 then480px40. New-send hard64KiB; no source EXIF/GPS copied. Old PNG/JPEG wire compatibility limit2MiB remains unchanged. |
| Video | Source at most128MiB/15seconds/4K, probed before export. Native compress_video1.0.0 requests H264/SDR MP4 <=480px/15fps with monoAAC32kbps, target0.30MB; retry360px/0.18MB if output exceeds512KiB. Re-probe actual output dimensions/duration/codec, check MP4 header; hard512KiB, no uncompressed fallback or automatic trimming. Image and video share camera/gallery and recovered-picker pipeline. Source retained; own temporary outputs removed on failure/cancel. Existing receiver decoding and old10MiB wire cap unchanged. Video metadata stripping is not claimed. |
| Signed metadata | `ChatRelayBody` schema2 carries `MediaManifest` (MIME, size, full SHA-256, Merkle root, fixed4KiB chunks). Existing schema1 text canonical bytes remain unchanged. The Chat signature binds incident/origin, parties, manifest and expiry; existing signed hop path and Help Offer authorization apply. |
| Capability | New peers advertise `chat.media.v1`; media manifests forward only to supporting proven peers. Older peers retain text support but cannot carry media. |
| Bytes/state | `MediaAttachmentStore` keeps bytes in app-private owner-hashed/message-hashed directories, not SQLite/base64 blobs. Atomic JSON metadata, flushed chunk files and final rename; no database migration (schema10). No wire file paths or original user filenames. Files are not encrypted at rest by this implementation. |
| Recovery | Receiver requests first missing chunk from saved previous key using a fresh proven session binding. Index-bound Merkle proofs authenticate each chunk; full digest/length/type is checked before completion. Completed intermediary files forward the signed manifest and serve chunks on the next hop. Final recipient validates actual decoding, then commits Chat before a signed final storage receipt. |
| Bounds | At most2 incomplete inbound objects per owner,128 objects per owner,15MiB per incident,50MiB total file+reserved staging quota across namespaces. One chunk reply in flight per peer/role. Persisted8-request ceiling per current missing chunk,30..480second backoff, original Chat30minute expiry (never renewed by recovery). Retain completed Chat files; clean expired incomplete staging. There is no media storage management UI yet. |
| Scheduling | Outbound chunk requests run after SOS/control/text scheduling, one per pass. Reply frames use the existing bounded serialized write queue; a peer cannot enqueue a second media reply while the first is active. No bandwidth/latency guarantee. Build8 queries negotiated native single-packet capacity (20..512 bytes, fallback20). iOS uses its withoutResponse size bound while retaining withResponse writes; Android saves actual MTU by role and waits up to3seconds for negotiation after subscription before readiness. Assembly tolerates active control-message interleaving, expires after10seconds peer inactivity or5minutes total age, with16 incomplete-message/64KiB logical-message caps. |
| Receipt | Existing signed receipt digest includes the media manifest; no final receipt before file completion/decoder/application row. Confirmed stored is durable machine storage, not viewing or a human response. |

Host tests cover authenticated A-B-C transfer with dropped chunks and exact file
comparison, corruption/reorder/replay, store restart, request backoff/budget,
staging quotas across accounts, assembly recovery, all four menu choices and
unverified-helper denial. Existing default suite601 passed and explicit original
receipt contract1 passed; static analysis clean at this implementation checkpoint.
These tests do not measure physical throughput, native picker/playback, disk-full
faults, every crash boundary, video interoperability or background transfer.
Build8 checkpoint: full default host suite607 passed, original explicit receipt contract1 passed and captured physical-photo signature/hop/digest/Merkle verification1 passed. Static analysis and configured Android debug/iOS signed Profile native builds passed. iPhone8 installed in place with21 SOS/57 Chat rows and media/map files retained; user confirms Home launch/history. Samsung/iPad remain7. First build7 physical camera-photo transfer FAILED (no receiver photo after3minutes); build8 negotiated capacity/assembly recovery has NOT yet passed physical media delivery. Evidence: `artifacts/physical_e2e/20261108_media_frame_recovery/`. Live retry-eligible outgoing Chat now keeps startup BLE recovery active even when the local source file is complete and no final receipt exists; retry budget and original expiry remain unchanged.

## Historical proposal / remaining hardening

Stage 2 originally had attachment metadata only. Its historical proposal follows;
the implementation table above is authoritative for build9 and the signed text
receipt is already implemented in build5. The old v9/future-receipt statements
below must not be read as current implementation status.

## Trust and signed manifest

A sender must be an authorized incident participant under the same verified SOS
and explicit signed Help Offer relationship used for text. A relay's current
Session Proof authenticates the immediate hop independently from the original
sender. Never trust MIME, ownership, file path or incident IDs solely because the
sender asserts them. Enforce lifecycle/account authorization before forwarding
and before displaying or opening an attachment.

A versioned, canonical, domain-separated signed manifest should bind: attachment
ID, Chat message ID, incident ID and immutable SOS digest, sender and recipient
installation keys, creation/expiry, sanitized display filename, declared MIME,
exact byte length, chunk size/count, SHA-256 full-object digest and a chunk-integrity
commitment (individual hashes for small manifests, or a Merkle root for large
ones). Include the encryption suite/version and ciphertext commitments if E2EE is
selected. Bind manifest digest into each transfer and receipt. Replays with the
same ID and another digest must fail, including after restart.

Signed manifests authenticate data; they do not encrypt it. Relays can read
current signed plaintext Chat. Evaluate end-to-end encryption as a separate
requirement before claiming attachment confidentiality: audited key agreement,
recipient identity binding to verified participants, AEAD, unique per-object keys
and nonces, authenticated chunk position/manifest context, replay resistance,
key rotation/recovery, multi-device behavior and encrypted-at-rest keys. Define
whether relays verify ciphertext hashes and endpoints verify plaintext hashes;
avoid exposing plaintext hashes if they create unacceptable correlation risks.
Do not invent a cryptographic scheme or treat Session Proof as E2EE.

## Storage and durable model

Use app-private files for bytes and database records for metadata/state only.
Never store base64 media blobs in Drift rows or copy source absolute paths over
the wire. Introduce a future additive migration **after** v9, with explicit
upgrade/recovery tests; Stage 2 keeps v9 unchanged.

Proposed records: attachment manifest, owner/incident association, local file
handle, expiry, verified byte count, per-peer transfer state and a received-chunk
bitmap/range set. Store forwarded inbox and outbox independently per installation.
Use app-generated opaque filenames. Resolve them beneath an app-owned root;
reject traversal, symlinks and caller-supplied absolute destinations. Persist
files via temporary staging, chunk integrity verification, bounded write/fsync
policy and atomic rename after whole-object SHA-256 validation. Reconcile file
and DB state on restart: neither a DB receipt nor a final rename alone proves
that both commits survived a crash.

A recipient can expose the attachment only after full verification. A relay can
store and forward validated chunks according to the signed commitment while
retaining the immutable sender manifest and hop/path evidence. Receipts must
mean durable persistence, not a native write completion.

## Chunk protocol and recovery

Negotiate media capability, supported version, size and chunk/window limits after
real Session Proof. Transfer application chunks over the existing framing layer;
application chunks are not GATT packets. A transfer identifier binds the manifest
digest, destination and attempt/session binding. Each chunk carries its index,
exact bounded length and integrity proof; validate ranges/count/length arithmetic
before allocating memory or disk.

Maintain a small bounded window. A signed or session-authenticated hop receipt
binds durable chunk/range state and manifest digest; a separately signed final
recipient receipt proves end-to-end completion. Both contracts are future work:
current text Chat has neither a hop receipt nor a final receipt protocol.

On reconnect, require a fresh Session Proof, exchange committed ranges and resume
only missing verified chunks. Do not carry an old session binding into a new
connection. Resend lost receipts/chunks idempotently. Persist retry budgets and
backoff, cap overall age and attempts, and retain recoverable state after
transient failure. Terminal quota/authorization/expiry errors must not spin.
Use the signed bounded path chain to exclude visited peers and prefer the actual
destination; never broadcast media to all nearby devices.

## Initial policy proposal (requires product validation)

| Resource | Proposed starting bound |
|---|---|
| Image object | 2 MiB after processing, bounded dimensions/pixel count |
| Video object | 10 MiB after processing, up to 15 seconds |
| Application chunk | 4 KiB initially; negotiate downward |
| Outstanding window | At most 2 chunks per peer |
| Active media transfers | 1 per peer, 2 per installation |
| Staging + relay quota | 50 MiB total, reserved before accepting manifest |
| Per-incident quota | 15 MiB |
| Incomplete lifetime | At most 24 hours; align with incident retention policy |

These are design limits, not demonstrated usable BLE transfer sizes/speeds.
Video may be impractical at the current 6-byte frame payload; measure hardware
throughput before promising an experience. Account for ciphertext, temporary
files, manifests, receipts, bitmap growth and filesystem overhead. Reject new
work before quota allocation exceeds limits. Protect SOS/security/text capacity;
never evict undelivered priority traffic to accept media. Cleanup should delete
expired/orphaned media in bounded batches, release quota transactionally and
preserve an authorized transfer's necessary resume state until policy expiry.
Disk-full handling must leave existing valid data intact.

## Validation and privacy

Allowlist codecs/MIME and check content magic plus a bounded decoder's actual
format, dimensions and duration. Check both compressed and decoded resource
limits; reject archives, executable content, mismatched metadata and malformed
containers. A filename extension is not MIME validation. Treat thumbnails and
transcodes as new derived objects with explicit digests. Never execute media or
allow arbitrary URI schemes. Sandbox display/decoding and handle decoder errors.

Strip location/EXIF and other identifying metadata by default unless the user
explicitly opts to share it. Do not log paths, file content, full digests linked
to identities or private thumbnails. Use app-private storage, platform file
protection where available, OS secure key storage and explicit retention/account
cleanup semantics. Evaluate screenshot/backup/export behavior and encrypted
cache/thumbnail requirements. Signed SOS GPS provenance is separate from media
metadata and remains subject to location permission and authenticity limits.

## Scheduling and platforms

Priority: SOS/lifecycle and security controls, storage receipts, text Chat, then
media. Pause media between small bounded chunks when priority work arrives.
Apply fair per-peer quotas and backpressure; never enqueue a whole video as an
unbounded frame list on the shared write queue. Media processing/transcoding and
hashing should stream bounded buffers away from UI-critical work where supported.

Use Android/iOS platform pickers and app-private copied files; transient picker
URIs and iOS security-scoped URLs cannot be persisted as transfer authority.
Handle permission denial, low disk, app termination, OS suspension and restricted
background BLE honestly. Foreground/background policy must follow each native
transport's real capabilities. No always-on delivery guarantee is proposed.

## Verification before implementation release

Extend the three-node harness at the external file/picker boundary while retaining
real manifest signatures, persistence and handlers. Test corruption at every
chunk boundary, reorder/duplicates, resume on all hops, receipt loss, disk full,
quota competition, crash between file/DB commits, malicious lengths/MIME,
unauthorized participants, lifecycle revocation, encrypted tampering, cleanup and
text/SOS priority. Run upgrade tests on a copy of a v9 database and prove existing
durable jobs remain intact. Then verify Android/iOS interoperability, actual
transfer times, memory, thermal/battery behavior and background restrictions on
physical hardware. All such media verification is **NOT TESTED** in Stage 2.


Build9 compression candidate (8 November2026): mandatory automatic compression
implemented before confirmation/import/manifest signing; UI displays measured
outputKB and reduction relative to picked input. Compression failures do not
enqueue the original. Existing stored attachments and cryptographic bindings
remain unchanged. Focused9 host tests pass with fake encoders for pipeline
bounds/retries/cleanup, not native codec quality. Native builds/final checks and
phone compression/playback/BLE delivery acceptance remain pending at this checkpoint.
Build8 Profile retry also had no visible photo within the requested3minutes;
compression is not yet evidence that the original transport failure is resolved.


Build10 iOS notification capacity correction (9 November2026): build8/9 native
query advertised per-central negotiated capacity but flushPeripheral still
rejected notifications above20 bytes. Physical iPhone log shows capability
writes start/fail with512-byte capacity; Samsung lacked incoming Relay proof.
Both query and actual send guard now use one per-central bounded helper. Swift
7-boundary/call-site regression and focused Bluetooth/media/receipt48 tests pass.
No compression/signature/wire-limit/schema change; native/install/device result
pending. See `20261109_ios_notification_capacity/DIAGNOSIS.json`.


Build11 viewer layout correction: gallery-video reached Samsung once and sender
confirmed storage, but playback remains unaccepted because portrait sizing
pushed controls off-screen. Video now fits remaining height above48px seek and
play targets within SafeArea; confirm dialog scrolls on short/enlarged-text views.
Original layout3 regression cases fail, fixed3 pass; scoped UI suites30 pass,
application analysis clean. Hardware playback retest pending, not all app pages
audited. Evidence: `20261109_media_viewer_layout/DIAGNOSIS.json`.


Build12 Android audio preparation candidate: physical Samsung short H264/AAC
source failed in Media3 AudioGraphInput during forced audio re-encode. Android
now requests AudioPassthrough (supportedAAC retained; unsupported audio may still
be converted by native plugin), while video is compressed under existing512KiB
output bound. iOS mono32kbps policy unchanged. Whitelisted diagnostic code only
in non-release logs. Host14pass; physical export/playback not yet accepted.
See `20261109_android_video_audio/DIAGNOSIS.json`.


Build13 native selection correction: Samsung Media3 encoder-selection probe
reproduces CBR->NONE, VBR->SUPPORTED at identical requested H264 parameters.
Raw MediaCodec direct configure/start/stop accepts both; the measured failure
is capability-filtered Media3 selection, not proof the hardware cannot encodeCBR.
Versioned MIT packages/compress_video1.0.0 override changes Android CBR toVBR;
final output512KiB guard retained. Full619 host tests/application analysis pass,
configured Android Profile13 builds. Native full export/device media acceptance
pending. Evidence: `20261109_android_video_vbr/DIAGNOSIS.json`.


Build14 Apple local-video MIME correction: received340644-byte compressed MP4
exactly matches source, but extensionless content fails default AVFoundation
track detection. Explicit MP4 MIME restores2tracks on same captured bytes in
native regression. Versioned BSD3 video_player_avfoundation override allows
video/mp4 orvideo/quicktime hints on local file URLs only, iOS17+/macOS14+.
Validation AND viewer supply the MIME; network behavior unchanged, no bytes
renamed/copied or cryptographic validation skipped. Older OS opaque-file case
not accepted. Focused27host tests/analysis pass; iPhone playback/receipt pending.
Evidence: `20261109_apple_video_mime/DIAGNOSIS.json`.
