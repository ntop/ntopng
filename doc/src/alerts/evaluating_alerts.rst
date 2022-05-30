Evaluating Alerts
=================

ntopng alerts are evaluated with :ref:`WebUIUserScripts`. Checks are executed for hosts, interfaces, SNMP devices, and other network elements, and are configurable from the settings.

.. figure:: ../img/alerts_checks_management.png
  :align: center
  :alt: Checks Configuration
  
Checks are desiged to verify specific conditions and when they are not me, trigger an alert. Below you can find the list of check families

.. toctree::
    :maxdepth: 2

    host_checks
    interface_checks
    local_network_checks
    snmp_checks
    flow_checks
    system_checks
    syslog_checks
    

