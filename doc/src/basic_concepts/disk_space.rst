Disk Space Requirements
########################

ntopng uses disk space to store:

- Timeseries
- Flows

Timeseries storage can be controlled, to a great extent, using the
Preferences page. For example, one can choose to store only the traffic
timeseries of every host, or can also enable the generation of Layer-7
application protocol timeseries.

Timeseries are generated for interfaces, local networks, traffic profiles,
and local hosts, just to name a few. As local hosts are always orders of
magnitude greater than other timeseries, the space used by ntopng is
expressed as a function of the number of local hosts in the system.

Estimating Space Requirements
------------------------------

The following tables summarize the approximate disk space used per local
host, depending on which timeseries driver and which timeseries are
enabled.

RRD
~~~

RRD files have a fixed size and do not grow over time. The space needed
per local host depends on which timeseries are enabled:

========================================================================  =================================================
Enabled Timeseries                                                        Disk Space
========================================================================  =================================================
Host Timeseries "Light" (default)                                         92 KB / local host (2 RRDs / host)
Host Timeseries "Full", Layer-7 Applications "None"                       1.3 MB / local host (approx. 25 RRDs / host)
Host Timeseries "Full", Layer-7 Applications "Per Category"                1.6 MB / local host (approx. 30 RRDs / host)
Host Timeseries "Full", Layer-7 Applications "Per Application"            up to 13.8 MB / local host
Host Timeseries "Full", Layer-7 Applications "Both"                       up to 14.1 MB / local host
========================================================================  =================================================

InfluxDB
~~~~~~~~

Unlike RRD, InfluxDB timeseries grow over time, so the space required
also depends on the retention period, in addition to the number of local
hosts and the chosen resolution:

======================  ===========================  ==========================
InfluxDB                10-second resolution          60-second resolution
======================  ===========================  ==========================
Timeseries storage      ~450 KB / local host / day    ~75 KB / local host / day
======================  ===========================  ==========================

Flows
-----

Flow storage is optional and disabled by default. As a rough average
(mostly IPv4 traffic with some IPv6), ntopng uses approximately
**11 bytes per stored flow**; this can be higher with predominantly IPv6
traffic or when long metadata strings are stored along with the flows.

.. note::

  These figures are indicative averages measured on real production
  deployments and are meant only as a rule of thumb for capacity
  planning. For the full methodology used to derive them, as well as
  more up to date figures, see:
  https://www.ntop.org/ntopng-disk-requirements-for-timeseries-and-flows/

The same page can also be used to estimate the space required to store
flows.