import 'package:flutter/services.dart';

class EmergencyConsent {
  const EmergencyConsent({
    required this.configured,
    required this.allowPublicRelay,
    this.allowVoluntaryRescue = false,
    required this.shareLocation,
  });

  const EmergencyConsent.safeDefault()
    : configured = false,
      allowPublicRelay = false,
      allowVoluntaryRescue = false,
      shareLocation = false;

  final bool configured;
  final bool allowPublicRelay;
  final bool allowVoluntaryRescue;
  final bool shareLocation;

  EmergencyConsent copyWith({
    bool? configured,
    bool? allowPublicRelay,
    bool? allowVoluntaryRescue,
    bool? shareLocation,
  }) {
    final relay = allowPublicRelay ?? this.allowPublicRelay;
    return EmergencyConsent(
      configured: configured ?? this.configured,
      allowPublicRelay: relay,
      allowVoluntaryRescue: relay
          ? (allowVoluntaryRescue ?? this.allowVoluntaryRescue)
          : false,
      shareLocation: relay ? (shareLocation ?? this.shareLocation) : false,
    );
  }
}

abstract interface class EmergencyConsentStore {
  Future<EmergencyConsent> load();

  Future<void> save(EmergencyConsent consent);
}

/// Device-local consent configured before an emergency. This is deliberately
/// separate from OS Bluetooth permission and from volunteering this device to
/// carry other people's relay messages.
class PlatformEmergencyConsentStore implements EmergencyConsentStore {
  const PlatformEmergencyConsentStore();

  static const _channel = MethodChannel('sos_app/preferences');

  @override
  Future<EmergencyConsent> load() async {
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getEmergencyConsent',
    );
    if (value == null) return const EmergencyConsent.safeDefault();
    final configured = value['configured'];
    final allowPublicRelay = value['allowPublicRelay'];
    final allowVoluntaryRescue = value['allowVoluntaryRescue'];
    final shareLocation = value['shareLocation'];
    if (configured is! bool ||
        allowPublicRelay is! bool ||
        shareLocation is! bool ||
        (allowVoluntaryRescue != null && allowVoluntaryRescue is! bool) ||
        (shareLocation && !allowPublicRelay)) {
      throw const FormatException('Invalid saved emergency consent.');
    }
    return EmergencyConsent(
      configured: configured,
      allowPublicRelay: allowPublicRelay,
      allowVoluntaryRescue: allowVoluntaryRescue as bool? ?? false,
      shareLocation: shareLocation,
    );
  }

  @override
  Future<void> save(EmergencyConsent consent) {
    return _channel.invokeMethod<void>('setEmergencyConsent', {
      'configured': consent.configured,
      'allowPublicRelay': consent.allowPublicRelay,
      'allowVoluntaryRescue':
          consent.allowPublicRelay && consent.allowVoluntaryRescue,
      'shareLocation': consent.allowPublicRelay && consent.shareLocation,
    });
  }
}

class MemoryEmergencyConsentStore implements EmergencyConsentStore {
  MemoryEmergencyConsentStore({
    this.consent = const EmergencyConsent.safeDefault(),
  });

  EmergencyConsent consent;
  int saveCount = 0;

  @override
  Future<EmergencyConsent> load() async => consent;

  @override
  Future<void> save(EmergencyConsent consent) async {
    this.consent = consent;
    saveCount++;
  }
}
