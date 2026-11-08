import 'ble_models.dart';

/// Correlates native readiness/disconnect events per peer and GATT role.
/// Native attempt numbers are monotonic within a transport lifetime. Missing
/// metadata keeps legacy disconnect behavior: retire proof rather than assume
/// that an uncorrelated disconnect is stale.
class BleConnectionEvents {
  final _attempts = <String, Map<BleSessionRole, int?>>{};

  void clear() => _attempts.clear();

  List<BleEvent> accept(BleEvent event) {
    final peer = event.device?.id.trim();
    if (peer == null || peer.isEmpty) return [event];
    if (event.type == 'connected') {
      final role = event.role ?? BleSessionRole.central;
      final roles = _attempts.putIfAbsent(peer, () => {});
      final current = roles[role];
      if (current != null &&
          event.attempt != null &&
          event.attempt! < current) {
        return [];
      }
      roles[role] = event.attempt ?? current;
      return [event];
    }
    if (event.type != 'disconnected') return [event];
    final roles = _attempts[peer];
    if (event.role == null && event.attempt == null) {
      _attempts.remove(peer);
      return [event];
    }
    if (event.role == null && roles != null && roles.isNotEmpty) {
      // A tagged event without a role must not clear the opposite role's
      // newer connection. Normalize only the matching roles for all consumers.
      final matching = roles.keys
          .where((role) => roles[role] == null || roles[role] == event.attempt)
          .toList();
      for (final role in matching) {
        roles.remove(role);
      }
      if (roles.isEmpty) _attempts.remove(peer);
      return [
        for (final role in matching)
          BleEvent(
            type: event.type,
            device: event.device,
            role: role,
            attempt: event.attempt,
            error: event.error,
          ),
      ];
    }
    final current = roles?[event.role];
    if (current != null && event.attempt != null && current != event.attempt) {
      return [];
    }
    roles?.remove(event.role);
    if (roles?.isEmpty ?? false) _attempts.remove(peer);
    return [event];
  }
}
