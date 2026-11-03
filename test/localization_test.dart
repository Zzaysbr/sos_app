import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sos_app/core/localization/language_selector_tile.dart';
import 'package:sos_app/core/localization/locale_controller.dart';
import 'package:sos_app/core/localization/locale_preference_store.dart';
import 'package:sos_app/core/localization/localization.dart';
import 'package:sos_app/l10n/generated/app_localizations_en.dart';
import 'package:sos_app/l10n/generated/app_localizations_th.dart';

class _FailingLocaleStore implements LocalePreferenceStore {
  @override
  Future<Locale?> load() async => null;

  @override
  Future<void> save(Locale locale) => Future<void>.error(StateError('write'));
}

class _LocaleHarness extends StatefulWidget {
  const _LocaleHarness({required this.controller, this.textScale = 1});

  final LocaleController controller;
  final double textScale;

  @override
  State<_LocaleHarness> createState() => _LocaleHarnessState();
}

class _LocaleHarnessState extends State<_LocaleHarness> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: widget.controller.locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    localeResolutionCallback: resolveSupportedLocale,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(widget.textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: LanguageSelectorTile(controller: widget.controller),
      ),
    ),
  );
}

void main() {
  group('locale preference validation', () {
    test('accepts English', () {
      expect(
        PlatformLocalePreferenceStore.parseLanguageCode('en'),
        const Locale('en'),
      );
    });

    test('normalizes and accepts Thai', () {
      expect(
        PlatformLocalePreferenceStore.parseLanguageCode(' TH '),
        const Locale('th'),
      );
    });

    test('invalid stored locale fails safely', () {
      expect(PlatformLocalePreferenceStore.parseLanguageCode('fr'), isNull);
    });

    test('missing stored locale fails safely', () {
      expect(PlatformLocalePreferenceStore.parseLanguageCode(null), isNull);
    });
  });

  group('locale resolution', () {
    const supported = [Locale('en'), Locale('th')];

    test('resolves English region to English', () {
      expect(
        resolveSupportedLocale(const Locale('en', 'GB'), supported),
        const Locale('en'),
      );
    });

    test('resolves Thai region to Thai', () {
      expect(
        resolveSupportedLocale(const Locale('th', 'TH'), supported),
        const Locale('th'),
      );
    });

    test('unsupported system locale falls back to English', () {
      expect(
        resolveSupportedLocale(const Locale('ja'), supported),
        const Locale('en'),
      );
    });

    test('missing system locale falls back to English', () {
      expect(resolveSupportedLocale(null, supported), const Locale('en'));
    });
  });

  group('locale controller persistence', () {
    test('persists English', () async {
      final store = MemoryLocalePreferenceStore();
      final controller = LocaleController(store: store);
      expect(await controller.setLocale(const Locale('en')), isTrue);
      expect(store.value, const Locale('en'));
      expect(store.saveCount, 1);
    });

    test('persists Thai', () async {
      final store = MemoryLocalePreferenceStore();
      final controller = LocaleController(store: store);
      expect(await controller.setLocale(const Locale('th')), isTrue);
      expect(store.value, const Locale('th'));
      expect(controller.locale, const Locale('th'));
    });

    test('rejects unsupported locale without writing', () async {
      final store = MemoryLocalePreferenceStore();
      final controller = LocaleController(store: store);
      expect(await controller.setLocale(const Locale('fr')), isFalse);
      expect(store.saveCount, 0);
      expect(controller.locale, isNull);
    });

    test('selecting the current locale does not write twice', () async {
      final store = MemoryLocalePreferenceStore(const Locale('th'));
      final controller = LocaleController(
        store: store,
        initialLocale: const Locale('th'),
      );
      expect(await controller.setLocale(const Locale('th')), isTrue);
      expect(store.saveCount, 0);
    });

    test('a persisted locale can initialize a new controller', () async {
      final store = MemoryLocalePreferenceStore(const Locale('th'));
      final restored = LocaleController(
        store: store,
        initialLocale: await store.load(),
      );
      expect(restored.locale, const Locale('th'));
    });
  });

  group('localized safety language', () {
    test('English relay copy does not claim final delivery', () {
      final l10n = AppLocalizationsEn();
      expect(l10n.storedOnRelay(1), contains('final delivery is unconfirmed'));
      expect(l10n.nearbyRelayOn, contains('does not become a responder'));
    });

    test('Thai relay copy does not claim final delivery', () {
      final l10n = AppLocalizationsTh();
      expect(l10n.storedOnRelay(1), contains('ยังไม่ยืนยัน'));
      expect(l10n.nearbyRelayOn, contains('ไม่ได้กลายเป็นผู้ช่วยเหลือ'));
    });
  });

  group('language selector', () {
    testWidgets('hot switches English to Thai and persists', (tester) async {
      final store = MemoryLocalePreferenceStore(const Locale('en'));
      final controller = LocaleController(
        store: store,
        initialLocale: const Locale('en'),
      );
      await tester.pumpWidget(_LocaleHarness(controller: controller));
      expect(find.text('Language'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thai').last);
      await tester.pumpAndSettle();

      expect(find.text('ภาษา'), findsOneWidget);
      expect(controller.locale, const Locale('th'));
      expect(store.value, const Locale('th'));
    });

    testWidgets('write failure keeps current language and shows error', (
      tester,
    ) async {
      final controller = LocaleController(
        store: _FailingLocaleStore(),
        initialLocale: const Locale('en'),
      );
      await tester.pumpWidget(_LocaleHarness(controller: controller));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thai').last);
      await tester.pumpAndSettle();

      expect(controller.locale, const Locale('en'));
      expect(find.textContaining('could not be saved'), findsOneWidget);
    });

    for (final locale in [const Locale('en'), const Locale('th')]) {
      testWidgets('${locale.languageCode} selector fits narrow large text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = LocaleController(
          store: MemoryLocalePreferenceStore(locale),
          initialLocale: locale,
        );
        await tester.pumpWidget(
          _LocaleHarness(controller: controller, textScale: 2),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('language-selector')), findsOneWidget);
      });
    }
  });
}
