import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/sos/data/media_attachment_store.dart';
import 'package:sos_app/features/sos/data/chat_repository.dart';
import 'package:sos_app/features/nearby_ble/domain/chat_relay_envelope.dart';
import 'package:sos_app/features/nearby_ble/domain/media_manifest.dart';

import 'support/three_node_ble_simulation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Future<Directory> temp() async {
    final directory = await Directory.systemTemp.createTemp('media-contract-');
    addTearDown(() => directory.delete(recursive: true));
    return directory;
  }

  Future<File> sample(Directory root) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xffc02020), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return File('${root.path}/synthetic.png')..writeAsBytesSync([
      ...data!.buffer.asUint8List(),
      ...List.generate(9000, (i) => i % 251),
    ]);
  }

  test('verified chunks resume after store restart; reorder/replay safe, corruption rejected', () async {
    final root = await temp();
    final a = MediaAttachmentStore(ownerId: 'A', root: root);
    final source = await a.importFile(
      id: 'm',
      incident: 'i',
      source: await sample(root),
      mime: 'image/png',
    );
    final b = MediaAttachmentStore(ownerId: 'B', root: root);
    await b.bind(
      id: 'm',
      incident: 'i',
      manifest: source.manifest,
      envelope: 'signed-test-envelope',
      expires: DateTime.now().add(const Duration(minutes: 10)),
      previousKey: 'A',
    );
    final c2 = await a.chunk('m', 2), c0 = await a.chunk('m', 0);
    await b.putChunk('m', 2, c2.data, c2.proof);
    await b.putChunk('m', 0, c0.data, c0.proof);
    await b.putChunk('m', 0, c0.data, c0.proof);
    await expectLater(
      b.putChunk('m', 1, c0.data, c0.proof),
      throwsFormatException,
    );
    final restarted = MediaAttachmentStore(ownerId: 'B', root: root);
    expect(await restarted.nextMissing('m'), 1);
    final c1 = await a.chunk('m', 1);
    final damaged = [...c1.data]..[13] ^= 1;
    await expectLater(
      restarted.putChunk('m', 1, damaged, c1.proof),
      throwsFormatException,
    );
    final complete = await restarted.putChunk('m', 1, c1.data, c1.proof);
    expect(complete.complete, isTrue);
    expect(await complete.file.readAsBytes(), await source.file.readAsBytes());
    expect(
      await MediaAttachmentStore(
        ownerId: 'different-owner',
        root: root,
      ).find('m'),
      isNull,
    );
    await expectLater(
      restarted.bind(
        id: 'm',
        incident: 'other',
        manifest: source.manifest,
        envelope: 'signed-test-envelope',
        expires: DateTime.now(),
      ),
      throwsFormatException,
    );
  });
  test('durable request budget and backoff cannot reset on restart', () async {
    final root = await temp();
    final a = MediaAttachmentStore(ownerId: 'A', root: root);
    final m = await a.importFile(
      id: 'm',
      incident: 'i',
      source: await sample(root),
      mime: 'image/png',
    );
    var b = MediaAttachmentStore(ownerId: 'B', root: root);
    var now = DateTime.utc(2026);
    await b.bind(
      id: 'm',
      incident: 'i',
      manifest: m.manifest,
      envelope: 'fixture',
      expires: now.add(const Duration(minutes: 30)),
    );
    expect(await b.claimRequest('m', 0, now), isTrue);
    expect(await b.claimRequest('m', 0, now), isFalse);
    for (var i = 1; i < 8; i++) {
      b = MediaAttachmentStore(ownerId: 'B', root: root);
      now = now.add(const Duration(minutes: 1));
      if (i > 1) now = now.add(const Duration(minutes: 7));
      // Use independent fixture expiry far enough to test the retry cap below.
      await b.bind(
        id: 'm',
        incident: 'i',
        manifest: m.manifest,
        envelope: 'fixture',
        expires: now.add(const Duration(minutes: 30)),
      );
      expect(await b.claimRequest('m', 0, now), isTrue);
    }
    now = now.add(const Duration(minutes: 10));
    expect(await b.claimRequest('m', 0, now), isFalse);
  });
  test(
    'quota reserves staging across accounts; expiry preserves completed files',
    () async {
      final root = await temp();
      final a = MediaAttachmentStore(ownerId: 'A', root: root);
      final m = await a.importFile(
        id: 'complete',
        incident: 'saved',
        source: await sample(root),
        mime: 'image/png',
      );
      final manifest = MediaManifest(
        mime: 'video/mp4',
        bytes: MediaManifest.maxVideoBytes,
        digest: m.manifest.digest,
        root: m.manifest.root,
      );
      final now = DateTime.utc(2026);
      await a.bind(
        id: 'pending-a',
        incident: 'one',
        manifest: manifest,
        envelope: 'fixture',
        expires: now,
      );
      await expectLater(
        a.bind(
          id: 'same-incident',
          incident: 'one',
          manifest: manifest,
          envelope: 'fixture',
          expires: now,
        ),
        throwsFormatException,
      );
      final b = MediaAttachmentStore(ownerId: 'B', root: root);
      final c = MediaAttachmentStore(ownerId: 'C', root: root);
      final results = await Future.wait([
        b
            .bind(
              id: 'pending-b',
              incident: 'two',
              manifest: manifest,
              envelope: 'fixture',
              expires: now,
            )
            .then((_) => true, onError: (Object _) => false),
        c
            .bind(
              id: 'over-global-quota',
              incident: 'three',
              manifest: manifest,
              envelope: 'fixture',
              expires: now,
            )
            .then((_) => true, onError: (Object _) => false),
      ]);
      expect(results, [true, false]);
      expect(await a.pending(now), isEmpty);
      expect(await a.find('pending-a'), isNull);
      expect((await a.find('complete'))!.complete, isTrue);
      expect(await m.file.exists(), isTrue);
    },
  );
  test(
    'reconciles chunks after crash before completion metadata commit',
    () async {
      final root = await temp();
      final a = MediaAttachmentStore(ownerId: 'A', root: root);
      final m = await a.importFile(
        id: 'm',
        incident: 'i',
        source: await sample(root),
        mime: 'image/png',
      );
      final b = MediaAttachmentStore(ownerId: 'B', root: root);
      final receiving = await b.bind(
        id: 'm',
        incident: 'i',
        manifest: m.manifest,
        envelope: 'fixture',
        expires: DateTime.now().add(const Duration(minutes: 30)),
      );
      for (var i = 0; i < m.manifest.count; i++) {
        final chunk = await a.chunk('m', i);
        await File('${receiving.directory.path}/chunk-$i')
            .writeAsBytes(chunk.data, flush: true);
      }
      final restarted = MediaAttachmentStore(ownerId: 'B', root: root);
      expect(await restarted.nextMissing('m'), isNull);
      expect((await restarted.find('m'))!.complete, isTrue);
      expect(await receiving.file.readAsBytes(), await m.file.readAsBytes());
    },
  );
  test('real signed A-B-C media waits for complete files and final recipient receipt', () async {
    final root = await temp();
    final s = ThreeNodeSimulation(mediaRoot: root);
    addTearDown(s.close);
    await s.start();
    await s.prepareIncident();
    final file = await s.a.coordinator.mediaStore.importFile(
      id: 'media-1',
      incident: 'incident-1',
      source: await sample(root),
      mime: 'image/png',
    );
    final chat = await s.a.chat.insertMessage(
      sosId: 'incident-1',
      text: 'Photo',
      messageId: 'media-1',
      messageType: 'media',
      attachmentPath: file.file.path,
      attachmentMimeType: 'image/png',
      attachmentName: 'Photo',
    );
    s.network.dropTypes.add('chat.media.chunk.v1');
    final c = await s.c.identity();
    await s.a.coordinator.enqueueChatThroughRelay(
      chat: chat,
      recipientKeyId: c.keyId,
      recipientPublicKey: base64UrlEncode(c.publicKey),
    );
    await s.network.until(
      () async => (await s.b.coordinator.mediaStore.find('media-1')) != null,
    );
    await s.network.pump();
    expect(await s.c.chat.loadMessages('incident-1'), isEmpty);
    expect(
      (await s.a.chat.loadMessages('incident-1')).single.status,
      isNot(ChatDeliveryStatus.delivered),
    );
    s.network.dropTypes.clear();
    for (var i = 0; i < 15; i++) {
      s.clock.advance(const Duration(seconds: 35));
      for (final n in [s.a, s.b, s.c]) {
        await n.coordinator.processDue();
      }
      await s.network.pump();
      if ((await s.a.chat.loadMessages('incident-1')).single.status ==
          ChatDeliveryStatus.delivered) {
        break;
      }
    }
    final received = await s.c.chat.loadMessages('incident-1');
    expect(
      received,
      hasLength(1),
      reason: s.c.logs.reversed.take(20).join('\n'),
    );
    expect(
      await File(received.single.attachmentPath!).readAsBytes(),
      await file.file.readAsBytes(),
    );
    expect(
      (await s.a.chat.loadMessages('incident-1')).single.status,
      ChatDeliveryStatus.delivered,
    );
    final transfers = s.network.captures.where(
      (c) => c.$3.type == ChatRelayTransfer.wireKind,
    );
    expect(
      transfers.map((c) => '${c.$1}->${c.$2}'),
      containsAll(['A->B', 'B->C']),
    );
  });
}
