# Monitored Metrics

ntopng currently implements `MonitoredCounter`s and `MonitoredGauge`s
to add monitoring to plain counters and gauges. Both classes inherit
from `MonitoredMetric` to re-use certain parts of the code.

Monitoring basically boils down to the calculation of a Relative
Strength Index (RSI) on the monitored metrics.

To reduce memory usage, RSI is computed on Exponentially Weighted
Moving Averages (EWMAs) of gains and losses, rather than on the actual
gains and losses. The alpha coefficient used has been currently chosen
to be `0.5`.

Currently, monitored counters and gauges are:

- The active number of host client and server flows (gauge)
- The number of low-goodput host client and server flows (gauge)
- The number of host DNS queries, OK replies and error replies,
  both sent and received (counter)
- The number of host ICMP destination unreachable messages (counter)
- The number of ARP requests and replies (counter)

## Alerts

When the RSI of a certain monitored metric goes below 25 or above 75
-- RSI should normally stay at around 50 when the metric doesn't
change significantly from the past -- an engaged anomaly alert is
raised.

Currently, engaged alerts are triggered for all the monitored counters
and gauges listed above, except for ARP requests and replies.

To enable alerts generation for these alerts it is necessary to set the
following key

```
redis-cli set "ntopng.prefs.beta_anomaly_index_alerts" "1"
```
