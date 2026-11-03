import 'dart:math';

enum RecoveryStage {
  emailPending,
  secondFactorPending,
  verified,
  completed,
  expired,
  locked,
}

class RecoveryException implements Exception {
  const RecoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RecoveryUnavailableException extends RecoveryException {
  const RecoveryUnavailableException()
    : super('Secure password recovery is not configured.');
}

/// An opaque proof issued by a trusted backend after independently verifying
/// one recovery factor. The client cannot construct a valid proof because the
/// backend binding and signature are checked by [PasswordRecoveryBackend].
class RecoveryFactorProof {
  const RecoveryFactorProof({
    required this.transactionId,
    required this.accountBinding,
    required this.factor,
    required this.proofId,
  });

  final String transactionId;
  final String accountBinding;
  final RecoveryFactor factor;
  final String proofId;
}

enum RecoveryFactor { email, secondFactor }

abstract interface class PasswordRecoveryBackend {
  Future<void> begin({required String transactionId, required String email});

  Future<RecoveryFactorProof> verifyFactor({
    required String transactionId,
    required RecoveryFactor factor,
    required String serverProof,
  });

  Future<void> changePassword({
    required String transactionId,
    required String accountBinding,
    required String newPassword,
    required String confirmationProof,
  });
}

/// Firebase Auth's public password-reset API is intentionally not used here:
/// it verifies email ownership only and has no client API to bind a second
/// factor to the same reset transaction. A deployed, HTTPS backend must be
/// supplied before this flow can be enabled.
class UnavailablePasswordRecoveryBackend implements PasswordRecoveryBackend {
  const UnavailablePasswordRecoveryBackend();

  @override
  Future<void> begin({required String transactionId, required String email}) {
    throw const RecoveryUnavailableException();
  }

  @override
  Future<RecoveryFactorProof> verifyFactor({
    required String transactionId,
    required RecoveryFactor factor,
    required String serverProof,
  }) {
    throw const RecoveryUnavailableException();
  }

  @override
  Future<void> changePassword({
    required String transactionId,
    required String accountBinding,
    required String newPassword,
    required String confirmationProof,
  }) {
    throw const RecoveryUnavailableException();
  }
}

class RecoveryTransaction {
  const RecoveryTransaction({
    required this.id,
    required this.email,
    required this.createdAt,
    required this.expiresAt,
    required this.stage,
    required this.attempts,
    this.accountBinding,
  });

  final String id;
  final String email;
  final DateTime createdAt;
  final DateTime expiresAt;
  final RecoveryStage stage;
  final int attempts;
  final String? accountBinding;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  RecoveryTransaction copyWith({
    RecoveryStage? stage,
    int? attempts,
    String? accountBinding,
  }) => RecoveryTransaction(
    id: id,
    email: email,
    createdAt: createdAt,
    expiresAt: expiresAt,
    stage: stage ?? this.stage,
    attempts: attempts ?? this.attempts,
    accountBinding: accountBinding ?? this.accountBinding,
  );
}

class PasswordRecoveryCoordinator {
  PasswordRecoveryCoordinator({
    required this.backend,
    DateTime Function()? now,
    Random? random,
    this.ttl = const Duration(minutes: 10),
    this.maxAttempts = 5,
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  final PasswordRecoveryBackend backend;
  final DateTime Function() _now;
  final Random _random;
  final Duration ttl;
  final int maxAttempts;
  RecoveryTransaction? _transaction;
  RecoveryFactorProof? _emailProof;
  RecoveryFactorProof? _secondFactorProof;

  RecoveryTransaction? get transaction => _transaction;

  Future<RecoveryTransaction> start({required String email}) async {
    final normalized = email.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized)) {
      throw const RecoveryException('Enter a valid email address.');
    }
    final now = _now().toUtc();
    final transaction = RecoveryTransaction(
      id: _newId(),
      email: normalized,
      createdAt: now,
      expiresAt: now.add(ttl),
      stage: RecoveryStage.emailPending,
      attempts: 0,
    );
    _transaction = transaction;
    _emailProof = null;
    _secondFactorProof = null;
    await backend.begin(transactionId: transaction.id, email: normalized);
    return transaction;
  }

  Future<void> verifyFactor({
    required RecoveryFactor factor,
    required String serverProof,
  }) async {
    final current = _requireActive();
    if (current.attempts >= maxAttempts) {
      _transaction = current.copyWith(stage: RecoveryStage.locked);
      throw const RecoveryException('Too many attempts. Start again later.');
    }
    try {
      final proof = await backend.verifyFactor(
        transactionId: current.id,
        factor: factor,
        serverProof: serverProof,
      );
      if (proof.transactionId != current.id || proof.factor != factor) {
        throw const RecoveryException('Verification failed.');
      }
      if (factor == RecoveryFactor.email) {
        _emailProof = proof;
      } else {
        _secondFactorProof = proof;
      }
      final bothVerified = _emailProof != null && _secondFactorProof != null;
      _transaction = current.copyWith(
        stage: bothVerified
            ? RecoveryStage.verified
            : RecoveryStage.secondFactorPending,
        accountBinding: proof.accountBinding,
      );
    } catch (_) {
      final attempts = current.attempts + 1;
      _transaction = current.copyWith(
        attempts: attempts,
        stage: attempts >= maxAttempts
            ? RecoveryStage.locked
            : current.stage,
      );
      rethrow;
    }
  }

  Future<void> changePassword({
    required String newPassword,
    required String confirmation,
    required String confirmationProof,
  }) async {
    final current = _requireActive();
    if (current.stage != RecoveryStage.verified ||
        _emailProof == null ||
        _secondFactorProof == null ||
        current.accountBinding == null) {
      throw const RecoveryException('Both verification factors are required.');
    }
    if (newPassword.length < 6 || newPassword != confirmation) {
      throw const RecoveryException('Password confirmation failed.');
    }
    await backend.changePassword(
      transactionId: current.id,
      accountBinding: current.accountBinding!,
      newPassword: newPassword,
      confirmationProof: confirmationProof,
    );
    _transaction = current.copyWith(stage: RecoveryStage.completed);
    _emailProof = null;
    _secondFactorProof = null;
  }

  RecoveryTransaction _requireActive() {
    final current = _transaction;
    if (current == null) {
      throw const RecoveryException('Start a recovery transaction first.');
    }
    if (current.isExpired(_now().toUtc())) {
      _transaction = current.copyWith(stage: RecoveryStage.expired);
      throw const RecoveryException('Recovery session expired. Start again.');
    }
    if (current.stage == RecoveryStage.locked ||
        current.stage == RecoveryStage.completed) {
      throw const RecoveryException('Recovery session is no longer valid.');
    }
    return current;
  }

  String _newId() {
    final values = List<int>.generate(16, (_) => _random.nextInt(256));
    return values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }
}
