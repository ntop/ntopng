--
-- (C) 2020-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

-- ##############################################

local alert_creators = {}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param metric Same as `alert_subtype`
-- @param value A number indicating the measure which crossed the threshold
-- @param operator A string indicating the operator used when evaluating the threshold, one of "gt", ">", "<"
-- @param threshold A number indicating the threshold compared with `value`  using operator
-- @return A table with the alert built
function alert_creators.createThresholdCross(metric, value, operator, threshold)
   local threshold_type = {
      metric = metric,
      value = value,
      operator = operator,
      threshold = threshold,
   }

   return threshold_type
end

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @param host_pool A string with the host pool id
-- @return A table with the alert built
function alert_creators.createPoolConnectionDisconnection(host_pool)
   local host_pools = require "host_pools"
   -- Instantiate host pools
   local host_pools_instance = host_pools:create()

   local built = {
      pool = host_pools_instance:get_pool_name(host_pool),
   }

   return built
end

-- ##############################################

return alert_creators

-- ##############################################
