import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:compress_video/compress_video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sos_app/features/sos/presentation/chat_media.dart';
import 'package:sos_app/features/sos/presentation/chat_media_compression.dart';

class TempPaths extends PathProviderPlatform {
  TempPaths(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

class FakeEncoder implements ChatMediaEncoder {
  final qualities = <int>[];
  final dimensions = <(int, int)>[];
  final videoTargets = <(int, double)>[];
  final outputs = <File>[];
  List<int> imageBytes = [2000];
  List<int> videoBytes = [1000];
  int duration = 5000;
  String outputCodec = 'h264';
  bool fail = false;
  @override
  Future<Uint8List> jpeg(Uint8List png, int quality) async {
    qualities.add(quality);
    final buffer = await ui.ImmutableBuffer.fromUint8List(png);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    dimensions.add((descriptor.width, descriptor.height));
    descriptor.dispose();
    buffer.dispose();
    if (fail) throw StateError('encoder failed');
    // The encoder is mocked: host tests verify bounds/control flow, not native JPEG quality.
    final data = Uint8List(imageBytes.removeAt(0));
    data.setRange(0, 3, [0xff, 0xd8, 0xff]);
    return data;
  }

  @override
  Future<MediaInfo> videoInfo(File file) async => MediaInfo(
    durationMs: duration,
    widthPx: outputs.contains(file) ? 480 : 1920,
    heightPx: outputs.contains(file) ? 270 : 1080,
    rotationDegrees: 0,
    sizeBytes: await file.length(),
    videoCodec: outputs.contains(file) ? outputCodec : 'hevc',
    videoBitrateBps: null,
    frameRateFps: 15,
    hasAudio: true,
    isHdr: false,
  );

  @override
  Future<void> video(
    File source,
    File output, {
    required int longSide,
    required double targetSizeMb,
  }) async {
    videoTargets.add((longSide, targetSizeMb));
    outputs.add(output);
    final data = Uint8List(videoBytes.removeAt(0));
    data.setRange(4, 12, 'ftypisom'.codeUnits);
    await output.writeAsBytes(data);
    if (fail) throw StateError('encoder failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform original;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat-compression-test-');
    original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TempPaths(root.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = original;
    await root.delete(recursive: true);
  });

  Future<File> photo() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff336699), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1600, 900);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('${root.path}/original.png');
    await f.writeAsBytes(png!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    return f;
  }

  test(
    'Android keeps supported AAC while video remains bounded and compressed',
    () {
      final android = chatVideoCompressionOptions(
        android: true,
        longSide: 480,
        targetSizeMb: 0.30,
        outputPath: '/temp/video.mp4',
      );
      expect(android.audio, isA<AudioPassthrough>());
      expect(android.codec, VideoCodec.h264);
      expect(android.maxLongSidePx, 480);
      expect(android.maxFps, 15);
      expect(android.targetSizeMb, 0.30);
      final ios = chatVideoCompressionOptions(
        android: false,
        longSide: 360,
        targetSizeMb: 0.18,
        outputPath: '/temp/video.mp4',
      );
      expect(ios.audio, isA<AudioReencode>());
      expect(ios.targetSizeMb, 0.18);
    },
  );
  test('diagnostic failure code never contains private exception details', () {
    expect(
      chatMediaFailureCode(const FormatException('/private/video.mov')),
      'attachment_preparation',
    );
    expect(
      chatMediaFailureCode(const FormatException('video_compression')),
      'video_compression',
    );
  });

  test('photo becomes bounded JPEG while preserving source bytes', () async {
    final source = await photo();
    final before = await source.readAsBytes();
    final encoder = FakeEncoder();
    final result = await prepareChatMedia(
      source,
      video: false,
      encoder: encoder,
    );
    expect(result.mime, 'image/jpeg');
    expect(result.temporary, true);
    expect(result.originalBytes, before.length);
    expect(await result.file.length(), lessThanOrEqualTo(chatImageSendBytes));
    expect(await source.readAsBytes(), before);
    expect(encoder.dimensions, [(960, 540)]);
    expect(result.file.path, isNot(source.path));
  });

  test('photo automatically lowers dimensions/quality and rejects oversized output', () async {
    final source = await photo();
    final encoder = FakeEncoder()..imageBytes = [70000, 70000, 70000];
    await expectLater(
      prepareChatMedia(source, video: false, encoder: encoder),
      throwsA(isA<FormatException>()),
    );
    expect(encoder.dimensions, [(960, 540), (720, 405), (480, 270)]);
    expect(encoder.qualities, [68, 55, 40]);
    expect(root.listSync().length, 1);
  });

  test(
    'photo retries to smaller JPEG without returning uncompressed source',
    () async {
      final encoder = FakeEncoder()..imageBytes = [70000, 40000];
      final result = await prepareChatMedia(
        await photo(),
        video: false,
        encoder: encoder,
      );
      expect(await result.file.length(), 40000);
      expect(encoder.qualities, [68, 55]);
    },
  );

  test(
    'short large video is compressed before output size enforcement',
    () async {
      final source = File('${root.path}/camera.mov');
      final handle = await source.open(mode: FileMode.write);
      await handle.truncate(12 * 1024 * 1024);
      await handle.close();
      final encoder = FakeEncoder();
      final result = await prepareChatMedia(
        source,
        video: true,
        encoder: encoder,
      );
      expect(result.mime, 'video/mp4');
      expect(result.temporary, true);
      expect(encoder.videoTargets, [(480, 0.30)]);
      expect(await result.file.length(), 1000);
      expect(await source.length(), 12 * 1024 * 1024);
    },
  );

  test(
    'oversized video retries lower target and removes first output',
    () async {
      final source = await File('${root.path}/camera.mov')
          .writeAsBytes([1, 2, 3]);
      final encoder = FakeEncoder()..videoBytes = [600000, 100000];
      final result = await prepareChatMedia(
        source,
        video: true,
        encoder: encoder,
      );
      expect(encoder.videoTargets, [(480, 0.30), (360, 0.18)]);
      expect(await encoder.outputs.first.exists(), false);
      expect(await result.file.length(), 100000);
    },
  );

  test(
    'failed video encoding deletes partial output and keeps original',
    () async {
      final source = await File('${root.path}/camera.mov')
          .writeAsBytes([1, 2, 3]);
      final encoder = FakeEncoder()..fail = true;
      await expectLater(
        prepareChatMedia(source, video: true, encoder: encoder),
        throwsStateError,
      );
      expect(await encoder.outputs.single.exists(), false);
      expect(await source.readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'long video rejected before transcoding; unsupported output never sent',
    () async {
      final source = await File('${root.path}/camera.mov')
          .writeAsBytes([1, 2, 3]);
      final encoder = FakeEncoder()..duration = 16000;
      await expectLater(
        prepareChatMedia(source, video: true, encoder: encoder),
        throwsFormatException,
      );
      expect(encoder.videoTargets, isEmpty);
      encoder.duration = 5000;
      encoder.outputCodec = 'hevc';
      await expectLater(
        prepareChatMedia(source, video: true, encoder: encoder),
        throwsFormatException,
      );
      expect(await encoder.outputs.single.exists(), false);
    },
  );
}
