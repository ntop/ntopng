SNMP Behavioural Checks
#######################

These checks are executed after a periodic SNMP poll session, in order to detect relevant changes since the previous SNMP poll

____________________

**Duplex Status Change**
~~~~~~~~~~~~~~~~~~~~~~

Check for Duplex Status.

The term full-duplex describes simultaneous data transmission and receptions over one channel. A full-duplex device is capable of bi-directional network data transmission at the same time.

Half-duplex devices can only transmit in one direction at one time

The alert is sent when Duplex status is changed.


*Category: SNMP*

*Enabled by Default*


**Interface Errors**
~~~~~~~~~~~~~~~~~~~~

Checks for Interface Errors.
 
An interface discard happens when the device has decided to discard a packet for some reasons. It could be a corrupt packet, the device is busy, buffer overflows, packet size issues, or other issues.

The alert is sent when an interface error is seen.

*Category: SNMP*

*Enabled by Default*


**Interface Load Threshold Alerts**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks if the threshold for port load is respected.

Port exhaustion occurs when a node runs out of available ports. When an application stops using a specific port, the port enters a "time-wait state" before it becomes available for use by another application.

When traffic exceeds the configured limit, it is dropped.

The alert is sent when the threshold is exceeds.

*Category: SNMP*

*Enabled by Default*


**LLDP/CDP Topology Monitor**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for changes in the SNMP network topology.

Mapping network topology helps to keep all the information about the network. Informing about each piece of equipment, how everything is interconnected, including extra details such as IP addresses, traffic speed or volume, or any other configuration parameters.
A network topology map diagram is also important troubleshooting tool, it can report poor performance between a workstation and a server. The SNMP simple network management protocol or other protocols such as the Cisco Discovery Protocol (CDP) poll the devices and discover their interconnections. This information automatically build a graphical representation of the network, a network topology map.

Alert is sent when changes in the SNMP network topology are discovered.

*Category: SNMP*

*Enabled by Default*


**MAC Port Changed**
~~~~~~~~~~~~~~~~~~~~

Checks if a MAC has been moved between interfaces or devices.

If a MAC address is continuously moved between the two interfaces, Layer 2 loops might occur. To detect and locate loops, you can view the MAC address move information. To display the MAC address move records after the device is started, use the display mac-address mac-move command.

Alert is sent when MAc address moved between interfaces.

*Category: SNMP*

*Enabled by Default*


**Oper. Status Change**
~~~~~~~~~~~~~~~~~~~~~~~~

Checks if the operational state of an interface has been changed.


There are the operational states for an interface:

• Up—Ready to pass packets (if admin status is changed to up, then operational status should change to up if the interface is ready to transmit and receive network traffic).

• Down—If admin status is down, then operational status should be down

• Testing—In test mode, no operational packets can be passed

• Unknown—Status can not be determined for some reason

and few others.

Alert is sent in case the operational state of an interface changed.


*Category: SNMP*

*Enabled by Default*


**SNMP Device Restart**
~~~~~~~~~~~~~~~~~~~~~~~

Checks for SNMP device restart.

An SNMP device is a device that is managed using SNMP. Most common network devices, like routers, switches, firewalls, load balancers, storage devices, UPS devices, and printers, are equipped with SNMP. The vendors preconfigure the SNMP agent, and the admins simply have to enable SNMP to start managing the device.

When an SNMP agent restarts (for example, after a reboot of the network device), it generally resets all counter variables to zero, and afterwards it may show incorrect values. 

Alert is sent when a restart for an SNMP device has been seen. 

*Category: SNMP*

*Enabled by Default*

