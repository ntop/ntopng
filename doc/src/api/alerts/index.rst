Alerts API
===========

ntopng provides an alert engine to generate alerts and visualize them into the GUI.

Currently only built-in alerts are supported, which are described in https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/alert_consts.lua .

Engaged Alerts
--------------

Some alerts in ntopng are shown as "Engaged" and reported as a red triangle
on a host or network interface. Engaged alerts represent ongoing issues and
are "released" once the issue re-enters.

Engaged alerts have a `periodicity` which the defines the expected trigger
frequency of them. If an alert is not "refreshed" (triggered) for some time
it will be automatically released.

.. toctree::

    alerts_api.rst
