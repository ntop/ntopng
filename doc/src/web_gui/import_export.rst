Configuration Import/Export
===========================

ntopng provides the ability to backup its configuration, in order to be able to restore it in case of system
failures and reinstallations, or to clone it to other systems requiring the very same configuration (e.g. in
a cluster or in a high-availability deployment), saving a lot of time for manually copying all the settings.

Through the web GUI it is possible to export selected configurations, including:

- SNMP configuration
- Active Monitoring configuration
- Checks configuration
- Alerts Endpoints and Recipients
- All Pools (this will also include all the previous items, as this depends on them)

or export the entire ntopng configuration, which includes *Users* and *Preferences* in addition to all the
above items. In both cases, a small JSON file containing the configuration is generated.

It is also possible to import back a configuration which as been exported before, providing the JSON file.
The configuration items contained in the imported configuration will be added to those already present in
the current ntopng configuration (e.g. endpoint already configured in ntopng, if any, will not be deleted when
importing additional endpoints).

Resetting the configuration to factory defaults is also possible. This is also useful when importing
a configuration and preserving the old one is not required nor wanted (e.g. when adding a set of recipients
and endpoints without preserving those already present).

All this is available from the *Settings* -> *Manage Configurations* menu, as shown in the below picture.

.. figure:: ../img/web_gui_import_export_page.png
  :align: center
  :alt: Manage Configurations Page

  The Manage Configurations Page

 
