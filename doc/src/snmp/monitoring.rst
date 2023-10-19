Device Monitoring
-----------------

ntopng supports several MIBS including (but not limited to):

- MIB-II
- LLDP / CDP MIB
- Bridge MIB
- netSNMP

Below you can see an overview of a device:

.. figure:: ../img/SNMP_System.png
  :align: center
  :alt: SNMP Device Overview

During device discovery, ntopng automatically detectes the MIBs and in the device menu are displayed icons of those that aare available. In the picture below you can see for instance an overview of the SNMP memory and CPU usage.

.. figure:: ../img/SNMP_CPU.png
  :align: center
  :alt: SNMP Device: CPU and Memory


Network Interfaces
------------------

One of the main uses of SNMP is monitoring of network interfaces. ntopng displays them in a table view:

.. figure:: ../img/SNMP_Interfaces.png
  :align: center
  :alt: SNMP Network Interfaces

Clicking on an interface id a drill-down page is shown

.. figure:: ../img/SNMP_Interface.png
  :align: center
  :alt: SNMP Network Interface Overview


Binding MAC Address to Interface
--------------------------------

If present, ntopng polls the bridge MIB that is used to discover the MAC addresses observed on a network interface.

.. figure:: ../img/SNMP_Bridge.png
  :align: center
  :alt: SNMP Interfaces and MAC Addresses

As shown above, ntopng reports the list of MAC addresses for each network interface and uses this information in network monitoring.

.. figure:: ../img/SNMP_MacBridge.png
  :align: center
  :alt: SNMP Interfaces and MAC Addresses

In the above picture you can see how SNMP is used to bind an IP address to SNMP and thus to a physical device.


