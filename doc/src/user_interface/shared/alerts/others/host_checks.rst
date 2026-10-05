.. _HostChecks target:

Host Behavioural Checks
#######################

Host checks are performed on active hosts.

____________________


Countries Contacts
~~~~~~~~~~~~~~~~~~

Checks for Countries Contacts.

The endpoint sends too many requests to different countries - the recognition is based on IP location, overcoming the threshold > 100 Contacts (Minute).

The alert is sent when the threshold is exceeded.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Dangerous Host
~~~~~~~~~~~~~~

Checks for Dangerous Hosts.

If the score exceeds the threshold, the host could be consideres dangerous.

The alert is sent when a dangerous host is detected.

*Interface: Packet & ZMQ*

*Category: Intrusion Detection and Prevention*

*Not Enabled by Default*


DNS Flood
~~~~~~~~~

Checks for DNS Flood.

DNS Flood Alert

DNS flood is a type of DDoS attack in which the attacker targets one or more DNS servers, attempting to hamper resolution of resource records of that zone and its sub-zones.

The alert is sent when the number of sent/received SYNs/sec exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


DNS Server Contacts
~~~~~~~~~~~~~~~~~~~

Checks for DNS Server Contacts.

DNS servers are sensitive to all network-based attacks. There are many ways attackers can cause a large amount of network traffic to the DNS servers, such as TCP/UDP/ICMP floods, rendering the service unavailable to other network users by saturating the network connection to the DNS servers.

The alert is sent when number of different DNS servers contacted exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


DNS Traffic
~~~~~~~~~~~

Checks for DNS Traffic.

DNS traffic exceeds the threshold >  (1 MB) 

The alert is sent when the threshold is exceeded.

*Category: Network*

*Not Enabled by Default*


Domain Name Contacts
~~~~~~~~~~~~~~~~~~~~
Checks for Domain Names Contacts.

The alert is sent when the number of contacted Domain Names from a host exceeds the threshold. Never triggered for DNS and SMTP servers.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Flow Flood
~~~~~~~~~~

Checks for Flow Flood.

Flow Flood alert.

Flow flood is a type of DDoS attack in which the attacker targets one or more hosts by sending a huge amout of flows towards them.

The alert is sent when the number of flows/sec exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Flows Anomaly
~~~~~~~~~~~~~

Checks for a Flow Anomaly

Flow-based anomaly detection centers around the concept of the network flow. A flow record is an indicator that a certain network flow took place and that two network endpoints have communicated with each other.

The alert is sent when the system detects anomalies in active flows number.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


Host External Check (REST)
~~~~~~~~~~~~~~~~~~~~~~~~~~

Trigger a host alert from an external script via REST API. For further information please visit :ref:`RESTAPIDocV2 target` and check the *rest/v2/trigger/host/alert.lua* API.
Please note that the Check must be enabled from the Settings as any other Behavioural Checks before pushing alerts via REST API.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


Host User Check Script
~~~~~~~~~~~~~~~~~~~~~~

Trigger a host alert based on a custom Lua user script. For further information please visit :ref:`ApiHostChecks target`

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


ICMP Flood
~~~~~~~~~~

Checks for ICMP Flood.

The ICMP flood, is a common Denial of Service (DoS) attack in which an attacker takes down a victim’s computer by overwhelming it with ICMP echo requests, also known as pings.
The attack involves flooding the victim’s network with request packets, knowing that the network will respond with an equal number of reply packets. 


The alert is sent when the number of sent/received ICMP Flows/sec exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


NAT Detected
~~~~~~~~~~~~~~~~~~~
Checks for devices operating behind a NAT. 

The alert is sent when a device is detected behind a NAT.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


NTP Server Contacts
~~~~~~~~~~~~~~~~~~~

Checks for NTP Server Contacts.

The perpetrator exploits Network Time Protocol (NTP) servers to overwhelm a targeted server with UDP traffic. The attack is defined as an amplification that can easily generate a devastating high-volume DDoS attack.

The alert is sent when the number of different NTP servers contacted exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Remote Connection
~~~~~~~~~~~~~~~~~

Checks for Remote Connection.

In RDP protocol has been found some critical vulnerabilities. RDP is a complex protocol with many extensions and the potential of finding new critical bugs is still high. 

The alert is sent whenever an host has at least one active flow using a remote access protocol.

*Interface: Packet & ZMQ*

*Category: Network*

*Not Enabled by Default*


Scan
~~~~~~~~~~~~~~
Detects scanning activities targeting ports, networks, and services. This alert requires Clickhouse.

The check runs every 5 minutes on the historical flows, taking into account only the flows that did not receive a response. Each detection has its own threshold, that can be configured (or individually disabled) from the check settings; the alert is triggered when the threshold is reached or exceeded.

- Port Scan: a host contacted too many ports of another host. The threshold is the number of distinct ports contacted on the same host (default: 20 ports).
- Service Scan: an attack targeting multiple hosts on a specific service. The threshold is the number of distinct hosts contacted on the same port (default: 50 hosts).
- Network Scan: communication with an unusually high number of hosts. The threshold is the number of distinct hosts contacted in the same network (default: 100 hosts). It is not reported for hosts already reported for a Service Scan.
- Service Down: a host made an excessive number of attempts to contact another host on a specific port, but the target did not respond. This behavior may indicate that the destination service is down or unreachable. The threshold is the number of attempts towards the same host and port (default: 50 flows).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Scan Realtime
~~~~~~~~~~~~~~
A collection of checks to identify hosts performing scanning activities.

- RX-only Host Scan: Detects scans targeting RX-only hosts. An alert is triggered whenever an RX-only host is subject to a scanning attempt.
- Incomplete Flows Scan: Detects hosts generating an unusually high number of incomplete TCP/UDP flows. These patterns are often indicative of host or network scanning, which can be a precursor to exploits or attacks.
- SYN Scan: Detects SYN scanning activity. In a SYN scan, similar to port scanning, a threat actor attempts to initiate a TCP connection with each port on a target server by sending a SYN (synchronization) packet. If a port responds with a SYN/ACK, it indicates the port is open. The attacker then sends an RST to avoid completing the handshake.
- FIN Scan: Detects FIN scan activity. This technique is used by attackers or security analysts to identify open ports by sending packets with only the FIN (finish) flag set. Open ports typically do not respond, while closed ports send a RST.
- RST Scan: Detects an unusually high number of packets with the RST (reset) flag. A spike in RESET flags can indicate scanning behavior or potential issues within the network.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Score Anomaly
~~~~~~~~~~~~~

Checks for score anomaly.

Anomalies score represents how abnormal the behavior of the host is, based on its past behavior.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Score Threshold Exceeded
~~~~~~~~~~~~~~~~~~~~~~~~

Checks for Score Threshold

Each host has a numerical non-negative value used to store the score value. This value is computed over a 1-minute time frame.When the score of an host exceeds the threshold 	> 5000 Score (Minute) the alert is triggered.

The alert is sent when the threshold is passed.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


Server Port Detected
~~~~~~~~~~~~~~~~~~~~

Checks for Server Ports changes.

When an host opens or closes a port that could mean an issue (a service is down or an host is infected).

The alert is sent when a change to the server ports is detected.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


SMTP Server Contacts
~~~~~~~~~~~~~~~~~~~~

Checks for SMTP Server Contacts.

The alert is sent when the number of different SMTP servers contacted exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


SNMP Flood
~~~~~~~~~~

Checks for SNMP Flood.

SNMP Flood Alert

An SNMP flood attack exploits the SNMP protocol by sending a high volume of SNMP requests to a target device in a short period. These requests often overwhelm the target device's CPU or memory resources, leading to performance degradation or even complete failure of the device's network services.

The alert is sent when the number SNMP flows/sec exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*


SYN Flood
~~~~~~~~~

Checks for SYN Flood.

SYN Flood Alert

A SYN flood DDoS attack exploits a weakness in the TCP connection (the “three-way handshake”), a SYN request to initiate a TCP connection with a host must be answered by a SYN-ACK response from that host, and then confirmed by an ACK response from the requester. In a SYN flood scenario, the requester sends multiple SYN requests, but does not respond to the host’s SYN-ACK response, or sends the SYN requests from a spoofed IP address. The host system continues to wait for acknowledgement for each of the requests, resulting in denial of service.

The alert is sent when the number of sent/received SYNs/sec exceeds the threshold.

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

*Not Enabled by Default*

