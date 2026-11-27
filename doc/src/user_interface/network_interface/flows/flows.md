---
title: "Flows"
description: "The \u2018Flows\u2019 entry in the top toolbar can be selected to visualize realtime traffic information on the currently"
outline: [2, 3]
lastUpdated: 2026-11-16T17:41:35+01:00
---

<a id="webguiflows"></a>

# Flows {#flows}

## Live {#live}

The ‘Flows’ entry in the top toolbar can be selected to visualize realtime traffic information on the currently
active flows. A flow can be thought of as a logical, bi-directional communication channel between two
hosts [^footnote-1]. Multiple simultaneous flows can exist between the same pair of hosts.

![Active Flows](../../../img/web_gui_flows_active.png "Active Flows Page")

Flows are uniquely identified via a 5-tuple composed of:

- Source and destination IP address
- Source and destination port
- Layer-4 protocol

Each flow is shown as a row entry in the flows table. Flows are sortable by application using the rightmost
dropdown menu at the top right edge of the table. Similarly, the other dropdown menu enables the user
to choose the number of flows displayed on each page.

Flows have multiple information fields, namely, Application, Layer-4 Protocol, Client and Server hosts,
Duration, Client and Server Breakdown, Current Throughput, Total Bytes, and Additional Information.

When the flows carry process or container information (for example flows exported by nProbe with eBPF), the
process and container names are shown next to the hosts: click one to see only the flows of that process or
container. The [Pods and Containers](/user_interface/network_interface/interface/containers.md#containers) page opens the flows of a pod or container in the same way; the active filters
are shown above the table and can be removed one by one.
Information fields are briefly discussed below.

### Detailed Flow Information {#detailed-flow-information}

By clicking the details button at the beginning of the flow, its details open in a side panel next
to the table; the expand icon of the panel opens them as a full page. Here all the information ntopng
has about the flow is displayed, and it is updated every few seconds while the flow is active (an arrow
next to the counters shows when they grow). When the flow is no longer in memory a message says so.

Flows of industrial protocols (Modbus, S7Comm, Profinet: Enterprise L) and flows carrying BGP
information have more tabs next to *Overview* with their protocol details. The tab is greyed out
when the details are not available, and its tooltip says why: ntopng decodes Modbus from the traffic
it captures, while the S7Comm and Profinet details are sent by nProbe for the flows it collects.

From the details page you can also:

- open the live flows of the same port, application or category, the client and server hosts and
  their MAC addresses;
- add the server name of the flow to a category or to an application (administrators): click the *+*
  next to the name, choose the category or application and confirm. A category is applied at once,
  an application after restarting ntopng;
- in the *Issues* table, exclude a check for this flow (Enterprise M), open the configuration of the
  check or the alerts of the flow;
- on inline interfaces (nEdge), drop the traffic of the flow (administrators): a confirmation is asked.

![Flow Details](../../../img/web_gui_flows_details.png "Flow Details Page")

### Application {#application}

Application is the Layer-7 program which is exchanging data through the flow. This is the piece of
software that lays closest to the end user. Examples of Applications are Skype, Redis, HTTP, and Bit
Torrent. Layer-7 applications are detected by the NTOP open source Deep Packet Inspection (DPI) engine
named nDPI [^footnote-2]. In case application detection fails, ntopng marks the flow as ‘Unknown’. If the detection
succeeds, the application name and an informative icon are shown.

Here is a list of possible informative icons:

> - The lock icon tells that the protocol carries information in a secure way (e.g. via SSL)
> - The thumb-up icons tells that the protocol is generally not harmful for network performance
> - The thumb-down icons tells that the protocol is generally harmful for network performance
> - The smile face tells that the protocol is generally used for user entertainment
> - The yellow triangle indicates a possible problem on the flow. By clicking a flow details it's possible to see what the reported problem is (e.g. flow with low goodput)

The application name can be clicked to see all hosts generating traffic for the application.

### Layer-4 Protocol (L4 Proto) {#layer-4-protocol-l4-proto}

The layer-4 protocol is the one used at the transport level. Most common transport protocol are the
reliable Transmission Control Protocol (TCP) and the best-effort User Datagram Protocol (UDP).

### Client {#client}

This field contains host and port information regarding the client endpoint of the flow. An host is
considered a client if it is the initiator of the flow. Information is shown as host:port and both information
are clickable. If the host has a public IP address, ntopng also shows the country flag for that client [^footnote-3] . A blue
flag is drawn when the host is the ntopng host.

### Server {#server}

Similarly to the client, this field contains information regarding the server endpoint of the flow. An host is
considered a server if it is not the initiator of the flow. We refer the reader to the previous paragraph for a
detailed description.

### Duration {#duration}

This is the amount of time that has elapsed since the flow was opened by the client.

### Breakdown {#breakdown}

Flows are bi-directional, in the sense that traffic flows both from the server to the client and from the client
to the server. This coloured bar gives and indication on the amount of traffic exchanged in each of the two
directions. Client to server traffic in shown in orange, while server to client in blue.

### Actual Throughput {#actual-throughput}

The throughput is computed periodically (the refresh time is a few seconds).

### Total Bytes {#total-bytes}

The amount of traffic exchanged thought the flow. This total value is the sum of traffic exchanged in each
of the two directions (client to server and server to client).

### TLS Information {#tls-information}

ntopng provides detailed information on TLS flows:

![TLS information](../../../img/web_gui_flows_tls_information.png)

- The TLS certificate requested by the client and the server names returned by the server
- The TLS certificate validity time frame
- Client and server [JA3] signatures, which represent a fingerprint of the most relevant
  information in the TLS handshake. By clicking on the signature it is possible to manually
  check if the signature corresponds to a known malware into the [abuse.ch database].
- The Client [TLS ALPN], which contains the list of application protocols provided
  by the client during the TLS handshake
- The supported TLS protocols of the client

This information is very valuable in identifying potential threats on the encrypted traffic,
which include but are not limited to:

- Malicious clients/server (by matching the JA3 signature)
- Expired TLS certificates
- Unsecure TLS protocols in use
- MITM TLS attacks

ntopng already reports such events with specialized alerts (the available alerts
depend on the ntopng version used). For an in depth discussion on the challenges with encrypted traffic and how
the metadata can help in identifying network threats, check out the related ntop
[blog post] and related posts.

### SSH Signature {#ssh-signature}

In a similar way to the JA3 TLS signature, [HASSH] is a fingerprint on the SSH handshake.
ntopng generates the HASSH fingerprint of both the client and the server hosts of the flow.
ntopng also extracts and visualizes the SSH application banner which usually reports the
name and version of the SSH client/server application used.

This information can be used to identify outdated and vulnerable programs, which
undermine the hosts security. Moreover, the HASSH fingerprint can be matched against
known malware signatures to identify known threats.

### DNS Signature {#dns-signature}

ntopng also extracts and visualizes information regarding DNS application.
It reports, in the following order, the DNS query type, the DNS query error and DNS query,
following the standard classification ([RFC1035]).

![DNS information](../../../img/web_gui_flows_dns_information.png)

### Info {#info}

Extra information nDPI is able to extract from the detected flow is made available in this field. This field
may include URLs, traffic profiles (in the Professional Version), contents of DNS requests, and so on.

[^footnote-1]: Actually, flows may also exist between a host and a multicast group, as well as a broadcast domain.

[^footnote-2]: <https://github.com/ntop/nDPI>

[^footnote-3]: These data are based on MaxMind databases.

### Issues {#issues}

A flow could have some issues (reported in the [Alerts](/basic_concepts/alerts.md#basicconceptalerts)).
All the issues of the flow are reported in the Detailed Flow Information page.

![DNS information](../../../img/web_gui_flows_issues_information.png)


<a id="minor-connection-state"></a>

### Major and Minor Connection State {#major-and-minor-connection-state}

A flow using TCP as the L4 Protocol will have major and minor connection state.

The major connection states are:

- **ATTEMPTED**
- **ESTABLISHED**
- **CLOSED**

For each major connection states, there are many minor connection states.

When the major connection state is **ATTEMPTED**, the minor connection state could be one of the following states:

- **S0**: Connection attempt seen, no reply.
- **REJ**: Connection attempt rejected.
- **RSTOS0**: The client sent a SYN followed by a RST, and we never saw a SYN-ACK from the server.
- **RSTRH**: The server sent a SYN ACK followed by a RST, and we never saw a SYN from the (purported) client.
- **SH**: The client sent a SYN followed by a FIN, and we never saw a SYN ACK from the server (hence the connection was “half” open).
- **SHR**: The server sent a SYN ACK followed by a FIN, and we never saw a SYN from the client.
- **OTH**: No SYN seen, just midstream traffic.

If the major connection state is **ESTABLISHED** the minor connection state is

- **S1**: Connection established, not terminated.

Finally, if the major connection state is **CLOSED**, the minor connection state could be one of the following states:

- **SF**: Normal establishment and termination.
- **S2**: Connection established and close attempt by the client seen (but no reply from the server).
- **S3**: Connection established and close attempt by the server seen (but no reply from the client).
- **RSTO**: Connection established, the client aborted (sent a RST).
- **RSTR**: The server sent a RST.

## Flow Analysis {#flow-analysis}

![Live Flows navigation bar](../../../img/live_flows_nav_bar.png "Live Flows navigation bar")

The flow analysis page allows flows to be analysed in an aggregated fashion instead of the classical 5-tuple. Basic aggregation criteria are available in all ntopng versions, whereas advanced ones only on selected Enterprise editions.

In every row:

- Click a host, an application, a port or a VLAN to keep only the rows with that value. The filter is shown above the table and can be removed from there.
- Click the icon next to a host or an Autonomous System to open its details page.
- Click the button in the Actions column to see the single flows (connections) of that row in the Flows view.

### Application Protocol {#application-protocol}

![Live Flows Analysis Application Criteria](../../../img/live_flows_analysis_app_criteria.png)

This criteria allows you to aggregate flows according to the application protocol (e.g. WhatsApp). This is useful for selecting all flows with a specific protocol.

### Client {#id1}

![Live Flows Analysis Client Criteria](../../../img/live_flows_analysis_client_criteria.png)

You can use this aggregation criteria to cluster all flows originated by a specific client.

### Server Criteria {#server-criteria}

![Live Flows Analysis Server Criteria](../../../img/live_flows_analysis_server_criteria.png)

You can use this aggregation criteria to cluster all flows targeting a specific server.

### Client / Server / Destination Port Criteria {#client-server-destination-port-criteria}

![Live Flows Analysis Client Server Dst Port Criteria](../../../img/live_flows_analysis_client_server_dst_port_criteria.png)

You can use this aggregation criteria to cluster all flows with the same Client/Server/DstPort.

::: info
The following aggregation criteria are available only from Enterprise M license or superior.
:::

### Client / Server Criteria {#client-server-criteria}

![Live Flows Analysis Client / Server Criteria](../../../img/live_flows_analysis_client_server_criteria.png)

You can use this aggregation criteria to cluster all flows with the same Client/Server.

### App. Proto / Client / Server Criteria {#app-proto-client-server-criteria}

![Live Flows Analysis App. Proto / Client / Server Criteria](../../../img/live_flows_analysis_app_client_server_criteria.png)

You can use this aggregation criteria to cluster all flows with the same Application Protocol/Client/Server.

### Info Criteria {#info-criteria}

![Live Flows Analysis Info Criteria](../../../img/live_flows_analysis_info_criteria.png)

You can use this aggregation criteria to cluster all flows with the same information field (e.g. resolved host name in DNS flows).

## Geo Map View {#geo-map-view}

An other way to visualize the flows on a Geo Map;

::: info
This feature is available from the Enterprise L. The [Geolocation](/basic_concepts/geolocation.md#geolocation) needs to be enabled.
:::

When clicking on an host the flows relative to that node will be highlighted with the information:

- IP Address: IP Address of the host
- Protocol: protocol used by the flows
- Total Flows: number of flows by the host

![Live Flows Analysis Info Criteria](../../../img/geomap_live_flows.png)

[abuse.ch database]: https://sslbl.abuse.ch/ja3-fingerprints
[blog post]: https://www.ntop.org/ndpi/effective-tls-fingerprinting-beyond-ja3
[hassh]: https://engineering.salesforce.com/open-sourcing-hassh-abed3ae5044c
[ja3]: https://github.com/salesforce/ja3
[rfc1035]: https://datatracker.ietf.org/doc/html/rfc1035
[tls alpn]: https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation
