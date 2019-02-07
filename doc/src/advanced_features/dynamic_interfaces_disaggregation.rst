Dynamic Interfaces Disaggregation
=================================

ntopng can split and visualize the traffic into virtual interfaces based on a specified criterion.
This comes handy, for example, when a single nProbe instance is capturing flows from multiple
NetFlow/sFLow exporters. By default, ntopng would aggregate all the exporters traffic together
into one `tcp://...` interface, whereas by enabling the disaggregation by "Probe IP" ntopng
will also create as many virtual interfaces as the exporters, for example
`tcp://...192.168.0.1` and `tcp://...192.168.2.20`.

Dynamic Interfaces Disaggregation can be enabled from the "Network Interfaces" preference
tab.

.. figure:: ./../img/dynamic_interface_disaggregation.png
  :align: center
  :alt: Dynamic Interfaces Disaggregation

  Disaggregation Settings

Here is a summary of the available disaggregation criterion:

- `None`: do not disaggregate
- `VLAN Id`: create a virtual interface for each VLAN
- `Probe IP`: on ZMQ, create a virtual interface for each %EXPORTER_IPV4_ADDRESS
- `Interface`: on ZMQ, create a virtual interface for %INPUT_SNMP and another for %OUTPUT_SNMP.
  A single flow will be *duplicated* on two virtual interfaces.
- `Ingress Interface`: on ZMQ, create a virtual interface for each %INPUT_SNMP
- `VRF Id`: on ZMQ, create a virtual interface for each %INGRESS_VRFID

Most of them only work in ZMQ mode and require the relevant template field to be
added to the nprobe options as explained in the `nprobe section`_.

.. note::

   Changes will take effect only after a ntopng restart

.. _`nprobe section`: ../using_with_nprobe.html#exported-flow-fields
