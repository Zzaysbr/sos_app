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
  final videoTargets = <(int, int)>[];
  final outputs = <File>[];
  List<int> imageBytes = [2000];
  List<int> videoBytes = [1000];
  int duration = 5000;
  String outputCodec = 'h264';
  int outputLongSide = 360;
  double outputFps = 10;
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
    widthPx: outputs.contains(file) ? outputLongSide : 1920,
    heightPx: outputs.contains(file) ? (outputLongSide * 9 / 16).round() : 1080,
    rotationDegrees: 0,
    sizeBytes: await file.length(),
    videoCodec: outputs.contains(file) ? outputCodec : 'hevc',
    videoBitrateBps: null,
    frameRateFps: outputFps,
    hasAudio: true,
    isHdr: false,
  );

  @override
  Future<void> video(
    File source,
    File output, {
    required int longSide,
    required int videoBitrateBps,
  }) async {
    videoTargets.add((longSide, videoBitrateBps));
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
        longSide: 360,
        videoBitrateBps: 96000,
        outputPath: '/temp/video.mp4',
      );
      expect(android.audio, isA<AudioPassthrough>());
      expect(android.codec, VideoCodec.h264);
      expect(android.maxLongSidePx, 360);
      expect(android.maxFps, 10);
      expect(android.videoBitrateBps, 96000);
      expect(android.targetSizeMb, isNull);
      final ios = chatVideoCompressionOptions(
        android: false,
        longSide: 240,
        videoBitrateBps: 64000,
        outputPath: '/temp/video.mp4',
      );
      expect(ios.audio, isA<AudioReencode>());
      expect(ios.videoBitrateBps, 64000);
      expect(ios.targetSizeMb, isNull);
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
    expect(encoder.dimensions, [(640, 360)]);
    expect(result.file.path, isNot(source.path));
  });

  test('photo automatically lowers dimensions/quality and rejects oversized output', () async {
    final source = await photo();
    final encoder = FakeEncoder()..imageBytes = [30000, 30000, 30000];
    await expectLater(
      prepareChatMedia(source, video: false, encoder: encoder),
      throwsA(isA<FormatException>()),
    );
    expect(encoder.dimensions, [(640, 360), (480, 270), (320, 180)]);
    expect(encoder.qualities, [55, 42, 30]);
    expect(root.listSync().length, 1);
  });

  test(
    'photo retries to smaller JPEG without returning uncompressed source',
    () async {
      final encoder = FakeEncoder()..imageBytes = [30000, 20000];
      final result = await prepareChatMedia(
        await photo(),
        video: false,
        encoder: encoder,
      );
      expect(await result.file.length(), 20000);
      expect(encoder.qualities, [55, 42]);
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
      expect(encoder.videoTargets, [(360, 96000)]);
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
      expect(encoder.videoTargets, [(360, 96000), (240, 64000)]);
      expect(await encoder.outputs.first.exists(), false);
      expect(await result.file.length(), 100000);
    },
  );

  test('video exceeding every fast-send budget is rejected without source fallback', () async {
    final source = await File('${root.path}/camera.mov')
        .writeAsBytes([1, 2, 3]);
    final encoder = FakeEncoder()..videoBytes = [400000, 400000];
    await expectLater(
      prepareChatMedia(source, video: true, encoder: encoder),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'code',
          'video_compression_size',
        ),
      ),
    );
    expect(encoder.outputs, hasLength(2));
    for (final output in encoder.outputs) {
      expect(await output.exists(), false);
    }
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test(
    'encoder output must actually honor the reduced dimensions and frame rate',
    () async {
      final source = await File('${root.path}/camera.mov')
          .writeAsBytes([1, 2, 3]);
      for (final badDimensions in [true, false]) {
        final encoder = FakeEncoder()
          ..outputLongSide = badDimensions ? 480 : 360
          ..outputFps = badDimensions ? 10 : 30;
        await expectLater(
          prepareChatMedia(source, video: true, encoder: encoder),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'code',
              'video_compression',
            ),
          ),
        );
        expect(await encoder.outputs.single.exists(), false);
      }
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
