Configuration and Discovery
---------------------------

You can configure a single device or discover devices on a subnet by clicking on the '+' icon and filling up the form below

.. figure:: ../img/SNMP_AddDevices.png
  :align: center
  :alt: Add SNMP Device

Alternatively, you can import a JSON file containing the configuration of the devices by clicking on the import icon (|import|).

.. |import| image:: ../img/SNMP_ImportIcon.png
  :height: 25px

.. figure:: ../img/SNMP_ImportDevices.png
  :align: center
  :alt: Import SNMP Devices

ntopng will then discover all the active SNMP devices adding them to the device list

.. figure:: ../img/SNMP_Overview.png
  :align: center
  :alt: SNMP Devices Overview

Devices are polled automatically every 5 minutes and timeseries are created if enabled in preferences where you can also specify the default SNMP community.

.. figure:: ../img/SNMP_Preferences.png
  :align: center
  :alt: SNMP Preference


SNMP Import file
~~~~~~~~~~~~~~~~

The file to import for SNMP device configuration must be a JSON array, with each object containing the 'ip_address' key corresponding to the IP address of the SNMP devices, with or without the CIDR (by default set to /32). 
It is also possible to specify the community (default is 'public') and the SNMP version (default is '2c').

.. code:: json

  [
    { 
      "ip_address":"192.168.2.38",
      "version":"2c",
      "community":"public"
    },
    {
      "ip_address":"192.168.2.0/24",
      "version":"2c",
      "community":"public"
    }
  ]


