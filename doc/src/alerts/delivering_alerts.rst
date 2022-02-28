.. _DeliveringAlertsToRecipients:

Delivering Alerts to Recipients
===============================

Once evaluated, alerts are sent to recipients. Recipients, along with their associated endpoints, are managed from the system interface.

.. figure:: ../img/alerts_endpoints_recipients_management.png
  :align: center
  :alt: Endpoints and Recipients Management

Recipients are associated to one, and only one endpoint, but the same endpoint can be shared across multiple recipients.

Endpoints and recipients have a type and a set of configuration parameters which depends on the type. All the available endpoints and recipients are described in the next section.

Endpoints contain common configuration which is then extended with recipients configuration. For example, the *email* endpoint contains the SMTP server address, whereas *email* recipients contain destination email addressses. This allows the creation of multiple *email* recipients, all sharing the same endpoint and, thus, the same SMTP server address.

An extensive example can bee seen at https://www.ntop.org/ntopng/using-ntopng-recipients-and-endpoints-for-flexible-alert-handling/.

Builtin
-------

A builtin *Alert Store DB* recipient, along with its builtin *Alert Store DB* endpoint, is always present. This is used to deliver alerts to the internal database (SQLite or ClickHouse) and have them accessible inside the web UI. Engaged alerts are not affected by the builtin pair and are always shown. For example, the following alerts are shown under *Flow Alerts* because they have been delivered to the builtin recipient. The builtin recipient cannot be edited or deleted.

.. figure:: ../img/alerts_builtin_historical_flows.png
  :align: center
  :alt: Builtin Recipient - Flow Alerts

Delivery Criteria
-----------------

Each recipient can be configured to receive alerts on the basis of a few criteria:

- Severity
- Alert Category
- Host Pool

Severity Criteria
~~~~~~~~~~~~~~~~~

A minimum severity is indicated when creating/editing the recipient. All alerts having the indicated (or an higher severity) will be delivered to the recipient.

.. figure:: ../img/alerts_recipient_criteria_minimum_severity.png
  :align: center
  :alt: Severity

Alert Category
~~~~~~~~~~~~~~

Multiple types can be indicated when creating/editing the recipient. All alerts belonging to the indicated types will be delivered to the recipient.

.. figure:: ../img/alerts_recipient_criteria_category_filter.png
  :align: center
  :alt: Alert Category


Host Pool Criteria
~~~~~~~~~~~~~~~~~~

None or multiple host pools can be configured to filter alerts which are relative to hosts, including Flow and Host alerts.
 
.. figure:: ../img/alerts_recipient_criteria_pool_filter.png
  :align: center
  :alt: Host Pool Criteria