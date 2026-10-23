# Future LoRa Transport Feasibility

Date: 22 October 2026. Decision: **feasible as a separate hardware-backed
transport experiment, not ready for implementation or release selection**.

## Current architecture and smallest safe change

The durable application layer is already reusable: SOS, Chat and Location have
stable message IDs, SQLite outbox/inbox rows, application ACKs, bounded retries,
duplicate protection and owner/session checks. `SosBleCoordinator` still depends
on BLE-specific discovery, connection roles, peer routes and
`BleTransportClient`; it is therefore an abstraction for two native BLE
implementations, not a generic radio boundary.

After hardware and its adapter protocol are selected, the smallest change is to
extract a transport-neutral coordinator port for:

1. peer discovery/selection and session readiness;
2. sending a bounded binary application frame to an explicit route;
3. data, disconnect and error events; and
4. a transport capability containing maximum payload and availability.

The BLE implementation would adapt its existing client to that port. A LoRa
implementation would adapt a physical accessory and keep the current envelopes,
message IDs, outbox ownership, ACK semantics and persistence above it. LoRa
fragmentation, radio airtime scheduling and on-air reassembly belong below that
port. Do not rename or refactor the working BLE coordinator until a chosen
device proves the needed operations; no placeholder or dependency was added in
this phase.

## Hardware and phone connection

Phones do not contain a LoRa radio. Each endpoint needs a certified sub-GHz
radio, MCU, antenna, power source and firmware. For a cross-platform prototype,
the preferred phone-to-adapter link is BLE GATT: iOS and Android both support
BLE accessory communication, and Apple states that BLE accessories use Core
Bluetooth without requiring the External Accessory/MFi path. Wired USB is less
uniform: Android host/accessory support depends on handset hardware, while the
iOS External Accessory path is controlled by the accessory manufacturer/MFi.

An evaluation board must combine BLE and a 920–925 MHz-capable LoRa radio. As
examples for investigation rather than a purchase decision, RAK lists an
nRF52840 + SX1262 BLE/LoRa module at USD 15, while Seeed lists LoRa-only/UART
development boards from USD 19.90–24.90. The latter still needs a BLE MCU or a
wired adapter. A realistic two-node prototype estimate is USD 80–250 total once
boards, antennas, batteries/enclosures, shipping and spare hardware are
included. Certification, custom PCB, firmware and field labor are excluded;
obtain current Thai-compliant vendor quotes before procurement.

Sources: [Apple Core Bluetooth and MFi guidance](https://developer.apple.com/bluetooth/),
[Apple External Accessory](https://developer.apple.com/documentation/externalaccessory/),
[Android USB host/accessory overview](https://developer.android.com/develop/connectivity/usb),
[RAK BLE/LoRa modules](https://store.rakwireless.com/collections/lpwan-modules),
[Seeed LoRa board pricing](https://www.seeedstudio.com/lora-series).

## Radio and regulatory constraints

Thailand is listed as AS923-1 at 920–925 MHz in the LoRa Alliance regional
parameters. The NBTC equipment workflow lists LoRa non-RFID equipment at
920–925 MHz and distinguishes equipment at or below 50 mW from higher-power
Class A paths up to 4 W EIRP. The exact product, antenna, EIRP, certification,
channel access and operating mode must be reviewed against the current NBTC
technical standard before field transmission; selecting `AS923` in firmware
alone does not establish compliance.

LoRa is the radio modulation. LoRaWAN adds a network/gateway MAC and is not a
direct phone-to-phone protocol. A direct offline SOS accessory likely needs a
documented point-to-point protocol in adapter firmware; choosing LoRaWAN would
also require gateways/network availability and its own uplink/downlink timing.

The AS923 LoRaWAN table permits application payload sizes that vary sharply by
data rate and dwell-time configuration: published examples range from 11 bytes
at DR2 with a 400 ms dwell limit to 222 bytes at higher rates. Semtech lists the
SX1262 LoRa programmable bit rate up to 62.5 kbps, but useful low-rate,
long-link modes are much slower and airtime increases with spreading factor,
payload and retries. Existing BLE messages can span many 20-byte frames, so the
LoRa adapter must define a smaller fragment format, reassembly limits, timeout
and airtime budget. Chat attachments are out of scope; repeated Location
updates must be rate-limited. No throughput or range is guaranteed from chipset
link-budget figures.

Sources: [NBTC SDoC equipment bands](https://standard.nbtc.go.th/%E0%B8%9A%E0%B8%A3%E0%B8%B4%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%AD%E0%B8%AD%E0%B8%99%E0%B9%84%E0%B8%A5%E0%B8%99%E0%B9%8C/SDoC-Online.aspx),
[NBTC Class A equipment bands](https://standard.nbtc.go.th/%E0%B8%9A%E0%B8%A3%E0%B8%B4%E0%B8%81%E0%B8%B2%E0%B8%A3%E0%B8%AD%E0%B8%AD%E0%B8%99%E0%B9%84%E0%B8%A5%E0%B8%99%E0%B9%8C/ClassA.aspx),
[LoRa Alliance RP002-1.0.4](https://resources.lora-alliance.org/home/rp002-1-0-4-regional-parameters),
[AS923 payload table](https://lora-alliance.org/wp-content/uploads/2021/05/RP002-1.0.3-FINAL-1.pdf),
[Semtech SX1262 specifications](https://www.semtech.com/products/wireless-rf/lora-connect/sx1262).

## Security and delivery behavior

The current installation binding is an association aid, not cryptographic
authentication. A future direct-radio design needs device provisioning and
authenticated encryption with unique nonces and replay protection. It must bind
the authenticated accessory identity to the selected incident peer; a radio
address or sender-declared ID is insufficient. Keys must stay in platform secure
storage/accessory protected storage and must never derive from Firebase UID.

Application ACKs remain mandatory after durable persistence. Retries must reuse
the logical message ID, honor a radio airtime budget and jitter, and deduplicate
both fragments and completed messages. Negative, late, duplicate and wrong-peer
ACK behavior should retain the current fail-closed rules. A native radio TX
completion only means the adapter transmitted; it is not receiver persistence.

## Required field gate

Before implementation selection, obtain at least three identical certified
adapter prototypes and freeze firmware/radio parameters. Test open, obstructed,
indoor-floor and moving scenarios at multiple distances; both directions; SOS,
Chat and rate-limited Location; simultaneous send/collision; corrupt/missing
fragments; ACK loss; wrong key/peer; disconnect/reconnect; phone and adapter
restart; low battery; antenna/orientation variation; and coexistence with BLE.
Record PHY settings, payload bytes, airtime, RSSI/SNR, attempts, application ACK,
latency and energy usage. Tests must stay within the approved Thai radio limits.

Open risks are regulatory certification, accessory provisioning/recovery, iOS
background limits, BLE-to-adapter becoming the short-link failure point,
low-throughput fragmentation, collisions/duty limits, antenna/product design,
firmware update security and a substantially larger hardware/support surface.

