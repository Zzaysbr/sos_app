import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/sos/data/sos_cloud_service.dart';
import 'features/sos/data/sos_repository.dart';
import 'features/sos/data/sos_sync_coordinator.dart';
import 'features/sos/presentation/sos_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final database = AppDatabase();

  runApp(SosApp(database: database));
}

class SosApp extends StatelessWidget {
  const SosApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SOS App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: AuthGate(authService: authService, database: database),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.database,
  });

  final AuthService authService;
  final AppDatabase database;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SosRepository? _repository;
  SosSyncCoordinator? _syncCoordinator;
  String? _repositoryOwnerId;

  void _disposeSyncResources() {
    final coordinator = _syncCoordinator;
    _syncCoordinator = null;
    _repository = null;
    _repositoryOwnerId = null;

    if (coordinator != null) {
      unawaited(coordinator.dispose());
    }
  }

  void _ensureSyncResources(User user) {
    if (_repositoryOwnerId == user.uid &&
        _repository != null &&
        _syncCoordinator != null) {
      return;
    }

    _disposeSyncResources();

    final repository = SosRepository(
      database: widget.database,
      cloudService: SosCloudService(firestore: FirebaseFirestore.instance),
      firebaseAuth: FirebaseAuth.instance,
    );

    final coordinator = SosSyncCoordinator(
      repository: repository,
      firebaseAuth: FirebaseAuth.instance,
    );

    _repositoryOwnerId = user.uid;
    _repository = repository;
    _syncCoordinator = coordinator;

    unawaited(coordinator.start());
  }

  @override
  void dispose() {
    _disposeSyncResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to check authentication status.')),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          if (_repository != null) {
            _disposeSyncResources();
          }

          return AuthPage(authService: widget.authService);
        }

        _ensureSyncResources(user);

        return SosPage(repository: _repository!);
      },
    );
  }
}
