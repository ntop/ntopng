# ClickHouse
For more information about howto use ClickHouse in ntopng please see
- https://www.ntop.org/guides/ntopng/flow_dump/clickhouse/clickhouse.html

# Usage Recommendations
We recommend you to [read this document](https://clickhouse.com/docs/en/operations/tips), in particular, if your system has limited resources such as memory and disk

# Data Retention on Large Deployments
When ntopng enforces retetion by deleting old data, it drops partitions that fall outside of the retentiong window. As clickhouse has restrictions on dropping data, retention won't happen if that amount of data to drop exceeds the configured maximum. In order to avoid this problem we recommend you to make sure that the ```/etc/clickhouse-server/config.xml``` file contains the following line

```
<max_partition_size_to_drop>0</max_partition_size_to_drop>
```

Once you have modified the above file, don't forget to restart clickhouse-server.

# Clickhouse Is Eating All My Disk/Memory
You can instruct ntopng to limit disk space usage by setting data retention in preferences to a low value. By default we store 30 days but that can take a lot of disk space on large networks In this case you can reduce it a bit (e.g. to 7 days).

However clickhouse is also using a lot of disk with system tables. You can check how much disk they use with:

```
SELECT
    table,
    formatReadableSize(sum(bytes)) AS size,
    min(min_date) AS min_date,
    max(max_date) AS max_date
FROM system.parts
WHERE active
GROUP BY table

Query id: 97d9131a-dc97-4b1e-958e-c8e2d00b2c87

┌─table───────────────────┬─size───────┬───min_date─┬───max_date─┐
│ flows                   │ 41.07 GiB  │ 1970-01-01 │ 1970-01-01 │
│ part_log                │ 229.23 MiB │ 2021-11-12 │ 2022-08-09 │
│ metric_log              │ 1.09 GiB   │ 2022-03-15 │ 2022-08-09 │
│ metric_log_3            │ 219.29 MiB │ 2022-02-15 │ 2022-03-15 │
│ trace_log               │ 5.93 GiB   │ 2021-11-12 │ 2022-08-09 │
│ query_thread_log        │ 489.17 MiB │ 2021-11-12 │ 2022-08-09 │
│ system_alerts           │ 18.72 KiB  │ 1970-01-01 │ 1970-01-01 │
│ metric_log_1            │ 112.99 MiB │ 2021-12-16 │ 2021-12-29 │
│ interface_alerts        │ 56.67 KiB  │ 1970-01-01 │ 1970-01-01 │
│ query_log               │ 19.13 MiB  │ 1970-01-01 │ 2022-08-09 │
│ metric_log_2            │ 346.79 MiB │ 2021-12-29 │ 2022-02-15 │
│ host_alerts             │ 10.43 KiB  │ 1970-01-01 │ 1970-01-01 │
│ session_log             │ 71.38 MiB  │ 2021-11-12 │ 2022-08-09 │
│ metric_log_0            │ 237.58 MiB │ 2021-11-12 │ 2021-12-16 │
│ user_alerts             │ 2.02 KiB   │ 1970-01-01 │ 1970-01-01 │
│ asynchronous_metric_log │ 1.25 GiB   │ 1970-01-01 │ 2022-08-09 │
└─────────────────────────┴────────────┴────────────┴────────────┘

```

You can reduce the table TTL (i.e. how long data is kept in memory) of the system tables by using *ALTER TABLE system.XXX MODIFY TTL event_date + INTERVAL 3 DAY;* where XXX is the table you want to use. 

We suggest to reduce the space used by large tables (column site in the above report), and in particular run this script

```
clickhouse-client -q "SELECT name FROM system.tables WHERE database = 'system' AND name LIKE '%_log%'" | \
xargs -I{} clickhouse-client -q "ALTER TABLE system.{} MODIFY TTL event_date + INTERVAL 1 DAY"
```

to set all tables TTL to one day.

You can also set system logs TTL by creating a configuration file /etc/clickhouse-server/config.d/system_logs_ttl.xml containing

```
  <clickhouse>
    <trace_log><ttl>event_date + INTERVAL 3 DAY DELETE</ttl></trace_log>
    <text_log><ttl>event_date + INTERVAL 3 DAY DELETE</ttl></text_log>
    <metric_log><ttl>event_date + INTERVAL 3 DAY DELETE</ttl></metric_log>
    <asynchronous_metric_log><ttl>event_date + INTERVAL 3 DAY DELETE</ttl></asynchronous_metric_log>
    <part_log><ttl>event_date + INTERVAL 3 DAY DELETE</ttl></part_log>
    <query_log><ttl>event_date + INTERVAL 7 DAY DELETE</ttl></query_log>
    <processors_profile_log><ttl>event_date + INTERVAL 3 DAY DELETE</ttl></processors_profile_log>
  </clickhouse>
```
 
Finally, you need to reduce the disk space used by ClickHouse logs by editing (as root) 
/etc/clickhouse-server/config.xml and under the <logger> section do:

- modify <level>trace</level> into <level>error</level>
- modify <size>1000M</size> to <size>100M</size>
- modify <count>10</count> to <count>3</count>
- service clickhouse-server start

The clickhouse-server service should be restarted to apply the changes:

```
systemctl restart clickhouse-server
```

# ClickHouse tips
- https://alex.dzyoba.com/kb/clickhouse/

