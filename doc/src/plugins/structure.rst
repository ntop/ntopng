.. _Plugin Structure:

Plugin Structure
================

The most complete example of plugin structure is the following

.. code:: bash

   example/
   |-- manifest.lua
   |-- locales
   |   `-- en.lua
   |-- alert_endpoints
   |   |-- example.lua
   |   `-- prefs_entries.lua
   |-- alert_definitions
   |   `-- alert_example.lua
   |-- status_definitions
   |   `-- status_example.lua
   |-- checks
   |   |-- interface
   |   |   `-- example.lua
   |   |-- network
   |   |   `-- example.lua
   |   |-- snmp_device
   |   |   `-- example.lua
   |   `-- system
   |       `-- example.lua
   |-- ts_schemas
   |   |-- min.lua
   |   `-- 5mins.lua
   `-- web_gui
       |-- example_page.lua
       `-- menu.lua

The root directory :code:`example` must have a name which is
representative for the plugin. Sub-directories contain:

- :code:`manifest.lua`: file containing a name and a description of the plugin. See :ref:`Manifest`.
- :code:`locales` (optional): files for the localization of strings used within the plugin, such as the description of a generated alert. When this directory is omitted, strings found in the plugin will be taken verbatim. See :ref:`Plugin Localization`.
- :code:`alert_endpoints` (optional): files to create alert endpoints. An alert endpoint is called by ntopng every time an alert is
  generated. Alert endpoints enable an alert to be post-processed or delivered downstream to an external alert collector. This directory can be omitted when the plugin does not create alert endpoints. See :ref:`Alert Endpoints`.
- :code:`checks`: files with the logic necessary to
  perform  custom actions. This directory contains additional
  sub-directories, namely, :code:`interface`, :code:`network`,
  :code:`snmp_device`, and :code:`system`. ntopng guarantees files
  found under the :code:`interface` directory are be executed for every
  interface; files found under the :code:`network` directory will be executed for every local network; and so on.
  Sub-directories can be missing or empty, depending
  on whether the plugins wants to perform certain actions or not. See :ref:`Checks`.
- :code:`ts_schemas`: contains timeseries schemas definitions. See :ref:`Timeseries Schemas`.
- :code:`web_gui`: file to create custom ntopng pages and link them in
  the main ntopng menu. See :ref:`Custom Pages`.

