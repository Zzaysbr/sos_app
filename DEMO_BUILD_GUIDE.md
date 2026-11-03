# off_grid_sos — Free Device Demo Build Guide

This guide targets direct physical-device demonstration. It does not produce a
store-distributable Android AAB or iOS IPA.

## Android Debug

```bash
flutter build apk --debug --dart-define-from-file=config/production.json
adb -s <ANDROID_SERIAL> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <ANDROID_SERIAL> shell monkey -p com.n1cxltine.sosapp 1
```

`install -r` updates the existing package without uninstalling or clearing its
data. The Debug keystore is acceptable for this demo only; it must never be
used as Release signing evidence.

## iOS Development / Personal Team

1. In Xcode, sign in to the owner's Apple ID and select the available Personal
   Team for the Runner target. Keep the existing Bundle ID unless Xcode reports
   that free provisioning cannot support it.
2. Ensure the physical iPhone is unlocked, trusted and has Developer Mode
   enabled.
3. Build with the existing development workflow:

```bash
flutter build ios --debug --dart-define-from-file=config/production.json
xcrun devicectl device install app --device <DEVICE_ID> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <DEVICE_ID> com.n1cxltine.sosapp
```

Open the app from the Home Screen and verify the session, local SOS history and
Chat remain present. Do not uninstall or clear data.

## Provisioning renewal

Free development provisioning expires and may need renewal/reinstallation.
Refresh signing in Xcode for the owner's Personal Team, rebuild, and repeat the
update-in-place install. Never export private keys or put provisioning secrets
in Git.

The current physical-demo evidence records successful Profile installation and
Home Screen launch on Samsung SM-A536E, iPhone 15 Plus and iPad Air 11-inch
(M2). Feature-level BLE/SOS/Location acceptance remains governed by the
separate physical test records.

## Scope boundaries

Android Release keystore, signed AAB, Apple Distribution certificate/profile,
TestFlight and App Store submission belong to the future Store Distribution
Gate. They remain intentionally unresolved.
