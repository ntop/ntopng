.. _FlexibleAlerts:

Basic Concepts
==============

Flexible alert handling in ntopng allows to:

  - Avoid flooding recipients with too many alerts Only send to a
  - recipient the subset of alerts which are relevant for it,
  - according to different criteria

    - Severity-based criteria (e.g., only send alerts with severity
    - error or higher to that particular recipient) Type-based
    - criteria (e.g., only send security-related alerts to that
    - particular recipient)

Flexible alert handling is obtained with:

- Pools: to create groups of hosts, interfaces, SNMP devices, and
- other elements Endpoints and Recipients: to configure the actual
- alert recipients

Pools
-----

Pools are used to create groups of hosts, interfaces, SNMP devices and
other elements and they are managed from the system interface.

.. figure:: ../img/alerts_pools_management.png
  :align: center
  :alt: Pools Management

Endpoints and Recipients
------------------------

ntopng delivers alert to recipients. Recipients are configurable and
are always associated to one, and only one endpoint. Endpoints are
used to specify configurations that are common to multiple recipients.

Recipients and endpoints are managed from the system interface.

.. figure:: ../img/alerts_endpoints_recipients_management.png
  :align: center
  :alt: Endpoints and Recipients Management


For example, one can create the email endpoint as follows


.. figure:: ../img/alerts_email_endpoint.png
  :align: center
  :alt: Email Endpoint Configuration

Then, one can create multiple email recipients sharing the same
endpoint but each one with a different destination email address:


.. figure:: ../img/alerts_email_recipient.png
  :align: center
  :alt: Email Endpoint Configuration

Each endpoint can be configured to receive alerts:

- With a severity greater than or equal to a minimum severity
- With one or multiple categories

Once recipients are configured, ntopng will start delivering them only
the subset of alerts they are intended to receive.

See https://www.ntop.org/ntopng/using-ntopng-recipients-and-endpoints-for-flexible-alert-handling/
for a full example.


