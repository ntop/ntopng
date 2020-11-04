--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

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
-- @param host_pool A string with the host pool id
-- @return A table with the alert built
function alert_creators.createPoolConnectionDisconnection(alert_severity, host_pool)
   local host_pools = require "host_pools"
   -- Instantiate host pools
   local host_pools_instance = host_pools:create()

   local built = {
      alert_severity = alert_severity,
      alert_type_params = {
	 pool = host_pools_instance:get_pool_name(host_pool),
      },
   }

   return built
end

-- ##############################################

function alert_creators.createNoIfActivity(alert_severity, alert_granularity, ifid)
   local no_if_activity_type = {
      alert_granularity = alert_granularity,
      alert_severity = alert_severity,
      alert_type_params = {
         ifname = ifname,
      }
   }

   return no_if_activity_type
end

-- ##############################################

return alert_creators

-- ##############################################
