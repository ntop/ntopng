Local Traffic Volume Rules
================================

ntopng can trigger customizable alerts, based on a local host traffic timeseries (or all local hosts if '*' is specified) or on a local network interface. This is useful to identify hosts or interface that trigger too much traffic on a specified timeframe.

.. note::

  This feature is available only from Enterprise M license or superior.

.. figure:: ./../img/traffic_rules.png
  :align: center
  :alt: Local Traffic Volume Rules Page

  Local Traffic Volume Rules Page

Here some example of rules:
  - The daily traffic of ens160 network interfce does not have to exceed 15 GB in total;
  - The daily traffic of 192.168.2.28 does not have to be less than 2 GB in total;
  - The NTP daily traffic of 192.168.1.1 does not have to exceed 2 GB in total;
  - The 1kxun traffic every 5 minutes of 1.1.1.1 does not have to exceed 15% from the precedent 5 minutes total traffic;
  - The traffic every 5 minutes of 1.1.1.1 does not have to exceed 1 Mbps;

Whenever a condition is met, ntopng is going to trigger an alert.

To add a new rule, click the '+' symbol above the table

.. figure:: ./../img/add_traffic_rule.png
  :align: center
  :alt: Add a Local Traffic Volume Rule

  Add a Local Traffic Volume Rule

At this point, fill the fields with the correct informations:
  - Target: insert the IP of a Local Host to be analyzed or a * (meaning that all Local Hosts has to be analyzed) or select a local network interface
  - Metric: select the metric to be analyzed (e.g. DNS -> the DNS traffic)
  - Frequency: select the frequency of the analysis (e.g. 5 Min -> analyzed every 5 minutes)
  - Threshold: select the type of threshold (Volume, Throughput or Percentage), lowerbound or upperbound, and the threshold that, if exceeded, is going to trigger an alert
  - Percentage Threshold: is calculcated beetwen the last two frequency checks (e.g. <1% with frequency 5 Min -> if the difference between precedent frequency and the last 5 minutes check is lower than 1% trigger and alert)

.. figure:: ./../img/add_traffic_rule_modal.png
  :align: center
  :alt: Add a Local Traffic Volume Rule

  Add a Local Traffic Volume Rule

From now on, a new entry with the configured fields is going to be added to the table and whenever the threshold is exceeded a new alert is going to be triggered.

.. figure:: ./../img/remove_traffic_rule.png
  :align: center
  :alt: Remove a Local Host Traffic Volume Rule

  Remove a Local Host Traffic Volume Rule

Instead, in order to remove an entry, click on the action button of the row to delete and from there the rule can be deleted.

.. note::
   
   Traffic rules are evaluated according to the rule frequency specified. For instance Daily rules are evaluated every midnight considering the traffic of the previous day.

