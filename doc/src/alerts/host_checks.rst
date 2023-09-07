.. _HostChecks target:

Host Behavioural Checks
#######################

Host checks are performed on active hosts.

____________________


**Countries Contacts**
~~~~~~~~~~~~~~~~~~~~~~
Checks for Countries Contacts.

The endpoint sends too many requests to different countries - the recognition is based on IP location, overcoming the threshold > 100 Contacts (Minute).

The alert is sent when the threshold is exceeded.


*Category: Cybersecurity*

*Not Enabled by Default*


**Dangerous Host**
~~~~~~~~~~~~~~~~~~

Checks for Dangerous Hosts.

If the score exceeds the threshold, the host could be consideres dangerous.

The alert is sent when a dangerous host is detected.


*Category: Intrusion Detection and Prevention*

*Not Enabled by Default*


**DNS Flood**
~~~~~~~~~~~~~

Checks for DNS Flood.

DNS Flood Alert

DNS flood is a type of DDoS attack in which the attacker targets one or more DNS servers, attempting to hamper resolution of resource records of that zone and its sub-zones.

The alert is sent when the number of sent/received SYNs/sec exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*


**DNS Server Contacts**
~~~~~~~~~~~~~~~~~~~~~~~
Checks for DNS Server Contacts.

DNS servers are sensitive to all network-based attacks. There are many ways attackers can cause a large amount of network traffic to the DNS servers, such as TCP/UDP/ICMP floods, rendering the service unavailable to other network users by saturating the network connection to the DNS servers.

The alert is sent when number of different DNS servers contacted exceeds the threshold.


*Category: Cybersecurity*

*Not Enabled by Default*


**DNS Traffic**
~~~~~~~~~~~~~~~~~~~~~~
Checks for DNS Traffic.

DNS traffic exceeds the threshold >  (1 MB) 

The alert is sent when the threshold is exceeded.

*Category: Network*

*Not Enabled by Default*


**Domain Name Contacts**
~~~~~~~~~~~~~~~~~~~~~~~
Checks for Domain Names Contacts.

The alert is sent when the number of different Domain Names contacted from an host exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*


**Flow Flood**
~~~~~~~~~~~~~

Checks for Flow Flood.

Flow Flood alert.

Flow flood is a type of DDoS attack in which the attacker targets one or more hosts by sending a huge amout of flows towards them.

The alert is sent when the number of flows/sec exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*


**Flows Anomaly**
~~~~~~~~~~~~~~~~~

Checks for a Flow Anomaly

Flow-based anomaly detection centers around the concept of the network flow. A flow record is an indicator that a certain network flow took place and that two network endpoints have communicated with each other.

The alert is sent when the system detects anomalies in active flows number.

*Category: Network*

*Not Enabled by Default*


**Host External Check (REST)**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Trigger a host alert from an external script via REST API. For further information please visit :ref:`RESTAPIDocV2 target` and check the *rest/v2/trigger/host/alert.lua* API.
Please note that the Check must be enabled from the Settings as any other Behavioural Checks before pushing alerts via REST API.

*Category: Network*

*Not Enabled by Default*


**Host User Check Script**
~~~~~~~~~~~~~~~~~~~~~~~~~~

Trigger a host alert based on a custom Lua user script. For further information please visit :ref:`ApiHostChecks target`

*Category: Network*

*Not Enabled by Default*


**ICMP Flood**
~~~~~~~~~~~~~~~~~~~~

Checks for ICMP Flood.

The ICMP flood, is a common Denial of Service (DoS) attack in which an attacker takes down a victim’s computer by overwhelming it with ICMP echo requests, also known as pings.
The attack involves flooding the victim’s network with request packets, knowing that the network will respond with an equal number of reply packets. 


The alert is sent when the number of sent/received ICMP Flows/sec exceeds the threshold.


*Category: Network*

*Not Enabled by Default*


**NTP Server Contacts**
~~~~~~~~~~~~~~~~~~~~~~~

Checks for NTP Server Contacts.

The perpetrator exploits Network Time Protocol (NTP) servers to overwhelm a targeted server with UDP traffic. The attack is defined as an amplification that can easily generate a devastating high-volume DDoS attack.

The alert is sent when the number of different NTP servers contacted exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*


**NTP Traffic**
~~~~~~~~~~~~~~~~~~~~~
Checks for  NTP Traffic. 

Network Time Protocol (NTP) server, could be flooded with traffic (DDoS attack). When NTP traffic exceeds the threshold 	> (1 MB) the alert is triggered.

The alert is sent when the threshold is crossed.


*Category: Network*

*Not Enabled by Default*


**P2P Traffic**
~~~~~~~~~~~~~~~~~~~~~

Checks for P2P Traffic.


As P2P traffic continues to grow. This growth in traffic causes network congestion, performance deterioration.When P2P traffic exceeds the threshold the alert is triggered.

The alert is sent when the threshold is crossed.

*Category: Network*

*Not Enabled by Default*


**Packets Exceeded**
~~~~~~~~~~~~~~~~~

Checks for Packets.

Detects and reports on packets based on behavior characteristics of the sender or characteristics of the packets. Foresees possible attack vectors by packet-per-second or percentage-increase-over-time thresholds.

The alert is sent when the packet delta (sent + received) exceeds the threshold.

*Category: Network*

*Not Enabled by Default*


**Score Anomaly**
~~~~~~~~~~~~~~~~~

Checks for score anomaly.

Anomalies score represents how abnormal the behavior of the host is, based on its past behavior.

*Category: Cybersecurity*

*Not Enabled by Default*

**SYN Flood Alert**
~~~~~~~~~~~~~~~~~~~

Checks for SYN Flood.

SYN Flood Alert

A SYN flood DDoS attack exploits a weakness in the TCP connection (the “three-way handshake”), a SYN request to initiate a TCP connection with a host must be answered by a SYN-ACK response from that host, and then confirmed by an ACK response from the requester. In a SYN flood scenario, the requester sends multiple SYN requests, but does not respond to the host’s SYN-ACK response, or sends the SYN requests from a spoofed IP address. The host system continues to wait for acknowledgement for each of the requests, resulting in denial of service.

The alert is sent when the number of sent/received SYNs/sec exceeds the threshold.

*Category: Cybersecurity*

*Not Enabled by Default*

**SYN Scan Alert**
~~~~~~~~~~~~~~~~~~

Checks for SYN Scan.

Syn scan alert In SYN scanning, similar to port scanning, the threat actor attempts to set up a (TCP/IP) connection with a server on every possible port. This is done by sending a SYN (synchronization) packet, as if to initiate a three-way handshake, to every port on the server.
If the server replies with an ACK (acknowledgement)response or SYN/ACK (synchronization acknowledged) packet from a particular port, it means that the port is open. Then, the malicious actor sends an RST.

The alert is sent when the number of sent/received SYNs/min exceeds the threshold.

*Category: Network*

*Not Enabled by Default*


**Remote Connection**
~~~~~~~~~~~~~~~~~~~~~

Checks for Remote Connection.

In RDP protocol has been found some critical vulnerabilities. RDP is a complex protocol with many extensions and the potential of finding new critical bugs is still high. 

The alert is sent whenever an host has at least one active flow using a remote access protocol.

*Category: Network*

*Not Enabled by Default*

**Scan Detection Alert**
~~~~~~~~~~~~~~~~~~~~~~~~
Checks for a scan detection.

Host and network scanning cannot go unnoticed because they are usually a symptom of possible exploits and attacks.TCP/UDP flows exceeds the specified standard > 32 Flows (Minute) 

*Category: Cybersecurity*

*Not Enabled by Default*

**Score Threshold Exceeded**
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Checks for Score Threshold

Each host has a numerical non-negative value used to store the score value. This value is computed over a 1-minute time frame.When the score of an host exceeds the threshold 	> 5000 Score (Minute) the alert is triggered.

The alert is sent when the threshold is passed.

*Category: Cybersecurity*

*Not Enabled by Default*

