import 'package:flutter/material.dart';

import '../../nearby_ble/data/route_device_names.dart';
import '../../nearby_ble/data/user_route_repository.dart';
import '../../nearby_ble/presentation/user_route_view.dart';

/// Only mounted by Home after filtering to this device's current, active SOS.
/// A saved source is known even before there is evidence of another device.
class CurrentSosRoutePanel extends StatefulWidget {
  const CurrentSosRoutePanel({
    super.key,
    required this.incidentId,
    required this.repository,
    required this.names,
  });
  final String incidentId;
  final UserRouteRepository repository;
  final RouteDeviceNames names;
  @override
  State<CurrentSosRoutePanel> createState() => _CurrentSosRoutePanelState();
}

class _CurrentSosRoutePanelState extends State<CurrentSosRoutePanel> {
  late Stream<UserRoutesSnapshot> _stream;
  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watch(widget.incidentId);
  }

  @override
  void didUpdateWidget(CurrentSosRoutePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentId != widget.incidentId ||
        oldWidget.repository.ownerId != widget.repository.ownerId ||
        !identical(oldWidget.repository.db, widget.repository.db)) {
      _stream = widget.repository.watch(widget.incidentId);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
    ),
    child: StreamBuilder<UserRoutesSnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        final title = routeText(
          context,
          'Current SOS route',
          'เส้นทาง SOS ปัจจุบัน',
        );
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                routeText(
                  context,
                  'Route details could not be loaded.',
                  'ยังอ่านรายละเอียดเส้นทางไม่ได้',
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(
                  () => _stream = widget.repository.watch(widget.incidentId),
                ),
                icon: const Icon(Icons.refresh),
                label: Text(routeText(context, 'Try again', 'ลองอีกครั้ง')),
              ),
            ],
          );
        }
        final known = snapshot.data?.sos ?? const <UserRoute>[];
        return UserRouteView(
          title: title,
          names: widget.names,
          routes: known.isNotEmpty
              ? known
              : const [
                  UserRoute(
                    nodes: [UserRouteNode(null, local: true)],
                    stage: UserRouteStage.saved,
                    extent: UserRouteExtent.endpointsOnly,
                  ),
                ],
        );
      },
    ),
  );
}
