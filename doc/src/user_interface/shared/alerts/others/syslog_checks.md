---
title: "Syslog Behavioural Checks"
description: "Syslog checks are called whenever ntopng collects logs as described in Syslog target. They are not real checks but rather are triggered whenever a syslog..."
outline: [2, 3]
lastUpdated: 2025-02-12T16:12:50+01:00
---

<a id="syslogchecks-target"></a>

# Syslog Behavioural Checks {#syslog-behavioural-checks}

Syslog checks are called whenever ntopng collects logs as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target). They are not real checks but rather are triggered whenever a syslog event is received. Below you can find the various syslog families.

______________________________________________________________________

## Fortinet {#fortinet}

Collects syslog logs from Fortinet devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the Fortined VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## Host Log {#host-log}

Collects syslog logs from hosts. This is used to integrate all logs exported by hosts in the network.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## Kerberos/NXLog {#kerberos-nxlog}

Collect Kerberos authentication logs exported by NXLog in XML or JSON format. This is mainly used to handle Identity Management (user correlation) when Active Directory is used.
In order to integrate Kerberos with this plugin, NXLog should be configured to export Kerberos events using syslog and send them to ntopng as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

Example of NXLog *nxlog.conf* configuration file for XML export:

```text
define ROOT     C:\Program Files\nxlog
define CERTDIR  %ROOT%\cert
define CONFDIR  %ROOT%\conf
define LOGDIR   %ROOT%\data
define LOGFILE  %LOGDIR%\nxlog.log
LogFile %LOGFILE%

Moduledir %ROOT%\modules
CacheDir  %ROOT%\data
Pidfile   %ROOT%\data\nxlog.pid
SpoolDir  %ROOT%\data

<Extension _syslog>
    Module      xm_syslog
</Extension>

<Extension _charconv>
    Module      xm_charconv
    AutodetectCharsets iso8859-2, utf-8, utf-16, utf-32
</Extension>

<Extension _exec>
    Module      xm_exec
</Extension>

<Extension xml>
    Module  xm_xml
</Extension>

<Input eventlog>
    Module im_msvistalog
     Query <QueryList>\
               <Query Id="0">\
                   <Select Path="Security">*[System[(EventID=4768 or EventID=4769)]]</Select>\
               </Query>\
           </QueryList>
</Input>

<Output out>
    Module      om_tcp
    Host        ntopng_ip
    Port        4637
    <Exec>
        $EventTime = integer($EventTime);
        to_xml();
    </Exec>
</Output>

<Route 1>
    Path          eventlog => out
</Route>
```

## nBox {#nbox}

Collects syslog logs from nBox appliances. This is used to get notifications about services (start, stop, failures, crashes).

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## OpenVPN {#openvpn}

Collects syslog logs from devices running OpenVPN. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the OpenVPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## OPNsense {#opnsense}

Collects syslog logs from OPNsense devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the OPNsense VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## SonicWALL {#sonicwall}

Collects syslog logs from SonicWALL devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the SonicWALL VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## Sophos {#sophos}

Collects syslog logs from Sophos devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the Sophos VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*

## Suricata {#suricata}

Collects Suricata events in EVE JSON format through syslog. The EVE JSON output facility in Suricata outputs flows, alerts, anomalies, metadata, file info and protocol specific records. This can be used to collect flows (similar to Netflow), alerts, or both from Suricata.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in [Syslog Log Ingestion](/advanced_features/syslog.md#syslog-target).

*Interface: Packet & ZMQ*

*Category: Cybersecurity*
