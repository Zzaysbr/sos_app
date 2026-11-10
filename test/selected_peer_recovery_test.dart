import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/features/nearby_ble/domain/selected_peer_recovery.dart';
import 'package:sos_app/features/nearby_ble/domain/ble_models.dart';

void main() {
  final key = base64UrlEncode(List<int>.filled(32, 31));
  final stranger = base64UrlEncode(List<int>.filled(32, 77));
  SelectedPeerRecovery selected() => SelectedPeerRecovery()
    ..select('old')
    ..authenticated('old', key);

  test(
    'hint is a bounded public filter, invalid keys do not produce a hint',
    () {
      expect(relayDiscoveryHint(key), '1f1f1f1f');
      expect(relayDiscoveryHint('not a public key'), isNull);
      expect(relayDiscoveryHint(base64UrlEncode([1, 2])), isNull);
      expect(
        BleDevice.fromMap({'id': 'new', 'recoveryHint': '1f1f1f1f'})
            .recoveryHint,
        '1f1f1f1f',
      );
    },
  );
  test(
    'new locator is quarantined until the selected signing key proves it',
    () {
      final s = selected();
      s.observe('new', relayDiscoveryHint(key), hasProvenRoute: (_) => false);
      expect(s.mayInitiate('new', hasProvenRoute: (_) => false), isTrue);
      expect(s.quarantined('new'), isTrue);
      expect(s.expectedKey('new'), key);
      expect(s.mayAuthenticate('new', stranger), isFalse);
      expect(s.mayAuthenticate('new', key), isTrue);
      s.authenticated('new', key);
      expect(s.quarantined('new'), isFalse);
      expect(s.selectedLocators, {'new'});
      expect(s.mayInitiate('old', hasProvenRoute: (_) => false), isFalse);
    },
  );
  test('no recovery connection is opened beside a proven route', () {
    final s = selected();
    s.observe('new', relayDiscoveryHint(key), hasProvenRoute: (_) => true);
    expect(s.connectionCandidates, {'old'});
    expect(s.mayInitiate('old', hasProvenRoute: (_) => true), isFalse);
  });

  test(
    'manual reuse of a proven alias leaves its active sibling unquarantined',
    () {
      final s = selected();
      s.observe(
        'current',
        relayDiscoveryHint(key),
        hasProvenRoute: (_) => false,
      );
      s.authenticated('current', key);
      s.selectProven('old', key);
      expect(s.quarantined('current'), isFalse);
      expect(s.mayAuthenticate('current', key), isTrue);
      s.selectProven('current', key);
      expect(s.selectedLocators, {'current'});
    },
  );

  test('automatic retry of the old locator cannot substitute another key', () {
    final s = selected();
    expect(s.expectedKey('old'), key);
    expect(s.mayAuthenticate('old', stranger), isFalse);
    s.authenticated('old', stranger);
    expect(s.quarantined('old'), isTrue);
    expect(s.mayInitiate('old', hasProvenRoute: (_) => false), isFalse);
    s.observe(
      'real-new',
      relayDiscoveryHint(key),
      hasProvenRoute: (_) => false,
    );
    expect(s.expectedKey('real-new'), key);
  });

  test(
    'explicit manual reselection can authorize an installation with a new key',
    () {
      final s = selected();
      s.select('old');
      expect(s.mayAuthenticate('old', stranger), isTrue);
      s.authenticated('old', stranger);
      s.observe(
        'old-key-alias',
        relayDiscoveryHint(key),
        hasProvenRoute: (_) => false,
      );
      expect(
        s.mayInitiate('old-key-alias', hasProvenRoute: (_) => false),
        isFalse,
      );
    },
  );
  test('unknown and colliding hints never authorize automatic selection', () {
    final s = selected();
    s.observe(
      'unknown',
      relayDiscoveryHint(stranger),
      hasProvenRoute: (_) => false,
    );
    expect(s.mayInitiate('unknown', hasProvenRoute: (_) => false), isFalse);
    final collision = base64UrlEncode([
      ...List<int>.filled(4, 31),
      ...List<int>.filled(28, 80),
    ]);
    s.select('other');
    s.authenticated('other', collision);
    s.observe(
      'ambiguous',
      relayDiscoveryHint(key),
      hasProvenRoute: (_) => false,
    );
    expect(s.mayInitiate('ambiguous', hasProvenRoute: (_) => false), isFalse);
  });
  test('disconnect revokes the whole selected installation and late recovery proof', () {
    final s = selected();
    s.observe('new', relayDiscoveryHint(key), hasProvenRoute: (_) => false);
    s.forget('old');
    expect(s.connectionCandidates, isEmpty);
    expect(s.mayAuthenticate('new', key), isFalse);
    s.observe('another', relayDiscoveryHint(key), hasProvenRoute: (_) => false);
    expect(s.mayInitiate('another', hasProvenRoute: (_) => false), isFalse);
  });
  test(
    'wrong-key candidate stays quarantined until a fresh manual selection',
    () {
      final s = selected();
      s.observe('spoof', relayDiscoveryHint(key), hasProvenRoute: (_) => false);
      s.reject('spoof');
      expect(s.quarantined('spoof'), isTrue);
      expect(s.mayAuthenticate('spoof', key), isFalse);
      s.observe('spoof', relayDiscoveryHint(key), hasProvenRoute: (_) => false);
      expect(s.mayInitiate('spoof', hasProvenRoute: (_) => false), isFalse);
      s.select('spoof');
      expect(s.quarantined('spoof'), isFalse);
      expect(s.mayAuthenticate('spoof', stranger), isTrue);
    },
  );
}
