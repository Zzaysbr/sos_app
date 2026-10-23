import 'package:flutter/services.dart';

import '../domain/app_role.dart';

abstract interface class RolePreferenceStore {
  Future<AppRole?> load();

  Future<void> save(AppRole role);
}

class PlatformRolePreferenceStore implements RolePreferenceStore {
  const PlatformRolePreferenceStore();

  static const _channel = MethodChannel('sos_app/preferences');

  @override
  Future<AppRole?> load() async {
    final value = await _channel.invokeMethod<String>('getPreferredRole');
    return AppRole.fromWire(value);
  }

  @override
  Future<void> save(AppRole role) =>
      _channel.invokeMethod<void>('setPreferredRole', role.wireValue);
}

class MemoryRolePreferenceStore implements RolePreferenceStore {
  MemoryRolePreferenceStore([this.value]);

  AppRole? value;
  int saveCount = 0;

  @override
  Future<AppRole?> load() async => value;

  @override
  Future<void> save(AppRole role) async {
    value = role;
    saveCount++;
  }
}
