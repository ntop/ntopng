Introduction
============

One of the greatest strengths of ntopng is its extensibility. By means
of plugins, functionalities of ntopng can be extended in a fast and easy
way, with just basic coding skills.

A plugin is a collection of scripts with
a predefined structure that enables ntopng to perform things such as
executing certain actions at the right point in time or when a certain
event occurs.

Plugins can watch and analyze network traffic, flows, hosts and
other network elements. In addition, plugins can monitor the health and status
of ntopng itself, as well as keep an eye on the system on top of which
ntopng is running.

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

ntopng community plugins are opensource and available on the `ntopng
GitHub plugins page
<https://github.com/ntop/ntopng/tree/dev/scripts/plugins>`_.

Plugins are written in Lua, so contributors don't have to know anything about
the internal ntopng engine to
create their own scripts and contribute them to the community.

Plugin Capabilities
-------------------

With plugins, one can instruct ntopng to execute certain actions at
regular intervals of time, or when it detects a certain condition. One
can also create custom pages and add them to the ntopng menu, and even
create timeseries of certain metrics of interest.

All plugin capabilities are briefly summarized below.

Alerts
~~~~~~

Plugins allow the generation of custom alerts. For example, one can
create an alert when it detects a certain host has too many TCP
retransmissions, or then the traffic towards a certain network drops
below a critical level. Similarly, one can create an alert when a
certain flow is using a suspicious port, or an invalid TLS
certificate.

Flow Statuses
~~~~~~~~~~~~~

By means of plugins, one can assign statuses to flows. Think
to a status as a sort of label, a tag which can be attached to flows
having certain features. So for example one can assign status
:code:`high_latency` to Remote Desktop flows with a latency above
250ms. Similarly, a status :code:`suspicious_port` can be assigned to
HTTP flows using a server port different from port 80. These are just
a couple of examples and actually the set of flow features one can use and
combine to assign a status is almost unlimited. Flow statuses can be
combined with alerts to instruct ntopng to trigger an alert as soon as
a certain flow status is detected.

Creating Custom Pages
~~~~~~~~~~~~~~~~~~~~~

Creating custom pages may be useful to users who want to extend
ntopng functionalities. For example, by means of custom pages, one can
create a TLS or MySQL ping to test and monitor the status of certain
critical services, and also chart the results. Custom pages can also
be added to the ntopng menu to allow quick access.

Writing Timeseries
~~~~~~~~~~~~~~~~~~

Using plugins, one can create and write timeseries for any custom
metric of interest. One can chart a particular metric for local hosts
(e.g., the number SYNs received), networks, and so on. ntopng charting
library can then be used to visualize created timeseries.

