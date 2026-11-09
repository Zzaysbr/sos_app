import 'dart:io';
import 'dart:typed_data';

import 'package:compress_video/compress_video.dart';
import 'package:flutter/material.dart';

/// A local poster frame only: no autoplay, player controller, extra attachment
/// copy or thumbnail transfer. Both incoming and outgoing bubbles use it.
class ChatVideoPreview extends StatefulWidget {
  const ChatVideoPreview({super.key, required this.file, this.loadThumbnail});

  final File file;
  final Future<Uint8List> Function(File file)? loadThumbnail;

  @override
  State<ChatVideoPreview> createState() => _ChatVideoPreviewState();
}

class _ChatVideoPreviewState extends State<ChatVideoPreview> {
  late Future<Uint8List?> _thumbnail;

  @override
  void initState() {
    super.initState();
    _thumbnail = _load();
  }

  @override
  void didUpdateWidget(ChatVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path ||
        oldWidget.loadThumbnail != widget.loadThumbnail) {
      _thumbnail = _load();
    }
  }

  Future<Uint8List?> _load() async {
    try {
      final bytes =
          await (widget.loadThumbnail?.call(widget.file) ??
                  CompressVideo().getThumbnail(
                    widget.file.path,
                    positionMs: 200,
                    quality: 65,
                    maxDimensionPx: 320,
                  ))
              .timeout(const Duration(seconds: 10));
      return bytes.isEmpty || bytes.length > 256 * 1024 ? null : bytes;
    } on Object {
      // Preview failure never changes delivery status or prevents full playback.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final openLabel = thai ? 'เปิดวิดีโอ' : 'Open video';
    return Semantics(
      label: openLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 220,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: const Color(0xff171a20),
                child: FutureBuilder<Uint8List?>(
                  future: _thumbnail,
                  builder: (context, snapshot) => Stack(
                    fit: StackFit.expand,
                    children: [
                      if (snapshot.data != null)
                        Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      const Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xb3000000),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xc0000000),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              openLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (snapshot.connectionState != ConnectionState.done)
                        const Positioned(
                          right: 8,
                          top: 8,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
