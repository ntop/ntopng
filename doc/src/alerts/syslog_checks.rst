Syslog Checks
#############

Syslog checks are called whenever ntopng collects logs as described in :ref:`Syslog target`. They are not real checks but rather are triggered whenever a syslog event is received. Below you can find the various syslog families.

____________________

**Fortinet**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from Fortinet devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the Fortined VPN server and associate traffic to users.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

**Host Log**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from hosts. This is used to integrate all logs exported by hosts in the network.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

**OpenVPN**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from devices running OpenVPN. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the OpenVPN server and associate traffic to users.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

**OPNsense**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from OPNsense devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the OPNsense VPN server and associate traffic to users.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

**SonicWALL**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from SonicWALL devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the SonicWALL VPN server and associate traffic to users.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

**Sophos**
~~~~~~~~~~~~~~~~~~~~~~

Collects syslog logs from Sophos devices. This is mainly used to implement Identity Management, to track all connection/disconnection events logged by the Sophos VPN server and associate traffic to users.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

**Suricata**
~~~~~~~~~~~~~~~~~~~~~~

Collects Suricata events in EVE JSON format through syslog. The EVE JSON output facility in Suricata outputs flows, alerts, anomalies, metadata, file info and protocol specific records. This can be used to collect flows (similar to Netflow), alerts, or both from Suricata.

*Category: Cybersecurity*

*Enabled by Default - requires the Syslog Producer configuration for Logs Demultiplexing as described in :ref:`Syslog target`*

