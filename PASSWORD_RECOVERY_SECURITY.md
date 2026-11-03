# Password Recovery Security

## Current architecture

The app uses `firebase_auth` `^6.7.0` for email/password registration,
sign-in, sign-out and the existing password-reset UI. Firebase is initialized
from the committed FlutterFire configuration for project `sos-app-d811a`.
No Cloud Function or trusted recovery backend exists in this repository.

## Security decision

Firebase `sendPasswordResetEmail` proves control of an email link, but the
client SDK does not provide a way to bind that reset code to an independently
verified second factor and a server-side recovery transaction. Firebase MFA
APIs in the installed SDK support sign-in/enrollment flows; they do not make an
email password-reset flow two-factor by themselves.

The app therefore fails closed for password recovery: `AuthService.resetPassword`
does not send an email-only reset request until a trusted backend is deployed.
The Forgot Password screen and the Account screen both route through this
policy; neither calls Firebase's email-reset endpoint directly. The UI reports
that secure recovery is not configured and never presents email ownership as
two-factor authentication.

## Implemented coordinator

`PasswordRecoveryCoordinator` models a short-lived transaction with:

- normalized email input and an opaque transaction ID;
- a ten-minute expiry and five-attempt lockout;
- separate email and second-factor proof slots;
- transaction and factor binding checks on backend-issued proofs;
- password-change rejection until both proofs are present;
- one-time completion that invalidates stored proofs and prevents replay;
- fail-closed behavior when no backend is configured.

The coordinator never accepts a client-provided `verified: true` flag. Proofs
must be issued by `PasswordRecoveryBackend`, which is intentionally unavailable
in the current build. A proof returned for a different transaction is rejected
before it can advance state.

## Required production backend

An owner-controlled HTTPS Cloud Function or equivalent trusted service must:

1. create a server-side recovery transaction without account enumeration;
2. send/verify the Firebase email action code;
3. challenge an enrolled Firebase MFA factor (TOTP or phone, subject to
   Firebase Console support and account policy);
4. bind both successful proofs to the same Firebase UID and transaction;
5. enforce expiry, one-time use, replay protection, rate limits and attempt
   limits atomically;
6. perform the password change using an approved Firebase Admin flow without
   exposing service-account credentials to Flutter; and
7. invalidate all outstanding transaction state after success.

No OTP secret, recovery code, password, service credential or reusable token
may be stored in Drift, SharedPreferences/UserDefaults, logs or client code.

## Firebase Console prerequisites

The owner must verify the project, enable the chosen MFA provider, enroll test
accounts, configure authorized domains/action links, deploy the backend and
configure HTTPS environment secrets. Billing, phone-number policy, abuse
controls and regional data requirements must be reviewed before enabling the
flow. These prerequisites were not changed or deployed by this task.

## Validation

`test/password_recovery_test.dart` covers valid/invalid factors, expiry,
replay, transaction/account binding, rate limiting, duplicate starts, password
gating, unavailable backend behavior and the legacy Firebase email-reset bypass.
The current focused auth/recovery set passes 21 tests; the full Flutter suite
passes 434 tests and `flutter analyze lib test` reports no issues. These are
unit/widget tests of the client state boundary; they are not evidence of a
deployed Firebase security boundary.

Production password recovery remains **BLOCKED** until the trusted backend and
real Firebase MFA configuration are deployed and tested with emulator and
authorized project accounts.
