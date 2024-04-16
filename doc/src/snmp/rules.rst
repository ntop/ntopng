Device rules
-----------------

.. note::

  This feature is available only from Enterprise L license.

Using SNMP Device rules, ntopng can generate an alert when an interface of a SNMP device crosses a threshold (either absolute or in percentage).

.. figure:: ../img/snmp_devices_rules.png
  :align: center
  :alt: SNMP Devices Rules

  SNMP Devices Rules

The idea is to compare the metric value with respect to a period of time and check the difference. If you use the percantage (%) you can easily spot situations where a host/interface doubles its traffic for instance.
  
Thresholds can be configured for SNMP metrics such as packets, bytes, and errors. 
When selecting packets or errors as the metric. The threshold can be specified as a percentage or absolute value with respect to the check frequency. Example if you set a traffic threshold of > 1 MB and 5 minutes frequency, an alert is triggered when the value of traffic in the last 5 minutes is greater then 1 MB. If instead you set the threshold to > 20% and 1 day frequency, an alert is triggered when the counter value with respect of the previous day is 20% (or more) bigger.

On the other hand, if bytes is chosen as the metric, the threshold can also be expressed in terms of volume (KB, MB, GB).
These checks are performed at frequencies of every 5 minutes, every hour, and every day.

These checks are useful for spotting misbehaving interfaces that instead would not have been noticed otherwise.

.. figure:: ../img/add_snmp_device_rule.png
  :align: center
  :alt: Add SNMP Device Rule

  Add SNMP Device Rule

When selecting the 'Percentage Change' threshold type, ntopng will check if the percentage change calculated between the last two frequency checks has crossed the specified threshold (e.g., <1% with a frequency of 5 minutes; if the difference between the preceding frequency and the last 5-minute check is lower than 1%, trigger an alert).

When selecting the 'Absolute Percentage' threshold type, ntopng will check if the percentage usage (uplink or downlink) of an interface on a device during the last period of time has crossed the specified threshold.