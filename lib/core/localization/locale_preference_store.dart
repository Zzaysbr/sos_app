import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract interface class LocalePreferenceStore {
  Future<Locale?> load();

  Future<void> save(Locale locale);
}

class PlatformLocalePreferenceStore implements LocalePreferenceStore {
  const PlatformLocalePreferenceStore();

  static const _channel = MethodChannel('sos_app/preferences');
  static const supportedLanguageCodes = {'en', 'th'};

  @override
  Future<Locale?> load() async {
    final languageCode = await _channel.invokeMethod<String>(
      'getPreferredLanguage',
    );
    return parseLanguageCode(languageCode);
  }

  @override
  Future<void> save(Locale locale) {
    if (!supportedLanguageCodes.contains(locale.languageCode)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported locale');
    }
    return _channel.invokeMethod<void>(
      'setPreferredLanguage',
      locale.languageCode,
    );
  }

  static Locale? parseLanguageCode(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (!supportedLanguageCodes.contains(normalized)) return null;
    return Locale(normalized!);
  }
}

class MemoryLocalePreferenceStore implements LocalePreferenceStore {
  MemoryLocalePreferenceStore([this.value]);

  Locale? value;
  int saveCount = 0;

  @override
  Future<Locale?> load() async => value;

  @override
  Future<void> save(Locale locale) async {
    value = locale;
    saveCount++;
  }
}
