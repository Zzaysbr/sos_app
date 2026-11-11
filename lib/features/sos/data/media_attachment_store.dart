import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../nearby_ble/domain/media_manifest.dart';

class StoredMedia {
  StoredMedia(this.directory, this.state);
  final Directory directory;
  final Map<String, Object?> state;
  String get id => state['id'] as String;
  String get incident => state['incident'] as String;
  MediaManifest get manifest => MediaManifest.fromJson(
    Map<String, Object?>.from(state['manifest'] as Map),
  );
  File get file => File('${directory.path}/content');
  bool get complete => state['complete'] == true;
  String? get envelope => state['envelope'] as String?;
  String? get transfer => state['transfer'] as String?;
  String? get previousKey => state['previousKey'] as String?;
  DateTime? get expires => DateTime.tryParse(state['expires'] as String? ?? '');
}

/// One store per account namespace. Bytes live in private opaque directories,
/// not SQLite/base64 rows. Atomic metadata + verified chunk files survive
/// reconnect/restart; a missing commit/file is treated as incomplete.
class MediaAttachmentStore {
  MediaAttachmentStore({required this.ownerId, this._root})
    : _lockKey = _root?.absolute.path ?? 'platform-chat-media-v1';
  final String ownerId;
  Directory? _root;
  final String _lockKey;
  // Store instances can overlap during account teardown/re-entry. Serialize
  // by storage root, including quota reservation across account namespaces.
  static final Map<String, Future<void>> _locks = {};
  static const totalQuota = 50 * 1024 * 1024;
  static const incidentQuota = 15 * 1024 * 1024;
  static const maxObjects = 128;

  Future<T> _serial<T>(Future<T> Function() work) {
    final next = (_locks[_lockKey] ?? Future<void>.value()).then((_) => work());
    final tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _locks[_lockKey] = tail;
    return next.whenComplete(() {
      if (identical(_locks[_lockKey], tail)) _locks.remove(_lockKey);
    });
  }

  Future<Directory> _base() async {
    final root = _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/chat-media-v1',
    );
    await root.create(recursive: true);
    await _ordinary(root.path, directory: true);
    return root;
  }

  Future<Directory> _owner() async {
    final base = await _base();
    final key = await _key(ownerId);
    final directory = Directory('${base.path}/$key');
    await directory.create();
    await _ordinary(directory.path, directory: true);
    return directory;
  }

  static Future<String> _key(String value) async =>
      (await Sha256().hash(utf8.encode(value))).bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
  static Future<void> _ordinary(String path, {bool directory = false}) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type !=
        (directory
            ? FileSystemEntityType.directory
            : FileSystemEntityType.file)) {
      throw const FormatException('Invalid private media storage');
    }
  }

  Future<StoredMedia?> _find(String id) async {
    final owner = await _owner();
    final directory = Directory('${owner.path}/${await _key(id)}');
    if (!await directory.exists()) return null;
    await _ordinary(directory.path, directory: true);
    final file = File('${directory.path}/state.json');
    if (!await file.exists()) return null;
    await _ordinary(file.path);
    final state = Map<String, Object?>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
    if (state['id'] != id) {
      throw const FormatException('Media identity conflict');
    }
    return StoredMedia(directory, state);
  }

  Future<StoredMedia?> find(String id) => _serial(() => _find(id));

  // Persist only an owner/message-scoped relative reference. iOS may move
  // the app's sandbox between installations; never reuse its old root.
  Future<({String reference, File file})?> _chatAttachment({
    required String id,
    required String incident,
    required String? mime,
    required String? path,
  }) async {
    if (mime == null) return null;
    final reference =
        'chat-media-v1/${await _key(ownerId)}/${await _key(id)}/content';
    final currentPath = _root == null
        ? null
        : '${_root!.path}/${await _key(ownerId)}/${await _key(id)}/content';
    if (path != null &&
        path != reference &&
        path != currentPath &&
        !path.endsWith('/$reference')) {
      return null;
    }
    final media = await _find(id);
    if (media == null ||
        !media.complete ||
        media.incident != incident ||
        media.manifest.mime != mime ||
        await FileSystemEntity.type(media.file.path, followLinks: false) !=
            FileSystemEntityType.file) {
      return null;
    }
    if (path == null) {
      // Metadata-only cloud restores used to erase this reference. Recover
      // only this owner's exact completed object, never a cloud-supplied path.
      if (await media.file.length() != media.manifest.bytes ||
          base64UrlEncode((await _hashFile(media.file)).bytes) !=
              media.manifest.digest) {
        return null;
      }
      try {
        await _checkMagic(media.file, mime);
      } on FormatException {
        return null;
      }
    }
    return (reference: reference, file: media.file);
  }

  Future<String?> canonicalChatPath({
    required String id,
    required String incident,
    required String? mime,
    required String? path,
  }) => _serial(
    () async =>
        (await _chatAttachment(
          id: id,
          incident: incident,
          mime: mime,
          path: path,
        ))?.reference ??
        path,
  );

  Future<String?> resolveChatPath({
    required String id,
    required String incident,
    required String? mime,
    required String? path,
  }) => _serial(
    () async =>
        (await _chatAttachment(
          id: id,
          incident: incident,
          mime: mime,
          path: path,
        ))?.file.path ??
        path,
  );

  Future<void> beginPicker(String incident, String kind) => _serial(() async {
    final file = File('${(await _base()).path}/picker.json');
    await file.writeAsString(
      jsonEncode({
        'owner': await _key(ownerId),
        'incident': incident,
        'kind': kind,
      }),
      flush: true,
    );
  });
  Future<String?> pendingPicker(String incident) => _serial(() async {
    final file = File('${(await _base()).path}/picker.json');
    if (!await file.exists()) return null;
    await _ordinary(file.path);
    final value = jsonDecode(await file.readAsString()) as Map;
    return value['owner'] == await _key(ownerId) &&
            value['incident'] == incident
        ? value['kind'] as String?
        : null;
  });
  Future<void> endPicker(String incident) => _serial(() async {
    final file = File('${(await _base()).path}/picker.json');
    if (!await file.exists()) return;
    await _ordinary(file.path);
    final value = jsonDecode(await file.readAsString()) as Map;
    if (value['owner'] == await _key(ownerId) &&
        value['incident'] == incident) {
      await file.delete();
    }
  });

  Future<void> allowTarget(String id, String key) => _serial(() async {
    final media = await _find(id);
    if (media == null || !media.complete) {
      throw const FormatException('Media not available');
    }
    final targets = List<String>.from(media.state['targets'] as List? ?? []);
    if (!targets.contains(key)) {
      if (targets.length >= 8) {
        throw const FormatException('Media target limit reached');
      }
      targets.add(key);
      media.state['targets'] = targets;
      await _save(media);
    }
  });

  Future<bool> claimRequest(String id, int index, DateTime now) => _serial(
    () async {
      final media = await _find(id);
      if (media == null ||
          media.complete ||
          !(media.expires?.isAfter(now) ?? false)) {
        return false;
      }
      media.manifest.lengthAt(index);
      final attempt = Map<String, Object?>.from(
        media.state['request'] as Map? ?? {},
      );
      final same = attempt['index'] == index;
      final count = same ? attempt['count'] as int? ?? 0 : 0;
      final due = DateTime.tryParse(attempt['due'] as String? ?? '');
      if (count >= 8 || (same && due != null && due.isAfter(now))) return false;
      media.state['request'] = {
        'index': index,
        'count': count + 1,
        'due': now
            .add(Duration(seconds: 30 * (1 << count.clamp(0, 4))))
            .toUtc()
            .toIso8601String(),
      };
      await _save(media);
      return true;
    },
  );

  Future<void> _save(StoredMedia media) async {
    final temp = File('${media.directory.path}/state.tmp');
    if (await FileSystemEntity.type(temp.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const FormatException('Invalid media staging file');
    }
    await temp.writeAsString(jsonEncode(media.state), flush: true);
    await temp.rename('${media.directory.path}/state.json');
  }

  Future<List<StoredMedia>> _all() async {
    final root = await _owner();
    final result = <StoredMedia>[];
    await for (final item in root.list(followLinks: false)) {
      if (item is! Directory) continue;
      final file = File('${item.path}/state.json');
      if (!await file.exists()) continue;
      await _ordinary(file.path);
      final state = Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
      result.add(StoredMedia(item, state));
    }
    return result;
  }

  Future<List<StoredMedia>> pending(DateTime now) => _serial(() async {
    if (!Platform.isAndroid && !Platform.isIOS && _root == null) {
      return <StoredMedia>[];
    }
    final result = <StoredMedia>[];
    for (final media in await _all()) {
      if (media.complete || media.envelope == null) continue;
      if (media.expires?.isAfter(now) ?? false) {
        result.add(media);
      } else {
        // Only incomplete expired staging; completed chat attachments stay.
        await media.directory.delete(recursive: true);
      }
    }
    return result;
  });

  Future<void> _reserve(String incident, int bytes) async {
    final records = await _all();
    if (records.length >= maxObjects ||
        records.where((r) => !r.complete).length >= 2 ||
        records
                    .where((r) => r.incident == incident)
                    .fold<int>(0, (n, r) => n + r.manifest.bytes) +
                bytes >
            incidentQuota) {
      throw const FormatException('Media storage quota reached');
    }
    // Across account namespaces; reserve twice for staging+atomic assembly.
    var used = 0;
    var reserved = 0;
    await for (final entity in (await _base()).list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      used += await entity.length();
      if (entity.path.endsWith('/state.json')) {
        final state = jsonDecode(await entity.readAsString()) as Map;
        if (state['complete'] != true) {
          reserved +=
              MediaManifest.fromJson(
                Map<String, Object?>.from(state['manifest'] as Map),
              ).bytes *
              2;
        }
      }
    }
    if (used + reserved + bytes * 2 > totalQuota) {
      throw const FormatException('Media storage quota reached');
    }
  }

  Future<StoredMedia> importFile({
    required String id,
    required String incident,
    required File source,
    required String mime,
  }) => _serial(() async {
    final bytes = await source.length();
    if (!MediaManifest.allowedMime.contains(mime) ||
        bytes < 1 ||
        bytes >
            (mime.startsWith('image/')
                ? MediaManifest.maxImageBytes
                : MediaManifest.maxVideoBytes)) {
      throw const FormatException('Media file exceeds allowed size');
    }
    if (await _find(id) != null) {
      throw const FormatException('Media ID already used');
    }
    await _reserve(incident, bytes);
    final directory = Directory('${(await _owner()).path}/${await _key(id)}');
    await directory.create();
    try {
      final staging = File('${directory.path}/import.tmp');
      final output = await staging.open(mode: FileMode.write);
      var copied = 0;
      try {
        await for (final data in source.openRead()) {
          copied += data.length;
          if (copied > bytes) {
            throw const FormatException('Media changed during import');
          }
          await output.writeFrom(data);
        }
        if (copied != bytes) {
          throw const FormatException('Media changed during import');
        }
        await output.flush();
      } finally {
        await output.close();
      }
      final hashes = await _leaves(staging, bytes);
      final digest = base64UrlEncode((await _hashFile(staging)).bytes);
      final manifest = MediaManifest(
        mime: mime,
        bytes: bytes,
        digest: digest,
        root: (await MediaManifest.tree(hashes)).last.single,
      );
      await _checkMagic(staging, mime);
      final media = StoredMedia(directory, {
        'id': id,
        'incident': incident,
        'manifest': manifest.toJson(),
        'complete': true,
      });
      await staging.rename(media.file.path);
      await _save(media);
      return media;
    } on Object {
      await directory.delete(recursive: true);
      rethrow;
    }
  });

  Future<StoredMedia> bind({
    required String id,
    required String incident,
    required MediaManifest manifest,
    required String envelope,
    required DateTime expires,
    String? transfer,
    String? previousKey,
  }) => _serial(() async {
    var media = await _find(id);
    if (media != null) {
      if (media.incident != incident ||
          jsonEncode(media.manifest.toJson()) !=
              jsonEncode(manifest.toJson()) ||
          (media.envelope != null && media.envelope != envelope)) {
        throw const FormatException('Conflicting media replay');
      }
    } else {
      await _reserve(incident, manifest.bytes);
      final directory = Directory('${(await _owner()).path}/${await _key(id)}');
      await directory.create();
      media = StoredMedia(directory, {
        'id': id,
        'incident': incident,
        'manifest': manifest.toJson(),
        'complete': false,
      });
    }
    media.state['envelope'] = envelope;
    media.state['expires'] = expires.toUtc().toIso8601String();
    // Retain the first authenticated inbound route, like final Chat receipts.
    if (media.transfer == null && transfer != null) {
      media.state['transfer'] = transfer;
      media.state['previousKey'] = previousKey;
    }
    await _save(media);
    return media;
  });

  Future<int?> nextMissing(String id) => _serial(() async {
    final media = await _find(id);
    if (media == null || media.complete) return null;
    for (var i = 0; i < media.manifest.count; i++) {
      final file = File('${media.directory.path}/chunk-$i');
      if (!await file.exists() ||
          await file.length() != media.manifest.lengthAt(i)) {
        return i;
      }
    }
    await _finish(media);
    return null;
  });

  Future<StoredMedia> putChunk(
    String id,
    int index,
    List<int> bytes,
    List<String> proof,
  ) => _serial(() async {
    final media = await _find(id);
    if (media == null) throw const FormatException('Unknown media');
    await media.manifest.verifyChunk(index, bytes, proof);
    if (media.complete) return media;
    final file = File('${media.directory.path}/chunk-$index');
    final temp = File('${media.directory.path}/chunk.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
    var available = 0;
    for (var i = 0; i < media.manifest.count; i++) {
      final chunk = File('${media.directory.path}/chunk-$i');
      if (await chunk.exists()) available++;
    }
    if (available != media.manifest.count) return media;
    return _finish(media);
  });

  Future<StoredMedia> _finish(StoredMedia media) async {
    final staging = File('${media.directory.path}/assemble.tmp');
    final output = await staging.open(mode: FileMode.write);
    try {
      for (var i = 0; i < media.manifest.count; i++) {
        final chunk = File('${media.directory.path}/chunk-$i');
        await _ordinary(chunk.path);
        await output.writeFrom(await chunk.readAsBytes());
      }
      await output.flush();
    } finally {
      await output.close();
    }
    if (await staging.length() != media.manifest.bytes ||
        base64UrlEncode((await _hashFile(staging)).bytes) !=
            media.manifest.digest) {
      await staging.delete();
      // Damaged staging must be requested again rather than stuck "complete".
      for (var i = 0; i < media.manifest.count; i++) {
        await File('${media.directory.path}/chunk-$i').delete();
      }
      throw const FormatException('Complete media integrity failed');
    }
    await _checkMagic(staging, media.manifest.mime);
    await staging.rename(media.file.path);
    media.state['complete'] = true;
    await _save(media);
    for (var i = 0; i < media.manifest.count; i++) {
      await File('${media.directory.path}/chunk-$i').delete();
    }
    return media;
  }

  final Map<String, List<List<String>>> _trees = {};
  Future<({Uint8List data, List<String> proof})> chunk(String id, int index) =>
      _serial(() async {
        final media = await _find(id);
        if (media == null || !media.complete) {
          throw const FormatException('Media not available');
        }
        await _ordinary(media.file.path);
        var tree = _trees[id];
        if (tree == null) {
          tree = await MediaManifest.tree(
            await _leaves(media.file, media.manifest.bytes),
          );
          if (tree.last.single != media.manifest.root) {
            throw const FormatException('Stored media damaged');
          }
          _trees.clear(); // bounded one-object cache
          _trees[id] = tree;
        }
        final length = media.manifest.lengthAt(index);
        final input = await media.file.open();
        try {
          await input.setPosition(index * MediaManifest.chunkBytes);
          return (
            data: await input.read(length),
            proof: MediaManifest.proof(tree, index),
          );
        } finally {
          await input.close();
        }
      });

  static Future<Hash> _hashFile(File file) async {
    final sink = Sha256().newHashSink();
    await for (final data in file.openRead()) {
      sink.add(data);
    }
    sink.close();
    return sink.hash();
  }

  static Future<List<String>> _leaves(File file, int length) async {
    final input = await file.open();
    final result = <String>[];
    try {
      var remaining = length;
      while (remaining > 0) {
        final bytes = await input.read(
          math.min(MediaManifest.chunkBytes, remaining),
        );
        if (bytes.isEmpty) throw const FormatException('Truncated media file');
        result.add(await MediaManifest.leaf(result.length, bytes));
        remaining -= bytes.length;
      }
    } finally {
      await input.close();
    }
    return result;
  }

  static Future<void> _checkMagic(File file, String mime) async {
    final input = await file.open();
    late Uint8List head;
    try {
      head = await input.read(32);
    } finally {
      await input.close();
    }
    final valid = switch (mime) {
      'image/png' =>
        head.length >= 8 &&
            head.take(8).join(',') == '137,80,78,71,13,10,26,10',
      'image/jpeg' =>
        head.length >= 3 && head[0] == 255 && head[1] == 216 && head[2] == 255,
      'video/mp4' || 'video/quicktime' =>
        head.length >= 12 &&
            ascii.decode(head.sublist(4, 8), allowInvalid: true) == 'ftyp',
      _ => false,
    };
    if (!valid) {
      throw const FormatException('Media format does not match content');
    }
  }
}
