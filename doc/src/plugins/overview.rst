Overview
========

Introduction
------------

ntopng core is extensible by means of plugins. Users and programmers with basic scripting skills are able to extend ntopng to implement custom features.

Capabilities
------------

Plugins offer the following capabilities.

Monitoring an Analysis
~~~~~~~~~~~~~~~~~~~~~~

Plugins provide mechanisms to watch and analyze network traffic, flows, hosts and other network elements. They also enable the monitoring of the health and status of ntopng, as well as of the system on top of which ntopng is running.

Alerts Generation
~~~~~~~~~~~~~~~~~

Plugins enable the generation of custom alerts. Generated alerts appear within the ntopng Web UI and are propagated towards external alert endpoints.

Flow Statuses
~~~~~~~~~~~~~

Plugins enable the assignment of custom statuses to flows. A status as a sort of label, a tag which can be attached to flows
having certain features. Alerts are triggered when certain flow statuses are detected.

Custom Pages
~~~~~~~~~~~~

Plugins enable the creation of custom pages. Custom pages are shown within the ntopng Web UI and have links in the menu.

Timeseries
~~~~~~~~~~

Plugins enable the generation of timeseries for custom metrics. Points of custom metrics are written from inside the plugin. ntopng charts show custom metrics points over time.

What is a Plugin
----------------

A plugin is a collection of Lua scripts with a predefined structure. 

Examples
~~~~~~~~

Examples of plugins are:

- A `flood
  detection <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/flow_flood>`_
  plugin to trigger alerts when hosts or networks are generating too
  many traffic flows
- A `blacklisted flows
  <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/blacklisted>`_
  plugin to detect flows involving malware or suspicious clients or servers
- A `monitor for the disk space
  <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/disk_monitor>`_
  which continuously observes free disk space and triggers alerts when the
  space available is below a certain threshold

Availability
------------

ntopng community plugins are opensource and available on the `ntopng
GitHub plugins page
<https://github.com/ntop/ntopng/tree/dev/scripts/plugins>`_.

