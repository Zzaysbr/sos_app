import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'core/database/app_database.dart';
import 'core/notifications/chat_notifications.dart';
import 'core/localization/locale_controller.dart';
import 'core/localization/locale_preference_store.dart';
import 'core/localization/localization.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_service.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/auth/presentation/auth_session_navigator.dart';
import 'features/nearby_ble/data/sos_ble_coordinator.dart';
import 'features/sos/data/sos_cloud_service.dart';
import 'features/sos/data/cloud_archive_service.dart';
import 'features/sos/data/chat_repository.dart';
import 'features/sos/data/sos_repository.dart';
import 'features/sos/data/sos_sync_coordinator.dart';

import 'features/sos/presentation/sos_page.dart';
import 'features/startup/presentation/startup_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final database = AppDatabase();

  final identity = await const MethodChannel('sos_ble_transport/methods')
      .invokeMethod<String>('deviceIdentity');
  if (identity == null || identity.isEmpty) {
    throw StateError('Local device identity is unavailable.');
  }
  const localeStore = PlatformLocalePreferenceStore();
  Locale? initialLocale;
  try {
    initialLocale = await localeStore.load();
  } on Object {
    // A missing, invalid, or unreadable preference must never block SOS use.
  }
  runApp(
    SosApp(
      database: database,
      localDeviceId: identity,
      localePreferenceStore: localeStore,
      initialLocale: initialLocale,
    ),
  );
}

class SosApp extends StatefulWidget {
  const SosApp({
    super.key,
    required this.database,
    this.localDeviceId,
    this.localePreferenceStore = const PlatformLocalePreferenceStore(),
    this.initialLocale,
  });

  final AppDatabase database;
  final String? localDeviceId;
  final LocalePreferenceStore localePreferenceStore;
  final Locale? initialLocale;

  @override
  State<SosApp> createState() => _SosAppState();
}

class _SosAppState extends State<SosApp> {
  late final LocaleController _localeController;
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _localeController = LocaleController(
      store: widget.localePreferenceStore,
      initialLocale: widget.initialLocale,
    )..addListener(_handleLocaleChanged);
  }

  void _handleLocaleChanged() => setState(() {});

  @override
  void dispose() {
    _localeController
      ..removeListener(_handleLocaleChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: _localeController.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) =>
          resolveSupportedLocale(locale, supportedLocales),
      home: StartupPage(
        onReady: (_) => AuthGate(
          authService: _authService,
          database: widget.database,
          localDeviceId: widget.localDeviceId,
          localeController: _localeController,
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.authService,
    required this.database,
    required this.localeController,
    this.localDeviceId,
  });

  final AuthService authService;
  final AppDatabase database;
  final LocaleController localeController;
  final String? localDeviceId;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SosRepository? _repository;
  SosSyncCoordinator? _syncCoordinator;
  SosBleCoordinator? _bleCoordinator;
  ChatRepository? _chatRepository;
  String? _repositoryOwnerId;
  int _resourceGeneration = 0;
  Future<void> _bleTeardown = Future<void>.value();
  Future<void>? _bleStart;

  void _disposeSyncResources() {
    _resourceGeneration++;
    final coordinator = _syncCoordinator;
    final bleCoordinator = _bleCoordinator;
    _syncCoordinator = null;
    _bleCoordinator = null;
    _repository = null;
    _chatRepository = null;
    _repositoryOwnerId = null;
    _bleStart = null;

    if (coordinator != null) {
      unawaited(coordinator.dispose());
    }
    if (bleCoordinator != null) {
      _bleTeardown = _bleTeardown.then((_) => bleCoordinator.dispose());
    }
  }

  void _ensureResources({
    required String ownerId,
    required bool authenticated,
  }) {
    if (_repositoryOwnerId == ownerId &&
        _repository != null &&
        _syncCoordinator != null) {
      return;
    }

    _disposeSyncResources();
    final generation = _resourceGeneration;

    final chatRepository = PersistentChatRepository(
      database: widget.database,
      ownerId: ownerId,
      senderId: widget.localDeviceId,
      onIncomingPersisted: (message) async {
        if (!mounted ||
            generation != _resourceGeneration ||
            (authenticated
                ? widget.authService.currentUser?.uid != ownerId
                : widget.authService.currentUser != null)) {
          return;
        }
        await const ChatNotifications().received(
          ownerId: ownerId,
          incidentId: message.sosId,
          messageId: message.id,
          text: message.text,
        );
      },
    );
    _chatRepository = chatRepository;
    final bleCoordinator = SosBleCoordinator(
      database: widget.database,
      ownerId: ownerId,
      localDeviceId: widget.localDeviceId,
      requirePeerBinding: widget.localDeviceId != null,
      manualPeerSelection: true,
      isSessionCurrent: () =>
          mounted &&
          generation == _resourceGeneration &&
          (authenticated
              ? widget.authService.currentUser?.uid == ownerId
              : widget.authService.currentUser == null),
      chatRepository: chatRepository,
      onLog: kReleaseMode
          ? null
          : (message) => debugPrint('[BLE delivery] $message'),
    );

    final repository = SosRepository(
      database: widget.database,
      cloudService: SosCloudService(firestore: FirebaseFirestore.instance),
      cloudArchiveService: CloudArchiveService(),
      firebaseAuth: FirebaseAuth.instance,
      localOwnerId: authenticated ? null : ownerId,
      onSosCreated: bleCoordinator.enqueueSos,
    );

    final coordinator = SosSyncCoordinator(
      repository: repository,
      firebaseAuth: FirebaseAuth.instance,
    );

    _repositoryOwnerId = ownerId;
    _repository = repository;
    _syncCoordinator = coordinator;
    _bleCoordinator = bleCoordinator;
    if (authenticated) unawaited(coordinator.start());
  }

  Future<void> _startBleOnDemand() {
    final existing = _bleStart;
    if (existing != null) return existing;
    final coordinator = _bleCoordinator;
    if (coordinator == null) return Future<void>.value();
    final operation = () async {
      await _bleTeardown;
      if (!mounted || !identical(_bleCoordinator, coordinator)) return;
      await coordinator.start();
    }();
    _bleStart = operation;
    return operation.whenComplete(() {
      if (identical(_bleStart, operation)) _bleStart = null;
    });
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
      initialData: widget.authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _disposeSyncResources();
          return Scaffold(
            body: Center(child: Text(context.l10n.authStatusUnavailable)),
          );
        }
        final user = widget.authService.currentUser;

        final authenticated = user != null;
        final ownerId = user?.uid ?? guestDeviceOwnerId;
        _ensureResources(ownerId: ownerId, authenticated: authenticated);

        // Replacing the session navigator also closes retained details, maps,
        // chats and dialogs belonging to the previous account.
        return AuthSessionNavigator(
          ownerId: ownerId,
          home: (sessionContext) => SosPage(
            repository: _repository!,
            bleTransport: _bleCoordinator?.transport,
            bleCoordinator: _bleCoordinator,
            chatRepository: _chatRepository,
            onChatMessageCreated: _bleCoordinator?.enqueueChat,
            onBleStartRequested: _startBleOnDemand,
            pendingBleWorkCheck: _bleCoordinator?.hasPendingBleRecovery,
            localeController: widget.localeController,
            isGuest: !authenticated,
            onLoginRequested: () => Navigator.of(sessionContext).push<void>(
              MaterialPageRoute<void>(
                builder: (loginContext) => AuthPage(
                  authService: widget.authService,
                  // Returning to Home is handled by the auth stream underneath.
                  // The callback only closes this optional guest sign-in route.
                  onAuthenticated: () {
                    if (loginContext.mounted &&
                        Navigator.of(loginContext).canPop()) {
                      Navigator.of(loginContext).pop();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
