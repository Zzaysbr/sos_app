import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.emailVerified) return;

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('Verification email failed: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to send verification email. Try again later.'),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Verification email failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;

    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No email address is associated with this account.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('Password reset failed: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to send password reset email. Please try again later.',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Password reset failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to use this account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await AuthService().logout();

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('Sign out failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'No email available';
    final initial = (user?.email?.isNotEmpty ?? false)
        ? user!.email![0].toUpperCase()
        : '?';
    final verified = user?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('My account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: colors.primaryContainer,
                      foregroundColor: colors.onPrimaryContainer,
                      child: Text(
                        initial,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'My account',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage your account and security settings.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildSettingsSection(
              title: 'ACCOUNT DETAILS',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 2),
                  child: Column(
                    children: [
                      _buildProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                      ),
                      _buildProfileRow(
                        icon: Icons.fingerprint,
                        label: 'User ID',
                        value: user?.uid ?? 'Unknown',
                      ),
                      _buildProfileRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Email verified',
                        value: verified ? 'Yes' : 'No',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildSettingsSection(
              title: 'ACCOUNT',
              children: [
                _buildSettingsTile(
                  icon: Icons.lock_reset_outlined,
                  title: 'Reset password',
                  subtitle: 'Send a password reset link by email',
                  onTap: _sendPasswordReset,
                ),
              ],
            ),
            if (user != null && !verified) ...[
              const SizedBox(height: 28),
              _buildSettingsSection(
                title: 'VERIFICATION',
                children: [
                  _buildSettingsTile(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Verify email address',
                    subtitle: 'Send a verification link to your email',
                    onTap: _sendVerificationEmail,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            _buildSettingsSection(
              title: 'SECURITY',
              children: [
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Sign out',
                  subtitle: 'Sign out from this device',
                  isDestructive: true,
                  onTap: _signOut,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    final color = isDestructive ? colors.error : colors.onSurface;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 28,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: isDestructive ? colors.error : colors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ],
    );
  }

  Widget _buildProfileRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
