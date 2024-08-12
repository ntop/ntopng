Local Networks Behavioural Checks
#################################

These checks are performed on local networks (see -m command line option).

____________________

Broadcast Domain Too Large
~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks broadcast domains.

The ARP traffic between two MACS addresses belonging to different broadcast domains is detected.

The Alert is sent when the broadcast domain is too large.

*Interface: Packet & ZMQ*

*Category: Network*

*Enabled by Default*


Flow Flood Victim
~~~~~~~~~~~~~~~~~

Checks for Flow Flood.

In a computer network, flooding occurs when a router uses a nonadaptive routing algorithm. When a network is having more than a predefined number of flows over a minute. The system sends a notification when servers of the monitored flows exceeds the threshold.

The alert is sent in case of server flow flood.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


IP/MAC Reassoc/Spoofing
~~~~~~~~~~~~~~~~~~~~~~~

Checks for IP or MAC Reassociation/Spoofing.

This alert might indicate an ARP spoof attempt. 

The alert is sent when an IP address, previously seen with a MAC address, is now seen with another MAC address. Only works for the builtin alert recipient.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


Network Discovery
~~~~~~~~~~~~~~~~~

Checks for Network Discovery.

Network discovery is the process that allows computers and devices to find each other when they are on the same network. It is the first step system administrators take when they want to map and monitor their network infrastructure. This process is sometimes also referred to as topology discovery.

The alert is sent when a network discovery is detected.

*Interface: Packet & ZMQ*

*Category: Network*

*Enabled by Default*


Network Issues
~~~~~~~~~~~~~~

Checks for Network Discovery.

Network issues, like packets loss, could identify an issue in the network.

The alert is sent when network issues (retransmissions, high number of fragments and packet loss) are identified.

*Interface: Packet & ZMQ*

*Category: Network*

*Enabled by Default*


Network Score per Host
~~~~~~~~~~~~~~~~~~~~~~

Checks for the score of the hosts in a network.

An high score (as average per host) on many hosts of a network could mean a possible issue with the network itself.

The alert is sent when the average score per host of a network is higher then a threshold.

*Interface: Packet & ZMQ*

*Category: Network*

*Enabled by Default*


SYN Flood Victim
~~~~~~~~~~~~~~~~

Checks for SYN Flood.

A SYN Flood is a common form of DDoS attack that can target any system connected to the Internet and providing TCP services like web server, email server, file transfer. A SYN flood is a type of TCP State-Exhaustion Attack that attempts to consume the connection state tables present in many infrastructure components, such as load balancers, firewalls and IPS.

The alert is sent when the number of received SYN exceeds the threshold.

*Interface: Packet*

*Category: Cybersecurity*

*Not Enabled by Default*


SYN Scan Victim
~~~~~~~~~~~~~~~

Checks for SYN Scan.

SYN scanning is a tactic that a hacker can use to determine the state of a communications port without establishing a full connection.
This approach, one of the oldest, sometimes is used to perform DoS attack. SYN scanning is also known as half-open scanning.

The alert is sent when the number of received SYNs exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*





