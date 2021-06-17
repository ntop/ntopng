Developing Alerts
#################

ntopng has the ability to create alerts for flows, hosts, and other network elements. Alerts for flows and hosts are created inside the C++ core of ntopng for performance. This section describes how to create alerts for hosts and flows. Alerts for other network elements are created by means of plugins (:ref:`Plugin Structure`).

Alerts are created inside checks. This section starts with a description of checks, and then moves to the alerts. The interplay between alerts and checks is presented, along with examples with the aim of giving a comprehensive overview of all the components at play.  The section ends with handy checklists that can be used as reference when developing alerts.

.. toctree::
    :maxdepth: 2

    developing_alerts

