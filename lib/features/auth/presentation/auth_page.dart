import 'package:flutter/material.dart';

import 'dart:async';

import '../../../core/localization/localization.dart';
import '../data/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.authService, this.onAuthenticated});

  final AuthService authService;
  final VoidCallback? onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isResetMode = false;
  bool _resetSuccess = false;
  bool _resetLoading = false;
  String? _resetError;
  String? _emailError;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isRegister) {
        await widget.authService.register(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) widget.onAuthenticated?.call();
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error, stackTrace) {
      debugPrint('Authentication failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.authFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_resetLoading || _resendCooldown > 0) return;
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = context.l10n.enterValidEmail);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _resetLoading = true;
      _resetError = null;
      _emailError = null;
    });

    try {
      await widget.authService.resetPassword(email: email);

      if (!mounted) return;
      setState(() {
        _resetSuccess = true;
        _resetLoading = false;
      });
      _startCooldown();
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _resetError = _friendlyResetError(error.message);
        _resetLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Password reset failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _resetError = 'Unable to send the reset email. Check your connection and try again.';
        _resetLoading = false;
      });
    } finally {
      if (mounted && _resetLoading) setState(() => _resetLoading = false);
    }
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  String _friendlyResetError(String message) {
    if (message.contains('not configured')) {
      return context.l10n.passwordRecoveryUnavailable;
    }
    if (message.contains('Too many')) {
      return 'Too many requests. Please wait before trying again.';
    }
    if (message.contains('Network')) {
      return 'Network error. Check your connection and try again.';
    }
    if (message.contains('valid email')) return message;
    return 'Unable to send the reset email. Please try again.';
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _openResetMode() => setState(() {
    _isResetMode = true;
    _resetSuccess = false;
    _resetError = null;
    _emailError = null;
  });

  void _backToLogin() => setState(() {
    _isResetMode = false;
    _resetSuccess = false;
    _resetError = null;
    _emailError = null;
    _resendCooldown = 0;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _isRegister ? l10n.createAccount : l10n.login;
    final action = _isRegister ? l10n.register : l10n.login;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isResetMode ? l10n.resetPassword : title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_isResetMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.resetPasswordDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_resetSuccess) _buildResetSuccess(context),
                    if (_resetError != null) _buildResetError(context),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l10n.email,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                  ),
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _emailError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (!_isResetMode) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_isResetMode)
                    FilledButton.icon(
                      onPressed: _resetLoading || _resendCooldown > 0
                          ? null
                          : _resetPassword,
                      icon: _resetLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.mail_outline),
                      label: Text(
                        _resetLoading
                            ? l10n.sendingResetLink
                            : l10n.sendResetLink,
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: Text(_isLoading ? l10n.pleaseWait : action),
                    ),

                  if (!_isRegister && !_isResetMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _openResetMode,
                        child: Text(l10n.forgotPassword),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_isResetMode)
                    TextButton(
                      onPressed: _resetLoading ? null : _backToLogin,
                      child: Text(l10n.backToLogin),
                    )
                  else
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isRegister = !_isRegister;
                              });
                            },
                      child: Text(
                        _isRegister
                            ? l10n.alreadyHaveAccount
                            : l10n.createNewAccount,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResetSuccess(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.mark_email_read_outlined, size: 42),
          const SizedBox(height: 8),
          Text(
            context.l10n.checkEmail,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(context.l10n.resetEmailPrivacy(_emailController.text.trim())),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _resendCooldown > 0 || _resetLoading
                ? null
                : _resetPassword,
            child: Text(
              _resendCooldown > 0
                  ? context.l10n.resendIn(_resendCooldown)
                  : context.l10n.resendEmail,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildResetError(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(_resetError!)),
          TextButton(
            onPressed: _resetLoading ? null : _resetPassword,
            child: Text(context.l10n.tryAgain),
          ),
        ],
      ),
    ),
  );
}
