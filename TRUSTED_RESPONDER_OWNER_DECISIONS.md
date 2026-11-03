# Trusted Responder Owner Decision Log

Date prepared: 2 November 2026 (Asia/Bangkok)

Status: **OPTION A APPROVED BY OWNER — FINAL DELIVERY v3 DEFERRED**

## Recorded owner decision

- Decision date: 2 November 2026 (Asia/Bangkok).
- Decision: Adopt **Option A — Safe Minimal MVP**.
- Rationale: Preserve the evidence-backed Direct BLE v1 and hop-only Relay v2
  behavior without inventing responder identity or implying human acceptance,
  rescue dispatch, or final delivery. A solo owner currently has no confirmed
  trust authority, responder registry, enrollment operation, revocation service,
  rescue organization, or external operational owner.
- Final Delivery v3: `DEFERRED`; it is not implemented or authorized to begin.
- Production Trust Authority: `BLOCKED`.
- Real responder enrollment and eligibility: `BLOCKED`.
- External operational ownership: `BLOCKED`.
- Scope of approval: current MVP direction only. No credential, authority,
  schema, protocol, backend, or responder claim is approved by this decision.

Allowed statuses:

- `PROPOSED` — recommended default awaiting owner decision.
- `APPROVED` — explicitly accepted by the owner and recorded with a date.
- `DEFERRED` — intentionally postponed without weakening current guarantees.
- `BLOCKED` — cannot be decided safely without external evidence/capability.

## Decision register

### TRD-001 — MVP trust model

- Topic: Current product trust scope.
- Why it matters: Determines whether the app may claim final responder delivery.
- Options: A) retain hop-only Relay v2; B) controlled pilot authority; C) full
  organization-delegated production authority.
- Decision: Adopt Option A now; prepare Option B only after prerequisites.
- Consequences:
  - A preserves truthful evidence but cannot confirm responder delivery.
  - B enables limited test evidence but creates authority/operations duties.
  - C supports public trust but requires organizations and production services.
- Developer can decide independently: Yes for choosing A; not for claiming B/C
  represents real emergency-service authority.
- External dependency: B needs credible pilot participants; C needs accountable
  organizations and operations.
- Decision date: 2 November 2026 (Asia/Bangkok).
- Status: `APPROVED`.

### TRD-002 — Trust-root ownership

- Topic: Who owns and protects credential-signing trust.
- Why it matters: A compromised or lost root invalidates every responder claim.
- Options: no root; developer-owned pilot-only root; organization-owned root;
  project root delegating organization issuers.
- Recommended default: No responder root for Option A. For Option B, a clearly
  labelled pilot-only offline root with recovery quorum and documented custody.
- Consequences: A single developer key is operationally fragile and cannot prove
  public rescue authority; organization ownership adds governance legitimacy.
- Developer can decide independently: Only for a pilot/test authority.
- External dependency: Production root requires legal/operational ownership.
- Status: `BLOCKED` for production; `DEFERRED` for pilot setup.

### TRD-003 — Responder eligibility

- Topic: Which people/devices qualify as responders.
- Why it matters: Device key possession is not responder authority.
- Options: project test participant; verified organization member; public
  emergency-service responder; no responder role.
- Recommended default: No responder role in MVP. Pilot may use named test
  participants and display that limitation explicitly.
- Consequences: Loose eligibility makes final delivery misleading; strict
  eligibility requires evidence and lifecycle management.
- Developer can decide independently: Test eligibility only.
- External dependency: Production eligibility requires participating organization.
- Status: `BLOCKED` for production.

### TRD-004 — Credential enrollment

- Topic: How principal, role and installation key are checked and bound.
- Why it matters: Prevents arbitrary installations from self-asserting responder status.
- Options: manual in-person pilot enrollment; authenticated remote pilot flow;
  organization-managed enrollment; self-registration.
- Recommended default: Manual documented pilot enrollment; never self-registration.
- Consequences: Manual enrollment scales poorly but is auditable; self-registration
  provides no meaningful responder authorization.
- Developer can decide independently: Pilot workflow, with consent from participants.
- External dependency: Production enrollment requires organization identity proofing.
- Status: `DEFERRED`.

### TRD-005 — Credential expiration

- Topic: Maximum offline responder credential lifetime.
- Why it matters: Bounds stolen-device and stale-role exposure.
- Options: hours, one day, several days, long-lived/offline indefinite.
- Recommended default: Short pilot credential, initially at most 24 hours;
  exact value requires test/operations approval. Never indefinite.
- Consequences: Short lifetime improves revocation bounds but requires frequent
  connectivity and renewal; long lifetime improves availability but increases risk.
- Developer can decide independently: Pilot value after documenting tradeoff.
- External dependency: Production value requires organization/service availability.
- Status: `PROPOSED`.

### TRD-006 — Offline revocation policy

- Topic: How stale or revoked credentials are handled without connectivity.
- Why it matters: Immediate revocation is impossible on disconnected devices.
- Options: fail when status bundle expires; bounded stale grace; credential-only
  expiry; always-online verification.
- Recommended default: Fail closed at the earlier of credential/status expiry,
  with no stale grace for pilot final persistence.
- Consequences: May reject legitimate offline responders after expiry; grace
  increases compromised-device exposure.
- Developer can decide independently: Pilot policy.
- External dependency: Production status publication and incident response service.
- Status: `PROPOSED`.

### TRD-007 — Guest SOS authorization

- Topic: How a Guest origin addresses a trusted responder.
- Why it matters: Guest has no Firebase identity and must remain local/isolated.
- Options: any trusted pilot responder; organization/role selector; specific
  opaque principal; require login.
- Recommended default: Option A has no final authorization. Pilot may use one
  preconfigured opaque pilot role without uploading Guest identity.
- Consequences: Requiring login harms offline use; broad selector increases
  disclosure/fanout; specific principal requires cached authority metadata.
- Developer can decide independently: Technical Guest isolation policy.
- External dependency: Credible responder selector still requires issuer data.
- Status: `DEFERRED`.

### TRD-008 — Recipient selection

- Topic: Who becomes eligible for final persistence.
- Why it matters: First-nearby-device selection is unsafe.
- Options: explicit specific responder; organization/role; any trusted responder;
  first nearby peer.
- Recommended default: Controlled pilot starts with one explicitly configured
  credential/role; never first nearby peer.
- Consequences: Explicit selection is safer but may reduce emergency availability;
  broad matching requires credible authority and privacy controls.
- Developer can decide independently: Pilot UI/policy after enrollment exists.
- External dependency: Organization selectors require organization integration.
- Status: `DEFERRED`.

### TRD-009 — Multi-responder fanout

- Topic: Number of final recipients/routes.
- Why it matters: Multiple responders can duplicate/conflict operational action.
- Options: one final responder; bounded N; organization fanout; unlimited.
- Recommended default: One for pilot; no unlimited fanout.
- Consequences: One is simpler but less available; fanout improves reach but
  needs coordination, privacy, dedup and incident ownership.
- Developer can decide independently: Pilot bound.
- External dependency: Production fanout needs operational coordination.
- Status: `DEFERRED`.

### TRD-010 — Relay payload confidentiality

- Topic: Whether intermediate relays may read SOS body/location.
- Why it matters: Signatures do not encrypt sensitive emergency data.
- Options: preserve explicit public-relay consent; end-to-end encrypt to one
  responder; multi-recipient encryption; remove relay content fields.
- Recommended default: Preserve explicit public-relay/location consent for
  Option A; require a separate encryption decision before public v3.
- Consequences: Plain signed payload aids routing but exposes content; encryption
  adds key-discovery, rotation, fanout and recovery complexity.
- Developer can decide independently: MVP disclosure/consent wording.
- External dependency: Production recipient-key infrastructure and privacy review.
- Status: `BLOCKED` for public v3.

### TRD-011 — Final persistence semantics

- Topic: Meaning of a final machine receipt.
- Why it matters: Prevents persistence from being presented as human action.
- Options: device received bytes; durable authorized persistence; human acceptance.
- Recommended default: v3, if later implemented, proves only durable authorized
  installation persistence after atomic commit.
- Consequences: Narrow semantics are truthful; broader semantics are unsafe
  without separate evidence.
- Developer can decide independently: Yes, as a protocol/UI invariant.
- External dependency: None for the semantic boundary; authority needed to use it.
- Status: `PROPOSED`.

### TRD-012 — Human acceptance semantics

- Topic: Evidence that a person accepted responsibility.
- Why it matters: Final persistence does not prove human attention or dispatch.
- Options: no human state; explicit authenticated accept action; organization
  dispatch integration.
- Recommended default: No human acceptance claim in MVP or v3 persistence.
- Consequences: Honest but limited; adding it creates new authentication,
  auditing, liability and operations requirements.
- Developer can decide independently: Defer the claim.
- External dependency: Real acceptance/dispatch requires operational organization.
- Status: `DEFERRED`.

### TRD-013 — Final receipt retention

- Topic: How long origin, relays and responder store receipt evidence.
- Why it matters: Needed for recovery/audit but creates privacy/storage exposure.
- Options: SOS expiry only; short operational retention; incident-lifetime;
  configurable/legal hold.
- Recommended default: Relays retain only through bounded receipt/SOS expiry;
  pilot origin/responder retain the minimal period needed for test evidence.
- Consequences: Short retention limits exposure but reduces later audit; long
  retention requires policy, deletion and subject-access handling.
- Developer can decide independently: Pilot retention with participant consent.
- External dependency: Production retention requires legal/privacy ownership.
- Status: `DEFERRED`.

### TRD-014 — Lost-device recovery

- Topic: Recovery after responder device/key loss.
- Why it matters: Stolen keys remain usable offline until expiry/status update.
- Options: revoke old credential/key and re-enroll; copy private seed; account-only
  recovery; remote wipe dependency.
- Recommended default: Revoke and create a new device key/credential. Never copy
  the Relay private seed or claim account recovery restores it.
- Consequences: Identity changes and may interrupt offline use; seed copying
  destroys per-device accountability.
- Developer can decide independently: Pilot procedure.
- External dependency: Production help desk/revocation operations.
- Status: `PROPOSED`.

### TRD-015 — Trust-root rotation and recovery

- Topic: Root loss/compromise and verifier update.
- Why it matters: A single pinned root can force reinstall or allow forged credentials.
- Options: single root; root + offline recovery keys; threshold quorum; app update only.
- Recommended default: Before pilot, define versioned root set, monotonic trust
  epoch, at least two separately protected recovery keys and signed successor roots.
- Consequences: More custody complexity but avoids one-key permanent failure;
  app-only rotation is slow and unavailable offline.
- Developer can decide independently: Pilot ceremony after secure storage plan.
- External dependency: Production requires audited custodians/operations.
- Status: `BLOCKED` pending design.

### TRD-016 — Production operational ownership

- Topic: Who monitors, accepts, dispatches, supports and responds to compromise.
- Why it matters: Software delivery evidence is not emergency response.
- Options: no production responder operation; developer pilot; contracted/partner
  organization; dedicated operations team.
- Recommended default: No production responder claim until an accountable
  organization accepts this role.
- Consequences: Without ownership the app must remain peer/relay assistance only;
  claiming service availability would mislead users.
- Developer can decide independently: Can decide not to claim production service.
- External dependency: Mandatory for production Trusted Responder.
- Status: `BLOCKED`.

### TRD-017 — Delayed receipt verification time

- Topic: Whether credential validity is checked at persistence or receipt arrival.
- Why it matters: Reverse routing can outlast credential validity.
- Options: require validity at arrival; require validity at signed persistence
  plus bounded arrival; reject every post-expiry arrival.
- Recommended default: Validate credential/status at signed persistence time and
  enforce a separate bounded receipt-arrival expiry; reject known prior revocation.
- Consequences: Preserves legitimate delayed evidence but needs signed status
  proof transported with the receipt and precise clock rules.
- Developer can decide independently: Protocol policy after security tests.
- External dependency: Signed status/time evidence distribution.
- Status: `BLOCKED` pending specification.

### TRD-018 — Final verification evidence bundle

- Topic: How an offline origin obtains credential/delegation/revocation proof.
- Why it matters: A credential digest alone is not verifiable evidence.
- Options: origin cache only; receipt carries bounded proof bundle; online fetch;
  hybrid cache + bundle.
- Recommended default: Bounded canonical proof bundle with the receipt, deduped
  against cache; online refresh is optional, never a fail-open substitute.
- Consequences: Larger payload and fragmentation pressure; cache-only can reject
  legitimate unseen responders; online-only breaks offline operation.
- Developer can decide independently: Protocol mechanism.
- External dependency: Authority must issue bundle/status evidence.
- Status: `BLOCKED` pending design and BLE size tests.

## Owner action

TRD-001 is approved. The next owner work is limited to the Safe Minimal MVP and
existing release blockers. Final Delivery v3 remains deferred. No other entry
should be treated as approved until the owner records an explicit decision and
date; production authority, real responder eligibility/enrollment, and external
operational ownership remain blocked.
