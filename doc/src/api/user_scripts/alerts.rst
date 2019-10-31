Alert Scripts
#############

Alert scripts are located into separate directories in order to separate them
from the other scripts. Such separation is neeeded because alert scripts are
only invoked if the alerts into ntopng are enabled.

Here is for example the host `syn_flood_victim.lua` script:

.. code:: lua

  local alerts_api = require("alerts_api")
  local user_scripts = require("user_scripts")

  -- #################################################################

  local script = {
    -- Specify an altenative alert type (the default is alerts_api.thresholdCrossType)
    threshold_type_builder = alerts_api.synFloodType,
    default_value = "syn_flood_victim;gt;50",

    hooks = {
      -- Call this every minute
      min = alerts_api.threshold_check_function,
    },
    ...
  }

  -- #################################################################

  -- This function returns the current value for the threshold check
  function script.get_threshold_value(granularity, info)
    return alerts_api.host_delta_val(script.key, granularity, info["packets.sent"] + info["packets.rcvd"])
  end

Most alert scripts use the `alerts_api.threshold_check_function` which performs simple threshold checks (e.g. `value > 10`)

Triggering alerts
-----------------

An alert user script should trigger alerts when some anomalous behaviour is detected.
Users can use the already provided hook callbacks:

  - `alerts_api.threshold_check_function`: can check thresholds and trigger threshold cross alerts
  - `alerts_api.anomaly_check_function`: checks anomaly status, set by the C core

or build their own alert custom logic. In the latter case, the hook callback should call the following functions:

  - `alerts_api.trigger(entity_info, type_info)` whenever the entity state is alerted
  - `alerts_api.release(entity_info, type_info)` whenever the entity state is not alerted

Alerts state is kept internally so multiple trigger/releases of the same alert have no effect.
The `type_info` is specific of the alert_type and should be built using one of the "type_info building functions"
available into `alerts_api.lua`, for example `alerts_api.thresholdCrossType`.


Built-in Alerts
---------------

Alert types are defined into `alert_consts.alert_types` inside
`scripts/lua/modules/alert_consts.lua`. In order to add new alert types,
the alert definition must be inserted into `alert_consts.alert_types`.
The new alert type must have a unique `alert_id` >= 0, a title and description.

Moreover, a new "type_info building function" should be added to the `alerts_api.lua` to describe
the alert type.
