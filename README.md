# Emergency (`sos_app`)

Flutter app สำหรับ local-first SOS, nearby BLE, incident Chat และแผนที่

อ่าน [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) ก่อนวิเคราะห์หรือแก้โปรเจกต์: มี architecture, requirements, implementation status, known issues, tests, physical-test procedure และ build/release gates

เอกสารเชิงลึกและหลักฐานที่ยังจำเป็นอยู่ใน Documentation Organization (§17) ผล automated tests ไม่ใช่การยืนยัน physical BLE หรือ emergency-service readiness

## ขอบเขตชุดสาธิต

- สร้าง SOS ลงเครื่องก่อน พร้อมพิกัดเมื่ออ่านได้และได้รับความยินยอม
- รับและส่งต่อ SOS ผ่าน BLE พร้อม signed Help Offer
- Chat ไปกลับ พร้อม signed receipt หลังผู้รับเก็บข้อความสำเร็จ
- ยกเลิกเหตุจากต้นทาง เก็บประวัติ และหยุดติดตามเฉพาะเครื่อง

มีหลักฐานเครื่องจริงของคู่ iPhone–Samsung และการส่งต่อแบบเก็บรอผ่าน Samsung ระหว่าง iPhone กับ iPad โดยสลับ Bluetooth ปลายทาง ดูขอบเขตและผลแต่ละรอบใน PROJECT_CONTEXT.md การทดสอบนี้ไม่ใช่การรับรองหลายทอดที่เชื่อมต่อพร้อมกันทุกเครื่องหรือความเสถียรระยะยาว

## ตรวจซ้ำก่อนส่งงาน

```sh
flutter pub get
flutter test --no-pub
flutter test --no-pub regression/stage2_remaining_contract_test.dart
dart analyze lib test regression
```

ทดสอบ Firestore rules หลังติดตั้ง dependencies ของ `security-tests` และมี Java/Firebase CLI พร้อม:

```sh
npm --prefix security-tests ci
python3 scripts/test_firestore_rules.py
```

คำสั่งหลังใช้ demo project และเลือกพอร์ต loopback ว่างแยกจากบริการอื่น ไม่ deploy rules ผลผ่านใน emulator ไม่ยืนยัน rules ที่ใช้งานจริงบน cloud

## สาธิตบนเครื่องจริง

สำหรับ iPhone/iPad ที่ต้องเปิดจากไอคอน Home ให้สร้าง **Profile** หรือ Release; Debug ใช้กับ Flutter tooling/Xcode และไม่ใช่ไฟล์สำหรับขั้นทดสอบนี้ ตัวอย่างใช้ไฟล์ตั้งค่าส่วนตัวที่ git ignore ไว้แล้ว (ห้ามเผยแพร่เนื้อหาหรือคีย์):

```sh
flutter build ios --profile --dart-define-from-file=config/production.json
python3 scripts/check_ios_standalone_build.py build/ios/iphoneos/Runner.app --build-number 6
```

ตัวตรวจยืนยัน bundle/build number, ไม่มี Debug kernel และลายเซ็นผ่านก่อนติดตั้ง แต่ยังไม่ใช่ผลยืนยันว่าเปิดบนเครื่องจริงได้ ให้ติดตั้งทับและตรวจประวัติ/การเปิดจากไอคอนทุกครั้ง

1. ใช้เหตุและข้อความทดสอบ เปิด Bluetooth และปิด Internet บนคู่ทดสอบ
2. ผู้ช่วยเลือก Rescue เปิดรับเหตุและ Nearby SOS Relay
3. ต้นทางส่ง SOS หนึ่งครั้ง ผู้ช่วยกด Offer Help หนึ่งครั้ง
4. ตรวจ verified offer/Offer delivery จากนั้นส่ง Chat ไปกลับ ตรวจข้อความฝั่งรับและสถานะยืนยันฝั่งส่ง
5. ทดสอบขาดการเชื่อมต่อโดยใช้ข้อความเดิม ไม่ส่งซ้ำ แล้วตรวจ receipt หลังกลับมาเชื่อมต่อ
6. ยกเลิกเหตุจากต้นทาง ตรวจรายการฝั่งผู้ช่วยและประวัติ แล้วคืนการตั้งค่าเครือข่ายตามปกติ

ใช้คำแนะนำหลายทอดและหลักฐานรหัสข้อความใน PROJECT_CONTEXT.md เมื่อต้องยืนยันว่าผ่านตัวกลางจริง การวางสามเครื่องใกล้กันแล้วเห็นข้อความยังไม่พิสูจน์เส้นทาง

## ผลตรวจส่งมอบและข้อจำกัด

**Mini-project closeout remains OPEN:** both phones now have one observed camera/gallery photo/video case in each direction with receiver count1/open-or-play and sender Confirmed stored. One Android camera-video case required an explicit Bluetooth reconnect; uninterrupted/repeated reliability and latency are not accepted. See [current acceptance matrix and limitations](artifacts/physical_e2e/20261109_media_acceptance/STATUS.md). Current iPhone14/Samsung13; iPad update/media checks remain pending. New media is automatically compressed (JPEG<=64KiB, H264 video<=512KiB/15seconds); native codec/opaque-file fixes are versioned in local plugin overrides. Offline maps passed one saved region per Samsung/iPhone in documented zoom/bounds.

ดู [รายงานส่งมอบ build 5](artifacts/physical_e2e/20261108_mini_project_closeout/HANDOVER.md) สำหรับผลที่ตรวจแล้วและข้อจำกัดแต่ละกรณี รวมถึงตำแหน่งหลังรีสตาร์ท, ล็อกจอแล้วกลับเข้าแอปทั้งสองฝั่ง, บัญชี → Guest → บัญชีเดิม, ภาษาไทย/อังกฤษ และแผนที่ออนไลน์ ผลที่ผู้ใช้รายงานแยกจากหลักฐานฐานข้อมูลและการตรวจลายเซ็นไว้ในรายงาน

GPS พบ Current location หลังรีสตาร์ทแล้ว แต่สาเหตุ timeout ก่อนหน้ายังไม่ทราบ ระยะพักแอปยาว, OS ปิดแอป และการแยกบัญชีคนละบัญชี/ข้อมูล cloud จริงยังไม่ได้รับรอง แผนที่ออฟไลน์รับรองเฉพาะพื้นที่และซูมที่บันทึกไว้ E2EE, LoRa และการแจกจ่ายผ่าน Store ไม่รวมอยู่ในชุดสาธิตข้างต้น ต้องเทียบกับข้อกำหนดรายวิชาก่อนตัดออกจากงานส่ง รูปและวิดีโอเป็นข้อกำหนดบังคับตามการยืนยันล่าสุด และยังต้องผ่านการทดสอบก่อนส่งมอบ
