# Role-Based UX Audit

Date: 23 October 2026

## Decision

The app now asks the user to choose one locally persisted operating mode:

- **Need Help** — emergency action, own incident status, history, incident chat and location sharing.
- **Rescue** — BLE listening, received incident triage, locally accepted work and incident communication.

The visual direction is **Calm & Decisive**, with system Light/Dark support. Need Help uses a restrained emergency red; Rescue uses green/blue. Every mode distinction also uses text, icons and navigation labels, so color is never the only signal.

## Previous state

`SosPage` exposed one shared navigation model. Sending, history, chat, settings and BLE debug tools were available, but the primary intent was not explicit. A receiver could open incoming incidents, yet there was no dedicated responder journey and BLE persistence wording could be read as a human response.

The existing repositories already provided the correct safety boundaries:

- SOS queries are scoped to the current session owner.
- Guest device history is a separate explicit query.
- BLE inbox/outbox rows preserve message and incident identity.
- Chat and Location reuse the existing incident route and selected peer.
- Cloud sync excludes the Guest owner.

These boundaries were retained.

## Implemented behavior

### Role selection and persistence

The first role choice is explicit, accessible and responsive. Android stores `preferred_role` in app-private `SharedPreferences`; iOS stores `sos.preferredRole.v1` in `UserDefaults`. Only `needHelp` and `rescue` are accepted. The preference contains no account secret and does not change Firebase auth, record ownership or BLE identity.

Switching roles is always available. When the current owner has an active incident, a confirmation sheet states that switching does not cancel the incident, delete data or stop the durable BLE queue. The scoped active-incident check validates the current auth session again before returning data.

### Need Help

- The emergency action remains the dominant control and retains its hold gesture.
- An existing active SOS opens instead of creating another own incident.
- Received incidents do not block the user from creating their own SOS.
- History, local-device history, details, Chat, Location and map reuse the existing repositories and routes.
- BLE application ACK is described as persistence on the receiver device. The UI explicitly does not infer a human acknowledgement.

### Rescue

- The landing screen starts BLE listening only after an explicit action; role selection does not request Bluetooth permission.
- Incoming incidents are the intersection of the current owner-scoped SOS query and durable BLE delivery inbox IDs. Inbox origin is never treated as authorization.
- Items show freshness and warn when their snapshot is older than 15 minutes.
- “Accept” is local session workflow state. Repeated and concurrent taps are idempotent.
- The UI states that local acceptance is neither exclusive assignment nor a response sent to the person requesting help.
- Rescue can open incident details, Chat, Location and map. It cannot resolve or cancel the sender's incident.
- Empty states do not invent responders, incidents or network availability.

## Data, auth and protocol impact

- No database schema or migration.
- No Firebase Rules or ownership change.
- No BLE UUID, frame, production message kind or ACK semantic change.
- No dependency change.
- No automatic Guest merge or Guest cloud upload.
- No ownership transfer during role, login, logout or account transitions.
- Stable SOS/message IDs and durable outbox/inbox states remain unchanged.

## Accessibility and resilience

- Interactive theme controls use a minimum 48 px target.
- Role cards expose button semantics and descriptive text.
- Light and Dark themes use semantic Material color roles.
- Role preference read/write failures remain visible and retryable.
- The wide role layout shrink-wraps safely inside a vertical scroll view.

## Known limits

- Rescue acceptance is local and lasts for the current app process. Persisted or shared assignment needs a separately designed ownership/coordination model and is deliberately not implied.
- The current protocol confirms durable application receipt, not that a human saw or accepted an incident.
- Nearby ordering is based on received time because RSSI and reliable responder distance are not available as incident truth.
- Physical role-flow validation has not been run for this change. Existing Phase 7 BLE evidence remains historical evidence for the underlying transport only.
- Production map configuration, remaining physical reliability tests and signed release validation remain release blockers.

## Files introduced or materially changed

- `lib/core/theme/app_theme.dart`
- `lib/features/role/domain/app_role.dart`
- `lib/features/role/domain/role_workflow_controller.dart`
- `lib/features/role/data/role_preference_store.dart`
- `lib/features/role/presentation/role_selection_page.dart`
- `lib/features/sos/presentation/sos_page.dart`
- `lib/features/sos/data/sos_repository.dart`
- `lib/features/nearby_ble/data/ble_delivery_repository.dart`
- `android/app/src/main/kotlin/com/example/sos_app/MainActivity.kt`
- `ios/Runner/AppDelegate.swift`
- `lib/main.dart`
- `.impeccable.md` and `CLAUDE.md`
