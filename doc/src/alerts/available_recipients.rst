Available Endpoints and Recipients
==================================

Currently available Endpoints and recipients are 

Email
-----

One can create the email endpoint as follows

.. figure:: ../img/alerts_email_endpoint.png
  :align: center
  :alt: Email Endpoint Configuration

Then, one can create multiple email recipients sharing the same
endpoint but each one with a different destination email address:


.. figure:: ../img/alerts_email_recipient.png
  :align: center
  :alt: Email Endpoint Configuration

Discord
-------

Discord (https://discord.com) is a popular collaboration application that can be used by ntopng to deliver alerts to recipients. In order to deliver alerts you need to configure a new Discord server as described in this document https://support.discord.com/hc/en-us/articles/204849977-How-do-I-create-a-server- and the to create a webhook as decribed here https://support.discord.com/hc/en-us/articles/360045093012-Server-Integrations-Page

.. figure:: ../img/discord_endpoint.png

Once in the webhook click on the "Copy Webhook URL" button that will copy the URL into your clipboard. Done this we're ready to create a ntopng Discord Endpoint. On the System interface (upper menubar, dropdown menu) select Notifications -> Endpoints and click on the + icon. A new dialog windown will open: select Discord from the endpoint type menu and insert the Webhook URL you have previusly copied on your clipboard, pick a endpoint name you like and save it.

Done this you can create a recipient for this endpoint. You can optionally specify a Username in the recipient page that is used when messages are delivered to Discord. If you do not set a username the one used in the Discord Webhook page will be used (usually set to 'Captain Hook').

.. figure:: ../img/discord_alerts.png

The above picture shows sample alerts delivered to a discord server.


Telegram
--------

First of all navigate from the Web GUI into the section Notification->Endpoints; after that, click on the `+` on the right corner of the Endpoint window, this way it will add a new Endpoint for the notification system. Select inside the `Type` window `Telegram`. Then open Telegram, search for `@BotFather` and start a new conversion with it.

.. figure:: ../img/telegram_new_conversation_botfather.png

After that, send the following messages in this order:
  - :code:`/newbot`
  - :code:`bot_name` (the name that's going to have the bot, e.g. `ntopng_telegram_plugin`)
  - :code:`bot_username` (the username that's going to have the bot, e.g. `ntopng_telegram_plugin_bot`)

.. figure:: ../img/telegram_full_conversation_botfather.png

Now @BotFather will give a token, useful to enable ntopng to talk with the bot actually created; copy this token and paste it into the `Add New Endpoint` window of ntopng previously opened, name the Endpoint (e.g. `telegram_endpoint`) and click `Add`.

After that navigate to Notification->Recipients and, just like before, click on the `+` simbol on the right high corner of the Recipient window. Now select into the Endpoint section of `Add New Recipient` the endpoint previously created, name it (e.g. telegram_recipient_mychat), select the Minimum Severity of the notifications and the Category of the notification desired.

Then go back to Telegram. 
If the bot have to personally send the alarms directly into the private chat then follow these steps:
  - search for `@getidsbot` and start a conversation with it
  - copy the id the bot gave to you

.. figure:: ../img/telegram_getidsbot_search.png

 Otherwise if you want to add the bot to a group chat and send messagges on that group, follow the following steps:
  - add the bot you previosly created (searching for his name) to your group chat
  - now add to that group chat `@getidsbot`
  - copy the id the bot sent on the group chat

.. figure:: ../img/telegram_getidsbot_copy_id_group.png

Now paste the id into the `Add New Recipient` window of ntopng and click `Add` (click `Test Recipient` to test if the bot is working correctly).

Now add to the relative Pool the Telegram recipient you just created and it's done!

.. figure:: ../img/telegram_alerts.png

Script
------

Create the script you want to execute each time the alert is triggered and put it inside the directory :code:`/usr/share/ntopng/`.
Then create the new Endpoint, selecting the script you just created.

.. figure:: ../img/shell_endpoint.png

After that create a new recipient to associate with the new endpoint just created and inside the Options field insert the various options you want to pass to the shell script when executing.

.. figure:: ../img/shell_recipient.png

.. note::

        The script must need at least one argument, that is the JSON object given to the script by the alert script, containing various informations about the alert itself.


Webhook
-------

TODO

Elasticsearch
-------------

This recipient is designed to send alerts to `Elasticsearch <https://www.elastic.co/>`_.

.. note::

  Elasticsearch recipient is only available in ntopng Enterprise M or above.


The endpoint requires the Elasticsearch URL to be specified, along with (optional) parameters for the authentication.

.. figure:: ../img/web_gui_alerts_es_endpoint.png
  :align: center
  :alt: Elasticsearch Endpoint

  Elasticsearch Endpoint

Multiple recipients can then be associated to the Elasticsearch endpoint. Any recipient can use a different prefix for the index names.

.. figure:: ../img/web_gui_alerts_es_recipient.png
  :align: center
  :alt: Elasticsearch Recipient

  Elasticsearch Recipient

By default, alerts are sent to Elasticsearch indexes :code:`alerts-ntopng-<year>.<month>.<day>`. A new index is created every day. For example, index names used for two consecutive days of April 17th and 18th 2020 are :code:`alerts-ntopng-2020-04-17` and :code:`alerts-ntopng-2020-04-18`. If an index prefix is specified in the endpoint, then the prefix is used in place of :code:`alerts-ntopng`.

The Elasticsearch connection can be tested by clicking the "Test Connection" button of the preferences.

.. note::

  Elasticsearch alert endpoint requires at least Elasticsearch version 7. Version can be tested by clicking the "Test Connection" button of the preferences.

Alerts are sent to Elasticsearch in JSON format. The the following keys are always present:

- :code:`@timestamp`: UTC/GMT alert detection date and time in ISO format yyyy-MM-dd'T'HH:mm:ss.SSSZ.
- :code:`alert_tstamp`: Alert detection Unix epoch
- :code:`alert_tstamp_end`: Alert release Unix epoch for :ref:`Released Alerts`, otherwise this key is not present.
- :code:`alert_type`:  one of {`alert_blacklisted_country`, ` alert_broadcast_domain_too_large`, `alert_device_connection`, ...}. Strings list available at `/lua/defs_overview.lua`.
- :code:`alert_severity`: one of {`info`, `warning`, `error`}.
- :code:`alert_entity`: one of {`interface`, `host`, `network`, ...}. `List of all the available types <https://github.com/ntop/ntopng/blob/fae050b90a8eacf8d1dd64b9142b02b5f54753c8/scripts/lua/modules/alert_consts.lua#L299>`_.
- :code:`alert_entity_val`: A string representing the current alert entity. For hosts the format is `<ip>@<vlan>`, e.g.,  `127.0.0.1@0`.
- :code:`ifname`: The interface name string where the alert was detected, e.g., `eno1`.
- :code:`ntopng_instance_id`: The ntopng instance name string where the alert was detected., e.g., `ntopng-instance-brx1`. Instance name can be configured with option :code:`--instance-name`.
- :code:`engaged`: A boolean which is true for :ref:`Engaged Alerts`, false otherwise.
- :code:`alert_subtype`: A string subtype which depends on the :code:`alert_type`. For example threshold cross can have subtype `bytes`, `packets`, `score`, etc.
- :code:`alert_granularity`: one of {`min`, `5min`, `hour`, `day`}, empty. Empty when the alert doesn't come out of a periodic check (e.g., broadcast domain too large). `List of all the available granularities <https://github.com/ntop/ntopng/blob/fae050b90a8eacf8d1dd64b9142b02b5f54753c8/scripts/lua/modules/alert_consts.lua#L346>`_.
- :code:`alert_json`: A JSON string with additional, alert-specific information (e.g., the broadcast domain, the threshold set, the exceeded value).
- :code:`alert_msg`: A human readable string text message of the alert.

:ref:`Flow Alerts` have the following additional fields:

- :code:`flow_status`: one of {`status_blacklisted`, `status_data_exfiltration`, `status_suspicious_tcp_probing`}. Strings list available at `/lua/defs_overview.lua`.
- :code:`first_seen`: Flow first seen Unix epoch.
- :code:`l7_proto`: A string with the detected nDPI protocol, e.g., `HTTP.Google`.
- :code:`cli_asn`: Integer with the client ASN or empty when ASN information is not available.
- :code:`srv_asn`: Integer with the server ASN or empty when ASN information is not available.
- :code:`cli_country`: ISO 3166 alpha-2 country code string for the client or empty when country information is not available.
- :code:`srv_country`: ISO 3166 alpha-2 country code string for the server or empty when country information is not available.
- :code:`cli_port`: Integer of the client flow port.
- :code:`srv_port`: Integer of the server flow port.
- :code:`cli_os`: A string with the detected client operating system or empty when operating system is not available.
- :code:`srv_os`: A string with the detected server operating system or empty when operating system is not available.
- :code:`vlan_id`: Integer of the flow VLAN. Integer is zero when the flow has no VLAN.
- :code:`srv2cli_bytes`: Integer with the number of bytes transferred from the server to the client when the alert was generated.
- :code:`cli2srv_bytes`: Integer with the number of bytes transferred from the client to the server when the alert was generated.
- :code:`cli2srv_packets`: Integer with the number of packets transferred from the client to the server when the alert was generated.
- :code:`srv2cli_packets`: Integer with the number of packets transferred from the server to the client when the alert was generated.
- :code:`cli_addr`: A string with the client IPv4 or IPv6 address.
- :code:`srv_addr`: A string with the server IPv4 or IPv6 address.
- :code:`score`: The flow score integer.

Slack
-----

TODO

Syslog
------

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
   


