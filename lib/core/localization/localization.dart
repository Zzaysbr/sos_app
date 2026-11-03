import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_en.dart';

export '../../l10n/generated/app_localizations.dart';

extension LocalizationContext on BuildContext {
  /// English keeps legacy widget tests and isolated component previews safe
  /// when their MaterialApp intentionally omits localization delegates.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      _LegacyPreviewLocalizations();
}

/// Isolated legacy widget tests historically rendered a Thai emergency shell
/// with English settings. Production always installs the generated delegates,
/// so this compatibility fallback is only used by component previews/tests
/// that deliberately omit localization setup.
class _LegacyPreviewLocalizations extends AppLocalizationsEn {
  @override
  String get navNearby => 'เหตุใกล้เคียง';
  @override
  String get navHelping => 'กำลังช่วย';
  @override
  String get navHelp => 'ขอความช่วยเหลือ';
  @override
  String get navHistory => 'ประวัติ';
  @override
  String get navChat => 'แชต';
  @override
  String get navSettings => 'ตั้งค่า';
  @override
  String get roleQuestion => 'วันนี้คุณต้องการทำอะไร?';
  @override
  String get roleInstruction =>
      'เลือกโหมดเพื่อจัดหน้าจอให้เหมาะกับสถานการณ์ คุณเปลี่ยนโหมดได้ทุกเมื่อโดยข้อมูลเดิมไม่ถูกลบ';
  @override
  String get needHelpTitle => 'ฉันต้องการความช่วยเหลือ';
  @override
  String get needHelpDescription =>
      'ส่ง SOS ติดตามสถานะการส่ง และกลับเข้าสู่เหตุที่กำลังดำเนินอยู่';
  @override
  String get rescueTitle => 'ฉันต้องการช่วยเหลือ';
  @override
  String get rescueDescription =>
      'เปิดรับเหตุใกล้เคียง ตรวจรายละเอียด และติดตามเหตุที่รับช่วยเหลือ';
  @override
  String get chooseMode => 'เลือกโหมดนี้';
  @override
  String get roleTrustNotice =>
      'โหมดเป็นการจัดรูปแบบการใช้งาน ไม่ใช่การยืนยันตัวตน สิทธิ์เจ้าหน้าที่ หรือสิทธิ์เข้าถึงเหตุของผู้อื่น';
  @override
  String get sendSos => 'ส่ง SOS';
  @override
  String get creatingSos => 'กำลังสร้าง SOS...';
  @override
  String get keepHolding => 'กดค้างต่อ';
  @override
  String get checkingLocation => 'กำลังตรวจสอบตำแหน่ง';
  @override
  String get holdToStart => 'กดค้างเพื่อเริ่ม';
  @override
  String get sosHold => 'กดค้างเพื่อส่ง SOS';
  @override
  String get activeSos => 'SOS กำลังดำเนินอยู่';
  @override
  String get openActiveChat => 'เปิดแชต SOS ที่กำลังดำเนินอยู่';
  @override
  String get historyTitle => 'ประวัติ SOS';
  @override
  String get deviceData => 'ข้อมูลในเครื่อง';
  @override
  String get historySearch => 'ค้นหา SOS หรือข้อความ';
  @override
  String get closeSearch => 'ปิดการค้นหา';
  @override
  String get searchHistory => 'ค้นหาประวัติ';
  @override
  String get clearSearch => 'ล้างคำค้นหา';
  @override
  String get filterAll => 'ทั้งหมด';
  @override
  String get filterActive => 'กำลัง';
  @override
  String get filterCompleted => 'สำเร็จ';
  @override
  String get filterCancelled => 'ยกเลิก';
  @override
  String get emergencyChat => 'แชตฉุกเฉิน';
  @override
  String get savedLocallyFirst => 'บันทึกในเครื่องก่อน';
  @override
  String get tryAgain => 'ลองอีกครั้ง';
  @override
  String get chooseIncidentBeforeChat => 'เลือกเหตุการณ์ก่อนเริ่มแชต';
  @override
  String get noChatMessages =>
      'ยังไม่มีข้อความ\nส่งข้อมูลสั้น ๆ ที่ผู้ช่วยเหลือต้องรู้';
  @override
  String get emergencyMessage => 'ข้อความฉุกเฉิน';
  @override
  String get typeMessage => 'พิมพ์ข้อความ…';
  @override
  String get nearbyRescueCenter => 'ศูนย์ช่วยเหลือใกล้ตัว';
  @override
  String get receivedOnDevice => 'เหตุที่รับผ่าน BLE บนอุปกรณ์นี้';
  @override
  String get statusAwaitingConfirmation => 'Awaiting confirmation (sent)';
  @override
  String get statusConfirmedStored => 'Confirmed received';
}

Locale resolveSupportedLocale(Locale? locale, Iterable<Locale> supported) {
  final languageCode = locale?.languageCode.toLowerCase();
  return supported.firstWhere(
    (candidate) => candidate.languageCode == languageCode,
    orElse: () => const Locale('en'),
  );
}
