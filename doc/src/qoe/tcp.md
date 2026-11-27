---
title: "TCP-based Protocols"
description: "With TCP-based protocol such as TLS and SSH, QoE is computed based on the following metrics:"
outline: [2, 3]
lastUpdated: 2025-04-14T11:43:11+02:00
---
# TCP-based Protocols {#tcp-based-protocols}

With TCP-based protocol such as TLS and SSH, QoE is computed based on the following metrics:

- RTT (Round-Trip Time)
- Retrasmissions
- Packet Lost
- Jitter

The above metrics are computed continuously for the duration of the flow and not just at the flow start durin the three-way handshake.
