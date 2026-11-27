---
title: "UDP-based Protocols (QUIC and RTP)"
description: "With UDP-based protocols it is not possible to implement a 'generic' QoE measurement as with TCP. For this reason we have implemented QoE monitoring for:"
outline: [2, 3]
lastUpdated: 2025-04-14T11:43:11+02:00
---
# UDP-based Protocols (QUIC and RTP) {#udp-based-protocols-quic-and-rtp}

With UDP-based protocols it is not possible to implement a "generic" QoE measurement as with TCP. For this reason we have implemented QoE monitoring for:

- QUIC
- RTP

In particular:

- QUIC streams cn be monitored only when the [spin bit](https://blog.apnic.net/2018/05/11/explicit-passive-measurability-and-the-quic-spin-bit/) is set.
- RTP streams are monitored calculaing a [pseudo-MOS](https://en.wikipedia.org/wiki/Mean_opinion_score) as in [nProbe RTP plugin](https://www.ntop.org/guides/nprobe/plugins/rtp.html).
