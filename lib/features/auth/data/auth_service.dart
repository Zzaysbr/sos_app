import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);

    if (password.length < 6) {
      throw const AuthException('Password must contain at least 6 characters.');
    }

    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error.code));
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);

    if (password.isEmpty) {
      throw const AuthException('Password is required.');
    }

    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseError(error.code));
    }
  }

  Future<void> resetPassword({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    _validateEmail(normalizedEmail);
    try {
      // Firebase owns the reset token, expiry and email-ownership proof. The
      // token is never handled or logged by the app.
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      // Keep the UI non-enumerating even when a project has not enabled
      // Firebase's account-enumeration protection yet.
      if (error.code == 'user-not-found') return;
      throw AuthException(_mapFirebaseError(error.code));
    }
  }

  Future<void> logout() => _firebaseAuth.signOut();

  String _normalizeEmail(String email) => email.trim();

  void _validateEmail(String email) {
    if (email.isEmpty || !email.contains('@')) {
      throw const AuthException('Enter a valid email address.');
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'operation-not-allowed':
      case 'invalid-action-code':
        return 'Password recovery is not enabled for this project.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
