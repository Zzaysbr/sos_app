# Solo Owner Review: Trusted Responder and Final Delivery v3

Review date: 2 November 2026 (Asia/Bangkok)

Repository baseline: `main` / `af6efe2cf4133de2c340d3cd374f9ee944d5b163`

Review status: **OPTION A OWNER-APPROVED — FINAL DELIVERY v3 DEFERRED**

Primary design reviewed: `TRUSTED_RESPONDER_DESIGN.md`

## 1. Executive recommendation

**Owner decision recorded 2 November 2026: Option A — Safe Minimal MVP is
approved.** Preserve Direct BLE v1 and hop-only Relay v2, keep final delivery
explicitly unconfirmed, and do not implement Trusted Responder or Final Delivery
v3.

This is not a recommendation to weaken security. It is the opposite: the
current code correctly refuses final receipts because there is no credible
responder authority, enrollment process, registry, revocation operation, or
incident-response owner. Implementing only the cryptographic message format
would create an attractive but misleading claim that a device is an authorized
emergency responder.

Option B — Controlled Pilot remains deferred and becomes a valid target only
after the owner has:

1. identified a real, explicitly limited group of test responders;
2. documented how their identities and roles are checked;
3. established an offline trust-root backup and recovery procedure;
4. implemented a small credential issuer and signed status distribution;
5. accepted the offline revocation window and privacy limits in writing; and
6. ensured UI says “authorized pilot test responder,” never emergency service.

Option C is not appropriate for a solo owner today. It requires real
organizations, delegated authority governance, production signing operations,
monitoring, revocation distribution, support, privacy operations, and emergency
incident ownership that do not currently exist.

Release Gate remains **BLOCKED**. This review does not change the existing map,
distribution signing, physical reliability, localization, or responder-trust
blockers.

## 2. Evidence baseline

### Confirmed current implementation

- `main.dart` separates Firebase/local owner state from the native installation
  identity used by BLE. Firebase UID is not a responder credential.
- `relay_key_store.dart` stores a Relay v2 Ed25519 seed through platform secure
  storage and derives an installation-key fingerprint. The code explicitly
  treats it as an installation identity, not a person.
- `relay_envelope.dart` has canonical signed origin/hop structures and bounded
  time, hop, message, job, receipt, and storage limits.
- `hop_relay_coordinator.dart` requires proven sessions for offers and hop
  receipts and explicitly rejects final-recipient receipts.
- `relay_repository.dart:1019-1023` rejects final receipts because a trusted
  principal and authenticated final binding are unavailable.
- Relay-only tables remain outside normal SOS History and cloud sync.
- The current database is schema 6. No responder credential, authorization,
  final incident, or reverse final-receipt outbox table exists.
- Current physical evidence proves one foreground A -> B -> C hop-only storage
  path and signed hop evidence. It does not prove final responder delivery.

### Design assumptions, not implementation evidence

- No credential issuer, responder registry, delegated organization, trust
  bundle endpoint, revocation operation, or responder support process was found.
- No external rescue organization has accepted operational responsibility.
- No Final Delivery v3 wire kind, verifier, schema, UI, or physical evidence
  exists.
- No claim can be made about hardware-backed non-exportable Relay keys from the
  Dart secure-storage wrapper alone.

## 3. Architecture complexity assessment

The proposed hybrid model is a defensible target architecture for a mature
public system, but it combines several different products:

1. a public-key infrastructure and recovery ceremony;
2. responder identity proofing and organizational authorization;
3. a credential/status distribution backend;
4. a privacy-sensitive emergency incident receiver;
5. an offline store-and-forward cryptographic protocol;
6. a mobile database migration and crash-safe receipt queue; and
7. operational monitoring, support, revocation, and emergency response.

Cryptography is not the largest risk. The largest risk is making a true-looking
“delivered to responder” claim without anyone able to establish or maintain
what “responder” means.

### Component classification

| Component | Classification | Reason |
|---|---|---|
| Preserve Direct BLE v1 | Essential for a safe MVP | Existing proven behavior; unrelated v3 work must not regress it |
| Preserve fail-closed hop-only Relay v2 | Essential for a safe MVP | It truthfully proves relay persistence without inventing final delivery |
| Keep native write, hop receipt, final persistence, human acceptance, and dispatch distinct | Essential for a safe MVP | Prevents dangerous emergency UX claims |
| Existing expiry, hop/storage limits, dedup, relay consent, and Guest isolation | Essential for a safe MVP | Current safety and privacy boundary |
| Truthful user-facing status and safe terminology | Essential for a safe MVP | Users must know final delivery is unconfirmed |
| Credential-bound final responder identity | Needed before production release if final delivery is claimed | Device key alone cannot authorize a responder |
| Atomic incident/dedup/receipt transaction | Needed before production release if final delivery is claimed | Prevents receipt without durable incident or partial state |
| Durable reverse final-receipt route | Needed before production release if final delivery is claimed | Origin needs persisted cryptographic evidence after reconnect/restart |
| Credential expiry, status freshness, revocation, and root rotation | Needed before production release if final delivery is claimed | Long-lived offline credentials otherwise remain trusted after compromise |
| Separate human acceptance/dispatch protocol | Can be deferred without compromising current guarantees | No current claim of human acceptance; it must remain absent from v3 persistence |
| Multi-responder fanout | Can be deferred without compromising current guarantees | Adds conflict/coordination risk; one pilot responder is safer |
| Alternate reverse routing | Can be deferred without compromising current guarantees | Exact reverse chain is simpler for a controlled pilot |
| Organization federation/delegated issuers | Requires external organization or operational capability | Solo owner cannot establish third-party responder authority by declaration |
| Public responder registry and 24/7 incident operations | Requires external organization or operational capability | Requires governance, support, privacy and emergency ownership |
| Production HSM, key ceremony, monitoring and compromise response | Requires external service/operational capability | A laptop/private file is not sufficient for a public authority |
| Full organization-delegated hybrid platform for current MVP | Unnecessary complexity for the current project | No organization or operational consumer exists yet |
| Private-target invitations in v3 | Unnecessary complexity for the current project | It is a separate trust model and should not share public-emergency semantics |
| Human identity biometrics/attestation | Unnecessary complexity for the current project | It still would not establish organizational authority and expands privacy risk |

## 4. Trust-model challenge

### 4.1 Trust authority

#### No final responder verification

- Safest current choice.
- Requires no authority or invented responder role.
- Preserves signed origin/hop integrity and truthful “stored on relay” state.
- Cannot claim delivery to an authorized responder.

#### Developer-operated limited pilot authority

- Technically possible for a controlled test, provided every credential is
  explicitly labelled pilot/test and issued only after a documented check.
- It proves only that the project owner enrolled that test principal under the
  pilot policy. It does not prove public emergency-service authority.
- The developer becomes responsible for root custody, backup, recovery,
  enrollment records, revocation publication, privacy, support, and incident
  handling during the pilot.
- It is not suitable for an uncontrolled public deployment.

#### Organization-issued credentials

- Stronger real-world responder evidence if the organization owns enrollment,
  role changes, revocation, and operations.
- Cannot be fabricated in code or by a solo developer.
- Requires a real agreement, issuer onboarding, policy mapping, audit, and
  technical integration.

#### Future delegated organization authorities

- Appropriate long-term model when multiple organizations participate.
- Requires root/delegation governance, interoperability, issuer compromise
  response, policy versioning, monitoring and support.
- Premature for the present project.

#### Root ownership and recovery conclusion

- A solo developer can own a **pilot-only** root, not credibly assert a public
  rescue authority.
- A single root public key hardcoded in the app is insufficient for safe root
  compromise recovery. If its private key is lost, no new credentials can be
  issued; if stolen, attackers can mint credentials until every verifier stops
  trusting it.
- The design needs at least two offline recovery keys or a threshold recovery
  policy, key versioning, signed successor roots, and an app-shipped trust-root
  set. Root rotation must be accepted by an already trusted recovery quorum,
  not merely by the compromised online issuer.
- Public-key-only verifier configuration is enough to verify pilot signatures,
  but it does not supply enrollment, revocation, backup, audit, monitoring, or
  operational legitimacy.

### 4.2 What the current architecture can prove

| Claim | Currently provable? | Evidence/limit |
|---|---|---|
| A normal installation controls its Relay private key | Yes, within software/platform limits | Valid Ed25519 session/origin/hop signature |
| A BLE connection is the session bound to an advertised Relay key | Yes, for the proven session generation | Challenge/response and peer/session checks |
| A relay persisted the matching envelope | Yes | Valid session-bound hop receipt and durable row |
| Installation belongs to a registered responder | No | No issuer credential or registry |
| Responder belongs to an authorized organization | No | No organization authority/delegation |
| The human holding the device is the enrolled operator | No | No human-presence/reauth action or organizational audit |
| A human read or accepted the incident | No | No separate human action receipt |
| Assistance was dispatched or arrived | No | No operational system or evidence |

Firebase login, Rescue UI mode, nearby proximity, BLE identity, and Relay key
possession do not change the “No” results above.

### 4.3 Offline credentials and revocation

Technically achievable offline:

- verification of a previously obtained issuer signature;
- binding a credential to an installation public key;
- checking credential role/scope and signed recipient authorization;
- checking bounded expiry against a sufficiently trustworthy local clock;
- rejecting a credential present in the latest cached signed status bundle;
- preserving one signed final receipt through disconnect/restart.

Not technically achievable while disconnected:

- immediate knowledge of a revocation published after the last status bundle;
- confirmation that a responder's employment/role has not just changed;
- reliable global time when the device clock has been rolled back and no signed
  time anchor remains current;
- recovery from a newly compromised authority key before updated trust material
  reaches the device;
- remote deletion of a stolen device's private key.

Device replacement must create a new key and credential. Lost-device response
must revoke the old credential/key. Account recovery must not copy the Relay
private seed.

### 4.4 Final receipt and persistence review

The proposed transaction ordering is mostly sound: prepare deterministic
receipt material, sign it, atomically insert incident + dedup + receipt outbox,
commit, then transmit only from the committed outbox. A signed receipt may
exist briefly in memory before commit, but it must never be exposed to transport
or UI before the transaction succeeds.

Required invariants:

- `persistenceRecordId` is deterministically derived before signing and is the
  exact primary/unique identity inserted by the transaction.
- Retrying the same semantic delivery generates byte-identical receipt content
  and signature or reads the already committed receipt; it never generates a
  second incident.
- A conflict with the same semantic identity but different canonical bytes is a
  security failure, not a retry.
- Account/owner generation is checked inside the transaction.
- Reverse-route state is committed with the receipt, not afterward.
- Relays forward the final responder's immutable signature; they cannot change
  any receipt field and re-sign as final.

### 4.5 Relay confidentiality

The properties are distinct:

| Property | Current Relay v2 | Proposed credential/final receipt |
|---|---|---|
| Integrity | Signed origin/hop envelope | Can be retained |
| Installation authenticity | Key possession/session proof | Can bind responder credential to key |
| Responder authorization | Not present | Requires real issuer/enrollment |
| Confidentiality from relays | Not present | Signatures do not add it |
| Availability | Best-effort foreground bounded relay | Cannot be guaranteed cryptographically |

End-to-end payload encryption is not necessary to preserve today's explicitly
consented public-relay guarantee, but it is a P1 product/privacy decision before
public Trusted Responder deployment. If confidential contents are promised,
encryption must target authorized responder keys while still supporting routing,
key rotation, multi-recipient selection, expiry, and recovery. It must not be
bolted onto the receipt alone.

## 5. Findings

### SOR-01 — P0 — No credible responder authority or operational owner exists

- Confirmed evidence: no registry, issuer, delegated organization, or final
  incident operation exists in the repository or supplied evidence.
- Risk: implementing v3 could make a developer-issued device look like a real
  emergency responder.
- Required action: retain hop-only v2 or establish controlled pilot prerequisites.

### SOR-02 — P0 — Credential time semantics for delayed receipts are ambiguous

- Design evidence: the original design requires credential/status/receipt/SOS
  to be within their time windows during origin verification, but also expects
  receipts to return through intermittent relays.
- Risk: a valid receipt created while the credential was valid may arrive after
  credential expiry and be rejected; accepting it without a time rule may allow
  post-expiry evidence.
- Proposed correction: validate authorization at the signed durable
  `persistedAt/createdAt` time, require that time to be within SOS,
  authorization, credential, and status-evidence validity, require bounded
  receipt-arrival/retention expiry separately, and reject known revocation whose
  effective time precedes persistence. Define this in golden boundary vectors.
- Status: unresolved; do not implement v3 until approved.

### SOR-03 — P0 — Offline origin proof transport is incomplete

- Design evidence: the receipt carries `credentialDigest`, but the origin may
  be offline and may not possess the responder credential, delegation chain, or
  status evidence referenced by that digest.
- Risk: origin cannot verify a legitimate receipt offline or may be tempted to
  accept a digest without evidence.
- Proposed correction: define a bounded canonical `FinalVerificationBundle`
  transported with or before the receipt, containing the public credential,
  delegation chain and signed status proof needed at persistence time. The
  receipt signs their digests. Missing evidence leaves final delivery unconfirmed.
- Status: unresolved.

### SOR-04 — P1 — Trust-root rotation and compromise recovery are underspecified

- Design evidence: project-pinned roots and emergency rotation are proposed,
  but no quorum, successor-root format, rollback rule, or lost-root recovery is
  defined.
- Risk: one lost root halts issuance; one stolen root can mint responders; a
  single-root verifier may require application reinstall to recover.
- Proposed correction: versioned root set, offline recovery quorum, monotonic
  trust epoch, signed successor-root object, rollback prevention, overlap period,
  and tested emergency rotation ceremony before Option B.

### SOR-05 — P1 — Route-context digest is not independently reproducible

- Design evidence: it is described as hashing inbound peer/session/path facts,
  but exact canonical fields, ownership of evidence, and what the origin can
  verify are not specified.
- Risk: cross-platform mismatches or a field that only the final device knows
  could make valid receipts unverifiable.
- Proposed correction: publish an exact canonical route-evidence schema. Origin
  verification should require only retained origin correlation/path evidence;
  per-hop native peer IDs remain local and are validated hop-by-hop, not exposed
  as globally verifiable identity.

### SOR-06 — P1 — Public-relay confidentiality is unresolved

- Confirmed evidence: signatures protect integrity, not secrecy; intermediate
  relays can inspect current public emergency payloads.
- Risk: sensitive SOS text/location may be exposed to participating relays.
- Required action: keep explicit per-incident public-relay/location consent for
  Option A; decide and threat-model end-to-end encryption before public v3.

### SOR-07 — P1 — Persistence identity and transaction retry require a frozen specification

- Design evidence: deterministic receipt ID is proposed, while dedicated final
  tables and a persistence record ID are not yet implemented.
- Risk: nondeterministic local IDs, transaction retries or concurrent paths
  could create multiple incidents or receipts.
- Proposed correction: freeze length-prefixed derivations, unique constraints,
  transaction isolation, conflict outcomes, and statement-level failure tests
  before schema migration.

### SOR-08 — P1 — A developer-operated authority is not production responder proof

- Risk: valid cryptography could overstate social/organizational authority.
- Required action: pilot credentials must visibly state their limited issuer and
  test scope. Production responder claims require an accountable organization.

### SOR-09 — P2 — Secure storage does not establish non-extractable hardware keys

- Confirmed evidence: current code stores a 32-byte Ed25519 seed through
  `flutter_secure_storage`; the app process reconstructs the key pair.
- Risk: rooted/jailbroken/runtime-compromised devices may extract seed material.
- Required action: retain current safeguards for Relay v2; evaluate native
  non-exportable key support/attestation separately before stronger claims.

### SOR-10 — P2 — Human acceptance remains intentionally outside final persistence

- This is a correct boundary in the design.
- Required action: preserve it. Any future acceptance/dispatch feature needs a
  separate authenticated action, protocol, audit, UI and physical validation.

## 6. Option comparison

| Dimension | Option A: Safe Minimal MVP | Option B: Controlled Pilot | Option C: Full Production |
|---|---|---|---|
| Final responder claim | None; final unconfirmed | “Persisted by authorized pilot test installation” | Organization-authorized final persistence |
| Authority | None | Developer-operated pilot root with explicit limits | Project root plus real delegated organizations |
| Enrollment | None | Manual documented test-responder enrollment | Organization identity/role lifecycle |
| Offline verification | Existing Relay v2 signatures only | Short-lived pilot credentials/status bundle | Federated bounded trust bundles/revocation |
| Reverse receipt | Not implemented | Exact reverse chain initially | Durable exact/alternate routes under policy |
| Operational burden | Low | Moderate/high for one developer | High; requires teams/services |
| Public suitability | Honest hop-only function | Closed test only | Potentially suitable after independent review |
| Main risk | Users may overestimate relay usefulness unless UI is clear | Pilot credentials mistaken for public authority | Complex authority/privacy/operations failure |
| Current recommendation | **Yes** | Only after prerequisites | No, not now |

## 7. Recommended MVP scope

Implement no Final Delivery v3 protocol or schema now. The safe MVP scope is:

1. retain current final-receipt rejection in coordinator and repository;
2. retain Relay v2 as opt-in, foreground, bounded, public-emergency hop storage;
3. keep relay-only rows out of History and cloud sync;
4. ensure all normal UI says “stored by relay; final delivery unconfirmed”;
5. ensure Diagnostics remains debug/profile-only and privacy-redacted;
6. document that relays may inspect public relay contents and location when
   separately consented;
7. preserve Guest/account isolation, Direct v1 ACK semantics and all peer checks;
8. finish existing release blockers without presenting Relay v2 as emergency
   service delivery; and
9. prepare Option B externally before any v3 implementation branch begins.

The application can claim that an opted-in relay installation durably stored a
matching signed envelope when a valid hop receipt exists. It cannot claim an
authorized responder received it, a human saw it, assistance was dispatched,
or anyone will act.

## 8. Owner decision summary

The full decision register is in `TRUSTED_RESPONDER_OWNER_DECISIONS.md`.

- Approved on 2 November 2026: adopt Option A and retain truthful hop-only semantics.
- Deferred: Final Delivery v3 and Option B controlled-pilot implementation.
- Blocked externally: production authority, responder eligibility, organization
  delegation, operational ownership and public revocation.
- Deferred: fanout, alternate reverse routing, human acceptance, dispatch,
  private invitations and full production federation.
- Required before pilot: root recovery, enrollment evidence, expiration/status
  policy, offline verification bundle, lost-device process and pilot UX wording.

Only TRD-001 is approved by the owner's explicit instruction. External
dependencies are not approved or resolved.

## 9. Implementation roadmap summary

The detailed dependency-gated roadmap is in
`TRUSTED_RESPONDER_IMPLEMENTATION_ROADMAP.md`.

- Phase 0 closes decisions and corrects the v3 design specification.
- Phase 1 improves the existing safe MVP without v3 behavior.
- Phase 2 establishes real controlled-pilot authority/enrollment prerequisites.
- Phase 3 implements v3 only after Phases 0 and 2 pass their gates.
- Phase 4 adds production organizations, operations and release verification.

## 10. Risks remaining under Option A

- Relay v2 is foreground and best-effort; no availability guarantee exists.
- A hop receipt proves relay storage only and may never lead to a responder.
- Public relay contents are integrity-protected but not confidential from relays.
- Offline revocation/responder authorization do not exist because responder
  credentials do not exist.
- BLE radio range, OS lifecycle, permission, interference and device diversity
  remain physical reliability risks.
- Signed distribution, production map configuration, localization and the full
  current-build physical matrix remain release blockers.
- A user may still misunderstand relay status unless copy and onboarding are
  explicit and tested.

## 11. Explicit non-guarantees

The current application cannot guarantee or truthfully state that:

- a nearby device is an authorized responder;
- Firebase authentication proves responder eligibility;
- a Relay Ed25519 key identifies a person or organization;
- an SOS reached an authorized responder;
- a human read or accepted an incident;
- assistance was dispatched, will arrive, or arrived;
- a relay cannot read opted-in public SOS content;
- a revoked device will be rejected immediately while offline;
- foreground BLE relay is always available or has a guaranteed range; or
- current automated/historical physical evidence proves Final Delivery v3.

## 12. Review conclusion

**Final Delivery v3 is deferred by owner decision.** The design is valuable as a future
architecture, but its current authority, delayed-receipt verification,
offline-proof transport, root-recovery and route-evidence dependencies are not
closed. Option A preserves every current security boundary and avoids a false
emergency-delivery claim. Option B becomes reasonable only after its real-world
prerequisites are supplied and approved. No source, schema, native setting,
wire format, credential or signing key is changed by this review.
