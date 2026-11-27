---
title: "Active Monitoring Behavioural Checks"
description: "Active Monitoring checks are designed to spot network/connectivity problems of remote/local hosts."
outline: [2, 3]
lastUpdated: 2025-02-12T16:12:50+01:00
---
# Active Monitoring Behavioural Checks {#active-monitoring-behavioural-checks}

Active Monitoring checks are designed to spot network/connectivity problems of remote/local hosts.

______________________________________________________________________

## **Vulnerability Scan** {#vulnerability-scan}

Checks for Vulnerability scans.

Ntopng notifies when a host, previosly scanned, has changes both on the number of open ports and on the CVEs found.

The Alert is sent when at least one of these two has changed.

The Alert can be found in the Active Monitoring alert section.

*Interface: Packet & ZMQ*

*Category: CyberSecurity*

*Enabled by Default*
