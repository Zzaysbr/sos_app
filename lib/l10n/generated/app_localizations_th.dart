// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'Off Grid SOS';

  @override
  String get authStatusUnavailable => 'ไม่สามารถตรวจสอบสถานะการเข้าสู่ระบบได้';

  @override
  String get navNearby => 'เหตุใกล้เคียง';

  @override
  String get navHelping => 'กำลังช่วย';

  @override
  String get navHelp => 'ขอความช่วยเหลือ';

  @override
  String get navHelpCompact => 'SOS';

  @override
  String get navHistory => 'ประวัติ';

  @override
  String get navChat => 'แชต';

  @override
  String get navSettings => 'ตั้งค่า';

  @override
  String get settingsTitle => 'ตั้งค่า';

  @override
  String get preferences => 'การตั้งค่า';

  @override
  String get language => 'ภาษา';

  @override
  String get languageDescription => 'เลือกภาษาที่ใช้แสดงผลในแอป';

  @override
  String get languageEnglish => 'English (อังกฤษ)';

  @override
  String get languageThai => 'ไทย';

  @override
  String get languageSaveFailed => 'บันทึกภาษาไม่ได้ แอปยังใช้ภาษาเดิม';

  @override
  String get usageMode => 'โหมดการใช้งาน';

  @override
  String get modeRescueDescription => 'ผู้ช่วยเหลือ · แตะเพื่อเปลี่ยนโหมด';

  @override
  String get modeNeedHelpDescription => 'ผู้ประสบภัย · แตะเพื่อเปลี่ยนโหมด';

  @override
  String get notifications => 'การแจ้งเตือน';

  @override
  String get notificationsDescription => 'การอัปเดต SOS และการแจ้งเตือนในแอป';

  @override
  String get notificationsReady => 'การแจ้งเตือนพร้อมใช้งาน';

  @override
  String get notificationsReadyDetail => 'การอัปเดต SOS จะแสดงที่นี่';

  @override
  String get markAllRead => 'อ่านทั้งหมดแล้ว';

  @override
  String get noNotifications => 'ยังไม่มีการแจ้งเตือน';

  @override
  String get location => 'ตำแหน่ง';

  @override
  String get locationSettingsDescription => 'สิทธิ์และบริการตำแหน่ง';

  @override
  String get automaticPublicRelay => 'ส่งต่อ SOS สาธารณะของฉันอัตโนมัติ';

  @override
  String get automaticPublicRelayOn =>
      'เปิด เมื่อเกิดเหตุ ข้อมูล SOS ที่ลงลายเซ็นอาจถูกเก็บและส่งต่อผ่านอุปกรณ์ใกล้เคียงที่เข้าร่วมได้นานสูงสุด 30 นาที';

  @override
  String get automaticPublicRelayOff =>
      'ปิด ควรตั้งค่าก่อนเกิดเหตุ การอนุญาต Bluetooth เพียงอย่างเดียวจะไม่เปิดการส่งต่อสาธารณะ';

  @override
  String get includeLocationRelay => 'แนบตำแหน่งในการส่งต่อสาธารณะ';

  @override
  String get includeLocationRelayDescription =>
      'เป็นความยินยอมแยกต่างหาก เมื่อปิด ข้อความส่งต่อจะไม่มีพิกัด';

  @override
  String get nearbyRelay => 'ช่วยส่งต่อ SOS ใกล้เคียง';

  @override
  String get nearbyRelayOn =>
      'เปิดขณะแอปทำงาน อุปกรณ์นี้อาจเก็บและส่งต่อ SOS สาธารณะ แต่ไม่ได้กลายเป็นผู้ช่วยเหลือ';

  @override
  String get nearbyRelayOff =>
      'ปิดเป็นค่าเริ่มต้น เปิดเมื่อต้องการช่วยเก็บและส่งต่อ SOS สาธารณะของผู้อื่นเท่านั้น SOS ของคุณใช้ความยินยอมที่เลือกสำหรับเหตุนั้น';

  @override
  String get relayDiagnostics => 'ข้อมูลวินิจฉัย Relay';

  @override
  String get relayDiagnosticsDescription =>
      'หลักฐาน Relay v2 ในเครื่องแบบอ่านอย่างเดียว (รุ่นนักพัฒนา)';

  @override
  String get bleTest => 'ทดสอบ BLE (Debug)';

  @override
  String get bleTestDescription => 'ทดสอบ Bluetooth ใกล้เคียงระหว่างโทรศัพท์';

  @override
  String get emergencyCommunication => 'การสื่อสารฉุกเฉิน';

  @override
  String get myAccount => 'บัญชีของฉัน';

  @override
  String get savedOnDevice => 'บันทึกในอุปกรณ์นี้';

  @override
  String get noEmailAvailable => 'ไม่มีอีเมล';

  @override
  String get signInForCloud => 'เข้าสู่ระบบเพื่อสร้าง SOS บนคลาวด์ครั้งใหม่';

  @override
  String get emailVerified => 'ยืนยันอีเมลแล้ว';

  @override
  String get emailNotVerified => 'ยังไม่ยืนยันอีเมล';

  @override
  String get login => 'เข้าสู่ระบบ';

  @override
  String get register => 'สมัครบัญชี';

  @override
  String get createAccount => 'สร้างบัญชี';

  @override
  String get resetPassword => 'รีเซ็ตรหัสผ่าน';

  @override
  String get resetPasswordDescription =>
      'เราจะส่งลิงก์รีเซ็ตรหัสผ่านไปยังอีเมลของคุณ';

  @override
  String get email => 'อีเมล';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get pleaseWait => 'โปรดรอสักครู่…';

  @override
  String get forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get backToLogin => 'กลับไปเข้าสู่ระบบ';

  @override
  String get alreadyHaveAccount => 'มีบัญชีแล้ว? เข้าสู่ระบบ';

  @override
  String get createNewAccount => 'สร้างบัญชีใหม่';

  @override
  String get sendResetLink => 'ส่งลิงก์รีเซ็ต';

  @override
  String get sendingResetLink => 'กำลังส่งลิงก์รีเซ็ต…';

  @override
  String get enterValidEmail => 'กรุณากรอกอีเมลที่ถูกต้อง';

  @override
  String get authFailed =>
      'เข้าสู่ระบบไม่ได้ ตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';

  @override
  String get checkEmail => 'ตรวจสอบอีเมลของคุณ';

  @override
  String resetEmailPrivacy(String email) {
    return 'หากมีบัญชีสำหรับ $email คุณอาจได้รับลิงก์รีเซ็ต\nโปรดตรวจสอบกล่องขาเข้าและจดหมายขยะ';
  }

  @override
  String resendIn(int seconds) {
    return 'ส่งอีกครั้งใน $seconds วินาที';
  }

  @override
  String get resendEmail => 'ส่งอีเมลอีกครั้ง';

  @override
  String get manageAccount => 'จัดการบัญชีและการตั้งค่าความปลอดภัยของคุณ';

  @override
  String get accountDetails => 'รายละเอียดบัญชี';

  @override
  String get account => 'บัญชี';

  @override
  String get verification => 'การยืนยัน';

  @override
  String get security => 'ความปลอดภัย';

  @override
  String get userId => 'รหัสผู้ใช้';

  @override
  String get unknown => 'ไม่ทราบ';

  @override
  String get yes => 'ใช่';

  @override
  String get no => 'ไม่ใช่';

  @override
  String get resetPasswordByEmail => 'ส่งลิงก์รีเซ็ตรหัสผ่านทางอีเมล';

  @override
  String get verifyEmail => 'ยืนยันอีเมล';

  @override
  String get verifyEmailDescription => 'ส่งลิงก์ยืนยันไปยังอีเมลของคุณ';

  @override
  String get signOut => 'ออกจากระบบ';

  @override
  String get signOutDescription => 'ออกจากระบบบนอุปกรณ์นี้';

  @override
  String get signOutQuestion => 'ออกจากระบบ?';

  @override
  String get signOutWarning => 'คุณต้องเข้าสู่ระบบอีกครั้งเพื่อใช้บัญชีนี้';

  @override
  String get verificationSent => 'ส่งอีเมลยืนยันแล้ว โปรดตรวจสอบกล่องขาเข้า';

  @override
  String get verificationFailed => 'ส่งอีเมลยืนยันไม่ได้ โปรดลองภายหลัง';

  @override
  String get genericError => 'เกิดข้อผิดพลาด โปรดลองอีกครั้ง';

  @override
  String get noAccountEmail => 'บัญชีนี้ไม่มีอีเมลที่เชื่อมโยงอยู่';

  @override
  String get passwordResetSent =>
      'ส่งอีเมลรีเซ็ตรหัสผ่านแล้ว โปรดตรวจสอบกล่องขาเข้า';

  @override
  String get passwordResetFailed =>
      'ส่งอีเมลรีเซ็ตรหัสผ่านไม่ได้ โปรดลองภายหลัง';

  @override
  String get passwordRecoveryUnavailable =>
      'ยังไม่ได้ตั้งค่าการกู้คืนรหัสผ่านแบบปลอดภัย โปรดติดต่อผู้ดูแล แทนการรีเซ็ตด้วยอีเมลอย่างเดียว';

  @override
  String get signOutFailed => 'ออกจากระบบไม่ได้ โปรดลองอีกครั้ง';

  @override
  String get roleQuestion => 'วันนี้คุณต้องการทำอะไร?';

  @override
  String get roleInstruction =>
      'เลือกโหมดให้เหมาะกับสถานการณ์ คุณเปลี่ยนโหมดภายหลังได้โดยข้อมูลเดิมไม่ถูกลบ';

  @override
  String get needHelpEyebrow => 'ต้องการความช่วยเหลือ';

  @override
  String get needHelpTitle => 'ฉันต้องการความช่วยเหลือ';

  @override
  String get needHelpDescription =>
      'ส่ง SOS ติดตามการส่งใกล้เคียง และกลับเข้าสู่เหตุที่กำลังดำเนินอยู่';

  @override
  String get rescueEyebrow => 'ช่วยเหลือ';

  @override
  String get rescueTitle => 'ฉันต้องการช่วยเหลือ';

  @override
  String get rescueDescription =>
      'เปิดรับเหตุใกล้เคียง ตรวจรายละเอียด และติดตามเหตุที่กำลังช่วยเหลือ';

  @override
  String get chooseMode => 'เลือกโหมดนี้';

  @override
  String get roleTrustNotice =>
      'โหมดเปลี่ยนเพียงรูปแบบหน้าจอ ไม่ใช่การยืนยันตัวตน สิทธิ์ผู้ช่วยเหลือ หรือสิทธิ์เข้าถึงเหตุของผู้อื่น';

  @override
  String get emergencyChat => 'แชตฉุกเฉิน';

  @override
  String chatIncidentSemantics(String incidentId) {
    return 'แชตสำหรับเหตุ $incidentId';
  }

  @override
  String get savedLocallyFirst => 'บันทึกในเครื่องก่อน';

  @override
  String get chatNeedsRecipient =>
      'ข้อความในคิวต้องระบุผู้รับ BLE กรุณาเลือกอุปกรณ์ที่ตั้งใจ แอปจะไม่คาดเดาผู้รับ';

  @override
  String get assigning => 'กำลังกำหนด…';

  @override
  String get chooseRecipient => 'เลือกผู้รับ';

  @override
  String get tryAgain => 'ลองอีกครั้ง';

  @override
  String get chooseIncidentBeforeChat => 'เลือกเหตุการณ์ก่อนเริ่มแชต';

  @override
  String get noChatMessages =>
      'ยังไม่มีข้อความ\nส่งข้อมูลสั้น ๆ ที่อีกฝ่ายจำเป็นต้องรู้';

  @override
  String get emergencyMessage => 'ข้อความฉุกเฉิน';

  @override
  String get typeMessage => 'พิมพ์ข้อความ…';

  @override
  String get send => 'ส่ง';

  @override
  String get statusQueued => 'อยู่ในคิว';

  @override
  String get statusSending => 'กำลังส่ง';

  @override
  String get statusAwaitingConfirmation => 'รอการยืนยันจากแอปผู้รับ';

  @override
  String get statusConfirmedStored =>
      'ยืนยันว่าบันทึกบนอุปกรณ์ใกล้เคียงที่เลือกแล้ว';

  @override
  String get statusDelivered => 'ส่งถึงอุปกรณ์ผู้รับแล้ว';

  @override
  String get statusFailedRetryable => 'ล้มเหลว · ลองใหม่ได้';

  @override
  String get statusFailedNoRetry => 'ส่งไม่สำเร็จและยังไม่ได้นัดลองใหม่';

  @override
  String get statusFailedRetryScheduled => 'ล้มเหลว · นัดลองใหม่แล้ว';

  @override
  String get statusExpired => 'หมดอายุ';

  @override
  String get deliveryStatusUnavailable =>
      'ตรวจสอบสถานะการส่งไม่ได้ชั่วคราว แต่ SOS ยังบันทึกอยู่ในเครื่อง';

  @override
  String get savedNearbyUnavailable =>
      'บันทึกในเครื่องแล้ว แต่เซสชันนี้ส่งไปอุปกรณ์ใกล้เคียงไม่ได้';

  @override
  String get directStoredConfirmed =>
      'ยืนยันว่าบันทึกบนอุปกรณ์ใกล้เคียงที่เลือกแล้ว';

  @override
  String get sentAwaitingConfirmation =>
      'ส่งไปอุปกรณ์ใกล้เคียงแล้ว กำลังรอการยืนยันจากแอปผู้รับ';

  @override
  String storedOnRelay(int count) {
    return 'บันทึกบนอุปกรณ์ส่งต่อ $count เครื่องแล้ว แต่ยังไม่ยืนยันการส่งถึงปลายทาง';
  }

  @override
  String get forwardingAuthenticatedRelay =>
      'กำลังส่งต่อไปยังอุปกรณ์ Relay ใกล้เคียงที่ผ่านการตรวจสอบ';

  @override
  String get nearbyFailedNoRetry =>
      'ส่งใกล้เคียงไม่สำเร็จและยังไม่ได้นัดลองใหม่';

  @override
  String get nearbyFailedRetry => 'ส่งใกล้เคียงไม่สำเร็จ แต่นัดลองใหม่แล้ว';

  @override
  String get nearbyExpired => 'การส่งใกล้เคียงหมดอายุโดยยังไม่มีการยืนยัน';

  @override
  String get preparingNearbyRoute =>
      'กำลังเตรียมเส้นทางใกล้เคียงที่เชื่อถือได้';

  @override
  String get noRelayAccepted =>
      'ยังไม่มี Relay รับเก็บ SOS ระบบจะลองใหม่เมื่อมีอุปกรณ์ที่เข้าเงื่อนไข';

  @override
  String get searchingEligibleDevice =>
      'กำลังค้นหาอุปกรณ์ใกล้เคียงที่เข้าเงื่อนไข ยังไม่ยืนยันการส่งถึงปลายทาง';

  @override
  String get foregroundLocationSharing => 'แชร์ตำแหน่งขณะแอปเปิดอยู่';

  @override
  String locationDeliverySemantics(String status) {
    return 'สถานะส่งตำแหน่ง: $status';
  }

  @override
  String get locationOff => 'ปิด';

  @override
  String get readyToSend => 'พร้อมส่ง';

  @override
  String get gettingLocation => 'กำลังหาตำแหน่ง…';

  @override
  String get statusFailed => 'ล้มเหลว';

  @override
  String recipientLabel(String recipient) {
    return 'ผู้รับ: $recipient';
  }

  @override
  String get recipientNotSelected => 'ยังไม่ได้เลือก';

  @override
  String get locationOffDescription => 'ปิดอยู่ กรุณาเลือกผู้รับก่อนแชร์';

  @override
  String lastUpdate(String time) {
    return 'อัปเดตล่าสุด: $time';
  }

  @override
  String previousDelivery(String status) {
    return 'การส่งก่อนหน้า: $status';
  }

  @override
  String get starting => 'กำลังเริ่ม…';

  @override
  String get startSharing => 'เริ่มแชร์';

  @override
  String get sendLocation => 'ส่งตำแหน่ง';

  @override
  String get stopSharing => 'หยุดแชร์';

  @override
  String get selectRecipientToShare =>
      'เลือกผู้รับที่เชื่อมต่อแล้วเพื่อเริ่มแชร์';

  @override
  String get currentLocationUnavailable =>
      'ตำแหน่งปัจจุบันใช้ไม่ได้หรือไม่ถูกต้อง';

  @override
  String get locationUnavailableSaved =>
      'ไม่สามารถระบุตำแหน่งได้ — บันทึก SOS แล้วโดยไม่มีพิกัด';

  @override
  String get locationServicesDisabled => 'บริการตำแหน่งถูกปิดอยู่';

  @override
  String get locationPermissionDenied => 'ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง';

  @override
  String get locationPermissionDeniedForever =>
      'สิทธิ์ตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดในการตั้งค่า';

  @override
  String get locationTimedOut => 'การขอตำแหน่งหมดเวลา';

  @override
  String get locationShareFailed => 'แชร์ตำแหน่งไม่ได้ กรุณาลองอีกครั้ง';

  @override
  String get chooseBleRecipient => 'เลือกผู้รับ BLE';

  @override
  String get bleRecipientTrustNotice =>
      'เลือกอุปกรณ์ใกล้เคียงที่ต้องการ รหัสที่แสดงเป็นรหัสการเชื่อมต่อและไม่ได้ยืนยันตัวตนบุคคล';

  @override
  String get bleNotReady => 'BLE ยังไม่พร้อม';

  @override
  String get scanningNearby => 'กำลังค้นหาอุปกรณ์ใกล้เคียง…';

  @override
  String get unnamedDevice => 'อุปกรณ์ไม่มีชื่อ';

  @override
  String deviceStatus(String status) {
    return 'สถานะ: $status';
  }

  @override
  String get useDevice => 'ใช้เครื่องนี้';

  @override
  String get connect => 'เชื่อมต่อ';

  @override
  String get continueWithoutRecipient => 'ดำเนินการต่อโดยไม่เลือกผู้รับ';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get details => 'รายละเอียด';

  @override
  String get sosHold => 'กดค้างเพื่อส่ง SOS';

  @override
  String get sendSos => 'ส่ง SOS';

  @override
  String get creatingSos => 'กำลังสร้าง SOS…';

  @override
  String get keepHolding => 'กดค้างต่อ';

  @override
  String get checkingLocation => 'กำลังตรวจสอบตำแหน่ง';

  @override
  String get holdToStart => 'กดค้างเพื่อเริ่ม';

  @override
  String get openActiveChat => 'เปิดแชต SOS ที่กำลังดำเนินอยู่';

  @override
  String get activeSos => 'SOS กำลังดำเนินอยู่';

  @override
  String tapToOpenIncidentChat(String incidentId) {
    return 'แตะเพื่อเปิดแชต · เหตุ $incidentId';
  }

  @override
  String get historyTitle => 'ประวัติ SOS';

  @override
  String get closeSearch => 'ปิดการค้นหา';

  @override
  String get searchHistory => 'ค้นหาประวัติ';

  @override
  String get clearSearch => 'ล้างคำค้นหา';

  @override
  String get newestFirst => 'ใหม่ก่อน · แตะเพื่อเรียงเก่าก่อน';

  @override
  String get oldestFirst => 'เก่าก่อน · แตะเพื่อเรียงใหม่ก่อน';

  @override
  String get deviceData => 'ข้อมูลในเครื่อง';

  @override
  String get accountHistoryPendingSync =>
      'ประวัติบัญชีปัจจุบัน (รวมรายการรอซิงก์)';

  @override
  String get historySearch => 'ค้นหา SOS หรือข้อความ';

  @override
  String get filterAll => 'ทั้งหมด';

  @override
  String get filterActive => 'กำลังดำเนินการ';

  @override
  String get filterCompleted => 'สำเร็จ';

  @override
  String get filterCancelled => 'ยกเลิก';

  @override
  String itemCount(int count) {
    return '$count รายการ';
  }

  @override
  String get waitingForRecipient => 'กำลังรอผู้รับ';

  @override
  String get waitingReceiverConfirmation => 'กำลังรอการยืนยันจากผู้รับ';

  @override
  String get nearbyRescueCenter => 'ศูนย์ช่วยเหลือใกล้ตัว';

  @override
  String get receivedOnDevice => 'เหตุที่รับผ่าน BLE บนอุปกรณ์นี้';

  @override
  String get switchToNeedHelp => 'สลับไปโหมดขอความช่วยเหลือ';

  @override
  String get readyForNearbyIncidents => 'พร้อมรับเหตุใกล้เคียง';

  @override
  String get listenWhenReady => 'เปิดรับเหตุเมื่อคุณพร้อม';

  @override
  String get rescueListeningDescription =>
      'Bluetooth กำลังเปิดรับการเชื่อมต่อ ให้แอปอยู่ด้านหน้าเพื่อความน่าเชื่อถือสูงสุด';

  @override
  String get rescueOffDescription =>
      'ระบบจะขอสิทธิ์ Bluetooth เมื่อกดเริ่ม และจะไม่ถือว่าการเชื่อมต่อคือการรับช่วยเหลือ';

  @override
  String get incidentMap => 'แผนที่เหตุการณ์';

  @override
  String get mapTilesRequireInternet =>
      'แผนที่ต้องใช้อินเทอร์เน็ต แต่พิกัดยังดูแบบออฟไลน์ได้';

  @override
  String get finalDeliveryUnconfirmed => 'ยังไม่ยืนยันการส่งถึงปลายทาง';

  @override
  String get activeIncidentExists => 'ยังมีเหตุที่กำลังดำเนินอยู่';

  @override
  String get roleSwitchPreservesData =>
      'การสลับโหมดจะไม่ยกเลิกเหตุ ไม่ลบข้อมูล และไม่หยุดคิว BLE คุณกลับมาเปิดเหตุเดิมได้ทุกเมื่อ';

  @override
  String get stayInMode => 'อยู่โหมดเดิม';

  @override
  String get switchMode => 'สลับโหมด';

  @override
  String get rescuePreparingBluetooth => 'กำลังเตรียม Bluetooth…';

  @override
  String get rescueListening => 'กำลังเปิดรับเหตุ';

  @override
  String get startRescueListening => 'เริ่มเปิดรับเหตุ';

  @override
  String get receivedIncidents => 'เหตุที่ได้รับ';

  @override
  String incidentCount(int count) {
    return '$count เหตุ';
  }

  @override
  String get helpingIncidents => 'เหตุที่กำลังช่วย';

  @override
  String get switchModeTooltip => 'สลับโหมด';

  @override
  String get storedOnThisDevice => 'บันทึกบนอุปกรณ์นี้';

  @override
  String get helpingStateNotice =>
      'สถานะนี้ช่วยให้กลับมาเปิดเหตุได้เร็ว แต่ไม่ใช่การมอบหมายแบบเอกสิทธิ์และยังไม่ได้ส่งการตอบรับจากมนุษย์ถึงผู้ประสบภัย';

  @override
  String get noTrackedIncidents => 'ยังไม่มีเหตุที่รับติดตาม';

  @override
  String get trackIncidentHint =>
      'เลือก “รับติดตามบนอุปกรณ์นี้” จากเหตุที่ได้รับเพื่อปักไว้ในหน้านี้';

  @override
  String get viewReceivedIncidents => 'ดูเหตุที่ได้รับ';

  @override
  String get noReceivedIncidents => 'ยังไม่มีเหตุที่รับเข้ามา';

  @override
  String get receivedIncidentHint =>
      'เปิดรับเหตุและให้ผู้ส่งเลือกอุปกรณ์นี้ เหตุจะปรากฏหลังบันทึกสำเร็จ';

  @override
  String get openTrackedIncident => 'เปิดเหตุที่กำลังช่วย';

  @override
  String rescueStartFailed(String error) {
    return 'เปิดรับเหตุไม่สำเร็จ: $error';
  }

  @override
  String get switchToRescue => 'สลับไปโหมดผู้ช่วยเหลือ';

  @override
  String get locationServices => 'บริการตำแหน่ง';

  @override
  String get permission => 'สิทธิ์การเข้าถึง';

  @override
  String get openLocationSettings => 'เปิดการตั้งค่าตำแหน่ง';

  @override
  String get openAppSettings => 'เปิดการตั้งค่าแอป';

  @override
  String get close => 'ปิด';

  @override
  String get incidentChats => 'แชตตามเหตุการณ์';

  @override
  String get noChatIncidents => 'ยังไม่มีเหตุสำหรับแชต';

  @override
  String openIncidentChatSemantics(String type, String incidentId) {
    return 'เปิดแชตเหตุ $type $incidentId';
  }

  @override
  String get enableLocationServices => 'กรุณาเปิดบริการตำแหน่งแล้วลองอีกครั้ง';

  @override
  String get locationPermissionRequired => 'ต้องอนุญาตตำแหน่งเพื่อส่ง SOS';

  @override
  String get unableGetLocation => 'ไม่สามารถรับตำแหน่งปัจจุบันได้';

  @override
  String get sosSavedRelaySearching =>
      'บันทึก SOS แล้ว กำลังค้นหาอุปกรณ์ Relay ที่เข้าร่วม แต่ยังไม่ยืนยันการส่งถึงปลายทาง';

  @override
  String get sosSavedWithLocation =>
      'บันทึก SOS พร้อมตำแหน่งแล้ว กำลังรอเส้นทางใกล้เคียงที่เชื่อถือได้';

  @override
  String get sosSavedLocally =>
      'บันทึก SOS ในเครื่องแล้ว กำลังรอเส้นทางใกล้เคียงที่เชื่อถือได้';

  @override
  String sosSendFailed(String error) {
    return 'ส่ง SOS ไม่สำเร็จ: $error';
  }

  @override
  String get deviceHistory => 'ข้อมูลในเครื่อง';

  @override
  String get guestHistoryNotice =>
      'SOS ของ Guest อยู่เฉพาะอุปกรณ์นี้ ไม่ผูกกับบัญชีและไม่อัปโหลดขึ้นคลาวด์';

  @override
  String get noGuestHistory => 'ไม่มีข้อมูล Guest ในเครื่อง';

  @override
  String get sosDetails => 'รายละเอียด SOS';

  @override
  String get manageSos => 'จัดการ SOS';

  @override
  String get editMessage => 'แก้ไขข้อความ';

  @override
  String get deleteSos => 'ลบ SOS';

  @override
  String get closeSosDetails => 'ปิดรายละเอียด SOS';

  @override
  String get type => 'ประเภท';

  @override
  String get humanResponse => 'การตอบรับจากมนุษย์';

  @override
  String get noHumanConfirmation =>
      'Protocol ปัจจุบันยังไม่มีการยืนยันการตอบรับจากมนุษย์ สถานะ BLE ยืนยันเฉพาะการบันทึกบนอุปกรณ์ผู้รับ';

  @override
  String get responderStatus => 'สถานะผู้ช่วยเหลือ';

  @override
  String get sharedLocation => 'ตำแหน่งที่แชร์';

  @override
  String get noVerifiedSharedLocation =>
      'ยังไม่มีตำแหน่งที่แชร์และผ่านการตรวจสอบสำหรับเหตุนี้';

  @override
  String get viewSharedLocation => 'ดูตำแหน่งที่แชร์';

  @override
  String get created => 'สร้างเมื่อ';

  @override
  String get updated => 'อัปเดตเมื่อ';

  @override
  String get sync => 'การซิงก์';

  @override
  String get deviceOnly => 'อยู่ในเครื่องเท่านั้น';

  @override
  String get synced => 'ซิงก์แล้ว';

  @override
  String get pendingSync => 'รอซิงก์';

  @override
  String get message => 'ข้อความ';

  @override
  String get openIncidentChat => 'เปิดแชตเหตุการณ์';

  @override
  String get viewOnMap => 'ดูบนแผนที่';

  @override
  String get markResolved => 'ทำเครื่องหมายว่าแก้ไขแล้ว';

  @override
  String get cancelSos => 'ยกเลิก SOS';

  @override
  String get bleDelivery => 'การส่งผ่าน BLE';

  @override
  String get recipient => 'ผู้รับ';

  @override
  String unableSetRecipient(String error) {
    return 'ตั้งค่าผู้รับไม่ได้: $error';
  }

  @override
  String get publicSosRelay => 'Relay SOS สาธารณะ';

  @override
  String get relayExpiredUnconfirmed =>
      'Relay หมดอายุก่อนยืนยันการส่งถึงปลายทาง';

  @override
  String get relayForwardingUnconfirmed =>
      'กำลังส่งต่อผ่านอุปกรณ์ใกล้เคียง แต่ยังไม่ยืนยันการส่งถึงปลายทาง';

  @override
  String get relayRetryUnconfirmed =>
      'กำลังรอลองส่งต่อใหม่ แต่ยังไม่ยืนยันการส่งถึงปลายทาง';

  @override
  String get relayWaitingUnconfirmed =>
      'กำลังรอส่งต่อ แต่ยังไม่ยืนยันการส่งถึงปลายทาง';

  @override
  String get deleteSosQuestion => 'ลบ SOS หรือไม่?';

  @override
  String get deleteCannotUndo => 'การดำเนินการนี้ย้อนกลับไม่ได้';

  @override
  String get delete => 'ลบ';

  @override
  String get save => 'บันทึก';

  @override
  String get editSos => 'แก้ไข SOS';

  @override
  String get describeEmergency => 'อธิบายเหตุฉุกเฉิน';

  @override
  String get downloadVisibleArea => 'ดาวน์โหลดพื้นที่ที่เห็น';

  @override
  String get offlineDownloadRequiresProvider =>
      'การดาวน์โหลดออฟไลน์ต้องใช้ Geoapify สำหรับ production';

  @override
  String get manageOfflineMaps => 'จัดการแผนที่ออฟไลน์';

  @override
  String get zoomIn => 'ขยายแผนที่';

  @override
  String get zoomOut => 'ย่อแผนที่';

  @override
  String get centerCurrentLocation => 'เลื่อนแผนที่ไปยังตำแหน่งปัจจุบัน';

  @override
  String get refreshCurrentLocation => 'รีเฟรชตำแหน่งปัจจุบัน';

  @override
  String get sharedLocationAvailable =>
      'มีตำแหน่งที่แชร์จากอุปกรณ์คู่ที่ตรงกัน';

  @override
  String get sharedLocationExpired =>
      'ตำแหน่งที่แชร์หมดอายุและไม่แสดงเป็นตำแหน่งปัจจุบัน';

  @override
  String get sharedLocationUnavailable => 'ตำแหน่งที่แชร์ใช้ไม่ได้';

  @override
  String get currentLocationIncidentAvailable =>
      'ตำแหน่งปัจจุบันใช้ไม่ได้ แต่ตำแหน่งเหตุยังดูได้';

  @override
  String get currentLocationStale =>
      'ตำแหน่งปัจจุบันเก่าเกินไป โปรดรีเฟรชก่อนใช้อ้างอิง';

  @override
  String get currentLocationAvailable => 'มีตำแหน่งปัจจุบัน';

  @override
  String incidentCoordinates(String latitude, String longitude) {
    return 'พิกัดเหตุ: $latitude, $longitude';
  }

  @override
  String get incidentCoordinatesUnavailable => 'ไม่มีพิกัดของเหตุการณ์';

  @override
  String get downloadedTilesAvailable =>
      'มีแผนที่บางส่วนใช้ออฟไลน์แล้ว ส่วนที่ขาดยังต้องใช้อินเทอร์เน็ต';

  @override
  String get preparingMapStorage => 'กำลังเตรียมพื้นที่เก็บแผนที่…';

  @override
  String downloadingTiles(int completed, int total) {
    return 'กำลังดาวน์โหลด $completed/$total ช่องแผนที่';
  }

  @override
  String get retryMapTiles => 'ลองโหลดแผนที่อีกครั้ง';

  @override
  String get mapProviderUnavailable =>
      'ผู้ให้บริการแผนที่ใช้ไม่ได้ใน build นี้';

  @override
  String get developmentTileProvider =>
      'กำลังใช้ผู้ให้บริการแผนที่สำหรับพัฒนา โปรดตั้งค่า MAP_TILE_URL สำหรับ production';

  @override
  String get noIncidentLocation => 'เหตุการณ์นี้ไม่มีตำแหน่งที่ใช้ได้';

  @override
  String get mapName => 'ชื่อแผนที่';

  @override
  String minimumZoom(int zoom) {
    return 'ระดับซูมต่ำสุด: $zoom';
  }

  @override
  String maximumZoom(int zoom) {
    return 'ระดับซูมสูงสุด: $zoom';
  }

  @override
  String get download => 'ดาวน์โหลด';

  @override
  String get offlineMaps => 'แผนที่ออฟไลน์';

  @override
  String get noDownloadedRegions => 'ยังไม่มีพื้นที่แผนที่ที่ดาวน์โหลดไว้';

  @override
  String get offlineDownloadCancelled => 'ยกเลิกการดาวน์โหลดแผนที่ออฟไลน์แล้ว';

  @override
  String get chatSavedPending =>
      'บันทึกในเครื่องแล้ว การส่งผ่าน BLE ยังรอดำเนินการ';

  @override
  String get chatSendFailed => 'ส่งข้อความไม่ได้ โปรดลองอีกครั้ง';

  @override
  String get noQueuedMessagesNeedRecipient =>
      'ไม่มีข้อความในคิวที่ต้องกำหนดผู้รับ';

  @override
  String recipientAssigned(int count) {
    return 'กำหนดผู้รับให้ข้อความในคิว $count ข้อความแล้ว';
  }

  @override
  String assignRecipientFailed(String error) {
    return 'กำหนดผู้รับไม่ได้: $error';
  }

  @override
  String get developerToolUnavailable => 'เครื่องมือนักพัฒนาใช้ไม่ได้';

  @override
  String get relayDiagnosticsUnavailable => 'ข้อมูลวินิจฉัย Relay ใช้ไม่ได้';

  @override
  String get relayDiagnosticsReadFailed =>
      'อ่านสถานะ Relay ในเครื่องไม่ได้ ไม่มีข้อมูลถูกเปลี่ยนแปลง';

  @override
  String get noRelayRecords => 'ไม่มีรายการ Relay';

  @override
  String get noRelayRecordsDescription =>
      'อุปกรณ์นี้ไม่มีข้อความ Relay v2 ที่เก็บไว้ รายการ Relay-only จะไม่ปรากฏในประวัติ SOS';

  @override
  String get relayEvidenceNotice =>
      'ข้อมูลสำหรับนักพัฒนาเท่านั้น Hop receipt พิสูจน์ว่า Relay เครื่องถัดไปเก็บข้อมูลแล้ว แต่ไม่พิสูจน์ว่าผู้ช่วยเหลือได้รับ SOS';

  @override
  String relayMessagesStored(int count) {
    return 'ข้อความ Relay ที่เก็บไว้: $count';
  }

  @override
  String get locallyOriginatedSos => 'SOS ที่สร้างจากเครื่องนี้';

  @override
  String get relayOnlyEnvelope => 'ข้อมูล Relay-only';

  @override
  String get messageId => 'รหัสข้อความ';

  @override
  String get payloadDigest => 'สรุป Payload';

  @override
  String get incomingHopCount => 'จำนวน Hop ขาเข้า';

  @override
  String get latestPersisted => 'บันทึกล่าสุด';

  @override
  String get latestRelayJobStatus => 'สถานะงาน Relay ล่าสุด';

  @override
  String get relayAttemptCount => 'จำนวนครั้งที่ Relay พยายามส่ง';

  @override
  String get hopReceipt => 'Hop receipt';

  @override
  String get hopReceiptsStored => 'Hop receipt ที่เก็บไว้';

  @override
  String get finalResponderReceipt => 'Final responder receipt';

  @override
  String get confirmed => 'ยืนยันแล้ว';

  @override
  String get notConfirmed => 'ยังไม่ยืนยัน';

  @override
  String get finalReceiptsStored => 'Final receipt ที่เก็บไว้';

  @override
  String get lastRelayErrorCategory => 'ประเภทข้อผิดพลาด Relay ล่าสุด';

  @override
  String get none => 'ไม่มี';

  @override
  String get storedOnRelayStatus => 'เก็บบน Relay แล้ว';

  @override
  String get storedByNextRelay => 'Relay เครื่องถัดไปเก็บแล้ว';

  @override
  String get awaitingHopReceipt => 'กำลังรอ Hop receipt';

  @override
  String get finalReceiptRecorded => 'บันทึก Final receipt แล้ว';

  @override
  String get receivedFromNextRelay => 'ได้รับจาก Relay เครื่องถัดไป';

  @override
  String get pending => 'รอดำเนินการ';

  @override
  String get failedOrExpired => 'ล้มเหลวหรือหมดอายุ';

  @override
  String get notRecordedLocally => 'ไม่ได้บันทึกในเครื่อง';

  @override
  String get resolveSosQuestion => 'แก้ไขเหตุ SOS แล้วหรือไม่?';

  @override
  String get cancelSosQuestion => 'ยกเลิก SOS หรือไม่?';

  @override
  String get resolveSosConfirmation =>
      'ยืนยันว่าต้องการทำเครื่องหมายว่าเหตุ SOS นี้ได้รับการแก้ไขแล้วหรือไม่?';

  @override
  String get cancelSosConfirmation => 'ยืนยันว่าต้องการยกเลิก SOS นี้หรือไม่?';

  @override
  String get back => 'ย้อนกลับ';

  @override
  String get resolve => 'แก้ไขแล้ว';

  @override
  String get sosMarkedResolved => 'ทำเครื่องหมายว่าแก้ไข SOS แล้ว';

  @override
  String get sosCancelled => 'ยกเลิก SOS แล้ว';

  @override
  String failedUpdateSos(String error) {
    return 'อัปเดต SOS ไม่สำเร็จ: $error';
  }

  @override
  String get sosUpdated => 'อัปเดต SOS แล้ว';

  @override
  String get sosDeleted => 'ลบ SOS แล้ว';

  @override
  String failedDeleteSos(String error) {
    return 'ลบ SOS ไม่สำเร็จ: $error';
  }

  @override
  String get syncCompleted => 'ซิงก์เสร็จแล้ว';

  @override
  String syncFailed(String error) {
    return 'ซิงก์ไม่สำเร็จ: $error';
  }

  @override
  String get localDataOnly => 'ข้อมูลในเครื่องเท่านั้น';

  @override
  String get tapToOpenChat => 'แตะเพื่อเปิดแชต';

  @override
  String get tapToViewDetails => 'แตะเพื่อดูรายละเอียด';

  @override
  String get unableOpenAttribution => 'เปิดลิงก์แหล่งที่มาไม่ได้';

  @override
  String offlineRegionAvailable(String name) {
    return '$name พร้อมใช้งานออฟไลน์แล้ว';
  }

  @override
  String deleteNamedItem(String name) {
    return 'ลบ $name';
  }

  @override
  String offlineRegionSummary(
    int count,
    String size,
    int minZoom,
    int maxZoom,
  ) {
    return '$count ช่องแผนที่ · $size · ซูม $minZoom–$maxZoom';
  }

  @override
  String get bleTestDebug => 'ทดสอบ BLE (Debug)';

  @override
  String get debugToolOnly => 'เครื่องมือ Debug เท่านั้น';

  @override
  String get debugToolSafety => 'หน้านี้ไม่สร้างหรือส่งการแจ้งเตือน SOS จริง';

  @override
  String get bluetoothStatus => 'สถานะ Bluetooth';

  @override
  String get permissions => 'สิทธิ์การใช้งาน';

  @override
  String get blePlatformCapabilities =>
      'Android และ iOS รองรับการค้นหา โฆษณา เชื่อมต่อ เขียน และรับข้อมูล BLE ต้องทดสอบขณะแอปเปิดอยู่ การวัดระยะใช้ application ACK ส่วนข้อความทดสอบทั่วไปแสดงเพียงการยอมรับการเขียนของระบบ';

  @override
  String get startScan => 'เริ่มค้นหา';

  @override
  String get stopScan => 'หยุดค้นหา';

  @override
  String get startAdvertising => 'เริ่มโฆษณา';

  @override
  String get stopAdvertising => 'หยุดโฆษณา';

  @override
  String get discoveredDevices => 'อุปกรณ์ที่ค้นพบ';

  @override
  String get noDevicesDiscovered =>
      'ยังไม่พบอุปกรณ์ โปรดเริ่มค้นหาบนอุปกรณ์ทั้งสองเครื่อง';

  @override
  String get disconnect => 'ตัดการเชื่อมต่อ';

  @override
  String get testMessage => 'ข้อความทดสอบ';

  @override
  String get bleRangeDiagnostic => 'วินิจฉัยระยะและคุณภาพ BLE';

  @override
  String get rangeDiagnosticSafety =>
      'โปรดบันทึกระยะจริงด้วยตนเอง RSSI คือความแรงสัญญาณและไม่ถูกแปลงเป็นระยะทาง ทดสอบแต่ละระยะทั้งพื้นที่เปิดและมีสิ่งกีดขวาง';

  @override
  String get startRangeRun => 'เริ่มวัดระยะ';

  @override
  String get stop => 'หยุด';

  @override
  String receivedMessages(int count) {
    return 'ข้อความที่ได้รับ ($count)';
  }

  @override
  String get noCompleteMessages => 'ยังไม่ได้รับข้อความที่สมบูรณ์';

  @override
  String get diagnosticLog => 'บันทึกวินิจฉัย';

  @override
  String get clear => 'ล้าง';

  @override
  String get noDiagnostics => 'ยังไม่มีข้อมูลวินิจฉัย';

  @override
  String get mapConfigProductionProviderMissing =>
      'ยังไม่ได้ตั้งค่าผู้ให้บริการแผนที่สำหรับ build นี้';

  @override
  String get mapConfigUrlMissing => 'ไม่มีที่อยู่บริการแผนที่';

  @override
  String get mapConfigUrlInvalid => 'ที่อยู่บริการแผนที่จะต้องใช้ HTTPS';

  @override
  String get mapConfigPublicOsmBlocked =>
      'บริการแผนที่ OpenStreetMap สาธารณะใช้ไม่ได้ใน build สำหรับเผยแพร่';

  @override
  String get mapConfigGeoapifyKeyMissing => 'ไม่มีคีย์สำหรับบริการแผนที่';

  @override
  String get mapConfigTemplateInvalid => 'การตั้งค่าบริการแผนที่ไม่สมบูรณ์';

  @override
  String get mapConfigAttributionMissing =>
      'ไม่มีข้อความอ้างอิงแผนที่ที่จำเป็น';

  @override
  String get mapConfigGeoapifyAttributionIncomplete =>
      'ต้องแสดงการอ้างอิง Geoapify และ OpenStreetMap';

  @override
  String get mapConfigUserAgentMissing => 'ไม่มีข้อมูลระบุตัวตนของบริการแผนที่';

  @override
  String get offlineMapStorageUnavailable =>
      'ที่เก็บแผนที่ออฟไลน์ใช้ไม่ได้บนอุปกรณ์นี้';

  @override
  String get offlineMapDownloadFailed =>
      'ดาวน์โหลดแผนที่ออฟไลน์ไม่ได้ โปรดตรวจการเชื่อมต่อ พื้นที่เก็บข้อมูล และผู้ให้บริการแผนที่';

  @override
  String get incidentCoordinatesInvalid =>
      'พิกัดของเหตุการณ์ใช้ไม่ได้หรือไม่ถูกต้อง';

  @override
  String sharedCoordinates(String latitude, String longitude, String time) {
    return 'ตำแหน่งที่แชร์: $latitude, $longitude · $time';
  }

  @override
  String get mapLegend =>
      'แดง: เหตุการณ์ · ม่วง: ตำแหน่งที่แชร์ · น้ำเงิน: อุปกรณ์นี้';

  @override
  String offlineMapDefaultName(String date) {
    return 'พื้นที่เหตุการณ์ $date';
  }

  @override
  String offlineTileEstimate(int count, String megabytes) {
    return '$count ช่องแผนที่ · ประมาณ $megabytes MB';
  }

  @override
  String offlineMapTooLarge(int maxTiles) {
    return 'โปรดลดพื้นที่ที่มองเห็นหรือช่วงซูม ขีดจำกัดความปลอดภัยคือ $maxTiles ช่องแผนที่';
  }

  @override
  String get offlineMapDownloadInfo =>
      'โปรดเปิดแอปค้างไว้ระหว่างดาวน์โหลด ระบบจะเก็บเฉพาะพื้นที่ที่มองเห็นภายในขอบเขต';

  @override
  String offlineMapStorageSummary(String size) {
    return 'จัดเก็บแล้ว: $size';
  }
}
