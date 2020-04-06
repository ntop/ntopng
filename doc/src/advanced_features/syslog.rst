Syslog Log Ingestion
====================

ntopng can collect logs from external sources, including IDS systems and Firewalls.

Log collection from IDS systems like `Suricata <https://suricata-ids.org>`_ can be 
used to enrich ntopng with additional security-oriented information including *flow* 
metadata (extracted files is an example) and *alerts* detected by means of 
signature-based threat-detection algorithms. For further information about this use
case please read the Suricata Integration section.

Firewall logs instead can be ingested by ntopng to provide visibility over firewall
activities. An example is the *Identity Management*, in fact it is possible to track
all connection/disconnection events logged by a VPN server, in order to associate 
traffic to users.

Syslog Configuration
~~~~~~~~~~~~~~~~~~~~

ntopng implements a daemon able to listen for syslog logs on TCP or UDP at one (or
more) configured endpoint. The log producer should be configured to send logs to 
that endpoint.

Let's assume an IDS is running on the same host. *rsyslog* should be installed and 
configured to export logs to ntopng. This is possible by creating a new configuration
file under :code:`/etc/rsyslog.d` specifying the IP, the port and the protocol where
ntopng will listen for connections.

.. code:: bash

   cat /etc/rsyslog.d/99-remote.conf 
   *.*  action(type="omfwd" target="127.0.0.1" port="9999" protocol="tcp" action.resumeRetryCount="100" queue.type="linkedList" queue.size="10000")

Please remember to *restart* the *rsyslog* service in order to apply the configuration.

Note: if log messages from the IDS are printed to the console by journalctl 
as broadcast messages, you probably want to suppress them by setting 
:code:`ForwardToWall=no` in */etc/systemd/journald.conf*.
Please remember to *restart* the *systemd-journald* service to apply the change.

ntopng Configuration
~~~~~~~~~~~~~~~~~~~~

In order to enable log ingestion from syslog in ntopng, a new syslog interface
should be added to the configuration file, with the syntax :code:`syslog://<ip>:<port>`
Example:

.. code:: text

   -i=syslog://127.0.0.1:9999
   -i=eth1

By default, ntopng uses the TCP protocol, in order to switch to UDP, the :code:`@udp`
suffix should be appended to the interface name (example :code:`syslog://127.0.0.1:9999@udp`).

Note:

- Multiple syslog clients can connect simultaneously to the same ntopng instance.
- Remember to *restart* the *ntopng* service to apply the change.

Logs Demultiplexing
~~~~~~~~~~~~~~~~~~~

ntopng does its best to automatically detect the producer of each log message, and
base on that parse the content and ingest all the contained information. However, 
in some cases, this is not explicitly specified in the message and an hint is required
in order to figure out who is the producer of the log message and parse it correctly,
expecially when the same syslog stream contains log messages from multiple producers.
For this reason, a *Syslog Log Producers* tab is available in the syslog interface in 
the web GUI, where it is possible to configure all syslog sources by providing the 
source IP address (as it appears in the log) and the source type (e.g. Fortinet, 
SonicWALL, Suricata).

.. figure:: ../img/advanced_features_syslog.png
  :align: center
  :alt: Syslog Log Producers

  Syslog Log Producers Configuration

Please note that adding or removing sources does *not* require an application
restart.

