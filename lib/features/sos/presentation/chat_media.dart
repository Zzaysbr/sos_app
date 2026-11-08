import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:compress_video/compress_video.dart' show MediaInfo;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'chat_media_compression.dart';

enum ChatMediaSource { cameraImage, libraryImage, cameraVideo, libraryVideo }

String mediaText(BuildContext context, String en, String th) =>
    Localizations.localeOf(context).languageCode == 'th' ? th : en;

class PreparedChatMedia {
  const PreparedChatMedia(
    this.file,
    this.mime, {
    this.temporary = false,
    this.originalBytes,
  });
  final File file;
  final String mime;
  final bool temporary;
  final int? originalBytes;
}

Future<PreparedChatMedia?> pickChatMedia(ChatMediaSource source) async {
  final picker = ImagePicker();
  final camera =
      source == ChatMediaSource.cameraImage ||
      source == ChatMediaSource.cameraVideo;
  final video =
      source == ChatMediaSource.cameraVideo ||
      source == ChatMediaSource.libraryVideo;
  final picked = video
      ? await picker.pickVideo(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxDuration: const Duration(seconds: 15),
          preferredCameraDevice: CameraDevice.rear,
        )
      : await picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 70,
          requestFullMetadata: false,
        );
  if (picked == null) return null;
  return prepareChatMedia(File(picked.path), video: video);
}

// Sending limits are deliberately smaller than the wire/storage compatibility
// limits: old attachments remain readable, while new BLE transfers use less data.
const chatImageSendBytes = 64 * 1024;
const chatVideoSendBytes = 512 * 1024;

Future<PreparedChatMedia> prepareChatMedia(
  File file, {
  required bool video,
  ChatMediaEncoder? encoder,
}) async {
  final codec = encoder ?? NativeChatMediaEncoder();
  final originalBytes = await file.length();
  if (originalBytes <= 0) throw const FormatException('empty_media');
  if (video) {
    // Check a selected camera/library source before invoking the native encoder.
    // The old10MiB wire cap applies to output, not a short high-bitrate source.
    if (originalBytes > 128 * 1024 * 1024) {
      throw const FormatException('video_source_size');
    }
    final source = await codec.videoInfo(file);
    if (!_validVideo(source) ||
        source.widthPx * source.heightPx > 3840 * 2160) {
      throw const FormatException('video_duration');
    }
    for (final setting in [(480, 0.30), (360, 0.18)]) {
      final output = await _mediaTemp('video', 'mp4');
      var keep = false;
      try {
        await codec.video(
          file,
          output,
          longSide: setting.$1,
          targetSizeMb: setting.$2,
        );
        final bytes = await output.length();
        if (bytes <= 0 || bytes > chatVideoSendBytes) continue;
        final info = await codec.videoInfo(output);
        if (!_validVideo(info) ||
            math.max(info.widthPx, info.heightPx) > 480 ||
            (info.videoCodec != 'h264' && info.videoCodec != 'unknown')) {
          throw const FormatException('video_compression');
        }
        final head = await output
            .openRead(0, 12)
            .fold<List<int>>([], (a, b) => a..addAll(b));
        if (head.length < 12 ||
            String.fromCharCodes(head.sublist(4, 8)) != 'ftyp' ||
            String.fromCharCodes(head.sublist(8, 12)) == 'qt  ') {
          throw const FormatException('video_compression');
        }
        keep = true;
        return PreparedChatMedia(
          output,
          'video/mp4',
          temporary: true,
          originalBytes: originalBytes,
        );
      } finally {
        if (!keep && await output.exists()) await output.delete();
      }
    }
    throw const FormatException('video_compression_size');
  }
  if (originalBytes > 20 * 1024 * 1024) {
    throw const FormatException('image_size');
  }
  final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 64 * 1024 * 1024 ||
        descriptor.width > 16384 ||
        descriptor.height > 16384) {
      throw const FormatException('image_size');
    }
    for (final setting in [(960, 68), (720, 55), (480, 40)]) {
      final scale = math.min(
        1.0,
        setting.$1 / math.max(descriptor.width, descriptor.height),
      );
      final decoder = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      ui.Image? image;
      ui.Image? opaque;
      ui.Picture? picture;
      try {
        image = (await decoder.getNextFrame()).image;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
        canvas.drawImage(image, ui.Offset.zero, ui.Paint());
        picture = recorder.endRecording();
        opaque = await picture.toImage(image.width, image.height);
        final png = await opaque.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw const FormatException('image_compression');
        final jpeg = await codec.jpeg(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          setting.$2,
        );
        if (jpeg.length < 3 ||
            jpeg[0] != 0xff ||
            jpeg[1] != 0xd8 ||
            jpeg[2] != 0xff) {
          throw const FormatException('image_compression');
        }
        if (jpeg.length > chatImageSendBytes) continue;
        final output = await _mediaTemp('image', 'jpg');
        try {
          await output.writeAsBytes(jpeg, flush: true);
        } on Object {
          if (await output.exists()) await output.delete();
          rethrow;
        }
        // Bounded rasterization and JPEG encoding carry no source EXIF/GPS.
        return PreparedChatMedia(
          output,
          'image/jpeg',
          temporary: true,
          originalBytes: originalBytes,
        );
      } finally {
        opaque?.dispose();
        picture?.dispose();
        image?.dispose();
        decoder.dispose();
      }
    }
    throw const FormatException('image_compression_size');
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

bool _validVideo(MediaInfo info) =>
    info.durationMs > 0 &&
    info.durationMs <= 15000 &&
    info.widthPx > 0 &&
    info.heightPx > 0;

Future<File> _mediaTemp(String kind, String extension) async => File(
  '${(await getTemporaryDirectory()).path}/chat-$kind-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}.$extension',
);

class ChatMediaViewer extends StatefulWidget {
  const ChatMediaViewer({super.key, required this.file, required this.mime});
  final File file;
  final String mime;
  @override
  State<ChatMediaViewer> createState() => _ChatMediaViewerState();
}

class _ChatMediaViewerState extends State<ChatMediaViewer> {
  VideoPlayerController? _video;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    if (widget.mime.startsWith('video/')) {
      final player = _video = VideoPlayerController.file(
        widget.file,
        httpHeaders: {'Content-Type': widget.mime},
      );
      player
          .initialize()
          .timeout(const Duration(seconds: 20))
          .then(
            (_) {
              if (mounted) setState(() {});
            },
            onError: (Object _) {
              if (mounted) setState(() => _failed = true);
            },
          );
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    return Scaffold(
      appBar: AppBar(title: Text(mediaText(context, 'Attachment', 'ไฟล์แนบ'))),
      body: Center(
        child: _failed
            ? Text(
                mediaText(
                  context,
                  'Unable to open this file',
                  'ไม่สามารถเปิดไฟล์นี้ได้',
                ),
              )
            : video == null
            ? InteractiveViewer(
                child: Image.file(
                  widget.file,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              )
            : !video.value.isInitialized
            ? const CircularProgressIndicator()
            : ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: video,
                builder: (context, value, _) => ChatVideoLayout(
                  aspectRatio: value.aspectRatio,
                  video: VideoPlayer(video),
                  progress: VideoProgressIndicator(video, allowScrubbing: true),
                  controls: IconButton.filled(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    tooltip: mediaText(
                      context,
                      value.isPlaying ? 'Pause' : 'Play',
                      value.isPlaying ? 'หยุดชั่วคราว' : 'เล่น',
                    ),
                    onPressed: () async {
                      value.isPlaying
                          ? await video.pause()
                          : await video.play();
                    },
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Video shares the available height with controls; portrait clips cannot push
/// the seek/play targets below the bottom edge or system navigation inset.
class ChatVideoLayout extends StatelessWidget {
  const ChatVideoLayout({
    super.key,
    required this.aspectRatio,
    required this.video,
    required this.progress,
    required this.controls,
  });
  final double aspectRatio;
  final Widget video;
  final Widget progress;
  final Widget controls;

  @override
  Widget build(BuildContext context) => SafeArea(
    minimum: const EdgeInsets.only(bottom: 8),
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio.isFinite && aspectRatio > 0
                  ? aspectRatio
                  : 1,
              child: video,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(height: 48, child: Center(child: progress)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: controls,
        ),
      ],
    ),
  );
}
