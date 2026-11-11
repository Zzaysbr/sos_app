import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../domain/app_role.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({
    super.key,
    required this.onSelected,
    this.savingRole,
    this.errorText,
  });

  final ValueChanged<AppRole> onSelected;
  final AppRole? savingRole;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final choices = [
              _RoleChoice(
                role: AppRole.needHelp,
                icon: Icons.sos_rounded,
                eyebrow: l10n.needHelpEyebrow,
                title: l10n.needHelpTitle,
                description: l10n.needHelpDescription,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFFFF6B64)
                    : const Color(0xFFB42318),
                background: theme.brightness == Brightness.dark
                    ? const Color(0xFF3A1716)
                    : const Color(0xFFFFEDEA),
              ),
              _RoleChoice(
                role: AppRole.rescue,
                icon: Icons.health_and_safety_rounded,
                eyebrow: l10n.rescueEyebrow,
                title: l10n.rescueTitle,
                description: l10n.rescueDescription,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF90CAF9)
                    : const Color(0xFF1565C0),
                background: theme.brightness == Brightness.dark
                    ? const Color(0xFF0D2A4A)
                    : const Color(0xFFE3F0FF),
              ),
            ];
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                wide ? 56 : 24,
                40,
                wide ? 56 : 24,
                32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.roleQuestion,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.roleInstruction,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (errorText != null) ...[
                        Material(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    errorText!,
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var index = 0;
                              index < choices.length;
                              index++
                            ) ...[
                              Expanded(
                                child: _RoleChoiceCard(
                                  choice: choices[index],
                                  saving: savingRole == choices[index].role,
                                  onTap: savingRole == null
                                      ? () => onSelected(choices[index].role)
                                      : null,
                                ),
                              ),
                              if (index == 0) const SizedBox(width: 20),
                            ],
                          ],
                        )
                      else
                        for (final choice in choices) ...[
                          _RoleChoiceCard(
                            choice: choice,
                            saving: savingRole == choice.role,
                            onTap: savingRole == null
                                ? () => onSelected(choice.role)
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.roleTrustNotice,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleChoice {
  const _RoleChoice({
    required this.role,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.color,
    required this.background,
  });

  final AppRole role;
  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Color color;
  final Color background;
}

class _RoleChoiceCard extends StatelessWidget {
  const _RoleChoiceCard({
    required this.choice,
    required this.saving,
    required this.onTap,
  });

  final _RoleChoice choice;
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: choice.title,
      child: Material(
        color: choice.background,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 270),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(choice.icon, color: choice.color, size: 48),
                  const SizedBox(height: 28),
                  Text(
                    choice.eyebrow,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: choice.color,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    choice.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  Text(choice.description, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      if (saving)
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: choice.color,
                          ),
                        )
                      else ...[
                        Flexible(
                          child: Text(
                            context.l10n.chooseMode,
                            style: TextStyle(
                              color: choice.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, color: choice.color),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
