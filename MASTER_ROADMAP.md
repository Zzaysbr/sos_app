# OFF_GRID_SOS Master Roadmap

Status: APPROVED — MVP FIRST  
Version: 1.0  
Last updated: 3 November 2026

## Product direction

`off_grid_sos` prioritizes fast SOS creation, local persistence, BLE offline
communication, location/map usefulness, safe synchronization, truthful status,
privacy, accessibility and security. A phase is not complete merely because
code exists; acceptance evidence and regression tests are required.

## Phases

| Phase | Scope | Status |
|---|---|---|
| 1 | Foundation, architecture, dependencies, theme | IMPLEMENTED — validation baseline required |
| 2 | Firebase Auth, guest mode, ownership, recovery | IMPLEMENTED WITH SECURITY LIMITATIONS |
| 3 | SOS creation, persistence, history, location | IMPLEMENTED — regression validation required |
| 4 | BLE discovery, Chat, ACK, retry, dedupe | IMPLEMENTED — reliability validation required |
| 5 | Location Sharing and maps | IMPLEMENTED — provider/delivery validation required |
| 6 | Drift, Firestore, ownership, guest isolation | IMPLEMENTED — isolation validation required |
| 7 | SOS/Chat/BLE integration and delivery integrity | IN PROGRESS |
| 8 | Security, UX, accessibility and QA | IN PROGRESS |
| 9 | Signed MVP release and deployment | BLOCKED |

## Non-negotiable decisions

- Guest data remains local and isolated.
- BLE recipient and transport identities remain explicitly bound.
- ACK, retry and deduplication semantics must not be weakened.
- Relay v2 is foreground-only, consent-gated, signed and hop-only.
- Hop receipts never mean responder delivery or human assistance.
- Password recovery must not treat email ownership as MFA.
- Current password recovery is fail-closed until a trusted backend exists.
- Production map provider, attribution, signing and physical validation remain
  release gates.

## Active quests

- Q-701 Chat sender/transport identity binding — VERIFY/FIX AS NEEDED
- Q-702 Location recipient identity and ACK — VERIFY/FIX AS NEEDED
- Q-703 BLE lifecycle/stale callbacks — VERIFY/FIX AS NEEDED
- Q-704 SOS delivery state consistency — VERIFY/FIX AS NEEDED
- Q-801 Password recovery security boundary — HARDENED; backend still blocked
- Q-802 Trusted backend and genuine MFA recovery — BLOCKED
- Q-803 Accessibility and UX hardening — IN PROGRESS
- Q-804 Automated regression coverage — IN PROGRESS
- Q-805 Map provider readiness — BLOCKED UNTIL VERIFIED
- Q-806 Guest/account isolation — VERIFY
- Q-901 MVP release acceptance — BLOCKED

## Release decision

The MVP Release Gate remains **BLOCKED** until physical BLE evidence, map
provider verification, signing/provisioning, configuration and critical
security/data-integrity gates are complete. Historical progress `78.5%` and
Level 7 are not recalculated as EXP because the exact ledger balance is unknown.
