.. _SyslogChecks target:

Syslog Checks
#############

Syslog checks are called whenever ntopng collects logs as described in :ref:`Syslog target`. They are not real checks but rather are triggered whenever a syslog event is received. Below you can find the various syslog families.

____________________

**Fortinet**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from Fortinet devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the Fortined VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**Host Log**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from hosts. This is used to integrate all logs exported by hosts in the network.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**Kerberos/NXLog**
~~~~~~~~~~~~~~~~~~~~~~

Collect Kerberos authentication logs exported by NXLog in XML format. This is mainly used to handle Identity Management (user correlation) when Active Directory is used.
In order to integrate Kerberos with this plugin, NXLog should be configured to export Kerberos events using syslog and send them to ntopng as described in :ref:`Syslog target`.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**OpenVPN**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from devices running OpenVPN. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the OpenVPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**OPNsense**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from OPNsense devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the OPNsense VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**SonicWALL**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from SonicWALL devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the SonicWALL VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**Sophos**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from Sophos devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the Sophos VPN server and associate traffic to users.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

**Suricata**
~~~~~~~~~~~~~~~~~~~~~~

Collects Suricata events in EVE JSON format through syslog. The EVE JSON output facility in Suricata outputs flows, alerts, anomalies, metadata, file info and protocol specific records. This can be used to collect flows (similar to Netflow), alerts, or both from Suricata.

Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`.

*Category: Cybersecurity*

