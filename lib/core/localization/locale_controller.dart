import 'package:flutter/material.dart';

import 'locale_preference_store.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({required this.store, Locale? initialLocale})
    : _locale = initialLocale;

  final LocalePreferenceStore store;
  Locale? _locale;

  Locale? get locale => _locale;

  Future<bool> setLocale(Locale locale) async {
    if (!PlatformLocalePreferenceStore.supportedLanguageCodes.contains(
      locale.languageCode,
    )) {
      return false;
    }
    if (_locale?.languageCode == locale.languageCode) return true;
    await store.save(locale);
    _locale = Locale(locale.languageCode);
    notifyListeners();
    return true;
  }
}
