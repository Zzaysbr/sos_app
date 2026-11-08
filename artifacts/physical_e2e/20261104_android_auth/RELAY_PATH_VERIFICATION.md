# Physical relay path verification — 4 November 2026

Topology: A iPhone 15 Plus → B Samsung A53 (RFCT80GPFVY) → C V2050
(15728100670086M). All times Asia/Bangkok.

Incident: `1793777993188376`. No new incident was created for this comparison.

## Verified evidence

- Earlier read-only B snapshot contains the incident, incoming hop 0, queued.
- B log: forwarding started 15:07:09.090, outgoing hop 1, retry 0.
- B log: transfer completed 15:08:06.461 (57.370s), awaiting hop receipt.
- C log: assembled transfer 15:08:03.872; validated the same incident;
  persisted Rescue candidate 15:08:05.675.
- Read-only C snapshot contains both relay and Rescue Inbox rows for the same
  incident; candidate pending, incoming hop 1.
- Immutable payload digests in B's earlier snapshot and C's snapshot match.
- C's stored wire envelope has path length 2, one hop attestation, and an
  immediate sender different from the SOS origin. That sender matches C's
  persisted previous-hop identity.
- Recomputed the production deterministic attempt ID using the target key
  authenticated by B at 15:06:59 and the incident's origin message ID. It
  exactly matches the transfer ID assembled by C. Public keys/identifiers and
  signed payload contents are omitted here.

These correlated sender logs, transfer ID, payload digest and persisted
destination evidence verify B→C forwarding for this incident. UI visibility
alone was not used as proof. A direct origin-only transfer would not have this
validated intermediate hop.

## Limitations

- Latest B snapshot was taken after expiry/cleanup and contains no live relay
  rows. It cannot establish current retry or signed-receipt state. Comparison
  uses the previously captured B row and contemporaneous logs.
- Signed durable hop receipt return is NOT VERIFIED. Earlier A attempts timed
  out despite B persistence; B also retried after C reception.
- No final-responder delivery ACK, Offer Help round trip, location display or
  bidirectional Chat acceptance is claimed for this run.
- Authentication and forwarding latency remain significant. One successful
  transfer is not evidence of stable repeated lifecycle recovery.

Evidence logs: `B_forward_transfer.log`, `C_SOS_persisted.log`. Private database
copies were inspected locally outside the repository; they are not committed
or included in this report.
