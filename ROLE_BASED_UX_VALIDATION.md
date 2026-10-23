# Role-Based UX Validation

Date: 23 October 2026

## Automated matrix

| Check | Result | Evidence |
|---|---|---|
| First role selection and local persistence | PASS | `role_based_ux_test.dart` |
| Light/Dark rebuild with persisted Rescue role | PASS | `role_based_ux_test.dart` |
| Active-incident switch warning and data retention | PASS | `role_based_ux_test.dart` |
| Own active SOS duplicate prevention | PASS | `role_based_ux_test.dart` |
| Incoming SOS does not block own SOS | PASS | `role_based_ux_test.dart` |
| Repeated/concurrent Rescue accept protection | PASS | `role_based_ux_test.dart` |
| BLE persistence is not shown as human acknowledgement | PASS | `role_based_ux_test.dart` |
| Guest local history and details | PASS | `local_device_history_test.dart` |
| BLE listener starts before native interaction | PASS | `ble_start_order_test.dart` |
| Inbox/outbox deduplication and peer validation | PASS | `ble_delivery_repository_test.dart` |
| Existing full Flutter regression suite | PASS | 220 tests |
| Physical role journeys on Android/iOS | NOT RUN | No new device session was performed for this UI change |

## Command results

| Command | Exit code | Result |
|---|---:|---|
| Focused Role/Guest/BLE suite | 0 | 35 tests passed |
| `flutter test` | 0 | 220 tests passed |
| `flutter analyze lib test` | 0 | No issues found |
| `flutter build apk --debug --no-pub` | 0 | `build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build ios --debug --no-codesign --no-pub` | 0 | `build/ios/iphoneos/Runner.app`; unsigned |
| `git diff --check` | 0 | No whitespace errors |

The test output includes existing Drift multiple-database warnings in migration/restart fixtures and the `flutter_map` OSM development warning. Neither command failed. Public OSM fallback remains prohibited for release.

## Release decision

The role UX implementation is source-validated, but the overall Release Gate remains **BLOCKED**. This work does not replace required physical reliability evidence, an owner-configured production map provider or signed Android/iOS release artifacts.
