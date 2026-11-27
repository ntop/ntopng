---
title: "alert_api API"
description: "identifies the alerts for the hosts, 'influx_db' the alerts for InfluxDB periodicity, e.g. if set to '5mins', it means that the alert 'trigger' method"
outline: [2, 3]
lastUpdated: 2020-08-17T16:45:47+09:00
---
# alert_api API {#alert-api-api}

## Trigger alert {#trigger-alert}

```lua
local device_connection_alert = alerts:newAlert({
  entity = "mac",
  type = "device_connection",
  severity = "info",
})

device_connection_alert:trigger("00:11:22:33:44:55",
   "The device 00:11:22:33:44:55 has connected to the network")
```

## Metadata {#metadata}

`Metadata mandatory params`:
: - *type*: defines the type of the alert, for example "threshold_cross", "new_device"
  - *entity*: defines the type of the entity which this alert is inherent to, e.g. "host"
    identifies the alerts for the hosts, "influx_db" the alerts for InfluxDB
  - *severity*: defines the alert severity, "info", "warning" or "error"

`Metadata optional params`:
: - *periodicity*: if set, it specify which is the expected alert recheck
    periodicity, e.g. if set to "5mins", it means that the alert "trigger" method
    is expected to be called every 5 minutes. Supported values
    are "min", "5mins", "hour", "day"
  - *subtype*: when multiple alerts with the same type existing, it is possible
    to specify a subtype. For example, threshold cross alerts for bytes have
    type="threshold_cross" and subtype="min_bytes"
  - *formatter*: a function that will be used to format the alert message.
    The function will receive two parameters (msg, alert_record). msg contains
    the message of the alert (usually a parsed JSON), whereas alert_record
    contains the fields of the alerts as stored into the database. (experimental)

### `get_notification_key(alert)` {#get-notification-key}

Returns a key containing a hashed string of the `alert` to quickly identify the alert notification

**Parameters**

- `alert`: A triggered/released alert table

**Returns**: The key as a string

### `is_trigger_notified(alert)` {#is-trigger-notified}

Checks whether the triggered `alert` has already been notified

**Parameters**

- `alert`: A triggered alert table

**Returns**: True if the `alert` has already been notified, false otherwise

### `mark_trigger_notified(alert)` {#mark-trigger-notified}

Marks the triggered `alert` as notified to the recipients

**Parameters**

- `alert`: A triggered alert table

**Returns**: nil

### `mark_release_notified(alert)` {#mark-release-notified}

Marks the released `alert` as notificed to the recipients

**Parameters**

- `alert`: A released alert table

**Returns**: nil

### `addAlertPoolAndNetworkInfo(entity_info, alert_json)` {#addalertpoolandnetworkinfo}

Adds pool information to the alert

**Parameters**

- `entity_info`: data returned by one of the entity_info building functions

### `addTags(alert, type_info)` {#addtags}

Adds the tags of the check generating the alert and the ones of its source, e.g. an active monitoring measurement (used by the issues and by the recipients) active monitoring measurement (used by the issues and by the recipients)

### `pushSmartRecordingFilter(entity_info, ifid)` {#pushsmartrecordingfilter}

Push filter matching the alert to Smart Recording if enabled See also Host::enqueueAlertToRecipients for alerts triggered from C++ See also Host::enqueueAlertToRecipients for alerts triggered from C++

**Parameters**

- `entity_info`: data returned by one of the entity_info building functions

### `alerts_api.store(entity_info, type_info, when)` {#alerts-api-store}

**Parameters**

- `entity_info`: data returned by one of the entity_info building functions
- `type_info`: data returned by one of the type_info building functions
- `when`: (optional) the time when the release event occurs

**Returns**: true if the alert was successfully stored, false otherwise

### `alerts_api.trigger(entity_info, type_info, when, cur_alerts)` {#alerts-api-trigger}

Trigger an alert of given type on the entity

**Parameters**

- `entity_info`: data returned by one of the entity_info building functions
- `type_info`: data returned by one of the type_info building functions
- `when`: (optional) the time when the release event occurs
- `cur_alerts`: (optional) a table containing triggered alerts for the current entity

**Returns**: true on if the alert was triggered, false otherwise

::: info
The actual trigger is performed asynchronously
:::

::: info
false is also returned if an existing alert is found and refreshed
:::

### `alerts_api.release(entity_info, type_info, when, cur_alerts)` {#alerts-api-release}

Release an alert of given type on the entity

**Parameters**

- `entity_info`: data returned by one of the entity_info building functions
- `type_info`: data returned by one of the type_info building functions
- `when`: (optional) the time when the release event occurs
- `cur_alerts`: (optional) a table containing triggered alerts for the current entity

**Returns**: true on success, false otherwise

::: info
The actual release is performed asynchronously
:::

### `alerts_api.setForcedReleases(enabled)` {#alerts-api-setforcedreleases}

Mark the next releases as forced: alerts released while the condition may still be active (e.g. on shutdown), the issues of the alerts are kept open may still be active (e.g. on shutdown), the issues of the alerts are kept open
