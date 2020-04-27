--
-- (C) 2020 - ntop.org
--

-- ##############################################

local alert_creators = {}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param alert_subtype A string indicating the subtype for this threshold cross (e.g,. 'bytes', 'active', 'packets', ...)
-- @param alert_granularity A granularity as defined in `alert_consts.alerts_granularities`
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @return A table with the alert built
function alert_creators.createThresholdCross(alert_severity, alert_subtype, alert_granularity, metric, value, operator, threshold)
   local threshold_type = {
      alert_subtype = alert_subtype,
      alert_granularity = alert_granularity,
      alert_severity = alert_severity,
      alert_type_params = {
	 metric = metric,
	 value = value,
	 operator = operator,
	 threshold = threshold,
      }
   }

   return threshold_type
end

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param device The a string with the name or ip address of the device that connected/disconnected
-- @return A table with the alert built
function alert_creators.createDeviceConnectionDisconnection(alert_severity, device)
  local built = {
    alert_severity = alert_severity,
    alert_type_params = {
       device = device,
    },
  }

  return built
end

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @param host_pool The a string with the host pool details
-- @return A table with the alert built
function alert_creators.createPoolConnectionDisconnection(alert_severity, host_pool)
   local host_pools_utils = require("host_pools_utils")

   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 host_pools_utils.getPoolName(interface.getId(), host_pool),
      },
   }

   return built
end

-- ##############################################

return alert_creators

-- ##############################################
