import 'dart:convert';

/// Public, collision-prone routing hint only. Never an authentication result.
String? relayDiscoveryHint(String keyId) {
  try {
    final bytes = base64Url.decode(base64Url.normalize(keyId));
    if (bytes.length != 32) return null;
    return bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  } on FormatException {
    return null;
  }
}

/// Selection lasts for this owner/coordinator session, just like manual BLE
/// selection. New locators remain quarantined until the selected key proves it.
class SelectedPeerRecovery {
  static const maximumPeers = 128;
  final selectedLocators = <String>{};
  final _selectedKeys = <String>{};
  final _verifiedKeys = <String, String>{};
  final _candidates = <String, String>{};
  final _quarantined = <String>{};
  final _rejected = <String>{};

  Iterable<String> get connectionCandidates => {
    ...selectedLocators,
    ..._candidates.keys,
  };
  String? expectedKey(String peer) =>
      _candidates[peer] ??
      (selectedLocators.contains(peer) ? _verifiedKeys[peer] : null);
  bool quarantined(String peer) => _quarantined.contains(peer);
  String? knownKey(String peer) => _verifiedKeys[peer] ?? _candidates[peer];

  void select(String peer) {
    // An explicit user choice can replace an obsolete installation/key. It is
    // distinct from an automatic retry, which must keep the previously proven key.
    if (knownKey(peer) != null) forget(peer);
    _verifiedKeys.remove(peer);
    _candidates.remove(peer);
    _quarantined.remove(peer);
    _rejected.remove(peer);
    selectedLocators.add(peer);
  }

  /// Explicit user selection reusing a currently proof-complete route. Do not
  /// revoke other live aliases of that same installation while reusing it.
  void selectProven(String peer, String key) {
    final previous = knownKey(peer);
    if (previous != null && previous != key) forget(peer);
    _candidates.remove(peer);
    _quarantined.remove(peer);
    _rejected.remove(peer);
    _verifiedKeys.remove(peer);
    selectedLocators.add(peer);
    _selectedKeys.add(key);
    authenticated(peer, key);
  }

  void authenticated(String peer, String key) {
    if (!mayAuthenticate(peer, key)) {
      reject(peer);
      return;
    }
    if (_verifiedKeys.length >= maximumPeers &&
        !_verifiedKeys.containsKey(peer)) {
      final evictable = _verifiedKeys.keys
          .where((p) => !selectedLocators.contains(p))
          .firstOrNull;
      if (evictable != null) _verifiedKeys.remove(evictable);
    }
    final selected =
        selectedLocators.contains(peer) || _selectedKeys.contains(key);
    if (selected) {
      selectedLocators.removeWhere((p) => _verifiedKeys[p] == key);
      selectedLocators.add(peer);
      _selectedKeys.add(key);
      _candidates.removeWhere((p, k) => k == key);
      _quarantined.remove(peer);
      _rejected.remove(peer);
    }
    if (_verifiedKeys.length < maximumPeers ||
        _verifiedKeys.containsKey(peer)) {
      _verifiedKeys[peer] = key;
    }
  }

  void observe(
    String peer,
    String? hint, {
    required bool Function(String) hasProvenRoute,
  }) {
    if (selectedLocators.contains(peer) ||
        _rejected.contains(peer) ||
        hint == null ||
        !RegExp(r'^[0-9a-f]{8}$').hasMatch(hint)) {
      return;
    }
    final matches = _selectedKeys
        .where((key) => relayDiscoveryHint(key) == hint)
        .toList();
    // A collision is ambiguous: require a manual selection instead of guessing.
    if (matches.length != 1 || hasProvenRoute(matches.single)) return;
    if (_candidates.length >= maximumPeers && !_candidates.containsKey(peer)) {
      return;
    }
    if (_quarantined.length >= maximumPeers && !_quarantined.contains(peer)) {
      return;
    }
    _candidates[peer] = matches.single;
    _quarantined.add(peer);
  }

  bool mayAuthenticate(String peer, String key) {
    final expected = expectedKey(peer);
    if (expected != null) return expected == key && _selectedKeys.contains(key);
    return !_quarantined.contains(peer);
  }

  bool mayInitiate(
    String peer, {
    required bool Function(String) hasProvenRoute,
  }) {
    final key = _candidates[peer] ?? _verifiedKeys[peer];
    if (key != null && hasProvenRoute(key)) return false;
    return selectedLocators.contains(peer) ||
        (_candidates.containsKey(peer) && !_rejected.contains(peer));
  }

  void reject(String peer) {
    _candidates.remove(peer);
    selectedLocators.remove(peer);
    if (_quarantined.length < maximumPeers) _quarantined.add(peer);
    if (_rejected.length < maximumPeers) _rejected.add(peer);
    // Keep quarantine until explicit selection; late frames must stay blocked.
  }

  void forget(String peer) {
    final key = knownKey(peer);
    selectedLocators.remove(peer);
    if (key == null) {
      reject(peer);
      return;
    }
    _selectedKeys.remove(key);
    for (final p in {..._verifiedKeys.keys, ..._candidates.keys}) {
      if (_verifiedKeys[p] == key || _candidates[p] == key) {
        selectedLocators.remove(p);
        _quarantined.add(p);
        reject(p);
      }
    }
  }
}
