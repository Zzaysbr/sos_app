import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.verificationSent)));
    } on FirebaseAuthException catch (error, stackTrace) {
      debugPrint('Verification email failed: ${error.code}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.verificationFailed)));
    } catch (error, stackTrace) {
      debugPrint('Verification email failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;

    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.noAccountEmail)));
      return;
    }

    try {
      await AuthService().resetPassword(email: email.trim());

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.passwordResetSent)));
    } on AuthException catch (error) {
      if (!mounted) return;
      final message = error.message.contains('not configured')
          ? context.l10n.passwordRecoveryUnavailable
          : context.l10n.passwordResetFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error, stackTrace) {
      debugPrint('Password reset failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.genericError)));
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      useRootNavigator: false,
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.signOutQuestion),
          content: Text(l10n.signOutWarning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.signOut),
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

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.signOutFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? l10n.noEmailAvailable;
    final initial = (user?.email?.isNotEmpty ?? false)
        ? user!.email![0].toUpperCase()
        : '?';
    final verified = user?.emailVerified ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myAccount)),
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
                      l10n.myAccount,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.manageAccount,
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
              title: l10n.accountDetails,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 2),
                  child: Column(
                    children: [
                      _buildProfileRow(
                        icon: Icons.email_outlined,
                        label: l10n.email,
                        value: email,
                      ),
                      _buildProfileRow(
                        icon: Icons.fingerprint,
                        label: l10n.userId,
                        value: user?.uid ?? l10n.unknown,
                      ),
                      _buildProfileRow(
                        icon: Icons.verified_user_outlined,
                        label: l10n.emailVerified,
                        value: verified ? l10n.yes : l10n.no,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildSettingsSection(
              title: l10n.account,
              children: [
                _buildSettingsTile(
                  icon: Icons.lock_reset_outlined,
                  title: l10n.resetPassword,
                  subtitle: l10n.resetPasswordByEmail,
                  onTap: _sendPasswordReset,
                ),
              ],
            ),
            if (user != null && !verified) ...[
              const SizedBox(height: 28),
              _buildSettingsSection(
                title: l10n.verification,
                children: [
                  _buildSettingsTile(
                    icon: Icons.mark_email_read_outlined,
                    title: l10n.verifyEmail,
                    subtitle: l10n.verifyEmailDescription,
                    onTap: _sendVerificationEmail,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            _buildSettingsSection(
              title: l10n.security,
              children: [
                _buildSettingsTile(
                  icon: Icons.logout_rounded,
                  title: l10n.signOut,
                  subtitle: l10n.signOutDescription,
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
