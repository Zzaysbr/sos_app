import 'dart:io';
import 'dart:ui' as ui;

import 'package:video_player/video_player.dart';

Future<void> validateChatMediaFile(File file, String mime) async {
  if (mime.startsWith('image/')) {
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width < 1 ||
          descriptor.height < 1 ||
          descriptor.width > 1024 ||
          descriptor.height > 1024) {
        throw const FormatException('Invalid attachment dimensions');
      }
      codec = await descriptor.instantiateCodec();
      image = (await codec.getNextFrame()).image;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  } else {
    final player = VideoPlayerController.file(
      file,
      httpHeaders: {'Content-Type': mime},
    );
    try {
      await player.initialize().timeout(const Duration(seconds: 20));
      if (player.value.hasError ||
          player.value.duration <= Duration.zero ||
          player.value.duration > const Duration(seconds: 15) ||
          player.value.size.width * player.value.size.height > 3840 * 2160) {
        throw const FormatException('Invalid attachment video');
      }
    } finally {
      await player.dispose();
    }
  }
}
