import 'dart:convert';
import 'dart:typed_data';

class BleProtocolException implements Exception {
  const BleProtocolException(this.message);
  final String message;
  @override
  String toString() => 'BleProtocolException: $message';
}

class BleMessage {
  const BleMessage({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });
  final String id;
  final String type;
  final Map<String, Object?> payload;
  final DateTime createdAt;
}

/// Versioned envelope and MTU-safe frames used by both native transports.
class BleMessageCodec {
  static const protocolVersion = 1;
  static const maxMessageBytes = 64 * 1024;
  // 20 bytes is the guaranteed application payload for an unnegotiated ATT
  // MTU. Every native implementation can carry this frame without truncation.
  static const transportSafeFrameBytes = 20;
  // 1 byte version + 1 byte flags + 8 byte token + 2 byte index + 2 byte count.
  static const headerBytes = 14;

  static List<List<int>> encode(
    BleMessage message, {
    int maxFrameBytes = transportSafeFrameBytes,
  }) {
    if (maxFrameBytes <= headerBytes) {
      throw const BleProtocolException('Frame size is too small');
    }
    final envelope = <String, Object?>{
      'v': protocolVersion,
      'id': message.id,
      'type': message.type,
      'createdAt': message.createdAt.toUtc().toIso8601String(),
      'payload': message.payload,
      'checksum': _crc32(utf8.encode(jsonEncode(message.payload))),
    };
    final body = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
    if (body.isEmpty || body.length > maxMessageBytes) {
      throw const BleProtocolException('Message size is invalid');
    }
    final chunkSize = maxFrameBytes - headerBytes;
    final count = (body.length + chunkSize - 1) ~/ chunkSize;
    if (count > 0xffff) throw const BleProtocolException('Too many frames');
    final token = _token(message.id);
    return List.generate(count, (index) {
      final start = index * chunkSize;
      final end = (start + chunkSize).clamp(0, body.length);
      final frame = BytesBuilder();
      frame.add([protocolVersion, 0]);
      frame.add(_u64(token));
      frame.add(_u16(index));
      frame.add(_u16(count));
      frame.add(body.sublist(start, end));
      return frame.takeBytes();
    });
  }

  static BleMessage decode(Iterable<List<int>> frames) {
    final list = frames.toList();
    if (list.isEmpty) throw const BleProtocolException('No frames');
    final chunks = <int, List<int>>{};
    int? count;
    int? token;
    for (final frame in list) {
      if (frame.length <= headerBytes || frame[0] != protocolVersion) {
        throw const BleProtocolException('Unsupported or malformed frame');
      }
      final t = _readU64(frame, 2);
      final index = _readU16(frame, 10);
      final c = _readU16(frame, 12);
      if (c == 0 ||
          index >= c ||
          (count != null && c != count) ||
          (token != null && t != token)) {
        throw const BleProtocolException('Inconsistent frame metadata');
      }
      count = c;
      token = t;
      final chunk = frame.sublist(headerBytes);
      final previous = chunks[index];
      if (previous != null && !_sameBytes(previous, chunk)) {
        throw const BleProtocolException('Conflicting duplicate frame');
      }
      chunks[index] = chunk;
    }
    if (count == null || chunks.length != count) {
      throw const BleProtocolException('Incomplete message');
    }
    final bytes = BytesBuilder();
    for (var i = 0; i < count; i++) {
      bytes.add(chunks[i]!);
    }
    if (bytes.length > maxMessageBytes) {
      throw const BleProtocolException('Message is too large');
    }
    try {
      final value = jsonDecode(
        utf8.decode(bytes.takeBytes(), allowMalformed: false),
      ) as Map;
      if (value['v'] != protocolVersion ||
          value['id'] is! String ||
          value['type'] is! String ||
          value['payload'] is! Map ||
          value['checksum'] is! num) {
        throw const BleProtocolException('Invalid message envelope');
      }
      final payload = Map<String, Object?>.from(value['payload'] as Map);
      if ((value['checksum'] as num).toInt() !=
          _crc32(utf8.encode(jsonEncode(payload)))) {
        throw const BleProtocolException('Checksum mismatch');
      }
      return BleMessage(
        id: value['id'] as String,
        type: value['type'] as String,
        createdAt: DateTime.parse(value['createdAt'] as String),
        payload: payload,
      );
    } on FormatException catch (e) {
      throw BleProtocolException('Invalid UTF-8 or JSON: $e');
    } on TypeError catch (e) {
      throw BleProtocolException('Invalid message envelope: $e');
    }
  }

  static int _token(String id) => id.codeUnits.fold<int>(
    0xcbf29ce484222325,
    (h, c) => ((h ^ c) * 0x100000001b3) & 0xffffffffffffffff,
  );
  static List<int> _u16(int v) => [(v >> 8) & 255, v & 255];
  static List<int> _u64(int v) =>
      List.generate(8, (i) => (v >> (56 - 8 * i)) & 255);
  static int _readU16(List<int> b, int o) => (b[o] << 8) | b[o + 1];
  static int _readU64(List<int> b, int o) =>
      b.sublist(o, o + 8).fold(0, (v, x) => (v << 8) | x);
  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}

/// Reassembles out-of-order frames and drops duplicate message ids.
class BleMessageAssembler {
  BleMessageAssembler({
    this.timeout = const Duration(seconds: 10),
    this.maxDeliveredIds = 1024,
    this.dropDuplicateMessages = true,
    this.maxAssemblyAge = const Duration(minutes: 5),
  }) : assert(maxDeliveredIds > 0);
  final Duration timeout;
  final Duration maxAssemblyAge;
  final int maxDeliveredIds;

  /// Coordinators that must re-ACK durable duplicate deliveries can disable
  /// this transport-level suppression and let their idempotent repository
  /// decide how to handle the repeated logical message.
  final bool dropDuplicateMessages;
  final _frames = <int, Map<int, List<int>>>{};
  final _counts = <int, int>{};
  final _sizes = <int, int>{};
  final _updated = <int, DateTime>{};
  final _created = <int, DateTime>{};
  DateTime? _lastActivity;
  final _delivered = <String, DateTime>{};

  BleMessage? accept(List<int> frame, {DateTime? now}) {
    final current = now ?? DateTime.now();
    _expire(current);
    if (frame.length <= BleMessageCodec.headerBytes ||
        frame[0] != BleMessageCodec.protocolVersion) {
      throw const BleProtocolException('Unsupported or malformed frame');
    }
    final token = frame.sublist(2, 10).fold(0, (v, x) => (v << 8) | x);
    try {
      final index = (frame[10] << 8) | frame[11];
      final count = (frame[12] << 8) | frame[13];
      if (count == 0 ||
          index >= count ||
          (_counts[token] != null && _counts[token] != count)) {
        throw const BleProtocolException('Inconsistent frame metadata');
      }
      if (!_frames.containsKey(token) && _frames.length >= 16) {
        throw const BleProtocolException('Too many incomplete messages');
      }
      final frames = _frames.putIfAbsent(token, () => <int, List<int>>{});
      final previous = frames[index];
      if (previous != null) {
        if (!BleMessageCodec._sameBytes(previous, frame)) {
          throw const BleProtocolException('Conflicting duplicate frame');
        }
        return null;
      }
      final size =
          (_sizes[token] ?? 0) + frame.length - BleMessageCodec.headerBytes;
      if (size > BleMessageCodec.maxMessageBytes) {
        throw const BleProtocolException('Message is too large');
      }
      frames[index] = List<int>.of(frame);
      _created.putIfAbsent(token, () => current);
      _lastActivity = current;
      _counts[token] = count;
      _sizes[token] = size;
      _updated[token] = current;
      // Decode/CRC only once. Previously every frame copied and decoded the
      // entire prefix, which was quadratic for media chunks.
      if (frames.length != count) return null;
      final message = BleMessageCodec.decode(frames.values);
      _frames.remove(token);
      _counts.remove(token);
      _sizes.remove(token);
      _updated.remove(token);
      _created.remove(token);
      final previousDelivery = _delivered[message.id];
      if (previousDelivery != null && dropDuplicateMessages) return null;
      _delivered[message.id] = current;
      _evictDeliveredIfNeeded();
      return message;
    } on BleProtocolException catch (error) {
      if (!error.message.contains('Incomplete')) {
        _frames.remove(token);
        _counts.remove(token);
        _sizes.remove(token);
        _updated.remove(token);
        _created.remove(token);
        rethrow;
      }
      return null;
    }
  }

  void _expire(DateTime now) {
    final peerIdle =
        _lastActivity == null || now.difference(_lastActivity!) > timeout;
    _updated.removeWhere((token, time) {
      // A high-priority control message can preempt media on the same peer.
      // Active interleaving is not a broken link. Still cap absolute lifetime
      // and the existing16-message/64KiB-per-message memory limits.
      final tooOld = now.difference(_created[token] ?? time) > maxAssemblyAge;
      if (!tooOld && (!peerIdle || now.difference(time) <= timeout)) {
        return false;
      }
      _frames.remove(token);
      _counts.remove(token);
      _sizes.remove(token);
      _created.remove(token);
      return true;
    });
    _delivered.removeWhere((_, time) => now.difference(time) > timeout);
  }

  void _evictDeliveredIfNeeded() {
    while (_delivered.length > maxDeliveredIds) {
      final oldest = _delivered.entries.reduce(
        (a, b) => a.value.isBefore(b.value) ? a : b,
      );
      _delivered.remove(oldest.key);
    }
  }
}
