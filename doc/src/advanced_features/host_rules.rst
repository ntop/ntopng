Host Rules
==========

ntopng can trigger customizable alerts, based on the timeseries a local host (or all local hosts) has available.

.. note::

  This feature is available only from Enterprise M license on.

.. figure:: ./../img/host_rules.png
  :align: center
  :alt: Host Rules Page

  Host Rules Page

Here some example of rules:
- The daily traffic of 192.168.2.28 does not have to exceed 2 GB in total;
- The NTP daily traffic of 192.168.1.1 does not have to exceed 2 GB in total;
- The 1kxun traffic every 5 minutes of 1.1.1.1 does not have to exceed 1 GB in total;
- The traffic every 5 minutes of 1.1.1.1 does not have to exceed 1 Mbps;

Whenever a condition is not respected, ntopng is going to trigger an alert.

To add a new rule, click the '+' symbol above the table

.. figure:: ./../img/add_host_rule.png
  :align: center
  :alt: Add an Host Rule

  Add an Host Rule

At this point, fill the fields with the correct informations:
- Host Timeseries: insert the IP of a Local Host to be analyzed or a * (meaning that all Local Hosts has to be analyzed)
- Metric: select the metric to be analyzed (e.g. DNS -> the DNS traffic)
- Frequency: select the frequency of the analysis (e.g. 5 Min -> analyzed every 5 minutes)
- Threshold: select the type of threshold (Volume or Throughput) and the threshold that, if exceeded, is going to trigger an alert

.. figure:: ./../img/add_host_rule_modal.png
  :align: center
  :alt: Add an Host Rule

  Add an Host Rule

From now on, a new entry with the configured fields is going to be added to the table and whenever the threshold is exceeded a new alert is going to be triggered.

.. figure:: ./../img/remove_host_rule.png
  :align: center
  :alt: Remove an Host Rule

  Remove an Host Rule

To instead, remove an entry, click on the action button of the row to delete and from there the rule can be deleted.

