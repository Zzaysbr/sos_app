import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sos_app/features/sos/data/sos_repository.dart';
import 'package:sos_app/features/sos/data/sos_sync_coordinator.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockConnectivity extends Mock implements Connectivity {}

class _MockSosRepository extends Mock implements SosRepository {}

class _MockUser extends Mock implements User {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockFirebaseAuth auth;
  late _MockConnectivity connectivity;
  late _MockSosRepository repository;
  late StreamController<User?> authChanges;
  late StreamController<List<ConnectivityResult>> connectivityChanges;
  late User? currentUser;

  setUp(() {
    auth = _MockFirebaseAuth();
    connectivity = _MockConnectivity();
    repository = _MockSosRepository();
    authChanges = StreamController<User?>.broadcast();
    connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    currentUser = null;

    when(() => auth.currentUser).thenAnswer((_) => currentUser);
    when(() => auth.authStateChanges()).thenAnswer((_) => authChanges.stream);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => connectivityChanges.stream);
  });

  tearDown(() async {
    await authChanges.close();
    await connectivityChanges.close();
  });

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'guest and expired sessions never start cloud synchronization',
    () async {
      final coordinator = SosSyncCoordinator(
        repository: repository,
        firebaseAuth: auth,
        connectivity: connectivity,
      );

      await coordinator.start();
      authChanges.add(null);
      connectivityChanges.add(const [ConnectivityResult.wifi]);
      await settle();

      verifyNever(() => repository.syncPending());
      await coordinator.dispose();
    },
  );

  test(
    'network recovery retries the authenticated queue after a failed sync',
    () async {
      currentUser = _MockUser();
      var attempts = 0;
      final firstAttempt = Completer<void>();
      final secondAttempt = Completer<void>();
      when(() => repository.syncPending()).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          firstAttempt.complete();
          throw StateError('synthetic offline failure');
        }
        secondAttempt.complete();
      });
      final coordinator = SosSyncCoordinator(
        repository: repository,
        firebaseAuth: auth,
        connectivity: connectivity,
      );

      await coordinator.start();
      await firstAttempt.future;
      await settle();
      connectivityChanges.add(const [ConnectivityResult.wifi]);
      await secondAttempt.future;

      expect(attempts, 2);
      await coordinator.dispose();
    },
  );

  test(
    'expiry blocks retries until another authenticated session exists',
    () async {
      currentUser = _MockUser();
      var attempts = 0;
      final firstAttempt = Completer<void>();
      final secondAttempt = Completer<void>();
      when(() => repository.syncPending()).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) firstAttempt.complete();
        if (attempts == 2) secondAttempt.complete();
      });
      final coordinator = SosSyncCoordinator(
        repository: repository,
        firebaseAuth: auth,
        connectivity: connectivity,
      );

      await coordinator.start();
      await firstAttempt.future;
      currentUser = null;
      authChanges.add(null);
      connectivityChanges.add(const [ConnectivityResult.wifi]);
      await settle();
      expect(attempts, 1);

      currentUser = _MockUser();
      authChanges.add(currentUser);
      await secondAttempt.future;
      expect(attempts, 2);

      await coordinator.dispose();
    },
  );
}
