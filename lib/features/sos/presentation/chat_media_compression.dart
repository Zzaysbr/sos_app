import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:compress_video/compress_video.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Encoder seam for deterministic host tests; real codecs run on the device.
abstract interface class ChatMediaEncoder {
  Future<Uint8List> jpeg(Uint8List boundedPng, int quality);
  Future<MediaInfo> videoInfo(File file);
  Future<void> video(
    File source,
    File output, {
    required int longSide,
    required int videoBitrateBps,
  });
}

class NativeChatMediaEncoder implements ChatMediaEncoder {
  static final _video = CompressVideo();

  @override
  Future<Uint8List> jpeg(Uint8List boundedPng, int quality) =>
      FlutterImageCompress.compressWithList(
        boundedPng,
        minWidth: 1024,
        minHeight: 1024,
        quality: quality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

  @override
  Future<MediaInfo> videoInfo(File file) =>
      _video.getMediaInfo(file.path).timeout(const Duration(seconds: 20));

  @override
  Future<void> video(
    File source,
    File output, {
    required int longSide,
    required int videoBitrateBps,
  }) async {
    final job = _video.compress(
      source.path,
      options: chatVideoCompressionOptions(
        android: Platform.isAndroid,
        longSide: longSide,
        videoBitrateBps: videoBitrateBps,
        outputPath: output.path,
      ),
    );
    try {
      await job.result.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      await job.cancel();
      // Wait for native cancellation before the caller removes its partial file.
      try {
        await job.result;
      } on Object {
        // Preserve the timeout as the public failure.
      }
      rethrow;
    }
  }
}

/// Avoid Android's unnecessary audio decode/downmix pipeline for supported AAC.
/// Native passthrough retains audio and converts unsupported source formats as
/// needed. The caller still enforces the final file size/duration/codec bounds.
CompressOptions chatVideoCompressionOptions({
  required bool android,
  required int longSide,
  required int videoBitrateBps,
  required String outputPath,
}) => CompressOptions(
  maxLongSidePx: longSide,
  videoBitrateBps: videoBitrateBps,
  maxFps: 10,
  codec: VideoCodec.h264,
  hdr: HdrMode.toneMapToSdr,
  audio: android
      ? const AudioPassthrough()
      : const AudioReencode(bitrateBps: 32000, channels: 1),
  outputPath: outputPath,
);

String chatMediaFailureCode(Object error) {
  if (error is CompressVideoException) {
    return 'compression_${error.reason.name}';
  }
  if (error is TimeoutException) return 'compression_timeout';
  if (error is FormatException) {
    const codes = {
      'empty_media',
      'video_source_size',
      'video_duration',
      'video_compression',
      'video_compression_size',
      'image_size',
      'image_compression',
      'image_compression_size',
    };
    if (codes.contains(error.message)) return error.message;
  }
  return 'attachment_preparation';
}
