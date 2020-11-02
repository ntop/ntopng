.. _FlexibleAlerts:

Basic Concepts
==============

ntopng alerts are:

- Evaluated with User Scripts for pools of hosts, interfaces, SNMP devices, and other network elements
- Delivered to recipients using type- or severity-based criteria

Evaluating Alerts
-----------------

ntopng alerts are evaluated with User Scripts. User Scripts are executed for hosts, interfaces, SNMP devices, and other network elements. All network elements are evaluated in pools. Host Pools group together multiple hosts. Similarily, Interface pools group together multiple interfaces, and so on. Pools are managed from the system interface.

.. figure:: ../img/alerts_pools_management.png
  :align: center
  :alt: Pools Management


User Scripts are configurable. Each User Script can have multiple configurations. A configuration contains values for thresholds and other User Uscript-specific parameters. Configurations are applied to pools. Different pools can have different configurations.

TODO: refine.


Delivering Alerts to Recipients
-------------------------------

ntopng delivers alert to recipients. Recipients are configurable and
are always associated to one, and only one endpoint. Endpoints are
used to specify configurations that are common to multiple recipients.

Recipients and endpoints are managed from the system interface.

.. figure:: ../img/alerts_endpoints_recipients_management.png
  :align: center
  :alt: Endpoints and Recipients Management

Configuring Recipients
~~~~~~~~~~~~~~~~~~~~~~

Each endpoint can be configured to receive alerts:

- With a severity greater than or equal to a minimum severity
- With one or multiple categories

Once recipients are configured, ntopng will start delivering them only the subset of alerts they are intended to receive.

TODO: refine

See https://www.ntop.org/ntopng/using-ntopng-recipients-and-endpoints-for-flexible-alert-handling/
for a full example.


Associating Recipients to Pools
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Recipients are associated to pools. A recipient can be associated to multiple pools.

TODO: refine.


Available Endpoints and Recipients
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


Currently available Endpoints and recipients are 

Email
^^^^^

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
^^^^^^^

Telegram
^^^^^^^^

Webhook
^^^^^^^

Elasticsearch
^^^^^^^^^^^^^

Slack
^^^^^

Syslog
^^^^^^


