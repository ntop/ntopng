.. _TrafficReport:

Traffic Report
==============

The Traffic Report shows how much traffic an interface, a local network or a host made in each
hour of a day, or in each day of a week or of a month, next to the same hour or day of the
period before. It is a tab of the interface page, of the network page and of the host page (local
hosts only).

.. note::
    The Traffic Report needs the Enterprise M license and the RRD timeseries driver (it reads the
    traffic charts). It is not available for pcap files.

Choose the period with the buttons at the top:

- **Daily**, **Weekly** or **Monthly**: one row per hour (daily) or per day (weekly, monthly).
- The arrows move to the previous or to the next period; the next one is disabled on the current
  period.
- The date field jumps to the period of a day, **Today** opens the report of today.

For each hour or day the table shows the traffic and the active time (how long there was
traffic) of the period, of the previous period and the difference between them. Saturdays and
Sundays are in red. The last row has the totals. Click an hour or a day to open the traffic
charts of that time.
