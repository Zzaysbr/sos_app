# Solo Developer Roadmap: Trusted Responder and Final Delivery

Prepared: 2 November 2026 (Asia/Bangkok)

Status: **DEPENDENCY-GATED ROADMAP — NO IMPLEMENTATION AUTHORIZED**

The owner-approved current path is Option A: retain Direct BLE v1 and hop-only
Relay v2. Final Delivery v3 is deferred and may begin only after trust-authority
and responder-enrollment prerequisites are real, documented, and separately
approved.

## Roadmap rules

- Preserve current BLE UUIDs and Direct v1/Relay v2 wire behavior.
- Never reinterpret native writes or hop receipts as final persistence.
- Never infer responder eligibility from Firebase, BLE, Rescue mode, proximity,
  or a self-signed Relay key.
- Keep all new protocol work capability/version gated and disabled by default.
- Separate automated evidence from physical evidence.
- No phase may bypass an unmet external dependency.

## Phase 0 — Design decisions and threat-model closure

### P0.1 Owner decision register

- Scope: TRD-001 was approved on 2 November 2026. Review every remaining entry
  in `TRUSTED_RESPONDER_OWNER_DECISIONS.md`; record explicit
  approval/defer/block decisions with dates.
- Dependencies: Owner review.
- Expected files/modules: documentation only.
- Automated tests: none.
- Physical tests: none.
- Security risks: ambiguous decisions become accidental protocol policy.
- Completion criteria: all P0 entries have explicit owner status; none inferred.
- External infrastructure: none.

### P0.2 Correct delayed-receipt time semantics

- Scope: Specify credential/status validity at persistence time and separate
  receipt-arrival expiry, revocation effective time, skew and clock rollback.
- Dependencies: TRD-005, TRD-006, TRD-017.
- Expected files/modules: design protocol appendix; no source yet.
- Automated tests: table-driven boundary vectors for before/at/after every time
  boundary and delayed return.
- Physical tests: none in design phase.
- Security risks: accepting post-revocation receipt or rejecting valid delayed evidence.
- Completion criteria: exact canonical timestamps and verifier pseudocode approved.
- External infrastructure: signed status/time policy required for later phases.

### P0.3 Specify offline verification bundle

- Scope: Exact canonical credential, delegation and status proof transported to
  an origin that has never seen the responder.
- Dependencies: TRD-002, TRD-003, TRD-018.
- Expected files/modules: protocol specification and size budget.
- Automated tests: canonical/golden vectors, missing/extra/malformed chain,
  maximum BLE-fragment size, cache dedup.
- Physical tests: BLE transfer timing/fragment interruption after implementation.
- Security risks: accepting digest without proof; unbounded bundle DoS.
- Completion criteria: exact fields, signatures, limits and caching rules approved.
- External infrastructure: future issuer/status publisher.

### P0.4 Specify root rotation and recovery

- Scope: Versioned root set, recovery quorum, successor-root object, monotonic
  epoch, overlap, rollback prevention, lost/compromised root runbook.
- Dependencies: TRD-002, TRD-015.
- Expected files/modules: security design/runbook only.
- Automated tests: valid rotation, insufficient quorum, rollback, compromised
  online issuer, lost root, expired overlap.
- Physical tests: cached old/new root behavior after offline restart later.
- Security risks: permanent lockout or malicious root replacement.
- Completion criteria: two-person/key separation model exists even if both
  custodians are owner-controlled locations for pilot; recovery drill documented.
- External infrastructure: secure offline custody; production requires independent custodians.

### P0.5 Freeze route and persistence semantics

- Scope: Exact route-context schema, deterministic persistence/receipt IDs,
  transaction isolation, conflict and retry rules.
- Dependencies: P0.2-P0.3.
- Expected files/modules: v3 protocol/schema design.
- Automated tests: independent derivation vectors and model-based race tests.
- Physical tests: none until implementation.
- Security risks: origin cannot reproduce route evidence; duplicate incidents.
- Completion criteria: all components are length-prefixed/canonical and origin-
  verifiable; native peer handles remain local.
- External infrastructure: none.

### Phase 0 gate

All P0 decisions/specifications approved. Otherwise Final Delivery v3 remains
deferred and Phase 3 must not start.

## Phase 1 — Safe MVP improvements using existing architecture

### P1.1 Truthful Relay status and terminology audit

- Scope: Ensure normal UI distinguishes searching, stored on relay, final
  unconfirmed, and failure; remove any implication of responder/human delivery.
- Dependencies: Option A owner decision.
- Expected files/modules: SOS/Home/Chat/History status widgets and localization
  resources when that separate work is authorized.
- Automated tests: widget tests for every evidence state, Thai/English and large text.
- Physical tests: Android/iPhone/iPad status observation during direct and hop-only runs.
- Security risks: UX can overstate evidence even when protocol is safe.
- Completion criteria: no native/hop state is labelled final/accepted/dispatched.
- External infrastructure: none.

### P1.2 Public relay privacy disclosure

- Scope: Explain that opted-in public SOS and separately consented coordinates
  may be visible to relay devices; consent remains per incident.
- Dependencies: privacy wording approval.
- Expected files/modules: consent/onboarding/help documentation only after authorization.
- Automated tests: persistence of consent, location-off default, no account/contact fields.
- Physical tests: consent on/off and payload privacy inspection on all platforms.
- Security risks: uninformed sensitive-data disclosure.
- Completion criteria: plain-language disclosure accepted and tested.
- External infrastructure: privacy review desirable; not required for local test.

### P1.3 Preserve and expand fail-closed regression coverage

- Scope: Lock current final-receipt rejection, hop/session binding, relay-only
  History isolation, owner/Guest isolation and restart recovery.
- Dependencies: current dirty work reconciled without losing user changes.
- Expected files/modules: existing Relay v2 tests only; no v3 behavior.
- Automated tests: unsupported final receipt, wrong peer/key, replay, expiry,
  lifecycle resume, migration, relay-only history.
- Physical tests: current A -> B -> C hop-only route and diagnostics; final remains unconfirmed.
- Security risks: future refactor accidentally enables reserved final v2.
- Completion criteria: complete suite/analyzer/diff check and timestamped device evidence.
- External infrastructure: physical devices only.

### P1.4 Finish unrelated release blockers

- Scope: production map, signed distributions, localization and outstanding
  physical reliability matrix from `FINAL_PRODUCT_AUDIT.md`.
- Dependencies: owner credentials/providers/devices.
- Expected files/modules: governed by their existing plans, not this roadmap.
- Automated tests: existing release validation.
- Physical tests: signed candidate, BLE failures/range, Guest/account isolation.
- Security risks: v3 work distracts from known P0/P1 release blockers.
- Completion criteria: evidence in release readiness; release gate stays blocked until all pass.
- External infrastructure: signing assets, map provider, devices.

### Phase 1 gate

Current MVP makes only evidence-supported hop-only claims and passes existing
release guards. This phase does not authorize v3.

## Phase 2 — Controlled pilot prerequisites

### P2.1 Define pilot participants and enrollment evidence

- Scope: Identify a small closed set of consenting test responders, their test
  roles, identity check and removal process.
- Dependencies: TRD-003/TRD-004 decisions.
- Expected files/modules: operational enrollment register outside source control.
- Automated tests: not applicable to human proofing; validate parser against synthetic IDs.
- Physical tests: verify credential appears only on enrolled installation.
- Security risks: test credential mistaken for public authority; personal data handling.
- Completion criteria: signed participant consent, explicit “pilot/test only” policy.
- External infrastructure: real pilot participants.

### P2.2 Establish pilot trust-root custody

- Scope: Generate keys only in a separately authorized ceremony, protect root
  offline, establish recovery quorum/backup and rotation drill.
- Dependencies: Phase 0 root specification and explicit key-generation authorization.
- Expected files/modules: no private material in repository; public root manifest later.
- Automated tests: use disposable test keys only.
- Physical tests: old/new root cache rotation drill later.
- Security risks: lost/stolen root, backup exposure, secret leakage.
- Completion criteria: documented custody, inventory, recovery and compromise runbook.
- External infrastructure: secure offline storage; production HSM not required for pilot.

### P2.3 Build pilot issuer/status service

- Scope: Issue short-lived, installation-bound pilot credentials and signed
  bounded status bundles; audit issue/revoke/renew operations.
- Dependencies: P2.1-P2.2, Phase 0 canonical specs.
- Expected files/modules: separate backend/service repository preferred; mobile
  app receives public evidence only.
- Automated tests: golden signatures, authorization, expiry, epoch rollback,
  revocation, credential/key mismatch, audit events.
- Physical tests: enroll, renew, revoke, offline expiry and lost-device scenario.
- Security risks: online issuer compromise, secrets in logs/backups, availability.
- Completion criteria: issuer has no SOS content, secrets protected, recovery drill passes.
- External infrastructure: hosted endpoint/status distribution and monitoring.

### P2.4 Decide pilot confidentiality and retention

- Scope: Explicit public-relay disclosure versus end-to-end encryption; define
  incident/receipt/credential/audit retention.
- Dependencies: TRD-010/TRD-013.
- Expected files/modules: privacy and protocol design; no implementation until approved.
- Automated tests: payload field inventory and deletion/expiry policies later.
- Physical tests: inspect relay payload/privacy and cleanup later.
- Security risks: sensitive content disclosure or unverifiable encrypted routing.
- Completion criteria: owner and participants accept documented policy.
- External infrastructure: privacy consultation recommended.

### Phase 2 gate

Pilot authority, participants, root recovery, issuer/status service, privacy and
offline policy exist and pass drills. Without this gate, Phase 3 is prohibited.

## Phase 3 — Final Delivery v3 implementation

### P3.1 Implement canonical credentials and verification bundle

- Scope: Strict exact-key parsing, canonical encoding, issuer/delegation/status
  verification, bounded cache and fail-closed errors.
- Dependencies: Phase 0 specs and Phase 2 service.
- Expected files/modules: new Relay domain credential/trust classes, repository,
  owner-scoped cache tables, test vectors; no v2 format changes.
- Automated tests: independent golden vectors, fuzz/malformed input, quotas,
  rollback, all wrong-chain/scope/key/time cases.
- Physical tests: Android/iOS credential cache, secure key, offline restart.
- Security risks: parser differential, algorithm confusion, stale trust.
- Completion criteria: backend and Flutter produce identical vectors; external review desirable.
- External infrastructure: pilot issuer/status endpoint.

### P3.2 Add transactional schema migration

- Scope: Add dedicated responder incidents, authorization, dedup, receipt
  outbox/route and trust metadata tables; never mutate relay-only v2 semantics.
- Dependencies: frozen persistence IDs and table review.
- Expected files/modules: Drift tables, `app_database.dart`, generated file,
  migration snapshots/tests.
- Automated tests: v5/v6->new schema, injected failure rollback, existing data
  preservation, downgrade rejection, quota/accounting, owner isolation.
- Physical tests: update-in-place with existing SOS/Chat/relay/Guest data on Android/iOS.
- Security risks: data loss, cross-owner collision, accidental cloud sync.
- Completion criteria: migration gate passes before protocol capability is enabled.
- External infrastructure: none.

### P3.3 Implement final verifier and atomic persistence

- Scope: Verify origin/hops/authorization/credential/route, sign deterministic
  receipt, atomically persist incident + dedup + exact receipt outbox.
- Dependencies: P3.1-P3.2.
- Expected files/modules: final delivery service/repository; no insertion into
  current origin `sos_messages` unless separately approved.
- Automated tests: statement failure injection, concurrent paths, owner switch,
  exact replay/conflict, crash before/after commit, signing failure.
- Physical tests: final device force-close at controlled points and restart.
- Security risks: receipt before persistence, duplicate incident, account leakage.
- Completion criteria: no observable receipt without commit; exact duplicate returns same receipt.
- External infrastructure: valid pilot credential evidence.

### P3.4 Implement version/capability negotiation and reverse route

- Scope: New v3 kinds/capability, exact reverse chain, durable relay receipt
  outbox, bounded retry/expiry and restart recovery.
- Dependencies: P3.3.
- Expected files/modules: additive v3 coordinator/repository paths; existing v2
  handlers retain explicit rejection.
- Automated tests: old/new peer matrix, wrong peer/route/session, reconnect,
  origin/relay restart, delayed receipt, duplicate/conflict and size limits.
- Physical tests: A -> B -> trusted C with A unable to reach C, then reverse
  receipt through B; repeat platform directions and restarts.
- Security risks: downgrade confusion, route substitution, receipt loss.
- Completion criteria: origin confirms only after verified persisted receipt;
  old peers remain hop-only and safe.
- External infrastructure: pilot trust service for credentials/status.

### P3.5 Add strictly scoped pilot UI

- Scope: Show pilot credential state and distinguish relay stored, authorized
  pilot persistence, human acceptance absent, expired/unverifiable evidence.
- Dependencies: P3.1-P3.4.
- Expected files/modules: settings/enrollment/status/History UI and localization.
- Automated tests: all evidence/error states, accessibility, privacy masking.
- Physical tests: Android/iPhone/iPad navigation and evidence comparison.
- Security risks: wording overstates test responder authority.
- Completion criteria: every screen says pilot/test where applicable and never implies dispatch.
- External infrastructure: pilot support/contact process.

### Phase 3 gate

All automated security/migration/compatibility tests and controlled three-device
physical cases pass on frozen signed artifacts. This proves only controlled
pilot persistence, not public emergency-service readiness.

## Phase 4 — Production operations and release verification

### P4.1 Establish accountable production authority

- Scope: Contract/integrate real responder organization(s), delegated issuer
  policy, identity proofing, role lifecycle and incident ownership.
- Dependencies: external agreement and governance.
- Expected files/modules: authority/delegation policies and backend integration.
- Automated tests: delegation, cross-organization, revocation and policy versions.
- Physical tests: organization-controlled enrollment/revocation and response drill.
- Security risks: governance failure, unauthorized delegation, liability.
- Completion criteria: named accountable owners and audited processes.
- External infrastructure: mandatory.

### P4.2 Production key operations and monitoring

- Scope: HSM/managed signing, access controls, key rotation, transparency/audit,
  status publication SLA, monitoring, alerting and compromise response.
- Dependencies: P4.1.
- Expected files/modules: infrastructure-as-code and runbooks outside mobile source.
- Automated tests: backup/restore, rotation, failover and compromise simulations.
- Physical tests: offline clients across planned rotation/outage.
- Security risks: authority compromise or unavailable revocation.
- Completion criteria: operational readiness exercise passes.
- External infrastructure: mandatory operations/security capability.

### P4.3 Production confidentiality, privacy and retention

- Scope: Complete threat/privacy assessment, encryption decision, data subject
  rights, legal basis, retention, breach response and geographic controls.
- Dependencies: participating organizations and jurisdictions.
- Expected files/modules: privacy design and any approved protocol extension.
- Automated tests: deletion/retention/access policy and crypto vectors.
- Physical tests: end-to-end privacy and offline failure behavior.
- Security risks: sensitive emergency data exposure.
- Completion criteria: accountable privacy owner signs off.
- External infrastructure: legal/privacy and organization support.

### P4.4 Frozen release-candidate acceptance

- Scope: Signed Android/iOS distribution builds, migration, physical direct/
  relay/final tests, faults, range, map, localization and operational drill.
- Dependencies: all current release blockers plus P4.1-P4.3.
- Expected files/modules: release evidence only after code freeze.
- Automated tests: full suite/analyzer/signing guards/secret scans.
- Physical tests: complete current runbooks on supported device/platform matrix.
- Security risks: development evidence mistaken for release evidence.
- Completion criteria: every gate has artifact hash, signature, commit and physical evidence.
- External infrastructure: signing, map provider, organizations, test devices and operations.

## Recommended next action

TRD-001 is approved. Continue only the Safe Minimal MVP work in Phase 1 and do
not begin v3 source/schema work. Begin the remaining Phase 0 specification
closure and Phase 2 external preparation only when a controlled pilot is a
concrete product goal with real participants and operational ownership.
