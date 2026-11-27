---
title: "Alerts API"
description: "ntopng provides an alert engine to generate alerts and visualize them into the GUI."
outline: [2, 3]
lastUpdated: 2020-08-17T16:45:17+09:00
---
# Alerts API {#alerts-api}

ntopng provides an alert engine to generate alerts and visualize them into the GUI.

Currently only built-in alerts are supported, which are described in <https://github.com/ntop/ntopng/blob/dev/scripts/lua/modules/alert_consts.lua> .

## Engaged Alerts {#engaged-alerts}

Some alerts in ntopng are shown as "Engaged" and reported as a red triangle
on a host or network interface. Engaged alerts represent ongoing issues and
are "released" once the issue re-enters.

Engaged alerts have a `periodicity` which the defines the expected trigger
frequency of them. If an alert is not "refreshed" (triggered) for some time
it will be automatically released.

- [alert_api API](/api/alerts/alerts_api.md)
  - [Trigger alert](/api/alerts/alerts_api.md#trigger-alert)
  - [Metadata](/api/alerts/alerts_api.md#metadata)

