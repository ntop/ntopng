Evaluating Alerts
=================

ntopng alerts are evaluated with User Scripts. User Scripts are executed for hosts, interfaces, SNMP devices, and other network elements, and are configurable from the settings


.. figure:: ../img/alerts_user_scripts_management.png
  :align: center
  :alt: User Scripts Configuration


Although only a **Default** configuration is shown in the figure above, each User Script can have multiple configurations. A configuration contains values for thresholds and other User Uscript-specific parameters.

In the example below, the **Default** configuration for Host User Scripts is configured to trigger an alert when the number of new flows per second generated exceeds 256.


.. figure:: ../img/alerts_default_host_configuration.png
  :align: center
  :alt: Default Configuration for Host User Scripts


Configurations are applied to pools. Different pools can have different configurations.

All network elements are evaluated in pools. :ref:`BasicConceptsHostPools` group together multiple hosts. Similarily, Interface pools group together multiple interfaces, and so on.

Pools are managed from the system interface.

.. figure:: ../img/alerts_pools_management.png
  :align: center
  :alt: Pools Management


TODO: refine.
