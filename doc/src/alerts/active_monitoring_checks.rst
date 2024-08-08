Active Monitoring Behavioural Checks
####################################

Active Monitoring checks are designed to spot network/connectivity problems of remote/local hosts.

____________________


**Vulnerability Scan**
~~~~~~~~~~~~~~~~~~~~~~
Checks for Vulnerability scans.

Ntopng notifies when a host, previosly scanned, has changes both on the number of open ports and on the CVEs found.

The Alert is sent when at least one of these two has changed.

The Alert can be found in the Active Monitoring alert section.

*Interface: Packet & ZMQ*

*Category: CyberSecurity*

*Enabled by Default*