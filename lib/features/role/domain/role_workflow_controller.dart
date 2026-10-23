class RoleWorkflowController {
  final Set<String> _acceptedIncidentIds = <String>{};
  final Set<String> _acceptingIncidentIds = <String>{};

  Set<String> get acceptedIncidentIds => Set.unmodifiable(_acceptedIncidentIds);

  bool isAccepted(String sosId) => _acceptedIncidentIds.contains(sosId);

  bool isAccepting(String sosId) => _acceptingIncidentIds.contains(sosId);

  bool canCreateSos({
    required Iterable<String> activeIncidentIds,
    required Set<String> inboundIncidentIds,
  }) => activeIncidentIds.every(inboundIncidentIds.contains);

  Future<bool> accept(
    String sosId, {
    Future<void> Function()? onAccepted,
  }) async {
    if (_acceptedIncidentIds.contains(sosId) ||
        !_acceptingIncidentIds.add(sosId)) {
      return false;
    }
    try {
      await onAccepted?.call();
      _acceptedIncidentIds.add(sosId);
      return true;
    } finally {
      _acceptingIncidentIds.remove(sosId);
    }
  }
}
