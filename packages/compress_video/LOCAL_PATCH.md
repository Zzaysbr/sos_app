# Local compatibility patch

Based on compress_video1.0.0 (MIT), retaining lib/android/darwin and upstream license.
The app uses this local override so the exact native fix is versioned.
Android TransformerEngine requests VBR instead of unconditional CBR. Physical
Samsung SM-A536E Exynos AVC encoders report CBR unsupported and reject the
requested format, while VBR supports the same dimensions/15fps/bitrate.
The app still enforces actual512KiB output size before signing/queueing.
No Apple native change, silent-audio fallback or source-file bypass.
Build13 hardware export acceptance remains pending.
