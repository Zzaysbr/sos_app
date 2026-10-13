# SOS App — System Audit, Feature Inventory, Bugs, and Handoff Notes

วันที่จัดทำ: 13 ตุลาคม 2026  
ขอบเขต: ตรวจจาก source code, tests, configuration และ native BLE implementation ใน repository ปัจจุบัน  
จุดประสงค์: ใช้เป็นเอกสารส่งต่อ GPT/นักพัฒนา เพื่อเข้าใจระบบก่อนแก้หรือเพิ่มฟีเจอร์

> เอกสารนี้แยกข้อเท็จจริงจากโค้ดออกจากสิ่งที่ยังไม่ยืนยันเสมอ Build หรือ unit test ผ่านไม่ได้แปลว่า Android ↔ iPhone BLE ทำงานครบใน hardware จริง

---

## 1. สรุปภาพรวม

โปรเจกต์เป็น Flutter application สำหรับสร้างและติดตาม SOS แบบ local-first โดยมีสามเส้นทางข้อมูลแยกกัน:

1. SOS ในเครื่อง — หน้าหลักสร้าง SOS แล้วบันทึกลง Drift ก่อน
2. Cloud sync — รายการใน sos_sync_queue ถูกส่งไป Firestore เมื่อมี network หรือเมื่อแอปกลับมา foreground
3. Nearby BLE — SOS ที่สร้างแล้วถูกแปลงเป็น versioned envelope เก็บใน BLE outbox และ coordinator พยายามส่งผ่าน BLE พร้อมรอ ACK จากอุปกรณ์ปลายทาง

### มี implementation แล้ว

- Firebase email/password login, register, reset password และ logout
- Home, History, Settings และ Account Details
- สร้าง SOS แบบกดค้าง พร้อมขอ location และแสดงสถานะ local/cloud sync
- Drift schema version 3 พร้อมตาราง SOS, Firestore queue, BLE outbox และ BLE inbox
- Firestore CRUD สำหรับ collection sos และ security rules
- BLE framing ที่มี frame metadata, ลำดับชิ้นส่วน, CRC, timeout และ validation
- SosBleEnvelope schema version 1 สำหรับ sos.delivery และ sos.ack
- persistent BLE delivery state, duplicate suppression และ ACK correlation
- native GATT central/peripheral paths บน Android และ iOS รวมถึง peripheral TX notifications
- BLE Test (Debug) UI สำหรับ scan, advertise, connect, send raw test message และดู log

### ยังเป็นข้อจำกัดหรือยังไม่ยืนยัน

- ยังไม่มีหลักฐานจาก automated test ว่า iPhone ↔ Android ส่ง SOS envelope และ ACK ครบ end-to-end บน hardware จริง
- BLE coordinator เป็น foreground/best-effort; ไม่มี background worker หรือการรับประกันเมื่อ process ถูก terminate
- BLE Test UI ส่ง BleMessage(type: test) แบบ raw ไม่ได้จำลอง production SOS workflow
- senderDeviceId เป็น metadata ที่ผู้ส่งระบุได้ ไม่ใช่ตัวตน authenticated
- production coordinator และ BLE Test page สร้าง/ใช้ transport ผ่าน channel เดียวกัน หากเปิดพร้อมกันอาจเกิด lifecycle หรือ event-sink contention
- Android/iOS permissions, MTU, OS background restrictions และ reconnect ยังต้องยืนยันบนอุปกรณ์จริง

---

## 2. โครงสร้างโปรเจกต์

~~~text
lib/
  main.dart
  firebase_options.dart
  core/database/
    app_database.dart
    app_database.g.dart
    tables/sos_messages.dart
    tables/sos_sync_queue.dart
    tables/ble_outbox.dart
    tables/ble_inbox.dart
  features/auth/
    data/auth_service.dart
    presentation/auth_page.dart
  features/sos/
    data/sos_repository.dart
    data/sos_cloud_service.dart
    data/sos_sync_coordinator.dart
    presentation/sos_page.dart
    presentation/account_page.dart
  features/nearby_ble/
    data/ble_protocol.dart
    data/ble_transport.dart
    data/ble_delivery_repository.dart
    data/sos_ble_coordinator.dart
    domain/ble_models.dart
    domain/ble_delivery_state.dart
    domain/sos_ble_envelope.dart
    presentation/ble_test_page.dart
android/app/src/main/kotlin/.../BleTransportBridge.kt
ios/Runner/BleTransport.swift
test/
security-tests/
packages/flutter_nearby_connections_plus/
~~~

packages/flutter_nearby_connections_plus ยังอยู่ใน dependency override ใน pubspec.yaml แต่ native transport ที่ระบบ SOS ใช้จริงเป็น BleTransportBridge/BleTransport ของโปรเจกต์นี้ ไม่ควรสลับ fallback ไป package เก่าโดยอัตโนมัติ

---

## 3. Bootstrap, authentication และ lifecycle

### 3.1 จุดเริ่มต้น

lib/main.dart:14-25 เรียก WidgetsFlutterBinding.ensureInitialized(), Firebase.initializeApp, สร้าง AppDatabase แล้วรัน SosApp.

SosApp (lib/main.dart:27-46) ตั้ง Material theme สีแดงและใช้ AuthGate เป็นหน้าเริ่มต้น ไม่มี router package แยก; navigation ส่วนใหญ่ใช้ MaterialPageRoute.

### 3.2 AuthGate dependency graph

AuthGate (lib/main.dart:63-164) ฟัง FirebaseAuth.authStateChanges():

- loading: progress
- stream error: error view
- ไม่มี user: dispose cloud/BLE resources แล้วแสดง AuthPage
- มี user: สร้าง SosBleCoordinator, SosRepository และ SosSyncCoordinator แล้วแสดง SosPage

~~~text
FirebaseAuth user
       |
       +--> SosBleCoordinator(database, ownerId)
       |       +--> BleTransport
       |       +--> BleDeliveryRepository
       |
       +--> SosRepository(database, cloudService,
       |                  onSosCreated: bleCoordinator.enqueueSos)
       |       +--> SosCloudService
       |
       +--> SosSyncCoordinator(repository)
~~~

_ensureSyncResources() เรียก start() แบบ unawaited และ _disposeSyncResources() dispose แบบ async โดยไม่รอจาก builder (lib/main.dart:69-123). Classes มี start/stop/dispose guards แต่ยังมี race ที่ควรทดสอบเมื่อ auth เปลี่ยนเร็วหรือมี hot restart:

- start เก่ากับ dispose ใหม่อาจคาบเกี่ยว
- error จาก start/dispose ถูก debug-print มากกว่าจะเป็น UI state
- AppDatabase ที่สร้างใน main() ไม่มีการปิดอย่างชัดเจนเมื่อ process ปิด

### 3.3 Auth

lib/features/auth/data/auth_service.dart ใช้ Firebase Auth:

- register: normalize email, ตรวจ email แบบเบื้องต้น, password อย่างน้อย 6 ตัวอักษร
- login: ตรวจ input แล้ว sign in
- resetPassword: ส่ง reset email
- logout: sign out
- map Firebase error code เป็น AuthException

auth_page.dart มี login/register toggle, password visibility, forgot password, loading guard และ mounted checks.

account_page.dart แสดง email, Firebase UID และ email verification status พร้อม reset password, verification email และ sign out.

ข้อจำกัดด้านบัญชี:

- password policy แค่ขั้นต่ำ 6 ตัวอักษร
- email validation เพียงตรวจว่ามี @
- ไม่มี email verification gate, MFA, provider linking หรือ account deletion
- Firebase identity ไม่ใช่ BLE peer identity

---

## 4. SOS UI และ workflow

### 4.1 Home และการสร้าง SOS

lib/features/sos/presentation/sos_page.dart มี bottom navigation 3 แท็บ: Home, History, Settings.

ปุ่มแดงต้องกดค้างประมาณ 1.4 วินาที (_sosHoldDuration, ช่วง sos_page.dart:212-313) จึงเรียก _sendSos(); ปล่อยก่อนเวลาจะ cancel.

_sendSos() (sos_page.dart:1474-1529):

1. guard _sendingSos
2. สร้าง id จาก DateTime.now().microsecondsSinceEpoch.toString()
3. ตรวจ location service/permission
4. อ่านตำแหน่งด้วย Geolocator timeout 10 วินาที
5. เรียก SosRepository.create() ด้วย type emergency, message Emergency SOS, coordinate ที่ได้หรือ null
6. แสดง snackbar

หา location ไม่ได้ไม่ได้หยุดการสร้าง record เสมอไป; SOS สามารถถูกบันทึกโดยไม่มี coordinate.

### 4.2 History และ Settings

History ฟัง repository.watchAll() จาก Drift, เรียงใหม่สุดก่อน และมี total/active/resolved/cancelled, filters, detail sheet, edit, resolve, cancel และ delete.

SosRepository.update() อนุญาต status active, resolved, cancelled. Settings อยู่ช่วง sos_page.dart:1049-1120 มี account card, notifications (placeholder), location settings และปุ่ม BLE Test (Debug) ที่ sos_page.dart:1086-1092.

ข้อความ “SOS sent” ใน UI หมายถึงสร้าง local record และเริ่ม queue ไม่ใช่หลักฐานว่า cloud หรือ peer BLE รับแล้ว

---

## 5. Local database (Drift)

### 5.1 Schema และ migration

lib/core/database/app_database.dart ใช้ Drift และประกาศ SosMessages, SosSyncQueue, BleOutbox, BleInbox. schema version ปัจจุบันคือ 3:

- จาก version <2: สร้าง sosSyncQueue
- จาก version <3: สร้าง bleOutbox และ bleInbox

generated code อยู่ที่ app_database.g.dart; ไม่ควรแก้ตรง ให้แก้ table/database แล้วรัน generation.

### 5.2 SOS tables

SosMessages: primary key id, ownerId, type, nullable message/latitude/longitude, status, syncState, createdAt, updatedAt.

SosSyncQueue: queueId auto-increment, sosId, ownerId, operation, optional serialized payload และ createdAt.

### 5.3 BLE tables

BleOutbox (lib/core/database/tables/ble_outbox.dart):

- messageId primary key/idempotency key
- sosId, optional destinationId
- schemaVersion, serialized payload
- state, retryCount, nextRetryAt, lastAttemptAt, lastError
- created/updated/acknowledged timestamps

BleInbox (lib/core/database/tables/ble_inbox.dart):

- messageId primary keyเพื่อ deduplication
- sosId, untrusted senderDeviceId
- schemaVersion, validated payload
- processingState, receivedAt, persistedAt
- acknowledgementStatus

Cloud queue แยกจาก BLE queue และไม่ควรนำมาใช้แทนกัน.

---

## 6. SOS Repository และ Firestore

### 6.1 Local-first create

SosRepository.create() (sos_repository.dart:52-124) ทำ transaction insert SOS active/pending และ enqueue Firestore create ก่อน. หลัง transaction:

1. โหลด row กลับ
2. เรียก _onSosCreated(created) เพื่อ BLE enqueue
3. ถ้า BLE queueing fail จะ debug-print แต่ไม่ rollback local SOS
4. เรียก syncPending() ถ้า account ยังเป็น owner เดิม

ดังนั้น BLE failure ไม่ควรทำให้ SOS local หาย.

### 6.2 Cloud sync

SosCloudService ใช้ Firestore collection sos:

- exists(id)
- create ด้วย doc(id).set
- update
- delete

SosSyncCoordinator ฟัง auth/connectivity, sync เมื่อ network กลับมาและ app resumed, serialize sync ด้วย _syncFuture/_syncRequested. SosRepository.syncPending() ประมวลผล queue ตามลำดับ ลบ item เมื่อสำเร็จ และตั้ง syncState=synced เมื่อไม่มี queue เหลือ.

Failure จะเก็บ queue เพื่อ retry รอบต่อไป แต่ไม่มี per-item error UI ที่ละเอียด.

### 6.3 Security rules

Rules อยู่ที่ security-tests/firestore.rules; tests อยู่ที่ security-tests/firestore.rules.test.js. ครอบคลุม owner read/update/delete, unauthenticated denial, forged owner create denial และ filtered query. firebase.json ชี้ rules ไปไฟล์นี้ ไม่ใช่ root firestore.rules.

---

## 7. BLE protocol และ envelope

### 7.1 Frame protocol

lib/features/nearby_ble/data/ble_protocol.dart:

- protocol version 1
- JSON envelope มี version/id/type/createdAt/payload/checksum
- UTF-8
- header 14 bytes มี version/flags/message token/frame index/frame count
- default frame size ประมาณ 180 bytes
- max logical message 64 KiB
- CRC32

BleMessageAssembler แยก partial messages ตาม token, รับ out-of-order, ตรวจ index/count, suppress duplicate ที่เหมือนกัน, reject conflicting duplicate, timeout ประมาณ 10 วินาที และไม่คืน partial message.

ความเสี่ยง: 180 bytes เป็น protocol layer ไม่ใช่หลักฐานว่า MTU/characteristic ของทุกรุ่นรองรับ ต้องยืนยัน negotiated MTU และ write/notify callback บนอุปกรณ์จริง.

### 7.2 SOS envelope v1

lib/features/nearby_ble/domain/sos_ble_envelope.dart:

- sos.delivery และ sos.ack
- sosId: stable SOS record/event
- messageId: stable logical transport message; retry ใช้เดิม
- senderDeviceId: informational/untrusted
- max envelope payload 16 KiB
- validate version, required strings, timestamps, status และ coordinates
- status: active/resolved/cancelled
- ACK: ackFor, ackStatus (persisted/rejected), optional error

GATT write success หรือ send() return ไม่ใช่ remote persistence ACK. ACK ถูกสร้างหลัง receiver validate และ persist local record สำเร็จ.

---

## 8. Persistent BLE state และ coordinator

### 8.1 States

ble_delivery_state.dart มี outbox states: queued, sending, writeAccepted, awaitingAcknowledgement, acknowledged, failed, expired.

Inbox states: received, persisted, rejected. ACK status: persisted, rejected.

ble_delivery_repository.dart ใช้ primary key/transaction เพื่อ enqueue แบบ idempotent, due selection, legal transition, stale recovery, inbox dedup และ ACK recording.

### 8.2 Coordinator flow

sos_ble_coordinator.dart เป็น foreground coordinator:

~~~text
SosRepository.create
  -> enqueueSos
  -> BleDeliveryRepository.enqueueOutbox
  -> processDue (poll ประมาณ 5 วินาที)
  -> connect หากยังไม่มี peer
  -> encode frames และ transport.send
  -> writeAccepted
  -> awaitingAcknowledgement
  -> รับ sos.ack
  -> recordAcknowledgement
  -> acknowledged
~~~

Receiver:

~~~text
frames -> assembler -> envelope validation
       -> persistIncomingDelivery (transaction + dedup)
       -> sos.ack persisted/rejected
~~~

role ของ session แยก central/peripheral; ถ้ามีทั้งสอง role coordinator เลือก central ก่อนสำหรับ outbound.

ข้อจำกัด:

- poll/retry ทำงาน foreground เท่านั้น
- ไม่มี background/terminated worker
- peer ว่างจะเลือก connected peer แรก
- rejected ACK ปัจจุบันทำให้ failed และไม่มี next retry; ต้องกำหนด policy ว่าควร retry หรือเป็น permanent rejection
- source peer metadata ยังไม่ใช่ cryptographic identity

---

## 9. Dart transport และ BLE Test UI

ble_transport.dart ใช้ channels เดิม:

- MethodChannel: sos_ble_transport/methods
- EventChannel: sos_ble_transport/events

API มี initialize, requestPermissions, start/stop discovery, start/stop advertising, connect, disconnect, send และ dispose. มี role central/peripheral, active-call tracking และ disposed guards.

ble_test_page.dart มี request permissions, scan/stop, advertise/stop, device list (id/name/RSSI), connect/disconnect, input/send, received messages, diagnostic log, clear log และ connect timeout ประมาณ 15 วินาที.

หน้าทดสอบส่ง raw BleMessage(type: test); จึงตรวจ transport/framing ได้ แต่ไม่ใช่ production SOS persistence/ACK test.

**ความเสี่ยงสำคัญ:** AuthGate สร้าง production coordinator transport อยู่แล้ว แต่ BLE Test page สร้าง transport อีกตัวผ่าน channel เดิม. ถ้า native event channel มี sink ได้ชุดเดียว อาจแย่ง event หรือ dispose กันเอง. ควร share transport instance หรือห้ามเปิด debug page ขณะ coordinator ทำงาน.

---

## 10. Native BLE

### 10.1 UUID

| สิ่งที่ | UUID |
|---|---|
| Service | 8B7F0001-6D3A-4C8B-9D21-5A7F2E110001 |
| RX | 8B7F0002-6D3A-4C8B-9D21-5A7F2E110001 |
| TX | 8B7F0003-6D3A-4C8B-9D21-5A7F2E110001 |
| CCCD | 00002902-0000-1000-8000-00805f9b34fb |

### 10.2 Android

android/app/src/main/kotlin/com/example/sos_app/BleTransportBridge.kt มี:

- scanner/advertiser และ permission/state checks
- GATT server RX write/write-no-response และ TX notify/read + CCCD
- central BluetoothGatt map และ ready clients
- peripheral client/subscription maps
- peripheral send ผ่าน BluetoothGattServer.notifyCharacteristicChanged, มี bounded queue และ onNotificationSent
- central receive ผ่าน onCharacteristicChanged
- server write callback รับ RX และตอบ request ตาม support
- peripheral connected event หลัง CCCD TX subscribe
- main-thread-safe EventChannel dispatch
- cleanup ของ scans, advertising, GATT และ pending operations

Manifest (android/app/src/main/AndroidManifest.xml:3-9) มี legacy Bluetooth/location และ Android 12+ BLUETOOTH_SCAN, BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE.

ยังต้องยืนยัน status 19, vendor disconnect, MTU และ multi-client behavior ด้วย logs/hardware.

### 10.3 iOS

ios/Runner/BleTransport.swift มี:

- CBCentralManager และ CBPeripheralManager บน main queue
- central scan/connect/discover/subscribe/write
- peripheral service/RX/TX/advertising
- didReceiveWrite รับและตอบ ATT request
- subscribedCentrals และ bounded notification queue
- updateValue พร้อม backpressure/flush ใน peripheralManagerIsReady
- peripheral connected หลัง TX subscribe
- dispose stop scan/advertise/cancel central connections

Info.plist มี Bluetooth/location usage descriptions แต่มี duplicate NSLocalNetworkUsageDescription และ NSBonjourServices ที่ควร cleanup.

### 10.4 Connected ที่เชื่อถือได้

central ต้องผ่าน service/characteristic discovery และ notification setup; peripheral ต้องมี CCCD subscription ก่อน TX notification พร้อม. Link-connected อย่างเดียวไม่ควรแสดง Connected ใน production state.

---

## 11. Permissions และ prerequisites

Android 12+ ต้องอนุญาต Nearby devices. บางรุ่นยังต้องเปิด Location Services สำหรับ scan. ต้องตรวจ adapter enabled, scanner/advertiser non-null และ permissions ก่อน operation.

iOS ต้องมี Bluetooth usage description; location ใช้แนบ coordinate SOS. iOS จำกัด background BLE และอาจ suspend app.

การทดสอบจริงต้องใช้ physical phones, Bluetooth เปิด, permissions granted, foreground app และกำหนดหนึ่งเครื่องเป็น advertise/peripheral อีกเครื่องเป็น scan/central.

---

## 12. Tests และผลล่าสุด

Tests ที่มี:

- test/ble_protocol_test.dart — frames, out-of-order, duplicates, missing/invalid, UTF-8
- test/ble_transport_test.dart — transport event/method/dispose paths
- test/ble_test_page_test.dart — debug UI
- test/sos_ble_envelope_test.dart — round-trip/validation/size/IDs
- test/ble_delivery_repository_test.dart — uniqueness/transitions/ACK/due rows
- test/sos_ble_coordinator_test.dart — send/receive/ACK/retry/lifecycle
- test/sos_repository_test.dart — local SOS/cloud queue
- security-tests/firestore.rules.test.js — Firestore emulator rules

ผลล่าสุดที่มีบันทึกจากรอบ implementation BLE:

- flutter test: ผ่านทั้งหมด 44 tests
- targeted coordinator/repository: ผ่าน 17 tests
- flutter analyze: 32 info-level issues เดิมใน packages/flutter_nearby_connections_plus; ไม่พบ error ใหม่จาก production BLE ที่แก้รอบนั้น
- flutter build apk --debug: ผ่าน
- flutter build ios --debug --no-codesign: ผ่าน
- git diff --check: ผ่าน

ผลเหล่านี้ไม่ใช่ hardware BLE acceptance.

---

## 13. Feature matrix

| พื้นที่ | สถานะ | หลักฐาน/หมายเหตุ |
|---|---|---|
| Firebase initialization | ทำแล้ว | lib/main.dart |
| Email/password auth | ทำแล้ว | auth_service.dart, auth_page.dart |
| Reset password | ทำแล้ว | Firebase reset email |
| Account details | ทำแล้ว | account_page.dart |
| Local SOS create | ทำแล้ว | Drift transaction |
| Location capture | ทำแล้วแบบ best-effort | null location allowed |
| History/filter/detail | ทำแล้ว | sos_page.dart |
| Resolve/cancel/edit/delete | ทำแล้ว | repository + UI |
| Firestore SOS CRUD | ทำแล้ว | SosCloudService |
| Offline cloud queue | ทำแล้ว | SosSyncQueue |
| BLE frame protocol | ทำแล้ว/tested | metadata, CRC, assembler |
| SOS BLE envelope v1 | ทำแล้ว/tested | delivery + ACK |
| BLE outbox/inbox | ทำแล้ว/tested | schema v3 |
| Foreground BLE coordinator | ทำแล้วบางส่วน | poll/retry/ACK |
| Android central/peripheral | implementation present | hardware unverified |
| iOS central/peripheral | implementation present | hardware unverified |
| BLE debug UI | ทำแล้ว | raw test messages |
| Production SOS → BLE enqueue | ทำแล้ว | repository callback |
| Remote persistence ACK | implementation present | end-to-end unverified |
| Background/terminated delivery | ยังขาด | ไม่มี worker |
| BLE peer authentication | ยังขาด | sender ID untrusted |
| Push notifications | ยังขาด | settings placeholder |
| Delivery status UI | ยังขาด | ไม่มี outbox/inbox dashboard |

---

## 14. Bugs, risks และ technical debt

### สูง

1. **ยังไม่มี hardware evidence ของ SOS ACK end-to-end** — source มี paths แต่ต้องพิสูจน์ discovery, CCCD, frame IDs, inbox persistence และ ACK state จริง
2. **Foreground-only delivery** — app suspend/terminate แล้วไม่มี worker รับ/retry ต่อ
3. **Transport ownership ซ้ำ** — production coordinator กับ BLE Test page อาจแย่ง channel/event sink
4. **BLE identity ไม่ authenticated** — peer อาจส่ง envelope/ACK ปลอมได้

### กลาง

5. **Peer selection เมื่อ destination ว่าง** เลือก peer แรก อาจผิดคนเมื่อมีหลายอุปกรณ์
6. **ACK rejection policy** ไม่มี retry ต่อ ต้องตัดสินใจ product policy
7. **MTU/fragmentation assumptions** ต้องทดสอบ frame 180 bytes กับ negotiated MTU จริง
8. **Auth resource race** start/dispose แบบ unawaited ใน AuthGate
9. **Cloud sync errors ไม่แสดงละเอียด** queue คงอยู่แต่ผู้ใช้ไม่เห็น per-item error
10. **SOS id ใช้ wall-clock** ควรพิจารณา UUID/ULID เพื่อ uniqueness ที่แข็งแรง
11. **Info.plist duplicate keys** ทำให้ behavior และ maintenance ไม่ชัด

### ต่ำ/UX

12. BLE Test copy อาจล้าสมัยเมื่อ coordinator production มี ACK แล้ว
13. Notifications setting เป็น placeholder
14. analyzer info lints ใน local dependency ยังมี 32 รายการ

---

## 15. สิ่งที่ยัง Unverified

ต้องมี device logs หรือ hardware test เพื่อยืนยัน:

- iPhone scan พบ Android advertiser
- Android advertiser callback สำเร็จบนรุ่นเป้าหมาย
- GATT service/RX/TX discovery ครบสองทิศ
- CCCD write ทำให้ peripheral notification-ready
- payload ใกล้ MTU ถูกแบ่งและประกอบครบ
- receiver persist ก่อนส่ง sos.ack persisted
- sender acknowledged เฉพาะ ACK ที่ messageId/sosId/source ตรง
- duplicate delivery ไม่สร้าง SOS row ซ้ำ
- disconnect/reconnect ใช้ messageId เดิม
- behavior หลัง app restart/background

---

## 16. แผนทดสอบจริง

### Transport smoke test

1. เปิดแอปทั้งสองเครื่อง foreground
2. Settings → BLE Test (Debug)
3. เครื่อง A request permissions + Start Advertising
4. เครื่อง B request permissions + Start Scan
5. Connect discovered stable id
6. ตรวจ event: connecting → discovering service → characteristics → notification setup → connected
7. ส่ง raw test A → B และ B → A
8. เก็บ timestamp, role, peer id, callback status โดยไม่เก็บ payload/location

### Production SOS

1. หลีกเลี่ยง BLE Test page เพื่อไม่ชน coordinator
2. สร้าง controlled SOS จาก Home
3. ตรวจ sosId, outbox messageId, destination
4. ตรวจ receiver inbox/local SOS ก่อน ACK
5. ตรวจ sender acknowledged หลัง sos.ack persisted เท่านั้น

### Failure/retry

- ส่ง envelope/message เดิมซ้ำและตรวจ inbox uniqueness
- ตัด connection ระหว่าง frames แล้ว reconnect
- restart app ขณะ outbox awaiting ACK แล้วตรวจ messageId เดิม
- ส่ง malformed JSON/CRC/index แล้วตรวจไม่มี positive ACK/SOS row
- ทดสอบหลาย peer

---

## 17. ลำดับงานแนะนำ

### ระยะ A: lifecycle

1. กำหนด transport owner เดียวต่อ engine
2. share client หรือ block debug page ระหว่าง production coordinator
3. เพิ่ม auth churn/hot restart tests
4. กำหนด stop/resume policy ชัดเจน

### ระยะ B: hardware proof

1. smoke test สองทิศ
2. payload/MTU matrix
3. notification backpressure/reconnect
4. inbox-before-ACK และ outbox-after-ACK evidence

### ระยะ C: production hardening

1. authenticated peer/session key และ message MAC/signature
2. delivery status UI แยกจาก cloud sync
3. background strategy ตาม OS constraints
4. inbox/outbox retention/cleanup
5. UUID/ULID สำหรับ SOS IDs หากต้องการ production-grade uniqueness
6. privacy-safe observability

---

## 18. Prompt พร้อมใช้สำหรับส่งต่อ GPT

~~~text
โปรเจกต์คือ Flutter sos_app สำหรับ local-first SOS.

ข้อเท็จจริง:
- AuthGate ใน lib/main.dart สร้าง SosRepository, SosSyncCoordinator และ SosBleCoordinator เมื่อมี user.
- SosRepository.create() บันทึก SosMessages + SosSyncQueue ก่อน แล้วเรียก onSosCreated เพื่อ enqueue BLE; BLE failure ห้าม rollback SOS local.
- Firestore queue แยกจาก BLE outbox/inbox.
- Drift schema version 3 มี SosMessages, SosSyncQueue, BleOutbox, BleInbox.
- BLE channels เดิมคือ sos_ble_transport/methods และ sos_ble_transport/events.
- UUID ห้ามเปลี่ยน:
  Service 8B7F0001-6D3A-4C8B-9D21-5A7F2E110001
  RX 8B7F0002-6D3A-4C8B-9D21-5A7F2E110001
  TX 8B7F0003-6D3A-4C8B-9D21-5A7F2E110001
  CCCD 00002902-0000-1000-8000-00805f9b34fb
- BleProtocol มี explicit frame metadata, CRC, out-of-order assembler และ timeout.
- SosBleEnvelope schema v1 มี sos.delivery และ sos.ack; messageId ต้องคงเดิมระหว่าง retry; senderDeviceId ยังไม่ authenticated.
- SosBleCoordinator เป็น foreground/best-effort; outbox states แยก writeAccepted/awaitingAcknowledgement/acknowledged.
- Android/iOS native มี central/peripheral paths และ peripheral TX notification implementation แต่ hardware end-to-end ยังต้องพิสูจน์.
- BLE Test (Debug) ส่ง raw test BleMessage ไม่ใช่ production SOS flow.

ข้อห้าม:
- อย่าเปลี่ยน UUID, channel, framing, CRC หรือ envelope โดยไม่มีหลักฐาน.
- อย่าถือ GATT write success เป็น remote persistence ACK.
- อย่าลบ/rollback outbox เมื่อ transport fail.
- อย่าอ้าง hardware BLE หรือ background delivery สำเร็จโดยไม่มี logs จริง.
- แยก cloud sync status ออกจาก BLE delivery status.

ก่อนแก้ให้อ่าน PROJECT_SYSTEM_AUDIT.md และ source ที่อ้างถึง ตรวจ tests/build ที่เกี่ยวข้อง และรายงาน root cause กับหลักฐานจริง.
~~~

---

## 19. File index

ลำดับอ่าน source:

1. lib/main.dart
2. lib/features/sos/presentation/sos_page.dart
3. lib/features/sos/data/sos_repository.dart
4. lib/features/sos/data/sos_sync_coordinator.dart และ sos_cloud_service.dart
5. lib/core/database/app_database.dart และ lib/core/database/tables/*
6. lib/features/nearby_ble/data/ble_protocol.dart
7. lib/features/nearby_ble/domain/sos_ble_envelope.dart
8. lib/features/nearby_ble/data/ble_delivery_repository.dart
9. lib/features/nearby_ble/data/sos_ble_coordinator.dart
10. lib/features/nearby_ble/data/ble_transport.dart
11. lib/features/nearby_ble/presentation/ble_test_page.dart
12. android/.../BleTransportBridge.kt
13. ios/Runner/BleTransport.swift
14. tests ที่เกี่ยวข้องก่อนแก้ implementation

เอกสารนี้เป็น audit snapshot ของ working tree ปัจจุบัน ไม่ใช่ specification ที่แทน source code ได้ หาก source เปลี่ยน ต้องอัปเดตเอกสารและ line references ตามจริง.

