Alerts
======

ntopng includes an alerting engine to report different kind of events. Please read the `Basic Concepts <../basic_concepts/alerts.html>`_ 
section to learn more about this feature.

The Alerts Menu opens a page with the list of alerts that was fired. This icon is hidden if no alerts was
triggered or after purge operation. Each row in the Alerts page presents an alert detected by ntopng with
information such as Date, Severity, Type and Description.

.. figure:: ../img/web_gui_alerts_page.png
  :align: center
  :alt: Alerts Page

  The Alerts Page

:ref:`WebUIUserScripts` are responsible for the generation of alerts. Enabling and disabling a user scripts enables or disables the corresponding alerts. Alerts can also be disabled globally from the preferences.

.. figure:: ../img/web_gui_alerts_disable.png
  :align: center
  :alt: Global Alerts Toggle

  Global Alerts Toggle

.. _ThirdPartyAlertEndpoints:

Alert Endpoints
---------------

Generated alerts can also be sent to third-party endpoints. Currently supported endpoints are:

- Email
- Slack
- Syslog
- Nagios
- Webhook

Endpoints can be enabled and configured from the ntopng preferences page. Users can create custom
endpoints via a custom plugin. Check out the `example plugin <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/example/alert_endpoints>`_
for more details.

Email
~~~~~

Ntopng only supports sending emails to a SMTP server without authentication. Since ntopng
does not authenticate with the SMTP server, the server may reject the email. For
this reason, it is suggested to setup a local mail server (e.g. postfix_) and use
it as the email forwarder to the actual mail server.

It is possible to test the email sending functionality by using the "Send Test Email"
button. If an error occurs, an error message will be printed to the ntopng log.
It is possible to get a detailed log of the communication between ntopng and the mail server
by adding the `-v 6` option to the ntopng configuration. After doing this, the email
log will be printed in the console. It is advisable to use the `grep` command
(e.g. `ntopng -v6 | grep "Utils.cpp"`) to only filter out the email log information.

.. _postfix: https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-postfix-on-ubuntu-16-04

Webhook
~~~~~~~

Webhooks allow you to subscribe to alerts by configuring a HTTP endpoint. Alerts are encoded
in JSON messages and sent to the configured URL where they can be processed or used to trigger 
automations. 

You can add an endpoint by defining the URL and shared secret (optional). The shared secret is 
a user-defined secret to be validated by the webhook receiver. If the HTTP server requires HTTP 
authentication, you should also configure username and password.

.. figure:: ../img/web_gui_preferences_alerts_webhook.png
  :align: center
  :alt: Webhook Notification Preferences

  The Webhook Notification Preferences Page

It is possible to test the endpoint to make sure it is active and reachable by using the 
“Send Test Message” button. If an error occurs, an error message will be reported.

Example of alert sent to the webhook endpoint:

.. code:: text

   {version:0.1,sharedsecret:0123456789,alerts:[{"severity":"info","entity_value":"ntopng","ifid":1,"action":"store","tstamp":1536245738,"type":"process_notification","entity_type":"host","message":"[<tstamp>]][Process] Stopped ntopng v.3.7.180906 (CentOS Linux release 7.5.1804 (Core) ) [pid: 4783][options: --interface \"eno1\" --interface \"lo\" --dump-flows \"[hidden]\" --https-port \"4433\" --dont-change-user ]"}]}

Syslog
~~~~~~

Alerts are sent to syslog using standard syslog severities as per RFC 5424.

ntopng alert severities are mapped to standard syslog severities as follow:

- *Info*  becomes syslog :code:`LOG_INFO` equal to the integer 6
- *Warning* becomes syslog :code:`LOG_WARNING` equal to the integer 4
- *Error* becomes syslog :code:`LOG_ERR` equal to the integer 3

Two formats are available when sending alerts to syslog, namely plaintext and JSON. The format defaults to plaintext and can be toggled from the ntopng preferences page.

**Plaintext**

Plaintext alerts have the following format:

.. code:: bash

   [tstamp][severity][type][entity][entity value][action] ... and a plain text message...

Fields have the following meaning:

- :code:`[tstamp]` is the time at which ntopng detected the alert. This time
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

   devel ntopng: [<tstamp>][Info][Device Connection][Device][58:40:4E:CE:28:29] The device Apple_CE:28:29 has connected to the network.
   devel ntopng: [<tstamp>][Error][Threshold Cross][Interface][iface_0][Engaged] Minute traffic crossed by interface eno1 [1.08 MB > 2 Bytes]
   devel ntopng: [<tstamp>][Warning][Remote to Remote Flow][Flow] Remote client and remote server [Flow: 192.168.1.100:138 192.168.1.255:138] [L4 Protocol: UDP]

**JSON**

JSON alerts have the following keys that are in common with plaintext alerts, namely :code:`[entity]`, :code:`[entity value]`, :code:`[action]`, :code:`[tstamp]`, :code:`[severity]` and :code:`[type]`.

The additional keys are:

- :code:`message`: is a text message describing the alert.
- :code:`ifid`: the id of the monitored ntopng interface
- :code:`alert_key`: is a string that, for threshold-based alerts, represents the check interval (e.g., min, 5min, hour) and the type of threshold checked (e.g., bytes, packets).

Examples of JSON alerts sent to syslog are

.. code:: bash

   develv ntopng: {"entity_value":"ntopng","ifid":1,"action":"store","tstamp":1536245738,"type":"process_notification","entity_type":"host","message":"[<tstamp>]][Process] Stopped ntopng v.3.7.180906 (CentOS Linux release 7.5.1804 (Core) ) [pid: 4783][options: --interface \"eno1\" --interface \"lo\" --dump-flows \"[hidden]\" --https-port \"4433\" --dont-change-user ]","severity":"info"}
   devel ntopng: {"message":"[<tstamp>][Threshold Cross][Engaged] Minute traffic crossed by interface eno1 [891.58 KB > 1 Byte]","entity_value":"iface_0","ifid":0,"alert_key":"min_bytes","tstamp":1536247320,"type":"threshold_cross","action":"engage","severity":"error","entity_type":"interface"}
