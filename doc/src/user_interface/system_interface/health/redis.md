---
title: "Redis"
description: "Redis is a key-value store used by ntopng to cache data and preferences. Redis runs as an external service both on Linux and on Windows. ntopng connects..."
outline: [2, 3]
lastUpdated: 2026-11-19T12:14:10+01:00
---

<a id="redis"></a>

# Redis {#redis}

[Redis](https://redis.io/) is a key-value store used by ntopng to cache data and preferences. Redis runs as an external service both on Linux and on Windows. ntopng connects to Redis using sockets. Failing to connect to Redis would cause ntopng to malfunction. Redis must always be up, running and reachable to ensure ntopng functionalities.

Aim of this monitor is to check Redis health and resources used. The page has three tabs: *Overview*, *Historical Data* and *Queues*.

![The Redis Monitor Overview](../../../img/redis_monitor_home.png "The Redis Monitor Overview")

The *Status* card, refreshed every 5 seconds, has three items:

- `Health`: A badge which is either green or red, depending on the status of Redis. The badge is red when Redis fails to save its data to disk (or, when the Redis Append Only File (AOF) is enabled, to write it), otherwise it is green.
- `RAM`: Total memory Redis has obtained from the operating system.
- `Database Keys`: Total number of keys currently stored in Redis.

On Windows Redis does not report its health and the number of keys: only the RAM is shown. The chart icon next to a value opens its chart.

ntopng interacts with Redis using [commands](https://redis.io/commands). Below the card, a table reports how many times each command was issued since ntopng started. The chart button of a row opens the calls of that command over time.

![The Redis Commands](../../../img/redis_monitor_wrench.png "The Redis Commands")

This table is mostly useful to debug anomalous uses of commands and is not really relevant for a user.

The *Historical Data* tab shows the charts:

- A stacked `Top Commands Call` to have an overview of the top commands used in time.
- RAM used
- Database keys
- Number of calls for a subset of Redis commands used.

Timeseries can be disabled from the ntopngPreferences, tab *Timeseries->System Probes*: the *Historical Data* tab and the chart buttons are then disabled.

The *Queues* tab, refreshed every 5 seconds, lists the Redis lists used by ntopng as queues: a component pushes entries (e.g. the updates of the assets of each interface) that another one processes later (e.g. writes them to the database once a minute). For each queue the table shows:

- `Queue` and `Interface Name`: what the queue holds and the interface it belongs to (*System* for the queues not bound to an interface).
- `Redis Key`: the Redis list.
- `Length`: the number of entries waiting to be processed.
- `Max Length` and `Fill %`: the length the queue is limited to and how full it is (empty when the queue is not limited).

When a queue is full, entries are dropped (the newest or the oldest ones, depending on the queue). A fill level shown in red (90% or more) means that the entries are queued faster than they are processed. The queues are sorted by fill level, the fullest first.
