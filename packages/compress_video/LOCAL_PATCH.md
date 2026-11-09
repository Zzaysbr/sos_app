# Local compatibility patch

Based on compress_video1.0.0 (MIT), retaining lib/android/darwin and upstream license.
The app uses this local override so the exact native fix is versioned.
Android TransformerEngine requests VBR instead of unconditional CBR. Physical
Samsung SM-A536E Exynos AVC encoders report CBR unsupported and reject the
requested format, while VBR supports the same dimensions/15fps/bitrate.
The app still enforces actual512KiB output size before signing/queueing.
No silent-audio fallback or source-file bypass.

Build16 also supplies AVURLAssetOverrideMIMETypeKey for thumbnail extraction
from local extensionless ISO-BMFF files with an ftyp header (MP4 or QuickTime
major brand), on iOS17+/macOS14+. Normal named sources keep upstream behavior.
This fixes poster extraction from opaque Chat storage without making copies,
changing attachment bytes or thumbnail transfer/storage quota. Older Apple
systems retain upstream behavior and may show the play fallback.
Android camera export and phone playback were accepted in scoped build13/14
cases; build16 poster previews require separate physical acceptance.
