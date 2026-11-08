import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Signed as part of ChatRelayBody v2. Chunk proofs commit to both index and
/// content; the complete-file digest is checked again before exposing a file.
class MediaManifest {
  MediaManifest({
    required this.mime,
    required this.bytes,
    required this.digest,
    required this.root,
  }) {
    if (!allowedMime.contains(mime) ||
        bytes < 1 ||
        bytes > (mime.startsWith('image/') ? maxImageBytes : maxVideoBytes) ||
        !_hash(digest) ||
        !_hash(root)) {
      throw const FormatException('Invalid media manifest');
    }
  }

  static const chunkBytes = 4096;
  static const maxImageBytes = 2 * 1024 * 1024;
  static const maxVideoBytes = 10 * 1024 * 1024;
  static const allowedMime = {
    'image/png',
    'image/jpeg',
    'video/mp4',
    'video/quicktime',
  };
  final String mime;
  final int bytes;
  final String digest;
  final String root;
  int get count => (bytes + chunkBytes - 1) ~/ chunkBytes;
  int lengthAt(int index) {
    if (index < 0 || index >= count) {
      throw const FormatException('Invalid media chunk index');
    }
    return index == count - 1 ? bytes - index * chunkBytes : chunkBytes;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'mime': mime,
    'bytes': bytes,
    'sha256': digest,
    'merkleRoot': root,
    'chunkBytes': chunkBytes,
  };
  factory MediaManifest.fromJson(Map<String, Object?> json) {
    if (json['version'] != 1 ||
        json['chunkBytes'] != chunkBytes ||
        json['mime'] is! String ||
        json['bytes'] is! int ||
        json['sha256'] is! String ||
        json['merkleRoot'] is! String) {
      throw const FormatException('Unsupported media manifest');
    }
    return MediaManifest(
      mime: json['mime'] as String,
      bytes: json['bytes'] as int,
      digest: json['sha256'] as String,
      root: json['merkleRoot'] as String,
    );
  }

  Future<void> verifyChunk(
    int index,
    List<int> data,
    List<String> proof,
  ) async {
    if (data.length != lengthAt(index) ||
        proof.length != proofDepth(count) ||
        proof.any((p) => !_hash(p))) {
      throw const FormatException('Invalid media chunk/proof size');
    }
    var hash = await leaf(index, data);
    var cursor = index;
    for (final sibling in proof) {
      hash = cursor.isEven
          ? await branch(hash, sibling)
          : await branch(sibling, hash);
      cursor ~/= 2;
    }
    if (hash != root) {
      throw const FormatException('Media chunk integrity failed');
    }
  }

  static bool _hash(String value) {
    try {
      return value.length == 44 && base64Url.decode(value).length == 32;
    } on Object {
      return false;
    }
  }

  static Future<String> sha(List<int> data) async =>
      base64UrlEncode((await Sha256().hash(data)).bytes);
  static Future<String> leaf(int index, List<int> data) {
    final prefix = ByteData(5)
      ..setUint8(0, 0)
      ..setUint32(1, index);
    return sha([...prefix.buffer.asUint8List(), ...data]);
  }

  static Future<String> branch(String left, String right) =>
      sha([1, ...base64Url.decode(left), ...base64Url.decode(right)]);
  static int proofDepth(int n) {
    var depth = 0;
    while (n > 1) {
      n = (n + 1) ~/ 2;
      depth++;
    }
    return depth;
  }

  static Future<List<List<String>>> tree(List<String> leaves) async {
    if (leaves.isEmpty) throw const FormatException('Empty media tree');
    final levels = [List<String>.of(leaves)];
    while (levels.last.length > 1) {
      final row = levels.last;
      final next = <String>[];
      for (var i = 0; i < row.length; i += 2) {
        next.add(await branch(row[i], row[i + 1 < row.length ? i + 1 : i]));
      }
      levels.add(next);
    }
    return levels;
  }

  static List<String> proof(List<List<String>> tree, int index) {
    final result = <String>[];
    for (final level in tree.take(tree.length - 1)) {
      final sibling = index ^ 1;
      result.add(level[sibling < level.length ? sibling : index]);
      index ~/= 2;
    }
    return result;
  }
}
