---
title: "Metrics"
description: "Here is the full list of metrics exported as timeseries by ntopng. There are two types of metrics exported by ntopng currently: counters and gauges."
outline: [2, 3]
lastUpdated: 2026-10-21T10:36:08+02:00
---
# Metrics {#metrics}

Here is the full list of metrics exported as timeseries by ntopng.

There are two types of metrics exported by ntopng currently: **counters** and **gauges**.

- **counters** are used for continuous incrementing metrics such as the total number of bytes.
- **gauges** are used for metrics such as the number of active flows or active hosts at a certain point in time.

ntopng supports two backends for storing timeseries: RRD and InfluxDB. The supported resolution may change
based on the backend and can be configured through the Runtime Preferences (this is the case of InfluxDB for
some of the metrics as reported below).

## Interface Metrics {#interface-metrics}

::: info iface:traffic
Total number of bytes for an interface.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:traffic_rxtx
Total number of sent and received bytes for an interface.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info iface:packets
Total number of packets captured from an interface.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name    | Description       |
| ------- | ----------------- |
| packets | Packets captured. |
:::

::: info iface:zmq_recv_flows
Total number of flows received from a ZMQ socket.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name  | Description     |
| ----- | --------------- |
| flows | Flows received. |
:::

::: info iface:zmq_flow_coll_drops
Total number of dropped flows for a ZMQ interface.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name  | Description    |
| ----- | -------------- |
| drops | Dropped flows. |
:::

::: info iface:exported_flows
Total number of exported flows.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description               |
| --------- | ------------------------- |
| num_flows | Number of exported flows. |
:::

::: info iface:dropped_flows
Total number of dropped flows.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description              |
| --------- | ------------------------ |
| num_flows | Number of dropped flows. |
:::

::: info iface:drops
Total number of dropped packets on an interface.

- **Type**: counter
- **Resolution**: 1s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name    | Description      |
| ------- | ---------------- |
| packets | Dropped packets. |
:::

::: info iface:ndpi
Total number of bytes per application protocol (nDPI) for an interface.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name     | Description                 |
| -------- | --------------------------- |
| ifid     | Interface index             |
| protocol | Application protocol (nDPI) |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:ndpi_categories
Total number of bytes per application protocol category (nDPI) for an interface.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name     | Description                          |
| -------- | ------------------------------------ |
| ifid     | Interface index                      |
| category | Application protocol category (nDPI) |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:l4protos
Total number of bytes per L4 protocol for an interface.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name    | Description     |
| ------- | --------------- |
| l4proto | L4 protocol     |
| ifid    | Interface index |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:ndpi_flows
Total number of flows per application protocol (nDPI) for an interface.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name     | Description                 |
| -------- | --------------------------- |
| ifid     | Interface index             |
| protocol | Application protocol (nDPI) |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_flows | Number of flows. |
:::

::: info iface:local2remote
Total number of bytes from Local hosts to Remote hosts for an interface.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:remote2local
Total number of bytes from Remote hosts to Local hosts for an interface.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:hosts
Number of hosts on an interface.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_hosts | Number of hosts. |
:::

::: info iface:local_hosts
Number of local hosts on an interface.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_hosts | Number of hosts. |
:::

::: info iface:devices
Number of devices on an interface.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name        | Description        |
| ----------- | ------------------ |
| num_devices | Number of devices. |
:::

::: info iface:flows
Number of flows on an interface.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_flows | Number of flows. |
:::

::: info iface:http_hosts
Total number of Local HTTP hosts.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_hosts | Number of hosts. |
:::

::: info iface:nfq_pct
Netfilter queue length (nEdge).

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name        | Description   |
| ----------- | ------------- |
| num_nfq_pct | Queue length. |
:::

::: info iface:1d_delta_traffic_volume
Number of bytes seen on an interface.

- **Type**: gauge
- **Resolution**: 1h

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

::: info iface:1d_delta_flows
Number of flows seen on an interface.

- **Type**: gauge
- **Resolution**: 1h

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_flows | Number of flows. |
:::

## Device Metrics {#device-metrics}

::: info mac:traffic
Total number of bytes sent and received by a L2 device.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| mac  | MAC address     |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info mac:arp_rqst_sent_rcvd_rpls
Total ARP requests sent and replies received by a L2 device.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| mac  | MAC address     |

**Fields**

| Name                 | Description           |
| -------------------- | --------------------- |
| request_packets_sent | ARP requests sent.    |
| reply_packets_rcvd   | ARP replies received. |
:::

::: info mac:ndpi_categories
Total number of bytes per category (nDPI) for a L2 device.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                          |
| -------- | ------------------------------------ |
| ifid     | Interface index                      |
| mac      | MAC address                          |
| category | Application protocol category (nDPI) |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

## Host Metrics {#host-metrics}

::: info host:traffic
Total number of bytes sent and received by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info host:active_flows
Number of active flows for a host.

- **Type**: gauge
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name            | Description                              |
| --------------- | ---------------------------------------- |
| flows_as_client | Number of flows with the host as client. |
| flows_as_server | Number of flows with the host as server. |
:::

::: info host:total_flows
Total number of flows for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name            | Description                                    |
| --------------- | ---------------------------------------------- |
| flows_as_client | Total number of flows with the host as client. |
| flows_as_server | Total number of flows with the host as server. |
:::

::: info host:misbehaving_flows
Total number of misbehaving flows for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name            | Description                                                |
| --------------- | ---------------------------------------------------------- |
| flows_as_client | Total number of misbehaving flows with the host as client. |
| flows_as_server | Total number of misbehaving flows with the host as server. |
:::

::: info host:unreachable_flows
Total number of ICMP Port Unreachable flows for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name            | Description                                                          |
| --------------- | -------------------------------------------------------------------- |
| flows_as_client | Total number of ICMP Port Unreachable flows with the host as client. |
| flows_as_server | Total number of ICMP Port Unreachable flows with the host as server. |
:::

::: info host:host_unreachable_flows
Total number of ICMP Host Unreachable flows for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name            | Description                                                          |
| --------------- | -------------------------------------------------------------------- |
| flows_as_client | Total number of ICMP Host Unreachable flows with the host as client. |
| flows_as_server | Total number of ICMP Host Unreachable flows with the host as server. |
:::

::: info host:ndpi_flows
Total number of flows per application protocol (nDPI) for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                 |
| -------- | --------------------------- |
| ifid     | Interface index             |
| host     | Host                        |
| protocol | Application protocol (nDPI) |

**Fields**

| Name      | Description            |
| --------- | ---------------------- |
| num_flows | Total number of flows. |
:::

::: info host:echo_packets
Total number of ICMP Echo packets sent and received by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name         | Description                                             |
| ------------ | ------------------------------------------------------- |
| packets_sent | Total number of ICMP Echo packets sent by the host.     |
| packets_rcvd | Total number of ICMP Echo packets received by the host. |
:::

::: info host:echo_reply_packets
Total number of ICMP Echo Reply packets sent and received by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name         | Description                                                   |
| ------------ | ------------------------------------------------------------- |
| packets_sent | Total number of ICMP Echo Reply packets sent by the host.     |
| packets_rcvd | Total number of ICMP Echo Reply packets received by the host. |
:::

::: info host:dns_qry_sent_rsp_rcvd
Total number of DNS queries sent and replies received by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name                  | Description                                 |
| --------------------- | ------------------------------------------- |
| queries_packets       | Total number of DNS queries.                |
| replies_ok_packets    | Total number of DNS replies with no errors. |
| replies_error_packets | Total number of DNS replies with errors.    |
:::

::: info host:dns_qry_rcvd_rsp_sent
> Total number of DNS queries received and replies sent by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name                  | Description                                 |
| --------------------- | ------------------------------------------- |
| queries_packets       | Total number of DNS queries.                |
| replies_ok_packets    | Total number of DNS replies with no errors. |
| replies_error_packets | Total number of DNS replies with errors.    |
:::

::: info host:tcp_rx_stats
Total number of retransmitted, Out-Of-Order and lost TCP packets received by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name                   | Description                            |
| ---------------------- | -------------------------------------- |
| retransmission_packets | Total number of retransmitted packets. |
| out_of_order_packets   | Total number of Out-Of-Order packets.  |
| lost_packets           | Total number of lost packets.          |
:::

::: info host:tcp_tx_stats
Total number of retransmitted, Out-Of-Order and lost TCP packets sent by a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name                   | Description                            |
| ---------------------- | -------------------------------------- |
| retransmission_packets | Total number of retransmitted packets. |
| out_of_order_packets   | Total number of Out-Of-Order packets.  |
| lost_packets           | Total number of lost packets.          |
:::

::: info host:total_alerts
Total number of alerts generated by the host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name   | Description             |
| ------ | ----------------------- |
| alerts | Total number of alerts. |
:::

::: info host:contacts
Total number of contacts/peers with the host as client or server.

- **Type**: gauge
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name          | Description                                       |
| ------------- | ------------------------------------------------- |
| num_as_client | Total number of contacts with the host as client. |
| num_as_server | Total number of contacts with the host as server. |
:::

::: info host:l4protos
Total number of bytes sent and received by L4 protocol for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info host:udp_sent_unicast
Total number of bytes sent by the host for unicast and non unicast traffic.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name                   | Description               |
| ---------------------- | ------------------------- |
| bytes_sent_unicast     | Bytes sent (unicast).     |
| bytes_sent_non_unicast | Bytes sent (non unicast). |
:::

::: info host:ndpi
Total number of bytes sent and received per application protocol (nDPI) for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                 |
| -------- | --------------------------- |
| ifid     | Interface index             |
| host     | Host                        |
| protocol | Application protocol (nDPI) |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info host:ndpi_categories
Total number of bytes sent and received per category (nDPI) for a host.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                          |
| -------- | ------------------------------------ |
| ifid     | Interface index                      |
| host     | Host                                 |
| category | Application protocol category (nDPI) |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info host:1d_delta_traffic_volume
Number of bytes sent and received by a host.

- **Type**: gauge
- **Resolution**: 1h

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info host:1d_delta_flows
Number of flows for a host.

- **Type**: gauge
- **Resolution**: 1h

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_flows | Number of flows. |
:::

::: info host:1d_delta_contacts
Number of contacts/peers with the host as client or server.

- **Type**: gauge
- **Resolution**: 1h

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| host | Host            |

**Fields**

| Name      | Description                                 |
| --------- | ------------------------------------------- |
| as_client | Number of contacts with the host as client. |
| as_server | Number of contacts with the host as server. |
:::

## Subnet Metrics {#subnet-metrics}

::: info subnet:traffic
Total number of ingress/egress/inner bytes for a subnet.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name          | Description    |
| ------------- | -------------- |
| bytes_ingress | Ingress bytes. |
| bytes_egress  | Egress bytes.  |
| bytes_inner   | Inner bytes.   |
:::

::: info subnet:broadcast_traffic
Total number of bytes for brodcast traffic for a subnet.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name          | Description    |
| ------------- | -------------- |
| bytes_ingress | Ingress bytes. |
| bytes_egress  | Egress bytes.  |
| bytes_inner   | Inner bytes.   |
:::

::: info subnet:tcp_retransmissions
Total number of retransmitted TCP packets for a subnet.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name            | Description                    |
| --------------- | ------------------------------ |
| packets_ingress | Ingress Retransmitted packets. |
| packets_egress  | Egress Retransmitted packets.  |
| packets_inner   | Inner Retransmitted packets.   |
:::

::: info subnet:tcp_out_of_order
Total number of Out Of Order TCP packets for a subnet.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name            | Description                   |
| --------------- | ----------------------------- |
| packets_ingress | Ingress Out Of Order packets. |
| packets_egress  | Egress Out Of Order packets.  |
| packets_inner   | Inner Out Of Order packets.   |
:::

::: info subnet:rtt
Round Trip Time for a Network, computed as exponentially weighted moving average.

- **Type**: gauge
- **Resolution**: 1m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| millis_rtt | Round Trip Time |
:::

::: info subnet:tcp_lost
Total number of lost TCP packets for a subnet.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name            | Description               |
| --------------- | ------------------------- |
| packets_ingress | Ingress TCP lost packets. |
| packets_egress  | Egress TCP lost packets.  |
| packets_inner   | Inner TCP lost packets.   |
:::

::: info subnet:tcp_keep_alive
Total number of TCP Keepalives packets for a subnet.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| subnet | Subnet          |

**Fields**

| Name            | Description                     |
| --------------- | ------------------------------- |
| packets_ingress | Ingress TCP Keepalives packets. |
| packets_egress  | Egress TCP Keepalives packets.  |
| packets_inner   | Inner TCP Keepalives packets.   |
:::

## VLAN Metrics {#vlan-metrics}

::: info vlan:traffic
Total number of bytes sent and received for a VLAN.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| vlan | VLAN ID         |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info vlan:ndpi
Total number of bytes sent and received per application protocol (nDPI) for a VLAN.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                 |
| -------- | --------------------------- |
| ifid     | Interface index             |
| vlan     | VLAN ID                     |
| protocol | Application protocol (nDPI) |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

## SNMP Interface Metrics {#snmp-interface-metrics}

::: info snmp_if:traffic
Total number of bytes sent and received by a SNMP interface.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description          |
| -------- | -------------------- |
| ifid     | Interface index      |
| device   | SNMP device          |
| if_index | SNMP interface index |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info snmp_if:errors
Total number of packets discarded or with errors on a SNMP interface.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description          |
| -------- | -------------------- |
| ifid     | Interface index      |
| device   | SNMP device          |
| if_index | SNMP interface index |

**Fields**

| Name         | Description                          |
| ------------ | ------------------------------------ |
| packets_disc | Total number of discarded packets.   |
| packets_err  | Total number of packets with errors. |
:::

## Traffic Profile Metrics {#traffic-profile-metrics}

::: info profile:traffic
Total number of bytes for a Traffic Profile.

- **Type**: counter
- **Resolution**: 1m

**Tags**

| Name    | Description     |
| ------- | --------------- |
| ifid    | Interface index |
| profile | Profile name    |

**Fields**

| Name  | Description |
| ----- | ----------- |
| bytes | Bytes.      |
:::

## Host Pool Metrics {#host-pool-metrics}

::: info host_pool:traffic
Total number of bytes sent and received by a host pool.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pool | Host Pool       |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info host_pool:hosts
Number of hosts in a host pool.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pool | Host Pool       |

**Fields**

| Name      | Description      |
| --------- | ---------------- |
| num_hosts | Number of hosts. |
:::

::: info host_pool:devices
Number of devices in a host pool.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pool | Host Pool       |

**Fields**

| Name        | Description        |
| ----------- | ------------------ |
| num_devices | Number of devices. |
:::

::: info host_pool:blocked_flows
Total number of blocked flows for a host pool.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pool | Host Pool       |

**Fields**

| Name      | Description              |
| --------- | ------------------------ |
| num_flows | Number of blocked flows. |
:::

::: info host_pool:ndpi
Total number of bytes sent and received per application protocol (nDPI) for a host pool.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                 |
| -------- | --------------------------- |
| ifid     | Interface index             |
| pool     | Host Pool                   |
| protocol | Application protocol (nDPI) |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

## ASN Metrics {#asn-metrics}

::: info asn:traffic
Total number of bytes sent and received by an AS.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description                    |
| ---- | ------------------------------ |
| ifid | Interface index                |
| asn  | ASN (Autonomous System Number) |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info asn:ndpi
Total number of bytes sent and received per application protocol (nDPI) by an AS.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description                    |
| -------- | ------------------------------ |
| ifid     | Interface index                |
| asn      | ASN (Autonomous System Number) |
| protocol | Application protocol (nDPI)    |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info asn:rtt
Round Trip Time for an AS, computed as exponentially weighted moving average.

- **Type**: gauge
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description                    |
| ---- | ------------------------------ |
| ifid | Interface index                |
| asn  | ASN (Autonomous System Number) |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| millis_rtt | Round Trip Time |
:::

::: info asn:tcp_retransmissions
Total number of retransmitted TCP packets from/to an AS.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description                    |
| ---- | ------------------------------ |
| ifid | Interface index                |
| asn  | ASN (Autonomous System Number) |

**Fields**

| Name         | Description                        |
| ------------ | ---------------------------------- |
| packets_sent | Retransmitted packets from the AS. |
| packets_rcvd | Retransmitted packets to the AS.   |
:::

::: info asn:tcp_out_of_order
Total number of Out Of Order TCP packets from/to an AS.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description                    |
| ---- | ------------------------------ |
| ifid | Interface index                |
| asn  | ASN (Autonomous System Number) |

**Fields**

| Name         | Description                       |
| ------------ | --------------------------------- |
| packets_sent | Out Of Order packets from the AS. |
| packets_rcvd | Out Of Order packets to the AS.   |
:::

::: info asn:tcp_lost
Total number of lost TCP packets from/to an AS.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description                    |
| ---- | ------------------------------ |
| ifid | Interface index                |
| asn  | ASN (Autonomous System Number) |

**Fields**

| Name         | Description               |
| ------------ | ------------------------- |
| packets_sent | Lost packets from the AS. |
| packets_rcvd | Lost packets to the AS.   |
:::

::: info asn:tcp_keep_alive
Total number of TCP Keepalives packets from/to an AS.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name | Description                    |
| ---- | ------------------------------ |
| ifid | Interface index                |
| asn  | ASN (Autonomous System Number) |

**Fields**

| Name         | Description                         |
| ------------ | ----------------------------------- |
| packets_sent | TCP Keepalives packets from the AS. |
| packets_rcvd | TCP Keepalives packets to the AS.   |
:::

## Country Metrics {#country-metrics}

::: info country:traffic
Total number of ingress/egress/inner bytes for a country.

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name    | Description     |
| ------- | --------------- |
| ifid    | Interface index |
| country | Country         |

**Fields**

| Name          | Description            |
| ------------- | ---------------------- |
| bytes_ingress | Country ingress bytes. |
| bytes_egress  | Country egress bytes.  |
| bytes_inner   | Country inner bytes.   |
:::

## Flow Device Metrics {#flow-device-metrics}

::: info flowdev_port:traffic
Total number of bytes sent and received on a port of a flow device (nProbe).

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| device | Device IP       |
| port   | Port index      |

**Fields**

| Name       | Description     |
| ---------- | --------------- |
| bytes_sent | Bytes sent.     |
| bytes_rcvd | Bytes received. |
:::

::: info flowdev_port:usage
Usage of a port of a flow device, as percentage of the configured port speed.

- **Type**: gauge
- **Resolution**: 5m, or 1m when "Flow Exporters and nProbes Timeseries Resolution" is set to 1 minute

**Tags**

| Name   | Description     |
| ------ | --------------- |
| ifid   | Interface index |
| device | Device IP       |
| port   | Port index      |

**Fields**

| Name     | Description                     |
| -------- | ------------------------------- |
| uplink   | Uplink (out) usage percentage.  |
| downlink | Downlink (in) usage percentage. |
:::

::: info flowdev_port:ndpi
Total number of bytes sent and received by an application on a port of a flow device (nProbe).
Created when the "Flow Exporters L7 Application" preference is set to "Per Application".

- **Type**: counter
- **Resolution**: 5m, or 1m when "Flow Exporters and nProbes Timeseries Resolution" is set to 1 minute

**Tags**

| Name     | Description      |
| -------- | ---------------- |
| ifid     | Interface index  |
| device   | Device IP        |
| port     | Port index       |
| protocol | Application name |

**Fields**

| Name       | Description                |
| ---------- | -------------------------- |
| bytes_sent | Bytes sent (uplink).       |
| bytes_rcvd | Bytes received (downlink). |
:::

::: info flowdev_port:ndpi_usage
Usage of an application on a port of a flow device, as percentage of the configured port speed.
This metric is not stored: it is calculated at query time from `flowdev_port:ndpi` and the
port uplink/downlink speed, so it is only available through the timeseries REST API
(e.g. `/lua/rest/v2/get/timeseries/ts.lua`).

- **Type**: gauge (derived)
- **Resolution**: same as `flowdev_port:ndpi`

**Tags**

Same as `flowdev_port:ndpi`, `ifid`, `device` and `port` are mandatory.

**Fields**

| Name       | Description                     |
| ---------- | ------------------------------- |
| bytes_sent | Uplink (out) usage percentage.  |
| bytes_rcvd | Downlink (in) usage percentage. |

The top applications usage, for a single direction, can be requested with the
`top:flowdev_port:ndpi_usage_downlink` and `top:flowdev_port:ndpi_usage_uplink` schemas.
:::

## Event Exporter Metrics {#event-exporter-metrics}

::: info evexporter_iface:traffic
Total number of bytes sent and received on an interface of an event probe (nProbe Agent).

- **Type**: counter
- **Resolution**: 5m (RRD) / 10s-1min according to preferences (InfluxDB)

**Tags**

| Name     | Description     |
| -------- | --------------- |
| ifid     | Interface index |
| exporter | Exporter IP     |
| ifname   | Interface name  |

**Fields**

| Name       | Description                 |
| ---------- | --------------------------- |
| bytes_sent | Bytes sent (Out Octets).    |
| bytes_rcvd | Bytes received (In Octets). |
:::

## Container Metrics {#container-metrics}

::: info container:num_flows
Number of flows for a container.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name      | Description     |
| --------- | --------------- |
| ifid      | Interface index |
| container | Container ID    |

**Fields**

| Name      | Description                                   |
| --------- | --------------------------------------------- |
| as_client | Number of flows with the container as client. |
| as_server | Number of flows with the container as server. |
:::

::: info container:rtt
Round Trip Time for a container.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name      | Description     |
| --------- | --------------- |
| ifid      | Interface index |
| container | Container ID    |

**Fields**

| Name      | Description                      |
| --------- | -------------------------------- |
| as_client | RTT for the container as client. |
| as_server | RTT for the container as server. |
:::

::: info container:rtt_variance
Round Trip Time variance for a container.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name      | Description     |
| --------- | --------------- |
| ifid      | Interface index |
| container | Container ID    |

**Fields**

| Name      | Description                               |
| --------- | ----------------------------------------- |
| as_client | RTT variance for the container as client. |
| as_server | RTT variance for the container as server. |
:::

## POD Metrics {#pod-metrics}

::: info pod:num_containers
Number of containers for a Kubernetes POD.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pod  | POD ID          |

**Fields**

| Name           | Description           |
| -------------- | --------------------- |
| num_containers | Number of containers. |
:::

::: info pod:num_flows
Number of flows for a Kubernetes POD.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pod  | POD ID          |

**Fields**

| Name      | Description                             |
| --------- | --------------------------------------- |
| as_client | Number of flows with the POD as client. |
| as_server | Number of flows with the POD as server. |
:::

::: info pod:rtt
Round Trip Time for a Kubernetes POD.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pod  | POD ID          |

**Fields**

| Name      | Description                |
| --------- | -------------------------- |
| as_client | RTT for the POD as client. |
| as_server | RTT for the POD as server. |
:::

::: info pod:rtt_variance
Round Trip Time variance for a POD.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |
| pod  | POD ID          |

**Fields**

| Name      | Description                         |
| --------- | ----------------------------------- |
| as_client | RTT variance for the POD as client. |
| as_server | RTT variance for the POD as server. |
:::

## Process Metrics {#process-metrics}

::: info process:resident_memory
Memory statistics for the ntopng process.

- **Type**: gauge
- **Resolution**: 1m

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name           | Description              |
| -------------- | ------------------------ |
| resident_bytes | Resident memory (bytes). |
:::

## System Metrics {#system-metrics}

::: info system:cpu_load
CPU load statistics.

- **Type**: gauge
- **Resolution**: 5s

**Tags**

| Name | Description     |
| ---- | --------------- |
| ifid | Interface index |

**Fields**

| Name            | Description          |
| --------------- | -------------------- |
| load_percentage | CPU load percentage. |
:::

::: info system:thread_cpu_load
CPU utilization for each individual ntopng internal thread (e.g. packet processing,
periodic activities, address resolution).

- **Type**: gauge
- **Resolution**: 5s

**Tags**

| Name        | Description               |
| ----------- | ------------------------- |
| ifid        | Interface index           |
| thread_name | Name of the ntopng thread |

**Fields**

| Name                | Description                                |
| ------------------- | ------------------------------------------ |
| cpu_utilization_pct | CPU utilization percentage for the thread. |
:::
