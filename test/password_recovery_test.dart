import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/features/auth/data/auth_service.dart';
import 'package:sos_app/features/auth/data/password_recovery.dart';

class _Auth extends Mock implements FirebaseAuth {}

class _Backend implements PasswordRecoveryBackend {
  int beginCount = 0;
  int verifyCount = 0;
  int changeCount = 0;
  bool rejectEmail = false;
  bool rejectSecondFactor = false;
  RecoveryFactorProof? foreignProof;
  String? lastTransaction;
  String? lastAccount;

  @override
  Future<void> begin({required String transactionId, required String email}) async {
    beginCount++;
    lastTransaction = transactionId;
  }

  @override
  Future<RecoveryFactorProof> verifyFactor({
    required String transactionId,
    required RecoveryFactor factor,
    required String serverProof,
  }) async {
    verifyCount++;
    if ((factor == RecoveryFactor.email && rejectEmail) ||
        (factor == RecoveryFactor.secondFactor && rejectSecondFactor)) {
      throw const RecoveryException('Verification failed.');
    }
    return foreignProof ?? RecoveryFactorProof(
      transactionId: transactionId,
      accountBinding: 'account-binding',
      factor: factor,
      proofId: '$transactionId-${factor.name}',
    );
  }

  @override
  Future<void> changePassword({
    required String transactionId,
    required String accountBinding,
    required String newPassword,
    required String confirmationProof,
  }) async {
    changeCount++;
    lastAccount = accountBinding;
  }
}

void main() {
  late _Backend backend;
  late DateTime now;
  late PasswordRecoveryCoordinator coordinator;

  setUp(() {
    backend = _Backend();
    now = DateTime.utc(2026, 1, 1);
    coordinator = PasswordRecoveryCoordinator(
      backend: backend,
      now: () => now,
      ttl: const Duration(minutes: 5),
    );
  });

  test('valid email starts a neutral recovery transaction', () async {
    final tx = await coordinator.start(email: ' Person@Example.com ');
    expect(tx.email, 'person@example.com');
    expect(tx.stage, RecoveryStage.emailPending);
    expect(backend.beginCount, 1);
  });

  test('invalid email is rejected before backend access', () async {
    expect(
      () => coordinator.start(email: 'not-an-email'),
      throwsA(isA<RecoveryException>()),
    );
    expect(backend.beginCount, 0);
  });

  test('valid email factor advances to second-factor pending', () async {
    await coordinator.start(email: 'person@example.com');
    await coordinator.verifyFactor(
      factor: RecoveryFactor.email,
      serverProof: 'server-proof',
    );
    expect(coordinator.transaction!.stage, RecoveryStage.secondFactorPending);
  });

  test('invalid email factor does not advance the transaction', () async {
    backend.rejectEmail = true;
    await coordinator.start(email: 'person@example.com');
    await expectLater(
      coordinator.verifyFactor(
        factor: RecoveryFactor.email,
        serverProof: 'invalid',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(coordinator.transaction!.stage, RecoveryStage.emailPending);
  });

  test('valid second factor completes both-factor verification', () async {
    await coordinator.start(email: 'person@example.com');
    await coordinator.verifyFactor(
      factor: RecoveryFactor.email,
      serverProof: 'email-proof',
    );
    await coordinator.verifyFactor(
      factor: RecoveryFactor.secondFactor,
      serverProof: 'second-proof',
    );
    expect(coordinator.transaction!.stage, RecoveryStage.verified);
  });

  test('invalid second factor cannot unlock password change', () async {
    backend.rejectSecondFactor = true;
    await coordinator.start(email: 'person@example.com');
    await coordinator.verifyFactor(
      factor: RecoveryFactor.email,
      serverProof: 'email-proof',
    );
    await expectLater(
      coordinator.verifyFactor(
        factor: RecoveryFactor.secondFactor,
        serverProof: 'invalid',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(coordinator.transaction!.stage, RecoveryStage.secondFactorPending);
  });

  test('expired first-factor transaction is rejected', () async {
    await coordinator.start(email: 'person@example.com');
    now = now.add(const Duration(minutes: 5));
    await expectLater(
      coordinator.verifyFactor(
        factor: RecoveryFactor.email,
        serverProof: 'late',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(coordinator.transaction!.stage, RecoveryStage.expired);
  });

  test('expired second-factor challenge is rejected', () async {
    await coordinator.start(email: 'person@example.com');
    await coordinator.verifyFactor(
      factor: RecoveryFactor.email,
      serverProof: 'email-proof',
    );
    now = now.add(const Duration(minutes: 5));
    await expectLater(
      coordinator.verifyFactor(
        factor: RecoveryFactor.secondFactor,
        serverProof: 'late',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(coordinator.transaction!.stage, RecoveryStage.expired);
  });

  test('password change is rejected before both factors', () async {
    await coordinator.start(email: 'person@example.com');
    await expectLater(
      coordinator.changePassword(
        newPassword: 'new-password',
        confirmation: 'new-password',
        confirmationProof: 'proof',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(backend.changeCount, 0);
  });

  test('password change is accepted only after both factors', () async {
    await coordinator.start(email: 'person@example.com');
    await coordinator.verifyFactor(
      factor: RecoveryFactor.email,
      serverProof: 'email-proof',
    );
    await coordinator.verifyFactor(
      factor: RecoveryFactor.secondFactor,
      serverProof: 'second-proof',
    );
    await coordinator.changePassword(
      newPassword: 'new-password',
      confirmation: 'new-password',
      confirmationProof: 'backend-proof',
    );
    expect(coordinator.transaction!.stage, RecoveryStage.completed);
    expect(backend.changeCount, 1);
  });

  test('completed transaction cannot be replayed', () async {
    await coordinator.start(email: 'person@example.com');
    await coordinator.verifyFactor(
      factor: RecoveryFactor.email,
      serverProof: 'email-proof',
    );
    await coordinator.verifyFactor(
      factor: RecoveryFactor.secondFactor,
      serverProof: 'second-proof',
    );
    await coordinator.changePassword(
      newPassword: 'new-password',
      confirmation: 'new-password',
      confirmationProof: 'backend-proof',
    );
    await expectLater(
      coordinator.changePassword(
        newPassword: 'another-password',
        confirmation: 'another-password',
        confirmationProof: 'replay',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(backend.changeCount, 1);
  });

  test('factor proof from another transaction is rejected', () async {
    await coordinator.start(email: 'person@example.com');
    backend.foreignProof = const RecoveryFactorProof(
      transactionId: 'different-transaction',
      accountBinding: 'other-account',
      factor: RecoveryFactor.email,
      proofId: 'other',
    );
    await expectLater(
      coordinator.verifyFactor(
        factor: RecoveryFactor.email,
        serverProof: 'foreign',
      ),
      throwsA(isA<RecoveryException>()),
    );
    expect(coordinator.transaction!.stage, RecoveryStage.emailPending);
  });

  test('rate limiting locks after repeated failures', () async {
    backend.rejectEmail = true;
    coordinator = PasswordRecoveryCoordinator(
      backend: backend,
      now: () => now,
      maxAttempts: 2,
    );
    await coordinator.start(email: 'person@example.com');
    for (var i = 0; i < 2; i++) {
      await expectLater(
        coordinator.verifyFactor(
          factor: RecoveryFactor.email,
          serverProof: 'invalid',
        ),
        throwsA(isA<RecoveryException>()),
      );
    }
    expect(coordinator.transaction!.stage, RecoveryStage.locked);
  });

  test('duplicate start replaces the previous transaction', () async {
    final first = await coordinator.start(email: 'first@example.com');
    final second = await coordinator.start(email: 'second@example.com');
    expect(second.id, isNot(first.id));
    expect(coordinator.transaction!.email, 'second@example.com');
    expect(backend.beginCount, 2);
  });

  test('unavailable backend fails closed without claiming email delivery', () async {
    final unavailable = PasswordRecoveryCoordinator(
      backend: const UnavailablePasswordRecoveryBackend(),
    );
    await expectLater(
      unavailable.start(email: 'person@example.com'),
      throwsA(isA<RecoveryUnavailableException>()),
    );
  });

  test('AuthService blocks the legacy email-only Firebase reset path', () async {
    final auth = _Auth();
    final service = AuthService(firebaseAuth: auth);

    await expectLater(
      service.resetPassword(email: 'person@example.com'),
      throwsA(isA<AuthException>()),
    );
    verifyNever(() => auth.sendPasswordResetEmail(email: any(named: 'email')));
  });
}
