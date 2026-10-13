import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/data/ble_protocol.dart';

BleMessage _message({Object? payload, String id = 'message-1'}) => BleMessage(
  id: id,
  type: 'sos',
  createdAt: DateTime.utc(2026, 1, 1),
  payload: {'payload': payload ?? 'เหตุฉุกเฉิน 🚨'},
);

List<List<int>> _frames({Object? payload, int frameSize = 32}) =>
    BleMessageCodec.encode(
      _message(payload: payload),
      maxFrameBytes: frameSize,
    );

List<int> _withIndex(List<int> frame, int index) {
  final copy = List<int>.from(frame);
  copy[10] = index >> 8;
  copy[11] = index & 0xff;
  return copy;
}

List<int> _withCount(List<int> frame, int count) {
  final copy = List<int>.from(frame);
  copy[12] = count >> 8;
  copy[13] = count & 0xff;
  return copy;
}

void main() {
  test('round trips frames received in reverse order', () {
    final frames = _frames();
    final decoded = BleMessageCodec.decode(frames.reversed);
    expect(decoded.payload['payload'], 'เหตุฉุกเฉิน 🚨');
  });

  test('round trips frames in random order', () {
    final frames = _frames(payload: List<String>.filled(50, 'data'));
    final shuffled = List<List<int>>.from(frames)..shuffle(Random(42));
    expect(BleMessageCodec.decode(shuffled).type, 'sos');
  });

  test('assembles interleaved messages independently by token', () {
    final first = BleMessageCodec.encode(
      _message(id: 'message-a', payload: 'a' * 80),
    );
    final second = BleMessageCodec.encode(
      _message(id: 'message-b', payload: 'b' * 80),
    );
    final assembler = BleMessageAssembler();
    final decoded = <String>{};
    for (var i = 0; i < first.length || i < second.length; i++) {
      if (i < first.length) {
        final message = assembler.accept(first[i]);
        if (message != null) decoded.add(message.id);
      }
      if (i < second.length) {
        final message = assembler.accept(second[i]);
        if (message != null) decoded.add(message.id);
      }
    }
    expect(decoded, {'message-a', 'message-b'});
  });

  test('keeps every default frame within the unnegotiated ATT payload', () {
    final frames = BleMessageCodec.encode(_message(payload: 'ack' * 80));
    expect(frames, isNotEmpty);
    expect(frames.every((frame) => frame.length <= 20), isTrue);
    expect(BleMessageCodec.decode(frames).payload['payload'], 'ack' * 80);
  });

  test('accepts an identical duplicate but rejects conflicting duplicate', () {
    final frames = _frames(payload: List<String>.filled(20, 'data'));
    expect(BleMessageCodec.decode([...frames, frames.first]).type, 'sos');
    final conflicting = List<int>.from(frames.first)..[14] ^= 1;
    expect(
      () => BleMessageCodec.decode([...frames, conflicting]),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('rejects missing frames', () {
    final frames = _frames(payload: List<String>.filled(20, 'data'));
    expect(
      () => BleMessageCodec.decode(frames.take(frames.length - 1)),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('rejects invalid indices and inconsistent counts', () {
    final frames = _frames();
    expect(
      () => BleMessageCodec.decode([_withIndex(frames.first, frames.length)]),
      throwsA(isA<BleProtocolException>()),
    );
    expect(
      () =>
          BleMessageCodec.decode([_withCount(frames.first, frames.length + 1)]),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('preserves UTF-8 split across frame boundaries', () {
    final frames = _frames(payload: 'ก' * 100, frameSize: 20);
    expect(
      BleMessageCodec.decode(frames.reversed).payload['payload'],
      'ก' * 100,
    );
  });

  test('allows an empty structured payload but rejects an empty frame', () {
    final message = BleMessage(
      id: 'empty',
      type: 'ping',
      createdAt: DateTime.utc(2026),
      payload: const {},
    );
    expect(
      BleMessageCodec.decode(BleMessageCodec.encode(message)).payload,
      isEmpty,
    );
    expect(
      () => BleMessageCodec.decode([
        List<int>.filled(BleMessageCodec.headerBytes, 0),
      ]),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('rejects oversized payloads', () {
    expect(
      () => BleMessageCodec.encode(_message(payload: 'x' * 70000)),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('rejects malformed JSON, invalid UTF-8, and corrupted data', () {
    final frames = _frames();
    final malformed = List<int>.from(frames.first);
    malformed.removeRange(14, malformed.length);
    expect(
      () => BleMessageCodec.decode([malformed]),
      throwsA(isA<BleProtocolException>()),
    );

    final invalidUtf8 = List<int>.from(frames.first);
    invalidUtf8[14] = 0xff;
    expect(
      () => BleMessageCodec.decode([...frames.take(1), invalidUtf8]),
      throwsA(isA<BleProtocolException>()),
    );

    final corrupted = List<int>.from(frames.last)..[14] ^= 0x01;
    expect(
      () => BleMessageCodec.decode([
        ...frames.take(frames.length - 1),
        corrupted,
      ]),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('rejects a transport-truncated multi-frame message', () {
    final fullFrames = BleMessageCodec.encode(
      _message(id: 'truncated', payload: 'ack' * 80),
      maxFrameBytes: 180,
    );
    final truncated = fullFrames
        .map((frame) => frame.sublist(0, 20))
        .toList(growable: false);
    final assembler = BleMessageAssembler();
    expect(
      () => truncated.forEach(assembler.accept),
      throwsA(isA<BleProtocolException>()),
    );
  });

  test('assembler handles duplicates and expires incomplete messages', () {
    final frames = _frames(payload: List<String>.filled(20, 'data'));
    final assembler = BleMessageAssembler(timeout: const Duration(seconds: 1));
    final start = DateTime.utc(2026, 1, 1);
    expect(assembler.accept(frames.first, now: start), isNull);
    expect(assembler.accept(frames.first, now: start), isNull);
    expect(
      assembler.accept(
        frames[1],
        now: start.add(const Duration(milliseconds: 500)),
      ),
      isNull,
    );
    expect(
      assembler.accept(frames.last, now: start.add(const Duration(seconds: 2))),
      isNull,
    );
  });

  test('malformed frame does not poison the next complete message', () {
    final frames = _frames(payload: 'recovery', frameSize: 20);
    final assembler = BleMessageAssembler();
    final malformed = List<int>.from(frames.first)..[0] = 0xff;

    expect(
      () => assembler.accept(malformed),
      throwsA(isA<BleProtocolException>()),
    );

    BleMessage? decoded;
    for (final frame in frames) {
      decoded = assembler.accept(frame) ?? decoded;
    }
    expect(decoded?.id, 'message-1');
    expect(decoded?.payload['payload'], 'recovery');
  });
}
