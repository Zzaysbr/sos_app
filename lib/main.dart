import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/database/app_database.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/sos/data/sos_cloud_service.dart';
import 'features/sos/data/sos_repository.dart';
import 'features/sos/presentation/sos_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final database = AppDatabase();

  runApp(
    SosApp(
      database: database,
    ),
  );
}

class SosApp extends StatelessWidget {
  const SosApp({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SOS App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
        ),
        useMaterial3: true,
      ),
      home: AuthGate(
        authService: authService,
        database: database,
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.database,
  });

  final AuthService authService;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return AuthPage(
            authService: authService,
          );
        }

        final repository = SosRepository(
          database: database,
          cloudService: SosCloudService(
            firestore: FirebaseFirestore.instance,
          ),
          firebaseAuth: FirebaseAuth.instance,
        );

        return SosPage(
          repository: repository,
          user: user,
        );
      },
    );
  }
}