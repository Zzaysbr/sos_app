# Local extensionless-file MIME patch

Based on Flutter video_player_avfoundation2.12.3, BSD3 license retained.
For file URLs only, an allowlisted Content-Type video/mp4 or video/quicktime
header selects AVURLAssetOverrideMIMETypeKey on iOS17+/macOS14+.
Network assets retain upstream options. No file copy/rename, quota bypass or
decoder-validation bypass. Older Apple OS versions retain upstream behavior
and are not accepted for this opaque-file playback case.
The app supplies MIME from its validated/signed media metadata to both file
validation and the attachment viewer. Native regression uses identical captured
bytes: extensionless default asset has0 tracks, explicit MP4 MIME has2.
