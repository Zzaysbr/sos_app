import 'dart:convert';
import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/relay_envelope.dart';

abstract interface class RelayPrivateKeyStore {
  Future<List<int>?> readSeed();
  Future<void> writeSeed(List<int> seed);
}

/// Stores only the Ed25519 seed in platform protected storage. AndroidOptions
/// uses an Android Keystore-wrapped AES-GCM store; IOSOptions uses a local,
/// non-synchronizing Keychain item that does not migrate to another device.
class PlatformRelayPrivateKeyStore implements RelayPrivateKeyStore {
  PlatformRelayPrivateKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: false,
              migrateOnAlgorithmChange: true,
              migrateWithBackup: false,
              storageNamespace: 'sos_relay_v2',
            ),
            iOptions: IOSOptions(
              accountName: 'com.n1cxltine.sosapp.relay.v2',
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
          );

  static const _seedKey = 'ed25519-origin-seed-v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<int>?> readSeed() async {
    try {
      final encoded = await _storage.read(key: _seedKey);
      if (encoded == null) return null;
      final seed = base64Url.decode(base64Url.normalize(encoded));
      if (seed.length != 32) throw const FormatException();
      return seed;
    } catch (error) {
      throw RelayKeyStoreException(
        'Unable to read the relay signing key.',
        error,
      );
    }
  }

  @override
  Future<void> writeSeed(List<int> seed) async {
    if (seed.length != 32) {
      throw const RelayKeyStoreException(
        'Relay signing seed must be 32 bytes.',
      );
    }
    try {
      await _storage.write(key: _seedKey, value: base64UrlEncode(seed));
    } catch (error) {
      throw RelayKeyStoreException(
        'Unable to store the relay signing key.',
        error,
      );
    }
  }
}

class RelaySigningIdentity {
  const RelaySigningIdentity({
    required this.keyPair,
    required this.publicKey,
    required this.keyId,
  });

  final SimpleKeyPair keyPair;
  final List<int> publicKey;
  final String keyId;
}

/// Fails closed when secure storage cannot read or persist the installation
/// seed. Direct v1 code does not call this service and remains independent.
class RelayIdentityService {
  RelayIdentityService({
    required this.keyStore,
    RelayCryptography? cryptography,
    Ed25519? algorithm,
  }) : _cryptography = cryptography ?? RelayCryptography(),
       _algorithm = algorithm ?? Ed25519();

  final RelayPrivateKeyStore keyStore;
  final RelayCryptography _cryptography;
  final Ed25519 _algorithm;
  Future<RelaySigningIdentity>? _identity;
  static Future<void> _globalInitialization = Future<void>.value();

  Future<RelaySigningIdentity> loadOrCreate({required bool allowCreate}) =>
      _identity ??=
          _serializeInitialization(
            () => _loadOrCreate(allowCreate: allowCreate),
          ).catchError((Object error) {
            _identity = null;
            throw error;
          });

  Future<T> _serializeInitialization<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _globalInitialization = _globalInitialization.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<RelaySigningIdentity> _loadOrCreate({
    required bool allowCreate,
  }) async {
    var seed = await keyStore.readSeed();
    if (seed == null) {
      if (!allowCreate) {
        throw const RelayKeyStoreException(
          'Relay signing key is missing and creation was not authorized.',
        );
      }
      final generated = await _algorithm.newKeyPair();
      seed = await generated.extractPrivateKeyBytes();
      if (seed.length != 32) {
        throw const RelayKeyStoreException(
          'Cryptographic provider returned an invalid relay seed.',
        );
      }
      await keyStore.writeSeed(seed);
      final persisted = await keyStore.readSeed();
      if (persisted == null || !_sameBytes(persisted, seed)) {
        throw const RelayKeyStoreException(
          'Relay signing key could not be verified after storage.',
        );
      }
    }
    if (seed.length != 32) {
      throw const RelayKeyStoreException(
        'Stored relay signing key has invalid length.',
      );
    }
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = (await keyPair.extractPublicKey()).bytes;
    return RelaySigningIdentity(
      keyPair: keyPair,
      publicKey: List<int>.unmodifiable(publicKey),
      keyId: await _cryptography.publicKeyId(publicKey),
    );
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class RelayKeyStoreException implements Exception {
  const RelayKeyStoreException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'RelayKeyStoreException: $message';
}
