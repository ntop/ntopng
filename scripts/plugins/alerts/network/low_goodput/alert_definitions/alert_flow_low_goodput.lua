--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @return A table with the alert built
local function createFlowLowGoodput(goodput_ratio)
   local built = {
      alert_type_params = {
	 goodput_ratio = goodput_ratio
      }
   }

   return built
end

-- #######################################################

return {
   alert_key = alert_keys.ntopng.alert_flow_low_goodput,
   i18n_title = "alerts_dashboard.flow_low_goodput",
   icon = "fas fa-exclamation",
   creator = createFlowLowGoodput,
}
