import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'sos_repository.dart';

class SosSyncCoordinator with WidgetsBindingObserver {
  SosSyncCoordinator({
    required this._repository,
    FirebaseAuth? firebaseAuth,
    Connectivity? connectivity,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _connectivity = connectivity ?? Connectivity();

  final SosRepository _repository;
  final FirebaseAuth _firebaseAuth;
  final Connectivity _connectivity;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<void>? _syncFuture;

  bool _started = false;
  bool _syncRequested = false;
  Future<void>? _disposeFuture;

  Future<void> start() async {
    if (_started) return;
    if (_disposeFuture != null) {
      throw StateError('A disposed coordinator cannot be restarted.');
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _authSubscription = _firebaseAuth.authStateChanges().listen(
      (user) {
        if (user != null) _requestSync();
      },
      onError: (Object error, StackTrace stackTrace) {
        _logError('Authentication stream failed', error, stackTrace);
      },
    );

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        if (_hasNetwork(results)) _requestSync();
      },
      onError: (Object error, StackTrace stackTrace) {
        _logError('Connectivity stream failed', error, stackTrace);
      },
    );

    _requestSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _firebaseAuth.currentUser != null) {
      _requestSync();
    }
  }

  void _requestSync() {
    if (!_started || _firebaseAuth.currentUser == null) return;

    _syncRequested = true;
    if (_syncFuture != null) return;

    final future = _drainSyncRequests();
    _syncFuture = future;
    unawaited(future);
  }

  Future<void> _drainSyncRequests() async {
    try {
      while (_syncRequested && _started) {
        _syncRequested = false;
        if (_firebaseAuth.currentUser == null) continue;

        try {
          await _repository.syncPending();
        } catch (error, stackTrace) {
          _logError('SOS sync failed', error, stackTrace);
        }
      }
    } finally {
      _syncFuture = null;

      if (_syncRequested && _started) {
        _requestSync();
      }
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  void _logError(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('$message: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    _started = false;
    _syncRequested = false;

    WidgetsBinding.instance.removeObserver(this);

    await _authSubscription?.cancel();
    await _connectivitySubscription?.cancel();

    _authSubscription = null;
    _connectivitySubscription = null;

    // Wait for an active sync before releasing this coordinator.
    await _syncFuture;
  }
}
