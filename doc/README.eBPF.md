# eBPF

ntopng support the reception of eBPF/Netlink events over ZMQ. Such events can be produced either with:

- `nprobe_mini` (note that this name might be changed in the future)
- `libebpfflow` (opensource library available at https://github.com/ntop/libebpfflow)

Received events are of different kinds, namely:

- `flow` events carry information of communication flows and will be shown by ntopng as if they were - almost - regular flows.
- `netstat` events carry traffic updates for the active traffic flows and also for the listening sockets - think to these events as the equivalents of the Linux `netstat` tool.
- `counters` events carry traffic update for the system interfaces.

## Setup

### Setting up `ntopng`

To start receiving eBPF events, a regular ZMQ interface has to be added to ntopng:

```
ntopng ./ntopng -i tcp://*:1234c <... other options ...>
```

Event producers have, in turn, to be instructed to deliver events to ntopng right into the ZMQ interface.

### Setting up `nprobe_mini`

`nprobe_mini`, assuming it is executing on the same ntopng machine, can be started as

```
./nprobe_mini   -v --zmq tcp://127.0.0.1:1234c
```

One might need to adjust the ZMQ url to connect to an ntopng running on a remote machine or on a different port.

### Setting up `libebpfflow`

Similarly, `libebpfflow` can be started as

```
./ebpflowexport -v -z tcp://127.0.0.1:1234c
```

Note that the executable is called `ebpflowexport` as the `libebpfflow` is just the library per se.


## Execution

Once ntopng and one of the event producers have been started up, ntopng will start showing event data inside the dedicated ZMQ interface.

Events will also be shown inside other packet interfaces, provided that ntopng is monitoring them, and it finds a match between the interface name and the `IF_NAME` read inside the event. Indeed, events carry an `IF_NAME` representing the interface responsible for the generation of the event, and this `IF_NAME` is used by ntopng to search for a match among the other monitored interfaces. When a match is found, the event is dispatched to the matching interface.

For example, assuming ntopng is running as

```
./ntopng -i tcp://*:1234c -i lo -i ens3 -i cbr0
```

The incoming event

```
{ "timestamp": "1557135868.956831", "TID": 0, "LOCAL_PROCESS": { "PID": 29730, "UID": 0, "GID": 0, "GID_NAME": "root", "PROCESS_PATH": "\/snap\/microk8s\/522\/kubelet" }, "LOCAL_FATHER_PROCESS": { "PID": 1, "UID": 0, "UID_NAME": "daemon", "GID": 0, "GID_NAME": "root", "PROCESS_PATH": "\/lib\/systemd\/systemd" }, "TCP_EVENT_TYPE": "CONNECT", "IF_NAME": "cbr0", "IP_PROTOCOL_VERSION": 4, "PROTOCOL": 6, "NW_LATENCY_MS": 0.177, "L4_LOCAL_PORT": 58916, "L4_REMOTE_PORT": 10054, "IPV4_LOCAL_ADDR": "10.1.1.1", "IPV4_REMOTE_ADDR": "10.1.1.13", "EXPORTER_IPV4_ADDRESS": "192.168.2.131" }
```

Will not only be added to the ZMQ interface `tcp://*:1234c` but also to `cbr0` as found in `IF_NAME`.

### Companion Interface

One of the other interfaces being monitored by ntopng can be indicated as the *companion* of the ZMQ interface. The companion interface, which must be marked as being receiving mirrored traffic, is useful to combine events with real traffic data. When a companion is defined, the ZMQ interface will start delivering events to that companion as well, actually combining real traffic data with events.

The use case is when multiple remote event producers are exporting events to a machine which is also receiving mirrored traffic.

To configure the companion interface:

1. Visit the configuration page of the interface you want to indicate as companion and make sure "Mirrored Traffic" is checked.
2. Visit the configuration page of the ZMQ interface and use the dropdown "Companion Interface" to pick the desired interface.

From that point on, events will not only be available in the ZMQ interface but also in the specified companion.

For example, assuming ntopng as been started as

```
./ntopng -i tcp://*:1234c -i lo -i ens3
```

If one wants to indicate interface `ens3` as the companion of `tcp://*:1234c`, one can:
1. Visit the configuration page of `ens3` and make sure "Mirrored Traffic" is checked.
2. Visit the configuration page of `tcp://*:1234c` and select `ens3` from the "Companion Interface" dropdown.

_Note: Events involving loopback addresses (e.g., `127.0.0.1`) will not be delivered to the companion interface as loopback traffic is meant to stay on the local machine and will never be seen in mirrored traffic_.
