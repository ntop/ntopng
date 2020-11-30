--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_severities`
-- @return A table with the alert built
local function createUDPUnidirectional()
   local built = {
      alert_type_params = {},
   }

   return built
end

return {
  alert_key = alert_keys.ntopng.alert_udp_unidirectional,
  i18n_title = "flow_details.udp_unidirectional",
  icon = "fas fa-info-circle",
  creator = createUDPUnidirectional,
}
