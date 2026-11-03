# Phase 8 Thai/English Localization Implementation

Date: 2 November 2026  
Baseline branch: `main`  
Baseline HEAD: `af6efe2cf4133de2c340d3cd374f9ee944d5b163`

## Status

The application now uses Flutter's official generated-localization stack for
English (`en`) and Thai (`th`). Emergency-critical and main product flows use
generated `AppLocalizations` strings, the Settings screen can switch language
without an application restart, and the selected language is persisted by a
small native preference channel on Android and iOS.

This work does not change SOS, Chat, Location Sharing, BLE, Relay v2, database,
Firebase, ownership or Guest-isolation semantics. Option A remains in force:
Relay v2 is hop-only and Final Delivery v3 remains deferred.

## Architecture

- `l10n.yaml` configures Flutter `gen-l10n` with English as the template.
- `lib/l10n/app_en.arb` and `lib/l10n/app_th.arb` are the maintained resources.
- Generated classes are emitted under `lib/l10n/generated/` and are not edited
  manually.
- `LocaleController` owns the runtime locale and changes it without rebuilding
  repositories, database connections or BLE coordinators.
- `PlatformLocalePreferenceStore` uses `sos_app/preferences` to read and write
  only the supported language codes `en` and `th`.
- Android stores the preference in application `SharedPreferences`; iOS stores
  it in `UserDefaults`. Missing, invalid and failed reads fall back safely.
- Unsupported system locales resolve to English. When there is no saved value,
  the supported system locale is used; otherwise English is selected.
- The persisted locale is loaded before `runApp`, avoiding a normal-startup
  flash of the wrong language.

## Localized scope

The generated resources are wired into startup, authentication, role
selection, Home, SOS creation, active SOS, History, SOS Details, Chat, BLE
recipient selection, Relay consent/status, Location Sharing, Map/offline-map
states, Account, Settings, notifications and Relay Diagnostics. Error, empty,
loading, confirmation, tooltip and accessibility text touched in these flows
uses the selected locale. Dates and times in Chat, Location Sharing, Map and
Relay Diagnostics use Flutter `MaterialLocalizations`.

BLE Test controls, safety guidance and empty states are localized. Technical
diagnostic values and machine state names remain unchanged because they are
developer evidence rather than product copy; protocol identifiers, raw
diagnostic state and machine-readable errors are intentionally not translated.
The production Relay Diagnostics route remains unavailable in Release builds.

## Terminology safeguards

- “SOS created” means the incident was persisted locally.
- Native write completion is not translated as delivery confirmation.
- “Stored on relay” means a relay durably accepted the envelope and always
  remains explicitly separate from final delivery.
- A hop receipt is not described as responder persistence or human acceptance.
- Neither locale claims that help is on the way or assistance was dispatched.
- Relay-only records remain outside normal SOS History.

## Persistence and failure behavior

- Selecting Thai or English persists before the controller publishes the new
  locale.
- A failed preference write leaves the current UI language unchanged and shows
  a localized error.
- Duplicate selection does not write again.
- Invalid stored values are ignored; unsupported locales resolve to English.
- Language switching does not clear navigation, SOS History, Chat, Relay state,
  account state or Guest data.

## Accessibility and responsive coverage

Automated widget coverage verifies the language selector at 320 px width and
2.0 text scale in both locales, accessible selector labels, hot switching,
critical Relay safety wording and existing SOS/Chat/Map responsive flows.
Translated text wraps rather than using smaller emergency-action fonts.

Physical Thai/English layout validation on Android, iPhone and iPad is **NOT
RUN** for this change. Automated layout success is not physical-device
evidence.

## Tests added or updated

`test/localization_test.dart` contains 19 focused tests covering supported and
invalid language codes, locale resolution, English fallback, preference
persistence/restoration, write failure, hot switching, Relay safety semantics,
large text and narrow layouts. Existing Auth, role UX, map, local history and
Relay Diagnostics widget tests were made deterministic for their intended
locale without weakening behavioral assertions.

## Validation evidence

Executed from the current dirty working tree on 2 November 2026:

- `flutter gen-l10n`: PASS, exit 0.
- Broad focused localization/SOS/Chat/Location/Map/Relay Diagnostics widget
  set: PASS, 79 tests, exit 0. After the final localized map-error adjustment,
  the affected localization/Map/Relay Diagnostics subset also passed 41
  tests, exit 0. The final localization/BLE Test/Relay Diagnostics subset
  passed 43 tests, exit 0.
- `flutter test --reporter compact`: PASS, 410 tests, exit 0.
- `flutter analyze lib test`: PASS, no issues, exit 0.
- `git diff --check`: PASS, exit 0.

The full-suite output contains the repository's existing Drift multiple-test-
database warnings and synthetic failure logs exercised by negative tests; the
test command itself completed successfully.

## Files introduced for localization

- `l10n.yaml`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_th.arb`
- `lib/l10n/generated/`
- `lib/core/localization/localization.dart`
- `lib/core/localization/locale_controller.dart`
- `lib/core/localization/locale_preference_store.dart`
- `lib/core/localization/language_selector_tile.dart`
- `test/localization_test.dart`

Existing presentation, startup, native preference bridge, package manifest and
locale-sensitive tests were updated in place. Pre-existing dirty Relay, map,
UX and documentation work was preserved and was not staged or committed.

## Remaining release blockers

Localization alone does not open the Release Gate. Production map
configuration/live validation, signed Android and iOS distribution artifacts,
the outstanding physical reliability/range matrix, and the documented
production trust/operational dependencies remain unresolved. Final Delivery v3
is still not implemented.
