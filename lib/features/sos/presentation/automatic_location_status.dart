import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../nearby_ble/presentation/user_route_view.dart';
import '../../nearby_ble/data/automatic_incident_location.dart';

/// Informational only: SOS/acceptance controls the session, never a GPS picker.
class AutomaticLocationStatus extends StatelessWidget {
  const AutomaticLocationStatus({super.key, this.status});
  final ValueListenable<AutomaticLocationState>? status;

  @override
  Widget build(BuildContext context) {
    Widget content(AutomaticLocationState value) {
      final message = switch (value) {
        AutomaticLocationState.permissionRequired => routeText(
          context,
          'Allow location access in Settings to share your position automatically.',
          'อนุญาตตำแหน่งในการตั้งค่า เพื่อแชร์ตำแหน่งอัตโนมัติ',
        ),
        AutomaticLocationState.unavailable => routeText(
          context,
          'Location is unavailable. Retrying automatically.',
          'ยังหาตำแหน่งไม่ได้ ระบบจะลองใหม่อัตโนมัติ',
        ),
        AutomaticLocationState.sharing => routeText(
          context,
          'Automatic location updates are active.',
          'กำลังอัปเดตตำแหน่งอัตโนมัติ',
        ),
        _ => routeText(
          context,
          'Location updates start automatically for this active SOS.',
          'ระบบจะอัปเดตตำแหน่งอัตโนมัติระหว่างใช้งาน SOS',
        ),
      };
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.share_location),
        title: Text(
          routeText(context, 'Automatic location', 'ตำแหน่งอัตโนมัติ'),
        ),
        subtitle: Text(message),
      );
    }

    if (status == null) return content(AutomaticLocationState.idle);
    return ValueListenableBuilder<AutomaticLocationState>(
      valueListenable: status!,
      builder: (_, value, _) => content(value),
    );
  }
}
