.. _BasicConceptSystemInterface:

System Interface
################

ntopng monitoring capabilities are not limited to the network traffic. ntopng monitors also:

- The system on top of which ntopng is running (e.g, disk space and load)
- Status and health of the current ntopng instance (with a :ref:`Redis Monitor` and an :ref:`InfluxDB Monitor`)

Monitoring features above are performed by the system interface. The system interface is available in the ntopng interfaces dropdown menu as any other interface.

Network monitoring tasks that are not specific to a single interface are performed by the system interface as well. Indeed, the system interface features:

- An :ref:`Active Monitor` to actively monitored hosts in the network
- The monitoring of :ref:`SNMP` devices
