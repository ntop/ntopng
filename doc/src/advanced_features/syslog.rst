.. _Syslog target:

Syslog Log Ingestion
====================

ntopng can collect logs from external sources including IDS systems, Firewalls or
hosts running a standard syslog server.

Log collection from IDS systems like `Suricata <https://suricata-ids.org>`_ can be 
used to enrich ntopng with additional security-oriented information including *flow* 
metadata (extracted files is an example) and *alerts* detected by means of 
signature-based threat-detection algorithms. For further information about this use
case please read the Suricata Integration section.

Firewall logs instead can be ingested by ntopng to provide visibility over firewall
activities. An example is the *Identity Management*, in fact it is possible to track
all connection/disconnection events logged by a VPN server, in order to associate 
traffic to users. ntopng Enterprise L includes plugin for collecting VPN logs and
correlate network traffic to VPN users supporting multiple devices from the vendors 
below:

- `Fortinet </guides/ntopng/alerts/syslog_checks.html#fortinet>`_
- `Kerberos/NXLog (Windows Active Directory) </guides/ntopng/alerts/syslog_checks.html#kerberos-nxlog>`_
- `OpenVPN </guides/ntopng/alerts/syslog_checks.html#openvpn>`_
- `OPNsense </guides/ntopng/alerts/syslog_checks.html#opnsense>`_
- `SonicWall </guides/ntopng/alerts/syslog_checks.html#sonicwall>`_
- `Sophos </guides/ntopng/alerts/syslog_checks.html#sophos>`_

For further information about all the VPN plugins please also visit :ref:`SyslogChecks target`.

ntopng Configuration
~~~~~~~~~~~~~~~~~~~~

In order to enable log ingestion from syslog in ntopng, a new syslog interface
should be added to the configuration file, with the syntax :code:`syslog://<ip>:<port>`
Note that :code:`*` is also supported to listen on any IP.
Example:

.. code:: text

   -i=syslog://*:5140
   -i=eth1

By default, ntopng listens both on UDP and TCP, in order to listen on UDP only or TCP
only, the :code:`@udp` or :code:`@tcp` suffix should be appended to the interface name
(example :code:`syslog://*:5140@udp`).

Note:

- Multiple syslog clients can connect simultaneously to the same ntopng instance.
- Remember to *restart* the *ntopng* service to apply the change.
- Please make sure the firewall (including iptables on the same box) is not blocking 
  connections to the configured port.
- Please note that log demultiplexing should be configured in order to parse and display 
  logs as described in the next section.

Logs Demultiplexing
~~~~~~~~~~~~~~~~~~~

ntopng does its best to automatically detect the producer of each log message, and
base on that parse the content and ingest all the contained information. However, 
in some cases, this is not explicitly specified in the message and an hint is required
in order to figure out who is the producer of the log message and parse it correctly,
especially when the same syslog stream contains log messages from multiple producers.
This is usually not required with logs produced by IDS systems like Suricata for instance,
however it is mandatory with some Firewalls supporting *Identity Management* like
Fortinet and SonicWALL. For this reason, a *Syslog Log Producers* tab is available in the 
syslog interface in the web GUI, where it is possible to configure all syslog sources by 
providing the source IP address or the device name (as they appear in the log) and the 
source type (e.g. Fortinet, or SonicWALL). Please note that some firewalls do not add
the IP address and device name to the log, in that case it is possible to use :code:`*` 
as IP address, it will be used as default in case no configured IP is matching.

.. figure:: ../img/advanced_features_syslog.png
  :align: center
  :alt: Syslog Log Producers

  Syslog Log Producers Configuration

Note:

- adding or removing sources does *not* require an application restart
- if the *Syslog Log Producers* tab does not happear, the *Identity Management* 
  plugins are probably not installed or available

Syslog Relay Configuration (Optional)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ntopng already includes a daemon able to listen for syslog logs on TCP or UDP at one 
(or more) configured endpoint. The log producer should be configured to send logs to 
that endpoint.

In some cases (e.g. an IDS running on the same host) a syslog client (the same applies
to relay configurations) like *rsyslog* should be installed and configured to export logs 
to ntopng. This is possible by creating a new configuration file under :code:`/etc/rsyslog.d` 
specifying the IP, the port and the protocol where ntopng will listen for connections.

.. code:: bash

   cat /etc/rsyslog.d/99-remote.conf 
   *.*  action(type="omfwd" target="127.0.0.1" port="5140" protocol="tcp" action.resumeRetryCount="100" queue.type="linkedList" queue.size="10000")

Please remember to *restart* the *rsyslog* service in order to apply the configuration.

Note: if log messages from the IDS are printed to the console by journalctl 
as broadcast messages, you probably want to suppress them by setting 
:code:`ForwardToWall=no` in */etc/systemd/journald.conf*.
Please remember to *restart* the *systemd-journald* service to apply the change.
It may be also required to edit */etc/rsyslog.d/50-default.conf* commenting out
lines containing :code:`:omusrmsg:*`.

Hosts Log Ingestion
~~~~~~~~~~~~~~~~~~~

The syslog integration in ntopng can also be used to collect logs from hosts
in the network, and trigger alerts when some log exceeding the configured severity
level is exceeded. This can be accomplished by creating the same configuration
described in the previous section for setting up a Syslog Relay using *rsyslog*
on each host. Example:

.. code:: bash

   cat /etc/rsyslog.d/99-remote.conf 
   *.*  action(type="omfwd" target="10.0.0.1" port="5140" protocol="tcp" action.resumeRetryCount="100" queue.type="linkedList" queue.size="10000")

Please remember to *restart* the *rsyslog* service in order to apply the configuration.

At this point the host should start sending syslog logs to ntopng.
In order to instruct ntopng to treat those logs as coming from hosts in
the monitored network, it is requested to specify the producer IP and 
producer type (in this case Host Log) under *Interface* -> *Syslog Log Producers*
as explained in the *Logs Demultiplexing* section.

Please note that it is also possible to change the severity level for
controlling which log event should actually trigger an alert in ntopng
under *Settings* -> *Syslog* -> *Edit* -> *Host Log* -> *Edit*.

It's a common practice to setup syslog ingestion for (important) hosts in the
monitored network. In this case it is convenient to have alerts generated in 
the same interface (the syslog interface should be used otherwise) where network 
traffic for the corresponding host is analysed. This is possible by configuring
the syslog interface as companion interface under *Interface* -> *Settings* -> *Companion Interface*.

nBox Log Ingestion
~~~~~~~~~~~~~~~~~~

nBox appliances based on the nBox UI are able to export events to syslog. This
includes the activity of users starting and stopping applications and services,
and software failures.
Syslog logs generated by nBox UI can be ingested by ntopng and used to generate
alerts. This requires the syslog format to be configured to JSON in the nBox UI
Notifications preferences. The ntopng address (including the port used for listening
for syslog logs) should be also configured.

.. figure:: ../img/advanced_features_nboxui_notifications_settings.png
  :align: center
  :alt: nBox UI Notifications Settings

  nBox UI Notifications Settings

The Syslog Log Producers configuration for the syslog interface in ntopng
should be configured to decode syslog logs as nBox UI logs by configuring
nBox as log producer.

.. figure:: ../img/advanced_features_nboxui_producer_configuration.png
  :align: center
  :alt: Syslog Log Producers

  Syslog Log Producers Configuration

At this point, ntopng should be able to ingest and decode events from the nBox
appliance and the Alerts Notifications can be configured to deliver those events
to the administrator via any supported Notification Endpoint and Recipient.

.. figure:: ../img/advanced_features_nboxui_telegram_notification.png
  :align: center
  :alt: nBox UI Telegram Notification

  nBox UI Telegram Notification

