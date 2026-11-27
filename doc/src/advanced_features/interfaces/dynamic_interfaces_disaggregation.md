---
title: "Interfaces Disaggregation"
description: "ntopng can split and visualize the traffic into virtual sub-interfaces based on a specified criterion."
outline: [2, 3]
lastUpdated: 2026-11-19T10:48:53+01:00
---
# Interfaces Disaggregation {#interfaces-disaggregation}

ntopng can split and visualize the traffic into virtual sub-interfaces based on a specified criterion.
This comes handy, for example, when a single nProbe instance is capturing flows from multiple
NetFlow/sFLow Exporters. By default, ntopng would aggregate all the Exporters traffic together
into one `tcp://...` interface, whereas by enabling the disaggregation by "Probe IP" ntopng
will also create as many virtual interfaces as the Exporters, for example
`tcp://...192.168.0.1` and `tcp://...192.168.2.20`.

## Dynamic Disaggregation {#dynamic-disaggregation}

Dynamic Interfaces Disaggregation can be enabled from the Disaggregation tab of the interface details
page, as depicted in the picture below.

![Dynamic Interfaces Disaggregation](../../img/dynamic_interface_disaggregation.png "Disaggregation Settings")

Here is a summary of the available disaggregation criterion:

- `None`: do not disaggregate
- `VLAN Id`: create a virtual interface for each VLAN
- `Probe IP`: on ZMQ, create a virtual interface for each %EXPORTER_IPV4_ADDRESS
- `Interface`: on ZMQ, create a virtual interface for %INPUT_SNMP and another for %OUTPUT_SNMP.
  A single flow will be *duplicated* on two virtual interfaces.
- `Ingress Interface`: on ZMQ, create a virtual interface for each %INPUT_SNMP
- `VRF Id`: on ZMQ, create a virtual interface for each %INGRESS_VRFID

Most of them only work in ZMQ mode and require the relevant template field to be
added to the nprobe options as explained in the [nprobe section].

## Custom Disaggregation {#custom-disaggregation}

In addition to the dynamic disaggregation, it is also possible to use custom BPF-like filters to
disaggregate incoming traffic and divert it to logical sub-interfaces. This can be achieved by
disabling Dynamic Traffic Disaggregation (setting it to 'None') and creating new rules in the
Custom Traffic Disaggregation section of the same tab. Alternatively you can use both disaggregation methods at the
same time, by selecting a Dynamic disaggregation criteria and configuring custom rules at the
same time. Custom rules have higher priority: traffic matching custom rules will not be
processed by the dynamic disaggregation.

![Custom Interfaces Disaggregation](../../img/custom_interface_disaggregation.png "Custom Disaggregation Settings")

An extended nBPF format is supported when defining sub-interfaces, in fact in addition to the
standard BPF primitives, NetFlow fields can also be used, including INPUT_SNMP, OUTPUT_SNMP,
SRC_VLAN, DST_VLAN.
Note that in this case the same traffic can be diverted to multiple interfaces in case of
overlapping filters.

![Custom Interfaces Disaggregation Dialog](../../img/custom_interface_disaggregation_dialog.png "Custom Disaggregation Dialog")

::: info
Changes will take effect only after a ntopng restart
:::

[nprobe section]: /using_with_nprobe.md#exported-flow-fields
