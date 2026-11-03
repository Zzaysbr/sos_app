# SOS Lifecycle Test Report

## Verification matrix

| Lifecycle | Implementation | Automated Tests | Physical |
|---|---|---|---|
| SOS creation | IMPLEMENTED | PASS (existing SOS/navigation/location suite) | NOT VERIFIED |
| GPS attachment | IMPLEMENTED | PASS (location failure/recovery coverage) | NOT VERIFIED |
| A → B relay | IMPLEMENTED | PASS (HopRelayCoordinator suite) | PASS in prior operator/log evidence |
| B → C relay | IMPLEMENTED | PASS (deterministic three-node relay test) | NOT VERIFIED in this task |
| Rescue Inbox | IMPLEMENTED | PASS (Rescue Inbox and relay tests) | NOT VERIFIED |
| Victim location | IMPLEMENTED | PASS (Incident Map tests) | NOT VERIFIED |
| A → C Chat | IN PROGRESS | Signed envelope contract tests PASS; runtime routing not yet wired | NOT RUN |
| C → A Chat | IN PROGRESS | Signed envelope contract tests PASS; runtime routing not yet wired | NOT RUN |
| Cancel/Resolve | PARTIAL | Existing local lifecycle tests only | NOT VERIFIED |

## Automated validation

- Focused Hop Relay tests: **25 passed**, exit code 0.
- Full Flutter suite: **456 passed**, exit code 0.
- `flutter analyze lib test`: **PASS**, exit code 0.
- `git diff --check`: **PASS**, exit code 0.

## Exact P0 blocker

`SosBleCoordinator.enqueueChat` persists a `SosBleEnvelope.chatMessage` in the direct
BLE outbox. `SosBleCoordinator._handleChatDelivery` persists and acknowledges it at
the first receiver, but there is no authenticated next-hop Chat envelope, durable
relay-job state, or route metadata that can safely distinguish an intermediate relay
from the final recipient. Adding forwarding without those contracts would risk
forged sender identity, wrong-incident delivery, duplicate messages, and false
`delivered` states.

## Q-709 slice completed

`ChatRelayEnvelope` and `RelayCryptography.signChatRelay/verifyChatRelay` provide a
versioned canonical signed payload. The current implementation intentionally does
not claim end-to-end encryption; relay nodes can observe text but cannot alter or
rebind it without invalidating the signature.

## Physical status

No physical tests were run after the lifecycle code change. Prior physical evidence
does not prove bidirectional multi-hop Chat.
