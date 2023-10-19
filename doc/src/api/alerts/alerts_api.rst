alert_api API
#############

Trigger alert
-------------

.. code-block:: lua

  local device_connection_alert = alerts:newAlert({
    entity = "mac",
    type = "device_connection",
    severity = "info",
  })

  device_connection_alert:trigger("00:11:22:33:44:55",
     "The device 00:11:22:33:44:55 has connected to the network")

Metadata
--------

`Metadata mandatory params`:
  - *type*: defines the type of the alert, for example "threshold_cross", "new_device"
  - *entity*: defines the type of the entity which this alert is inherent to, e.g. "host"
    identifies the alerts for the hosts, "influx_db" the alerts for InfluxDB
  - *severity*: defines the alert severity, "info", "warning" or "error"

`Metadata optional params`:
  - *periodicity*: if set, it specify which is the expected alert recheck
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

.. doxygenfile:: alerts_api.lua.cpp
