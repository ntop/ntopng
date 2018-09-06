Alerts
######

The Alerts Menu opens a page with the list of alerts that was fired. This icon is hidden if no alerts was
triggered or after purge operation. Each row in the Alerts page presents an alert detected by ntopng with
information such as Date, Severity, Type and Description.

.. figure:: ../img/web_gui_alerts_page.png
  :align: center
  :alt: Alerts Page

  The Alerts Page

.. _ThirdPartyAlertEndpoints:

Alert Endopints
---------------

Generated alerts can also be sent to third-party endpoints. Currently supported endpoints are:

- Email
- Slack
- Syslog
- Nagios

Endpoints can be enabled and configured from the ntopng preferences page.


Syslog
~~~~~~

Alerts are sent to syslog using standard syslog severities as per RFC
5424 and have a fixed format:

.. code:: bash

   [timestamp][severity][type][entity][entity value][action] ... and a plain text message...

Fields have the following meaning:

- :code:`[timestamp]` is the time at which ntopng detected the alert. This time
  is not necessarily equal to the time the alert has reached syslog.
- :code:`[severity]` is the severity of the alert. Severities are also
  used when dispatching messages to syslog. Severities are "Warning", "Error" of "Info".
- :code:`[type]` is a string that indicates the type of alert.
- :code:`[entity]` is a class that categorizes the originator of the
  alert. It can be an "host", an "interface" and so on.
- :code:`[entity value]` is an identifier that uniquely identifies the
  originator along with the :code:`[entity]`. For example, entity
  value for an "host" is its IP address, for an "interface" is its
  name, for a "device" is its MAC address, and so on.
- :code:`[action]` indicates whether this is an engaged alert, an
  alert that has been released or if it just an alert that has to be stored.

Alert types, entities, and actions are explained in detail in section :ref:`BasicConceptAlerts`.
  
Examples of alerts sent to syslog are

.. code:: bash

   devel ntopng: [<timestamp>][Info][Device Connection][Device][58:40:4E:CE:28:29] The device Apple_CE:28:29 has connected to the network.
   devel ntopng: [<timestamp>][Error][Threshold Cross][Interface][iface_0][Engaged] Minute traffic crossed by interface eno1 [1.08 MB > 2 Bytes]
   devel ntopng: [<timestamp>][Warning][Remote to Remote Flow][Flow] Remote client and remote server [Flow: 192.168.1.100:138 192.168.1.255:138] [L4 Protocol: UDP]
