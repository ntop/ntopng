---
title: "Device Monitoring"
description: "ntopng supports several MIBS including (but not limited to): Below you can see an overview of a device:"
outline: [2, 3]
lastUpdated: 2026-08-27T14:05:53+00:00
---
# Device Monitoring {#device-monitoring}

ntopng supports several MIBS including (but not limited to):

- MIB-II
- LLDP / CDP MIB
- Bridge MIB
- netSNMP

Below you can see an overview of a device:

![SNMP Device Overview](../../../img/SNMP_System.png)

During device discovery, ntopng automatically detectes the MIBs and in the device menu are displayed icons of those that aare available. In the picture below you can see for instance an overview of the SNMP memory and CPU usage.

!['SNMP Device: CPU and Memory'](../../../img/SNMP_CPU.png)

## Network Interfaces {#network-interfaces}

One of the main uses of SNMP is monitoring of network interfaces. ntopng displays them in a table view:

![SNMP Network Interfaces](../../../img/SNMP_Interfaces.png)

Clicking on an interface id a drill-down page is shown

![SNMP Network Interface Overview](../../../img/SNMP_Interface.png)

## Interface Roles {#interface-roles}

It is possible to assign a role to a network interface that spcifies the intent for which such interface is used. Roles include:

- Customer
- IX
- Internal LAN
- Internet Connectivity
- Other
- Peering
- Transit

You can set the individual interface role as shown in the figure below

![SNMP Interface Role](../../../img/snmp_port_role.png)

## Interface Label Format {#interface-label-format}

From the preferences page it is possible to change the label format displayed
for SNMP interfaces. By default, ntopng shows the interface alias, but it is
also possible to display the interface name instead.

To change this setting, navigate to **Preferences → SNMP → SNMP Interface Label Format**.

![SNMP Interface Label Format](../../../img/SNMP_Interface_label.png)

## Binding MAC Address to Interface {#binding-mac-address-to-interface}

If present, ntopng polls the bridge MIB that is used to discover the MAC addresses observed on a network interface.

![SNMP Interfaces and MAC Addresses](../../../img/SNMP_Bridge.png)

As shown above, ntopng reports the list of MAC addresses for each network interface and uses this information in network monitoring.

![SNMP Interfaces and MAC Addresses](../../../img/SNMP_MacBridge.png)

In the above picture you can see how SNMP is used to bind an IP address to SNMP and thus to a physical device.
