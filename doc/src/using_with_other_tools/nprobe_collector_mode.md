---
title: "Using ntopng with nProbe (Collector Mode)"
description: "ntopng in collector mode listens for incoming data over ZMQ. One or multiple nProbe can connect the ntopng to send their data."
outline: [2, 3]
lastUpdated: 2021-11-09T11:13:35+01:00
---

<a id="usingntopngwithnprobecollectormode"></a>

# Using ntopng with nProbe (Collector Mode) {#using-ntopng-with-nprobe-collector-mode}

ntopng in collector mode listens for incoming data over ZMQ. One or multiple nProbe can connect the ntopng to send their data.

To start ntopng in collector mode specify an extra `c` at the end of the ZMQ endpoint.

For example, to start ntopng in collector mode and listen for incoming nProbe connections on port `5556` the following configuration can be used

```bash
ntopng -i tcp://*:5556c
```

The asterisk `*` tells ntopng to listen on any address available. A specific address can be indicated in place of the asterisk, e.g.,

```bash
ntopng -i tcp://127.0.0.1:5556c
```

In the configuration above, ntopng will only listens for nProbe connections arriving on `localhost`.

To connect nProbe instances to ntopng listening in collector mode, the IP address of ntopng and extra `--zmq-probe-mode` must be indicated in the nProbe configuration.

For example, to connect nProbe to a ntopng instance running in collector mode on host `192.168.2.222` port `5556` one can use

```bash
nprobe --zmq tcp://192.168.2.222:5556 --zmq-probe-mode <other nprobe options>
```

Multiple nProbe instances can be connected to the same ntopng instance running in collector mode, using the very same configuration. ntopng is able to recognize individual nProbe instances automatically.

::: info
The number of nProbe instances that can be connected to a single ntopng instances is limited and depends on the license. Check the nProbe product page for the actual limits.
:::

## Use Cases {#use-cases}

It is necessary to start ntopng in collector mode when

- Multiple nProbe instances need to be connected to the same ntopng
- nProbe is behind a firewall and thus it must be the connection initiator

See [Using ntopng with nProbe](/using_with_other_tools/nprobe.md#usingntopngwithnprobe) for additional details.
