.. _Plugins vs User Scripts:

Plugins vs User Scripts
=======================

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

To give a real example, let's consider the :ref:`Flow Flooders` plugin, which
will be presented in detail in the next section. This plugin aims at
triggering alerts when an host or a network is found to be a
flooder. The generated alert will be just one, 'this is a
flooder!', no matter if the flooder is an host or a network. However,
the flood detection logic is different between networks and
hosts. Hence, the plugin will contain just a single alert definition
but two user scripts, one for the hosts and one for the networks. Each
user script will be able to re-use the alert, thus avoiding code
duplication.



