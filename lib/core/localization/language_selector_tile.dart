import 'dart:async';

import 'package:flutter/material.dart';

import 'locale_controller.dart';
import 'localization.dart';

class LanguageSelectorTile extends StatefulWidget {
  const LanguageSelectorTile({super.key, required this.controller});

  final LocaleController controller;

  @override
  State<LanguageSelectorTile> createState() => _LanguageSelectorTileState();
}

class _LanguageSelectorTileState extends State<LanguageSelectorTile> {
  bool _saving = false;
  String? _error;

  Future<void> _select(String? languageCode) async {
    if (languageCode == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.controller.setLocale(Locale(languageCode));
      if (!saved && mounted) {
        setState(() => _error = context.l10n.languageSaveFailed);
      }
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.languageSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: const ValueKey('language-selector'),
          contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          minLeadingWidth: 28,
          leading: const Icon(Icons.language_outlined),
          title: Text(
            l10n.language,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(_error ?? l10n.languageDescription),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(56, 2, 16, 12),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('language-dropdown'),
            initialValue: Localizations.localeOf(context).languageCode,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            onChanged: _saving ? null : (value) => unawaited(_select(value)),
            items: [
              DropdownMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
              DropdownMenuItem(value: 'th', child: Text(l10n.languageThai)),
            ],
          ),
        ),
      ],
    );
  }
}
