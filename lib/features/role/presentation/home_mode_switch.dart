import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import '../domain/app_role.dart';

/// Compact icon-only mode toggle; current mode remains available to readers.
class HomeModeSwitch extends StatelessWidget {
  const HomeModeSwitch({super.key, required this.role, this.onChanged});
  final AppRole role;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final rescue = role == AppRole.rescue;
    final thai = Localizations.localeOf(context).languageCode == 'th';
    final colors = Theme.of(context).colorScheme;
    final label = rescue
        ? (thai ? 'โหมดกู้ภัย' : 'Rescue mode')
        : (thai ? 'โหมดขอความช่วยเหลือ' : 'Need help mode');
    final hint = rescue
        ? context.l10n.switchToNeedHelp
        : context.l10n.switchToRescue;
    final active = rescue ? const Color(0xFF1565C0) : const Color(0xFFD92323);
    return Tooltip(
      message: hint,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        hint: hint,
        toggled: rescue,
        enabled: onChanged != null,
        onTap: onChanged,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 100,
            height: 52,
            child: Material(
              color: Color.alphaBlend(
                active.withValues(alpha: rescue ? 0.20 : 0.10),
                colors.surfaceContainerHighest,
              ),
              shape: StadiumBorder(
                side: BorderSide(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onChanged,
                customBorder: const StadiumBorder(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            size: 24,
                            color: colors.onSurfaceVariant,
                          ),
                          Icon(
                            Icons.health_and_safety_outlined,
                            size: 24,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: AnimatedAlign(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          alignment: rescue
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surface,
                              border: Border.all(color: colors.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.18),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              rescue
                                  ? Icons.health_and_safety_outlined
                                  : Icons.sos_rounded,
                              size: 28,
                              color: onChanged == null
                                  ? colors.outline
                                  : active,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
