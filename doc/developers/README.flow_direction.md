Flow Direction (Client and Server)
==================================

A flow is created with the sender of its first packet as the client
(`cli_*` fields) and the receiver as the server (`srv_*` fields). The first
packet is often not sent by the client (e.g. a capture started mid-connection,
a lost SYN, a reply captured before its request), so ntopng checks the
direction and swaps the flow when it is reversed.

This document describes how the direction is decided and how the swap is
performed.

Preference
----------

Everything below is done only when the flow swap heuristic is enabled
(`ntopng.prefs.enable_flow_swap_heuristic`, enabled by default,
`Prefs::isFlowSwapHeuristicEnabled()`). When it is disabled, every function
involved returns immediately (including `Flow::request_swap()` and
`Flow::swap()`), and the client is always the sender of the first packet.

Packet interfaces
-----------------

The direction is decided by different functions, depending on the L4 protocol:

| L4 protocol | Function | Evidence |
|-------------|----------|----------|
| TCP | `checkTCPDirection()`, `checkDirectionByProtocol()`, `check_swap()` | handshake, default ports of the protocol, port order |
| UDP | `checkL7Direction()`, `checkDirectionByProtocol()` | request or reply (DNS, NTP, DHCP, DHCPv6, SNMP), default ports of the protocol detected by DPI |
| ICMP, ICMPv6 | `checkL7Direction()` | request or reply (echo, timestamp, information) |
| Others | `check_swap()` | port order, on the first packet |

The `direction_decided` bit of the flow is set once the direction is final:
from then on it does not change.

### TCP

The evidence, from the strongest to the weakest:

1. **Handshake** (`Flow::checkTCPDirection()`, called by
   `NetworkInterface::processPacket()` for every packet). The first SYN (sent by
   the client) or SYN-ACK (sent by the server) seen decides the direction,
   whatever came before it, e.g. a stray ACK/RST/FIN of a previous connection,
   or a SYN-ACK captured before its SYN. The decision is final.
2. **Default ports of the detected protocol**
   (`Flow::checkDirectionByProtocol()`, called at the beginning of
   `Flow::processDetectedProtocol()`, i.e. once, when the detection is
   completed, either by nDPI or by the giveup). When no handshake has been
   seen, the side using one of the default TCP ports of the detected protocol
   (nDPI, `ndpi_get_proto_defaults()`, master protocol first, then app
   protocol) is the server, e.g. SMTP on port 587 from port 515. Nothing is
   changed when both sides or neither use a default port. It takes into
   account a swap still pending: it requests a swap, or cancels the pending one
   when it was wrong.
3. **Port order** (`Flow::check_swap()`, called by `checkTCPDirection()` on the
   first packet of the flow, when it is not a handshake packet). The lower port
   is the server. Nothing is done when the client would be a non-unicast
   address.

Steps 3 and 2 happen first in time: step 3 on the first packet, step 2 at the
detection, step 1 whenever a SYN or SYN-ACK is seen.

The direction is also final once the protocol is detected on a flow that has
carried payload (`non_zero_payload_observed`, set by `Flow::processPacket()`
before the detection can be completed).

Flows with neither a handshake nor a default port (e.g. mid-stream flows of an
unknown protocol, or TLS on a non-default port) can only be guessed by the
port order: with the client port lower than the server port they stay
reversed.

### UDP and ICMP

`Flow::checkL7Direction()` is called by `Flow::processPacket()` for each
packet processed by nDPI, until the direction is decided. The first packet
whose payload tells whether it is a request (sent by the client) or a reply
(sent by the server) decides the direction:

| Protocol | Request | Reply |
|----------|---------|-------|
| DNS (UDP) | QR bit clear | QR bit set |
| NTP | mode 3 (client); mode 6 (control) and 7 (private) with the R bit clear | mode 4 (server); mode 6 and 7 with the R bit set |
| DHCP | op BOOTREQUEST | op BOOTREPLY |
| DHCPv6 | SOLICIT, REQUEST, CONFIRM, RENEW, REBIND, RELEASE, DECLINE, INFORMATION-REQUEST, RELAY-FORW, LEASEQUERY, RECONFIGURE-REQUEST, DHCPV4-QUERY, ADDR-REG-INFORM | ADVERTISE, REPLY, RECONFIGURE, RELAY-REPL, LEASEQUERY-REPLY, RECONFIGURE-REPLY, DHCPV4-RESPONSE, ADDR-REG-REPLY |
| SNMP | v1/v2c and v3 not encrypted: any PDU but Response and Report; v3 encrypted: reportable flag set, or sent to port 162 (a trap) | v1/v2c and v3 not encrypted: Response, Report; v3 encrypted: otherwise |
| ICMP | echo, timestamp and information request | echo, timestamp and information reply |
| ICMPv6 | echo request | echo reply |

Notes:

* Only with DPI confidence (`ndpiFlow->core.confidence ==
  NDPI_CONFIDENCE_DPI`): a protocol guessed by the port is not trusted to read
  the payload.
* Packets that do not tell it (e.g. NTP symmetric or broadcast modes, ICMP
  errors, SNMP messages that cannot be decoded) leave the decision to a later
  packet.
* RECONFIGURE (DHCPv6) is sent by the server unsolicited: it is on the server
  side, as a reply.
* SNMP traps and informs are sent by the client: their receiver (usually port
  162) is the server. The PDU type is read also in SNMPv3 messages, when not
  encrypted (privacy flag clear); for the encrypted ones the header is used
  (`isSNMPReply()`, with the BER helpers of nDPI).
* Once decided (`direction_decided`), a reversed flow is swapped **at once**
  (`request_swap()` followed by `swap()`), before the detection is completed,
  so that checks, services, dumps and the view get the actual peers.
* The flow is not swapped when the client would be a non-unicast address (e.g.
  a DHCP reply sent to broadcast).
* UDP flows not decided by their requests and replies (e.g. SIP, QUIC):
  once the protocol is detected, the side using one of its default UDP ports
  is the server, when only one side uses one (`checkDirectionByProtocol()`,
  as for TCP). The direction is then final: requests or replies seen later
  (extra dissection) do not change it. Only when the protocol is detected by DPI
  (`NDPI_CONFIDENCE_DPI`): when it is guessed by the ports, the port of the
  guess is a default port by definition, and the packets of any protocol sent
  to a known port (e.g. not DNS on port 53) would be swapped.
* There is no guess by the port order for UDP (`check_swap()` ignores UDP, as
  it would be often wrong, e.g. RTP or probing) and ICMP (no ports).

### Other L4 protocols

`Flow::check_swap()` on the first packet: the lower port is the server.

How a swap is performed
-----------------------

### Request

`Flow::request_swap()` only sets `swap_requested`. Until the swap is
performed, the code that needs the actual peers uses
`Flow::get_actual_peers()` and `Flow::get_actual_peers_ip()`, which take a
pending swap into account (e.g. `processDetectedProtocol()`, the periodicity
hash).

The swap is not performed at once because the direction of the current packet
(`src2dst_direction`) is still used by the code following the check.

### Execution

`Flow::swap()` exchanges the client and the server of the flow:

* hosts (moving the client/server flow counters of the hosts) or, with viewed
  interfaces (flows without hosts), the IP addresses;
* ports, MAC addresses, AS numbers, TOS;
* traffic counters, TCP flags, TCP sequence numbers, windows, TCP stats, RTT
  acks, inter-arrival times, partial stats of the dumps, periodic stats;
* attacker/victim flags of the alerts.

L7 information and latency counters are not swapped. At the end `swap_done` is
set and `swap_requested` is cleared.

A requested swap is performed:

* by the next packet of the flow, in either direction (`FlowHash::find()`
  returns the flow to swap, `NetworkInterface::getFlow()` swaps it and
  recomputes the direction of the packet);
* when there are no more packets (`Flow::performPendingSwap()`): when the flow
  ends (`flow_end_housekeeping()`), and before dumping the active flows once a
  pcap file has been read. This covers flows with a single packet, and swaps
  requested after the last packet (e.g. at the detection completed by the
  giveup).

A flow can be swapped more than once, e.g. a swap requested by the port order,
performed by the next packet, then a swap requested at the detection by the
default ports.

### Protocol detected checks

While a swap is pending the protocol detected checks are not run by
`Flow::housekeep()`: they are run on the swapped flow, by
`performPendingSwap()`.

Collected flows (ZMQ)
---------------------

Collected flows are not checked by the functions above: there are no packets,
only the fields exported by the probe (e.g. nProbe), and a flow is created
with the source of the exported record as the client. The direction is
decided when the record is parsed, before the flow is created or updated
(`ZMQParserInterface::preprocessFlow()`), following the rules of the packet
interfaces as far as the exported fields allow. A reversed record is swapped
with `ParsedFlow::swap()` (all the fields: addresses, ports, MAC addresses,
traffic counters, TCP flags, latencies, interface indexes, AS numbers, QoE),
and the flow is marked with `swap_done` (`ParsedFlow::isSwapped()`).

Nothing is done for non-unicast addresses (the client is never a broadcast or
multicast address) and for eBPF events (their direction is reliable).

### TCP

The evidence, from the strongest to the weakest (the first one that tells
decides):

1. **Handshake** (`isTCPServerFirstByFlags()`). The TCP flags are exported in
   OR for each direction (`CLIENT_TCP_FLAGS`, `SERVER_TCP_FLAGS`), so the
   order of the packets is not known: only a peer that has sent a SYN and
   never an ACK is known to be the client (it only sent the SYN of the
   handshake, e.g. a connection refused or not answered). A SYN together with
   an ACK can be both a SYN followed by other packets (e.g. a client whose
   packets in the other direction have not been captured) and a SYN-ACK (e.g.
   a server whose client SYN has not been captured).
2. **Default ports of the detected protocol**
   (`isServerFirstByDefaultPort()`): as `Flow::checkDirectionByProtocol()`,
   with the protocol exported by the probe (`L7_PROTO`, master protocol first,
   then app protocol) and `Utils::isDefaultPort()`. Not limited to the DPI
   confidence, as for the packet interfaces.
3. **Port order**, as `Flow::check_swap()`: the lower port is the server,
   unless the source has sent a SYN.

### UDP

Only the default ports of the protocol detected **with DPI** (`L7_CONFIDENCE`
exported as `NDPI_CONFIDENCE_DPI`, `isServerFirstByDefaultPort()`): e.g. a DNS
reply whose request has not been captured, exported as `8.8.8.8:53 ->
client:56696`, is swapped. There is no port order, as for the packet
interfaces. The requests and replies cannot be told (the payload is not
exported).

Records without the confidence (e.g. older probes) or with the protocol
guessed by the ports, and flows where both or no ports are default ports (e.g.
DNS 53 <-> 53), keep the direction of the probe.

### Other L4 protocols

The lower port is the server (ICMP flows have no ports).

### Notes

* The protocol ids exported by the probe are looked up in the nDPI of ntopng
  (`ndpi_get_proto_defaults()`): with different nDPI versions the ids of the
  less common protocols might not match.
* Each record of a flow (e.g. the periodic records of a long flow) is checked
  on its own; the records of a flow carry the same protocol and flags in OR,
  so they get the same direction. `getFlow()` finds the flow in both
  directions anyway.
* The direction is not checked again once the flow is created: there is no
  pending swap and no race with the view interfaces (see below).
* The probe is the best place to decide the direction (it sees the packets,
  e.g. the nDPI of nProbe knows the client of a DNS reply): these rules fix
  the records that the probe exports reversed.

View interfaces
---------------

The flows of a viewed interface have no hosts: `Flow::swap()` only exchanges
their IP addresses. The view sets the client and the server hosts of a flow at
its first visit, while the flow can be swapped later on. At each visit
`ViewInterface::checkViewedFlowSwap()` (pro) compares the IP addresses of the
flow with the ones of its hosts and, when they are reversed, swaps the hosts,
the traffic snapshotted by the view and the client/server flow counters of the
hosts.

Related
-------

* `Flow::isDHCPServerClient()`: whether the DHCP (or DHCPv6) server is the
  client of the flow. When the direction has been decided by the requests and
  replies, the server of the flow is the DHCP server; otherwise (replies sent
  to broadcast, direction not decided, collected flows) the ports tell it.

Tests
-----

The e2e tests (`tests/e2e/rest/tests/v2`) cover the cases above, with and
without a view interface (`*_view_*`):

* `tcp_direction_01`: TCP handshake orders, stray packets, mid-stream flows,
  SSH, TLS, SMTP default ports, late handshake packets;
* `flow_direction_l7_01`: NTP and ICMP requests and replies, SIP and QUIC
  default ports;
* `flow_direction_guessed_01`: no swap when the protocol is not detected by
  DPI;
* `flow_direction_dhcp_01`, `flow_direction_dhcp_02`,
  `flow_direction_dhcpv6_01`: DHCP and DHCPv6 messages;
* `flow_direction_snmp_01`: SNMPv1/v2c/v3 requests, replies, traps, informs;
* `flow_direction_swap_01`: DNS and SSH flows, swaps performed when no packet
  follows the request (dumped to ClickHouse);
* `peers_swap_heuristic_01`-`03`: SSH and TLS flows without the handshake.

The collected flows are not covered by the e2e tests (they replay pcap files
only): they can be checked by exporting a pcap file with nProbe to a ZMQ
collector interface (`nprobe -i <pcap> --ntopng zmq://127.0.0.1:<port>
--zmq-probe-mode -T "@NTOPNG@"` and `ntopng -i tcp://127.0.0.1:<port>c`).
