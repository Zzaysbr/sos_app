import 'package:flutter/services.dart';

abstract interface class RelayPreferenceStore {
  Future<bool> loadParticipationEnabled();

  Future<void> saveParticipationEnabled(bool enabled);
}

/// Device-local product preference. It is deliberately independent from
/// account ownership and defaults to disabled in each native implementation.
class PlatformRelayPreferenceStore implements RelayPreferenceStore {
  const PlatformRelayPreferenceStore();

  static const _channel = MethodChannel('sos_app/preferences');

  @override
  Future<bool> loadParticipationEnabled() async =>
      await _channel.invokeMethod<bool>('getRelayParticipationEnabled') ??
      false;

  @override
  Future<void> saveParticipationEnabled(bool enabled) =>
      _channel.invokeMethod<void>('setRelayParticipationEnabled', enabled);
}

class MemoryRelayPreferenceStore implements RelayPreferenceStore {
  MemoryRelayPreferenceStore({this.enabled = false});

  bool enabled;
  int saveCount = 0;

  @override
  Future<bool> loadParticipationEnabled() async => enabled;

  @override
  Future<void> saveParticipationEnabled(bool enabled) async {
    this.enabled = enabled;
    saveCount++;
  }
}
