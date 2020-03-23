Introduction
============

One of the greatest strengths of ntopng is its Lua
scriptability. Being able to create lua scripts allows faster and easier
developments, as contributors don't have to know anything about
the ntopng engine - which is written in :code:`C` and :code:`C++` - to
create their own scripts and contribute them to the community.
Lua scriptability is also one of the main differences ntopng has from
its predecessor ntop.

To have lua scripts executed by ntopng, one has to create a
plugin. Broadly speaking, a plugin is a collection of lua scripts with
a predefined structure that enables ntopng to recognize and execute
them at the rigth point in time or when a certain event happens.

Plugin Capabilities
-------------------

With plugins, one can instruct ntopng to execute certain actions at
regular intervals of time, or when it detects a certain condition. One
can also create custom pages and add them to the ntopng menu, and even
create timeseries of certain metrics of interest.

All plugin capabilities are briefly summarized below.

Alerts
------

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


Plugins vs User Scripts
-----------------------

It is easy to find menu entries and references to user scripts while
using the ntopng web user interface. Well, a user script is a part of
an ntopng plugin. A plugin can contain multiple
user scripts, whereas a user script is contained in one and only one
plugin.

So what are the differences between a plugin and a user script? A user
script contains the business logic which gets executed by ntopng when
a certain condition is detected (such as the creation of a new flow) or at
regular intervals of time (for example every minute). However, this
business logic may involve the generation of alerts, the setting of
flow statuses, and the writing of timeseries. A plugin is meant
to put together the business logic of user scripts with all the
ancillary things such as the definition of alerts and flow statuses.

To give a real example, let's consider the :ref:`Flow Flooders` which
will be presented in detail in the next section. This plugin aims at
triggering alerts when an host or a network is found to be a
flooder. The generated alert will be just one, 'this is a
flooder', no matter if the flooder is an host or a network. However,
the flood detection logic is different between networks and
hosts. Hence, the plugin will contain just a single alert definition
but two user scripts, one for the hosts and one for the networks. Each
user script will be able to re-use the alert, thus avoiding code
duplication.



