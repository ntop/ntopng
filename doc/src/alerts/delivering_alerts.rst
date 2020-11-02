Delivering Alerts to Recipients
===============================

ntopng delivers alert to recipients. Recipients are configurable and
are always associated to one, and only one endpoint. Endpoints are
used to specify configurations that are common to multiple recipients.

Recipients and endpoints are managed from the system interface.

.. figure:: ../img/alerts_endpoints_recipients_management.png
  :align: center
  :alt: Endpoints and Recipients Management

Configuring Recipients
----------------------

Each endpoint can be configured to receive alerts:

  - With a severity greater than or equal to a minimum severity
  - With one or multiple categories

Once recipients are configured, ntopng will start delivering them only the subset of alerts they are intended to receive.

TODO: refine

See https://www.ntop.org/ntopng/using-ntopng-recipients-and-endpoints-for-flexible-alert-handling/
for a full example.


Associating Recipients to Pools
-------------------------------

Recipients are associated to pools. A recipient can be associated to multiple pools.

TODO: refine.
