# OFF_GRID_SOS Unit Test Evidence

วันที่จัดทำ: 30 ตุลาคม 2026 (Asia/Bangkok)

## 1. ขอบเขตและวิธีการ

- Repository: `off_grid_sos`
- Branch: `main`
- HEAD ขณะทดสอบ: `c6e0b5335b7d77eda9fe4a3fa769bddf629fe4e3`
- Working tree มีงานเดิมที่ยังไม่ commit และถูกเก็บรักษาไว้ทั้งหมด
- ทุกเคสด้านล่างเป็น automated test ที่มีอยู่จริงใน repository
- รันแต่ละเคสด้วย `flutter test ... --plain-name ... --reporter expanded`
- ไม่มีการแก้ assertion, skip test หรือสร้างผลลัพธ์จำลอง
- ไฟล์ที่เลือกไม่มี `group()` ครอบอยู่ ชื่อ Group จึงระบุเป็น `ไม่มี (top-level ใน main())`
- Terminal output ฉบับเต็มอยู่ใน `test_evidence/test_case_XX.log`

## 2. สรุปผล

| รายการ | จำนวน |
|---|---:|
| Test Case ที่รันแยก | 14 |
| PASS | 14 |
| FAIL | 0 |
| SKIP | 0 |
| Full-suite tests | 359 PASS |

ไฟล์ Test ต้นฉบับที่ใช้:

- `test/sos_repository_test.dart`
- `test/ble_delivery_repository_test.dart`
- `test/sos_ble_coordinator_test.dart`
- `test/location_sharing_test.dart`
- `test/local_device_history_test.dart`
- `test/hop_relay_coordinator_test.dart`

---

## Test Case 01: outbox messageId is idempotent and conflicting reuse is rejected

**Purpose:** ตรวจว่า message ID เดิม enqueue ซ้ำอย่าง idempotent และห้าม reuse ID เดิมกับ payload ที่ขัดแย้ง

**Test File:** `test/ble_delivery_repository_test.dart`

**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test(
  'outbox messageId is idempotent and conflicting reuse is rejected',
  () async {
    final first = await repository.enqueueOutbox(_delivery());
    final duplicate = await repository.enqueueOutbox(_delivery());

    expect(first.messageId, duplicate.messageId);
    expect(await database.select(database.bleOutbox).get(), hasLength(1));
    expect(
      () => repository.enqueueOutbox(_delivery(text: 'Different payload')),
      throwsA(isA<BleDeliveryStateException>()),
    );
  },
);
```

**Execution Command:**

```bash
flutter test test/ble_delivery_repository_test.dart --plain-name "outbox messageId is idempotent and conflicting reuse is rejected" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/ble_delivery_repository_test.dart
00:00 +0: outbox messageId is idempotent and conflicting reuse is rejected
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** เก็บ outbox เพียงหนึ่งแถวและ reject payload ที่ขัดแย้ง
**Actual Behavior:** assertions ผ่านครบและจบด้วย `All tests passed!`
**Evidence:** `test_evidence/test_case_01.log`

---

## Test Case 02: inbox duplicate delivery is inserted once

**Purpose:** ตรวจ duplicate suppression ของ BLE inbox

**Test File:** `test/ble_delivery_repository_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('inbox duplicate delivery is inserted once', () async {
  final first = await repository.insertInboxDelivery(_delivery());
  final duplicate = await repository.insertInboxDelivery(_delivery());

  expect(first.inserted, isTrue);
  expect(duplicate.inserted, isFalse);
  expect(await database.select(database.bleInbox).get(), hasLength(1));
});
```

**Execution Command:**

```bash
flutter test test/ble_delivery_repository_test.dart --plain-name "inbox duplicate delivery is inserted once" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/ble_delivery_repository_test.dart
00:00 +0: inbox duplicate delivery is inserted once
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** duplicate message ไม่สร้าง inbox แถวที่สอง
**Actual Behavior:** มี inbox หนึ่งแถวและ duplicate คืน `inserted=false`
**Evidence:** `test_evidence/test_case_02.log`

---

## Test Case 03: persists inbound SOS before sending positive ACK and deduplicates delivery

**Purpose:** ตรวจว่า SOS ถูก persist ก่อน ACK และการส่งซ้ำไม่สร้าง SOS ซ้ำ

**Test File:** `test/sos_ble_coordinator_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('persists inbound SOS before sending positive ACK and deduplicates delivery', () async {
  final delivery = SosBleEnvelope.fromSosMessage(
    _sos(),
    messageId: 'incoming-1',
    senderDeviceId: device.id,
  );
  final frames = BleMessageCodec.encode(delivery.toBleMessage());
  for (final frame in frames) {
    transport.emit(BleEvent(type: 'data', device: device, payload: frame));
  }
  await _settle();
  final sentAfterFirst = transport.sent.length;

  for (final frame in frames) {
    transport.emit(BleEvent(type: 'data', device: device, payload: frame));
  }
  await _settle();

  expect(await database.select(database.sosMessages).get(), hasLength(1));
  expect(await database.select(database.bleInbox).get(), hasLength(1));
  expect(transport.sent.length, greaterThanOrEqualTo(sentAfterFirst));
  final ackMessage = _decodeSent(transport.sent);
  expect(ackMessage.type, SosBleMessageKind.acknowledgement.wireValue);
});
```

**Execution Command:**

```bash
flutter test test/sos_ble_coordinator_test.dart --plain-name "persists inbound SOS before sending positive ACK and deduplicates delivery" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/sos_ble_coordinator_test.dart
00:00 +0: persists inbound SOS before sending positive ACK and deduplicates delivery
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** SOS/inbox มีอย่างละหนึ่งแถวและส่ง application ACK
**Actual Behavior:** persistence, deduplication และ ACK assertions ผ่าน
**Evidence:** `test_evidence/test_case_03.log`

---

## Test Case 04: enqueues chat, frames it, and delivers only after matching chat ACK

**Purpose:** ตรวจ Chat enqueue/framing และเปลี่ยนเป็น Delivered เฉพาะ matching ACK

**Test File:** `test/sos_ble_coordinator_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test(
  'enqueues chat, frames it, and delivers only after matching chat ACK',
  () async {
    final now = DateTime.utc(2026, 1, 1);
    await database
        .into(database.sosMessages)
        .insert(
          SosMessagesCompanion.insert(
            id: 'chat-sos',
            ownerId: 'owner-1',
            type: 'emergency',
            status: 'active',
            syncState: 'pending',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final chat = await chatRepository.insertMessage(
      sosId: 'chat-sos',
      messageId: 'chat-1',
      text: 'Need assistance',
    );
    final row = await coordinator.enqueueChat(chat, destinationId: device.id);
    await coordinator.processDue();
    expect(
      _decodeSent(transport.sent).type,
      SosBleMessageKind.chatMessage.wireValue,
    );
    expect(
      (await chatRepository.loadMessages('chat-sos')).single.status,
      ChatDeliveryStatus.sent,
    );

    final ack = SosBleEnvelope.chatAcknowledgement(
      messageId: 'ack:chat-1',
      sosId: 'chat-sos',
      ackFor: row.messageId,
      ackStatus: SosBleAckStatus.persisted,
      createdAt: now,
    );
    for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
      transport.emit(BleEvent(type: 'data', device: device, payload: frame));
    }
    await _settle();
    expect(
      (await chatRepository.loadMessages('chat-sos')).single.status,
      ChatDeliveryStatus.delivered,
    );
  },
);
```

**Execution Command:**

```bash
flutter test test/sos_ble_coordinator_test.dart --plain-name "enqueues chat, frames it, and delivers only after matching chat ACK" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/sos_ble_coordinator_test.dart
00:00 +0: enqueues chat, frames it, and delivers only after matching chat ACK
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** Chat อยู่ Sent หลัง native write และ Delivered หลัง matching ACK
**Actual Behavior:** state transition assertions ผ่าน
**Evidence:** `test_evidence/test_case_04.log`

---

## Test Case 05: chat ACK from the wrong peer does not deliver the message

**Purpose:** ตรวจ sender/transport peer identity ของ Chat ACK

**Test File:** `test/sos_ble_coordinator_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('chat ACK from the wrong peer does not deliver the message', () async {
  final now = DateTime.utc(2026, 1, 1);
  await database
      .into(database.sosMessages)
      .insert(
        SosMessagesCompanion.insert(
          id: 'chat-sos-wrong-peer',
          ownerId: 'owner-1',
          type: 'emergency',
          status: 'active',
          syncState: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );
  final chat = await chatRepository.insertMessage(
    sosId: 'chat-sos-wrong-peer',
    messageId: 'chat-wrong-peer',
    text: 'Still waiting',
  );
  final row = await coordinator.enqueueChat(chat, destinationId: device.id);
  await coordinator.processDue();
  final ack = SosBleEnvelope.chatAcknowledgement(
    messageId: 'ack:chat-wrong-peer',
    sosId: chat.sosId,
    ackFor: row.messageId,
    ackStatus: SosBleAckStatus.persisted,
    createdAt: now,
  );
  for (final frame in BleMessageCodec.encode(ack.toBleMessage())) {
    transport.emit(
      BleEvent(
        type: 'data',
        device: const BleDevice(id: 'other-peer'),
        payload: frame,
      ),
    );
  }
  await _settle();
  expect(
    (await chatRepository.loadMessages(chat.sosId)).single.status,
    ChatDeliveryStatus.sent,
  );
});
```

**Execution Command:**

```bash
flutter test test/sos_ble_coordinator_test.dart --plain-name "chat ACK from the wrong peer does not deliver the message" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/sos_ble_coordinator_test.dart
00:00 +0: chat ACK from the wrong peer does not deliver the message
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** wrong peer ACK ไม่เปลี่ยน Chat เป็น Delivered
**Actual Behavior:** Chat คงสถานะ Sent
**Evidence:** `test_evidence/test_case_05.log`

---

## Test Case 06: requires the explicit recipient and bounds queued updates

**Purpose:** ตรวจ Location Sharing ต้องมี recipient เดิมที่ชัดเจนและจำกัด queued update

**Test File:** `test/location_sharing_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('requires the explicit recipient and bounds queued updates', () async {
  final first = _update(messageId: 'location-old');
  final second = _update(messageId: 'location-new');
  final now = DateTime.utc(2026, 1, 1, 12);
  await repository.enqueueLocationOutbox(
    first,
    destinationId: 'peer-1',
    now: now,
  );
  await repository.enqueueLocationOutbox(
    second,
    destinationId: 'peer-1',
    now: now,
  );

  final rows = await database.select(database.bleOutbox).get();
  expect(rows.map((row) => row.messageId), ['location-new']);
  expect(
    () => repository.enqueueLocationOutbox(
      _update(messageId: 'location-wrong'),
      destinationId: 'peer-2',
    ),
    throwsA(isA<BleDeliveryStateException>()),
  );

  final claimed = await repository.claimOutboxForSending(
    'location-new',
    now: now,
  );
  await repository.transitionOutboxState(
    claimed!.messageId,
    BleOutboxState.failed,
    now: now,
    nextRetryAt: now.add(const Duration(minutes: 1)),
    error: 'temporary failure',
  );
  expect(
    (await repository.lookupOutbox('location-new'))!.destinationId,
    'peer-1',
  );
});
```

**Execution Command:**

```bash
flutter test test/location_sharing_test.dart --plain-name "requires the explicit recipient and bounds queued updates" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/location_sharing_test.dart
00:00 +0: requires the explicit recipient and bounds queued updates
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** เก็บเฉพาะ location ล่าสุดและ reject recipient ที่เปลี่ยน
**Actual Behavior:** เหลือ `location-new` และ destination คงเป็น `peer-1`
**Evidence:** `test_evidence/test_case_06.log`

---

## Test Case 07: duplicate inbound location delivery is idempotent

**Purpose:** ตรวจ duplicate Location update ไม่สร้างข้อมูลซ้ำหรือ SOS record

**Test File:** `test/location_sharing_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('duplicate inbound location delivery is idempotent', () async {
  final update = _update(messageId: 'location-duplicate');
  final first = await repository.persistIncomingLocation(
    update,
    expectedRecipientId: 'peer-1',
    now: DateTime.utc(2026, 1, 1, 12),
  );
  final second = await repository.persistIncomingLocation(
    update,
    expectedRecipientId: 'peer-1',
    now: DateTime.utc(2026, 1, 1, 12),
  );

  expect(first.inserted, isTrue);
  expect(second.inserted, isFalse);
  expect(await database.select(database.bleInbox).get(), hasLength(1));
  expect(await database.select(database.sosMessages).get(), isEmpty);
});
```

**Execution Command:**

```bash
flutter test test/location_sharing_test.dart --plain-name "duplicate inbound location delivery is idempotent" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/location_sharing_test.dart
00:00 +0: duplicate inbound location delivery is idempotent
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** duplicate location มี inbox เพียงหนึ่งแถว
**Actual Behavior:** duplicate คืน `inserted=false` และไม่สร้าง SOS
**Evidence:** `test_evidence/test_case_07.log`

---

## Test Case 08: wrong recipient and expired inbound updates are rejected

**Purpose:** ตรวจ wrong recipient rejection และ Location expiry validation

**Test File:** `test/location_sharing_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('wrong recipient and expired inbound updates are rejected', () async {
  expect(
    () => repository.persistIncomingLocation(
      _update(messageId: 'location-wrong-recipient'),
      expectedRecipientId: 'other-device',
      now: DateTime.utc(2026, 1, 1, 12),
    ),
    throwsA(isA<BleDeliveryStateException>()),
  );
  expect(
    () => repository.persistIncomingLocation(
      _update(
        messageId: 'location-expired-inbound',
        expiresAt: DateTime.utc(2026, 1, 1, 12, 1),
      ),
      expectedRecipientId: 'peer-1',
      now: DateTime.utc(2026, 1, 1, 12, 2),
    ),
    throwsA(isA<LocationBleEnvelopeException>()),
  );
});
```

**Execution Command:**

```bash
flutter test test/location_sharing_test.dart --plain-name "wrong recipient and expired inbound updates are rejected" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/location_sharing_test.dart
00:00 +0: wrong recipient and expired inbound updates are rejected
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** wrong recipient และ expired update ถูก reject
**Actual Behavior:** ได้ exception ตามชนิดที่กำหนดทั้งสองกรณี
**Evidence:** `test_evidence/test_case_08.log`

---

## Test Case 09: SOS ACK confirms only the message named by ackFor

**Purpose:** ตรวจ ACK correlation ด้วย message ID ไม่ยืนยัน SOS อื่น

**Test File:** `test/ble_delivery_repository_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('SOS ACK confirms only the message named by ackFor', () async {
  final now = DateTime.utc(2026, 1, 1, 12);
  await repository.enqueueOutbox(
    _delivery(messageId: 'sos-target', sosId: 'incident-target'),
    destinationId: 'selected-peer',
    now: now,
  );
  await repository.enqueueOutbox(
    _delivery(messageId: 'sos-other', sosId: 'incident-other'),
    destinationId: 'selected-peer',
    now: now,
  );
  await repository.claimOutboxForSending('sos-target', now: now);
  await repository.claimOutboxForSending('sos-other', now: now);

  await repository.recordAcknowledgement(
    SosBleEnvelope.acknowledgement(
      messageId: 'ack-other-only',
      sosId: 'incident-other',
      ackFor: 'sos-other',
      ackStatus: SosBleAckStatus.persisted,
      createdAt: now,
    ),
    sourceDeviceId: 'selected-peer',
    now: now,
  );

  expect(
    (await repository.lookupOutbox('sos-target'))!.state,
    BleOutboxState.sending.wireValue,
  );
  expect(
    (await repository.lookupOutbox('sos-other'))!.state,
    BleOutboxState.acknowledged.wireValue,
  );
});
```

**Execution Command:**

```bash
flutter test test/ble_delivery_repository_test.dart --plain-name "SOS ACK confirms only the message named by ackFor" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/ble_delivery_repository_test.dart
00:00 +0: SOS ACK confirms only the message named by ackFor
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** ยืนยันเฉพาะ `sos-other`; `sos-target` ยัง Sending
**Actual Behavior:** state ของทั้งสอง row ตรงตาม expected
**Evidence:** `test_evidence/test_case_09.log`

---

## Test Case 10: delayed wrong-peer ACK cannot confirm a failed attempt

**Purpose:** ตรวจ retry/delayed ACK จาก peer ที่ผิดต้องไม่ฟื้น failed attempt เป็น success

**Test File:** `test/ble_delivery_repository_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('delayed wrong-peer ACK cannot confirm a failed attempt', () async {
  await sending();
  await repository.transitionOutboxState('message-1', BleOutboxState.failed);
  await expectLater(
    repository.recordAcknowledgement(ack(), sourceDeviceId: 'other-peer'),
    throwsA(isA<BleDeliveryStateException>()),
  );
  expect((await repository.lookupOutbox('message-1'))!.state, 'failed');
});
```

**Execution Command:**

```bash
flutter test test/ble_delivery_repository_test.dart --plain-name "delayed wrong-peer ACK cannot confirm a failed attempt" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/ble_delivery_repository_test.dart
00:00 +0: delayed wrong-peer ACK cannot confirm a failed attempt
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** wrong-peer ACK ถูก reject และ row คง Failed
**Actual Behavior:** repository throw และ state ยังคง `failed`
**Evidence:** `test_evidence/test_case_10.log`

---

## Test Case 11: device history exposes Guest details and map without account actions

**Purpose:** ตรวจ Guest data isolation/visibility ใน Local Device History โดยไม่เปิด account actions

**Test File:** `test/local_device_history_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
testWidgets(
  'device history exposes Guest details and map without account actions',
  (tester) async {
    final repository = HistoryRepository();
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    when(() => repository.database).thenReturn(database);
    final sos = SosMessage(
      id: 'original-guest-id',
      ownerId: guestDeviceOwnerId,
      type: 'emergency',
      message: 'Guest record stays here',
      latitude: 13.7,
      longitude: 100.5,
      status: 'active',
      syncState: 'pending',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    when(() => repository.watchAll()).thenAnswer((_) => Stream.value([]));
    when(() => repository.watchDeviceHistory())
        .thenAnswer((_) => Stream.value([sos]));
    await tester.pumpWidget(
      MaterialApp(
        home: SosPage(
          repository: repository,
          isGuest: true,
          rolePreferenceStore: MemoryRolePreferenceStore(AppRole.needHelp),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ประวัติ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ข้อมูลในเครื่อง'));
    await tester.pumpAndSettle();
    expect(find.text('Guest record stays here'), findsOneWidget);
    expect(find.text('ข้อมูลในเครื่องเท่านั้น'), findsOneWidget);
    await tester.tap(find.text('Guest record stays here'));
    await tester.pumpAndSettle();
    expect(find.text('SOS Details'), findsOneWidget);
    expect(find.text('View on map'), findsOneWidget);
    expect(find.text('Mark as Resolved'), findsNothing);
    expect(find.text('Cancel SOS'), findsNothing);
    expect(find.text('Open incident chat'), findsNothing);
    expect(find.text('Pending sync'), findsNothing);
    expect(tester.takeException(), isNull);
  },
);
```

**Execution Command:**

```bash
flutter test test/local_device_history_test.dart --plain-name "device history exposes Guest details and map without account actions" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/local_device_history_test.dart
00:00 +0: device history exposes Guest details and map without account actions
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** Guest SOS เปิดจากข้อมูลในเครื่องได้ แต่ไม่มี account mutation actions
**Actual Behavior:** widget และ absence assertions ผ่านทั้งหมด
**Evidence:** `test_evidence/test_case_11.log`

---

## Test Case 12: A to B to C appends one hop and returns only hop receipts

**Purpose:** ตรวจ automated Model C store-and-forward A→B→C, hop metadata และ hop receipt semantics

**Test File:** `test/hop_relay_coordinator_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('A to B to C appends one hop and returns only hop receipts', () async {
  final clock = DateTime.utc(2026, 10, 26, 14);
  final transportA = _LinkedTransport('device-a');
  final transportB = _LinkedTransport('device-b');
  final transportC = _LinkedTransport('device-c');
  transportA.link(transportB);
  transportB.link(transportC);
  final nodeA = _RelayNode(
    database: AppDatabase.forTesting(NativeDatabase.memory()),
    transport: transportA,
    now: () => clock,
  );
  final nodeB = _RelayNode(
    database: AppDatabase.forTesting(NativeDatabase.memory()),
    transport: transportB,
    now: () => clock,
  );
  final nodeC = _RelayNode(
    database: AppDatabase.forTesting(NativeDatabase.memory()),
    transport: transportC,
    now: () => clock,
  );
  addTearDown(nodeA.close);
  addTearDown(nodeB.close);
  addTearDown(nodeC.close);

  await nodeA.coordinator.setParticipationEnabled(true);
  await nodeB.coordinator.setParticipationEnabled(true);
  await nodeC.coordinator.setParticipationEnabled(true);
  await nodeB.start();
  await nodeC.start();
  await nodeA.start();
  await nodeA.coordinator.queuePublicEmergency(
    _sos('incident-three-hop', clock),
    includeLocation: false,
  );

  await _eventually(() async {
    final messages = await nodeC.database
        .select(nodeC.database.bleRelayMessages)
        .get();
    final attempts = await nodeB.database
        .select(nodeB.database.bleRelayAttempts)
        .get();
    return messages.length == 1 &&
        attempts.length == 1 &&
        attempts.single.state == RelayAttemptState.acceptedByRelay.wireValue;
  });

  final atB = await nodeB.database
      .select(nodeB.database.bleRelayMessages)
      .getSingle();
  final atC = await nodeC.database
      .select(nodeC.database.bleRelayMessages)
      .getSingle();
  final offerAtB = await RelayRepository(database: nodeB.database)
      .loadVerifiedOffer(atB.originMessageId, now: clock);
  final offerAtC = await RelayRepository(database: nodeC.database)
      .loadVerifiedOffer(atC.originMessageId, now: clock);
  expect(offerAtB.hopCount, 0);
  expect(offerAtC.hopCount, 1);
  expect(offerAtC.pathKeyIds, hasLength(2));
  expect(offerAtC.hopAttestations, hasLength(1));
  expect(
    await nodeC.database.select(nodeC.database.sosMessages).get(),
    isEmpty,
  );
  expect(
    await nodeA.database.select(nodeA.database.bleRelayReceipts).get(),
    hasLength(1),
  );
  expect(
    await nodeB.database.select(nodeB.database.bleRelayReceipts).get(),
    hasLength(1),
  );
  expect(nodeA.errors, isEmpty);
  expect(nodeB.errors, isEmpty);
  expect(nodeC.errors, isEmpty);
});
```

**Execution Command:**

```bash
flutter test test/hop_relay_coordinator_test.dart --plain-name "A to B to C appends one hop and returns only hop receipts" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: A to B to C appends one hop and returns only hop receipts
This warning will only appear on debug builds.
00:00 +1: All tests passed!
```

หมายเหตุ: output เต็มมี Drift debug warning เรื่องการสร้าง in-memory database หลาย instance สำหรับ test topology; command ยัง exit `0` และ test ผ่าน ดู warning/stack trace เต็มในไฟล์ evidence

**Exit Code:** `0`
**Result:** PASS (AUTOMATED เท่านั้น ไม่ใช่ physical-device PASS)
**Expected Behavior:** C เก็บ Relay-only message หนึ่งรายการ, hop count เพิ่มหนึ่ง, A/B ได้ hop receipt และไม่สร้าง normal SOS ที่ C
**Actual Behavior:** assertions ทุกข้อผ่าน; physical A→B→C ยังต้องรายงานแยก
**Evidence:** `test_evidence/test_case_12.log`

---

## Test Case 13: create keeps local SOS and queue when cloud fails

**Purpose:** ตรวจ SOS creation/persistence เมื่อ cloud ใช้งานไม่ได้

**Test File:** `test/sos_repository_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test('create keeps local SOS and queue when cloud fails', () async {
  when(
    () => cloud.create(
      id: any(named: 'id'),
      ownerId: any(named: 'ownerId'),
      type: any(named: 'type'),
      message: any(named: 'message'),
      latitude: any(named: 'latitude'),
      longitude: any(named: 'longitude'),
      status: any(named: 'status'),
      createdAt: any(named: 'createdAt'),
      updatedAt: any(named: 'updatedAt'),
    ),
  ).thenThrow(Exception('offline'));

  await repository.create(id: 'sos-1', type: 'emergency', message: 'Help');

  final sos = await repository.findById('sos-1');
  final queue = await database.select(database.sosSyncQueue).get();

  expect(sos, isNotNull);
  expect(sos!.ownerId, 'test-user-1');
  expect(sos.syncState, 'pending');
  expect(queue, hasLength(1));
  expect(queue.single.operation, 'create');
});
```

**Execution Command:**

```bash
flutter test test/sos_repository_test.dart --plain-name "create keeps local SOS and queue when cloud fails" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/sos_repository_test.dart
00:00 +0: create keeps local SOS and queue when cloud fails
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** เก็บ SOS local พร้อม pending sync queue เมื่อ cloud fail
**Actual Behavior:** SOS และ create queue มีอยู่ตาม expected
**Evidence:** `test_evidence/test_case_13.log`

---

## Test Case 14: guest creates local SOS without attempting authenticated cloud sync

**Purpose:** ตรวจ Guest ownership และป้องกัน Guest SOS ถูกส่ง cloud อัตโนมัติ

**Test File:** `test/sos_repository_test.dart`
**Group:** ไม่มี (top-level ใน `main()`)

**Test Code:**

```dart
test(
  'guest creates local SOS without attempting authenticated cloud sync',
  () async {
    when(() => auth.currentUser).thenReturn(null);
    final guestRepository = SosRepository(
      database: database,
      cloudService: cloud,
      firebaseAuth: auth,
      localOwnerId: 'guest-local-device',
    );

    await guestRepository.create(id: 'guest-sos', type: 'emergency');

    final sos = await guestRepository.findById('guest-sos');
    expect(guestRepository.isGuest, isTrue);
    expect(sos?.ownerId, 'guest-local-device');
    verifyNever(
      () => cloud.create(
        id: any(named: 'id'),
        ownerId: any(named: 'ownerId'),
        type: any(named: 'type'),
        message: any(named: 'message'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        status: any(named: 'status'),
        createdAt: any(named: 'createdAt'),
        updatedAt: any(named: 'updatedAt'),
      ),
    );
  },
);
```

**Execution Command:**

```bash
flutter test test/sos_repository_test.dart --plain-name "guest creates local SOS without attempting authenticated cloud sync" --reporter expanded
```

**Actual Terminal Output:**

```text
00:00 +0: loading ./Users/n1cxltine/Desktop/Code/Project/sos_app/test/sos_repository_test.dart
00:00 +0: guest creates local SOS without attempting authenticated cloud sync
00:00 +1: All tests passed!
```

**Exit Code:** `0`
**Result:** PASS
**Expected Behavior:** Guest SOS ใช้ local owner และไม่เรียก cloud create
**Actual Behavior:** owner ถูกต้องและ `verifyNever(cloud.create)` ผ่าน
**Evidence:** `test_evidence/test_case_14.log`

---

## 3. Final Validation

### Full Flutter Test Suite

**Command:**

```bash
flutter test --reporter compact
```

**Actual Result:**

```text
00:12 +359: All tests passed!
```

- Exit Code: `0`
- PASS: `359`
- FAIL: `0`
- Evidence: `test_evidence/full_flutter_test.log`

### Flutter Analyze

**Command:**

```bash
flutter analyze lib test
```

**Actual Result:**

```text
Analyzing 2 items...
No issues found! (ran in 1.6s)
```

- Exit Code: `0`
- Evidence: `test_evidence/flutter_analyze.log`

### Git Diff Check

**Command:**

```bash
git diff --check
```

- Exit Code: `0`
- Findings: ไม่มี whitespace error
- Evidence: `test_evidence/git_diff_check.log`

## 4. ข้อสรุป

- Selected evidence cases: **14 PASS / 0 FAIL / 0 SKIP**
- Full suite: **359 PASS / 0 FAIL**
- Analyzer: **PASS**
- Diff check: **PASS**
- Test Case 12 เป็น automated relay topology เท่านั้น ไม่ใช่หลักฐาน physical BLE A→B→C
- งานนี้ไม่ได้ stage, commit, push, reset, clean หรือแก้ business logic
