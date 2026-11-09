import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/relay_envelope.dart';

/// Account-scoped local display labels, never broadcast as authenticated names.
class RouteDeviceNames extends ChangeNotifier {
  RouteDeviceNames({required this.ownerId, this.directory});
  final String ownerId;
  final Directory? directory;
  Map<String, String> labels = const {};
  Future<Map<String, String>>? _loaded;
  static final _tails = <String, Future<void>>{};

  static bool validName(String value) =>
      value.runes.length <= 64 &&
      !RegExp(r'[\x00-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]')
          .hasMatch(value);

  Future<File> _file() async {
    final base =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/route-device-names-v1',
        );
    await base.create(recursive: true);
    if (await FileSystemEntity.type(base.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('Invalid label storage');
    }
    final key = (await Sha256().hash(utf8.encode(ownerId))).bytes
        .map((v) => v.toRadixString(16).padLeft(2, '0'))
        .join();
    return File('${base.path}/$key.json');
  }

  Future<Map<String, String>> _read(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return {};
    if (type != FileSystemEntityType.file || await file.length() > 65536) {
      throw const FormatException('Invalid label storage');
    }
    final data = jsonDecode(await file.readAsString());
    if (data is! Map || data.length > 128) {
      throw const FormatException('Invalid labels');
    }
    final values = <String, String>{};
    for (final entry in data.entries) {
      if (entry.key is! String ||
          entry.value is! String ||
          !validName(entry.value as String)) {
        throw const FormatException('Invalid label');
      }
      validateRelayKeyId(entry.key as String);
      values[entry.key as String] = (entry.value as String).trim();
    }
    return values;
  }

  Future<Map<String, String>> load() => _loaded ??= (() async {
    labels = Map.unmodifiable(await _read(await _file()));
    notifyListeners();
    return labels;
  })();

  Future<Map<String, String>> save(String key, String name) async {
    validateRelayKeyId(key);
    final trimmed = name.trim();
    if (!validName(trimmed)) {
      throw const FormatException('Invalid device label');
    }
    final file = await _file();
    final operation = (_tails[file.path] ?? Future<void>.value()).then((
      _,
    ) async {
      final names = await _read(file);
      if (trimmed.isEmpty) {
        names.remove(key);
      } else {
        names[key] = trimmed;
      }
      if (names.length > 128) {
        throw const FormatException('Too many device labels');
      }
      final staging = File('${file.path}.tmp');
      if (await FileSystemEntity.type(staging.path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException('Invalid label storage');
      }
      await staging.writeAsString(jsonEncode(names), flush: true);
      await staging.rename(file.path);
      return Map<String, String>.unmodifiable(names);
    });
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[file.path] = tail;
    return operation
        .then((value) {
          labels = value;
          _loaded = Future.value(value);
          notifyListeners();
          return value;
        })
        .whenComplete(() {
          if (identical(_tails[file.path], tail)) _tails.remove(file.path);
        });
  }
}
