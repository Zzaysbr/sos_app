# Emergency (`sos_app`)

Flutter app สำหรับ local-first SOS, nearby BLE, incident Chat และแผนที่

อ่าน [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) ก่อนวิเคราะห์หรือแก้โปรเจกต์: มี architecture, requirements, implementation status, known issues, tests, physical-test procedure และ build/release gates

เอกสารเชิงลึกและหลักฐานที่ยังจำเป็นอยู่ใน Documentation Organization (§17) ผล automated tests ไม่ใช่การยืนยัน physical BLE หรือ emergency-service readiness

## ขอบเขตชุดสาธิต

- สร้าง SOS ลงเครื่องก่อน พร้อมพิกัดเมื่ออ่านได้และได้รับความยินยอม
- รับและส่งต่อ SOS ผ่าน BLE พร้อม signed Help Offer
- Chat ไปกลับ พร้อม signed receipt หลังผู้รับเก็บข้อความสำเร็จ
- ยกเลิกเหตุจากต้นทาง เก็บประวัติ และหยุดติดตามเฉพาะเครื่อง

มีผลทดสอบ foreground/offline ของ iPhone–iPad–A53: เปลี่ยนจากทางตรงเป็นผ่านตัวกลางโดยใช้ SOS เดิม ส่งข้อความ/รูป/วิดีโอไปกลับ ตรวจ receipt ปลายทาง และปิดเหตุโดยคงประวัติ/สื่อไว้ ดู [ตาราง requirement และคู่มือเดโมล่าสุด](docs/DEMO_ACCEPTANCE.md) กับเหตุการณ์ตามลำดับใน PROJECT_CONTEXT.md การตัดลิงก์ด้วยปุ่มยังไม่ใช่การทดสอบระยะวิทยุจริง

## ตรวจซ้ำก่อนส่งงาน

```sh
flutter pub get
flutter test --no-pub --concurrency=1
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
flutter build ios --profile --build-number=25 --dart-define-from-file=config/production.json
python3 scripts/check_ios_standalone_build.py build/ios/iphoneos/Runner.app --build-number 25
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

รอบทดสอบ SOS/Chat/media ที่บันทึกวันที่11พฤศจิกายนผ่านตามขอบเขตใน PROJECT_CONTEXT.md: วิดีโอ A53→iPhone ตัวอย่างใหม่ประมาณ102KiB ใช้มากกว่า1ถึง3นาที; iPhone→A53ประมาณ48KiB ภายใน1นาที เป็นช่วงเวลาที่ผู้ทดสอบรายงาน ไม่ใช่ throughput guarantee รูปใหม่จำกัด24KiB; วิดีโอ H264/SDR360px/10fps จำกัด384KiB/15วินาที และเก็บเสียงตามนโยบายแต่ละแพลตฟอร์ม ไฟล์เก่ายังอ่านได้

Cloud เก็บ SOS/Chat metadata โดยไม่ใช้ Firebase Storage สำหรับ byte ของสื่อ การกู้ไฟล์หลัง Sync อาศัยไฟล์ที่ยังอยู่ใน private storage ของบัญชีนั้น ไม่ใช่การดาวน์โหลดไฟล์จาก cloud ลงเครื่องใหม่

แผนที่/พิกัดสองฝ่าย สีของผู้กู้ภัยบนเครื่องอื่น ล็อกจอ/เบื้องหลัง notification และระยะจริงยังต้องผ่านการตรวจรับบนรุ่นที่จะส่งงานตามคู่มือ แผนที่ offline ใช้ได้เฉพาะพื้นที่/zoom/provider ที่บันทึกไว้ล่วงหน้า โค้ดรองรับไม่ได้เท่ากับผลทดสอบเครื่องจริง

ผลและรายงานรุ่นเก่าใน artifacts/physical_e2e เป็นหลักฐานตามวันที่ของแต่ละรอบ ไม่ใช่สถานะติดตั้งล่าสุด E2EE, LoRa และการแจกจ่ายผ่าน Store ไม่อยู่ในหลักฐานการทดสอบชุดนี้
