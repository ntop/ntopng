Host Checks
###########

Host checks are performed on active hosts.

____________________

**DNS Server Contacts Alert**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Checks for DNS Server Contacts.

DNS servers are sensitive to all network-based attacks. There are many ways attackers can cause a large amount of network traffic to the DNS servers, such as TCP/UDP/ICMP floods, rendering the service unavailable to other network users by saturating the network connection to the DNS servers.

The alert is sent when number of different DNS servers contacted exceeds the threshold.


*Category: Cybersecurity*

*Not Enabled by Default*


**Dangerous Host**
~~~~~~~~~~~~~~~~~~

Checks for Dangerous Hosts.

If the score exceeds the threshold, the host could be consideres as dangerous.

The alert is sent when a dangerous host is detected.


*Category: Intrusion Detection and Prevention*

*Not Enabled by Default*


**Score Anomaly**
~~~~~~~~~~~~~~~~~

Checks for score anomaly.

Anomalies score represents how abnormal the behavior of the host is, based on its past behavior.

*Category: Cybersecurity*

*Not Enabled by Default*


**NTP Server Contacts**
~~~~~~~~~~~~~~~~~~~~~~~

Checks for NTP Server Contacts.

The perpetrator exploits Network Time Protocol (NTP) servers to overwhelm a targeted server with UDP traffic. The attack is defined as an amplification  can easily generate a devastating high-volume DDoS attack.

The alert is sent when the number of different NTP servers contacted exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*


**DNS Server Contacts Alert**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for DNS Server Contacts.

DDoS attacks typically occur with a botnet. The attacker uses a network of malware-infected computers to send large amounts of traffic to a target, such as a server. The goal is to overload the target and slow or crash it.

The alert is sent when the number of different DNS servers contacted exceeds the threshold. 

*Category: Cybersecurity*

*Not Enabled by Default*

**SYN Flood Alert**
~~~~~~~~~~~~~~~~~~~

Checks for SYN Flood.

SYN Flood Alert

A SYN flood DDoS attack exploits a weakness in the TCP connection(the “three-way handshake”),a SYN request to initiate a TCP connection with a host must be answered by a SYN-ACK response from that host, and then confirmed by an ACK response from the requester. In a SYN flood scenario, the requester sends multiple SYN requests, but does not respond to the host’s SYN-ACK response, or sends the SYN requests from a spoofed IP address. The host system continues to wait for acknowledgement for each of the requests,resulting in denial of service.

The alert is sent when the number of sent/received SYNs/sec exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*

**SYN Scan Alert**
~~~~~~~~~~~~~~~~~~

Checks for SYN Scan.

Syn scan alert In SYN scanning, similar to port scanning, the threat actor attempts to set up a (TCP/IP) connection with a server at every possible port. This is done by sending a SYN (synchronization) packet, as if to initiate a three-way handshake, to every port on the server.
If the server replies with an ACK (acknowledgement)response or SYN/ACK (synchronization acknowledged) packet from a particular port, it means the port is open. Then, the malicious actor sends an RST.

The alert is sent when the number of sent/received SYNs/min exceeds the threshold.

*Category: Network*

*Not Enabled by Default*


**ICMP Flood Alert**
~~~~~~~~~~~~~~~~~~~~

Checks for ICMP Flood.

The ICMP flood, is a common Denial of Service (DoS) attack in which an attacker takes down a victim’s computer by overwhelming it with ICMP echo requests, also known as pings.
The attack involves flooding the victim’s network with request packets, knowing that the network will respond with an equal number of reply packets. 


The alert is sent when the number of sent/received ICMP Flows/sec exceeds the threshold.


*Category: Network*

*Not Enabled by Default*


**Packets Alert**
~~~~~~~~~~~~~~~~~

Checks for Packets.

Detects and reports on packets based on behavior characteristics of the sender or characteristics of the packets.Foresees possible attack vectors by packet-per-second or percentage-increase-over-time thresholds.

The alert is sent when the packet delta (sent + received) exceeds the threshold.

*Category: Network*

*Not Enabled by Default*


**Remote Connection**
~~~~~~~~~~~~~~~~~~~~~

Checks for Remote Connection.

In RDP protocol has been found some critical vulnerabilities. RDP is a complex protocol with many extensions and the potential of finding new critical bugs is still high. 

The alert is sent whenever an host has at least one active flow using a remote access protocol.

*Category: Network*

*Not Enabled by Default*





