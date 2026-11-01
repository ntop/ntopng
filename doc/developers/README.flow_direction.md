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
involved returns immediately (including `Flow::swap()`), and the client is
always the sender of the first packet.

Packet interfaces
-----------------

The direction is decided by nDPI (`src/lib/ndpi_direction.c`, configuration
`flow.direction`, enabled by default): ntopng asks it whether the flow is
reversed and, when it is, swaps the flow **at once**.

| ntopng function | Called by | nDPI API |
|-----------------|-----------|----------|
| `Flow::checkDirection()` | `Flow::processPacket()`, after each packet processed by nDPI (also the extra dissection), and `Flow::endProtocolDissection()`, after the giveup | `ndpi_is_flow_reversed()` |
| `Flow::checkTCPDirection()` | `NetworkInterface::processPacket()`, for each TCP packet seen after nDPI has been freed | `ndpi_is_flow_reversed_by_tcp_flags()` |

The `direction_decided` bit of the flow is set once nDPI says the direction is
final (`NDPI_DIRECTION_FINAL`): from then on it does not change.

When the client of the flow is not one of the endpoints seen by nDPI (the APIs
return -1: never expected, as ntopng passes nDPI the packets of the flow), the
verdict is ignored: no swap, and `direction_decided` is not set.

### Rules (nDPI)

nDPI updates the direction with every packet passed to
`ndpi_detection_process_packet()` and at `ndpi_detection_giveup()`, until it is
final. The evidence, from the strongest to the weakest:

1. **TCP handshake**. The first SYN (sent by the client) or SYN-ACK (sent by
   the server) seen decides the direction, whatever came before it, e.g. a
   stray ACK/RST/FIN of a previous connection, or a SYN-ACK captured before its
   SYN. Final.
2. **Requests and replies**, only when the protocol is detected by DPI (a
   protocol guessed by the port is not trusted to read the payload). Final.
3. **Default ports of the detected protocol**, once the protocol is detected:
   the side using one of its default ports (master protocol first, then app
   protocol) is the server, when only one side uses one, e.g. SMTP on port 587
   from port 515. TCP with any confidence; UDP only by DPI (when guessed by the
   ports, the port of the guess is a default port by definition, and the
   packets of any protocol sent to a known port would be swapped). Final for
   UDP; for TCP once the flow has carried payload (any handshake of the
   connection came before it).
4. **Port order**, on the first packet (when it is not a TCP packet with the
   SYN flag): the lower port is the server. Not for UDP (it would be often
   wrong, e.g. RTP or probing). Nothing is done when the client would be a
   non-unicast address.
5. Otherwise the sender of the first packet is the client.

The requests and the replies:

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

* Packets that do not tell it (e.g. NTP symmetric or broadcast modes, ICMP
  errors, SNMP messages that cannot be decoded) leave the decision to a later
  packet.
* RECONFIGURE (DHCPv6) is sent by the server unsolicited: it is on the server
  side, as a reply. SNMP traps and informs are sent by the client: their
  receiver (usually port 162) is the server.
* A reply sent to a non-unicast address does not move the client (e.g. a DHCP
  reply sent to broadcast). nDPI knows only the addresses that are non-unicast
  everywhere: 0.0.0.0, 255.255.255.255, the multicast addresses, `::` and
  `ff00::/8`. The network and broadcast addresses of the local networks are
  known only by ntopng (`IpAddress::isNonEmptyUnicastAddress()`): ntopng does
  not swap a flow when its client would become one of them, its client being
  unicast (`Flow::isSwapToNonUnicast()`, e.g. a DHCP reply sent to
  192.168.1.255). The direction is still final when nDPI says so.
* L4 protocols other than TCP, UDP, ICMP and ICMPv6 (e.g. SCTP): the client is
  the sender of the first packet.
* Flows with neither a handshake nor a default port (e.g. mid-stream flows of
  an unknown protocol, or TLS on a non-default port) can only be guessed by the
  port order: with the client port lower than the server port they stay
  reversed.

### After nDPI

ntopng frees nDPI once the detection (and the extra dissection) is completed,
e.g. after 12 packets without a detection. A TCP flow whose direction is not
final yet (no payload and no handshake seen, e.g. one-way traffic of RSTs) is
still decided by a later SYN or SYN-ACK (`Flow::checkTCPDirection()`): nDPI is
given only the flags of the packet and the current direction of the flow
(`ndpi_is_flow_reversed_by_tcp_flags()`, stateless).

The UDP and ICMP flows are not changed after nDPI.

No swap is done when nDPI is given up while the flow is being deleted
(`Flow::~Flow()`, `accountFlowTraffic()`).

How a swap is performed
-----------------------

### At once

When nDPI says the flow is reversed, `Flow::swapNow()` swaps it immediately
(`Flow::swap()`) and reverses the direction of the current packet
(`src2dst_direction`), which `Flow::processPacket()` and
`Flow::checkTCPDirection()` return to `NetworkInterface::processPacket()` for
the code following them (e.g. the HTTP, DNS and QUIC dissection, the DNS and
SNMP flood counters). The traffic of the packet has already been accounted
(`Flow::incStats()`, TCP flags, TOS) with the old direction, and it is swapped
with the rest of the flow.

The swap happens before the detection is completed (also by the giveup), so
that the protocol detected processing, the server ports of the hosts, the
checks, the dumps and the view get the actual peers.

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

A flow can be swapped more than once, e.g. by the port order on the first
packet, then by the default ports at the detection.

### Requested swaps (nEdge)

On nEdge the swap is only requested (`swap_requested`), as it waits for the MAC
address of the server: `NetworkInterface::getFlow()` swaps the flow with the
first packet sent by the server. Until then the code that needs the actual
peers uses `Flow::get_actual_peers()` and `Flow::get_actual_peers_ip()`, which
take a pending swap into account, the protocol detected checks are not run by
`Flow::housekeep()`, and a swap still pending when there are no more packets is
performed by `Flow::performPendingSwap()` (flow end, end of a pcap file).

Collected flows (ZMQ)
---------------------

Collected flows are not checked by the functions above. The direction is set
when the flow is parsed (`ZMQParserInterface::preprocessFlow()`):

* flows swapped by nProbe (`ParsedFlow::isSwapped()`) are marked with
  `swap_done`;
* otherwise the lower port is the server, except for UDP, non-unicast
  addresses, and TCP flows whose client has sent a SYN (the TCP flags are in OR,
  so the handshake order is not known).

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
  client of the flow. When the direction is final, the server of the flow is
  the DHCP server; otherwise (replies sent to broadcast, direction not decided,
  collected flows) the ports tell it.
* nDPI: `ndpiReader` prints the direction of each flow (`[Client: ...]
  [Direction: <state>, <evidence>]`), and its tests include the
  `direction_*.pcap` captures of the cases above.

Tests
-----

The e2e tests (`tests/e2e/rest/tests/v2`) cover the cases above, with and
without a view interface (`*_view_*`):

* `tcp_direction_01`: TCP handshake orders, stray packets, mid-stream flows,
  SSH, TLS, SMTP default ports, late handshake packets (also after nDPI has
  been freed, e.g. one-way RSTs);
* `flow_direction_l7_01`: NTP and ICMP requests and replies, SIP and QUIC
  default ports;
* `flow_direction_guessed_01`: no swap when the protocol is not detected by
  DPI;
* `flow_direction_dhcp_01`, `flow_direction_dhcp_02`,
  `flow_direction_dhcpv6_01`: DHCP and DHCPv6 messages;
* `flow_direction_snmp_01`: SNMPv1/v2c/v3 requests, replies, traps, informs;
* `flow_direction_swap_01`: DNS and SSH flows, swapped flows dumped to
  ClickHouse;
* `peers_swap_heuristic_01`-`03`: SSH and TLS flows without the handshake.
